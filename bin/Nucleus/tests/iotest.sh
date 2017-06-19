#!/bin/sh

ROOT_PID=$$

case `uname -s` in

    Linux)
        export IOTEST_OS="LINUX"
        export IOTEST_USER=`id -un`
        ;;
    LynxOS)
        export IOTEST_OS="LYNXOS"
        export IOTEST_USER=`whoami`
        ;;
    *NT*)
        export IOTEST_OS="WINDOWS"
        export IOTEST_USER=`id -un`
        ;;
    *)
        echo 'ERROR: Unsupported OS type: uname -s = "'`uname -s`'"'
        exit 1
        ;;
esac

case `uname -m` in

    ppc|PowerPC)
        export IOTEST_PLF="PPC"
        export IOTEST_CPU="ppc"
        ;;

    x86_64|i?86)
        export IOTEST_PLF="PC"
        export IOTEST_CPU=`uname -i`
        ;;
    *)
        echo 'ERROR: Unsupported machine type: uname -m = "'`uname -m`'"'
        exit 1
        ;;
esac

if [ "$iotest_log" != "" ]; then
    log_file="$iotest_log"
else
    log_file=./iotest.log
fi
#=========================================================
#Functions to handle xml report
#=========================================================
#Xml file tags
export HEAD_LABEL="TestCases"
export TEST_LABEL="TestCase"
export STEP_LABEL="Step"
export TITLE_LABEL="Name"
export DESC_LABEL="Purpose"
export REF_LABEL="Reference"

#Names of the variables to describe the tests
export var_Title="Titre"
export var_Description="Description"
export var_Requirement="Exigence"

#Xml report specific variables
start_time=$SECONDS
cur_test=""
tmp_xml_file_save=""

#functions
#Saving the name of the temporary file is required to test the library within itself (non-regression tests)
function init_tmp_xml {
if [ ! -z $tmp_xml_file ];then
    tmp_xml_file_save="$tmp_xml_file"
fi
export tmp_xml_file="/tmp/iotest_xml_file_`date +%Y%m%d-%Hh%Mm%Ss`_$$.tmp"
}

function restore_tmp_xml {
if [ ! -z $tmp_xml_file_save ];then
    tmp_xml_file="$tmp_xml_file_save"
fi
}

function get_test_duration {
    test_duration=$(($SECONDS - $1))
    let hours=$test_duration/3600
    let minutes=$test_duration%3600/60
    let seconds=$test_duration%60
    format_duration="${hours}h:${minutes}mn:${seconds}s"
    echo "$format_duration"
}

function get_test_name {
    title=`eval echo \\\$$var_Title$cur_test`
    if [ ! -z "$title" ]; then
	echo "        <$TITLE_LABEL>$title</$TITLE_LABEL>"  >>  $xml_file
    fi
}


function get_test_purpose {
    desc=`eval echo \\\$$var_Description$cur_test`
    if [ ! -z "$desc" ]; then
	echo "        <$DESC_LABEL>$desc</$DESC_LABEL>"  >>  $xml_file
    fi
}

function get_test_references {
    reqs=`eval echo \\\$$var_Requirement$cur_test`
    if [ ! -z "$reqs" ]; then
	IFS=';'; req_array=($reqs)
	for req in "${req_array[@]}"; do
	    echo "            <$REF_LABEL>$req</$REF_LABEL>"  >>  $tmp_xml_file
	done
    fi
}

#function to create the header the end of the xml report
function init_xml_report {
    if [ ! -z "$xml_file" ]; then
	init_tmp_xml
	(
	echo "<!-- Xml test report file -->"
	echo "<!-- Generated date : `date \"+%D at %T\"` -->"
	echo "<!-- Author : `whoami` -->"
	echo "<!-- Environment : `hostname` ($OSREL) -->"
	echo "<!-- Command line : \"$COMMAND_LINE\" -->"
	echo "<$HEAD_LABEL>" ) >  $xml_file
    fi
}

function close_xml_report {
    if [ ! -z "$xml_file" ] && [ -e $xml_file ]; then
	restore_tmp_xml
	echo "</$HEAD_LABEL>" >>  $xml_file
    fi
}

#Functions to report a test in xml file
function init_test_xml_report {
    if [ ! -z "$xml_file" ] && [ -e $xml_file ]; then
	echo "    <$TEST_LABEL ID=\"$1\">" >>  $xml_file
	cur_test="$1"
    	if [ "$IOTEST_OS" != "LYNXOS" ];then
    	    start_time=`date +%s`
	else
	    start_time=`date "+%j;%k;%m;%S"`
	fi
	start_time=$SECONDS
    fi
}

function close_test_xml_report {
    if [ ! -z "$xml_file" ] && [ -e $xml_file ]; then
        dur="`get_test_duration $start_time`"
	(
	get_test_name
	get_test_purpose
	echo "        <Duration>$dur</Duration>"
	echo "        <Result>$1</Result>"
	if [ -e $tmp_xml_file ]; then
	    cat $tmp_xml_file
	fi
	echo "    </$TEST_LABEL>" ) >>  $xml_file
	if [ -e $tmp_xml_file ]; then
		rm $tmp_xml_file
	fi
    fi
}

#function for a test step in xml file
#Use of temprorary file is to organize the tags of the xml report
function step_test_xml_report {
    if [ ! -z "$xml_file" ] && [ -e $xml_file ]; then
	(
	echo "        <$STEP_LABEL ID=\"$1\">"
	get_test_references
	echo "            <Result>$2</Result>"
	echo "        </$STEP_LABEL>" ) >>  $tmp_xml_file
    fi
}


opt_profil=0

#=========================================================
#Tests Functions
#=========================================================
function assert {
    ret=$?
    res="Success"
    if [ "$ret" != "0" ]; then
        echo "Assertion failed: $1 (error $ret)"
        export ASSERT_ERROR="1"
	res="Failure"
    fi
    step_test_xml_report "$1" $res
}

function assert_failure {
    ret=$?
    res="Success"
    if [ "$ret" = "0" ]; then
        echo "Assertion should have failed: $1"
        export ASSERT_ERROR="1"
	res="Failure"
    fi
    step_test_xml_report "$1" $res
}

function list_tests {
    if [ ! -z "$filter_include" -a ! -z "$filter_exclude" ]; then
        typeset -F | sed 's/declare -f //' | grep "^Test" | grep "$filter_include" | grep -v "$filter_exclude" | sort
    elif [ ! -z "$filter_include" ]; then
        typeset -F | sed 's/declare -f //' | grep "^Test" | grep "$filter_include" | sort
    elif [ ! -z "$filter_exclude" ]; then
        typeset -F | sed 's/declare -f //' | grep "^Test" | grep -v "$filter_exclude" | sort
    else
        typeset -F | sed 's/declare -f //' | grep "^Test" | sort
    fi
}

function get_setup_test {
    typeset -F | sed 's/declare -f //' | grep -x "Setup$1"
}

function setup_test {
    func=`get_setup_test $1`
    if [ ! -z "$func" ]; then
        $func
    fi
}

function get_cleanup_test {
    typeset -F | sed 's/declare -f //' | grep -x "Cleanup$1"
}

function cleanup_test {
    func=`get_cleanup_test $1`
    if [ ! -z "$func" ]; then
        $func
    fi
}

function get_timeout_test {
    timeout=`eval echo \\\$Timeout$1`
    if [ "$timeout" -eq "$timeout" -a "$timeout" -ge "0" ] 2>/dev/null ; then
        # This is a valid number
        echo $timeout
    else
        # No timeout defined, or empty, or not a valid number, or negative
        # default value is 0 = infinite
        echo 0
    fi
}

function do_test {
    the_test=$1

    ASSERT_ERROR="0"
    setup_test $the_test
    set -x
    $the_test
    set +x
    cleanup_test $the_test
    exit $ASSERT_ERROR
}

function launch_test {
    export TEST_TIMEOUT=`get_timeout_test $1`
    echo "Configured timeout: $TEST_TIMEOUT s (0 means infinite)"
    do_test $1 &
    export TEST_PID=$!
}



function pid_exists {
    if [ $IOTEST_OS = "WINDOWS" ]; then
        ps -s | awk '{print $1}' | grep -q $1
    elif [ $IOTEST_OS = "LYNXOS" ]; then
        [ `ps -p $1 | wc -l` = "3" ]
    else
        ps $1 > /dev/null 2>&1
    fi
    if [ "$?" = "0" ]; then
        echo "YES"
    else
        echo "NO"
    fi
}

function export_test_result {
#variable TEST_RESULT_XML  prevent the  suppression of characters " ***" in shell Lynx for format xml
  if [ "$1" = "TIMEOUT" ]; then
      export TEST_RESULT="Timeout ***"
      export TEST_RESULT_XML="Timeout"
      export GLOBAL_RESULT="FAILURE"
  elif [ "$1" = "0" ]; then
      export TEST_RESULT="Success"
      export TEST_RESULT_XML="Success"
  else
      export TEST_RESULT="Failure ***"
      export TEST_RESULT_XML="Failure"
      export GLOBAL_RESULT="FAILURE"
  fi
}

function wait_test_end {

    if [ "$TEST_TIMEOUT" = "0" ]; then
      wait $TEST_PID
      export_test_result "$?"
    else
      loop="0"
      while [ "$loop" -le "$TEST_TIMEOUT" ]; do
          loop=$(($loop + 1))
          if [ `pid_exists $TEST_PID` != "YES" ]; then
            # Test has ended
            wait $TEST_PID
            export_test_result "$?"
            return
          fi
          sleep 1
      done
      # Timeout !
      # We kill it !
      export_test_result "TIMEOUT"
      kill -9 $TEST_PID
      wait $TEST_PID
    fi
}

function do_run {
    export RESULTAT="SUCCESS"
    export TEST_TIMEOUT="NO"
    if [ $opt_profil -eq 0 ];then
	list=`list_tests`
    else
	echo "-------------Tests Profils to be run :-----------------------"
	check_all_profils
	print_profils
	list=`list_all_profils_tests | sort -u `
    fi


    wc_list=`echo "$list" | wc -w | awk '{print $1}'`
    cur=0

    if [ -e $log_file -a ! -w $log_file ]; then
        echo "Error: log file $log_file is not writable."
        printf "*** [%s] FAILURE ***\n" "`date +"%F %T"`"
        exit -1
    fi
    if [ ! -z "$xml_file" ] && [ -e $xml_file -a ! -w $xml_file ]; then
	  echo "Error: xml result file $xml_file is not writable."
	  printf "*** [%s] FAILURE ***\n" "`date +"%F %T"`"
	  exit -1
    fi

    init_xml_report

    echo "Start testing... Logs are recorded to file : " $log_file
    (
    echo "================================================================================"
    echo "====> Starting tests on :"
    echo " hostname: " `hostname`
    echo " uname -a: " `uname -a`
    echo " date    : " `date`
    echo " user    : " $IOTEST_USER ) >> $log_file
    export GLOBAL_RESULT="SUCCESS"
    for the_test in $list ; do
        init_test_xml_report $the_test
        cur=`expr $cur + 1`
        printf "[%s] Starting test  %3i/$wc_list : $the_test\n" "`date +"%F %T"`" "$cur" 2>&1 | tee -a $log_file
        launch_test $the_test >> $log_file 2>&1
        wait_test_end >> $log_file 2>&1
        printf "[%s] Result of test %3i/$wc_list : %-40s %s\n" "`date +"%F %T"`" "$cur" "$the_test" "$TEST_RESULT" 2>&1 | tee -a $log_file
	close_test_xml_report "$TEST_RESULT_XML"
    done
    close_xml_report
    printf "*** [%s] $GLOBAL_RESULT ***\n" "`date +"%F %T"`" 2>&1 | tee -a $log_file
    if [ "$GLOBAL_RESULT" = "SUCCESS" ]; then
        exit 0
    else
        exit -1
    fi

}

function do_list {
    if [ $opt_profil -eq 0 ];then
	print_test_list "`list_tests`"
    else
	print_profils
    fi
}


function print_test_list {
    list="$1"
    wc_list=`echo  "$list"| wc -w|awk '{print $1}'`
    cur=0
    for the_test in $list ; do
	cur=`expr $cur + 1`
	if [ ! -z `get_setup_test $the_test` ]; then setup="YES" ; else setup="NO" ; fi
	if [ ! -z `get_cleanup_test $the_test` ]; then cleanup="YES" ; else cleanup="NO" ; fi
	timeout=`get_timeout_test $the_test`
	printf "Test %3i/$wc_list : $the_test (Setup=%s Cleanup=%s Timeout=%ss)\n" "$cur" "$setup" "$cleanup" "$timeout"
    done
}

function do_help {
    echo "$0 is a test suite"
    echo ""
    echo "Syntax:  $0 [subcommand]"
    echo "Where [subcommand] may be:"
    echo "    list  [-p]"
    echo "          Lists available tests (or profiles if [-p] switch is set)"
    echo "    run [-i regexp1] [-e regexp2] [-f file_name] [-p]"
    echo "          Runs tests (or profiles if [-p] switch is set)"
    echo "          Tests to be run have a name matching [regexp1] and not matching [regexp2]."
    echo "          If neither [-e] nor [-i] switches are supplied, all tests are run."
    echo "          If [-f] switch is set, record test results in [file_name]."
    echo "    help                        "
    echo "          Print help and exit"
}

function syntax_error {

    echo "Hmmm... Syntax error !"
    echo ""
    do_help
    exit -1

}

#=========================================================
#Profil
#=========================================================
function list_profils {
    if [ ! -z "$filter_include" -a ! -z "$filter_exclude" ]; then
	typeset  |sed 's/typeset //'| grep "^Profil.*=" | sed 's/=.*$//g'|grep "$filter_include" | grep -v "$filter_exclude" | sort
    elif [ ! -z "$filter_include" ]; then
	typeset  |sed 's/typeset //'| grep "^Profil.*=" | sed 's/=.*$//g'|grep "$filter_include" | sort
    elif [ ! -z "$filter_exclude" ]; then
	typeset  |sed 's/typeset //'| grep "^Profil.*=" | sed 's/=.*$//g'|grep -v "$filter_exclude" | sort
    else
	typeset  |sed 's/typeset //'| grep "^Profil.*=" | sed 's/=.*$//g'|sort
    fi
}

function list_all_profils_tests {
    profil_list=`list_profils`
    for profil in $profil_list;do
	list_profil_tests $profil
    done
}

function check_all_profils {
    profil_list=`list_profils`
    for profil in $profil_list;do
	profil_tests=`eval echo \\\$$profil`
	for a_test in $profil_tests;do
	    check_profil_test "$a_test" "$profil"
	done
    done
}

function check_profil_test {
#Check on all tests, prevent misuse of variables filter that may be activated with profil
    check_list_tests=`typeset -F | sed 's/declare -f //' | grep "^Test" | sort`
    for ref_test in $check_list_tests; do
	if [ "$ref_test" == "$1" ];then
	    return 1
	fi
    done
    echo "!-------------------------------------------!" 1>&2
    echo "Error : unknown test!" 1>&2
    echo "the test $1 listed in profil $2 doesnot exist." 1>&2
    echo "!-------------------------------------------!" 1>&2

    exit -2
}

function list_profil_tests {
    profil_tests=`eval echo \\\$$1`
    for a_test in $profil_tests;do
	check_profil_test "$a_test" "$1"
	echo $a_test
    done

}

function print_profils {
    profil_list=`list_profils`
    for profil in $profil_list;do
	echo "=========================================================="
	echo "Tests included in profil : $profil"
	echo "----------------------------------------------------------"
	profil_tests=`list_profil_tests $profil |sort`
	print_test_list "$profil_tests"
	echo ""
    done
    echo "=========================================================="
}


#=========================================================
#Main
#=========================================================
function iotest_main {

    if [ "$#" -lt "1" ]; then
        do_help
        exit -1
    fi

    export filter_include=""
    export filter_exclude=""
    export xml_file=""
    export COMMAND_LINE="`pwd`/$0 $*"
    opt_profil=0

    iotest_cmd="$1"
    OPTIND=2

    while getopts ":e:i:f:p" argument ; do

        case $argument in
            "e")
              filter_exclude=$OPTARG
              ;;
            "i")
              filter_include=$OPTARG
	     ;;
	    "f")
              xml_file=$OPTARG
              echo "the results of the tests are recorded in xml file : $xml_file"
              ;;
	    "p")
		opt_profil=1
		;;
	      *)
              syntax_error
              ;;
        esac

    done

    if [ $(($OPTIND - 1)) != "$#" ]; then
        syntax_error
    fi

    case $iotest_cmd in
        "run")
            do_run
            ;;
        "list")
            do_list
            ;;
        "help")
            do_help
            ;;
        *)
            syntax_error
    esac
}
