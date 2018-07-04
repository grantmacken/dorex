#!/usr/bin/env bash
source t/setup
use Test::More


# tail -f  ${OPENRESTY_HOME}/nginx/logs/error.log |grep --line-buffered -oP '^.+\K\[lua\].+$$' | cut -d ',' -f1
# prove t/ 


auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
req=${WEBSITE}/micropub
headersFile='.tmp/page-headers'
bodyFile='.tmp/page-body'
statusFile='.tmp/page-status'

##################################
# micropub endpoint
# These tests check how my micropub endpoint
# handles receiving and processing micropub POSTS that mention/comment another POST located somewhere else.
# "A reply (or comment) is a kind of post "    https://indieweb.org/reply
# Reply posts have are established by having a in-reply-to property in the entry
# After storing the entry on my site,
# we attempt to send a webmention to the mentioned site,
# by using the in-reply-to url link. 
# Workflow
# 1. do Webmention endpoint discovery on that link
# 2. send a Webmention using the endpoint with source and target parameters
#  - source  -- my page with my link mentioning some other page somewhere else
#  - target  -- the link to the other page

function mpReply () {
  local fBody="${bodyFile}${1}"
  local fHeaders="${headersFile}${1}"
  local fStatus="${statusFile}${1}"
  if [ -e $fBody ] ;then rm $fBody ; fi
  if [ -e $fHeaders ] ;then rm $fHeaders ; fi
  if [ -e $fStatus ] ;then rm $fStatus ; fi

  curl -s \
    -H "$auth" \
    -d 'h=entry' \
    -d "content=${2}" \
    -d "in-reply-to=${3}" \
    --output "${fBody}"\
    --write-out  %{http_code} \
    --dump-header "${fHeaders}" \
    $req > $fStatus
}

function mpNote () {
  local fBody="${bodyFile}${1}"
  local fHeaders="${headersFile}${1}"
  local fStatus="${statusFile}${1}"
  if [ -e $fBody ] ;then rm $fBody ; fi
  if [ -e $fHeaders ] ;then rm $fHeaders ; fi
  if [ -e $fStatus ] ;then rm $fStatus ; fi

  curl -s \
    -H "$auth" \
    -d 'h=entry' \
    -d "content=${2}" \
    --output "${fBody}"\
    --write-out  %{http_code} \
    --dump-header "${fHeaders}" \
    $req > $fStatus
}

function mpSendMention () {
  local url="${WEBSITE}/webmention"
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
    $url > $fStatus
}

# echo $(cat '.tmp/page-headers.txt' | grep -oP '^location:\s\K(.+)$' ) 

 # echo $(cat '.tmp/page-headers.txt' | grep -oP '^location:\s\K(.+)$' ) > .tmp/location.txt
########################################################################################### 
# https://indieweb.org/reply
# https://indieweb.org/Webmention-developer
# procedure outline
# 1. Post note on your my site    - return 201 + location of post
# 2. Post a reply to the original
#    - use location   
#    - reply has in-reply-to property
# 3. Server -  creates and stores entry
#           -  include author information in your reply post
# 3. Server -  sees link in in-reply-to link property
#           -  discovers webmention endpoint from link
#           -  verifies link
#           -  sends webmention to endpoint

# mpNote '1'  'note test 1, talk to the hand' && sleep 1
#         my sites page  .....                                              some other page I mentioned
#    ID  'a reply' a kind of post mentioning another page                              in-reply-to link
# mpReply "2"  "reply test 2, Hi hand" "$( grep -oP '^location:\s\K(.+)$' ${headersFile}1 )"
# mpReply "2"  "reply test 1 " 'https://gmack.nz/n4m51'
# note  - the above creates a reply, but resty-http sends webmenton to remote IP
# so we curl the webmention to mock sending to local IP
#             ID   source                    target
mpSendMention "3" "https://gmack.nz/r4m51" "https://gmack.nz/n4m51" 

# mpReply "3"  "reply test 1 " 'https://webmention.rocks/test/1'
 # get '2'  'test 2,  data stored in eXistdb, proxied behind openResty' 'https://webmention.rocks/test/2'

#####################
plan tests 1

note "==============="
note " website: $WEBSITE"
note " status:  $(cat ${statusFile}3 )"
note "==============="
note '    HEADERS    '
note "==============="
note "$(cat ${headersFile}3 )"
note "==============="
note '    BODY    '
note "==============="
note "$(cat ${bodyFile}3 )"
note "==============="

# note "a note on my own site"
# is "$( head -1 ${statusFile}1 )" "201" "should serve HTTP/2 201"
# is "$( grep -oP '^location' ${headersFile}1 )" "location" "should have location header: $( grep -oP '^location:\s\K(.+)$' ${headersFile}1 )"
# note "a reply on my own site commenting on:  $( grep -oP '^location:\s\K(.+)$' ${headersFile}1 )"
note "a reply on my own site commenting on:  $( grep -oP '^location:\s\K(.+)$' ${headersFile}1 )"
is "$( head -1 ${statusFile}3 )" "201" "should serve HTTP/2 201 $( head -1 ${statusFile}3 )"
# ok "$(test -n $location)" "should serve header location $location"
# ok "$(echo $headers |  grep -q 'HTTP/2 201')" "should serve HTTP/2 201"







