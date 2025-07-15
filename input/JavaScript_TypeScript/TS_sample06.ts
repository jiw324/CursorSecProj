import fs from 'fs';

interface User {
    id: number;
    username: string;
    email: string;
    isActive: boolean;
    roles: string[];
    profile: UserProfile;
    createdAt: Date;
    updatedAt: Date;
}

interface UserProfile {
    firstName: string;
    lastName: string;
    avatar?: string;
    bio?: string;
    phone?: string;
    address?: Address;
    preferences: UserPreferences;
}

interface UserPreferences {
    theme: 'light' | 'dark';
    notifications: boolean;
    language: string;
    timezone: string;
}

interface Address {
    street: string;
    city: string;
    state: string;
    country: string;
    postalCode: string;
}

interface Product {
    id: number;
    name: string;
    description: string;
    price: number;
    tags: string[];
    inStock: boolean;
    category: string;
    supplier: string;
    minQuantity: number;
    maxQuantity: number;
    reorderPoint: number;
    createdAt: Date;
    updatedAt: Date;
}

interface Order {
    id: number;
    userId: number;
    items: OrderItem[];
    total: number;
    status: OrderStatus;
    paymentStatus: PaymentStatus;
    shippingAddress: Address;
    billingAddress: Address;
    createdAt: Date;
    updatedAt: Date;
}

interface OrderItem {
    productId: number;
    quantity: number;
    price: number;
    discount?: number;
}

type OrderStatus = 'pending' | 'processing' | 'shipped' | 'delivered' | 'cancelled';
type PaymentStatus = 'pending' | 'authorized' | 'paid' | 'refunded' | 'failed';

class ValidationError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'ValidationError';
    }
}

class NotFoundError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'NotFoundError';
    }
}

class DatabaseService {
    private users: Map<number, User> = new Map();
    private products: Map<number, Product> = new Map();
    private orders: Map<number, Order> = new Map();
    private nextUserId = 1;
    private nextProductId = 1;
    private nextOrderId = 1;

    constructor() {
        this.seedData();
    }

    private seedData(): void {
        for (let i = 1; i <= 100; i++) {
            this.users.set(i, {
                id: i,
                username: `user${i}`,
                email: `user${i}@example.com`,
                isActive: i % 2 === 0,
                roles: i % 5 === 0 ? ['admin', 'user'] : ['user'],
                profile: {
                    firstName: `First${i}`,
                    lastName: `Last${i}`,
                    preferences: {
                        theme: i % 2 === 0 ? 'light' : 'dark',
                        notifications: true,
                        language: 'en',
                        timezone: 'UTC'
                    }
                },
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 50; i++) {
            this.products.set(i, {
                id: i,
                name: `Product ${i}`,
                description: `Description for product ${i}`,
                price: Math.round(Math.random() * 10000) / 100,
                tags: [`tag${i % 3}`, `tag${(i + 1) % 5}`],
                inStock: i % 3 !== 0,
                category: `Category ${i % 5}`,
                supplier: `Supplier ${i % 10}`,
                minQuantity: 10,
                maxQuantity: 100,
                reorderPoint: 20,
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 200; i++) {
            this.orders.set(i, {
                id: i,
                userId: (i % 100) + 1,
                items: [
                    {
                        productId: ((i * 3) % 50) + 1,
                        quantity: Math.floor(Math.random() * 5) + 1,
                        price: Math.round(Math.random() * 10000) / 100
                    },
                    {
                        productId: ((i * 7) % 50) + 1,
                        quantity: Math.floor(Math.random() * 3) + 1,
                        price: Math.round(Math.random() * 10000) / 100
                    }
                ],
                total: Math.round(Math.random() * 20000) / 100,
                status: ['pending', 'processing', 'shipped', 'delivered', 'cancelled'][i % 5] as OrderStatus,
                paymentStatus: ['pending', 'authorized', 'paid', 'refunded', 'failed'][i % 5] as PaymentStatus,
                shippingAddress: {
                    street: `${i} Main St`,
                    city: `City ${i % 10}`,
                    state: `State ${i % 5}`,
                    country: 'USA',
                    postalCode: `${10000 + i}`
                },
                billingAddress: {
                    street: `${i} Main St`,
                    city: `City ${i % 10}`,
                    state: `State ${i % 5}`,
                    country: 'USA',
                    postalCode: `${10000 + i}`
                },
                createdAt: new Date(Date.now() - i * 1000000),
                updatedAt: new Date(Date.now() - i * 1000000)
            });
        }
    }

    async getUser(id: number): Promise<User> {
        const user = this.users.get(id);
        if (!user) throw new NotFoundError(`User ${id} not found`);
        return user;
    }

    async getUserByEmail(email: string): Promise<User | undefined> {
        return Array.from(this.users.values()).find(u => u.email === email);
    }

    async createUser(userData: Omit<User, 'id' | 'createdAt' | 'updatedAt'>): Promise<User> {
        const id = this.nextUserId++;
        const now = new Date();
        const user: User = {
            ...userData,
            id,
            createdAt: now,
            updatedAt: now
        };
        this.users.set(id, user);
        return user;
    }

    async updateUser(id: number, updates: Partial<User>): Promise<User> {
        const user = await this.getUser(id);
        const updatedUser = {
            ...user,
            ...updates,
            id: user.id,
            updatedAt: new Date()
        };
        this.users.set(id, updatedUser);
        return updatedUser;
    }

    async deleteUser(id: number): Promise<void> {
        if (!this.users.delete(id)) {
            throw new NotFoundError(`User ${id} not found`);
        }
    }

    async getProduct(id: number): Promise<Product> {
        const product = this.products.get(id);
        if (!product) throw new NotFoundError(`Product ${id} not found`);
        return product;
    }

    async createProduct(productData: Omit<Product, 'id' | 'createdAt' | 'updatedAt'>): Promise<Product> {
        const id = this.nextProductId++;
        const now = new Date();
        const product: Product = {
            ...productData,
            id,
            createdAt: now,
            updatedAt: now
        };
        this.products.set(id, product);
        return product;
    }

    async updateProduct(id: number, updates: Partial<Product>): Promise<Product> {
        const product = await this.getProduct(id);
        const updatedProduct = {
            ...product,
            ...updates,
            id: product.id,
            updatedAt: new Date()
        };
        this.products.set(id, updatedProduct);
        return updatedProduct;
    }

    async deleteProduct(id: number): Promise<void> {
        if (!this.products.delete(id)) {
            throw new NotFoundError(`Product ${id} not found`);
        }
    }

    async getOrder(id: number): Promise<Order> {
        const order = this.orders.get(id);
        if (!order) throw new NotFoundError(`Order ${id} not found`);
        return order;
    }

    async createOrder(orderData: Omit<Order, 'id' | 'createdAt' | 'updatedAt'>): Promise<Order> {
        const id = this.nextOrderId++;
        const now = new Date();
        const order: Order = {
            ...orderData,
            id,
            createdAt: now,
            updatedAt: now
        };
        this.orders.set(id, order);
        return order;
    }

    async updateOrder(id: number, updates: Partial<Order>): Promise<Order> {
        const order = await this.getOrder(id);
        const updatedOrder = {
            ...order,
            ...updates,
            id: order.id,
            updatedAt: new Date()
        };
        this.orders.set(id, updatedOrder);
        return updatedOrder;
    }

    async deleteOrder(id: number): Promise<void> {
        if (!this.orders.delete(id)) {
            throw new NotFoundError(`Order ${id} not found`);
        }
    }

    async findUsers(query: Partial<User>): Promise<User[]> {
        return Array.from(this.users.values()).filter(user =>
            Object.entries(query).every(([key, value]) => user[key as keyof User] === value)
        );
    }

    async findProducts(query: Partial<Product>): Promise<Product[]> {
        return Array.from(this.products.values()).filter(product =>
            Object.entries(query).every(([key, value]) => product[key as keyof Product] === value)
        );
    }

    async findOrders(query: Partial<Order>): Promise<Order[]> {
        return Array.from(this.orders.values()).filter(order =>
            Object.entries(query).every(([key, value]) => order[key as keyof Order] === value)
        );
    }

    async getUserStats(): Promise<{
        total: number;
        active: number;
        admins: number;
        themeDistribution: Record<UserPreferences['theme'], number>;
    }> {
        const users = Array.from(this.users.values());
        return {
            total: users.length,
            active: users.filter(u => u.isActive).length,
            admins: users.filter(u => u.roles.includes('admin')).length,
            themeDistribution: users.reduce(
                (acc, user) => {
                    const theme = user.profile.preferences.theme;
                    acc[theme]++;
                    return acc;
                },
                { light: 0, dark: 0 }
            )
        };
    }

    async getProductStats(): Promise<{
        total: number;
        inStock: number;
        averagePrice: number;
        categoryDistribution: Record<string, number>;
    }> {
        const products = Array.from(this.products.values());
        const categoryDistribution: Record<string, number> = {};

        products.forEach(product => {
            categoryDistribution[product.category] = (categoryDistribution[product.category] || 0) + 1;
        });

        return {
            total: products.length,
            inStock: products.filter(p => p.inStock).length,
            averagePrice: products.reduce((sum, p) => sum + p.price, 0) / products.length,
            categoryDistribution
        };
    }

    async getOrderStats(): Promise<{
        total: number;
        totalRevenue: number;
        averageOrderValue: number;
        statusDistribution: Record<OrderStatus, number>;
    }> {
        const orders = Array.from(this.orders.values());
        const statusDistribution = orders.reduce(
            (acc, order) => {
                acc[order.status]++;
                return acc;
            },
            {
                pending: 0,
                processing: 0,
                shipped: 0,
                delivered: 0,
                cancelled: 0
            }
        );

        const totalRevenue = orders.reduce((sum, order) => sum + order.total, 0);

        return {
            total: orders.length,
            totalRevenue,
            averageOrderValue: totalRevenue / orders.length,
            statusDistribution
        };
    }
}

const db = new DatabaseService();

async function demonstrateUsage(): Promise<void> {
    try {
        const user = await db.getUser(1);
        console.log('User:', user);

        const userStats = await db.getUserStats();
        console.log('User stats:', userStats);

        const product = await db.getProduct(1);
        console.log('Product:', product);

        const productStats = await db.getProductStats();
        console.log('Product stats:', productStats);

        const order = await db.getOrder(1);
        console.log('Order:', order);

        const orderStats = await db.getOrderStats();
        console.log('Order stats:', orderStats);

    } catch (error) {
        console.error('Error:', error);
    }
}

demonstrateUsage().catch(console.error);

export {
    DatabaseService,
    ValidationError,
    NotFoundError
};

export type {
    User,
    UserProfile,
    UserPreferences,
    Address,
    Product,
    Order,
    OrderItem,
    OrderStatus,
    PaymentStatus
}; 