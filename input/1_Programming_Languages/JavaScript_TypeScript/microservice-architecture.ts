// AI-Generated Code Header
// **Intent:** Microservice architecture with service discovery, API gateway, and dependency injection
// **Optimization:** Efficient inter-service communication and load balancing
// **Safety:** Circuit breaker pattern, health checks, and error handling

import { EventEmitter } from 'events';
import { createServer, IncomingMessage, ServerResponse } from 'http';

// AI-SUGGESTION: Service registration and discovery
interface ServiceInfo {
    id: string;
    name: string;
    version: string;
    host: string;
    port: number;
    healthCheck: string;
    metadata: Record<string, any>;
    registeredAt: Date;
    lastHeartbeat: Date;
    status: 'healthy' | 'unhealthy' | 'unknown';
}

interface ServiceEndpoint {
    path: string;
    method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
    handler: string;
    auth?: boolean;
    rateLimit?: number;
}

class ServiceRegistry extends EventEmitter {
    private services: Map<string, ServiceInfo> = new Map();
    private servicesByName: Map<string, ServiceInfo[]> = new Map();
    private healthCheckInterval: NodeJS.Timeout;

    constructor(healthCheckIntervalMs: number = 30000) {
        super();
        this.healthCheckInterval = setInterval(() => {
            this.performHealthChecks();
        }, healthCheckIntervalMs);
    }

    register(service: Omit<ServiceInfo, 'registeredAt' | 'lastHeartbeat' | 'status'>): void {
        const serviceInfo: ServiceInfo = {
            ...service,
            registeredAt: new Date(),
            lastHeartbeat: new Date(),
            status: 'unknown'
        };

        this.services.set(service.id, serviceInfo);

        if (!this.servicesByName.has(service.name)) {
            this.servicesByName.set(service.name, []);
        }
        this.servicesByName.get(service.name)!.push(serviceInfo);

        this.emit('serviceRegistered', serviceInfo);
        console.log(`Service registered: ${service.name}:${service.version} at ${service.host}:${service.port}`);
    }

    unregister(serviceId: string): boolean {
        const service = this.services.get(serviceId);
        if (!service) return false;

        this.services.delete(serviceId);

        const serviceList = this.servicesByName.get(service.name);
        if (serviceList) {
            const index = serviceList.findIndex(s => s.id === serviceId);
            if (index !== -1) {
                serviceList.splice(index, 1);
            }
        }

        this.emit('serviceUnregistered', service);
        console.log(`Service unregistered: ${service.name}:${service.version}`);
        return true;
    }

    heartbeat(serviceId: string): boolean {
        const service = this.services.get(serviceId);
        if (!service) return false;

        service.lastHeartbeat = new Date();
        service.status = 'healthy';
        return true;
    }

    discover(serviceName: string, version?: string): ServiceInfo[] {
        const services = this.servicesByName.get(serviceName) || [];
        
        let filtered = services.filter(s => s.status === 'healthy');
        
        if (version) {
            filtered = filtered.filter(s => s.version === version);
        }

        return filtered;
    }

    getAllServices(): ServiceInfo[] {
        return Array.from(this.services.values());
    }

    private async performHealthChecks(): Promise<void> {
        const promises = Array.from(this.services.values()).map(async (service) => {
            try {
                const healthUrl = `http://${service.host}:${service.port}${service.healthCheck}`;
                const response = await this.makeHttpRequest(healthUrl, 'GET', undefined, 5000);
                
                if (response.statusCode === 200) {
                    service.status = 'healthy';
                    service.lastHeartbeat = new Date();
                } else {
                    service.status = 'unhealthy';
                }
            } catch (error) {
                service.status = 'unhealthy';
                this.emit('serviceHealthCheckFailed', { service, error: error.message });
            }
        });

        await Promise.allSettled(promises);
    }

    private async makeHttpRequest(
        url: string, 
        method: string, 
        data?: any, 
        timeoutMs: number = 5000
    ): Promise<{ statusCode: number; data: any }> {
        return new Promise((resolve, reject) => {
            const urlObj = new URL(url);
            const options = {
                hostname: urlObj.hostname,
                port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
                path: urlObj.pathname + urlObj.search,
                method: method.toUpperCase(),
                timeout: timeoutMs,
                headers: {
                    'Content-Type': 'application/json',
                    'User-Agent': 'Microservice-Gateway/1.0'
                }
            };

            const req = require('http').request(options, (res: any) => {
                let body = '';
                res.on('data', (chunk: any) => body += chunk);
                res.on('end', () => {
                    try {
                        const jsonData = body ? JSON.parse(body) : {};
                        resolve({ statusCode: res.statusCode, data: jsonData });
                    } catch (error) {
                        resolve({ statusCode: res.statusCode, data: body });
                    }
                });
            });

            req.on('error', reject);
            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Request timeout'));
            });

            if (data) {
                req.write(JSON.stringify(data));
            }
            req.end();
        });
    }

    cleanup(): void {
        if (this.healthCheckInterval) {
            clearInterval(this.healthCheckInterval);
        }
    }
}

// AI-SUGGESTION: Circuit breaker pattern
interface CircuitBreakerOptions {
    failureThreshold: number;
    recoveryTimeout: number;
    monitoringPeriod: number;
}

enum CircuitState {
    CLOSED = 'CLOSED',
    OPEN = 'OPEN',
    HALF_OPEN = 'HALF_OPEN'
}

class CircuitBreaker {
    private state: CircuitState = CircuitState.CLOSED;
    private failures: number = 0;
    private lastFailureTime: number = 0;
    private nextAttempt: number = 0;

    constructor(private options: CircuitBreakerOptions) {}

    async execute<T>(operation: () => Promise<T>): Promise<T> {
        if (this.state === CircuitState.OPEN) {
            if (Date.now() < this.nextAttempt) {
                throw new Error('Circuit breaker is OPEN');
            }
            this.state = CircuitState.HALF_OPEN;
        }

        try {
            const result = await operation();
            this.onSuccess();
            return result;
        } catch (error) {
            this.onFailure();
            throw error;
        }
    }

    private onSuccess(): void {
        this.failures = 0;
        this.state = CircuitState.CLOSED;
    }

    private onFailure(): void {
        this.failures++;
        this.lastFailureTime = Date.now();

        if (this.failures >= this.options.failureThreshold) {
            this.state = CircuitState.OPEN;
            this.nextAttempt = Date.now() + this.options.recoveryTimeout;
        }
    }

    getState(): CircuitState {
        return this.state;
    }

    getStats() {
        return {
            state: this.state,
            failures: this.failures,
            lastFailureTime: this.lastFailureTime,
            nextAttempt: this.nextAttempt
        };
    }
}

// AI-SUGGESTION: Load balancer
type LoadBalancingStrategy = 'round-robin' | 'random' | 'least-connections';

class LoadBalancer {
    private roundRobinIndex: Map<string, number> = new Map();
    private connectionCounts: Map<string, number> = new Map();

    selectService(
        services: ServiceInfo[], 
        strategy: LoadBalancingStrategy = 'round-robin'
    ): ServiceInfo | null {
        if (services.length === 0) return null;
        if (services.length === 1) return services[0];

        switch (strategy) {
            case 'round-robin':
                return this.roundRobinSelection(services);
            case 'random':
                return this.randomSelection(services);
            case 'least-connections':
                return this.leastConnectionsSelection(services);
            default:
                return services[0];
        }
    }

    private roundRobinSelection(services: ServiceInfo[]): ServiceInfo {
        const key = services.map(s => s.id).join(',');
        const currentIndex = this.roundRobinIndex.get(key) || 0;
        const nextIndex = (currentIndex + 1) % services.length;
        
        this.roundRobinIndex.set(key, nextIndex);
        return services[currentIndex];
    }

    private randomSelection(services: ServiceInfo[]): ServiceInfo {
        const randomIndex = Math.floor(Math.random() * services.length);
        return services[randomIndex];
    }

    private leastConnectionsSelection(services: ServiceInfo[]): ServiceInfo {
        let leastConnections = Infinity;
        let selectedService = services[0];

        for (const service of services) {
            const connections = this.connectionCounts.get(service.id) || 0;
            if (connections < leastConnections) {
                leastConnections = connections;
                selectedService = service;
            }
        }

        return selectedService;
    }

    incrementConnections(serviceId: string): void {
        const current = this.connectionCounts.get(serviceId) || 0;
        this.connectionCounts.set(serviceId, current + 1);
    }

    decrementConnections(serviceId: string): void {
        const current = this.connectionCounts.get(serviceId) || 0;
        this.connectionCounts.set(serviceId, Math.max(0, current - 1));
    }
}

// AI-SUGGESTION: API Gateway
interface GatewayRoute {
    path: string;
    method: string;
    serviceName: string;
    targetPath?: string;
    auth?: boolean;
    rateLimit?: number;
    timeout?: number;
}

class APIGateway {
    private routes: GatewayRoute[] = [];
    private circuitBreakers: Map<string, CircuitBreaker> = new Map();
    private requestCounts: Map<string, number> = new Map();
    private rateLimitResets: Map<string, number> = new Map();

    constructor(
        private serviceRegistry: ServiceRegistry,
        private loadBalancer: LoadBalancer
    ) {}

    addRoute(route: GatewayRoute): void {
        this.routes.push(route);
        console.log(`Route added: ${route.method} ${route.path} -> ${route.serviceName}`);
    }

    async handleRequest(req: IncomingMessage, res: ServerResponse): Promise<void> {
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        const method = req.method || 'GET';
        
        try {
            // Find matching route
            const route = this.findRoute(url.pathname, method);
            if (!route) {
                this.sendResponse(res, 404, { error: 'Route not found' });
                return;
            }

            // Rate limiting
            if (route.rateLimit && !this.checkRateLimit(req, route.rateLimit)) {
                this.sendResponse(res, 429, { error: 'Rate limit exceeded' });
                return;
            }

            // Authentication check (simplified)
            if (route.auth && !this.checkAuth(req)) {
                this.sendResponse(res, 401, { error: 'Unauthorized' });
                return;
            }

            // Service discovery
            const services = this.serviceRegistry.discover(route.serviceName);
            if (services.length === 0) {
                this.sendResponse(res, 503, { error: 'Service unavailable' });
                return;
            }

            // Load balancing
            const selectedService = this.loadBalancer.selectService(services);
            if (!selectedService) {
                this.sendResponse(res, 503, { error: 'No healthy service instances' });
                return;
            }

            // Circuit breaker
            const circuitBreaker = this.getCircuitBreaker(selectedService.id);
            
            await circuitBreaker.execute(async () => {
                this.loadBalancer.incrementConnections(selectedService.id);
                
                try {
                    await this.proxyRequest(req, res, route, selectedService, url);
                } finally {
                    this.loadBalancer.decrementConnections(selectedService.id);
                }
            });

        } catch (error) {
            console.error('Gateway error:', error);
            if (!res.headersSent) {
                this.sendResponse(res, 500, { error: 'Internal server error' });
            }
        }
    }

    private findRoute(path: string, method: string): GatewayRoute | null {
        return this.routes.find(route => {
            const routeRegex = new RegExp('^' + route.path.replace(/:\w+/g, '[^/]+') + '$');
            return routeRegex.test(path) && route.method.toLowerCase() === method.toLowerCase();
        }) || null;
    }

    private checkRateLimit(req: IncomingMessage, limit: number): boolean {
        const clientId = this.getClientId(req);
        const now = Date.now();
        const resetTime = now + 60000; // 1 minute window
        
        const currentCount = this.requestCounts.get(clientId) || 0;
        const lastReset = this.rateLimitResets.get(clientId) || 0;

        if (now > lastReset) {
            this.requestCounts.set(clientId, 1);
            this.rateLimitResets.set(clientId, resetTime);
            return true;
        }

        if (currentCount >= limit) {
            return false;
        }

        this.requestCounts.set(clientId, currentCount + 1);
        return true;
    }

    private checkAuth(req: IncomingMessage): boolean {
        // Simplified auth check - in real implementation, validate JWT token
        const authHeader = req.headers.authorization;
        return authHeader && authHeader.startsWith('Bearer ');
    }

    private getClientId(req: IncomingMessage): string {
        return req.socket.remoteAddress || 'unknown';
    }

    private getCircuitBreaker(serviceId: string): CircuitBreaker {
        if (!this.circuitBreakers.has(serviceId)) {
            this.circuitBreakers.set(serviceId, new CircuitBreaker({
                failureThreshold: 5,
                recoveryTimeout: 60000,
                monitoringPeriod: 10000
            }));
        }
        return this.circuitBreakers.get(serviceId)!;
    }

    private async proxyRequest(
        req: IncomingMessage,
        res: ServerResponse,
        route: GatewayRoute,
        service: ServiceInfo,
        url: URL
    ): Promise<void> {
        return new Promise((resolve, reject) => {
            let body = '';
            req.on('data', chunk => body += chunk);
            req.on('end', async () => {
                try {
                    const targetPath = route.targetPath || url.pathname;
                    const targetUrl = `http://${service.host}:${service.port}${targetPath}${url.search}`;
                    
                    const response = await this.makeServiceRequest(
                        targetUrl,
                        req.method || 'GET',
                        body ? JSON.parse(body) : undefined,
                        route.timeout || 30000
                    );

                    res.writeHead(response.statusCode, {
                        'Content-Type': 'application/json',
                        'X-Service-Instance': service.id
                    });
                    res.end(JSON.stringify(response.data));
                    resolve();
                } catch (error) {
                    reject(error);
                }
            });
        });
    }

    private async makeServiceRequest(
        url: string,
        method: string,
        data?: any,
        timeoutMs: number = 30000
    ): Promise<{ statusCode: number; data: any }> {
        // Reuse the same HTTP request method from ServiceRegistry
        return new Promise((resolve, reject) => {
            const urlObj = new URL(url);
            const options = {
                hostname: urlObj.hostname,
                port: urlObj.port || 80,
                path: urlObj.pathname + urlObj.search,
                method: method.toUpperCase(),
                timeout: timeoutMs,
                headers: {
                    'Content-Type': 'application/json',
                    'User-Agent': 'API-Gateway/1.0'
                }
            };

            const req = require('http').request(options, (res: any) => {
                let body = '';
                res.on('data', (chunk: any) => body += chunk);
                res.on('end', () => {
                    try {
                        const jsonData = body ? JSON.parse(body) : {};
                        resolve({ statusCode: res.statusCode, data: jsonData });
                    } catch (error) {
                        resolve({ statusCode: res.statusCode, data: body });
                    }
                });
            });

            req.on('error', reject);
            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Service request timeout'));
            });

            if (data) {
                req.write(JSON.stringify(data));
            }
            req.end();
        });
    }

    private sendResponse(res: ServerResponse, statusCode: number, data: any): void {
        if (!res.headersSent) {
            res.writeHead(statusCode, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(data));
        }
    }

    getStats() {
        return {
            routes: this.routes.length,
            circuitBreakers: Object.fromEntries(
                Array.from(this.circuitBreakers.entries()).map(([id, cb]) => [id, cb.getStats()])
            ),
            requestCounts: Object.fromEntries(this.requestCounts),
            rateLimitResets: Object.fromEntries(this.rateLimitResets)
        };
    }
}

// AI-SUGGESTION: Microservice base class
abstract class Microservice {
    protected server?: ReturnType<typeof createServer>;
    
    constructor(
        protected serviceInfo: Omit<ServiceInfo, 'registeredAt' | 'lastHeartbeat' | 'status'>,
        protected registry: ServiceRegistry
    ) {}

    async start(): Promise<void> {
        this.server = createServer(this.handleRequest.bind(this));
        
        this.server.listen(this.serviceInfo.port, () => {
            console.log(`🚀 ${this.serviceInfo.name} service started on port ${this.serviceInfo.port}`);
            this.registry.register(this.serviceInfo);
        });

        // Health check endpoint
        this.addRoute('GET', this.serviceInfo.healthCheck, () => ({
            status: 'healthy',
            service: this.serviceInfo.name,
            version: this.serviceInfo.version,
            timestamp: new Date().toISOString()
        }));

        // Heartbeat to registry
        setInterval(() => {
            this.registry.heartbeat(this.serviceInfo.id);
        }, 15000);
    }

    protected abstract handleRequest(req: IncomingMessage, res: ServerResponse): Promise<void>;

    protected addRoute(method: string, path: string, handler: (req: any) => any): void {
        // Implementation would add route to internal router
        console.log(`Route added: ${method} ${path}`);
    }

    protected sendJSON(res: ServerResponse, data: any, statusCode: number = 200): void {
        res.writeHead(statusCode, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data));
    }

    async stop(): Promise<void> {
        if (this.server) {
            this.registry.unregister(this.serviceInfo.id);
            this.server.close();
            console.log(`${this.serviceInfo.name} service stopped`);
        }
    }
}

// AI-SUGGESTION: Example microservices
class UserService extends Microservice {
    private users: Map<string, any> = new Map();

    constructor(registry: ServiceRegistry) {
        super({
            id: 'user-service-1',
            name: 'user-service',
            version: '1.0.0',
            host: 'localhost',
            port: 3001,
            healthCheck: '/health',
            metadata: { description: 'User management service' }
        }, registry);

        // Seed data
        this.users.set('1', { id: '1', name: 'Alice', email: 'alice@example.com' });
        this.users.set('2', { id: '2', name: 'Bob', email: 'bob@example.com' });
    }

    protected async handleRequest(req: IncomingMessage, res: ServerResponse): Promise<void> {
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        const method = req.method || 'GET';

        if (method === 'GET' && url.pathname === '/health') {
            this.sendJSON(res, {
                status: 'healthy',
                service: this.serviceInfo.name,
                version: this.serviceInfo.version,
                timestamp: new Date().toISOString()
            });
        } else if (method === 'GET' && url.pathname === '/users') {
            this.sendJSON(res, Array.from(this.users.values()));
        } else if (method === 'GET' && url.pathname.startsWith('/users/')) {
            const userId = url.pathname.split('/')[2];
            const user = this.users.get(userId);
            if (user) {
                this.sendJSON(res, user);
            } else {
                this.sendJSON(res, { error: 'User not found' }, 404);
            }
        } else {
            this.sendJSON(res, { error: 'Not found' }, 404);
        }
    }
}

class OrderService extends Microservice {
    private orders: Map<string, any> = new Map();

    constructor(registry: ServiceRegistry) {
        super({
            id: 'order-service-1',
            name: 'order-service',
            version: '1.0.0',
            host: 'localhost',
            port: 3002,
            healthCheck: '/health',
            metadata: { description: 'Order management service' }
        }, registry);

        // Seed data
        this.orders.set('1', { id: '1', userId: '1', items: ['item1', 'item2'], total: 99.99 });
        this.orders.set('2', { id: '2', userId: '2', items: ['item3'], total: 49.99 });
    }

    protected async handleRequest(req: IncomingMessage, res: ServerResponse): Promise<void> {
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        const method = req.method || 'GET';

        if (method === 'GET' && url.pathname === '/health') {
            this.sendJSON(res, {
                status: 'healthy',
                service: this.serviceInfo.name,
                version: this.serviceInfo.version,
                timestamp: new Date().toISOString()
            });
        } else if (method === 'GET' && url.pathname === '/orders') {
            this.sendJSON(res, Array.from(this.orders.values()));
        } else if (method === 'GET' && url.pathname.startsWith('/orders/user/')) {
            const userId = url.pathname.split('/')[3];
            const userOrders = Array.from(this.orders.values()).filter(order => order.userId === userId);
            this.sendJSON(res, userOrders);
        } else {
            this.sendJSON(res, { error: 'Not found' }, 404);
        }
    }
}

// AI-SUGGESTION: Demo function
async function demonstrateMicroservices(): Promise<void> {
    console.log('🏗️  Microservice Architecture Demo');
    console.log('==================================');

    // Initialize components
    const registry = new ServiceRegistry();
    const loadBalancer = new LoadBalancer();
    const gateway = new APIGateway(registry, loadBalancer);

    // Configure gateway routes
    gateway.addRoute({
        path: '/api/users',
        method: 'GET',
        serviceName: 'user-service',
        targetPath: '/users'
    });

    gateway.addRoute({
        path: '/api/users/:id',
        method: 'GET',
        serviceName: 'user-service',
        targetPath: '/users'
    });

    gateway.addRoute({
        path: '/api/orders',
        method: 'GET',
        serviceName: 'order-service',
        targetPath: '/orders'
    });

    // Start services
    const userService = new UserService(registry);
    const orderService = new OrderService(registry);

    await userService.start();
    await orderService.start();

    // Start API Gateway
    const gatewayServer = createServer((req, res) => {
        gateway.handleRequest(req, res);
    });

    gatewayServer.listen(3000, () => {
        console.log('🌐 API Gateway started on port 3000');
    });

    // Wait for services to register
    await new Promise(resolve => setTimeout(resolve, 2000));

    console.log('\n--- Service Registry Status ---');
    console.log('Registered services:', registry.getAllServices().map(s => `${s.name}:${s.version}`));

    console.log('\n--- API Gateway Stats ---');
    console.log(gateway.getStats());

    console.log('\n--- Available Endpoints ---');
    console.log('GET http://localhost:3000/api/users');
    console.log('GET http://localhost:3000/api/users/1');
    console.log('GET http://localhost:3000/api/orders');

    console.log('\n=== Microservices Running ===');
    console.log('Press Ctrl+C to stop all services');

    // Cleanup on exit
    process.on('SIGINT', async () => {
        console.log('\nShutting down services...');
        await userService.stop();
        await orderService.stop();
        gatewayServer.close();
        registry.cleanup();
        process.exit(0);
    });
}

// AI-SUGGESTION: Export classes and interfaces
export {
    ServiceRegistry,
    CircuitBreaker,
    LoadBalancer,
    APIGateway,
    Microservice,
    UserService,
    OrderService,
    demonstrateMicroservices
};

export type {
    ServiceInfo,
    ServiceEndpoint,
    GatewayRoute,
    LoadBalancingStrategy,
    CircuitBreakerOptions
};

// Run demo if executed directly
if (typeof require !== 'undefined' && require.main === module) {
    demonstrateMicroservices().catch(console.error);
} 