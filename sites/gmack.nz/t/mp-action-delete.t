#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub
location=$(cat .tmp/location.txt | tr -d "[:cntrl:]" )

curl -s \
 -H "$auth" \
 -d 'action=delete' \
 -d "url=$location" \
 --output '.tmp/page-deleted.html' \
 --write-out  %{http_code} \
 --dump-header '.tmp/page-deleted-headers.txt' \
 $req  > /dev/null

page=$(cat .tmp/page-deleted.html)
headers=$(cat .tmp/page-deleted-headers.txt)

plan tests 1

note "==============="
note "$WEBSITE"
note "==============="
note "${page}"
note "==============="
note "${headers}"
note "==============="
note "${location}"
note "==============="

ok "$(echo $headers |  grep -q 'HTTP/2 204')" "should serve HTTP/2 204"








