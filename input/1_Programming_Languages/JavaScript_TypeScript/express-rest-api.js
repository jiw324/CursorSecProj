// AI-Generated Code Header
// **Intent:** Express.js REST API with authentication, middleware, and comprehensive CRUD operations
// **Optimization:** Efficient routing, middleware chain, and error handling
// **Safety:** Input validation, authentication, and security middleware

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

// AI-SUGGESTION: In-memory data stores (replace with real database in production)
const users = new Map();
const products = new Map();
const orders = new Map();

// AI-SUGGESTION: JWT Secret (use environment variable in production)
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

class APIError extends Error {
    constructor(message, statusCode = 500) {
        super(message);
        this.statusCode = statusCode;
        this.name = 'APIError';
    }
}

// AI-SUGGESTION: Express application setup
const app = express();
const PORT = process.env.PORT || 3000;

// AI-SUGGESTION: Security middleware
app.use(helmet());
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true
}));

// AI-SUGGESTION: Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.',
    standardHeaders: true,
    legacyHeaders: false
});
app.use(limiter);

// AI-SUGGESTION: Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// AI-SUGGESTION: Request logging middleware
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`${timestamp} - ${req.method} ${req.path} - IP: ${req.ip}`);
    next();
});

// AI-SUGGESTION: Authentication middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Invalid or expired token' });
        }
        req.user = user;
        next();
    });
};

// AI-SUGGESTION: Admin middleware
const requireAdmin = (req, res, next) => {
    if (!req.user || req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Admin access required' });
    }
    next();
};

// AI-SUGGESTION: Validation middleware
const validateUser = (req, res, next) => {
    const { username, email, password } = req.body;
    
    if (!username || username.length < 3) {
        return res.status(400).json({ error: 'Username must be at least 3 characters' });
    }
    
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return res.status(400).json({ error: 'Valid email is required' });
    }
    
    if (!password || password.length < 6) {
        return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }
    
    next();
};

// AI-SUGGESTION: Product validation middleware
const validateProduct = (req, res, next) => {
    const { name, price, category } = req.body;
    
    if (!name || name.trim().length === 0) {
        return res.status(400).json({ error: 'Product name is required' });
    }
    
    if (!price || price <= 0) {
        return res.status(400).json({ error: 'Valid price is required' });
    }
    
    if (!category || category.trim().length === 0) {
        return res.status(400).json({ error: 'Category is required' });
    }
    
    next();
};

// AI-SUGGESTION: Seed initial data
function seedData() {
    // Create admin user
    const adminId = uuidv4();
    const adminPasswordHash = bcrypt.hashSync('admin123', 10);
    users.set(adminId, {
        id: adminId,
        username: 'admin',
        email: 'admin@example.com',
        password: adminPasswordHash,
        role: 'admin',
        createdAt: new Date(),
        isActive: true
    });

    // Create sample products
    const sampleProducts = [
        { name: 'Laptop Pro', price: 1299.99, category: 'Electronics', stock: 50 },
        { name: 'Wireless Mouse', price: 29.99, category: 'Accessories', stock: 200 },
        { name: 'Mechanical Keyboard', price: 89.99, category: 'Accessories', stock: 75 },
        { name: 'Monitor 27"', price: 299.99, category: 'Electronics', stock: 30 },
        { name: 'USB-C Hub', price: 59.99, category: 'Accessories', stock: 100 }
    ];

    sampleProducts.forEach(product => {
        const id = uuidv4();
        products.set(id, {
            id,
            ...product,
            createdAt: new Date(),
            updatedAt: new Date()
        });
    });

    console.log('✅ Sample data seeded');
}

// AI-SUGGESTION: Authentication routes
app.post('/api/auth/register', validateUser, async (req, res, next) => {
    try {
        const { username, email, password } = req.body;
        
        // Check if user already exists
        const existingUser = Array.from(users.values())
            .find(u => u.email === email || u.username === username);
        
        if (existingUser) {
            throw new APIError('User with this email or username already exists', 409);
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const userId = uuidv4();
        
        const newUser = {
            id: userId,
            username,
            email,
            password: hashedPassword,
            role: 'user',
            createdAt: new Date(),
            isActive: true
        };
        
        users.set(userId, newUser);

        const token = jwt.sign(
            { userId, username, role: newUser.role },
            JWT_SECRET,
            { expiresIn: '24h' }
        );

        res.status(201).json({
            message: 'User registered successfully',
            token,
            user: {
                id: userId,
                username,
                email,
                role: newUser.role
            }
        });
    } catch (error) {
        next(error);
    }
});

app.post('/api/auth/login', async (req, res, next) => {
    try {
        const { email, password } = req.body;
        
        if (!email || !password) {
            throw new APIError('Email and password are required', 400);
        }

        const user = Array.from(users.values()).find(u => u.email === email);
        
        if (!user || !user.isActive) {
            throw new APIError('Invalid credentials', 401);
        }

        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            throw new APIError('Invalid credentials', 401);
        }

        const token = jwt.sign(
            { userId: user.id, username: user.username, role: user.role },
            JWT_SECRET,
            { expiresIn: '24h' }
        );

        res.json({
            message: 'Login successful',
            token,
            user: {
                id: user.id,
                username: user.username,
                email: user.email,
                role: user.role
            }
        });
    } catch (error) {
        next(error);
    }
});

// AI-SUGGESTION: User management routes
app.get('/api/users', authenticateToken, requireAdmin, (req, res) => {
    const userList = Array.from(users.values()).map(user => ({
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
        isActive: user.isActive
    }));
    
    res.json({ users: userList, total: userList.length });
});

app.get('/api/users/profile', authenticateToken, (req, res) => {
    const user = users.get(req.user.userId);
    if (!user) {
        return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt
    });
});

// AI-SUGGESTION: Product management routes
app.get('/api/products', (req, res) => {
    const { category, page = 1, limit = 10, search } = req.query;
    let productList = Array.from(products.values());
    
    // Apply filters
    if (category) {
        productList = productList.filter(p => 
            p.category.toLowerCase() === category.toLowerCase()
        );
    }
    
    if (search) {
        productList = productList.filter(p =>
            p.name.toLowerCase().includes(search.toLowerCase())
        );
    }
    
    // Pagination
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + parseInt(limit);
    const paginatedProducts = productList.slice(startIndex, endIndex);
    
    res.json({
        products: paginatedProducts,
        pagination: {
            total: productList.length,
            page: parseInt(page),
            limit: parseInt(limit),
            totalPages: Math.ceil(productList.length / limit)
        }
    });
});

app.get('/api/products/:id', (req, res, next) => {
    try {
        const product = products.get(req.params.id);
        if (!product) {
            throw new APIError('Product not found', 404);
        }
        res.json(product);
    } catch (error) {
        next(error);
    }
});

app.post('/api/products', authenticateToken, requireAdmin, validateProduct, (req, res, next) => {
    try {
        const { name, price, category, description, stock = 0 } = req.body;
        
        const productId = uuidv4();
        const newProduct = {
            id: productId,
            name: name.trim(),
            price: parseFloat(price),
            category: category.trim(),
            description: description?.trim() || '',
            stock: parseInt(stock),
            createdAt: new Date(),
            updatedAt: new Date()
        };
        
        products.set(productId, newProduct);
        
        res.status(201).json({
            message: 'Product created successfully',
            product: newProduct
        });
    } catch (error) {
        next(error);
    }
});

app.put('/api/products/:id', authenticateToken, requireAdmin, validateProduct, (req, res, next) => {
    try {
        const product = products.get(req.params.id);
        if (!product) {
            throw new APIError('Product not found', 404);
        }
        
        const { name, price, category, description, stock } = req.body;
        
        const updatedProduct = {
            ...product,
            name: name.trim(),
            price: parseFloat(price),
            category: category.trim(),
            description: description?.trim() || product.description,
            stock: stock !== undefined ? parseInt(stock) : product.stock,
            updatedAt: new Date()
        };
        
        products.set(req.params.id, updatedProduct);
        
        res.json({
            message: 'Product updated successfully',
            product: updatedProduct
        });
    } catch (error) {
        next(error);
    }
});

app.delete('/api/products/:id', authenticateToken, requireAdmin, (req, res, next) => {
    try {
        const product = products.get(req.params.id);
        if (!product) {
            throw new APIError('Product not found', 404);
        }
        
        products.delete(req.params.id);
        
        res.json({
            message: 'Product deleted successfully',
            deletedProduct: product
        });
    } catch (error) {
        next(error);
    }
});

// AI-SUGGESTION: Order management routes
app.post('/api/orders', authenticateToken, async (req, res, next) => {
    try {
        const { items } = req.body; // items: [{ productId, quantity }]
        
        if (!items || !Array.isArray(items) || items.length === 0) {
            throw new APIError('Order items are required', 400);
        }
        
        let totalAmount = 0;
        const orderItems = [];
        
        for (const item of items) {
            const product = products.get(item.productId);
            if (!product) {
                throw new APIError(`Product ${item.productId} not found`, 404);
            }
            
            if (product.stock < item.quantity) {
                throw new APIError(`Insufficient stock for ${product.name}`, 400);
            }
            
            const itemTotal = product.price * item.quantity;
            totalAmount += itemTotal;
            
            orderItems.push({
                productId: item.productId,
                productName: product.name,
                price: product.price,
                quantity: item.quantity,
                total: itemTotal
            });
            
            // Update stock
            product.stock -= item.quantity;
            products.set(item.productId, product);
        }
        
        const orderId = uuidv4();
        const newOrder = {
            id: orderId,
            userId: req.user.userId,
            items: orderItems,
            totalAmount,
            status: 'pending',
            createdAt: new Date(),
            updatedAt: new Date()
        };
        
        orders.set(orderId, newOrder);
        
        res.status(201).json({
            message: 'Order created successfully',
            order: newOrder
        });
    } catch (error) {
        next(error);
    }
});

app.get('/api/orders', authenticateToken, (req, res) => {
    const userOrders = Array.from(orders.values())
        .filter(order => req.user.role === 'admin' || order.userId === req.user.userId)
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
    res.json({ orders: userOrders, total: userOrders.length });
});

// AI-SUGGESTION: API documentation route
app.get('/api', (req, res) => {
    res.json({
        name: 'Express REST API',
        version: '1.0.0',
        endpoints: {
            authentication: {
                'POST /api/auth/register': 'Register new user',
                'POST /api/auth/login': 'User login'
            },
            users: {
                'GET /api/users': 'Get all users (admin only)',
                'GET /api/users/profile': 'Get current user profile'
            },
            products: {
                'GET /api/products': 'Get all products (with filters)',
                'GET /api/products/:id': 'Get product by ID',
                'POST /api/products': 'Create product (admin only)',
                'PUT /api/products/:id': 'Update product (admin only)',
                'DELETE /api/products/:id': 'Delete product (admin only)'
            },
            orders: {
                'GET /api/orders': 'Get user orders',
                'POST /api/orders': 'Create new order'
            }
        },
        authentication: 'Bearer token required for protected routes'
    });
});

// AI-SUGGESTION: Health check route
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        env: process.env.NODE_ENV || 'development'
    });
});

// AI-SUGGESTION: Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err);
    
    if (err instanceof APIError) {
        return res.status(err.statusCode).json({
            error: err.message,
            timestamp: new Date()
        });
    }
    
    // Handle validation errors
    if (err.name === 'ValidationError') {
        return res.status(400).json({
            error: 'Validation failed',
            details: err.message,
            timestamp: new Date()
        });
    }
    
    // Default error response
    res.status(500).json({
        error: 'Internal server error',
        timestamp: new Date()
    });
});

// AI-SUGGESTION: 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Route not found',
        requestedPath: req.originalUrl,
        method: req.method,
        timestamp: new Date()
    });
});

// AI-SUGGESTION: Server startup
function startServer() {
    seedData();
    
    app.listen(PORT, () => {
        console.log(`🚀 Express REST API server running on port ${PORT}`);
        console.log(`📚 API documentation: http://localhost:${PORT}/api`);
        console.log(`💊 Health check: http://localhost:${PORT}/health`);
        console.log(`👤 Admin credentials: admin@example.com / admin123`);
    });
}

if (require.main === module) {
    startServer();
}

module.exports = { app, startServer }; 