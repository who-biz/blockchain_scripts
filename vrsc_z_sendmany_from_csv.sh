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
fromaddr=""
port=12122

# change below to relevant rpc user/pass if using curl
#rpcuser=""
#rpcpass=""

# change this location of verus cli, bitcoin-cli, etc
# example cli="$HOME/VerusCoin/src/verus"
cli="$HOME/chips-10sec/src/verus"

# change this to relevant chain, ac_name, etc
# example: chain="-chain=vrsctest"
chain="chipstensec"

if [[ -z "$1" ]]; then
    echo "Error: no arguments supplied."
    echo "Usage: \"./vrsc_sendmany_from_csv.sh <from_address> <path_to_file>\""
    echo "Where <from_address> is address for funds to be spent from, and <path_to_file> is path to CSV file"
else
    fromaddr=$1
fi

currbal=$($cli -chain=$chain getcurrencybalance $fromaddr)
balance=$(echo $currbal | jq -r '.chipstensec')

if [[ -z "$balance" ]]; then
    echo "Could not get balance from daemon.  Please check that your daemon is running and responsive to RPC calls."
    echo "Exiting..."
fi

echo "$balance"
totalamount=0
excludedjson=""
excludedcount=0

if [[ -z "$2" ]]; then
    echo "Error: no csv file supplied."
    echo "Usage: \"./vrsc_sendmany_from_csv.sh <from_address> <path_to_file>\""
    echo "Where <from_address> is address for funds to be spent from, and <path_to_file> is path to CSV file"
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
                json=$(jq -n --arg addr $address --arg amt $amount '[{"address":$addr,"amount":$amt}]')
#                echo "$json"
                totalamount=$amount
            else
                totalamount=$(echo "$totalamount + $amount" | bc -l)
                if (( $(echo "$balance < $totalamount" |bc -l) )); then
                        if [[ $excludedcount < 1 ]]; then
                            echo "Available balance ($balance) less than ($totalamount) ..."
                            echo "Entries from <$address> and below will not receive funds!"
                            excludedjson=$(jq -n --arg addr $address --arg amt $amount '[{"address":$addr,"amount":$amt}]')
                        else
                            excludedjson=$(echo $json | jq --arg addr $address --arg amt $amount '.[.|length] |= . + {"address":$addr,"amount":$amt}')
                        fi
                        ((excludedcount++))
                else
                    json=$(echo $json | jq --arg addr $address --arg amt $amount '.[.|length] |= . + {"address":$addr,"amount":$amt}')
#                    echo "$json"
                    echo "$totalamount"
                fi
            fi

            ((counter++))
        done < <(tail -n +2 $FILE)

        echo "Distributing to snapshot addresses with (z_sendmany) ..."
        echo "Excluding a total of $excludedcount addresses from this command."
        echo "$excludedjson" > $HOME/excluded_addresses_from_snapshot.json
        echo "Excluded addresses logged to $HOME/excluded_addresses_from_snapshot.json"

        stringizedjson=$(echo $json | jq -sRr '. | sub("\n";"")')
#        stringizedjson=$(echo $json | jq -sj '.')
        z_sendmany="$cli -chain=$chain -stdin z_sendmany $fromaddr"
        echo "$z_sendmany"
        txid=$(echo "$stringizedjson" | $z_sendmany)
        if [[ -z $txid ]]; then
            echo "Error: Unsuccessful! Something went wrong when calling z_sendmany"
        else
           echo "z_sendmany successful... operation id = $txid"
        fi
    else
        echo "File at location $FILE not found, or is a directory etc..."
    fi
#    echo "$json"

fi
