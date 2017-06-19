#!/bin/sh

function TestCpu_1_GetNb {

    cpu getnb
    assert "Failed to get the number of cpu"

}

if [ "$IOTEST_PLF" != "PPC" ]; then

if [ "$IOTEST_OS" != "WINDOWS" ]; then

function TestCpu_2_Tags {

    # Simple list
    cpu tag list
    assert "Tag: cpu listing failed"

    # Tag creation
    cpu tag create first
    assert "Tag: create first failed"
    cpu tag create second
    assert "Tag: create second failed"
    cpu tag create third
    assert "Tag: create third failed"

    # Set tags
    cpu tag set first 0
    assert "Tag: set first failed"
    cpu tag set second 1
    assert "Tag: set second failed"
    cpu tag set third 0,1
    assert "Tag: set third failed"

    # Check that tags are _really_ created (all/by cpu)
    cpu tag list | grep -q "Existing tags : first second third \$"
    assert "Tag: tags not really created"
    cpu tag list-by-cpu 0 | grep -q "Existing tags on CPU 0 : first third \$"
    assert "Tag: tags by cpu not working"

    # Check that tags are _really_ created (by tag name)
    cpu tag get first | grep -q "Tag 'first' contains CPU : 0 \$"
    assert "Tag: tag first is invalid"
    cpu tag get second | grep -q "Tag 'second' contains CPU : 1 \$"
    assert "Tag: tag second is invalid"
    cpu tag get third | grep -q "Tag 'third' contains CPU : 0 1 \$"
    assert "Tag: tag third is invalid"

    # Delete tags
    cpu tag delete first
    assert "Tag: delete first failed"
    cpu tag delete second
    assert "Tag: delete second failed"
    cpu tag delete third
    assert "Tag: delete third failed"

    # Check cleanup
    cpu tag list | grep -q "Existing tags : \$"
    assert "Tag: bad clean"
    cpu thread list 1 | grep -q "Listing threads of pid 1 : 1 \$"
    assert "Tag: bad thread listing"

}

fi # not WINDOWS

function TestCpu_3_Bind {

    if [ "$IOTEST_OS" = "WINDOWS" ]; then
        sleep 1000 &
        MYPID=$!
    else
        sleep 1000 &
        MYPID=$!
    fi

    if [ -e /dev/cpuset/tasks ]; then
        /bin/echo $MYPID > /dev/cpuset/tasks
        assert "Bind: Unable to reset cpuset affinity"
    elif [ "$IOTEST_OS" = "LINUX" ]; then
        taskset -p ff $MYPID
        # No test on return value : always true ;-(
        # assert "Bind: Unable to reset taskset affinity"
    else
        # On windows XP, there is no way to spêcify a task affinity by command
        # line. So, we hope that the test script is launched without any
        # particular process affinity.
        # Note that on Windows > Windows 7, we can use the /affinity flag of
        # the "start" command
        :
    fi
    cpu bind get $MYPID
    assert_failure "Bind: bind get cpu0+cpu1 should not success"

    cpu bind set $MYPID 0
    assert "Bind: bind set cpu0 failed"
    cpu bind get $MYPID | grep -q "Pid $MYPID is on cpu : 0\$"
    assert "Bind: bind get cpu0 failed"
    cpu bind set $MYPID 1
    assert "Bind: bind set cpu1 failed"
    cpu bind get $MYPID | grep -q "Pid $MYPID is on cpu : 1\$"
    assert "Bind: bind get cpu1 failed"

    kill $MYPID

}


if [ "$IOTEST_OS" != "WINDOWS" ]; then

function TestCpu_4_Protect {

    cpu protect 1
    assert "Protect: Cannot protect cpu1"
    MYPID=$$
    cpu bind set $MYPID 0
    assert "Protect: Cannot bind to cpu0"
    cpu bind get $MYPID | grep -q "Pid $MYPID is on cpu : 0\$"
    assert "Protect: Cannot get cpu binding (cpu0)"
    cpu bind set $MYPID 1
    assert "Protect: Cannot bind to cpu1"
    cpu bind get $MYPID | grep -q "Pid $MYPID is on cpu : 1\$"
    assert "Protect: Cannot get cpu binding (cpu1)"
    cpu unprotect 1
    assert "Protect: Cannot unprotect cpu1"

}

fi # not WINDOWS

fi # not PPC
