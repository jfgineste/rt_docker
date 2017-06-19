#!/bin/ksh


###############################################################################
# Parametres globaux des priorites

KERNEL_RELEASE=`uname -r`

case ${KERNEL_RELEASE} in
    2.6.31-nh* | 2.6.33-nh* | 2.6.19.7-rt15* )
        prio_os_hrtimer=98
        prio_os_netrx=96
        prio_os_nettx=95
        prio_os_netrx_afdx=93
        ;;
    3.10.0-nh* )
        # OS kernel thread which are not directly used by RT tasks, so priorities are
        # above normal userspace priority (0) but below RT tasks.
        prio_os_kworker=20
        prio_os_posixcputmr=20
        prio_os_rtkit=20

        # Modifications have been made on the kernel to use specific kthread named
        # sirq-tmr-rt/* to handle process wakeup when using "timerfd" API from a
        # RT application.
        prio_os_hrtimer_rt=96
        ;;
    * )
        echo "******************************************************************"
        echo "Erreur gestion_prio.ksh "
        echo "Version de noyau non supportee : "`uname -r`
        echo "******************************************************************"
        exit 1
        ;;
esac

# Ionext
prio_ionext_irq=97
prio_ionext_process=94
prio_ionext_bionext=92
cpu_ionext_1=1
ip_ionext_1="151.157.*.*"
cpu_ionext_2=4
ip_ionext_2="151.158.*.*"
cpu_ionext_3=7
ip_ionext_3="151.159.*.*"

# AFDX
# Inutile de changer la prio des irq des i/f qui ne font qu'emettre
# On touche seulement a la reception, @ 220.2.40
prio_afdx_irq=93
prio_afdx_recv_process=93
prio_afdx_send_process=94
prio_afdx_recv_bioafdx=83
prio_afdx_send_bioafdx=85
prio_snmp_anim_request=92
prio_snmp_anim_trap=92
cpu_afdx=3

# Visuel
prio_visuel_irq=97
prio_visuel_motion_process=94
cpu_visuel=2

# Motion
prio_motion_irq=97

# Additional interface irq specified by the user
prio_addtional_irqs=97
typeset -i prio_additional_number=0
set -A additional_ip
set -A additional_cpu

###############################################################################
# Verification que le script est lance en root

if [[ `id -u` -ne 0 ]]; then
    echo "******************************************************************"
    echo "Error: ${0} needs to be run as root"
    echo "******************************************************************"
    exit 1
fi


###############################################################################
# Verification des parametres du script

function is_valid_arg {
    ip=${1}
    filter="^[0-9]\{1,3\}\.[0-9*]\{1,3\}\.[0-9*]\{1,3\}\.[0-9*]\{1,3\}/cpu[0-9]\{1,2\}\$"

    echo "${ip}" | grep "${filter}" 2>&1 > /dev/null
    if (( ${?} == 0 )) ; then
        echo "yes"
    else
        echo "no"
    fi
}

export ARGUMENT_IP=
export ARGUMENT_CPU=
function split_argument {
    typeset -u arg=${1}

    ARGUMENT_IP=`echo ${arg} | cut -d'/' -f 1`
    ARGUMENT_CPU=`echo ${arg} | cut -d'U' -f 2`
}

OPTIONS=`/usr/bin/getopt -o i: --long interface: -n gestion_prio.ksh -- "${@}"`

if [[ ${?} != 0 ]] ; then echo "Syntax error! Quitting..." ; exit 1 ; fi

eval set -- "$OPTIONS"

while true ; do

    case ${1} in
        -i|--interface)
            valide=`is_valid_arg ${2}`
            if [[ "$valide" != "yes" ]]; then
                echo "Error: Invalid -i argument : ${2} ! Should be 'A.B.C.D/cpuX'. Quitting..." ; exit 1
            fi
            split_argument ${2}
            additional_ip[${prio_additional_number}]=${ARGUMENT_IP}
            additional_cpu[${prio_additional_number}]=${ARGUMENT_CPU}
            prio_additional_number=${prio_additional_number}+1
            shift 2 ;;
        --) shift ; break ;;
        *) echo "Error parsing options! Quitting..." ; exit 1 ;;
    esac

done

if [[ ${#} != 0 ]]; then
    echo "This script does not allow additionnal parameter ('$*')! Quitting..."
    exit 1
fi

print "Here are the additionnal priorities specified in command line:"
if (( ${prio_additional_number} )); then
    typeset -i limite=${prio_additional_number}-1
    for index in `seq 0 ${limite}`; do
        echo "-> IP=${additional_ip[${index}]} CPU=${additional_cpu[${index}]} PRIO=${prio_addtional_irqs}"
    done
fi


###############################################################################
# Verification de la version du noyau
case `uname -r` in
    2.6.31-nh* | 2.6.33-nh* | 3.10.0-nh* )
        export IRQ_PID=
        get_irq_pid() {
            num=${1}
            IRQ_PID=`ps ax -o pid,cmd | grep "irq/${num}-" | grep -v grep | awk '{print $1}'`
            #Le awk sert a virer les espaces blancs
        }
        ;;
    2.6.19.7-rt15* )
        export IRQ_PID=
        get_irq_pid() {
            num=${1}
            IRQ_PID=`ps ax -o pid,cmd | grep "\[IRQ.${num}\]" | grep -v grep | awk '{print $1}'`
            #Le awk sert a virer les espaces blancs
        }
        ;;
    * )
        echo "******************************************************************"
        echo "Erreur gestion_prio.ksh "
        echo "Version de noyau non supportee : "`uname -r`
        echo "******************************************************************"
        exit 1
        ;;
esac


###############################################################################
# Fonctions
function power {
    res=1
    exp=${1}

    while (( ${exp} )) ; do
        res=`expr ${res} \* 2`
        exp=`expr ${exp} - 1`
    done
    echo ${res}
}

function change_prio_pid {
    echo "chrt -p -f ${2} ${1} ("`ps -o cmd ${1} | tail -1`")"
    chrt -p -f ${2} ${1} 2> /dev/null || echo "KO"
}

function change_prio {
    for pid in `ps -eLo tid,cmd | grep "${1}" | grep -v grep | awk '{printf \$1" "}'` ; do
        change_prio_pid ${pid} ${2}
    done
}

# change_prio utilise 'cmd' : trop dangereux car si le nom du process se retrouve aussi dans
# une ligne de commande en argument et bien on recupe¨re aussi un process qui n'a rien a voir
function change_prio_comm {
    for pid in `ps -eLo tid,comm | grep "${1}" | grep -v grep | awk '{printf \$1" "}'` ; do
        change_prio_pid ${pid} ${2}
    done
}


#parametres 1=scheduler_name 2=type 3=Father_Prio 4=Son_Prio
function change_prio_afdx {
    ps ax -o pid,comm | grep ${1} > /tmp/process_afdx.txt
    nombre_process_afdx=`wc -l /tmp/process_afdx.txt | awk '{print $1}'`
    if (( ${nombre_process_afdx} == 1 )) ; then
        # Il n'y a qu'un seul process -> c'est un process send !
        change_prio_pid `awk '{print $1}' /tmp/process_afdx.txt` ${3}
    elif (( ${nombre_process_afdx} == 2 )) ; then
        # Le pere des deux process est le processus d'emission
        father `awk '{print $1}' /tmp/process_afdx.txt`
        if (( ${FATHER} == 0 )) ; then
            echo "Impossible de determiner le processus ${2} parent"
        else
           change_prio_pid ${FATHER} ${3}
           change_prio_pid ${SON} ${4}
        fi
    elif (( ${nombre_process_afdx} == 0 )) ; then
        # Pas de processus AFDX
        echo "Pas de process ${2}."
    else
        # Plus de 2 process AFDX !
        echo "Trop de processus ${2} : ${nombre_process_afdx}"
    fi
}

export IRQ_NUM=
function get_irq_num {
    iface=${1}

    IRQ_NUM=`cat /proc/interrupts | grep ${iface} | cut -d ':' -f 1 | awk '{print $1}'`
    #Le awk sert a virer les espaces blancs
}

export FATHER=
export SON=
function father {
    process1=${1}
    process2=${2}

    if (( `ps -o ppid ${process1} | tail -n 1` == ${process2} )) ; then
        FATHER=${process2}
        SON=${process1}
    elif (( `ps -o ppid ${process2} | tail -n 1` == ${process1} )) ; then
        FATHER=${process1}
        SON=${process2}
    else
        FATHER=0
    fi
}

function change_prio_if {
    interface_name=${1}
    interface_prio=${2}

    get_irq_num ${interface_name}
    if [[ -n ${IRQ_NUM} ]] ; then
        get_irq_pid ${IRQ_NUM}
        if [[ -n ${IRQ_PID} ]] ; then
            change_prio_pid ${IRQ_PID} ${interface_prio}
        fi
    fi
}

export IP_MATCH_FILTER=
function ip_match_filter {
    ip=${1}
    filter=${2}

    echo "${ip}" | grep "${filter}" 2>&1 > /dev/null
    if (( ${?} == 0 )) ; then
        IP_MATCH_FILTER="yes"
    else
        IP_MATCH_FILTER="no"
    fi
}

function change_prio_ip {
    if_list=`ls /sys/class/net/`
    ip_recherchee=${1}
    prio_demandee=${2}

    # Parcours de l'interface pour trouver la bonne !
    for interface in ${if_list} ; do

        if_ip=`/sbin/ifconfig ${interface} | grep "inet" | awk '{print $2}' | cut -d: -f 2`
        ip_match_filter "${if_ip}" "${ip_recherchee}"
        if [[ "${IP_MATCH_FILTER}" == "yes" ]] ; then
            echo "Changing priority : i/f ${interface} (${ip_recherchee}) to prio ${prio_demandee}"
            change_prio_if "${interface}" "${prio_demandee}"
        fi
    done
}

function change_prio_sirq {
    change_prio "softirq-${1}" "${2}"
    change_prio "sirq-${1}" "${2}"
}

function change_cpu_pid {
    if [[ -d "/dev/cgroup" ]]; then
        cgroup_dir="cgroup"
    elif [[ -d "/dev/cpuset" ]]; then # CPUSET are obsolete since Nucleus 1.5.0 (Only used on RHEL5 preempt-rt)
        cgroup_dir="cpuset"
    fi
    echo "echo ${1} >> /dev/${cgroup_dir}/CPU${2}/tasks ("`ps -o cmd ${1} | tail -1`")"
    echo ${1} >> /dev/${cgroup_dir}/CPU${2}/tasks 2> /dev/null || echo "KO"
}

function change_cpu {
    for pid in `ps -eLo tid,cmd | grep "${1}" | grep -v grep | awk '{printf \$1" "}'` ; do
        change_cpu_pid ${pid} ${2}
    done
}

# change_prio utilise 'cmd' : trop dangereux car si le nom du process se retrouve aussi dans
# une ligne de commande en argument et bien on recupeere aussi un process qui n'a rien a voir
function change_cpu_comm {
    for pid in `ps -eLo tid,comm | grep "${1}" | grep -v grep | awk '{printf \$1" "}'` ; do
        change_cpu_pid ${pid} ${2}
    done
}

function change_cpu_ip {
    if_list=`ls /sys/class/net/`
    ip_recherchee=${1}
    prio_demandee=${2}

    # Parcours de l'interface pour trouver la bonne !
    for interface in ${if_list} ; do

        if_ip=`/sbin/ifconfig ${interface} | grep "inet" | awk '{print $2}' | cut -d: -f 2`
        ip_match_filter "${if_ip}" "${ip_recherchee}"
        if [[ "${IP_MATCH_FILTER}" == "yes" ]] ; then
            get_irq_num ${interface}
            if [[ -n ${IRQ_NUM} ]] ; then
                echo "Changing cpu : i/f ${interface} (${ip_recherchee} irq ${IRQ_NUM} ) to cpu ${prio_demandee}"
                local_prio_dec=`power ${prio_demandee}`
                local_prio_hex=`echo "obase=16 ; ${local_prio_dec}" | bc`
                echo "/bin/echo ${local_prio_hex} >> /proc/irq/${IRQ_NUM}/smp_affinity"
                /bin/echo ${local_prio_hex} >> /proc/irq/${IRQ_NUM}/smp_affinity
            fi
        fi
    done
}

function change_cpu_ionext {
    nb_ionext_manager=`ps -eo pid,ppid,comm | grep "ionext_manager"| wc -l`

    echo "Number of ionext managers: ${nb_ionext_manager}"
    if [[ ${nb_ionext_manager} -le 1 ]] ; then
        change_cpu "ionext_manager" ${cpu_ionext_1}
    elif [[ ${nb_ionext_manager} -le 3 ]] ; then
        change_cpu_multi "ionext_manager"
    else
        echo "WARNING : Number of ionext managers ${nb_ionext_manager} > 3 (not handled)!"
    fi
}

function change_cpu_multi {
    get_cpu_number
    num_cpu=${?}

    if [[ "${num_cpu}" -lt 4 ]] ; then
        echo "WARNING : insufficient number of cpus : ${num_cpu} (min 8) to launch multiple ionext manager at the same time "
        return -1
    else
        ps -eo pid,ppid,comm | grep "${1}" | while read line
        do
            pid=`echo ${line}  | awk '{print $1}'`
            ppid=`echo ${line} | awk '{print $2}'`
            if [[ -f  /proc/${pid}/cwd/interface.res ]] ; then
                ip_adress=`cat /proc/${pid}/cwd/interface.res`
                #affectation cpu
                if [[ "${ip_adress}" == "${ip_ionext_1}" ]] ; then
                    change_cpu_pid ${pid} ${cpu_ionext_1}
                elif [[ "${ip_adress}" == "${ip_ionext_2}" ]] ; then
                    change_cpu_pid ${pid} ${cpu_ionext_2}
                elif [[ "${ip_adress}" == "${ip_ionext_3}" ]] ; then
                    change_cpu_pid ${pid} ${cpu_ionext_3}
                fi
            else
                echo "WARNING : ionext manager (pid : ${pid}) does not got file /proc/${pid}/cwd/ip.interface.res "
            fi
        done
    fi
}

function get_cpu_number {
    num_cpu=`grep processor /proc/cpuinfo | wc -l`

    return ${num_cpu}
}


###############################################################################
# Changement de priorites de l'OS
echo -e "********** PROCESSUS SYSTEME **********"
case ${KERNEL_RELEASE} in
    2.6.31-nh* | 2.6.33-nh* | 2.6.19.7-rt15* )
        change_prio_sirq "hrtimer" ${prio_os_hrtimer}
        change_prio_sirq "net-rx" ${prio_os_netrx}
        change_prio_sirq "net-tx" ${prio_os_nettx}
        ;;
    3.10.0-nh* )
        # Note: by default all sirq threads have priority 3. Let this priority as these
        # threads are not used by RT programs.

        # Other kernel threads not used in RT context (low priority)
        change_prio "kworker" ${prio_os_kworker}
        change_prio "posixcputmr" ${prio_os_posixcputmr}

        # Other kernel threads used in RT context (high priority)
        change_prio_sirq "tmr-rt" ${prio_os_hrtimer_rt}

        # If rtkit is installed, set a lower priority than RT task as this is currently
        # not used.
        change_prio "rtkit-daemon" ${prio_os_rtkit}

        ###############################################################################
        # Make sure we don't use sirq threads using when sending/receiving packets
        # on ALL interfaces, including non-RT ones.
        echo -e "********** NETWORKING: RPS/RFS DEACTIVATION **********"

        for iface in $(ls /sys/class/net)
        do
            # Make sure all network interface are not using RPS and RFS which means
            # sirq-net-rx threads are not used (this is the default values)
            echo "Desativation of RPS on ${iface}"
            echo "0000 > /sys/class/net/${iface}/queues/rx-0/rps_cpus"
            echo 0000 > /sys/class/net/${iface}/queues/rx-0/rps_cpus

            echo "Desativation of RFS on ${iface}"
            echo "0 > /sys/class/net/${iface}/queues/rx-0/rps_flow_cnt"
            echo 0 > /sys/class/net/${iface}/queues/rx-0/rps_flow_cnt
        done
        ;;
esac

###############################################################################
# Changement de priorites des moteurs E/S

# AFDX
echo -e "\n********** PROCESSUS AFDX **********"
change_prio_ip "220.2.40.10" ${prio_afdx_irq}
change_prio_ip "220.2.38.11" ${prio_afdx_irq}
change_prio_afdx "scheduler_afdx" "AFDX" ${prio_afdx_send_process} ${prio_afdx_recv_process}
change_prio_afdx "scheduler_snmp" "SNMP" ${prio_snmp_anim_trap} ${prio_snmp_anim_request}
change_prio_afdx "bio_afdx" "BIOAFDX" ${prio_afdx_send_bioafdx} ${prio_afdx_recv_bioafdx}

change_cpu_comm "scheduler_afdx" ${cpu_afdx}
change_cpu_comm "scheduler_snmp" ${cpu_afdx}
change_cpu_comm "bio_afdx" ${cpu_afdx}
change_cpu_ip "220.2.40.10" ${cpu_afdx}
change_cpu_ip "220.2.38.10" ${cpu_afdx}
change_cpu_ip "220.2.39.10" ${cpu_afdx}
change_cpu_ip "220.2.38.11" ${cpu_afdx}
change_cpu_ip "220.2.40.11" ${cpu_afdx}

case ${KERNEL_RELEASE} in
    2.6.31-nh* | 2.6.33-nh* | 2.6.19.7-rt15* )
        # Ajustement prio afdx suite au changement cpu
        echo "=> Ajustement de priorite AFDX suite au changement de CPU"
        afdx_cpu_plus_un=`expr ${cpu_afdx} + 1` # Plus un parce que sed va compter a compter de la ligne 1 (la ligne 0 existe pas !)
        #Affiche la ligne numero $(afdx_cpu_plus_un) de la liste des process net-rx => c'est le thread net-rx du cpu ${cpu_afdx} !!!
        netrx_afdx_pid=`ps auxm | grep -i net-rx | grep -v grep| awk '{ print $2 }' | sort -g | sed -n ${afdx_cpu_plus_un}p`
        change_prio_pid ${netrx_afdx_pid} ${prio_os_netrx_afdx}
        ;;
esac

# IONEXT
echo -e "\n********** PROCESSUS IONEXT **********"
change_prio "ionext_manager" ${prio_ionext_process}
change_prio "bionet" ${prio_ionext_bionext}
for cpu_id in `seq 1 3`; do
    eval ip_ionext=\${ip_ionext_${cpu_id}}
    eval cpu_ionext=\${cpu_ionext_${cpu_id}}

    change_prio_ip ${ip_ionext} ${prio_ionext_irq}
    change_cpu_ip  ${ip_ionext} ${cpu_ionext}
done
change_cpu_ionext

# VISUEL
echo -e "\n********** PROCESSUS DU VISUEL **********"
#Pour le M24
change_prio_ip "220.2.25.*" ${prio_visuel_irq}
#Pour Blagnac
change_prio_ip "220.9.126.*" ${prio_visuel_irq}
#Les process
change_prio "ncis_engine" ${prio_visuel_motion_process}
change_cpu "ncis_engine" ${cpu_visuel}
#Pour le M24
change_cpu_ip "220.2.25.*" ${cpu_visuel}
#Pour Blagnac
change_cpu_ip "220.9.126.*" ${cpu_visuel}

# MOTION
echo -e "\n********** PROCESSUS DU MOTION **********"
#Pour le M24
change_prio_ip "220.2.28.*" ${prio_motion_irq}

# ADDITIONAL NETWORKS
echo -e "\n********** ADDITIONNAL NETWORK INTERFACES **********"
if (( ${prio_additional_number} )); then
    typeset -i limite=${prio_additional_number}-1
    for index in `seq 0 ${limite}`; do
        change_cpu_ip  ${additional_ip[${index}]} ${additional_cpu[${index}]}
        change_prio_ip ${additional_ip[${index}]} ${prio_addtional_irqs}
    done
fi
