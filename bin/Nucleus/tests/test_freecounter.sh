#!/bin/sh


function BasicTestClass {

    classname=$1

    freecounter-sysconfig $classname
    assert "Sysconfig failure"
    freecounter-get32 $classname
    assert "Get32 failure"
    freecounter-get64 $classname
    assert "Get64 failure"
    freecounter-multiinit $classname $classname $classname $classname
    assert "Multiinit standard failure"
    freecounter-increase $classname 5
    assert "Increase failure"

}

function ExternalTestClass {

    classname=$1

    BasicTestClass $classname
    freecounter-test $classname continuity
    assert "Continuity failure"
    freecounter-ctl $classname ENABLE_ADIRS_HTR 1
    assert "ENABLE_ADIRS_HTR failure"
    freecounter-ctl $classname ENABLE_ADIRS_TMP 1
    assert "ENABLE_ADIRS_TMP failure"
    freecounter-ctl $classname GET_EXTERNAL_MODE
    assert "GET_EXTERNAL_MODE failure"
}

function TestFC_1_Fake {

    BasicTestClass "fake"

}
TimeoutTestFC_1_Fake=10

function TestFC_2_BadClass {
    freecounter-get32 tititototutu
    assert_failure "Bad class accepted"
}

function TestFC_3_Standard {

    BasicTestClass "standard"
    freecounter-get64 standard-test #with optarg
    assert_failure "standard class accepted with optarg"

}
TimeoutTestFC_3_Standard=10

if [ "$IOTEST_PLF" != "PPC" ]; then

function TestFC_4_ExternalLoop {

    ExternalTestClass "external-loop"

}
TimeoutTestFC_4_ExternalLoop=10

function TestFC_5_ExternalEmu {

    ExternalTestClass "external-emu"

}
TimeoutTestFC_5_ExternalEmu=10

function TestFC_6_ExternalArgs {

    freecounter-multiinit external-emu external-loop
    assert_failure "Several multi-init external accepted"
    freecounter-get32 external-badoptarg
    assert_failure "External class with bad optarg accepted"
    freecounter-get32 external
    assert_failure "External class without optarg accepted"

}

fi
