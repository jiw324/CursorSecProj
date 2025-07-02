#!/bin/bash

# Production Deployment Script
# Automates the deployment process for a web application
# Includes health checks, rollback capabilities, and notifications

set -euo pipefail  # Exit on any error, undefined var, or pipe failure

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
readonly APP_NAME="myapp"
readonly DOCKER_IMAGE="mycompany/${APP_NAME}"
readonly DEPLOY_ENV="${1:-production}"
readonly VERSION_TAG="${2:-latest}"
readonly HEALTH_CHECK_TIMEOUT=300
readonly ROLLBACK_ENABLED="${ROLLBACK_ENABLED:-true}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Error handling
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Deployment failed with exit code $exit_code"
        if [[ "$ROLLBACK_ENABLED" == "true" ]] && [[ -n "${PREVIOUS_VERSION:-}" ]]; then
            log_warning "Initiating rollback to version: $PREVIOUS_VERSION"
            rollback_deployment
        fi
        send_notification "failed" "Deployment failed for $APP_NAME:$VERSION_TAG"
    fi
}

trap cleanup EXIT

# Validation functions
validate_environment() {
    log_info "Validating deployment environment..."
    
    case "$DEPLOY_ENV" in
        development|staging|production)
            log_success "Environment '$DEPLOY_ENV' is valid"
            ;;
        *)
            log_error "Invalid environment: $DEPLOY_ENV"
            log_error "Valid environments: development, staging, production"
            exit 1
            ;;
    esac
    
    # Check required tools
    local required_tools=("docker" "kubectl" "curl" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is required but not installed"
            exit 1
        fi
    done
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Validate Kubernetes connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Docker functions
build_image() {
    log_info "Building Docker image: $DOCKER_IMAGE:$VERSION_TAG"
    
    if [[ ! -f "$SCRIPT_DIR/../Dockerfile" ]]; then
        log_error "Dockerfile not found at $SCRIPT_DIR/../Dockerfile"
        exit 1
    fi
    
    docker build \
        --tag "$DOCKER_IMAGE:$VERSION_TAG" \
        --tag "$DOCKER_IMAGE:latest" \
        --build-arg NODE_ENV="$DEPLOY_ENV" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
        "$SCRIPT_DIR/.."
        
    log_success "Docker image built successfully"
}

push_image() {
    log_info "Pushing Docker image to registry..."
    
    # Authenticate with registry if credentials provided
    if [[ -n "${DOCKER_REGISTRY_USER:-}" ]] && [[ -n "${DOCKER_REGISTRY_PASSWORD:-}" ]]; then
        echo "$DOCKER_REGISTRY_PASSWORD" | docker login --username "$DOCKER_REGISTRY_USER" --password-stdin
    fi
    
    docker push "$DOCKER_IMAGE:$VERSION_TAG"
    docker push "$DOCKER_IMAGE:latest"
    
    log_success "Docker image pushed successfully"
}

# Kubernetes deployment functions
get_current_version() {
    kubectl get deployment "$APP_NAME" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo ""
}

deploy_to_kubernetes() {
    log_info "Deploying to Kubernetes cluster..."
    
    # Store current version for potential rollback
    PREVIOUS_VERSION=$(get_current_version)
    if [[ -n "$PREVIOUS_VERSION" ]]; then
        log_info "Current version: $PREVIOUS_VERSION"
    fi
    
    # Apply Kubernetes manifests
    envsubst < "$SCRIPT_DIR/../k8s/deployment.yaml" | kubectl apply -f -
    envsubst < "$SCRIPT_DIR/../k8s/service.yaml" | kubectl apply -f -
    
    # Update deployment image
    kubectl set image deployment/"$APP_NAME" "$APP_NAME=$DOCKER_IMAGE:$VERSION_TAG"
    
    # Wait for rollout to complete
    log_info "Waiting for deployment rollout..."
    if kubectl rollout status deployment/"$APP_NAME" --timeout=600s; then
        log_success "Deployment rollout completed"
    else
        log_error "Deployment rollout failed"
        exit 1
    fi
}

# Health check functions
wait_for_health() {
    log_info "Performing health checks..."
    
    local start_time=$(date +%s)
    local service_url=$(kubectl get service "$APP_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [[ -z "$service_url" ]]; then
        service_url="localhost"
        kubectl port-forward service/"$APP_NAME" 8080:80 &
        local port_forward_pid=$!
        sleep 5  # Wait for port-forward to establish
    fi
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $HEALTH_CHECK_TIMEOUT ]]; then
            log_error "Health check timeout after ${HEALTH_CHECK_TIMEOUT}s"
            [[ -n "${port_forward_pid:-}" ]] && kill $port_forward_pid 2>/dev/null || true
            exit 1
        fi
        
        log_info "Health check attempt (${elapsed}s elapsed)..."
        
        if curl -sf "http://$service_url:8080/health" > /dev/null 2>&1; then
            log_success "Health check passed"
            [[ -n "${port_forward_pid:-}" ]] && kill $port_forward_pid 2>/dev/null || true
            break
        fi
        
        sleep 10
    done
}

# Rollback function
rollback_deployment() {
    if [[ -z "${PREVIOUS_VERSION:-}" ]]; then
        log_warning "No previous version available for rollback"
        return 1
    fi
    
    log_info "Rolling back to previous version: $PREVIOUS_VERSION"
    kubectl set image deployment/"$APP_NAME" "$APP_NAME=$PREVIOUS_VERSION"
    kubectl rollout status deployment/"$APP_NAME" --timeout=300s
    log_success "Rollback completed"
}

# Database migration
run_migrations() {
    if [[ ! -f "$SCRIPT_DIR/../migrations/migrate.sh" ]]; then
        log_info "No migrations found, skipping..."
        return 0
    fi
    
    log_info "Running database migrations..."
    
    # Create migration job
    kubectl create job "$APP_NAME-migration-$(date +%s)" \
        --from=deployment/"$APP_NAME" \
        --dry-run=client -o yaml | \
        sed 's/restartPolicy: Always/restartPolicy: Never/' | \
        kubectl apply -f -
    
    # Wait for migration to complete
    local job_name=$(kubectl get jobs -l job-name="$APP_NAME-migration" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
    
    if kubectl wait --for=condition=complete job/"$job_name" --timeout=300s; then
        log_success "Database migrations completed"
        kubectl delete job "$job_name"
    else
        log_error "Database migrations failed"
        kubectl logs job/"$job_name"
        exit 1
    fi
}

# Monitoring and notifications
send_notification() {
    local status="$1"
    local message="$2"
    
    # Slack notification
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        local color="good"
        [[ "$status" == "failed" ]] && color="danger"
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"fields\": [{
                        \"title\": \"Deployment Status\",
                        \"value\": \"$message\",
                        \"short\": false
                    }]
                }]
            }" \
            "$SLACK_WEBHOOK_URL" || log_warning "Failed to send Slack notification"
    fi
    
    # Email notification (if configured)
    if [[ -n "${EMAIL_RECIPIENTS:-}" ]]; then
        echo "$message" | mail -s "Deployment $status: $APP_NAME" "$EMAIL_RECIPIENTS" || \
            log_warning "Failed to send email notification"
    fi
}

# Performance testing
run_smoke_tests() {
    log_info "Running smoke tests..."
    
    if [[ -f "$SCRIPT_DIR/../tests/smoke.sh" ]]; then
        if bash "$SCRIPT_DIR/../tests/smoke.sh" "$DEPLOY_ENV"; then
            log_success "Smoke tests passed"
        else
            log_error "Smoke tests failed"
            exit 1
        fi
    else
        log_info "No smoke tests found, skipping..."
    fi
}

# Security scanning
security_scan() {
    log_info "Running security scan..."
    
    # Trivy security scan
    if command -v trivy &> /dev/null; then
        if trivy image --exit-code 1 "$DOCKER_IMAGE:$VERSION_TAG"; then
            log_success "Security scan passed"
        else
            log_warning "Security vulnerabilities found (check logs)"
        fi
    else
        log_info "Trivy not installed, skipping security scan"
    fi
}

# Cleanup old deployments
cleanup_old_deployments() {
    log_info "Cleaning up old deployments..."
    
    # Keep last 5 replica sets
    kubectl get rs -o name | sort -r | tail -n +6 | xargs -r kubectl delete
    
    # Cleanup old images (keep last 10)
    docker images "$DOCKER_IMAGE" --format "table {{.Tag}}\t{{.CreatedAt}}" | \
        tail -n +11 | awk '{print $1}' | \
        xargs -r -I {} docker rmi "$DOCKER_IMAGE:{}" || true
        
    log_success "Cleanup completed"
}

# Main deployment function
main() {
    log_info "Starting deployment of $APP_NAME:$VERSION_TAG to $DEPLOY_ENV"
    
    validate_environment
    
    # Pre-deployment hooks
    if [[ -f "$SCRIPT_DIR/pre-deploy.sh" ]]; then
        log_info "Running pre-deployment hooks..."
        bash "$SCRIPT_DIR/pre-deploy.sh" "$DEPLOY_ENV"
    fi
    
    # Build and push
    build_image
    security_scan
    push_image
    
    # Deploy
    deploy_to_kubernetes
    run_migrations
    wait_for_health
    run_smoke_tests
    
    # Post-deployment
    cleanup_old_deployments
    
    log_success "Deployment completed successfully!"
    send_notification "success" "Successfully deployed $APP_NAME:$VERSION_TAG to $DEPLOY_ENV"
    
    # Post-deployment hooks
    if [[ -f "$SCRIPT_DIR/post-deploy.sh" ]]; then
        log_info "Running post-deployment hooks..."
        bash "$SCRIPT_DIR/post-deploy.sh" "$DEPLOY_ENV"
    fi
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [VERSION]

Deploy application to specified environment.

Arguments:
    ENVIRONMENT    Target environment (development|staging|production)
    VERSION        Docker image tag (default: latest)

Environment Variables:
    ROLLBACK_ENABLED         Enable automatic rollback on failure (default: true)
    SLACK_WEBHOOK_URL        Slack webhook for notifications
    EMAIL_RECIPIENTS         Email addresses for notifications
    DOCKER_REGISTRY_USER     Docker registry username
    DOCKER_REGISTRY_PASSWORD Docker registry password

Examples:
    $0 staging v1.2.3
    $0 production latest
    ROLLBACK_ENABLED=false $0 production v2.0.0

EOF
}

# Command line argument handling
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Export environment variables for use in templates
export APP_NAME VERSION_TAG DEPLOY_ENV

# Run main function
main "$@" 