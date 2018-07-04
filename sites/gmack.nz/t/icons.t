#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"

req=${WEBSITE}/icons/mail 
reqNote='Fetch the mail icon'
page="$( curl -s -I ${req} )"

plan tests 4

note "Icons Headers Check For Request ${req}"
note "==============="
note "${page}"
note "==============="

ok "$(echo $page |  grep -q 'HTTP/2 200')" "should serve HTTP/2 OK "
ok "$(echo $page |  grep -q 'content-type: image/svg+xml')" "should serve header 'content-type: image/svg+xml'"
ok "$(echo $page |  grep -q 'content-encoding: gzip')" "should serve header 'content-encoding: gzip'"
ok "$(echo $page |  grep -q 'vary: Accept-Encoding')" "should serve header 'vary: Accept-Encoding'"
