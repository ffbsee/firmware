#!/bin/sh
TESTIP=$(nslookup "ipv6.download.thinkbroadband.com" | grep -oE "^Address .*" | grep -oE '([a-f0-9:]+:+)+[a-f0-9]+')
TESTURL4="http://ipv4.download.thinkbroadband.com/5MB.zip"
TESTURL6="http://ipv6.download.thinkbroadband.com/5MB.zip"
AMOUNT=$((5 * 8))
MYFFGW=$(sockread /var/run/fastd.status < /dev/null 2> /dev/null | sed 's/\(.*\)"name": "gw\([0-9]*\)[^"]*"\(.*\)established\(.*\)/\2/g')
case $MYFFGW in
  01)
    MYFFGWIP="fdef:1701:b5ee:23::1"
    ;;
  02)
    MYFFGWIP="fdef:1701:b5ee:23::2"
    ;;
  03)
    MYFFGWIP="fdef:1701:b5ee:23::3"
    ;;
  04)
    MYFFGWIP="fdef:1701:b5ee:23::4"
    ;;
  *)
    echo "Unknown FF-Gateway: GW"$MYFFGW
    exit
    ;;
esac

echo "Starting WGET-Speedtests"
echo "========================"
echo 

echo "Active FF-Gateway: GW"$MYFFGW
echo 
echo "Starting Download-Tests with $AMOUNT Mbits on " $(date) 
STARTWAN=$(date +%s)
wget -4 -q -O /dev/null $TESTURL4
wgetreturn=$?
if [[ $wgetreturn = 0 ]]; then
 ENDWAN=$(date +%s)
 echo "WAN Download via IPv4 done"
else
 echo "ERROR: Wan-Wget-Download via IPv4 failed."
 STARTWAN=$(date +%s)
 wget -6 -q -O /dev/null $TESTURL6
 if [[ $wgetreturn = 0 ]]; then
  ENDWAN=$(date +%s)
  echo "WAN Download via IPv6 done."
 else
  echo "ERROR: Wan-Wget-Download via IPv6 failed, too."
  exit
 fi
fi

DURATIONWAN=$(awk "BEGIN {print $ENDWAN - $STARTWAN}")
RESULTWAN=$(awk "BEGIN {print $AMOUNT/$DURATIONWAN}")

echo "WAN: "$AMOUNT "Mbit in " $DURATIONWAN " seconds."
echo "That's " $RESULTWAN "Mbit/s."
echo

echo "Pinging my Gateway: $MYFFGW at $MYFFGWIP"
GWPING=$(ping -I br-freifunk -c 3 -n $MYFFGWIP | grep "round-trip min" | grep -oE '([0-9][0-9\.\/]*)' | sed -r 's/[0-9\.]+\/([0-9\.]+)\/[0-9\.]+/\1/g')

echo "Initiating Wget-Speedtest via br-freifunk"
ip route add $TESTIP/128 via $MYFFGWIP
STARTFF=$(date +%s)
wget -6 -q -O /dev/null $TESTURL6
wgetreturn=$?
if [[ $wgetreturn = 0 ]]; then
 ENDFF=$(date +%s)
 echo "FF Download Done"
 ip route del $TESTIP/128 via $MYFFGWIP
else
 echo "ERROR: FF-Wget-Download failed.($wgetreturn)"
 ip route del $TESTIP/128 via $MYFFGWIP
 exit
fi

DURATIONFF=$(awk "BEGIN {print $ENDFF - $STARTFF}")
RESULTFF=$(awk "BEGIN {print $AMOUNT/$DURATIONFF}")

echo "FF: "$AMOUNT "Mbit in " $DURATIONFF " seconds."
echo "That's " $RESULTFF "Mbit/s."
echo
echo "All Download-Tests finished. " $(date) 
echo 

if [ "$1" = "-w" ]; then
  echo $RESULTFF > /tmp/log/last_speedtest_ff_mbps.txt
  echo $RESULTWAN > /tmp/log/last_speedtest_wan_mbps.txt
  echo $GWPING > /tmp/log/last_gwping.txt
  echo $STARTWAN > /tmp/log/last_speedtest_ts.txt
fi
