#!/bin/sh

read QUERY_STRING
eval $(echo "$QUERY_STRING" | awk -F'&' '{for(i=1; i <= NF; i++) { print $i }}')

echo -n $(httpd -d $passphrase) > /lib/cryptsetup/passfifo

for i in $(seq 10); do
  sleep 1
  echo $i

  [ -f /dev/mapper/root ] && exit 0
done

cat index.html | sed '/TPL:ERROR/d'

exit 0
