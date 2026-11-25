## Scrap script to export shopify reviews
https://docs.scrapy.org/en/latest/topics/item-pipeline.html

## Export to JSON
scrapy runspider reviews.py -o reviews.jl

## Export to CSV
scrapy runspider reviews.py -o reviews.csv -t csv


## To directly run the script and it will create the csv file
python main.py



## Before a commit
scripts/check-names.sh  (fails when a tracked file holds a name from the hashed deny list in .github/denyhash.txt)
