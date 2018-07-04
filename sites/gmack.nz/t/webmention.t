#!/usr/bin/env bash
source t/setup
use Test::More

req=${WEBSITE}/webmention
headersFile='.tmp/page-headers'
bodyFile='.tmp/page-body'
statusFile='.tmp/page-status'

##################################
# These tests checks how my webmention endpoint handles RECEIVING webmentions
# incoming webmentions will have a 
# source  -- The URL of somebody elsewhere mentions something on my site
# target  -- the URL on my site that us mentioned by somebody elsewhere in their source

function get () {
  local fBody="${bodyFile}${1}"
  local fHeaders="${headersFile}${1}"
  local fStatus="${statusFile}${1}"
  if [ -e $fBody ] ;then rm $fBody ; fi
  if [ -e $fHeaders ] ;then rm $fHeaders ; fi
  if [ -e $fStatus ] ;then rm $fStatus ; fi

  curl -s \
    -d "source=${2}" \
    -d "target=${3}" \
    --output "${fBody}"\
    --write-out  %{http_code} \
    --dump-header "${fHeaders}" \
    $req > $fStatus
}

function getNoTarget () {
  local fBody="${bodyFile}${1}"
  local fHeaders="${headersFile}${1}"
  local fStatus="${statusFile}${1}"
  if [ -e $fBody ] ;then rm $fBody ; fi
  if [ -e $fHeaders ] ;then rm $fHeaders ; fi
  if [ -e $fStatus ] ;then rm $fStatus ; fi

  curl -s \
    -H "$auth" \
    -d "source=${2}" \
    --output "${fBody}"\
    --write-out  %{http_code} \
    --dump-header "${fHeaders}" \
    $req > $fStatus
}

#  https://www.w3.org/TR/webmention/#h-receiving-webmentions
# Upon receipt of a POST request containing the source and target parameters, the receiver SHOULD verify the parameters

#        somebody mentions  ..... sommething I said
#    ID  SOURCE                  TARGET
getNoTarget '1' 'https://www.gmack.nz/r4kr1'
# src invalid urls
get '2' 'htt://webmention.rocks/test/3' 'https://www.gmack.nz/n4kr1'
get '3' 'https://webmention.rocks/test/3' 'https://gmack/n4kr1'
# same uri
get '4' 'https://www.gmack.nz/r4kr1' 'https://www.gmack.nz/r4kr1'
# target not a resource on my site ( ID not extractable )
get '5' 'https://webmention.rocks/test/3' 'https://www.gmack.nz/xxxxx'
# target not a resource on my site ( ID extractable but resource not in db )
get '6' 'https://webmention.rocks/test/3' 'https://gmack.nz/r4kr7'
# Webmention Verification
get '7' 'https://webmention.rocks/test/3' 'https://gmack.nz/r4kr1'
# get '2V' 'https://webmention.rocks/test/3' 'https://www.gmack.nz/xxxx'

plan tests 7

note "==============="
note "$WEBSITE"
note "$(cat ${bodyFile}7 )"
note "==============="
note "$(cat ${headersFile}7 )"
note "==============="
note "$(cat ${bodyFile}7 )"
note "==============="

note "webmention SHOULD have 2 POST args 'source' and 'target'"
ok "$( grep -q 'HTTP/2 400' ${headersFile}1 && echo 0 || echo 1 )" "should serve HTTP/2 400: $(cat ${bodyFile}1 )"
note "receiver MUST check that source and target are valid URLs"
is "$( head -1 ${statusFile}2 )" "400" "should serve HTTP/2 400: $(cat ${bodyFile}2 )"
is "$( head -1 ${statusFile}3 )" "400" "should serve HTTP/2 400: $(cat ${bodyFile}3 )"
is "$( head -1 ${statusFile}4 )" "400" "should serve HTTP/2 400: $(cat ${bodyFile}4 )"
is "$( head -1 ${statusFile}5 )" "400" "should serve HTTP/2 400: $(cat ${bodyFile}5 )"
is "$( head -1 ${statusFile}6 )" "400" "should serve HTTP/2 400: $(cat ${bodyFile}6 )"
note "Webmention Verification"
is "$( head -1 ${statusFile}7 )" "200" "should serve HTTP/2 200: GOT status  $( head -1 ${statusFile}7  ) "




