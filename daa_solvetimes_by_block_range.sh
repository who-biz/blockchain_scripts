#!/bin/bash
#
# Bash script to fetch block timestamps from a BTC-style blockchain
# and compare on inter-block basis for DAA evaluation
#
# First argument is lower bound of desired block range, second is upper bound
#
# @author who-biz

# change this location of verus cli, bitcoin-cli, etc
# example cli="$HOME/VerusCoin/src/verus"
cli=""

# change this to relevant chain, ac_name, etc
# example: chain="-chain=vrsctest"
chain=""

if [[ -z $cli ]]; then
    echo "Please modify script with location to command-line interface binary. See script comments for details."
    exit
fi

if [[ -z $1 || -z $2 ]]; then
    echo "This script requires two arguments to run.  Please specify lower bound block height as first arg, and upper bound block height as second arg."
    echo "Example: ./daa_solvetimes_by_block_range.sh 1000 2000"
    exit
fi

# change this to DAA window for chain in question
daawindow=45

counter=$1
timestamp1=0
timestamp2=0
totalblks=$(($2 - $1))
totaltime=0
upperbound=0
numblocksgt60s=0

while [ $counter -le $2 ]
do
    getblock=$($cli $chain getblock $counter)
    timestamp=$(echo $getblock | jq -r .time)
    blocktype=$(echo $getblock | jq -r .validationtype)
    if [ $counter -eq $1 ]
    then
        timestamp1=$timestamp
        timestamp2=$timestamp
    else
        timestamp2=$timestamp
    fi
    difference=$(($timestamp2 - $timestamp1))
    if [ $difference -gt 60 ]
    then
        ((numblksgt60s++))
    fi
    if [ $difference -gt $upperbound ]
    then
        if [ $counter -gt $daawindow ]
        then
            # ignore outliers from genesis to DAA window
            upperbound=$difference
        fi
    fi
    timestamp1=$timestamp
    echo "$counter, $difference, $blocktype"
    totaltime=$(($totaltime + $difference))
    ((counter++))
done

echo "total time = $totaltime"
echo "total blocks = $totalblks"
averagetime=$(($totaltime / $totalblks))
echo "average time = $averagetime"
echo "longest = $upperbound"
echo "blocks with >60s solve time = $numblksgt60s"


