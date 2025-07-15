#!/usr/bin/env python3

import asyncio
import json
import logging
import random
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Union
from urllib.parse import urljoin, urlparse
import warnings

import aiohttp
import requests
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
import pandas as pd

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class ScrapingConfig:
    max_workers: int = 5
    delay_range: tuple = (1, 3)
    timeout: int = 30
    retries: int = 3
    respect_robots_txt: bool = True
    user_agent: str = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    headers: Dict[str, str] = field(default_factory=dict)

@dataclass
class ScrapedData:
    url: str
    title: Optional[str] = None
    content: Optional[str] = None
    links: List[str] = field(default_factory=list)
    images: List[str] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)
    scraped_at: datetime = field(default_factory=datetime.now)

class RateLimiter:
    def __init__(self, min_delay: float = 1.0, max_delay: float = 3.0):
        self.min_delay = min_delay
        self.max_delay = max_delay
        self.last_request_time = 0
    
    async def wait(self) -> None:
        current_time = time.time()
        elapsed = current_time - self.last_request_time
        delay = random.uniform(self.min_delay, self.max_delay)
        
        if elapsed < delay:
            await asyncio.sleep(delay - elapsed)
        
        self.last_request_time = time.time()

class BaseScraper(ABC):
    def __init__(self, config: ScrapingConfig):
        self.config = config
        self.rate_limiter = RateLimiter(
            config.delay_range[0], 
            config.delay_range[1]
        )
    
    @abstractmethod
    async def scrape(self, url: str) -> ScrapedData:
        pass
    
    def get_headers(self) -> Dict[str, str]:
        headers = {
            'User-Agent': self.config.user_agent,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
        }
        headers.update(self.config.headers)
        return headers

class HTTPScraper(BaseScraper):
    def __init__(self, config: ScrapingConfig):
        super().__init__(config)
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def __aenter__(self):
        connector = aiohttp.TCPConnector(limit=self.config.max_workers)
        timeout = aiohttp.ClientTimeout(total=self.config.timeout)
        
        self.session = aiohttp.ClientSession(
            connector=connector,
            timeout=timeout,
            headers=self.get_headers()
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def scrape(self, url: str) -> ScrapedData:
        await self.rate_limiter.wait()
        
        for attempt in range(self.config.retries):
            try:
                async with self.session.get(url) as response:
                    if response.status == 200:
                        html = await response.text()
                        return self._parse_html(url, html)
                    else:
                        logger.warning(f"HTTP {response.status} for {url}")
                        
            except Exception as e:
                logger.error(f"Attempt {attempt + 1} failed for {url}: {e}")
                if attempt < self.config.retries - 1:
                    await asyncio.sleep(2 ** attempt)
        
        return ScrapedData(url=url, metadata={'error': 'Failed to scrape'})
    
    def _parse_html(self, url: str, html: str) -> ScrapedData:
        soup = BeautifulSoup(html, 'html.parser')
        
        title_tag = soup.find('title')
        title = title_tag.get_text(strip=True) if title_tag else None
        
        for script in soup(['script', 'style']):
            script.decompose()
        content = soup.get_text(strip=True)
        
        links = []
        for link in soup.find_all('a', href=True):
            absolute_url = urljoin(url, link['href'])
            links.append(absolute_url)
        
        images = []
        for img in soup.find_all('img', src=True):
            absolute_url = urljoin(url, img['src'])
            images.append(absolute_url)
        
        metadata = {}
        for meta in soup.find_all('meta'):
            name = meta.get('name') or meta.get('property')
            content_attr = meta.get('content')
            if name and content_attr:
                metadata[name] = content_attr
        
        return ScrapedData(
            url=url,
            title=title,
            content=content[:1000],
            links=links[:10],
            images=images[:10],
            metadata=metadata
        )

class BrowserScraper(BaseScraper):
    def __init__(self, config: ScrapingConfig, headless: bool = True):
        super().__init__(config)
        self.headless = headless
        self.driver: Optional[webdriver.Chrome] = None
    
    def __enter__(self):
        self._start_driver()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.driver:
            self.driver.quit()
    
    def _start_driver(self) -> None:
        options = Options()
        
        if self.headless:
            options.add_argument('--headless')
        
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-blink-features=AutomationControlled')
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_experimental_option('useAutomationExtension', False)
        options.add_argument(f'--user-agent={self.config.user_agent}')
        
        self.driver = webdriver.Chrome(options=options)
        self.driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    
    async def scrape(self, url: str) -> ScrapedData:
        await self.rate_limiter.wait()
        
        try:
            self.driver.get(url)
            
            WebDriverWait(self.driver, self.config.timeout).until(
                EC.presence_of_element_located((By.TAG_NAME, "body"))
            )
            
            title = self.driver.title
            
            content = self.driver.find_element(By.TAG_NAME, "body").text
            
            links = []
            for link_element in self.driver.find_elements(By.TAG_NAME, "a"):
                href = link_element.get_attribute("href")
                if href:
                    links.append(href)
            
            images = []
            for img_element in self.driver.find_elements(By.TAG_NAME, "img"):
                src = img_element.get_attribute("src")
                if src:
                    images.append(src)
            
            screenshot_path = f"screenshot_{int(time.time())}.png"
            self.driver.save_screenshot(screenshot_path)
            
            return ScrapedData(
                url=url,
                title=title,
                content=content[:1000],
                links=links[:10],
                images=images[:10],
                metadata={'screenshot': screenshot_path}
            )
            
        except Exception as e:
            logger.error(f"Browser scraping failed for {url}: {e}")
            return ScrapedData(url=url, metadata={'error': str(e)})

class EcommerceScraper(HTTPScraper):
    async def scrape_product(self, url: str) -> Dict[str, Any]:
        scraped_data = await self.scrape(url)
        
        if 'error' in scraped_data.metadata:
            return {'url': url, 'error': scraped_data.metadata['error']}
        
        soup = BeautifulSoup(scraped_data.content, 'html.parser')
        
        product_data = {
            'url': url,
            'title': scraped_data.title,
            'price': self._extract_price(soup),
            'description': self._extract_description(soup),
            'images': scraped_data.images,
            'availability': self._extract_availability(soup),
            'rating': self._extract_rating(soup),
            'reviews_count': self._extract_reviews_count(soup)
        }
        
        return product_data
    
    def _extract_price(self, soup: BeautifulSoup) -> Optional[str]:
        price_selectors = [
            '.price', '#price', '[data-price]', '.cost',
            '.price-current', '.sale-price', '.regular-price'
        ]
        
        for selector in price_selectors:
            price_element = soup.select_one(selector)
            if price_element:
                price_text = price_element.get_text(strip=True)
                return price_text
        
        return None
    
    def _extract_description(self, soup: BeautifulSoup) -> Optional[str]:
        desc_selectors = [
            '.description', '#description', '.product-description',
            '.product-details', '.item-description'
        ]
        
        for selector in desc_selectors:
            desc_element = soup.select_one(selector)
            if desc_element:
                return desc_element.get_text(strip=True)[:500]
        
        return None
    
    def _extract_availability(self, soup: BeautifulSoup) -> Optional[str]:
        availability_keywords = ['in stock', 'available', 'out of stock', 'sold out']
        text = soup.get_text().lower()
        
        for keyword in availability_keywords:
            if keyword in text:
                return keyword
        
        return None
    
    def _extract_rating(self, soup: BeautifulSoup) -> Optional[float]:
        rating_selectors = [
            '.rating', '.star-rating', '[data-rating]', '.review-score'
        ]
        
        for selector in rating_selectors:
            rating_element = soup.select_one(selector)
            if rating_element:
                rating_text = rating_element.get_text(strip=True)
                import re
                match = re.search(r'(\d+\.?\d*)', rating_text)
                if match:
                    return float(match.group(1))
        
        return None
    
    def _extract_reviews_count(self, soup: BeautifulSoup) -> Optional[int]:
        review_selectors = [
            '.reviews-count', '.review-count', '[data-reviews]'
        ]
        
        for selector in review_selectors:
            review_element = soup.select_one(selector)
            if review_element:
                review_text = review_element.get_text(strip=True)
                import re
                match = re.search(r'(\d+)', review_text)
                if match:
                    return int(match.group(1))
        
        return None

class NewsScraper(HTTPScraper):
    async def scrape_rss(self, rss_url: str) -> List[Dict[str, Any]]:
        try:
            import feedparser
            
            async with self.session.get(rss_url) as response:
                if response.status == 200:
                    rss_content = await response.text()
                    feed = feedparser.parse(rss_content)
                    
                    articles = []
                    for entry in feed.entries[:10]:
                        article = {
                            'title': getattr(entry, 'title', ''),
                            'link': getattr(entry, 'link', ''),
                            'summary': getattr(entry, 'summary', ''),
                            'published': getattr(entry, 'published', ''),
                            'author': getattr(entry, 'author', '')
                        }
                        articles.append(article)
                    
                    return articles
                    
        except Exception as e:
            logger.error(f"RSS scraping failed for {rss_url}: {e}")
        
        return []
    
    async def scrape_article(self, url: str) -> Dict[str, Any]:
        scraped_data = await self.scrape(url)
        
        if 'error' in scraped_data.metadata:
            return {'url': url, 'error': scraped_data.metadata['error']}
        
        soup = BeautifulSoup(scraped_data.content, 'html.parser')
        
        article_data = {
            'url': url,
            'title': scraped_data.title,
            'content': self._extract_article_content(soup),
            'author': self._extract_author(soup),
            'publish_date': self._extract_publish_date(soup),
            'tags': self._extract_tags(soup)
        }
        
        return article_data
    
    def _extract_article_content(self, soup: BeautifulSoup) -> Optional[str]:
        content_selectors = [
            'article', '.article-content', '.post-content',
            '.entry-content', '.content', '.article-body'
        ]
        
        for selector in content_selectors:
            content_element = soup.select_one(selector)
            if content_element:
                for unwanted in content_element(['script', 'style', 'nav', 'header', 'footer']):
                    unwanted.decompose()
                
                return content_element.get_text(strip=True)
        
        return None
    
    def _extract_author(self, soup: BeautifulSoup) -> Optional[str]:
        author_selectors = [
            '.author', '.byline', '[rel="author"]', '.post-author'
        ]
        
        for selector in author_selectors:
            author_element = soup.select_one(selector)
            if author_element:
                return author_element.get_text(strip=True)
        
        return None
    
    def _extract_publish_date(self, soup: BeautifulSoup) -> Optional[str]:
        date_selectors = [
            '[datetime]', '.publish-date', '.post-date', '.date'
        ]
        
        for selector in date_selectors:
            date_element = soup.select_one(selector)
            if date_element:
                return date_element.get('datetime') or date_element.get_text(strip=True)
        
        return None
    
    def _extract_tags(self, soup: BeautifulSoup) -> List[str]:
        tags = []
        tag_selectors = [
            '.tags a', '.tag', '.category', '.keywords'
        ]
        
        for selector in tag_selectors:
            tag_elements = soup.select(selector)
            for tag_element in tag_elements:
                tag_text = tag_element.get_text(strip=True)
                if tag_text:
                    tags.append(tag_text)
        
        return tags[:10]

class DataStorage:
    def __init__(self, storage_type: str = 'json'):
        self.storage_type = storage_type
        self.data_dir = Path('scraped_data')
        self.data_dir.mkdir(exist_ok=True)
    
    def save_data(self, data: Union[List[ScrapedData], List[Dict]], filename: str) -> None:
        filepath = self.data_dir / filename
        
        if self.storage_type == 'json':
            self._save_json(data, filepath.with_suffix('.json'))
        elif self.storage_type == 'csv':
            self._save_csv(data, filepath.with_suffix('.csv'))
        else:
            raise ValueError(f"Unsupported storage type: {self.storage_type}")
        
        logger.info(f"Data saved to {filepath}")
    
    def _save_json(self, data: Any, filepath: Path) -> None:
        json_data = []
        
        for item in data:
            if isinstance(item, ScrapedData):
                json_data.append({
                    'url': item.url,
                    'title': item.title,
                    'content': item.content,
                    'links': item.links,
                    'images': item.images,
                    'metadata': item.metadata,
                    'scraped_at': item.scraped_at.isoformat()
                })
            else:
                json_data.append(item)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(json_data, f, indent=2, ensure_ascii=False)
    
    def _save_csv(self, data: Any, filepath: Path) -> None:
        if isinstance(data[0], ScrapedData):
            df_data = []
            for item in data:
                df_data.append({
                    'url': item.url,
                    'title': item.title,
                    'content': item.content,
                    'scraped_at': item.scraped_at
                })
            df = pd.DataFrame(df_data)
        else:
            df = pd.DataFrame(data)
        
        df.to_csv(filepath, index=False, encoding='utf-8')

class ScrapingOrchestrator:
    def __init__(self, config: ScrapingConfig):
        self.config = config
        self.storage = DataStorage()
        self.results: List[ScrapedData] = []
    
    async def scrape_urls(self, urls: List[str], scraper_type: str = 'http') -> List[ScrapedData]:
        logger.info(f"Starting to scrape {len(urls)} URLs using {scraper_type} scraper")
        
        if scraper_type == 'http':
            async with HTTPScraper(self.config) as scraper:
                tasks = [scraper.scrape(url) for url in urls]
                results = await asyncio.gather(*tasks, return_exceptions=True)
        else:
            results = []
            with BrowserScraper(self.config) as scraper:
                for url in urls:
                    result = await scraper.scrape(url)
                    results.append(result)
        
        valid_results = [r for r in results if isinstance(r, ScrapedData)]
        self.results.extend(valid_results)
        
        logger.info(f"Successfully scraped {len(valid_results)} URLs")
        return valid_results
    
    async def scrape_ecommerce_products(self, product_urls: List[str]) -> List[Dict[str, Any]]:
        logger.info(f"Scraping {len(product_urls)} products")
        
        async with EcommerceScraper(self.config) as scraper:
            tasks = [scraper.scrape_product(url) for url in product_urls]
            results = await asyncio.gather(*tasks, return_exceptions=True)
        
        valid_results = [r for r in results if isinstance(r, dict)]
        return valid_results
    
    async def scrape_news_feed(self, rss_url: str) -> List[Dict[str, Any]]:
        logger.info(f"Scraping news from RSS: {rss_url}")
        
        async with NewsScraper(self.config) as scraper:
            articles = await scraper.scrape_rss(rss_url)
            
            tasks = [scraper.scrape_article(article['link']) for article in articles[:5]]
            full_articles = await asyncio.gather(*tasks, return_exceptions=True)
        
        valid_articles = [a for a in full_articles if isinstance(a, dict)]
        return valid_articles
    
    def save_results(self, filename: str = None) -> None:
        if not self.results:
            logger.warning("No results to save")
            return
        
        filename = filename or f"scraped_data_{int(time.time())}"
        self.storage.save_data(self.results, filename)

async def demonstrate_web_scraping():
    print("=== Web Scraping Automation Demo ===")
    
    config = ScrapingConfig(
        max_workers=3,
        delay_range=(1, 2),
        timeout=10
    )
    
    orchestrator = ScrapingOrchestrator(config)
    
    demo_urls = [
        'https://httpbin.org/html',
        'https://httpbin.org/json',
        'https://example.com'
    ]
    
    print(f"\n=== Scraping {len(demo_urls)} URLs ===")
    results = await orchestrator.scrape_urls(demo_urls)
    
    for result in results:
        print(f"URL: {result.url}")
        print(f"Title: {result.title}")
        print(f"Content length: {len(result.content or '')}")
        print(f"Links found: {len(result.links)}")
        print("---")
    
    orchestrator.save_results("demo_scraping")
    
    print("Web scraping demonstration completed!")

if __name__ == "__main__":
    asyncio.run(demonstrate_web_scraping()) 