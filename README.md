## Scrap script to export shopify reviews
https://docs.scrapy.org/en/latest/topics/item-pipeline.html

## Export to JSON
scrapy runspider reviews.py -o reviews.jl

## Export to CSV
scrapy runspider reviews.py -o reviews.csv -t csv


## To directly run the script and it will create the csv file
python main.py



## Before a commit
```sh
git config core.hooksPath .githooks   # once per clone
```
The hooks run `scripts/check-names.sh`, which fails when a change or commit message holds a private name from a word list kept outside the repo (`~/.config/names-guard/terms.txt`); without the list it warns and passes.
