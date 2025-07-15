const http = require('http');
const WebSocket = require('ws');
const crypto = require('crypto');
const EventEmitter = require('events');

class User {
    constructor(id, username, socket) {
        this.id = id;
        this.username = username;
        this.socket = socket;
        this.joinedAt = new Date();
        this.lastActivity = new Date();
        this.status = 'online';
        this.currentRoom = 'general';
    }

    updateActivity() {
        this.lastActivity = new Date();
    }

    setStatus(status) {
        this.status = status;
        this.updateActivity();
    }

    joinRoom(roomName) {
        this.currentRoom = roomName;
        this.updateActivity();
    }

    toJSON() {
        return {
            id: this.id,
            username: this.username,
            joinedAt: this.joinedAt,
            status: this.status,
            currentRoom: this.currentRoom,
            lastActivity: this.lastActivity
        };
    }
}

class Message {
    constructor(type, data, sender = null) {
        this.id = crypto.randomUUID();
        this.type = type;
        this.data = data;
        this.sender = sender;
        this.timestamp = new Date();
        this.edited = false;
        this.editHistory = [];
    }

    edit(newContent, editorId) {
        if (this.type === 'chat') {
            this.editHistory.push({
                previousContent: this.data.content,
                editedAt: new Date(),
                editedBy: editorId
            });
            this.data.content = newContent;
            this.edited = true;
        }
    }

    static createChatMessage(content, senderId, senderUsername, roomName) {
        return new Message('chat', {
            content: content.trim(),
            room: roomName,
            senderUsername: senderUsername
        }, senderId);
    }

    static createSystemMessage(content, roomName = 'general') {
        return new Message('system', {
            content,
            room: roomName
        });
    }

    static createUserJoinedMessage(username, roomName) {
        return new Message('user_joined', {
            username,
            room: roomName,
            content: `${username} joined the room`
        });
    }

    static createUserLeftMessage(username, roomName) {
        return new Message('user_left', {
            username,
            room: roomName,
            content: `${username} left the room`
        });
    }
}

class ChatRoom {
    constructor(name, maxUsers = 100) {
        this.name = name;
        this.maxUsers = maxUsers;
        this.users = new Map();
        this.messages = [];
        this.createdAt = new Date();
        this.isPrivate = false;
        this.adminUsers = new Set();
    }

    addUser(user) {
        if (this.users.size >= this.maxUsers) {
            throw new Error('Room is full');
        }

        this.users.set(user.id, user);
        user.joinRoom(this.name);

        const joinMessage = Message.createUserJoinedMessage(user.username, this.name);
        this.addMessage(joinMessage);

        return joinMessage;
    }

    removeUser(userId) {
        const user = this.users.get(userId);
        if (user) {
            this.users.delete(userId);
            const leaveMessage = Message.createUserLeftMessage(user.username, this.name);
            this.addMessage(leaveMessage);
            return leaveMessage;
        }
        return null;
    }

    addMessage(message) {
        this.messages.push(message);

        if (this.messages.length > 1000) {
            this.messages.shift();
        }

        return message;
    }

    getUserList() {
        return Array.from(this.users.values()).map(user => user.toJSON());
    }

    getRecentMessages(count = 50) {
        return this.messages.slice(-count);
    }

    makeAdmin(userId) {
        if (this.users.has(userId)) {
            this.adminUsers.add(userId);
            return true;
        }
        return false;
    }

    isAdmin(userId) {
        return this.adminUsers.has(userId);
    }

    getStats() {
        return {
            name: this.name,
            userCount: this.users.size,
            maxUsers: this.maxUsers,
            messageCount: this.messages.length,
            createdAt: this.createdAt,
            isPrivate: this.isPrivate,
            adminCount: this.adminUsers.size
        };
    }
}

class ChatServer extends EventEmitter {
    constructor(port = 8080) {
        super();
        this.port = port;
        this.users = new Map();
        this.rooms = new Map();
        this.bannedIPs = new Set();
        this.rateLimitMap = new Map();
        this.server = null;
        this.wss = null;

        this.initializeDefaultRooms();
        this.setupRateLimiting();
    }

    initializeDefaultRooms() {
        this.rooms.set('general', new ChatRoom('general', 200));
        this.rooms.set('tech', new ChatRoom('tech', 100));
        this.rooms.set('random', new ChatRoom('random', 150));

        console.log('Default rooms created: general, tech, random');
    }

    setupRateLimiting() {
        setInterval(() => {
            const oneMinuteAgo = Date.now() - 60000;
            for (const [ip, data] of this.rateLimitMap.entries()) {
                data.timestamps = data.timestamps.filter(ts => ts > oneMinuteAgo);
                if (data.timestamps.length === 0) {
                    this.rateLimitMap.delete(ip);
                }
            }
        }, 60000);
    }

    isRateLimited(ip) {
        const now = Date.now();
        const oneMinuteAgo = now - 60000;

        if (!this.rateLimitMap.has(ip)) {
            this.rateLimitMap.set(ip, { timestamps: [] });
        }

        const userData = this.rateLimitMap.get(ip);
        userData.timestamps = userData.timestamps.filter(ts => ts > oneMinuteAgo);

        if (userData.timestamps.length >= 30) {
            return true;
        }

        userData.timestamps.push(now);
        return false;
    }

    start() {
        this.server = http.createServer();
        this.wss = new WebSocket.Server({ server: this.server });

        this.wss.on('connection', (socket, request) => {
            this.handleConnection(socket, request);
        });

        this.server.listen(this.port, () => {
            console.log(`Chat server started on port ${this.port}`);
            console.log(`WebSocket endpoint: ws://localhost:${this.port}`);
            this.emit('serverStarted', { port: this.port });
        });

        process.on('SIGTERM', () => this.shutdown());
        process.on('SIGINT', () => this.shutdown());
    }

    handleConnection(socket, request) {
        const clientIP = request.socket.remoteAddress;

        if (this.bannedIPs.has(clientIP)) {
            socket.close(1008, 'IP banned');
            return;
        }

        console.log(`New connection from ${clientIP}`);

        let user = null;
        let isAuthenticated = false;

        socket.on('message', (data) => {
            try {
                const message = JSON.parse(data.toString());
                this.handleMessage(socket, message, user, clientIP);
            } catch (error) {
                this.sendError(socket, 'Invalid JSON format');
            }
        });

        socket.on('close', (code, reason) => {
            if (user) {
                this.handleUserDisconnect(user);
                console.log(`User ${user.username} disconnected (${code}: ${reason})`);
            }
        });

        socket.on('error', (error) => {
            console.error('WebSocket error:', error);
        });

        this.sendMessage(socket, {
            type: 'welcome',
            data: {
                message: 'Welcome to the chat server! Please authenticate.',
                availableRooms: Array.from(this.rooms.keys()),
                serverTime: new Date()
            }
        });
    }

    handleMessage(socket, message, user, clientIP) {
        if (this.isRateLimited(clientIP)) {
            this.sendError(socket, 'Rate limit exceeded. Please slow down.');
            return;
        }

        switch (message.type) {
            case 'auth':
                user = this.handleAuthentication(socket, message.data, clientIP);
                break;

            case 'chat':
                if (user) this.handleChatMessage(socket, message.data, user);
                else this.sendError(socket, 'Not authenticated');
                break;

            case 'join_room':
                if (user) this.handleJoinRoom(socket, message.data, user);
                else this.sendError(socket, 'Not authenticated');
                break;

            case 'leave_room':
                if (user) this.handleLeaveRoom(socket, message.data, user);
                else this.sendError(socket, 'Not authenticated');
                break;

            case 'get_users':
                if (user) this.handleGetUsers(socket, user);
                else this.sendError(socket, 'Not authenticated');
                break;

            case 'get_rooms':
                if (user) this.handleGetRooms(socket);
                else this.sendError(socket, 'Not authenticated');
                break;

            case 'private_message':
                if (user) this.handlePrivateMessage(socket, message.data, user);
                else this.sendError(socket, 'Not authenticated');
                break;

            case 'status_update':
                if (user) this.handleStatusUpdate(socket, message.data, user);
                else this.sendError(socket, 'Not authenticated');
                break;

            default:
                this.sendError(socket, 'Unknown message type');
        }
    }

    handleAuthentication(socket, data, clientIP) {
        const { username } = data;

        if (!username || username.length < 2 || username.length > 20) {
            this.sendError(socket, 'Username must be 2-20 characters');
            return null;
        }

        const existingUser = Array.from(this.users.values())
            .find(u => u.username.toLowerCase() === username.toLowerCase());

        if (existingUser) {
            this.sendError(socket, 'Username already taken');
            return null;
        }

        const userId = crypto.randomUUID();
        const user = new User(userId, username, socket);
        this.users.set(userId, user);

        const generalRoom = this.rooms.get('general');
        const joinMessage = generalRoom.addUser(user);

        this.sendMessage(socket, {
            type: 'auth_success',
            data: {
                user: user.toJSON(),
                currentRoom: 'general',
                recentMessages: generalRoom.getRecentMessages()
            }
        });

        this.broadcastToRoom('general', joinMessage, userId);

        console.log(`User ${username} authenticated and joined general room`);
        this.emit('userJoined', user);

        return user;
    }

    handleChatMessage(socket, data, user) {
        const { content, room = user.currentRoom } = data;

        if (!content || content.trim().length === 0) {
            this.sendError(socket, 'Message cannot be empty');
            return;
        }

        if (content.length > 500) {
            this.sendError(socket, 'Message too long (max 500 characters)');
            return;
        }

        const chatRoom = this.rooms.get(room);
        if (!chatRoom) {
            this.sendError(socket, 'Room does not exist');
            return;
        }

        if (!chatRoom.users.has(user.id)) {
            this.sendError(socket, 'You are not in this room');
            return;
        }

        const message = Message.createChatMessage(content, user.id, user.username, room);
        chatRoom.addMessage(message);

        user.updateActivity();

        this.broadcastToRoom(room, message);

        this.emit('messageReceived', { message, user, room });
    }

    handleJoinRoom(socket, data, user) {
        const { roomName } = data;

        if (!this.rooms.has(roomName)) {
            this.sendError(socket, 'Room does not exist');
            return;
        }

        const oldRoom = this.rooms.get(user.currentRoom);
        const newRoom = this.rooms.get(roomName);

        try {
            if (oldRoom) {
                const leaveMessage = oldRoom.removeUser(user.id);
                if (leaveMessage) {
                    this.broadcastToRoom(user.currentRoom, leaveMessage, user.id);
                }
            }

            const joinMessage = newRoom.addUser(user);

            this.sendMessage(socket, {
                type: 'room_joined',
                data: {
                    roomName,
                    userList: newRoom.getUserList(),
                    recentMessages: newRoom.getRecentMessages()
                }
            });

            this.broadcastToRoom(roomName, joinMessage, user.id);

            console.log(`User ${user.username} moved from ${oldRoom?.name || 'none'} to ${roomName}`);

        } catch (error) {
            this.sendError(socket, error.message);
        }
    }

    handleLeaveRoom(socket, data, user) {
        const room = this.rooms.get(user.currentRoom);
        if (room) {
            const leaveMessage = room.removeUser(user.id);
            if (leaveMessage) {
                this.broadcastToRoom(user.currentRoom, leaveMessage, user.id);
            }

            user.currentRoom = null;

            this.sendMessage(socket, {
                type: 'room_left',
                data: { roomName: room.name }
            });
        }
    }

    handleGetUsers(socket, user) {
        const room = this.rooms.get(user.currentRoom);
        if (room) {
            this.sendMessage(socket, {
                type: 'user_list',
                data: {
                    users: room.getUserList(),
                    roomName: room.name
                }
            });
        }
    }

    handleGetRooms(socket) {
        const roomStats = Array.from(this.rooms.values()).map(room => room.getStats());

        this.sendMessage(socket, {
            type: 'room_list',
            data: { rooms: roomStats }
        });
    }

    handlePrivateMessage(socket, data, user) {
        const { targetUserId, content } = data;

        const targetUser = this.users.get(targetUserId);
        if (!targetUser) {
            this.sendError(socket, 'User not found');
            return;
        }

        const message = {
            type: 'private_message',
            data: {
                from: user.username,
                fromId: user.id,
                content: content.trim(),
                timestamp: new Date()
            }
        };

        this.sendMessage(targetUser.socket, message);
        this.sendMessage(socket, {
            type: 'private_message_sent',
            data: {
                to: targetUser.username,
                content: content.trim(),
                timestamp: new Date()
            }
        });
    }

    handleStatusUpdate(socket, data, user) {
        const { status } = data;
        const validStatuses = ['online', 'away', 'busy', 'invisible'];

        if (!validStatuses.includes(status)) {
            this.sendError(socket, 'Invalid status');
            return;
        }

        user.setStatus(status);

        if (user.currentRoom) {
            this.broadcastToRoom(user.currentRoom, {
                type: 'user_status_update',
                data: {
                    userId: user.id,
                    username: user.username,
                    status: status
                }
            }, user.id);
        }
    }

    handleUserDisconnect(user) {
        if (user.currentRoom) {
            const room = this.rooms.get(user.currentRoom);
            if (room) {
                const leaveMessage = room.removeUser(user.id);
                if (leaveMessage) {
                    this.broadcastToRoom(user.currentRoom, leaveMessage, user.id);
                }
            }
        }

        this.users.delete(user.id);
        this.emit('userLeft', user);
    }

    broadcastToRoom(roomName, message, excludeUserId = null) {
        const room = this.rooms.get(roomName);
        if (!room) return;

        for (const user of room.users.values()) {
            if (excludeUserId && user.id === excludeUserId) continue;

            try {
                this.sendMessage(user.socket, message);
            } catch (error) {
                console.error(`Failed to send message to user ${user.username}:`, error);
            }
        }
    }

    sendMessage(socket, message) {
        if (socket.readyState === WebSocket.OPEN) {
            socket.send(JSON.stringify(message));
        }
    }

    sendError(socket, errorMessage) {
        this.sendMessage(socket, {
            type: 'error',
            data: { message: errorMessage, timestamp: new Date() }
        });
    }

    createRoom(roomName, maxUsers = 100, isPrivate = false) {
        if (this.rooms.has(roomName)) {
            throw new Error('Room already exists');
        }

        const room = new ChatRoom(roomName, maxUsers);
        room.isPrivate = isPrivate;
        this.rooms.set(roomName, room);

        console.log(`Room created: ${roomName} (max: ${maxUsers}, private: ${isPrivate})`);
        return room;
    }

    deleteRoom(roomName) {
        const room = this.rooms.get(roomName);
        if (!room) return false;

        const generalRoom = this.rooms.get('general');
        for (const user of room.users.values()) {
            try {
                generalRoom.addUser(user);
                this.sendMessage(user.socket, {
                    type: 'room_deleted',
                    data: {
                        deletedRoom: roomName,
                        movedTo: 'general',
                        message: `Room ${roomName} was deleted. You were moved to general.`
                    }
                });
            } catch (error) {
                console.error(`Failed to move user ${user.username} to general room:`, error);
            }
        }

        this.rooms.delete(roomName);
        console.log(`Room deleted: ${roomName}`);
        return true;
    }

    getServerStats() {
        return {
            totalUsers: this.users.size,
            totalRooms: this.rooms.size,
            totalMessages: Array.from(this.rooms.values())
                .reduce((sum, room) => sum + room.messages.length, 0),
            bannedIPs: this.bannedIPs.size,
            uptime: process.uptime(),
            memoryUsage: process.memoryUsage()
        };
    }

    shutdown() {
        console.log('Shutting down chat server...');

        const shutdownMessage = {
            type: 'server_shutdown',
            data: {
                message: 'Server is shutting down. Thank you for using our chat service!',
                timestamp: new Date()
            }
        };

        for (const user of this.users.values()) {
            try {
                this.sendMessage(user.socket, shutdownMessage);
                user.socket.close(1001, 'Server shutdown');
            } catch (error) {
                console.error(`Error notifying user ${user.username}:`, error);
            }
        }

        if (this.wss) {
            this.wss.close();
        }

        if (this.server) {
            this.server.close();
        }

        console.log('Chat server shutdown complete');
        process.exit(0);
    }
}

if (require.main === module) {
    const server = new ChatServer(8080);

    server.on('userJoined', (user) => {
        console.log(`👋 User joined: ${user.username}`);
    });

    server.on('userLeft', (user) => {
        console.log(`👋 User left: ${user.username}`);
    });

    server.on('messageReceived', ({ message, user, room }) => {
        console.log(`💬 [${room}] ${user.username}: ${message.data.content}`);
    });

    server.on('serverStarted', ({ port }) => {
        console.log(`🚀 Chat server is ready on port ${port}`);
        console.log(`📊 Server stats available at /stats`);

        setInterval(() => {
            const stats = server.getServerStats();
            console.log(`📊 Stats: ${stats.totalUsers} users, ${stats.totalRooms} rooms, ${stats.totalMessages} messages`);
        }, 30000);
    });

    server.start();
}

module.exports = { ChatServer, User, Message, ChatRoom }; 