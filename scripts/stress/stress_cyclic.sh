cyclictest -q -t1 -p 80 -i 10000 -l 10000 -n 2>&1 > stress_cyclic &
p_cyclic=$!
#p_ping=$(ps -ef | grep 'ping' | grep -v 'grep' | awk '{ printf $2 }')
kill -STOP $p_cyclic
chrt -f -p 87 $p_cyclic
#stress -c 2 -i 2 -m 2
kill -CONT $p_cyclic
