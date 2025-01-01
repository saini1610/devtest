#!/bin/bash
#set -x
. ~/.bash_profile
# Netstat and check if the number is greater than 2000
PORT=29998
OUTFILE="/home/sdpuser/scripts/netout.txt"
#removing old outfile
> "$OUTFILE"
echo "$(date)" >> "$OUTFILE"
netstat -anp | grep ":$PORT" | while read result; do
    # Extract the second field (bytes queued)
    output=$(echo $result | awk '{print $2}')

    # Check if bytes queued is greater than 2000
    if [[ "$output" -ge 1000 ]]; then
        echo "ALERT: Netstat on Charging $PORT is greater than 1000!" >> "$OUTFILE"
        echo "$result" >> "$OUTFILE"
        pkill -f 'chargingserver.MainClient'
        pkill -f 'telemune.engine.backend.common.RuleEngine'
# Use SCP to transfer the file
    /usr/bin/expect <<EOD
spawn scp /home/sdpuser/scripts/netout.txt "user@ip:/home/monitor/all_servers_data/CrbtData/"
expect -nocase "password:"
send "passwd\r"
expect eof
EOD

    else
        echo "Charging is working properly." >> "$OUTFILE"
    fi
done
