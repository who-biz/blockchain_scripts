#!/bin/bash
SHELL=/bin/sh PATH=/bin:/sbin:/usr/bin:/usr/sbin
#
# You MUST have jq installed for this to work https://stedolan.github.io/jq/download/
#
# use like: ./consolidate_chips.sh RCGxKMDxZcBGRZkxvgCRAXGpiQFt8wU7Wq 0.001
# Where first argument is address to be sent to, and second argument is minimum amount
#
# @author TheComputerGenie
# @edits  who-biz - for compat with VRSC-based chips

chipscli="$HOME/chips-10sec/src/verus -chain=chipstensec"

Addy=""
if [ "${1}" = "" ]; then
    echo "Need an address to send to"
    exit 1
fi
Addy=${1}

enabled="y"

maxInc="1500" MinCheck="1" RawOut="[" OutAmount="0"
maxconf=$($chipscli getblockcount) maxconf=$((maxconf + 1))
txids=() vouts=() amounts=()
SECONDS=0
echo "Finding UTXOS in $maxconf blocks to consolidate ..."
unspents=$($chipscli listunspent $MinCheck $maxconf)

inputUTXOs=""
if [[ -z $2 ]]; then
    inputUTXOs=$(jq -cr '[map(select(.spendable == true)) | .[] | {txid, vout, amount}]' <<<"${unspents}")
else
    inputUTXOs=$(jq -cr --arg lim "$2" '[map(select(.spendable == true)) | .[] | select(.amount>=($lim|tonumber)) | {txid, vout, amount}]' <<<"${unspents}")
fi

UTXOcount=$(jq -r '.|length' <<<"${inputUTXOs}")
duration=$SECONDS
echo "Found $UTXOcount UTXOs.... $(($duration % 60)) seconds"

function makeRaw() {
    for ((tc = 0; tc <= $1 - 1; tc++)); do
        RawOut2="{\"txid\":\"${txids[tc]}\",\"vout\":${vouts[tc]}},"
        RawOut="$RawOut$RawOut2"
        OutAmount=$(echo "scale=8; ($OutAmount + ${amounts[tc]})" | bc)
    done
    OutAmount=$(echo "scale=8; $OutAmount" | bc) OutAmount=${OutAmount/#./0.} #0.001 is the transaction fee you wish to spend
    RawOut="${RawOut::-1}" RawOut=$RawOut"] {\"$Addy\":$OutAmount}"
}
function addnlocktime() {
    #nlocktime=$(printf "%08x" $(date +%s) | dd conv=swab 2>/dev/null | rev)
	nlocktime="00000000"
    chophex=${toSign::-8}
    newhex=$chophex$nlocktime
}

if [[ $enabled == "y" ]]; then
    LoopsCount=$(echo "scale=0; ($UTXOcount / $maxInc)" | bc)
    echo "This will take $LoopsCount transaction(s) to complete...."
    SECONDS=0
    for txid in $(jq -r '.[].txid' <<<"${inputUTXOs}"); do txids+=("$txid"); done
    duration=$SECONDS
    echo "Captured txids... $(($duration % 60)) seconds"
    SECONDS=0
    for vout in $(jq -r '.[].vout' <<<"${inputUTXOs}"); do vouts+=("$vout"); done
    duration=$SECONDS
    echo "Captured vouts... $(($duration % 60)) seconds"
    SECONDS=0
    for amount in $(jq -r '.[].amount' <<<"${inputUTXOs}"); do
        if [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            amounts+=("$amount")
        else
            amounts+=("$(printf "%.8f" $amount)")
        fi
    done
    duration=$SECONDS
    echo "Captured amounts... $(($duration % 60)) seconds"
    echo "Packed and ready to begin...."
    for ((tlc = 0; tlc <= $LoopsCount; tlc++)); do
        echo "${#vouts[@]} UTXOs left to consolitate..."
        SECONDS=0
        if [[ ${#vouts[@]} -ge $maxInc ]]; then
            makeRaw $maxInc
        else
            makeRaw ${#vouts[@]}
        fi
        duration=$SECONDS
        echo "Created raw consolidated tx $(($duration % 60)) seconds"
        #echo $RawOut
        SECONDS=0
        toSign=$($chipscli createrawtransaction $RawOut)
        addnlocktime
        Signed=$($chipscli signrawtransaction $newhex | jq -r '.hex')
        lasttx=$(echo -e "$Signed" | $chipscli -stdin sendrawtransaction)
        echo "Consolidated $(jq '. | length' <<<"${RawOut}") UTXOs:"
        duration=$SECONDS
        echo "Sent signed raw consolidated tx: $lasttx for $OutAmount $ac_name  $(($duration % 60)) seconds"

        txids=("${txids[@]:$maxInc}")
        vouts=("${vouts[@]:$maxInc}")
        amounts=("${amounts[@]:$maxInc}")
        RawOut="[" OutAmount="0"
        sleep 3
    done

else
    echo "${unspents}"
fi
exit 1
