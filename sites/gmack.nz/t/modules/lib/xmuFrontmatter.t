#!/usr/bin/env bash
while read -r line; do
 echo "$line"
done <  <(curl -s http://localhost:8080/exist/rest/apps/gmack.nz/modules/tap.xq)


