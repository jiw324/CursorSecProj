type NonNullable<T> = T extends null | undefined ? never : T;
type ReturnType<T extends (...args: any) => any> = T extends (...args: any) => infer R ? R : any;
type Parameters<T extends (...args: any) => any> = T extends (...args: infer P) => any ? P : never;

type DeepPartial<T> = {
    [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
};

type DeepRequired<T> = {
    [P in keyof T]-?: T[P] extends object ? DeepRequired<T[P]> : T[P];
};

type KeysOfType<T, U> = {
    [K in keyof T]: T[K] extends U ? K : never;
}[keyof T];

type Getters<T> = {
    [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

type Setters<T> = {
    [K in keyof T as `set${Capitalize<string & K>}`]: (value: T[K]) => void;
};

type EventHandlers<T> = {
    [K in keyof T as `on${Capitalize<string & K>}Change`]: (oldValue: T[K], newValue: T[K]) => void;
};

function LogMethod(_target: any, _propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor | void {
    const originalMethod = descriptor.value;

    descriptor.value = function (...args: any[]) {
        const className = this.constructor.name;
        console.log(`[${new Date().toISOString()}] Calling ${className}.${_propertyKey} with args:`, args);

        const start = performance.now();
        const result = originalMethod.apply(this, args);
        const duration = performance.now() - start;

        console.log(`[${new Date().toISOString()}] ${className}.${_propertyKey} completed in ${duration.toFixed(2)}ms`);

        if (result instanceof Promise) {
            return result.then(value => {
                console.log(`[${new Date().toISOString()}] ${className}.${_propertyKey} resolved with:`, value);
                return value;
            }).catch(error => {
                console.error(`[${new Date().toISOString()}] ${className}.${_propertyKey} rejected with:`, error);
                throw error;
            });
        }

        console.log(`[${new Date().toISOString()}] ${className}.${_propertyKey} returned:`, result);
        return result;
    };

    return descriptor;
}

function Validate<T>(validator: (value: T) => boolean, errorMessage?: string) {
    return function (target: any, propertyName: string) {
        let value: T;

        const getter = function () {
            return value;
        };

        const setter = function (newValue: T) {
            if (!validator(newValue)) {
                throw new Error(errorMessage || `Invalid value for ${propertyName}: ${newValue}`);
            }
            value = newValue;
        };

        Object.defineProperty(target, propertyName, {
            get: getter,
            set: setter,
            enumerable: true,
            configurable: true
        });
    };
}

interface EventMap {
    [key: string]: any[];
}

class TypedEventEmitter<T extends EventMap> {
    private listeners: {
        [K in keyof T]?: Array<(...args: T[K]) => void>;
    } = {};

    on<K extends keyof T>(event: K, listener: (...args: T[K]) => void): this {
        if (!this.listeners[event]) {
            this.listeners[event] = [];
        }
        this.listeners[event]!.push(listener);
        return this;
    }

    emit<K extends keyof T>(event: K, ...args: T[K]): boolean {
        const eventListeners = this.listeners[event];
        if (!eventListeners || eventListeners.length === 0) {
            return false;
        }

        eventListeners.forEach(listener => {
            try {
                listener(...args);
            } catch (error) {
                console.error(`Error in event listener for '${String(event)}':`, error);
            }
        });

        return true;
    }

    off<K extends keyof T>(event: K, listener?: (...args: T[K]) => void): this {
        if (!listener) {
            delete this.listeners[event];
            return this;
        }

        const eventListeners = this.listeners[event];
        if (eventListeners) {
            const index = eventListeners.indexOf(listener);
            if (index !== -1) {
                eventListeners.splice(index, 1);
            }
        }

        return this;
    }

    once<K extends keyof T>(event: K, listener: (...args: T[K]) => void): this {
        const onceWrapper = (...args: T[K]) => {
            this.off(event, onceWrapper);
            listener(...args);
        };
        return this.on(event, onceWrapper);
    }
}

interface Entity {
    id: string;
    createdAt: Date;
    updatedAt: Date;
}

interface QueryOptions<T> {
    where?: Partial<T>;
    orderBy?: keyof T;
    limit?: number;
    offset?: number;
}

interface Repository<T extends Entity> {
    create(data: Omit<T, 'id' | 'createdAt' | 'updatedAt'>): Promise<T>;
    findById(id: string): Promise<T | null>;
    find(options?: QueryOptions<T>): Promise<T[]>;
    update(id: string, data: Partial<Omit<T, 'id' | 'createdAt'>>): Promise<T | null>;
    delete(id: string): Promise<boolean>;
    count(where?: Partial<T>): Promise<number>;
}

class InMemoryRepository<T extends Entity> implements Repository<T> {
    private data: Map<string, T> = new Map();
    private nextId = 1;

    async create(data: Omit<T, 'id' | 'createdAt' | 'updatedAt'>): Promise<T> {
        const now = new Date();
        const id = this.nextId++.toString();
        const baseEntity = {
            id,
            createdAt: now,
            updatedAt: now
        };
        const entity = { ...baseEntity, ...data } as T;

        this.data.set(entity.id, entity);
        return entity;
    }

    async findById(id: string): Promise<T | null> {
        return this.data.get(id) || null;
    }

    async find(options: QueryOptions<T> = {}): Promise<T[]> {
        let results = Array.from(this.data.values());

        if (options.where) {
            results = results.filter(item => {
                return Object.entries(options.where!).every(([key, value]) => {
                    return (item as any)[key] === value;
                });
            });
        }

        if (options.orderBy) {
            results.sort((a, b) => {
                const aVal = a[options.orderBy!];
                const bVal = b[options.orderBy!];
                if (aVal < bVal) return -1;
                if (aVal > bVal) return 1;
                return 0;
            });
        }

        if (options.offset) {
            results = results.slice(options.offset);
        }
        if (options.limit) {
            results = results.slice(0, options.limit);
        }

        return results;
    }

    async update(id: string, data: Partial<Omit<T, 'id' | 'createdAt'>>): Promise<T | null> {
        const existing = this.data.get(id);
        if (!existing) return null;

        const updated = {
            ...existing,
            ...data,
            updatedAt: new Date()
        } as unknown as T;

        this.data.set(id, updated);
        return updated;
    }

    async delete(id: string): Promise<boolean> {
        return this.data.delete(id);
    }

    async count(where?: Partial<T>): Promise<number> {
        if (!where) return this.data.size;

        const filtered = await this.find({ where });
        return filtered.length;
    }

    clear(): void {
        this.data.clear();
        this.nextId = 1;
    }
}

class QueryBuilder<T> {
    private conditions: Array<(item: T) => boolean> = [];
    private sortField?: keyof T;
    private sortDirection: 'asc' | 'desc' = 'asc';
    private limitValue?: number;
    private offsetValue?: number;

    where<K extends keyof T>(field: K, operator: 'eq' | 'ne' | 'gt' | 'lt' | 'in' | 'contains', value: T[K] | T[K][] | string): this {
        const condition = (item: T): boolean => {
            const fieldValue = item[field];

            switch (operator) {
                case 'eq':
                    return fieldValue === value;
                case 'ne':
                    return fieldValue !== value;
                case 'gt':
                    return fieldValue > (value as any);
                case 'lt':
                    return fieldValue < (value as any);
                case 'in':
                    return Array.isArray(value) && value.includes(fieldValue);
                case 'contains':
                    return typeof fieldValue === 'string' && typeof value === 'string' && fieldValue.includes(value);
                default:
                    return false;
            }
        };

        this.conditions.push(condition);
        return this;
    }

    orderBy<K extends keyof T>(field: K, direction: 'asc' | 'desc' = 'asc'): this {
        this.sortField = field;
        this.sortDirection = direction;
        return this;
    }

    limit(count: number): this {
        this.limitValue = count;
        return this;
    }

    offset(count: number): this {
        this.offsetValue = count;
        return this;
    }

    execute(data: T[]): T[] {
        let result = data.filter(item =>
            this.conditions.every(condition => condition(item))
        );

        if (this.sortField) {
            result.sort((a, b) => {
                const aVal = a[this.sortField!];
                const bVal = b[this.sortField!];

                let comparison = 0;
                if (aVal < bVal) comparison = -1;
                else if (aVal > bVal) comparison = 1;

                return this.sortDirection === 'desc' ? -comparison : comparison;
            });
        }

        if (this.offsetValue) {
            result = result.slice(this.offsetValue);
        }

        if (this.limitValue) {
            result = result.slice(0, this.limitValue);
        }

        return result;
    }
}

type StateChange<T> = {
    [K in keyof T]: {
        property: K;
        oldValue: T[K];
        newValue: T[K];
        timestamp: Date;
    };
}[keyof T];

class StateManager<T extends Record<string, any>> {
    private state: T;
    private history: StateChange<T>[] = [];
    private eventEmitter = new TypedEventEmitter<{
        stateChanged: [StateChange<T>];
        propertyChanged: [keyof T, T[keyof T], T[keyof T]];
    }>();

    constructor(initialState: T) {
        this.state = { ...initialState };
    }

    getState(): Readonly<T> {
        return { ...this.state };
    }

    setState<K extends keyof T>(property: K, value: T[K]): void {
        const oldValue = this.state[property];

        if (oldValue === value) return;

        const change: StateChange<T> = {
            property,
            oldValue,
            newValue: value,
            timestamp: new Date()
        };

        this.state[property] = value;
        this.history.push(change);

        this.eventEmitter.emit('stateChanged', change);
        this.eventEmitter.emit('propertyChanged', property, oldValue, value);
    }

    getProperty<K extends keyof T>(property: K): T[K] {
        return this.state[property];
    }

    subscribe(callback: (change: StateChange<T>) => void): () => void {
        this.eventEmitter.on('stateChanged', callback);
        return () => this.eventEmitter.off('stateChanged', callback);
    }

    subscribeToProperty<K extends keyof T>(
        property: K,
        callback: (oldValue: T[K], newValue: T[K]) => void
    ): () => void {
        const listener = (prop: keyof T, oldVal: T[keyof T], newVal: T[keyof T]) => {
            if (prop === property) {
                callback(oldVal as T[K], newVal as T[K]);
            }
        };

        this.eventEmitter.on('propertyChanged', listener);
        return () => this.eventEmitter.off('propertyChanged', listener);
    }

    getHistory(): readonly StateChange<T>[] {
        return [...this.history];
    }

    undo(): boolean {
        const lastChange = this.history.pop();
        if (!lastChange) return false;

        this.state[lastChange.property] = lastChange.oldValue;
        return true;
    }

    reset(newState: T): void {
        Object.keys(this.state).forEach(key => {
            const typedKey = key as keyof T;
            this.setState(typedKey, newState[typedKey]);
        });
    }
}

interface User extends Entity {
    username: string;
    email: string;
    profile: UserProfile;
    permissions: Permission[];
}

interface UserProfile {
    firstName: string;
    lastName: string;
    age: number;
    preferences: {
        theme: 'light' | 'dark';
        language: string;
        notifications: boolean;
    };
}

interface Permission {
    action: 'read' | 'write' | 'delete' | 'admin';
    resource: string;
    granted: boolean;
}

class UserService {
    constructor(private userRepository: Repository<User>) { }

    async createUser(userData: {
        username: string;
        email: string;
        profile: UserProfile;
    }): Promise<User> {
        if (!this.isValidEmail(userData.email)) {
            throw new Error('Invalid email format');
        }

        const existingUsers = await this.userRepository.find({
            where: { username: userData.username }
        });

        if (existingUsers.length > 0) {
            throw new Error('Username already exists');
        }

        return this.userRepository.create({
            ...userData,
            permissions: []
        });
    }

    async grantPermission(userId: string, permission: Permission): Promise<User | null> {
        const user = await this.userRepository.findById(userId);
        if (!user) return null;

        const existingPermissionIndex = user.permissions.findIndex(
            p => p.action === permission.action && p.resource === permission.resource
        );

        if (existingPermissionIndex >= 0) {
            user.permissions[existingPermissionIndex] = permission;
        } else {
            user.permissions.push(permission);
        }

        return this.userRepository.update(userId, { permissions: user.permissions });
    }

    async hasPermission(userId: string, action: Permission['action'], resource: string): Promise<boolean> {
        const user = await this.userRepository.findById(userId);
        if (!user) return false;

        return user.permissions.some(
            p => p.action === action && p.resource === resource && p.granted
        );
    }

    private isValidEmail(email: string): boolean {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    async getUserStats(): Promise<{
        totalUsers: number;
        usersByTheme: Record<UserProfile['preferences']['theme'], number>;
        averageAge: number;
        permissionDistribution: Record<Permission['action'], number>;
    }> {
        const allUsers = await this.userRepository.find();

        const stats = {
            totalUsers: allUsers.length,
            usersByTheme: { light: 0, dark: 0 },
            averageAge: 0,
            permissionDistribution: { read: 0, write: 0, delete: 0, admin: 0 }
        };

        if (allUsers.length === 0) return stats;

        allUsers.forEach(user => {
            stats.usersByTheme[user.profile.preferences.theme]++;
        });

        const totalAge = allUsers.reduce((sum, user) => sum + user.profile.age, 0);
        stats.averageAge = totalAge / allUsers.length;

        allUsers.forEach(user => {
            user.permissions.forEach(permission => {
                if (permission.granted) {
                    stats.permissionDistribution[permission.action]++;
                }
            });
        });

        return stats;
    }
}

async function demonstrateAdvancedTypeSystem(): Promise<void> {
    const userRepository = new InMemoryRepository<User>();
    const userService = new UserService(userRepository);

    const appState = new StateManager({
        currentUser: null as User | null,
        theme: 'light' as 'light' | 'dark',
        sidebarOpen: false,
        notifications: [] as string[]
    });

    const unsubscribe = appState.subscribe(change => {
        console.log(`State changed: ${String(change.property)} = ${change.newValue}`);
    });

    appState.setState('theme', 'dark');
    appState.setState('sidebarOpen', true);

    try {
        const user1 = await userService.createUser({
            username: 'alice',
            email: 'alice@example.com',
            profile: {
                firstName: 'Alice',
                lastName: 'Johnson',
                age: 28,
                preferences: {
                    theme: 'dark',
                    language: 'en',
                    notifications: true
                }
            }
        });

        const user2 = await userService.createUser({
            username: 'bob',
            email: 'bob@example.com',
            profile: {
                firstName: 'Bob',
                lastName: 'Smith',
                age: 35,
                preferences: {
                    theme: 'light',
                    language: 'en',
                    notifications: false
                }
            }
        });

        await userService.grantPermission(user1.id, {
            action: 'read',
            resource: 'documents',
            granted: true
        });

        await userService.grantPermission(user1.id, {
            action: 'write',
            resource: 'documents',
            granted: true
        });

        const canRead = await userService.hasPermission(user1.id, 'read', 'documents');
        const canDelete = await userService.hasPermission(user1.id, 'delete', 'documents');

        const allUsers = await userRepository.find();
        const queryBuilder = new QueryBuilder<User>();

        const youngUsers = queryBuilder
            .where('profile', 'contains', 'Alice')
            .orderBy('createdAt', 'desc')
            .limit(10)
            .execute(allUsers);

        const stats = await userService.getUserStats();

        type UserEvents = {
            userLoggedIn: [User];
            userLoggedOut: [string];
            userUpdated: [User, Partial<User>];
        };

        const userEventEmitter = new TypedEventEmitter<UserEvents>();

        userEventEmitter.on('userLoggedIn', (user) => {
            appState.setState('currentUser', user);
        });

        userEventEmitter.on('userLoggedOut', (username) => {
            appState.setState('currentUser', null);
        });

        userEventEmitter.emit('userLoggedIn', user1);
        userEventEmitter.emit('userLoggedOut', user1.username);

    } catch (error) {
        console.error('Demo error:', error);
    } finally {
        unsubscribe();
    }
}

export {
    DeepPartial,
    DeepRequired,
    KeysOfType,
    Getters,
    Setters,
    EventHandlers,
    LogMethod,
    Validate,
    TypedEventEmitter,
    Repository,
    InMemoryRepository,
    QueryBuilder,
    StateManager,
    UserService,
    demonstrateAdvancedTypeSystem
};

export type {
    Entity,
    QueryOptions,
    StateChange,
    User,
    UserProfile,
    Permission,
    EventMap
};

if (typeof require !== 'undefined' && require.main === module) {
    demonstrateAdvancedTypeSystem().catch(console.error);
} 