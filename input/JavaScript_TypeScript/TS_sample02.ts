import { EventEmitter } from 'events';

type ServiceLifetime = 'singleton' | 'transient' | 'scoped';

interface ServiceDescriptor<T = any> {
    token: ServiceToken<T>;
    implementation?: new (...args: any[]) => T;
    factory?: (container: Container) => T;
    instance?: T;
    lifetime: ServiceLifetime;
    dependencies?: ServiceToken<any>[];
}

interface ServiceToken<T = any> {
    name: string;
    type?: new (...args: any[]) => T;
}

const METADATA_KEY = {
    INJECTABLE: 'custom:injectable',
    INJECT: 'custom:inject',
    DEPENDENCIES: 'custom:dependencies'
};

function Injectable<T extends new (...args: any[]) => any>(target: T): T {
    SimpleReflect.defineMetadata(METADATA_KEY.INJECTABLE, true, target);
    return target;
}

function Inject(token: ServiceToken) {
    return function (target: any, propertyKey: string | symbol | undefined, parameterIndex: number) {
        const existingTokens = SimpleReflect.getMetadata(METADATA_KEY.INJECT, target) || [];
        existingTokens[parameterIndex] = token;
        SimpleReflect.defineMetadata(METADATA_KEY.INJECT, existingTokens, target);
    };
}

class SimpleReflect {
    private static metadata = new WeakMap<any, Map<string, any>>();

    static defineMetadata(key: string, value: any, target: any): void {
        if (!this.metadata.has(target)) {
            this.metadata.set(target, new Map());
        }
        this.metadata.get(target)!.set(key, value);
    }

    static getMetadata(key: string, target: any): any {
        return this.metadata.get(target)?.get(key);
    }

    static hasMetadata(key: string, target: any): boolean {
        return this.metadata.get(target)?.has(key) || false;
    }
}

if (typeof globalThis.Reflect === 'undefined') {
    (globalThis as any).Reflect = SimpleReflect;
}

class Container {
    private services = new Map<string, ServiceDescriptor>();
    private singletonInstances = new Map<string, any>();
    private scopedInstances = new Map<string, any>();
    private resolutionStack: string[] = [];

    register<T>(
        token: ServiceToken<T>,
        implementation: new (...args: any[]) => T,
        lifetime: ServiceLifetime = 'transient'
    ): this {
        this.services.set(token.name, {
            token,
            implementation,
            lifetime,
            dependencies: this.extractDependencies(implementation)
        });
        return this;
    }

    registerFactory<T>(
        token: ServiceToken<T>,
        factory: (container: Container) => T,
        lifetime: ServiceLifetime = 'transient'
    ): this {
        this.services.set(token.name, {
            token,
            factory,
            lifetime
        });
        return this;
    }

    registerInstance<T>(token: ServiceToken<T>, instance: T): this {
        this.services.set(token.name, {
            token,
            instance,
            lifetime: 'singleton'
        });
        this.singletonInstances.set(token.name, instance);
        return this;
    }

    resolve<T>(token: ServiceToken<T>): T {
        const descriptor = this.services.get(token.name);
        if (!descriptor) {
            throw new Error(`Service not registered: ${token.name}`);
        }

        if (this.resolutionStack.includes(token.name)) {
            throw new Error(`Circular dependency detected: ${this.resolutionStack.join(' -> ')} -> ${token.name}`);
        }

        this.resolutionStack.push(token.name);

        try {
            const instance = this.createInstance(descriptor);
            return instance;
        } finally {
            this.resolutionStack.pop();
        }
    }

    private createInstance<T>(descriptor: ServiceDescriptor<T>): T {
        if (descriptor.lifetime === 'singleton' && this.singletonInstances.has(descriptor.token.name)) {
            return this.singletonInstances.get(descriptor.token.name);
        }
 
        if (descriptor.lifetime === 'scoped' && this.scopedInstances.has(descriptor.token.name)) {
            return this.scopedInstances.get(descriptor.token.name);
        }

        let instance: T;

        if (descriptor.instance) {
            instance = descriptor.instance;
        } else if (descriptor.factory) {
            instance = descriptor.factory(this);
        } else if (descriptor.implementation) {
            const dependencies = this.resolveDependencies(descriptor.dependencies || []);
            instance = new descriptor.implementation(...dependencies);
        } else {
            throw new Error(`Cannot create instance for service: ${descriptor.token.name}`);
        }

        if (descriptor.lifetime === 'singleton') {
            this.singletonInstances.set(descriptor.token.name, instance);
        } else if (descriptor.lifetime === 'scoped') {
            this.scopedInstances.set(descriptor.token.name, instance);
        }

        return instance;
    }

    private resolveDependencies(tokens: ServiceToken[]): any[] {
        return tokens.map(token => this.resolve(token));
    }

    private extractDependencies(target: new (...args: any[]) => any): ServiceToken[] {
        const injectTokens = SimpleReflect.getMetadata(METADATA_KEY.INJECT, target) || [];
        return injectTokens.filter((token: ServiceToken) => token !== undefined);
    }

    isRegistered(token: ServiceToken): boolean {
        return this.services.has(token.name);
    }

    createScope(): Container {
        const scopedContainer = new Container();

        for (const [name, descriptor] of this.services) {
            scopedContainer.services.set(name, descriptor);
        }

        for (const [name, instance] of this.singletonInstances) {
            scopedContainer.singletonInstances.set(name, instance);
        }

        return scopedContainer;
    }

    dispose(): void {
        
        for (const [, instance] of this.scopedInstances) {
            if (instance && typeof instance.dispose === 'function') {
                instance.dispose();
            }
        }
        this.scopedInstances.clear();
    }

    getRegisteredServices(): ServiceDescriptor[] {
        return Array.from(this.services.values());
    }
}

const createToken = <T>(name: string): ServiceToken<T> => ({ name });

const TOKENS = {
    Logger: createToken<ILogger>('Logger'),
    DatabaseConnection: createToken<IDatabaseConnection>('DatabaseConnection'),
    UserRepository: createToken<IUserRepository>('UserRepository'),
    UserService: createToken<IUserService>('UserService'),
    EmailService: createToken<IEmailService>('EmailService'),
    NotificationService: createToken<INotificationService>('NotificationService')
};

interface ILogger {
    log(message: string, level?: 'info' | 'warn' | 'error'): void;
    info(message: string): void;
    warn(message: string): void;
    error(message: string): void;
}

interface IDatabaseConnection {
    connect(): Promise<void>;
    disconnect(): Promise<void>;
    query(sql: string, params?: any[]): Promise<any[]>;
    isConnected(): boolean;
}

interface IUserRepository {
    findById(id: string): Promise<User | null>;
    findByEmail(email: string): Promise<User | null>;
    create(user: Omit<User, 'id'>): Promise<User>;
    update(id: string, updates: Partial<User>): Promise<User | null>;
    delete(id: string): Promise<boolean>;
}

interface IUserService {
    createUser(userData: CreateUserData): Promise<User>;
    getUserById(id: string): Promise<User | null>;
    updateUser(id: string, updates: Partial<User>): Promise<User | null>;
    deleteUser(id: string): Promise<boolean>;
}

interface IEmailService {
    sendEmail(to: string, subject: string, body: string): Promise<boolean>;
}

interface INotificationService {
    notify(userId: string, message: string, type: 'info' | 'warning' | 'error'): Promise<void>;
}

interface User {
    id: string;
    email: string;
    name: string;
    createdAt: Date;
    updatedAt: Date;
}

interface CreateUserData {
    email: string;
    name: string;
}

class ConsoleLogger implements ILogger {
    log(message: string, level: 'info' | 'warn' | 'error' = 'info'): void {
        const timestamp = new Date().toISOString();
        const levelUpper = level.toUpperCase();
        console.log(`[${timestamp}] ${levelUpper}: ${message}`);
    }

    info(message: string): void {
        this.log(message, 'info');
    }

    warn(message: string): void {
        this.log(message, 'warn');
    }

    error(message: string): void {
        this.log(message, 'error');
    }
}

class MockDatabaseConnection implements IDatabaseConnection {
    private connected = false;
    private data = new Map<string, any>();

    constructor(private logger: ILogger) {
        this.logger.info('DatabaseConnection created');
    }

    async connect(): Promise<void> {
        this.logger.info('Connecting to database...');
        await new Promise(resolve => setTimeout(resolve, 100));
        this.connected = true;
        this.logger.info('Connected to database');
    }

    async disconnect(): Promise<void> {
        this.logger.info('Disconnecting from database...');
        this.connected = false;
        this.logger.info('Disconnected from database');
    }

    async query(sql: string, params?: any[]): Promise<any[]> {
        if (!this.connected) {
            throw new Error('Database not connected');
        }
        this.logger.info(`Executing query: ${sql}`);
        return [];
    }

    isConnected(): boolean {
        return this.connected;
    }
}

class UserRepository implements IUserRepository {
    private users = new Map<string, User>();
    private nextId = 1;

    constructor(
        private db: IDatabaseConnection,
        private logger: ILogger
    ) {
        this.logger.info('UserRepository created');
        this.seedData();
    }

    private seedData(): void {
        const users = [
            { email: 'alice@example.com', name: 'Alice Johnson' },
            { email: 'bob@example.com', name: 'Bob Smith' }
        ];

        users.forEach(userData => {
            const user: User = {
                id: (this.nextId++).toString(),
                email: userData.email,
                name: userData.name,
                createdAt: new Date(),
                updatedAt: new Date()
            };
            this.users.set(user.id, user);
        });
    }

    async findById(id: string): Promise<User | null> {
        this.logger.info(`Finding user by ID: ${id}`);
        return this.users.get(id) || null;
    }

    async findByEmail(email: string): Promise<User | null> {
        this.logger.info(`Finding user by email: ${email}`);
        for (const user of this.users.values()) {
            if (user.email === email) {
                return user;
            }
        }
        return null;
    }

    async create(userData: CreateUserData): Promise<User> {
        const user: User = {
            id: (this.nextId++).toString(),
            email: userData.email,
            name: userData.name,
            createdAt: new Date(),
            updatedAt: new Date()
        };

        this.users.set(user.id, user);
        this.logger.info(`Created user: ${user.id}`);
        return user;
    }

    async update(id: string, updates: Partial<User>): Promise<User | null> {
        const user = this.users.get(id);
        if (!user) return null;

        const updatedUser = {
            ...user,
            ...updates,
            updatedAt: new Date()
        };

        this.users.set(id, updatedUser);
        this.logger.info(`Updated user: ${id}`);
        return updatedUser;
    }

    async delete(id: string): Promise<boolean> {
        const deleted = this.users.delete(id);
        if (deleted) {
            this.logger.info(`Deleted user: ${id}`);
        }
        return deleted;
    }
}

class UserService implements IUserService {
    constructor(
        private userRepo: IUserRepository,
        private emailService: IEmailService,
        private logger: ILogger
    ) {
        this.logger.info('UserService created');
    }

    async createUser(userData: CreateUserData): Promise<User> {
        this.logger.info(`Creating user: ${userData.email}`);

        const existing = await this.userRepo.findByEmail(userData.email);
        if (existing) {
            throw new Error('User with this email already exists');
        }

        const user = await this.userRepo.create({
            email: userData.email,
            name: userData.name,
            createdAt: new Date(),
            updatedAt: new Date()
        });

        
        await this.emailService.sendEmail(
            user.email,
            'Welcome!',
            `Welcome ${user.name}! Your account has been created.`
        );

        return user;
    }

    async getUserById(id: string): Promise<User | null> {
        return this.userRepo.findById(id);
    }

    async updateUser(id: string, updates: Partial<User>): Promise<User | null> {
        return this.userRepo.update(id, updates);
    }

    async deleteUser(id: string): Promise<boolean> {
        return this.userRepo.delete(id);
    }
}

class EmailService implements IEmailService {
    constructor(private logger: ILogger) {
        this.logger.info('EmailService created');
    }

    async sendEmail(to: string, subject: string, body: string): Promise<boolean> {
        this.logger.info(`Sending email to ${to}: ${subject}`);
        
        await new Promise(resolve => setTimeout(resolve, 50));
        this.logger.info(`Email sent successfully to ${to}`);
        return true;
    }
}

class NotificationService implements INotificationService {
    constructor(
        private logger: ILogger,
        private emailService: IEmailService
    ) {
        this.logger.info('NotificationService created');
    }

    async notify(userId: string, message: string, type: 'info' | 'warning' | 'error'): Promise<void> {
        this.logger.info(`Sending ${type} notification to user ${userId}: ${message}`);

        await this.emailService.sendEmail(
            `user-${userId}@example.com`,
            `Notification: ${type.toUpperCase()}`,
            message
        );
    }
}

function configureContainer(): Container {
    const container = new Container();

    container.register(TOKENS.Logger, ConsoleLogger, 'singleton');
    container.register(TOKENS.DatabaseConnection, MockDatabaseConnection, 'singleton');
    container.register(TOKENS.UserRepository, UserRepository, 'singleton');
    container.register(TOKENS.UserService, UserService, 'transient');
    container.register(TOKENS.EmailService, EmailService, 'singleton');
    container.register(TOKENS.NotificationService, NotificationService, 'singleton');

    return container;
}

async function demonstrateDependencyInjection(): Promise<void> {
    console.log('🔧 Dependency Injection Container Demo');
    console.log('======================================');

    const container = configureContainer();

    console.log('\n--- Service Registration ---');
    console.log('Registered services:');
    container.getRegisteredServices().forEach(descriptor => {
        console.log(`- ${descriptor.token.name} (${descriptor.lifetime})`);
    });

    console.log('\n--- Service Resolution ---');
    
    const db = container.resolve(TOKENS.DatabaseConnection);
    await db.connect();

    const userService = container.resolve(TOKENS.UserService);

    console.log('\n--- User Operations ---');

    
    try {
        const newUser = await userService.createUser({
            email: 'charlie@example.com',
            name: 'Charlie Brown'
        });
        console.log('Created user:', newUser);


        const retrievedUser = await userService.getUserById(newUser.id);
        console.log('Retrieved user:', retrievedUser);

        
        const updatedUser = await userService.updateUser(newUser.id, {
            name: 'Charlie B. Brown'
        });
        console.log('Updated user:', updatedUser);

    } catch (error) {
        console.error('Error:', error.message);
    }

    console.log('\n--- Notification Service ---');
    const notificationService = container.resolve(TOKENS.NotificationService);
    await notificationService.notify('1', 'Welcome to our service!', 'info');

    console.log('\n--- Scoped Container Demo ---');
    const scopedContainer = container.createScope();
    const scopedUserService = scopedContainer.resolve(TOKENS.UserService);

    console.log('Scoped service resolved');

    scopedContainer.dispose();
    console.log('Scoped container disposed');
 
    await db.disconnect();

    console.log('\n=== Dependency Injection Demo Complete ===');
}

export {
    Container,
    createToken,
    configureContainer,
    demonstrateDependencyInjection,
    TOKENS,
    ConsoleLogger,
    MockDatabaseConnection,
    UserRepository,
    UserService,
    EmailService,
    NotificationService
};

export type {
    ServiceToken,
    ServiceDescriptor,
    ServiceLifetime,
    ILogger,
    IDatabaseConnection,
    IUserRepository,
    IUserService,
    IEmailService,
    INotificationService,
    User,
    CreateUserData
};
