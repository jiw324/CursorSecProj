#!/usr/bin/env python3

import asyncio
import hashlib
import logging
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Union
import uuid

from fastapi import (
    FastAPI, HTTPException, Depends, Security, status,
    Request, Response, BackgroundTasks, Query, Path
)
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
import jwt
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr, Field, validator
import redis
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import uvicorn

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: Optional[str] = Field(None, max_length=100)
    
    @validator('password')
    def validate_password(cls, v):
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        return v

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    full_name: Optional[str]
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    expires_in: int

class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    priority: int = Field(1, ge=1, le=5)
    category: Optional[str] = Field(None, max_length=50)

class TaskResponse(BaseModel):
    id: int
    title: str
    description: Optional[str]
    priority: int
    category: Optional[str]
    completed: bool
    created_at: datetime
    updated_at: Optional[datetime]
    user_id: int
    
    class Config:
        from_attributes = True

class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    priority: Optional[int] = Field(None, ge=1, le=5)
    category: Optional[str] = Field(None, max_length=50)
    completed: Optional[bool] = None

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    full_name = Column(String(100))
    hashed_password = Column(String(128), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Task(Base):
    __tablename__ = "tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    priority = Column(Integer, default=1)
    category = Column(String(50))
    completed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    user_id = Column(Integer, nullable=False, index=True)

class AuthService:
    def __init__(self):
        self.secret_key = "your-secret-key-change-in-production"
        self.algorithm = "HS256"
        self.access_token_expire_minutes = 30
        self.pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    
    def hash_password(self, password: str) -> str:
        return self.pwd_context.hash(password)
    
    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        return self.pwd_context.verify(plain_password, hashed_password)
    
    def create_access_token(self, data: Dict[str, Any]) -> str:
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(minutes=self.access_token_expire_minutes)
        to_encode.update({"exp": expire})
        
        encoded_jwt = jwt.encode(to_encode, self.secret_key, algorithm=self.algorithm)
        return encoded_jwt
    
    def decode_access_token(self, token: str) -> Dict[str, Any]:
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=[self.algorithm])
            return payload
        except jwt.PyJWTError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )

class DatabaseService:
    def __init__(self, database_url: str = "sqlite:///./test.db"):
        self.engine = create_engine(database_url, connect_args={"check_same_thread": False})
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        
        Base.metadata.create_all(bind=self.engine)
    
    def get_db(self) -> Session:
        db = self.SessionLocal()
        try:
            yield db
        finally:
            db.close()

class CacheService:
    def __init__(self, redis_url: str = "redis://localhost:6379"):
        try:
            self.redis_client = redis.from_url(redis_url, decode_responses=True)
            self.redis_client.ping()
            logger.info("Connected to Redis")
        except Exception as e:
            logger.warning(f"Redis connection failed: {e}")
            self.redis_client = None
    
    async def get(self, key: str) -> Optional[str]:
        if not self.redis_client:
            return None
        
        try:
            return self.redis_client.get(key)
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None
    
    async def set(self, key: str, value: str, expire: int = 300) -> bool:
        if not self.redis_client:
            return False
        
        try:
            return self.redis_client.setex(key, expire, value)
        except Exception as e:
            logger.error(f"Cache set error: {e}")
            return False
    
    async def delete(self, key: str) -> bool:
        if not self.redis_client:
            return False
        
        try:
            return bool(self.redis_client.delete(key))
        except Exception as e:
            logger.error(f"Cache delete error: {e}")
            return False

class BackgroundTaskService:
    def __init__(self):
        self.task_queue: List[Dict[str, Any]] = []
    
    async def send_email(self, email: str, subject: str, message: str) -> None:
        logger.info(f"Sending email to {email}: {subject}")
        await asyncio.sleep(2)
        logger.info(f"Email sent successfully to {email}")
    
    async def process_data(self, data: Dict[str, Any]) -> None:
        logger.info(f"Processing data: {data}")
        await asyncio.sleep(5)
        logger.info("Data processing completed")
    
    async def cleanup_old_tasks(self, days: int = 30) -> None:
        logger.info(f"Cleaning up tasks older than {days} days")
        await asyncio.sleep(3)
        logger.info("Cleanup completed")

class RateLimitMiddleware:
    def __init__(self, app, max_requests: int = 100, window_seconds: int = 60):
        self.app = app
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests: Dict[str, List[float]] = {}
    
    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            request = Request(scope, receive)
            client_ip = request.client.host
            
            current_time = time.time()
            
            if client_ip in self.requests:
                self.requests[client_ip] = [
                    req_time for req_time in self.requests[client_ip]
                    if current_time - req_time < self.window_seconds
                ]
            else:
                self.requests[client_ip] = []
            
            if len(self.requests[client_ip]) >= self.max_requests:
                response = JSONResponse(
                    status_code=429,
                    content={"detail": "Rate limit exceeded"}
                )
                await response(scope, receive, send)
                return
            
            self.requests[client_ip].append(current_time)
        
        await self.app(scope, receive, send)

auth_service = AuthService()
db_service = DatabaseService()
cache_service = CacheService()
task_service = BackgroundTaskService()

app = FastAPI(
    title="Advanced Task Management API",
    description="A comprehensive FastAPI microservice with authentication and advanced features",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["localhost", "127.0.0.1", "*.example.com"]
)

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security),
    db: Session = Depends(db_service.get_db)
) -> User:
    token = credentials.credentials
    payload = auth_service.decode_access_token(token)
    username = payload.get("sub")
    
    if not username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )
    
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    return user

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    
    response = await call_next(request)
    
    process_time = time.time() - start_time
    logger.info(
        f"{request.method} {request.url} - "
        f"Status: {response.status_code} - "
        f"Time: {process_time:.4f}s"
    )
    
    response.headers["X-Process-Time"] = str(process_time)
    return response

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "version": "1.0.0"
    }

@app.get("/health/detailed")
async def detailed_health_check():
    redis_status = "healthy" if cache_service.redis_client else "unavailable"
    
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "services": {
            "database": "healthy",
            "redis": redis_status,
            "auth": "healthy"
        }
    }

@app.post("/auth/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register_user(
    user_data: UserCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(db_service.get_db)
):
    existing_user = db.query(User).filter(
        (User.username == user_data.username) | (User.email == user_data.email)
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username or email already registered"
        )
    
    hashed_password = auth_service.hash_password(user_data.password)
    db_user = User(
        username=user_data.username,
        email=user_data.email,
        full_name=user_data.full_name,
        hashed_password=hashed_password
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    background_tasks.add_task(
        task_service.send_email,
        user_data.email,
        "Welcome!",
        "Thank you for registering with our service."
    )
    
    return db_user

@app.post("/auth/login", response_model=Token)
async def login_user(
    user_data: UserLogin,
    db: Session = Depends(db_service.get_db)
):
    user = db.query(User).filter(User.username == user_data.username).first()
    
    if not user or not auth_service.verify_password(user_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is disabled"
        )
    
    access_token = auth_service.create_access_token(data={"sub": user.username})
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": auth_service.access_token_expire_minutes * 60
    }

@app.get("/auth/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    return current_user

@app.post("/tasks", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    task_data: TaskCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(db_service.get_db)
):
    db_task = Task(
        title=task_data.title,
        description=task_data.description,
        priority=task_data.priority,
        category=task_data.category,
        user_id=current_user.id
    )
    
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    
    cache_key = f"user_tasks:{current_user.id}"
    await cache_service.delete(cache_key)
    
    return db_task

@app.get("/tasks", response_model=List[TaskResponse])
async def get_tasks(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    category: Optional[str] = Query(None),
    completed: Optional[bool] = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(db_service.get_db)
):
    cache_key = f"user_tasks:{current_user.id}:{skip}:{limit}:{category}:{completed}"
    cached_result = await cache_service.get(cache_key)
    
    if cached_result:
        import json
        return json.loads(cached_result)
    
    query = db.query(Task).filter(Task.user_id == current_user.id)
    
    if category:
        query = query.filter(Task.category == category)
    
    if completed is not None:
        query = query.filter(Task.completed == completed)
    
    tasks = query.offset(skip).limit(limit).all()
    
    import json
    tasks_json = json.dumps([task.__dict__ for task in tasks], default=str)
    await cache_service.set(cache_key, tasks_json, expire=300)
    
    return tasks

@app.get("/tasks/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: int = Path(..., gt=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(db_service.get_db)
):
    task = db.query(Task).filter(
        Task.id == task_id,
        Task.user_id == current_user.id
    ).first()
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )
    
    return task

@app.put("/tasks/{task_id}", response_model=TaskResponse)
async def update_task(
    task_update: TaskUpdate,
    task_id: int = Path(..., gt=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(db_service.get_db)
):
    task = db.query(Task).filter(
        Task.id == task_id,
        Task.user_id == current_user.id
    ).first()
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )
    
    update_data = task_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(task, field, value)
    
    task.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(task)
    
    cache_key = f"user_tasks:{current_user.id}"
    await cache_service.delete(cache_key)
    
    return task

@app.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: int = Path(..., gt=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(db_service.get_db)
):
    task = db.query(Task).filter(
        Task.id == task_id,
        Task.user_id == current_user.id
    ).first()
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )
    
    db.delete(task)
    db.commit()
    
    cache_key = f"user_tasks:{current_user.id}"
    await cache_service.delete(cache_key)

@app.get("/analytics/tasks")
async def get_task_analytics(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(db_service.get_db)
):
    total_tasks = db.query(Task).filter(Task.user_id == current_user.id).count()
    completed_tasks = db.query(Task).filter(
        Task.user_id == current_user.id,
        Task.completed == True
    ).count()
    
    from sqlalchemy import func
    category_stats = db.query(
        Task.category,
        func.count(Task.id).label('count')
    ).filter(Task.user_id == current_user.id).group_by(Task.category).all()
    
    priority_stats = db.query(
        Task.priority,
        func.count(Task.id).label('count')
    ).filter(Task.user_id == current_user.id).group_by(Task.priority).all()
    
    return {
        "total_tasks": total_tasks,
        "completed_tasks": completed_tasks,
        "completion_rate": completed_tasks / total_tasks if total_tasks > 0 else 0,
        "categories": [{"category": cat, "count": count} for cat, count in category_stats],
        "priorities": [{"priority": pri, "count": count} for pri, count in priority_stats]
    }

@app.post("/tasks/cleanup")
async def cleanup_old_tasks(
    background_tasks: BackgroundTasks,
    days: int = Query(30, ge=1, le=365),
    current_user: User = Depends(get_current_user)
):
    background_tasks.add_task(task_service.cleanup_old_tasks, days)
    
    return {"message": f"Cleanup task scheduled for tasks older than {days} days"}

@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    return JSONResponse(
        status_code=404,
        content={"detail": "Resource not found"}
    )

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc):
    logger.error(f"Internal server error: {exc}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )

@app.on_event("startup")
async def startup_event():
    logger.info("FastAPI microservice starting up...")
    logger.info("All services initialized successfully")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("FastAPI microservice shutting down...")
    if cache_service.redis_client:
        cache_service.redis_client.close()
    logger.info("Cleanup completed")

def run_demo():
    print("=== FastAPI Microservice Demo ===")
    print("Starting FastAPI server...")
    print("API Documentation: http://localhost:8000/docs")
    print("Health Check: http://localhost:8000/health")
    
    uvicorn.run(
        "fastapi_microservice:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )

if __name__ == "__main__":
    run_demo() 