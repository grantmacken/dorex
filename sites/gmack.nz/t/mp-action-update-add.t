#!/usr/bin/env bash
source t/setup
use Test::More

##[Updating A Post](https://www.w3.org/TR/micropub/#h-update)
#401: Add a value to an existing property

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub
location=$(cat .tmp/location.txt | tr -d "[:cntrl:]" )

json=$(cat << EOF
{
  "action": "update",
  "url": "${location}",
  "add": {
    "category":["test1", "test2"]
  }
}
EOF
)

status=$( curl -s \
 -H "$auth" \
 -H 'Content-Type: application/json' \
 -d "${json}" \
 --output '.tmp/page-update-add.html' \
 --write-out  %{http_code} \
 --dump-header '.tmp/page-update-add-headers.txt' \
 --url $req )

# page=$(cat .tmp/page-update-add.html)
# headers=$(cat .tmp/page-update-add-headers.txt)
page=$(cat .tmp/page-update-add.html)
headers=$(cat .tmp/page-update-add-headers.txt)

plan tests 1

# "Micropub action"
note "## Add a value to an existing property ##"
note "-----------------------------------------"
note "$WEBSITE"
note "==============="
note "${page}"
note "==============="
note "${headers}"
note "==============="
note "${location}"
note "==============="
note "$(echo $json | jq '.')" 
note "==============="

ok "$(echo $headers |  grep -q 'HTTP/2 204')" "should serve HTTP/2 204"
