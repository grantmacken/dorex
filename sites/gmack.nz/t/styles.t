#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"

req=${WEBSITE}/styles
reqNote='Fetch the main stylesheet'
page="$(curl -sI -H 'Accept-Encoding: gzip' ${req} )"
size="$(curl -s --write-out '%{size_download}' -H 'Accept-Encoding: gzip,deflate' --output /dev/null  ${req} )"
page2="$(curl -sI  ${req} )"
size2="$(curl -s --write-out '%{size_download}' --output /dev/null  ${req} )"

plan tests 10

note "${reqNote}"
note "Headers Check For Request ${req}"
note "With Curl use accept encoding gzip"
# note "==============="
# note "${page}"
# note "==============="
# note "size: [ ${size} ]"


ok "$(echo $page |  grep -q 'HTTP/2 200')" "should serve HTTP/2 OK "
ok "$(echo $page |  grep -q 'content-type: text/css')" "with gzip-static on then should serve header 'content-type: text/css'"
is "$(echo $page |  grep -oP 'content-encoding: gzip')"  "content-encoding: gzip"  "with gzip-static on then should serve header 'content-encoding: gzip'"
note " nginx sets 'etag on' automatically, seting both etag and last-modified "
ok "$(echo $page |  grep -q 'etag:')" "should serve *etag* header ${etag}"
ok "$(echo $page |  grep -q 'last-modified:')" "should serve *last-modified* header ${lastModified}"
note " nginx declaration 'expires max' sets both expires and cache-control headers"
ok "$(echo $page |  grep -q 'expires:')" "should serve *expires* header"
ok "$(echo $page |  grep -q 'cache-control: max-age=31536000')" "should serve cache-control: max-age=31536000"

note "Headers Check For Request ${req}"
note "With Curl do NOT use accept encoding gzip"
note "We expect gunzip to kick in"
# note "==============="
# note "${page2}"
# note "==============="
# note "size: [ ${size2} ]"

is "$(echo $page2 |  grep 'content-encoding: gzip')" ""  "gunzip should not serve header 'content-encoding: gzip'"
ok "$(echo $page2 |  grep -q 'content-type: text/css')" "gunzip should serve header 'content-type: text/css'"
ok "$( ((${size} < ${size2})) )" "gzip-static size [ ${size} ] should be smaller than gunzip size [ ${size2} ] "

