import scrapy
import re

class ReviewItem(scrapy.Item):
    title = scrapy.Field()
    rating = scrapy.Field()
    date = scrapy.Field()
    location = scrapy.Field()
    content = scrapy.Field()

class ShopifyReviewSpider(scrapy.Spider):
    name = 'reviews'
    custom_settings = { 
      'DOWNLOD_DELAY': 1,
      'FEED_FORMAT': 'csv',
      'FEED_URI' : 'reviews.csv'
    }
    
    headers = {} 
    params = {}


    start_urls = [
      'https://apps.shopify.com/example-app/reviews?sort_by=newest',
    ]

    def parse(self, response):
        for quote in response.css('div[data-merchant-review]'):
            item = ReviewItem()
            # Title
            item['title'] = quote.css('.tw-text-heading-xs.tw-text-fg-primary::attr(title)').get()
            if not item['title']:
                item['title'] = quote.css('.tw-text-heading-xs.tw-text-fg-primary::text').get()
            if item['title']:
                item['title'] = item['title'].strip()

            # Rating: extract from aria-label
            rating_label = quote.css('div[aria-label*="out of"]::attr(aria-label)').get()
            if rating_label:
                match = re.search(r'(\d+) out of', rating_label)
                item['rating'] = int(match.group(1)) if match else None
            else:
                item['rating'] = None

            # Date
            item['date'] = quote.css('.tw-text-body-xs.tw-text-fg-tertiary::text').get()
            if item['date']:
                item['date'] = item['date'].replace('Edited', '').strip()

            # Content: join all <p> tags in review content
            content_paragraphs = quote.css('div[data-truncate-content-copy] p::text').getall()
            item['content'] = '\n'.join([p.strip() for p in content_paragraphs if p.strip()])

            # Location: the next <div> after the title
            merchant_info_divs = quote.css('.tw-text-heading-xs.tw-text-fg-primary ~ div::text').get()
            if merchant_info_divs:
                item['location'] = merchant_info_divs.strip()
            else:
                item['location'] = None

            yield item

        next_page = response.css('a[rel="next"]::attr(href)').get()
        if next_page:
            yield response.follow(next_page, self.parse)