#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $SITE_ACCESS_TOKEN"
# echo $auth
req=${WEBSITE}/micropub

hEntry='h=entry'

content1='content=Micropub test of creating a basic h-entry' 
#107: Create an h-entry post with one category (form-encoded)
content2='content=Micropub test of creating an h-entry with one category. This post should have one category, test1'
#107: Create an h-entry post with two categories (form-encoded)
content3='content=Micropub test of creating an h-entry with categories. This post should have two categories, test1 and test2'
cat1='category[]=test1'
cat2='category[]=test2'

### 500: Delete a post (form-encoded)
content4='content=This post will be deleted when the test succeeds.' 

# page="$(curl -sI -H 'Accept-Encoding: gzip' ${req} )"
# size="$(curl -s --write-out '%{size_download}' -H 'Accept-Encoding: gzip,deflate' --output /dev/null  ${req} )"
# page2="$(curl -sI  ${req} )"
# size2="$(curl -s --write-out '%{size_download}' --output /dev/null  ${req} )"

curl -s \
 -H "$auth" \
 -d 'h=entry' \
 -d "${content4}" \
 --output '.tmp/page.html' \
 --write-out  %{http_code} \
 --dump-header '.tmp/page-headers.txt' \
 $req > /dev/null  && \
 echo $(cat '.tmp/page-headers.txt' | grep -oP '^location:\s\K(.+)$' ) > .tmp/location.txt

# page=$(cat .tmp/page.html)
# headers=$(cat .tmp/page-headers.txt)
location="$(cat .tmp/location.txt)"
page=$(cat .tmp/page.html)
headers=$(cat .tmp/page-headers.txt)

#####################

# location=$( curl -s \
#  -H "$auth" \
#  -d "$hEntry"\
#  -d "${content4}" \
#  $req | grep -oP '^location:\s\K(.+)$')


# page=$( curl -s \
#  -o .tmp/created.html \
#  -w %{http_code}  \
#  --dump-header .tmp/created-header.txt \
#  $location )

# page=$( curl -s -i \
#  -H "$auth" \
#  -d "action=undelete"\
#  -d "url=https://gmack.nz/n4ju1" \
#  $req )

#####################

plan tests 1

note "==============="
note "$WEBSITE"
note "==============="
note "${page}"
note "==============="
note "${headers}"
note "==============="
note "${location}"
note "==============="

ok "$(test -n $location)" "should serve header location $location"

# is "$(curl -s --write-out '%{http_code}' --output /dev/null  ${WEBSITE} )" "200" "${WEBSITE} status should be 200 OK"
# is "$(curl -s --write-out '%{http_code}' --output /dev/null  ${WEBSITE}/${pageID} )" "200" "${WEBSITE}/${pageID} status should be 200 OK"




# is $( curl -s -i \
#  -H "$auth" \
#  -d 'h=entry' \
#  -d "$content1" \
#  $req | head -n 7 | grep -oP '^location:')  "location:" "should serve header: location "







