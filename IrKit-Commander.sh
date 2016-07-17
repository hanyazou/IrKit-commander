#!/bin/bash

whoami=irkit-commander
TIMEOUT=5
CMD_FILE=/tmp/$whoami.cmd
LOG_FILE=/tmp/$whoami.log
#DEBUG=true

PATH=$PATH:/usr/local/bin

debug_echo()
{
    if [ .$DEBUG != . ]; then
        echo $whoami: "$*" >&2
    fi
}

#
# initialize
#
setup()
{
    if fswatch --help > /dev/null; then
        :
    else
        echo "Can't find fswatch command."
        echo "HINT: you could install fswatch with homebrew."
    fi

    IRKIT_HOST=`(dns-sd -B _irkit._tcp &) | while read -t $TIMEOUT in; do
        debug_echo "DNS-SD: $in"
        if echo "$in" | grep _irkit._tcp. > /dev/null; then
            echo $in | awk '{ print $7 }'
            exit
        fi
    done`
    
    if echo $IRKIT_HOST | grep -e '^[iI][rR][kK][iI][tT][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9]$' > /dev/null; then
        IRKIT_HOST=${IRKIT_HOST}.local.
        echo HOST = $IRKIT_HOST
    else
        echo "Can't find _irkit._tcp service."
        exit
    fi

    IRKIT_ADDR=`(dns-sd -G v4 $IRKIT_HOST &) | while read -t $TIMEOUT in; do
        debug_echo "DNS-SD: $in"
        if echo "$in" | grep -i $IRKIT_HOST > /dev/null; then
            echo $in | awk '{ print $6 }'
            exit
        fi
    done`
    if echo $IRKIT_ADDR | grep -e '^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' > /dev/null; then
        echo IP ADDR = $IRKIT_ADDR
    else
        echo "Can't resolve $IRKIT_HOST address."
        exit
    fi
}    

#
# IR remote control signals
#
SIG_UP='{"format":"raw","freq":38,"data":[17421,8755,1150,1150,1150,1150,1150,1150,1150,3228,1150,3228,1150,3228,1150,1150,1150,3228,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,3228,1150,3228,1150,1150,1150,3228,1150,3228,1150,1150,1150,1150,1150,3228,1150,1150,1150,1150,1150,3228,1150,1150,1150,1150,1150,3228,1150,3228,1150,1150,1150,65535,0,22165,17421,4400,1150,65535,0,65535,0,60108,17421,4400,1150]}'

SIG_DOWN='{"format":"raw","freq":38,"data":[17421,8755,1150,1150,1150,1150,1150,1150,1150,3228,1150,3228,1150,3228,1150,1150,1150,3228,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,1150,3228,1150,1150,1150,3228,1150,3228,1150,1150,1150,1150,1150,3228,1150,3228,1150,1037,1150,3228,1150,1150,1150,1150,1150,3228,1150,3228,1150,1150,1150,65535,0,22165,17421,4400,1150]}'

SIG_LIGHT='{"format":"raw","freq":38,"data":[16832,8459,1150,1002,1150,1002,1150,1002,1150,1002,1150,1002,1150,1002,1150,1002,1150,3341,1150,1002,1150,3341,1150,3341,1150,3341,1150,1002,1150,3341,1150,3341,1150,1002,1150,1002,1150,1002,1150,3341,1150,1002,1150,1002,1150,1002,1150,1002,1150,1002,1150,3341,1150,3341,1150,1002,1150,3341,1150,3341,1150,3341,1150,3341,1150,3341,1150,65535,0,4400,19991,10047,1232,3704,1232,3704,1232,3704,1232,1232,1232,1232,1232,3704,1232,3704,1232,3704,1232,1232,1232,1232,1232,3704,1232,3704,1232,1232,1232,1232,1232,1232,1232,1232,1232,3704,1232,3704,1232,3704,1232,1232,1232,1232,1232,1232,1232,1232,1232,3704,1232,1232,1232,1232,1232,1232,1232,3704,1232,3704,1232,3704,1232,3704,1232,1232,1232]}'

send_ir_command()
{
    curl -i "http://$IRKIT_ADDR/messages" -H "X-Requested-With: curl" -d \'$1\' > /dev/null 2>&1
}

#
# main routine
#
main()
{
    setup

    VOLUME=0
    debug_echo read command from $CMD_FILE
    (fswatch --latency 0.1 -o $CMD_FILE &) |
        while read event; do
            cmd=`cat $CMD_FILE`
            debug_echo event=$event
            debug_echo cmd=$cmd
            if [ .$cmd == ".UP" ]; then
                VOLUME=$((VOLUME + 1))
                /bin/echo -n "UP   (VOLUME=$VOLUME)..."
                send_ir_command \'$SIG_UP\'
                echo "done"
                echo NOP > $CMD_FILE
            elif [ .$cmd == ".DOWN" ]; then
                VOLUME=$((VOLUME - 1))
                /bin/echo -n "DOWN (VOLUME=$VOLUME)..."
                send_ir_command \'$SIG_DOWN\'
                echo "done"
                echo NOP > $CMD_FILE
            elif [ .$cmd == ".LIGHT" ]; then
                /bin/echo -n "LIGHT..."
                send_ir_command \'$SIG_LIGHT\'
                echo "done"
                echo NOP > $CMD_FILE
            elif [ .$cmd == ".NOP" ]; then
                :
            elif [ .$cmd == ".EXIT" ]; then
                echo EXIT
                exit
            else
                echo "Unknown command $cmd (ignored)"
            fi
        done
}

main 2>&1 | tee $LOG_FILE
