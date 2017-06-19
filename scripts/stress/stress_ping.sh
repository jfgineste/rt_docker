ping 10.2.239.76 &
p_ping=$!
#p_ping=$(ps -ef | grep 'ping' | grep -v 'grep' | awk '{ printf $2 }')
kill -STOP $p_ping
chrt -f -p 90 $p_ping
#stress -c 2 -i 2 -m 2
kill -CONT $p_ping
