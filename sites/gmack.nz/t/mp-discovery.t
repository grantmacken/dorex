#!/usr/bin/env bash
source t/setup
use Test::More
# prove -v t/mp-discovery.t

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub
headersFile='.tmp/config-headers.txt'
body='.tmp/config.json'
if [ -e $body ];then rm $body; fi
if [ -e $headersFile ];then rm $headersFile; fi

status=$( curl -GsS\
 -H "$auth" \
 -d 'q=config' \
 --output "$body" \
 --dump-header "$headersFile" \
 --url $req )

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
note "$(jq '.' <( <$body ))"  

ok "$(grep -q 'HTTP/2 200' $headersFile )" "should serve HTTP/2 200"
ok "$(jq --exit-status '.' <( <$body ) >/dev/null)" "body should parse as json"
ok "$(jq --exit-status 'has("media-endpoint")' <( <$body ) >/dev/null)" "json should contain a media endpoint"
