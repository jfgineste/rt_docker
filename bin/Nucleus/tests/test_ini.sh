#!/bin/sh

if [ "$IOTEST_OS" = "LINUX" ]; then

function TestIni_1_Global {

    iniparser_get "./sample.ini" group1 -k key2
    assert "Cannot get group1 key2"
    iniparser_get "./sample.ini" -b group1 -k key2
    assert "Cannot get group1 key2 while buffering"
    iniparser_get "./sample.ini" -b group1
    assert "Cannot get group1 while buffering"

    iniparser_get "./sample.ini" xzsjhck
    assert_failure "No error reading invalid group!"
    iniparser_get "./sample.ini" group1 -k sdokhsoh
    assert_failure "No error reading invalid key!"
    iniparser_get "vjklsjhv" group1 -k key2
    assert_failure "No error reading invalid file name!"

}

fi
