#!/usr/bin/env bash
while read -r line; do
 echo "$line"
done <  <(w3m -dump http://localhost:8080/exist/rest/apps/gmack.nz/modules/tap.xq?mod=modules/lib/oAuth.xqm
)


