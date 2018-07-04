#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub
location=$(cat .tmp/location.txt | tr -d "[:cntrl:]" )

json=$(cat << EOF
{"action": "update","url":"${location}","replace":{"content":["Micropub update test. This text should be replaced if the test succeed"]}}
EOF
)

status=$( curl -s \
 -H "$auth" \
 -H 'Content-Type: application/json' \
 -d "${json}" \
 --output '.tmp/page-update-replace.html' \
 --write-out  %{http_code} \
 --dump-header '.tmp/page-update-replace-headers.txt' \
 --url $req )

# page=$(cat .tmp/page-update-replace.html)
# headers=$(cat .tmp/page-update-replace-headers.txt)
page=$(cat .tmp/page-update-replace.html)
headers=$(cat .tmp/page-update-replace-headers.txt)

plan tests 1

note "==============="
note "$WEBSITE"
note "$status"
note "==============="
note "${page}"
note "==============="
note "${headers}"
note "==============="
note "${location}"
note "==============="
note "$(echo $json | jq '.')" 


ok "$(echo $headers |  grep -q 'HTTP/2 204')" "should serve HTTP/2 204"
