#!/bin/sh
# logs openttd passwords to a file periodically while


if [ $# -gt 2 -o $# -lt 1 ]; then
    echo "usage: $0 [pid] output"
    exit 1
fi

# pid
if [ $# -eq 2 -a "$1" -eq "$1" 2>/dev/null ]; then
    # given pid
    OPENTTD=$1
    shift
elif [ $# -eq 1 ]; then
    # guess pid
    pid=$(ps -C openttd -opid=)
    if [ `echo "$pid" | wc -l` -ne 1 ]; then
        echo "More than one openttd running, specify pid"
        ps ca | grep openttd
        exit 1
    fi
    OPENTTD=$pid
else
    echo "pid must be a number"
    exit 1
fi

OUTPUT=$1

# make script
t=$(tempfile -s .gdb -p ottd-)
cat <<EOH >$t
attach $OPENTTD
set \$n=0
printf "cmp hash\n"
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
printf "%2d: %s\n",\$n+1,_network_company_states+(36*\$n++)
detach
quit
EOH

dying()
{
    echo "goodbye, cruel world"
    rm -f "$t"
    exit 0
}

trap 'dying' TERM
trap 'dying' KILL
trap 'dying' INT


while true; do
    # run gdb
    if [ -f $OUTPUT.bak ]; then mv -f $OUTPUT.bak $OUTPUT.bak.bak; fi
    mv -f $OUTPUT $OUTPUT.bak
    date > $OUTPUT
    date -u >> $OUTPUT
    gdb -batch -x "$t" >> $OUTPUT
    sleep 300
done

