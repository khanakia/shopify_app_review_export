## Scrap script to export shopify reviews
https://docs.scrapy.org/en/latest/topics/item-pipeline.html

## Export to JSON
scrapy runspider reviews.py -o reviews.jl

## Export to CSV
scrapy runspider reviews.py -o reviews.csv -t csv


## To directly run the script and it will create the csv file
python main.py


