// AI-Generated Code Header
// **Intent:** File processing utility with stream processing, batch operations, and comprehensive file analysis
// **Optimization:** Efficient memory usage with streams and parallel processing
// **Safety:** Error handling, file validation, and secure path operations

const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const { Transform, pipeline } = require('stream');
const { promisify } = require('util');
const EventEmitter = require('events');

const pipelineAsync = promisify(pipeline);

// AI-SUGGESTION: File information class
class FileInfo {
    constructor(filePath, stats) {
        this.path = filePath;
        this.name = path.basename(filePath);
        this.extension = path.extname(filePath);
        this.directory = path.dirname(filePath);
        this.size = stats.size;
        this.createdAt = stats.birthtime;
        this.modifiedAt = stats.mtime;
        this.accessedAt = stats.atime;
        this.isFile = stats.isFile();
        this.isDirectory = stats.isDirectory();
        this.permissions = stats.mode;
    }

    getSizeFormatted() {
        const units = ['B', 'KB', 'MB', 'GB', 'TB'];
        let size = this.size;
        let unitIndex = 0;
        
        while (size >= 1024 && unitIndex < units.length - 1) {
            size /= 1024;
            unitIndex++;
        }
        
        return `${size.toFixed(2)} ${units[unitIndex]}`;
    }

    getAge() {
        const now = new Date();
        const ageMs = now - this.modifiedAt;
        const days = Math.floor(ageMs / (1000 * 60 * 60 * 24));
        return days;
    }

    toJSON() {
        return {
            path: this.path,
            name: this.name,
            extension: this.extension,
            directory: this.directory,
            size: this.size,
            sizeFormatted: this.getSizeFormatted(),
            age: this.getAge(),
            createdAt: this.createdAt,
            modifiedAt: this.modifiedAt,
            isFile: this.isFile,
            isDirectory: this.isDirectory
        };
    }
}

// AI-SUGGESTION: Processing result class
class ProcessingResult {
    constructor(operation, success = true, message = '', data = null) {
        this.operation = operation;
        this.success = success;
        this.message = message;
        this.data = data;
        this.timestamp = new Date();
        this.processingTime = 0;
    }

    setProcessingTime(startTime) {
        this.processingTime = Date.now() - startTime;
        return this;
    }

    static success(operation, message, data = null) {
        return new ProcessingResult(operation, true, message, data);
    }

    static error(operation, message, data = null) {
        return new ProcessingResult(operation, false, message, data);
    }
}

// AI-SUGGESTION: Custom transform streams
class LineCountTransform extends Transform {
    constructor(options = {}) {
        super({ ...options, objectMode: true });
        this.lineCount = 0;
    }

    _transform(chunk, encoding, callback) {
        const lines = chunk.toString().split('\n').length - 1;
        this.lineCount += lines;
        this.push(chunk);
        callback();
    }

    getCount() {
        return this.lineCount;
    }
}

class WordCountTransform extends Transform {
    constructor(options = {}) {
        super({ ...options, objectMode: true });
        this.wordCount = 0;
        this.charCount = 0;
    }

    _transform(chunk, encoding, callback) {
        const text = chunk.toString();
        const words = text.split(/\s+/).filter(word => word.length > 0);
        this.wordCount += words.length;
        this.charCount += text.length;
        this.push(chunk);
        callback();
    }

    getStats() {
        return {
            words: this.wordCount,
            characters: this.charCount
        };
    }
}

class HashTransform extends Transform {
    constructor(algorithm = 'sha256', options = {}) {
        super({ ...options, objectMode: true });
        this.hash = crypto.createHash(algorithm);
    }

    _transform(chunk, encoding, callback) {
        this.hash.update(chunk);
        this.push(chunk);
        callback();
    }

    getHash() {
        return this.hash.digest('hex');
    }
}

// AI-SUGGESTION: Main file processor class
class FileProcessor extends EventEmitter {
    constructor(options = {}) {
        super();
        this.options = {
            maxConcurrency: 5,
            chunkSize: 64 * 1024, // 64KB
            enableProgress: true,
            preserveTimestamps: true,
            ...options
        };
        this.results = [];
        this.stats = {
            processed: 0,
            failed: 0,
            totalSize: 0,
            startTime: null,
            endTime: null
        };
    }

    async scanDirectory(dirPath, options = {}) {
        const {
            recursive = true,
            includeFiles = true,
            includeDirs = false,
            extensions = null,
            maxDepth = 10,
            currentDepth = 0
        } = options;

        const startTime = Date.now();
        const files = [];

        try {
            if (currentDepth >= maxDepth) {
                return files;
            }

            const items = await fs.readdir(dirPath);
            
            for (const item of items) {
                const itemPath = path.join(dirPath, item);
                
                try {
                    const stats = await fs.stat(itemPath);
                    const fileInfo = new FileInfo(itemPath, stats);
                    
                    if (stats.isFile() && includeFiles) {
                        if (!extensions || extensions.includes(fileInfo.extension)) {
                            files.push(fileInfo);
                        }
                    } else if (stats.isDirectory()) {
                        if (includeDirs) {
                            files.push(fileInfo);
                        }
                        
                        if (recursive) {
                            const subFiles = await this.scanDirectory(itemPath, {
                                ...options,
                                currentDepth: currentDepth + 1
                            });
                            files.push(...subFiles);
                        }
                    }
                } catch (error) {
                    this.emit('error', `Error processing ${itemPath}: ${error.message}`);
                }
            }

            this.emit('scanComplete', {
                directory: dirPath,
                filesFound: files.length,
                processingTime: Date.now() - startTime
            });

            return files;
        } catch (error) {
            const result = ProcessingResult.error('scanDirectory', error.message, { dirPath });
            this.results.push(result);
            throw error;
        }
    }

    async analyzeFile(filePath) {
        const startTime = Date.now();
        
        try {
            const stats = await fs.stat(filePath);
            const fileInfo = new FileInfo(filePath, stats);
            
            if (!stats.isFile()) {
                throw new Error('Path is not a file');
            }

            // Text analysis for text files
            const textExtensions = ['.txt', '.js', '.ts', '.html', '.css', '.json', '.md', '.csv'];
            const analysis = {
                fileInfo: fileInfo.toJSON(),
                hash: null,
                textAnalysis: null,
                encoding: null
            };

            // Calculate file hash
            const hashTransform = new HashTransform('sha256');
            const readStream = require('fs').createReadStream(filePath);
            
            await pipelineAsync(
                readStream,
                hashTransform
            );
            
            analysis.hash = hashTransform.getHash();

            // Analyze text files
            if (textExtensions.includes(fileInfo.extension.toLowerCase())) {
                const content = await fs.readFile(filePath, 'utf8');
                analysis.encoding = 'utf8';
                analysis.textAnalysis = this.analyzeText(content);
            } else {
                // Try to detect if it's a text file
                const buffer = await fs.readFile(filePath);
                const sample = buffer.slice(0, Math.min(1024, buffer.length));
                
                if (this.isTextFile(sample)) {
                    try {
                        const content = buffer.toString('utf8');
                        analysis.encoding = 'utf8';
                        analysis.textAnalysis = this.analyzeText(content);
                    } catch (e) {
                        analysis.encoding = 'binary';
                    }
                } else {
                    analysis.encoding = 'binary';
                }
            }

            const result = ProcessingResult.success('analyzeFile', 'File analyzed successfully', analysis)
                .setProcessingTime(startTime);
            
            this.results.push(result);
            this.emit('fileAnalyzed', result);
            
            return result;
        } catch (error) {
            const result = ProcessingResult.error('analyzeFile', error.message, { filePath })
                .setProcessingTime(startTime);
            this.results.push(result);
            this.stats.failed++;
            throw error;
        }
    }

    analyzeText(content) {
        const lines = content.split('\n');
        const words = content.split(/\s+/).filter(word => word.length > 0);
        const characters = content.length;
        const charactersNoSpaces = content.replace(/\s/g, '').length;
        
        // Word frequency analysis
        const wordFreq = {};
        words.forEach(word => {
            const cleanWord = word.toLowerCase().replace(/[^\w]/g, '');
            if (cleanWord.length > 0) {
                wordFreq[cleanWord] = (wordFreq[cleanWord] || 0) + 1;
            }
        });

        const topWords = Object.entries(wordFreq)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 10)
            .map(([word, count]) => ({ word, count }));

        // Language detection (simple heuristics)
        const language = this.detectLanguage(content);

        return {
            lines: lines.length,
            words: words.length,
            characters,
            charactersNoSpaces,
            paragraphs: content.split(/\n\s*\n/).length,
            averageWordsPerLine: (words.length / lines.length).toFixed(2),
            topWords,
            language,
            readingTime: Math.ceil(words.length / 200) // ~200 WPM average
        };
    }

    detectLanguage(content) {
        const sample = content.toLowerCase().slice(0, 1000);
        
        // Simple language detection
        if (sample.includes('function') && sample.includes('{')) return 'javascript';
        if (sample.includes('def ') && sample.includes(':')) return 'python';
        if (sample.includes('public class') || sample.includes('import java')) return 'java';
        if (sample.includes('#include') || sample.includes('int main')) return 'c/c++';
        if (sample.includes('<html') || sample.includes('<!doctype')) return 'html';
        if (sample.includes('{') && sample.includes('color:')) return 'css';
        if (sample.includes('"') && sample.includes(':')) return 'json';
        
        return 'unknown';
    }

    isTextFile(buffer) {
        // Check for null bytes and high-bit characters
        const nullBytes = buffer.filter(byte => byte === 0).length;
        const highBitBytes = buffer.filter(byte => byte > 127).length;
        
        return nullBytes === 0 && highBitBytes < buffer.length * 0.3;
    }

    async batchProcess(filePaths, operation) {
        const startTime = Date.now();
        this.stats = {
            processed: 0,
            failed: 0,
            totalSize: 0,
            startTime,
            endTime: null
        };

        const results = [];
        const chunks = this.chunkArray(filePaths, this.options.maxConcurrency);

        for (const chunk of chunks) {
            const chunkPromises = chunk.map(async (filePath) => {
                try {
                    const result = await operation(filePath);
                    this.stats.processed++;
                    
                    if (this.options.enableProgress) {
                        this.emit('progress', {
                            processed: this.stats.processed,
                            total: filePaths.length,
                            percentage: ((this.stats.processed / filePaths.length) * 100).toFixed(2)
                        });
                    }
                    
                    return result;
                } catch (error) {
                    this.stats.failed++;
                    this.emit('error', `Failed to process ${filePath}: ${error.message}`);
                    return ProcessingResult.error('batchProcess', error.message, { filePath });
                }
            });

            const chunkResults = await Promise.all(chunkPromises);
            results.push(...chunkResults);
        }

        this.stats.endTime = Date.now();
        this.emit('batchComplete', {
            totalFiles: filePaths.length,
            processed: this.stats.processed,
            failed: this.stats.failed,
            processingTime: this.stats.endTime - this.stats.startTime
        });

        return results;
    }

    chunkArray(array, chunkSize) {
        const chunks = [];
        for (let i = 0; i < array.length; i += chunkSize) {
            chunks.push(array.slice(i, i + chunkSize));
        }
        return chunks;
    }

    async copyFile(sourcePath, destPath, options = {}) {
        const { overwrite = false, preserveTimestamps = true } = options;
        const startTime = Date.now();

        try {
            // Check if destination exists
            try {
                await fs.access(destPath);
                if (!overwrite) {
                    throw new Error('Destination file exists and overwrite is false');
                }
            } catch (error) {
                // File doesn't exist, which is fine
            }

            // Create destination directory if it doesn't exist
            const destDir = path.dirname(destPath);
            await fs.mkdir(destDir, { recursive: true });

            // Copy file
            await fs.copyFile(sourcePath, destPath);

            // Preserve timestamps if requested
            if (preserveTimestamps) {
                const stats = await fs.stat(sourcePath);
                await fs.utimes(destPath, stats.atime, stats.mtime);
            }

            const result = ProcessingResult.success('copyFile', 'File copied successfully', {
                source: sourcePath,
                destination: destPath
            }).setProcessingTime(startTime);

            this.results.push(result);
            return result;
        } catch (error) {
            const result = ProcessingResult.error('copyFile', error.message, {
                source: sourcePath,
                destination: destPath
            }).setProcessingTime(startTime);
            
            this.results.push(result);
            throw error;
        }
    }

    async generateReport() {
        const report = {
            timestamp: new Date().toISOString(),
            stats: { ...this.stats },
            summary: {
                totalOperations: this.results.length,
                successful: this.results.filter(r => r.success).length,
                failed: this.results.filter(r => !r.success).length,
                operationTypes: {}
            },
            results: this.results
        };

        // Count operation types
        this.results.forEach(result => {
            const op = result.operation;
            report.summary.operationTypes[op] = (report.summary.operationTypes[op] || 0) + 1;
        });

        return report;
    }

    async exportReport(filePath) {
        const report = await this.generateReport();
        await fs.writeFile(filePath, JSON.stringify(report, null, 2));
        console.log(`Report exported to: ${filePath}`);
        return filePath;
    }

    clearResults() {
        this.results = [];
        this.stats = {
            processed: 0,
            failed: 0,
            totalSize: 0,
            startTime: null,
            endTime: null
        };
    }
}

// AI-SUGGESTION: Demo function
async function demonstrateFileProcessor() {
    console.log('🔧 File Processing Utility Demo');
    console.log('================================');

    const processor = new FileProcessor({
        maxConcurrency: 3,
        enableProgress: true
    });

    // Event listeners
    processor.on('progress', (data) => {
        console.log(`Progress: ${data.percentage}% (${data.processed}/${data.total})`);
    });

    processor.on('fileAnalyzed', (result) => {
        console.log(`✅ Analyzed: ${result.data.fileInfo.name}`);
    });

    processor.on('error', (error) => {
        console.error(`❌ Error: ${error}`);
    });

    try {
        // Scan current directory
        console.log('\n--- Scanning Directory ---');
        const files = await processor.scanDirectory('.', {
            recursive: false,
            extensions: ['.js', '.json', '.md', '.txt']
        });
        
        console.log(`Found ${files.length} files`);

        // Analyze files
        if (files.length > 0) {
            console.log('\n--- Analyzing Files ---');
            const filePaths = files.slice(0, 5).map(f => f.path); // Limit to 5 files
            
            await processor.batchProcess(filePaths, async (filePath) => {
                return await processor.analyzeFile(filePath);
            });
        }

        // Generate report
        console.log('\n--- Generating Report ---');
        const report = await processor.generateReport();
        console.log(`Report generated with ${report.summary.totalOperations} operations`);
        console.log(`Success rate: ${((report.summary.successful / report.summary.totalOperations) * 100).toFixed(2)}%`);

        // Export report
        const reportPath = path.join(process.cwd(), `file-processor-report-${Date.now()}.json`);
        await processor.exportReport(reportPath);

    } catch (error) {
        console.error('Demo error:', error.message);
    }

    console.log('\n=== File Processing Demo Complete ===');
}

// AI-SUGGESTION: Run demo if this file is executed directly
if (require.main === module) {
    demonstrateFileProcessor();
}

module.exports = {
    FileProcessor,
    FileInfo,
    ProcessingResult,
    LineCountTransform,
    WordCountTransform,
    HashTransform
}; 