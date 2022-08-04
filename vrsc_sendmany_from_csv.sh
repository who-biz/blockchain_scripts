#!/bin/bash
#
# Bash script designed to distribute funds from a snapshot CSV of positive balance addresses
# CSV used should be created with https://github.com/who-biz/chipsposbal2csv
# Written to function with VerusCoin's daemon and CLI
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
excludedjson=""
excludedcount=0

if [[ -z "$2" ]]; then
    echo "Error: no csv file supplied."
    echo "Usage: \"./vrsc_sendmany_from_csv.sh <from_address> <path_to_file>\""
    echo "Where <from_address> is address for funds to spent from, and <path_to_file> is path to CSV file"
else

    FILE=$2
    if [[ -f "$FILE" ]]; then
        echo "Attempting to parse addresses and balances from $FILE ..."
        counter=0

        while IFS="," read -r address amount lastheight
        do
            if [[ -z $address || -z $amount ]]; then
                break
            fi
            if [[ $counter == 0 ]]; then
                json=$(jq -n --arg addr $address --arg amt $amount '{($addr):$amt|tonumber}')
                echo "$json"
                totalamount=$amount
            else
                totalamount=$(echo "$totalamount + $amount" | bc)
                if (( $(echo "$balance < $totalamount" | bc -l) )); then
                        if [[ $excludedcount < 1 ]]; then
                            echo "Available balance ($balance) less than ($totalamount) ..."
                            echo "Entries from <$address> and below will not receive funds!"
                            excludedjson=$(jq -n --arg addr $address --arg amt $amount '{($addr):$amt|tonumber}')
                        else
                            excludedjson=$(echo $json | jq --arg addr $address --arg amt $amount '. += {($addr): $amt|tonumber}')
                        fi
                        ((excludedcount++))
                else
                    json=$(echo $json | jq --arg addr $address --arg amt $amount '. += {($addr): $amt|tonumber}')
                    echo "$totalamount"
                fi
            fi
            ((counter++))
        done < <(tail -n +2 $FILE)

        echo "Distributing to snapshot addresses with (sendmany) ..."
        echo "Excluding a total of $excludedcount addresses from this command."
        echo "$excludedjson" > $HOME/excluded_addresses_from_snapshot.json
        echo "Excluded addresses logged to $HOME/excluded_addresses_from_snapshot.json"

        sendmany="$cli -chain=$chain sendmany $fromaddr '$json'"
        echo "$sendmany"
        txid=$($sendmany)
        if [[ -z $txid ]]; then
            echo "Error: Unsuccessful! Something went wrong when calling sendmany"
        else
           echo "Sendmany successful... txid = $txid"
        fi
    else
        echo "File at location $FILE not found, or is a directory etc..."
    fi
    #echo "$json"

fi
