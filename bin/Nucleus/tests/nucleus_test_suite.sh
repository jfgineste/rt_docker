#!/bin/sh

export iotest_log=/tmp/nucleustests.log
. ./iotest.sh

export PATH=`pwd`/../bin:$PATH

. ./test_timer.sh
. ./test_cpu.sh
. ./test_freecounter.sh
if [ "$IOTEST_PLF" != "PPC" ]; then
. ./test_ini.sh
fi

iotest_main $*
