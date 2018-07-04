#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub
headersFile='.tmp/headers.txt'
file='file=@resources/images/60/gmacknz.png'
if [ -e $headersFile ];then rm $headersFile;fi
curl -s \
 -H "$auth" \
 --http1.1 \
 -F "$file" \
 --write-out  %{http_code} \
 --dump-header "$headersFile"  \
 $req > /dev/null

headers="$(< $headersFile)"

#####################

plan tests 2

note "==============="
note "$WEBSITE"
note "${headers}"
note "==============="

ok "$(grep -q 'HTTP/1.1 201 Created' $headersFile)" \
   "HTTP/1.1 201 Created"
ok "$(grep -q '^Location:\s(.+)$' $headersFile)" \
   "should have a location header: $(grep -oP '^Location:\s(.+)$' $headersFile)"





