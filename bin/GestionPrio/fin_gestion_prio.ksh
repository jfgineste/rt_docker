#!/bin/ksh

for file in /proc/irq/*/smp_affinity ; do
    echo "/bin/echo ff > ${file}"
    /bin/echo ff > ${file}
done

for pid in `ps ax -o pid,cmd | grep -i "irq.[0-9]\{1,\}" | grep -v sirq | awk '{print $1}'`; do
    echo "chrt -p -f 50 ${pid} ("`ps -o cmd ${pid} | tail -1`")"
    chrt -p -f 50 ${pid} 2> /dev/null || echo "KO"
done

# Restore initial priorities on kernel 3.10
KERNEL_RELEASE=`uname -r`
case ${KERNEL_RELEASE} in
    3.10.0-nh* )
        prio_os_kworker=0
        for pid in `ps ax -o pid,cmd | grep -i "\[kworker/.*\]" | grep -v grep | awk '{print $1}'`; do
            echo "chrt -p -o ${prio_os_kworker} ${pid} ("`ps -o cmd ${pid} | tail -1`")"
            chrt -p -o ${prio_os_kworker} ${pid} 2> /dev/null || echo "KO"
        done

        prio_os_posixcputmr=99
        for pid in `ps ax -o pid,cmd | grep -i "\[posixcputmr/.*\]" | grep -v grep | awk '{print $1}'`; do
            echo "chrt -p -f ${prio_os_posixcputmr} ${pid} ("`ps -o cmd ${pid} | tail -1`")"
            chrt -p -f ${prio_os_posixcputmr} ${pid} 2> /dev/null || echo "KO"
        done

        prio_os_rtkit=99
        pid=`ps ax -o pid,cmd | grep -i "rtkit-daemon" | awk '{print $1}' | head -1`
        echo "chrt -p -f ${prio_os_rtkit} ${pid} ("`ps -o cmd ${pid} | tail -1`")"
        chrt -p -f ${prio_os_rtkit} ${pid} 2> /dev/null || echo "KO"

        prio_os_hrtimer_rt=1
        for pid in `ps ax -o pid,cmd | grep -i "\[sirq-tmr-rt/.*\]" | grep -v grep | awk '{print $1}'`; do
            echo "chrt -p -f ${prio_os_hrtimer_rt} ${pid} ("`ps -o cmd ${pid} | tail -1`")"
            chrt -p -f ${prio_os_hrtimer_rt} ${pid} 2> /dev/null || echo "KO"
        done
        ;;
esac

