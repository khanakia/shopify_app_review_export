import scrapy
from reviews import ShopifyReviewSpider 
from scrapy.crawler import CrawlerProcess


if __name__ == "__main__":
  process = CrawlerProcess()
  process.crawl(ShopifyReviewSpider)
  process.start()
