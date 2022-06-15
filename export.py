import scrapy

class ReviewItem(scrapy.Item):
    title = scrapy.Field()
    rating = scrapy.Field()
    date = scrapy.Field()
    location = scrapy.Field()
    content = scrapy.Field()

class ShopifyReviewSpider(scrapy.Spider):
    name = 'reviews'
    start_urls = [
      'https://apps.shopify.com/yotpo-subscription/reviews',
    ]

    def parse(self, response):
        for quote in response.css('div.review-listing '):
            item = ReviewItem()
            item['title'] =  quote.css('.review-listing-header__text::text').get().strip()
            item['rating'] = quote.css('.ui-star-rating')[0].xpath('@data-rating').get()
            item['date'] = quote.css('div.review-metadata__item-label::text').get().strip()
            item['content'] = quote.css('.review-content .truncate-content-copy p::text').get().strip()
            item['location'] = quote.css('div.review-merchant-characteristic__item span::text').get()
            if item['location'] is not None:
              item['location'] = item['location'].strip()

            yield item

        next_page = response.css('div.search-pagination a.search-pagination__next-page-text::attr("href")').get()
        if next_page is not None:
            yield response.follow(next_page, self.parse)