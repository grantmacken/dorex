#!/usr/bin/env bash
source t/setup
use Test::More
# prove -v t/mp-query-endpoint.t

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub
location="$(cat .tmp/location.txt | tr -d '[:cntrl:]')"
headersFile='.tmp/headers.txt'
body='.tmp/body.json'
if [ -e $body ]; then rm $body; fi
if [ -e $headersFile ]; then rm $headersFile; fi

status=$( curl -GsS \
 -H "$auth" \
 -d 'q=source' \
 -d "url=$location" \
 --output "$body" \
 --dump-header "$headersFile" \
 --url $req)

page=$(cat $body)
headers=$(cat $headersFile)

plan tests 3

note "==============="
note "$WEBSITE"
note "$status"
note "==============="
note "${page}"
note "==============="
note "${headers}"
note "==============="
# note "$(jq '.' <( <$body ))" 
# note "==============="

ok "$(grep -q 'HTTP/2 200' $headersFile )" "should serve HTTP/2 200"
ok "$(test -s $body )" "body should not be empty"
ok "$([ -s $body ] && jq --exit-status '.' <( <$body ) >/dev/null)" "body should parse as json"

