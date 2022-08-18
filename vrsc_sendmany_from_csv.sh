#!/bin/bash
#
# Bash script designed to distribute funds from a snapshot CSV of positive balance addresses
# CSV used should be created with https://github.com/who-biz/chipsposbal2csv
# Written to function with VerusCoin's daemon and CLI
#
# @author who-biz
#
# newer jq version no longer required

FILE=""
json=""
port=12122

# change this location of verus cli, bitcoin-cli, etc
# example cli="$HOME/VerusCoin/src/verus"
cli="$HOME/chips-10sec/src/verus"

# change this to relevant chain, ac_name, etc
# example: chain="-chain=vrsctest"
chain="chipstensec"

balance=$($cli -chain=$chain getbalance)

if [[ -z "$balance" ]]; then
    echo "Could not get balance from daemon.  Please check that your daemon is running and responsive to RPC calls."
    echo "Exiting..."
fi

echo "$balance"
totalamount=0
excludedjson=""
excludedcount=0

if [[ -z "$1" ]]; then
    echo "Error: no csv file supplied."
    echo "Usage: \"./vrsc_sendmany_from_csv.sh <path_to_csv_file>\""
else

    FILE=$1
    if [[ -f "$FILE" ]]; then
        echo "Attempting to parse addresses and balances from $FILE ..."
        counter=0

        while IFS="," read -r address amount lastheight
        do
            if [[ -z $address || -z $amount ]]; then
                break
            fi

            if [[ $counter == 0 ]]; then
                json=$(jq -n --arg addr $address --arg amt $amount '{($addr):$amt}')
                totalamount=$amount
            else
                totalamount=$(echo "$totalamount + $amount" | bc -l)
                if (( $(echo "$balance < $totalamount" |bc -l) )); then
#                 if (( $counter > 50 )); then
#                        break
                        if [[ $excludedcount < 1 ]]; then
#                            echo "Counter hit $counter entries, excluding the rest ..."
                            echo "Available balance ($balance) less than ($totalamount) ..."
                            echo "Entries from <$address> and below will not receive funds!"
                            excludedjson=$(jq -n --arg addr $address --arg amt $amount '{($addr):$amt}')
                        else
                            excludedjson=$(echo $json | jq --arg addr $address --arg amt $amount '. |= . + {($addr):$amt}')
                        fi
                        ((excludedcount++))
                else
                    json=$(echo $json | jq --arg addr $address --arg amt $amount '. |= . + {($addr):$amt}')
                    echo "$totalamount"
                fi
            fi

            ((counter++))
        done < <(tail -n +2 $FILE)

        echo "Distributing to snapshot addresses with (sendmany) ..."
        echo "Excluding a total of $excludedcount addresses from this command."
        echo "$excludedjson" > $HOME/excluded_addresses_from_snapshot.json
        echo "Excluded addresses logged to $HOME/excluded_addresses_from_snapshot.json"

        stringizedjson=$(echo $json | jq -sRj '. | gsub(" ";"")')
        sendmany="$cli -chain=$chain -stdin sendmany \"\" "
        echo "$stringizedjson"
        txid=$(printf "%s" $stringizedjson | $sendmany)
        if [[ -z $txid ]]; then
            echo "Error: Unsuccessful! Something went wrong when calling sendmany"
        else
           echo "sendmany successful..."
           echo "Resulting txid = $txid"
        fi
    else
        echo "File at location $FILE not found, or is a directory etc..."
    fi

fi
