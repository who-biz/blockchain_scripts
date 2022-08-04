#!/bin/bash
# Bash script designed to distribute funds from a snapshot CSV of positive balance addresses
# CSV used should be created with https://github.com/who-biz/chipsposbal2csv
# Written to function with VerusCoin's daemon and CLI
#
#
# @author who-biz

FILE=""
json=""
fromaddr=""
# change this location of verus cli, bitcoin-cli, etc
# example cli="$HOME/VerusCoin/src/verus"
cli="$HOME/chips10sec/src/verus"

# change this to relevant chain, ac_name, etc
# example: chain="-chain=vrsctest"
chain="chipstensec"

if [[ -z "$1" ]]; then
    echo "Error: no arguments supplied."
    echo "Usage: \"./vrsc_sendmany_from_csv.sh <from_address> <path_to_file>\""
    echo "Where <from_address> is address for funds to spent from, and <path_to_file> is path to CSV file"
else
    fromaddr=$1
fi

currbal=$($cli -chain=$chain getcurrencybalance $fromaddr)
balance=$(echo $currbal | jq -r '.chipstensec')
echo "$balance"
totalamount=0

if [[ -z "$2" ]]; then
    echo "Error: no csv file supplied."
    echo "Usage: \"./vrsc_sendmany_from_csv.sh <from_address> <path_to_file>\""
    echo "Where <from_address> is address for funds to spent from, and <path_to_file> is path to CSV file"
else

    FILE=$2
    if [[ -f "$FILE" ]]; then
        echo "Will attempt to parse addresses and balances from $FILE ..."
        counter=0
        while IFS="," read -r address amount lastheight
        do
            if [[ $counter == 0 ]]; then
                json=$(jq -n --arg addr $address --arg amt $amount '[{($addr):$amt}]')
                totalamount=$amount
#                echo "$json"
                ((counter++))
            else
                totalamount=$(echo "$totalamount + $amount" | bc)
                if (( $(echo "$balance < $totalamount" | bc -l) )); then
                    echo "Available balance ($balance) less than ($totalamount) ..."
                    echo "Entries from <$address> and below will not receive funds!"
                    break
                else
                    json=$(echo $json | jq --arg addr $address --arg amt $amount '. += [{($addr): $amt}]')
                    echo "$totalamount"
                fi
                ((counter++))
            fi
        done < <(tail -n +2 $FILE)
    else
        echo "File at location $FILE not found, or is a directory etc..."
    fi
    echo "$json"

fi
