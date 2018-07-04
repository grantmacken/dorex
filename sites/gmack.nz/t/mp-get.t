#!/usr/bin/env bash
source t/setup
use Test::More

req=$WEBSITE
req=$WEBSITE/$tID
resStatus=$( 
curl -s \
 --output '.tmp/page-body.txt' \
 --dump-header '.tmp/page-headers.txt' \
 --url ${req} \
)

page=$(cat .tmp/page-body.txt)
headers=$(cat .tmp/page-headers.txt)

plan tests 1

note "Check For Request $LOCATION"
note "==============="
note "$WEBSITE"
note "==============="
note "${page}"
note "==============="
note "${headers}"
note "==============="
ok "$(echo $headers |  grep -q 'HTTP/2 200')" "should serve HTTP/2 OK "
# ok "$(echo $page |  grep -q 'content-type: image/svg+xml')" "should serve header 'content-type: image/svg+xml'"
# ok "$(echo $page |  grep -q 'content-encoding: gzip')" "should serve header 'content-encoding: gzip'"
# ok "$(echo $page |  grep -q 'vary: Accept-Encoding')" "should serve header 'vary: Accept-Encoding'"
