#!/bin/bash
#set -x
. ~/.bash_profile
# File to monitor
Date=$(date "+%d_%m_%Y")
cd /home/sdpuser/logs/TelemuneChargingDualDb/BalanceWrite/ || exit
FILE="BalanceWrite.$Date"
OUTPUT_FILE="/home/sdpuser/scripts/chgcheck.txt"
rm "$OUTPUT_FILE"
echo "$(date)" >> "$OUTPUT_FILE"
echo "Checking Charging for ERRORS and proper Working."
# Check if the file exists
if [[ ! -e "$FILE" ]]; then
     echo "Error: $FILE does not exist. Please check Renewals First on Vasserver6 and then Charging" >> "$OUTPUT_FILE"

    # Perform SCP for missing file case
    /usr/bin/expect <<EOD
spawn scp "$OUTPUT_FILE" "monitor@10.71.218.7:/home/monitor/all_servers_data/CrbtData/"
expect -nocase "password:"
send "v_%6P3@g*ALj\r"
expect eof
EOD
    exit 1
fi

# Extract and process the last line
if LAST_LINE=$(tail -n 1 "$FILE") && TIMESTAMP=$(echo "$LAST_LINE" | grep -oP '\d{14}$') && [[ -n "$TIMESTAMP" ]]; then
    # Reformat the timestamp to a format recognized by date command (YYYY-MM-DD HH:MM:SS)
    TIMESTAMP_FORMATTED="${TIMESTAMP:0:4}-${TIMESTAMP:4:2}-${TIMESTAMP:6:2} ${TIMESTAMP:8:2}:${TIMESTAMP:10:2}:${TIMESTAMP:12:2}"
    FORMATTED_TIME=$(date -d "$TIMESTAMP_FORMATTED" "+%d-%m-%Y %H:%M:%S" 2>/dev/null)
    TOTAL_BALANCE=$(echo "$LAST_LINE" | grep -oP "Total Balance:\[\K[^\]]+")
    if [[ -n "$FORMATTED_TIME" ]]; then
        echo "Last charged time: $FORMATTED_TIME" >> "$OUTPUT_FILE"
        echo "Last Total Balance: $TOTAL_BALANCE" >> "$OUTPUT_FILE"
    else
        echo "Invalid timestamp format found: $TIMESTAMP" >> "$OUTPUT_FILE"
    fi
else
    echo "No valid timestamp found in the last line of the file." >> "$OUTPUT_FILE"
fi

# Get the file's modification time in seconds since epoch
MOD_TIME=$(stat -c %Y "$FILE")

# Get the current time in seconds since epoch
CURRENT_TIME=$(date +%s)

# Calculate the time difference
TIME_DIFF=$((CURRENT_TIME - MOD_TIME))

# Count occurrences of 'Total Balance:[-1.00.0]' in the last 10 lines
ERROR_COUNT=$(tail -n 10 "$FILE" | grep -c "Total Balance:\\[-1.00.0\\]")

# Check if the file was modified in the last half hour or contains errors
if [[ $TIME_DIFF -le 1800 && $ERROR_COUNT -le 10 ]]; then
    echo "$FILE has been modified in the last half hour."
elif [[ $TIME_DIFF -ge 2100 || $ERROR_COUNT -ge 10 ]]; then
    echo "$FILE has NOT been modified in the last half hour and contains errors [-1.00]. Please check Renewals First on Vasserver6 and then charging." >> "$OUTPUT_FILE"
# Use SCP to transfer the file
    /usr/bin/expect <<EOD
spawn scp /home/sdpuser/scripts/chgcheck.txt "monitor@10.71.218.7:/home/monitor/all_servers_data/CrbtData/"
expect -nocase "password:"
send "v_%6P3@g*ALj\r"
expect eof
EOD
else
    echo "$FILE has been modified and Less than 10 entries contain 'Total Balance:[-1.00.0]'."
fi
