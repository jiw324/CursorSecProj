// AI-Generated Code Header
// **Intent:** Web scraping automation with URL processing, content extraction, and data analysis
// **Optimization:** Efficient request handling with rate limiting and concurrent processing
// **Safety:** Robust error handling, request validation, and respectful scraping practices

const https = require('https');
const http = require('http');
const url = require('url');
const crypto = require('crypto');
const EventEmitter = require('events');

// AI-SUGGESTION: Simple HTML parser for basic content extraction
class SimpleHTMLParser {
    constructor(html) {
        this.html = html;
        this.doc = this.parseHTML(html);
    }

    parseHTML(html) {
        // Simple DOM-like structure for basic parsing
        return {
            content: html,
            getElementById: (id) => this.extractById(id),
            getElementsByTagName: (tag) => this.extractByTag(tag),
            getElementsByClassName: (className) => this.extractByClass(className),
            querySelector: (selector) => this.querySelector(selector),
            querySelectorAll: (selector) => this.querySelectorAll(selector)
        };
    }

    extractById(id) {
        const regex = new RegExp(`<[^>]+id=["']${id}["'][^>]*>([\\s\\S]*?)<\/[^>]+>`, 'i');
        const match = this.html.match(regex);
        return match ? { textContent: this.stripTags(match[1]) } : null;
    }

    extractByTag(tag) {
        const regex = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\/${tag}>`, 'gi');
        const matches = [];
        let match;
        
        while ((match = regex.exec(this.html)) !== null) {
            matches.push({
                textContent: this.stripTags(match[1]),
                innerHTML: match[1],
                outerHTML: match[0]
            });
        }
        
        return matches;
    }

    extractByClass(className) {
        const regex = new RegExp(`<[^>]+class=["'][^"']*${className}[^"']*["'][^>]*>([\\s\\S]*?)<\/[^>]+>`, 'gi');
        const matches = [];
        let match;
        
        while ((match = regex.exec(this.html)) !== null) {
            matches.push({
                textContent: this.stripTags(match[1]),
                innerHTML: match[1]
            });
        }
        
        return matches;
    }

    stripTags(html) {
        return html.replace(/<[^>]*>/g, '').trim();
    }

    extractLinks() {
        const regex = /<a[^>]+href=["']([^"']+)["'][^>]*>([^<]*)<\/a>/gi;
        const links = [];
        let match;
        
        while ((match = regex.exec(this.html)) !== null) {
            links.push({
                href: match[1],
                text: match[2].trim(),
                absolute: this.isAbsoluteURL(match[1])
            });
        }
        
        return links;
    }

    extractImages() {
        const regex = /<img[^>]+src=["']([^"']+)["'][^>]*(?:alt=["']([^"']*)["'])?[^>]*>/gi;
        const images = [];
        let match;
        
        while ((match = regex.exec(this.html)) !== null) {
            images.push({
                src: match[1],
                alt: match[2] || '',
                absolute: this.isAbsoluteURL(match[1])
            });
        }
        
        return images;
    }

    extractMetadata() {
        const metadata = {};
        
        // Title
        const titleMatch = this.html.match(/<title>([^<]*)<\/title>/i);
        if (titleMatch) metadata.title = titleMatch[1].trim();
        
        // Meta tags
        const metaRegex = /<meta[^>]+name=["']([^"']+)["'][^>]+content=["']([^"']+)["'][^>]*>/gi;
        let metaMatch;
        
        while ((metaMatch = metaRegex.exec(this.html)) !== null) {
            metadata[metaMatch[1]] = metaMatch[2];
        }
        
        // Open Graph tags
        const ogRegex = /<meta[^>]+property=["']og:([^"']+)["'][^>]+content=["']([^"']+)["'][^>]*>/gi;
        let ogMatch;
        
        while ((ogMatch = ogRegex.exec(this.html)) !== null) {
            metadata[`og:${ogMatch[1]}`] = ogMatch[2];
        }
        
        return metadata;
    }

    isAbsoluteURL(urlString) {
        return /^https?:\/\//.test(urlString);
    }
}

// AI-SUGGESTION: Scraping result class
class ScrapingResult {
    constructor(url, success = true, data = null, error = null) {
        this.url = url;
        this.success = success;
        this.data = data;
        this.error = error;
        this.timestamp = new Date();
        this.processingTime = 0;
        this.statusCode = null;
        this.headers = {};
        this.redirects = [];
    }

    setProcessingTime(startTime) {
        this.processingTime = Date.now() - startTime;
        return this;
    }

    static success(url, data) {
        return new ScrapingResult(url, true, data);
    }

    static error(url, error) {
        return new ScrapingResult(url, false, null, error);
    }
}

// AI-SUGGESTION: Rate limiter for respectful scraping
class RateLimiter {
    constructor(requestsPerSecond = 1) {
        this.requestsPerSecond = requestsPerSecond;
        this.interval = 1000 / requestsPerSecond;
        this.lastRequestTime = 0;
        this.queue = [];
        this.processing = false;
    }

    async wait() {
        return new Promise((resolve) => {
            this.queue.push(resolve);
            this.processQueue();
        });
    }

    processQueue() {
        if (this.processing || this.queue.length === 0) return;
        
        this.processing = true;
        const now = Date.now();
        const timeSinceLastRequest = now - this.lastRequestTime;
        const delay = Math.max(0, this.interval - timeSinceLastRequest);
        
        setTimeout(() => {
            const resolve = this.queue.shift();
            this.lastRequestTime = Date.now();
            this.processing = false;
            resolve();
            
            if (this.queue.length > 0) {
                this.processQueue();
            }
        }, delay);
    }

    setRate(requestsPerSecond) {
        this.requestsPerSecond = requestsPerSecond;
        this.interval = 1000 / requestsPerSecond;
    }
}

// AI-SUGGESTION: Main web scraper class
class WebScraperAutomation extends EventEmitter {
    constructor(options = {}) {
        super();
        this.options = {
            maxConcurrent: 5,
            timeout: 30000,
            retries: 3,
            retryDelay: 1000,
            userAgent: 'Mozilla/5.0 (compatible; WebScraperBot/1.0)',
            respectRobots: true,
            rateLimitRPS: 1,
            maxRedirects: 5,
            ...options
        };
        
        this.rateLimiter = new RateLimiter(this.options.rateLimitRPS);
        this.results = new Map();
        this.stats = {
            requested: 0,
            successful: 0,
            failed: 0,
            startTime: null,
            endTime: null
        };
        this.activeRequests = 0;
        this.robotsCache = new Map();
    }

    async scrapeURL(urlString, options = {}) {
        const startTime = Date.now();
        
        try {
            // Validate URL
            const parsedURL = new URL(urlString);
            
            // Check robots.txt if enabled
            if (this.options.respectRobots) {
                const allowed = await this.checkRobotsTxt(parsedURL);
                if (!allowed) {
                    throw new Error('Blocked by robots.txt');
                }
            }
            
            // Rate limiting
            await this.rateLimiter.wait();
            
            // Make HTTP request
            const response = await this.makeRequest(urlString, options);
            
            // Parse content
            const parser = new SimpleHTMLParser(response.body);
            const extractedData = this.extractData(parser, options.extractors || {});
            
            const result = ScrapingResult.success(urlString, {
                statusCode: response.statusCode,
                headers: response.headers,
                contentLength: response.body.length,
                contentType: response.headers['content-type'] || 'unknown',
                extractedData,
                metadata: parser.extractMetadata(),
                links: parser.extractLinks(),
                images: parser.extractImages(),
                processingTime: Date.now() - startTime
            }).setProcessingTime(startTime);
            
            result.statusCode = response.statusCode;
            result.headers = response.headers;
            
            this.results.set(urlString, result);
            this.stats.successful++;
            this.emit('scraped', result);
            
            return result;
            
        } catch (error) {
            const result = ScrapingResult.error(urlString, error.message)
                .setProcessingTime(startTime);
            
            this.results.set(urlString, result);
            this.stats.failed++;
            this.emit('error', { url: urlString, error: error.message });
            
            throw error;
        }
    }

    async makeRequest(urlString, options = {}) {
        return new Promise((resolve, reject) => {
            const parsedURL = new URL(urlString);
            const isHTTPS = parsedURL.protocol === 'https:';
            const client = isHTTPS ? https : http;
            
            const requestOptions = {
                hostname: parsedURL.hostname,
                port: parsedURL.port || (isHTTPS ? 443 : 80),
                path: parsedURL.pathname + parsedURL.search,
                method: options.method || 'GET',
                headers: {
                    'User-Agent': this.options.userAgent,
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.5',
                    'Accept-Encoding': 'gzip, deflate',
                    'Connection': 'keep-alive',
                    ...options.headers
                },
                timeout: this.options.timeout
            };
            
            const req = client.request(requestOptions, (res) => {
                let body = '';
                
                res.on('data', (chunk) => {
                    body += chunk.toString();
                });
                
                res.on('end', () => {
                    // Handle redirects
                    if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                        const redirectURL = new URL(res.headers.location, urlString);
                        resolve(this.makeRequest(redirectURL.toString(), options));
                        return;
                    }
                    
                    resolve({
                        statusCode: res.statusCode,
                        headers: res.headers,
                        body: body
                    });
                });
            });
            
            req.on('error', (error) => {
                reject(new Error(`Request failed: ${error.message}`));
            });
            
            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Request timeout'));
            });
            
            if (options.body) {
                req.write(options.body);
            }
            
            req.end();
        });
    }

    async checkRobotsTxt(parsedURL) {
        const robotsURL = `${parsedURL.protocol}//${parsedURL.host}/robots.txt`;
        
        if (this.robotsCache.has(robotsURL)) {
            return this.robotsCache.get(robotsURL);
        }
        
        try {
            const response = await this.makeRequest(robotsURL);
            if (response.statusCode === 200) {
                const allowed = this.parseRobotsTxt(response.body, parsedURL.pathname);
                this.robotsCache.set(robotsURL, allowed);
                return allowed;
            }
        } catch (error) {
            // If robots.txt is not accessible, assume allowed
        }
        
        this.robotsCache.set(robotsURL, true);
        return true;
    }

    parseRobotsTxt(robotsContent, path) {
        const lines = robotsContent.split('\n');
        let userAgentSection = false;
        let allowed = true;
        
        for (const line of lines) {
            const trimmedLine = line.trim().toLowerCase();
            
            if (trimmedLine.startsWith('user-agent:')) {
                const userAgent = trimmedLine.substring(11).trim();
                userAgentSection = userAgent === '*' || 
                    this.options.userAgent.toLowerCase().includes(userAgent);
            } else if (userAgentSection && trimmedLine.startsWith('disallow:')) {
                const disallowPath = trimmedLine.substring(9).trim();
                if (disallowPath && path.startsWith(disallowPath)) {
                    allowed = false;
                    break;
                }
            } else if (userAgentSection && trimmedLine.startsWith('allow:')) {
                const allowPath = trimmedLine.substring(6).trim();
                if (allowPath && path.startsWith(allowPath)) {
                    allowed = true;
                }
            }
        }
        
        return allowed;
    }

    extractData(parser, extractors) {
        const data = {};
        
        // Default extractors
        const defaultExtractors = {
            title: () => parser.extractMetadata().title,
            headings: () => [
                ...parser.extractByTag('h1'),
                ...parser.extractByTag('h2'),
                ...parser.extractByTag('h3')
            ].map(h => h.textContent),
            paragraphs: () => parser.extractByTag('p').map(p => p.textContent),
            wordCount: () => {
                const text = parser.stripTags(parser.html);
                return text.split(/\s+/).filter(word => word.length > 0).length;
            }
        };
        
        // Apply extractors
        const allExtractors = { ...defaultExtractors, ...extractors };
        
        for (const [key, extractor] of Object.entries(allExtractors)) {
            try {
                if (typeof extractor === 'function') {
                    data[key] = extractor(parser);
                } else if (typeof extractor === 'string') {
                    // CSS selector
                    data[key] = parser.querySelector(extractor);
                }
            } catch (error) {
                data[key] = null;
                this.emit('extractorError', { key, error: error.message });
            }
        }
        
        return data;
    }

    async batchScrape(urls, options = {}) {
        const startTime = Date.now();
        this.stats.startTime = startTime;
        this.stats.requested = urls.length;
        
        const results = new Map();
        const chunks = this.chunkArray(urls, this.options.maxConcurrent);
        
        for (const chunk of chunks) {
            const promises = chunk.map(async (url) => {
                try {
                    this.activeRequests++;
                    const result = await this.scrapeURL(url, options);
                    results.set(url, result);
                    
                    this.emit('progress', {
                        completed: results.size,
                        total: urls.length,
                        percentage: ((results.size / urls.length) * 100).toFixed(2)
                    });
                    
                    return result;
                } catch (error) {
                    this.emit('batchError', { url, error: error.message });
                    return null;
                } finally {
                    this.activeRequests--;
                }
            });
            
            await Promise.all(promises);
        }
        
        this.stats.endTime = Date.now();
        this.emit('batchComplete', {
            totalUrls: urls.length,
            successful: this.stats.successful,
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

    analyzeBatchResults() {
        const analysis = {
            totalResults: this.results.size,
            successRate: (this.stats.successful / this.stats.requested * 100).toFixed(2),
            averageProcessingTime: 0,
            contentTypes: {},
            statusCodes: {},
            domains: {},
            commonWords: {},
            errorTypes: {}
        };
        
        let totalProcessingTime = 0;
        const allWords = [];
        
        for (const result of this.results.values()) {
            if (result.success) {
                totalProcessingTime += result.processingTime;
                
                // Content type analysis
                const contentType = result.data.contentType.split(';')[0];
                analysis.contentTypes[contentType] = (analysis.contentTypes[contentType] || 0) + 1;
                
                // Status code analysis
                analysis.statusCodes[result.statusCode] = (analysis.statusCodes[result.statusCode] || 0) + 1;
                
                // Domain analysis
                const domain = new URL(result.url).hostname;
                analysis.domains[domain] = (analysis.domains[domain] || 0) + 1;
                
                // Word frequency analysis
                if (result.data.extractedData.paragraphs) {
                    const text = result.data.extractedData.paragraphs.join(' ').toLowerCase();
                    const words = text.match(/\b\w+\b/g) || [];
                    allWords.push(...words);
                }
            } else {
                analysis.errorTypes[result.error] = (analysis.errorTypes[result.error] || 0) + 1;
            }
        }
        
        if (this.stats.successful > 0) {
            analysis.averageProcessingTime = (totalProcessingTime / this.stats.successful).toFixed(2);
        }
        
        // Top 20 most common words
        const wordFreq = {};
        allWords.forEach(word => {
            if (word.length > 3) { // Filter out short words
                wordFreq[word] = (wordFreq[word] || 0) + 1;
            }
        });
        
        analysis.commonWords = Object.entries(wordFreq)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 20)
            .reduce((obj, [word, count]) => {
                obj[word] = count;
                return obj;
            }, {});
        
        return analysis;
    }

    async exportResults(filePath) {
        const results = Array.from(this.results.values());
        const analysis = this.analyzeBatchResults();
        
        const exportData = {
            timestamp: new Date().toISOString(),
            stats: this.stats,
            analysis,
            results: results.map(result => ({
                url: result.url,
                success: result.success,
                error: result.error,
                statusCode: result.statusCode,
                processingTime: result.processingTime,
                timestamp: result.timestamp,
                data: result.success ? {
                    contentLength: result.data.contentLength,
                    contentType: result.data.contentType,
                    title: result.data.metadata.title,
                    linkCount: result.data.links.length,
                    imageCount: result.data.images.length,
                    wordCount: result.data.extractedData.wordCount
                } : null
            }))
        };
        
        require('fs').promises.writeFile(filePath, JSON.stringify(exportData, null, 2));
        console.log(`Results exported to: ${filePath}`);
        return filePath;
    }

    getStats() {
        return {
            ...this.stats,
            activeRequests: this.activeRequests,
            cachedRobots: this.robotsCache.size,
            totalResults: this.results.size
        };
    }

    clearResults() {
        this.results.clear();
        this.stats = {
            requested: 0,
            successful: 0,
            failed: 0,
            startTime: null,
            endTime: null
        };
    }
}

// AI-SUGGESTION: Demo function
async function demonstrateWebScraper() {
    console.log('🕷️  Web Scraper Automation Demo');
    console.log('================================');

    const scraper = new WebScraperAutomation({
        rateLimitRPS: 2,
        maxConcurrent: 3,
        respectRobots: false // For demo purposes
    });

    // Event listeners
    scraper.on('progress', (data) => {
        console.log(`Progress: ${data.percentage}% (${data.completed}/${data.total})`);
    });

    scraper.on('scraped', (result) => {
        console.log(`✅ Scraped: ${result.url} (${result.data.contentLength} bytes)`);
    });

    scraper.on('error', (data) => {
        console.log(`❌ Error scraping ${data.url}: ${data.error}`);
    });

    try {
        // Demo URLs (using public APIs and test sites)
        const testUrls = [
            'https://httpbin.org/html',
            'https://jsonplaceholder.typicode.com/',
            'https://httpbin.org/robots.txt'
        ];

        console.log('\n--- Batch Scraping ---');
        const results = await scraper.batchScrape(testUrls, {
            extractors: {
                customData: (parser) => {
                    return {
                        linkCount: parser.extractLinks().length,
                        hasForm: parser.extractByTag('form').length > 0
                    };
                }
            }
        });

        console.log(`\nProcessed ${results.size} URLs`);

        // Analyze results
        console.log('\n--- Analysis ---');
        const analysis = scraper.analyzeBatchResults();
        console.log(`Success rate: ${analysis.successRate}%`);
        console.log(`Average processing time: ${analysis.averageProcessingTime}ms`);
        console.log('Content types:', analysis.contentTypes);

        // Export results
        const exportPath = `scraping-results-${Date.now()}.json`;
        await scraper.exportResults(exportPath);

    } catch (error) {
        console.error('Demo error:', error.message);
    }

    console.log('\n=== Web Scraper Demo Complete ===');
}

// AI-SUGGESTION: Run demo if this file is executed directly
if (require.main === module) {
    demonstrateWebScraper();
}

module.exports = {
    WebScraperAutomation,
    SimpleHTMLParser,
    ScrapingResult,
    RateLimiter
}; 