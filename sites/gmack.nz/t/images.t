#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"

req=${WEBSITE}/images/60/gmacknz 
reqNote='Fetch the site owners profile photo'
page="$(curl -sI ${req} )"
etag="$(curl -sI $req | grep -oP '^etag: \K.+$')"
lastModified="$(curl -sI $req | grep -oP '^last-modified: \K.+$')"
file="build/resources/images/60/gmacknz.png"
# page2="$(curl -sI -H 'If-None-Match: ${etag}' $req)"

plan tests 6

note "${reqNote}"
note "Image Headers Check For Request ${req}"
# note "==============="
# note "${page}"
# note "==============="

ok "$(echo $page |  grep -q 'HTTP/2 200')" "should serve HTTP/2 OK "
ok "$(echo $page |  grep -q 'content-type: image/png')" "should serve header 'content-type: image/png'"
note " nginx sets 'etag on' automatically, seting both etag and last-modified "
ok "$(echo $page |  grep -q 'etag:')" "should serve *etag* header ${etag}"
ok "$(echo $page |  grep -q 'last-modified:')" "should serve *last-modified* header ${lastModified}"
note " nginx declaration 'expires max' sets both expires and cache-control headers"
ok "$(echo $page |  grep -q 'expires:')" "should serve *expires* header"
ok "$(echo $page |  grep -q 'cache-control: max-age=31536000')" "should serve cache-control: max-age=31536000"


