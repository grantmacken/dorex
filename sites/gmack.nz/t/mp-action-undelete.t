#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub
location=$(cat .tmp/location.txt | tr -d "[:cntrl:]" )

curl -s \
 -H "$auth" \
 -d 'action=undelete' \
 -d "url=$location" \
 --output '.tmp/page-undelete.html' \
 --write-out  %{http_code} \
 --dump-header '.tmp/page-undelete-headers.txt' \
 $req  > /dev/null

page=$(cat .tmp/page-undelete.html)
headers=$(cat .tmp/page-undelete-headers.txt)

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

ok "$(echo $headers |  grep -q 'HTTP/2 200')" "should serve HTTP/2 200"






