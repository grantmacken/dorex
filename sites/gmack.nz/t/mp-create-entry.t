#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub

curl -s \
 -H "$auth" \
 -d 'h=entry' \
 -d 'content=This post is curled' \
 --output '.tmp/page.html' \
 --write-out  %{http_code} \
 --dump-header '.tmp/page-headers.txt' \
 $req > /dev/null  && \
 echo $(cat '.tmp/page-headers.txt' | grep -oP '^location:\s\K(.+)$' ) > .tmp/location.txt

location="$(cat .tmp/location.txt)"
page=$(cat .tmp/page.html)
headers=$(cat .tmp/page-headers.txt)

#####################

plan tests 2

note "==============="
note "$WEBSITE"
note "==============="
note "${page}"
note "==============="
note "${headers}"
note "==============="
note "${location}"
note "==============="

ok "$(test -n $location)" "should serve header location $location"
ok "$(echo $headers |  grep -q 'HTTP/2 201')" "should serve HTTP/2 201"








