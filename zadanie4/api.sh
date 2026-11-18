#/bin/bash

source .env

cat_url=$(curl -s -H "x-api-key: ${THE_CAT_API_KEY:-key}" https://beta-api.thecatapi.com/v1/images/search | jq -r .[0].url)

chucknorris=$(curl -s https://api.chucknorris.io/jokes/random | jq .value)

tmp=$(mktemp --suffix=.jpg)

curl -s $cat_url -o "$tmp"

catimg -w 120 "$tmp"

echo "$chucknorris"

rm -rf "$tmp"
