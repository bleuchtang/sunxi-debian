#!/bin/sh
read QUERY_STRING
eval $(echo "$QUERY_STRING"|awk -F'&' '{for(i=1;i<=NF;i++){print $i}}')
tmp=`httpd -d $Text_Field`
echo -ne $tmp >/lib/cryptsetup/passfifo
i=0
while true; do
  sleep 1
  i=$(($i + 1))
  echo $i
  if [ -f /dev/mapper/root ] ; then
    echo "<html>"
    echo "  <head>"
    echo "    <title>Unlock root partition</title>"
    echo "  </head>"
    echo ""
    echo "  <body>"
    echo "    <div style='text-align: center;'><IMG SRC='../unicorn.gif' ALT='image'>"
    echo "      Disk unlock !!"
    echo "    </div>"
    echo "  </body>"
    echo "</html>"
    exit 0
  elif [ ${i} -gt 10 ] ; then
    cat ../index.html
    exit 0
  fi
done

exit 0
