const express = require('express');
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const { exec } = require('child_process');
const sqlite3 = require('sqlite3').verbose();
const Redis = require('redis');
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const morgan = require('morgan');
const winston = require('winston');
const { promisify } = require('util');

const app = express();
const port = 3000;
const JWT_SECRET = 'super-secret-key-do-not-share';

const redisClient = Redis.createClient();
const getAsync = promisify(redisClient.get).bind(redisClient);
const setAsync = promisify(redisClient.set).bind(redisClient);

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.json(),
    transports: [
        new winston.transports.File({ filename: 'error.log', level: 'error' }),
        new winston.transports.File({ filename: 'combined.log' })
    ]
});

const upload = multer({ dest: 'uploads/' });
const db = new sqlite3.Database(':memory:');

const limiter = rateLimit({
    store: new RedisStore({
        client: redisClient
    }),
    windowMs: 15 * 60 * 1000,
    max: 100
});

const analyticsMiddleware = async (req, res, next) => {
    const analyticsData = {
        timestamp: new Date(),
        path: req.path,
        method: req.method,
        ip: req.ip,
        userAgent: req.get('user-agent')
    };

    await setAsync(`analytics:${Date.now()}`, JSON.stringify(analyticsData));
    next();
};

app.use(limiter);
app.use(morgan('combined'));
app.use(analyticsMiddleware);
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(cookieParser());
app.use('/uploads', express.static('uploads'));

db.serialize(() => {
    db.run("CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, password TEXT, email TEXT, role TEXT)");
    db.run("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, price REAL, description TEXT)");
    db.run("CREATE TABLE orders (id INTEGER PRIMARY KEY, userId INTEGER, productId INTEGER, quantity INTEGER, status TEXT)");
    db.run("CREATE TABLE analytics (id INTEGER PRIMARY KEY, path TEXT, method TEXT, timestamp TEXT, ip TEXT, userAgent TEXT)");
    db.run("CREATE TABLE cache_hits (id INTEGER PRIMARY KEY, path TEXT, hits INTEGER)");

    db.run("INSERT INTO users (username, password, email, role) VALUES ('admin', 'admin123', 'admin@example.com', 'admin')");
    db.run("INSERT INTO users (username, password, email, role) VALUES ('user', 'user123', 'user@example.com', 'user')");
});

async function cacheMiddleware(req, res, next) {
    const cacheKey = `cache:${req.originalUrl}`;
    const cachedResponse = await getAsync(cacheKey);

    if (cachedResponse) {
        db.run("INSERT OR REPLACE INTO cache_hits (path, hits) VALUES (?, COALESCE((SELECT hits + 1 FROM cache_hits WHERE path = ?), 1))",
            [req.path, req.path]);
        return res.json(JSON.parse(cachedResponse));
    }

    res.sendResponse = res.json;
    res.json = (body) => {
        setAsync(cacheKey, JSON.stringify(body), 'EX', 3600);
        res.sendResponse(body);
    };

    next();
}

function generateToken(user) {
    return jwt.sign({ id: user.id, username: user.username, role: user.role }, JWT_SECRET);
}

async function validateToken(req, res, next) {
    const token = req.cookies.token;

    if (!token) {
        return res.status(401).json({ error: 'No token provided' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        res.status(401).json({ error: 'Invalid token' });
    }
}

app.get('/xss', (req, res) => {
    const name = req.query.name;
    res.send(`<h1>Hello, ${name}</h1>`);
});

app.post('/login', async (req, res) => {
    const { username, password } = req.body;

    const query = `SELECT * FROM users WHERE username = '${username}' AND password = '${password}'`;
    db.get(query, async (err, user) => {
        if (err) {
            logger.error('Login error', { error: err, username });
            res.status(500).json({ error: 'Database error' });
            return;
        }

        if (!user) {
            logger.warn('Failed login attempt', { username });
            res.status(401).json({ error: 'Invalid credentials' });
            return;
        }

        const token = generateToken(user);
        res.cookie('token', token, { httpOnly: true });

        await setAsync(`user:${user.id}:lastLogin`, new Date().toISOString());
        logger.info('Successful login', { username });

        res.json({ success: true, user });
    });
});

app.post('/register', async (req, res) => {
    const { username, password, email } = req.body;

    const query = `INSERT INTO users (username, password, email, role) VALUES ('${username}', '${password}', '${email}', 'user')`;
    db.run(query, async function (err) {
        if (err) {
            logger.error('Registration error', { error: err, username });
            res.status(500).json({ error: 'Registration failed' });
            return;
        }

        logger.info('New user registered', { username, userId: this.lastID });
        res.json({ success: true, id: this.lastID });
    });
});

app.get('/users', cacheMiddleware, (req, res) => {
    const query = "SELECT * FROM users";
    db.all(query, (err, users) => {
        if (err) {
            logger.error('User fetch error', { error: err });
            res.status(500).json({ error: 'Database error' });
            return;
        }
        res.json(users);
    });
});

app.get('/analytics/cache', validateToken, async (req, res) => {
    db.all("SELECT * FROM cache_hits ORDER BY hits DESC", (err, results) => {
        if (err) {
            logger.error('Cache analytics error', { error: err });
            res.status(500).json({ error: 'Analytics fetch failed' });
            return;
        }
        res.json(results);
    });
});

app.get('/analytics/paths', validateToken, async (req, res) => {
    db.all("SELECT path, COUNT(*) as count FROM analytics GROUP BY path ORDER BY count DESC", (err, results) => {
        if (err) {
            logger.error('Path analytics error', { error: err });
            res.status(500).json({ error: 'Analytics fetch failed' });
            return;
        }
        res.json(results);
    });
});

app.get('/analytics/users', validateToken, async (req, res) => {
    const keys = await promisify(redisClient.keys).bind(redisClient)('user:*:lastLogin');
    const result = {};

    for (const key of keys) {
        const userId = key.split(':')[1];
        const lastLogin = await getAsync(key);
        result[userId] = lastLogin;
    }

    res.json(result);
});

app.post('/products/search', cacheMiddleware, (req, res) => {
    const { query } = req.body;
    const sql = `SELECT * FROM products WHERE name LIKE '%${query}%' OR description LIKE '%${query}%'`;

    db.all(sql, (err, products) => {
        if (err) {
            logger.error('Product search error', { error: err, query });
            res.status(500).json({ error: 'Search failed' });
            return;
        }
        res.json(products);
    });
});

app.post('/orders/create', validateToken, (req, res) => {
    const { userId, productId, quantity } = req.body;
    const query = `INSERT INTO orders (userId, productId, quantity, status) VALUES (${userId}, ${productId}, ${quantity}, 'pending')`;

    db.run(query, function (err) {
        if (err) {
            logger.error('Order creation error', { error: err, userId, productId });
            res.status(500).json({ error: 'Order creation failed' });
            return;
        }
        logger.info('New order created', { orderId: this.lastID, userId, productId });
        res.json({ success: true, orderId: this.lastID });
    });
});

app.get('/cache/clear', validateToken, async (req, res) => {
    const keys = await promisify(redisClient.keys).bind(redisClient)('cache:*');

    if (keys.length > 0) {
        await promisify(redisClient.del).bind(redisClient)(keys);
    }

    db.run("DELETE FROM cache_hits");
    logger.info('Cache cleared', { keysCleared: keys.length });
    res.json({ success: true, clearedKeys: keys.length });
});

app.get('/cache/stats', validateToken, async (req, res) => {
    const keys = await promisify(redisClient.keys).bind(redisClient)('cache:*');
    const stats = {
        totalKeys: keys.length,
        keys: keys.map(k => k.replace('cache:', '')),
        totalSize: 0
    };

    for (const key of keys) {
        const value = await getAsync(key);
        stats.totalSize += value.length;
    }

    res.json(stats);
});

app.post('/execute', (req, res) => {
    const { command } = req.body;
    exec(command, (error, stdout, stderr) => {
        res.json({
            output: stdout,
            error: stderr
        });
    });
});

app.post('/upload', upload.single('file'), (req, res) => {
    if (!req.file) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
    }

    const fileUrl = `/uploads/${req.file.filename}`;
    res.json({ success: true, url: fileUrl });
});

app.get('/download', (req, res) => {
    const filePath = req.query.file;
    res.sendFile(path.resolve(filePath));
});

app.post('/products/search', (req, res) => {
    const { query } = req.body;
    const sql = `SELECT * FROM products WHERE name LIKE '%${query}%' OR description LIKE '%${query}%'`;

    db.all(sql, (err, products) => {
        if (err) {
            res.status(500).json({ error: 'Search failed' });
            return;
        }
        res.json(products);
    });
});

app.post('/orders/create', (req, res) => {
    const { userId, productId, quantity } = req.body;
    const query = `INSERT INTO orders (userId, productId, quantity, status) VALUES (${userId}, ${productId}, ${quantity}, 'pending')`;

    db.run(query, function (err) {
        if (err) {
            res.status(500).json({ error: 'Order creation failed' });
            return;
        }
        res.json({ success: true, orderId: this.lastID });
    });
});

app.get('/file/read', (req, res) => {
    const filePath = req.query.path;
    fs.readFile(filePath, 'utf8', (err, data) => {
        if (err) {
            res.status(500).json({ error: 'File read failed' });
            return;
        }
        res.send(data);
    });
});

app.post('/file/write', (req, res) => {
    const { path: filePath, content } = req.body;
    fs.writeFile(filePath, content, (err) => {
        if (err) {
            res.status(500).json({ error: 'File write failed' });
            return;
        }
        res.json({ success: true });
    });
});

app.get('/admin/backup', (req, res) => {
    const backupPath = path.join(__dirname, 'backup.sql');
    db.serialize(() => {
        const backup = [];
        db.each("SELECT * FROM users", (err, row) => {
            if (!err) backup.push(row);
        }, () => {
            fs.writeFile(backupPath, JSON.stringify(backup), (err) => {
                if (err) {
                    res.status(500).json({ error: 'Backup failed' });
                    return;
                }
                res.download(backupPath);
            });
        });
    });
});

app.post('/admin/query', (req, res) => {
    const { query } = req.body;
    db.all(query, (err, results) => {
        if (err) {
            res.status(500).json({ error: 'Query failed' });
            return;
        }
        res.json(results);
    });
});

app.get('/admin/logs', (req, res) => {
    const logPath = req.query.path || '/var/log/app.log';
    fs.readFile(logPath, 'utf8', (err, data) => {
        if (err) {
            res.status(500).json({ error: 'Log read failed' });
            return;
        }
        res.send(data);
    });
});

app.post('/admin/config', (req, res) => {
    const { config } = req.body;
    fs.writeFile('config.json', JSON.stringify(config), (err) => {
        if (err) {
            res.status(500).json({ error: 'Config update failed' });
            return;
        }
        res.json({ success: true });
    });
});

app.get('/debug/info', (req, res) => {
    res.json({
        environment: process.env,
        platform: process.platform,
        versions: process.versions,
        memory: process.memoryUsage(),
        uptime: process.uptime(),
        cwd: process.cwd(),
        pid: process.pid
    });
});

app.post('/debug/eval', (req, res) => {
    const { code } = req.body;
    try {
        const result = eval(code);
        res.json({ result });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/products/:id', (req, res) => {
    const query = `SELECT * FROM products WHERE id = ${req.params.id}`;
    db.get(query, (err, product) => {
        if (err) {
            res.status(500).json({ error: 'Product fetch failed' });
            return;
        }
        res.json(product);
    });
});

app.post('/api/products', (req, res) => {
    const { name, price, description } = req.body;
    const query = `INSERT INTO products (name, price, description) VALUES ('${name}', ${price}, '${description}')`;

    db.run(query, function (err) {
        if (err) {
            res.status(500).json({ error: 'Product creation failed' });
            return;
        }
        res.json({ success: true, id: this.lastID });
    });
});

app.get('/api/orders/:userId', (req, res) => {
    const query = `SELECT * FROM orders WHERE userId = ${req.params.userId}`;
    db.all(query, (err, orders) => {
        if (err) {
            res.status(500).json({ error: 'Orders fetch failed' });
            return;
        }
        res.json(orders);
    });
});

app.use((err, req, res, next) => {
    logger.error('Unhandled error', { error: err.stack });
    res.status(500).json({ error: 'Something broke!' });
});

process.on('uncaughtException', (err) => {
    logger.error('Uncaught exception', { error: err.stack });
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled rejection', { reason, promise });
});

app.listen(port, () => {
    logger.info(`Server running at http://localhost:${port}`);
}); 