import fs from 'fs';

interface Customer {
    id: number;
    name: string;
    email: string;
    phone?: string;
    address: Address;
    loyaltyPoints: number;
    membershipLevel: MembershipLevel;
    createdAt: Date;
    updatedAt: Date;
}

interface Address {
    street: string;
    city: string;
    state: string;
    country: string;
    postalCode: string;
}

interface InventoryItem {
    id: number;
    sku: string;
    name: string;
    description: string;
    category: string;
    supplier: string;
    quantity: number;
    price: number;
    cost: number;
    reorderPoint: number;
    reorderQuantity: number;
    location: string;
    status: InventoryStatus;
    lastRestockDate: Date;
    createdAt: Date;
    updatedAt: Date;
}

interface Transaction {
    id: number;
    type: TransactionType;
    customerId: number;
    items: TransactionItem[];
    subtotal: number;
    tax: number;
    discount?: number;
    total: number;
    paymentMethod: PaymentMethod;
    status: TransactionStatus;
    notes?: string;
    date: Date;
    createdAt: Date;
    updatedAt: Date;
}

interface TransactionItem {
    itemId: number;
    quantity: number;
    price: number;
    discount?: number;
    total: number;
}

interface Supplier {
    id: number;
    name: string;
    contactPerson: string;
    email: string;
    phone: string;
    address: Address;
    paymentTerms: string;
    rating: number;
    activeStatus: boolean;
    createdAt: Date;
    updatedAt: Date;
}

interface PurchaseOrder {
    id: number;
    supplierId: number;
    items: PurchaseOrderItem[];
    status: PurchaseOrderStatus;
    orderDate: Date;
    expectedDeliveryDate: Date;
    actualDeliveryDate?: Date;
    subtotal: number;
    tax: number;
    total: number;
    notes?: string;
    createdAt: Date;
    updatedAt: Date;
}

interface PurchaseOrderItem {
    itemId: number;
    quantity: number;
    unitPrice: number;
    total: number;
}

type MembershipLevel = 'bronze' | 'silver' | 'gold' | 'platinum';
type InventoryStatus = 'in_stock' | 'low_stock' | 'out_of_stock' | 'discontinued';
type TransactionType = 'sale' | 'return' | 'adjustment';
type TransactionStatus = 'pending' | 'completed' | 'cancelled' | 'refunded';
type PaymentMethod = 'cash' | 'credit_card' | 'debit_card' | 'bank_transfer' | 'loyalty_points';
type PurchaseOrderStatus = 'draft' | 'pending' | 'approved' | 'shipped' | 'received' | 'cancelled';

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

class InventoryManagementSystem {
    private customers: Map<number, Customer> = new Map();
    private inventory: Map<number, InventoryItem> = new Map();
    private transactions: Map<number, Transaction> = new Map();
    private suppliers: Map<number, Supplier> = new Map();
    private purchaseOrders: Map<number, PurchaseOrder> = new Map();

    private nextCustomerId = 1;
    private nextItemId = 1;
    private nextTransactionId = 1;
    private nextSupplierId = 1;
    private nextPurchaseOrderId = 1;

    constructor() {
        this.seedData();
    }

    private seedData(): void {
        for (let i = 1; i <= 100; i++) {
            this.customers.set(i, {
                id: i,
                name: `Customer ${i}`,
                email: `customer${i}@example.com`,
                phone: `+1-555-${String(i).padStart(4, '0')}`,
                address: {
                    street: `${i} Main St`,
                    city: `City ${i % 10}`,
                    state: `State ${i % 5}`,
                    country: 'USA',
                    postalCode: `${10000 + i}`
                },
                loyaltyPoints: Math.floor(Math.random() * 1000),
                membershipLevel: ['bronze', 'silver', 'gold', 'platinum'][i % 4] as MembershipLevel,
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 50; i++) {
            const quantity = Math.floor(Math.random() * 100);
            this.inventory.set(i, {
                id: i,
                sku: `SKU${String(i).padStart(6, '0')}`,
                name: `Item ${i}`,
                description: `Description for item ${i}`,
                category: `Category ${i % 5}`,
                supplier: `Supplier ${i % 10}`,
                quantity,
                price: Math.round(Math.random() * 10000) / 100,
                cost: Math.round(Math.random() * 5000) / 100,
                reorderPoint: 20,
                reorderQuantity: 50,
                location: `Aisle ${Math.floor(i / 10)}-Shelf ${i % 10}`,
                status: quantity > 20 ? 'in_stock' : quantity > 0 ? 'low_stock' : 'out_of_stock',
                lastRestockDate: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000),
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 20; i++) {
            this.suppliers.set(i, {
                id: i,
                name: `Supplier ${i}`,
                contactPerson: `Contact ${i}`,
                email: `supplier${i}@example.com`,
                phone: `+1-555-${String(1000 + i).padStart(4, '0')}`,
                address: {
                    street: `${i} Business Ave`,
                    city: `City ${i % 10}`,
                    state: `State ${i % 5}`,
                    country: 'USA',
                    postalCode: `${20000 + i}`
                },
                paymentTerms: 'Net 30',
                rating: Math.floor(Math.random() * 5) + 1,
                activeStatus: i % 10 !== 0,
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 200; i++) {
            const items: TransactionItem[] = [];
            const itemCount = Math.floor(Math.random() * 3) + 1;
            let subtotal = 0;

            for (let j = 0; j < itemCount; j++) {
                const itemId = ((i * (j + 1)) % 50) + 1;
                const item = this.inventory.get(itemId)!;
                const quantity = Math.floor(Math.random() * 3) + 1;
                const price = item.price;
                const total = quantity * price;
                subtotal += total;

                items.push({
                    itemId,
                    quantity,
                    price,
                    total
                });
            }

            const tax = subtotal * 0.1;
            const total = subtotal + tax;

            this.transactions.set(i, {
                id: i,
                type: 'sale',
                customerId: (i % 100) + 1,
                items,
                subtotal,
                tax,
                total,
                paymentMethod: ['cash', 'credit_card', 'debit_card'][i % 3] as PaymentMethod,
                status: 'completed',
                date: new Date(Date.now() - i * 1000000),
                createdAt: new Date(Date.now() - i * 1000000),
                updatedAt: new Date(Date.now() - i * 1000000)
            });
        }

        for (let i = 1; i <= 50; i++) {
            const items: PurchaseOrderItem[] = [];
            const itemCount = Math.floor(Math.random() * 3) + 1;
            let subtotal = 0;

            for (let j = 0; j < itemCount; j++) {
                const itemId = ((i * (j + 1)) % 50) + 1;
                const item = this.inventory.get(itemId)!;
                const quantity = item.reorderQuantity;
                const unitPrice = item.cost;
                const total = quantity * unitPrice;
                subtotal += total;

                items.push({
                    itemId,
                    quantity,
                    unitPrice,
                    total
                });
            }

            const tax = subtotal * 0.1;
            const total = subtotal + tax;

            this.purchaseOrders.set(i, {
                id: i,
                supplierId: (i % 20) + 1,
                items,
                status: ['pending', 'approved', 'shipped', 'received'][i % 4] as PurchaseOrderStatus,
                orderDate: new Date(Date.now() - i * 2000000),
                expectedDeliveryDate: new Date(Date.now() + (7 - i % 7) * 24 * 60 * 60 * 1000),
                subtotal,
                tax,
                total,
                createdAt: new Date(Date.now() - i * 2000000),
                updatedAt: new Date(Date.now() - i * 2000000)
            });
        }
    }

    async getCustomer(id: number): Promise<Customer> {
        const customer = this.customers.get(id);
        if (!customer) throw new NotFoundError(`Customer ${id} not found`);
        return customer;
    }

    async findCustomers(query: Partial<Customer>): Promise<Customer[]> {
        return Array.from(this.customers.values()).filter(customer =>
            Object.entries(query).every(([key, value]) => customer[key as keyof Customer] === value)
        );
    }

    async getInventoryItem(id: number): Promise<InventoryItem> {
        const item = this.inventory.get(id);
        if (!item) throw new NotFoundError(`Inventory item ${id} not found`);
        return item;
    }

    async updateInventoryQuantity(id: number, change: number): Promise<InventoryItem> {
        const item = await this.getInventoryItem(id);
        const newQuantity = item.quantity + change;

        if (newQuantity < 0) {
            throw new ValidationError(`Insufficient quantity for item ${id}`);
        }

        const updatedItem: InventoryItem = {
            ...item,
            quantity: newQuantity,
            status: newQuantity > item.reorderPoint ? 'in_stock' : newQuantity > 0 ? 'low_stock' : 'out_of_stock',
            updatedAt: new Date()
        };

        this.inventory.set(id, updatedItem);
        return updatedItem;
    }

    async createTransaction(data: Omit<Transaction, 'id' | 'createdAt' | 'updatedAt'>): Promise<Transaction> {
        await this.getCustomer(data.customerId);

        for (const item of data.items) {
            await this.updateInventoryQuantity(item.itemId, -item.quantity);
        }

        const id = this.nextTransactionId++;
        const now = new Date();
        const transaction: Transaction = {
            ...data,
            id,
            createdAt: now,
            updatedAt: now
        };

        this.transactions.set(id, transaction);
        return transaction;
    }

    async getSupplier(id: number): Promise<Supplier> {
        const supplier = this.suppliers.get(id);
        if (!supplier) throw new NotFoundError(`Supplier ${id} not found`);
        return supplier;
    }

    async createPurchaseOrder(data: Omit<PurchaseOrder, 'id' | 'createdAt' | 'updatedAt'>): Promise<PurchaseOrder> {
        await this.getSupplier(data.supplierId);

        const id = this.nextPurchaseOrderId++;
        const now = new Date();
        const purchaseOrder: PurchaseOrder = {
            ...data,
            id,
            createdAt: now,
            updatedAt: now
        };

        this.purchaseOrders.set(id, purchaseOrder);
        return purchaseOrder;
    }

    async receivePurchaseOrder(id: number): Promise<PurchaseOrder> {
        const po = this.purchaseOrders.get(id);
        if (!po) throw new NotFoundError(`Purchase order ${id} not found`);
        if (po.status !== 'shipped') throw new ValidationError(`Purchase order ${id} is not ready to be received`);

        for (const item of po.items) {
            await this.updateInventoryQuantity(item.itemId, item.quantity);
        }

        const updatedPo = {
            ...po,
            status: 'received' as PurchaseOrderStatus,
            actualDeliveryDate: new Date(),
            updatedAt: new Date()
        };

        this.purchaseOrders.set(id, updatedPo);
        return updatedPo;
    }

    async getInventoryStats(): Promise<{
        totalItems: number;
        totalValue: number;
        lowStockItems: number;
        outOfStockItems: number;
        categoryDistribution: Record<string, number>;
    }> {
        const items = Array.from(this.inventory.values());
        const categoryDistribution: Record<string, number> = {};

        items.forEach(item => {
            categoryDistribution[item.category] = (categoryDistribution[item.category] || 0) + 1;
        });

        return {
            totalItems: items.length,
            totalValue: items.reduce((sum, item) => sum + item.quantity * item.price, 0),
            lowStockItems: items.filter(item => item.status === 'low_stock').length,
            outOfStockItems: items.filter(item => item.status === 'out_of_stock').length,
            categoryDistribution
        };
    }

    async getTransactionStats(): Promise<{
        totalTransactions: number;
        totalRevenue: number;
        averageTransactionValue: number;
        paymentMethodDistribution: Record<PaymentMethod, number>;
    }> {
        const transactions = Array.from(this.transactions.values());
        const paymentMethodDistribution = transactions.reduce(
            (acc, transaction) => {
                acc[transaction.paymentMethod]++;
                return acc;
            },
            {
                cash: 0,
                credit_card: 0,
                debit_card: 0,
                bank_transfer: 0,
                loyalty_points: 0
            } as Record<PaymentMethod, number>
        );

        const totalRevenue = transactions.reduce((sum, transaction) => sum + transaction.total, 0);

        return {
            totalTransactions: transactions.length,
            totalRevenue,
            averageTransactionValue: totalRevenue / transactions.length,
            paymentMethodDistribution
        };
    }
}

const ims = new InventoryManagementSystem();

async function demonstrateUsage(): Promise<void> {
    try {
        const inventoryStats = await ims.getInventoryStats();
        console.log('Inventory Statistics:', inventoryStats);

        const transactionStats = await ims.getTransactionStats();
        console.log('Transaction Statistics:', transactionStats);

        const transaction = await ims.createTransaction({
            type: 'sale',
            customerId: 1,
            items: [
                { itemId: 1, quantity: 2, price: 99.99, total: 199.98 }
            ],
            subtotal: 199.98,
            tax: 20.00,
            total: 219.98,
            paymentMethod: 'credit_card',
            status: 'completed',
            date: new Date()
        });
        console.log('New Transaction:', transaction);

        const purchaseOrder = await ims.createPurchaseOrder({
            supplierId: 1,
            items: [
                { itemId: 1, quantity: 50, unitPrice: 80.00, total: 4000.00 }
            ],
            status: 'pending',
            orderDate: new Date(),
            expectedDeliveryDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
            subtotal: 4000.00,
            tax: 400.00,
            total: 4400.00
        });
        console.log('New Purchase Order:', purchaseOrder);

    } catch (error) {
        console.error('Error:', error);
    }
}

demonstrateUsage().catch(console.error);

export {
    InventoryManagementSystem,
    ValidationError,
    NotFoundError
};

export type {
    Customer,
    Address,
    InventoryItem,
    Transaction,
    TransactionItem,
    Supplier,
    PurchaseOrder,
    PurchaseOrderItem,
    MembershipLevel,
    InventoryStatus,
    TransactionType,
    TransactionStatus,
    PaymentMethod,
    PurchaseOrderStatus
}; 