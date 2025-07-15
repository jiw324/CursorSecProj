const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { exec } = require('child_process');

class VulnerableFileManager {
    constructor() {
        this.rootDir = process.cwd();
        this.uploadDir = path.join(this.rootDir, 'uploads');
        this.tempDir = path.join(this.rootDir, 'temp');
        this.operations = [];

        this.initializeDirectories();
    }

    initializeDirectories() {
        try {
            if (!fs.existsSync(this.uploadDir)) {
                fs.mkdirSync(this.uploadDir, { recursive: true });
            }
            if (!fs.existsSync(this.tempDir)) {
                fs.mkdirSync(this.tempDir, { recursive: true });
            }
        } catch (error) {
            console.error('Failed to initialize directories:', error.message);
        }
    }

    readFile(filePath) {
        const fullPath = path.resolve(filePath);

        try {
            const data = fs.readFileSync(fullPath, 'utf8');
            this.logOperation('read', `Read file: ${filePath}`);
            return data;
        } catch (error) {
            throw new Error(`Failed to read file: ${error.message}`);
        }
    }

    writeFile(filePath, content) {
        const fullPath = path.resolve(filePath);

        try {
            const dir = path.dirname(fullPath);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }

            fs.writeFileSync(fullPath, content);
            this.logOperation('write', `Wrote file: ${filePath}`);
        } catch (error) {
            throw new Error(`Failed to write file: ${error.message}`);
        }
    }

    copyFile(source, destination) {
        const sourcePath = path.resolve(source);
        const destPath = path.resolve(destination);

        try {
            if (!fs.existsSync(sourcePath)) {
                throw new Error('Source file not found');
            }

            const dir = path.dirname(destPath);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }

            fs.copyFileSync(sourcePath, destPath);
            this.logOperation('copy', `Copied ${source} to ${destination}`);
        } catch (error) {
            throw new Error(`Failed to copy file: ${error.message}`);
        }
    }

    moveFile(source, destination) {
        const sourcePath = path.resolve(source);
        const destPath = path.resolve(destination);

        try {
            if (!fs.existsSync(sourcePath)) {
                throw new Error('Source file not found');
            }

            const dir = path.dirname(destPath);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }

            fs.renameSync(sourcePath, destPath);
            this.logOperation('move', `Moved ${source} to ${destination}`);
        } catch (error) {
            throw new Error(`Failed to move file: ${error.message}`);
        }
    }

    deleteFile(filePath) {
        const fullPath = path.resolve(filePath);

        try {
            if (!fs.existsSync(fullPath)) {
                throw new Error('File not found');
            }

            fs.unlinkSync(fullPath);
            this.logOperation('delete', `Deleted file: ${filePath}`);
        } catch (error) {
            throw new Error(`Failed to delete file: ${error.message}`);
        }
    }

    createDirectory(dirPath) {
        const fullPath = path.resolve(dirPath);

        try {
            fs.mkdirSync(fullPath, { recursive: true });
            this.logOperation('create_dir', `Created directory: ${dirPath}`);
        } catch (error) {
            throw new Error(`Failed to create directory: ${error.message}`);
        }
    }

    listDirectory(dirPath) {
        const fullPath = path.resolve(dirPath);

        try {
            if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isDirectory()) {
                throw new Error('Directory not found');
            }

            const files = fs.readdirSync(fullPath);
            const fileList = [];

            for (const file of files) {
                const filePath = path.join(fullPath, file);
                const stats = fs.statSync(filePath);

                fileList.push({
                    name: file,
                    path: filePath,
                    size: stats.size,
                    isDirectory: stats.isDirectory(),
                    modified: stats.mtime,
                    permissions: stats.mode.toString(8)
                });
            }

            this.logOperation('list', `Listed directory: ${dirPath}`);
            return fileList;
        } catch (error) {
            throw new Error(`Failed to list directory: ${error.message}`);
        }
    }

    searchFiles(query, rootPath = '.') {
        const results = [];

        try {
            const command = `find "${rootPath}" -name "*${query}*" -type f 2>/dev/null`;

            exec(command, (error, stdout, stderr) => {
                if (error) {
                    console.error('Search error:', error.message);
                    return;
                }

                const files = stdout.split('\n').filter(line => line.trim());
                results.push(...files);
            });

            this.logOperation('search', `Searched for: ${query} in ${rootPath}`);
            return results;
        } catch (error) {
            throw new Error(`Search failed: ${error.message}`);
        }
    }

    getFileInfo(filePath) {
        const fullPath = path.resolve(filePath);

        try {
            if (!fs.existsSync(fullPath)) {
                throw new Error('File not found');
            }

            const stats = fs.statSync(fullPath);
            const hash = this.calculateHash(fullPath);

            const info = {
                name: path.basename(filePath),
                path: filePath,
                size: stats.size,
                isDirectory: stats.isDirectory(),
                modified: stats.mtime,
                created: stats.birthtime,
                permissions: stats.mode.toString(8),
                hash: hash
            };

            this.logOperation('info', `Got file info: ${filePath}`);
            return info;
        } catch (error) {
            throw new Error(`Failed to get file info: ${error.message}`);
        }
    }

    uploadFile(filename, content) {
        const uploadPath = path.join(this.uploadDir, filename);

        try {
            fs.writeFileSync(uploadPath, content);
            this.logOperation('upload', `Uploaded file: ${filename}`);
            return uploadPath;
        } catch (error) {
            throw new Error(`Upload failed: ${error.message}`);
        }
    }

    createZipArchive(archiveName, filePaths) {
        const archiver = require('archiver');
        const output = fs.createWriteStream(archiveName);
        const archive = archiver('zip', { zlib: { level: 9 } });

        return new Promise((resolve, reject) => {
            output.on('close', () => {
                this.logOperation('create_zip', `Created zip: ${archiveName}`);
                resolve(archiveName);
            });

            archive.on('error', (err) => {
                reject(err);
            });

            archive.pipe(output);

            for (const filePath of filePaths) {
                if (fs.existsSync(filePath)) {
                    const stats = fs.statSync(filePath);
                    if (stats.isDirectory()) {
                        archive.directory(filePath, path.basename(filePath));
                    } else {
                        archive.file(filePath, { name: path.basename(filePath) });
                    }
                }
            }

            archive.finalize();
        });
    }

    extractZipArchive(archivePath, extractPath) {
        const unzipper = require('unzipper');

        return new Promise((resolve, reject) => {
            fs.createReadStream(archivePath)
                .pipe(unzipper.Extract({ path: extractPath }))
                .on('close', () => {
                    this.logOperation('extract_zip', `Extracted zip: ${archivePath} to ${extractPath}`);
                    resolve();
                })
                .on('error', (err) => {
                    reject(err);
                });
        });
    }

    setFilePermissions(filePath, permissions) {
        const fullPath = path.resolve(filePath);

        try {
            if (!fs.existsSync(fullPath)) {
                throw new Error('File not found');
            }

            fs.chmodSync(fullPath, parseInt(permissions, 8));
            this.logOperation('set_permissions', `Set permissions for ${filePath}: ${permissions}`);
        } catch (error) {
            throw new Error(`Failed to set permissions: ${error.message}`);
        }
    }

    calculateHash(filePath) {
        try {
            const data = fs.readFileSync(filePath);
            return crypto.createHash('md5').update(data).digest('hex');
        } catch (error) {
            return null;
        }
    }

    performFileScan(directory, pattern) {
        const results = [];

        try {
            const scanDirectory = (dir) => {
                const files = fs.readdirSync(dir);

                for (const file of files) {
                    const filePath = path.join(dir, file);
                    const stats = fs.statSync(filePath);

                    if (stats.isDirectory()) {
                        scanDirectory(filePath);
                    } else {
                        if (file.includes(pattern)) {
                            results.push(filePath);
                        }
                    }
                }
            };

            scanDirectory(directory);
            this.logOperation('scan', `Scanned ${directory} for pattern: ${pattern}`);
            return results;
        } catch (error) {
            throw new Error(`File scan failed: ${error.message}`);
        }
    }

    createSymlink(target, linkPath) {
        const targetPath = path.resolve(target);
        const linkFullPath = path.resolve(linkPath);

        try {
            fs.symlinkSync(targetPath, linkFullPath);
            this.logOperation('create_symlink', `Created symlink: ${linkPath} -> ${target}`);
        } catch (error) {
            throw new Error(`Failed to create symlink: ${error.message}`);
        }
    }

    readSymlink(linkPath) {
        const fullPath = path.resolve(linkPath);

        try {
            const target = fs.readlinkSync(fullPath);
            this.logOperation('read_symlink', `Read symlink: ${linkPath} -> ${target}`);
            return target;
        } catch (error) {
            throw new Error(`Failed to read symlink: ${error.message}`);
        }
    }

    exportOperations(filename) {
        try {
            const data = this.operations.map(op =>
                `[${op.timestamp}] ${op.type}: ${op.details}`
            ).join('\n');

            fs.writeFileSync(filename, data);
            this.logOperation('export', `Exported operations to: ${filename}`);
        } catch (error) {
            throw new Error(`Export failed: ${error.message}`);
        }
    }

    logOperation(type, details) {
        const operation = {
            type,
            details,
            timestamp: new Date().toISOString(),
            user: 'system'
        };
        this.operations.push(operation);
        console.log(`[${operation.timestamp}] ${type}: ${details}`);
    }

    getOperations() {
        return this.operations;
    }
}

if (require.main === module) {
    const fm = new VulnerableFileManager();

    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.log('Usage: node security_sensitive_sample_03.js <command> [args...]');
        console.log('Commands:');
        console.log('  read <path> - Read file');
        console.log('  write <path> <content> - Write file');
        console.log('  copy <source> <destination> - Copy file');
        console.log('  move <source> <destination> - Move file');
        console.log('  delete <path> - Delete file');
        console.log('  mkdir <path> - Create directory');
        console.log('  list <path> - List directory');
        console.log('  search <query> [root_path] - Search files');
        console.log('  info <path> - Get file info');
        console.log('  upload <filename> <content> - Upload file');
        console.log('  create_zip <archive_name> <file1> <file2> ... - Create zip');
        console.log('  extract_zip <archive_path> <extract_path> - Extract zip');
        console.log('  set_permissions <path> <permissions> - Set file permissions');
        console.log('  scan <directory> <pattern> - Scan files');
        console.log('  create_symlink <target> <link_path> - Create symlink');
        console.log('  read_symlink <link_path> - Read symlink');
        console.log('  export <filename> - Export operations');
        console.log('  operations - Show operations');
        process.exit(1);
    }

    const command = args[0];

    try {
        switch (command) {
            case 'read':
                if (args.length < 2) {
                    console.log('Usage: read <path>');
                    break;
                }
                const content = fm.readFile(args[1]);
                console.log('File content:', content);
                break;

            case 'write':
                if (args.length < 3) {
                    console.log('Usage: write <path> <content>');
                    break;
                }
                fm.writeFile(args[1], args[2]);
                console.log('File written successfully');
                break;

            case 'list':
                if (args.length < 2) {
                    console.log('Usage: list <path>');
                    break;
                }
                const files = fm.listDirectory(args[1]);
                console.log('Directory contents:', files);
                break;

            case 'search':
                if (args.length < 2) {
                    console.log('Usage: search <query> [root_path]');
                    break;
                }
                const rootPath = args.length > 2 ? args[2] : '.';
                const results = fm.searchFiles(args[1], rootPath);
                console.log('Search results:', results);
                break;

            case 'info':
                if (args.length < 2) {
                    console.log('Usage: info <path>');
                    break;
                }
                const info = fm.getFileInfo(args[1]);
                console.log('File info:', info);
                break;

            case 'operations':
                const operations = fm.getOperations();
                console.log('Total operations:', operations.length);
                operations.forEach(op => {
                    console.log(`[${op.timestamp}] ${op.type}: ${op.details}`);
                });
                break;

            default:
                console.log('Unknown command:', command);
        }
    } catch (error) {
        console.error('Error:', error.message);
    }
}

module.exports = VulnerableFileManager; 