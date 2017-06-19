#!/bin/sh


function TestTimer_1_BadClass {

    timer -t badclass
    assert_failure "Bad class is accepted"

}

function TestTimer_2_USleep {

    timer --class best --delay 3000 --loop 1000 --usleep
    assert "USleep failed"

}
TimeoutTestTimer_2_USleep=30

function TestTimer_3_Select {

    timer --class best --delay 3000 --loop 1000 --select
    assert "Select failed"

}
TimeoutTestTimer_3_Select=30