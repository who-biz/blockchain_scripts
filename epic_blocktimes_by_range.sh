#!/bin/bash
#
# Bash script to fetch block timestamps from a MimbleWimble blockchain
# and compare on inter-block basis for DAA evaluation
#
# First argument is lower bound of desired block range, second is upper bound
#
# @author who-biz

nodeurl="http://127.0.0.1"
nodeport="13419"

# change this location of verus cli, bitcoin-cli, etc
getblocks="curl -s -X GET $nodeurl:$nodeport/v1/headers/"

# change this to DAA window for 
daawindow=45

# change this to your desired outlier threshold
# stdout at conclusion of script will display count
# of blocks in dataset with solve times larger than threshold
outlierthreshold=100

counter=$1
timestamp1=0
timestamp2=0
totalblks=$(($2 - $1))
totaltime=0
upperbound=0
numoutlierblocks=0

# check that we have 2 arguments
if [ -z "$2" ]
then
    echo "You must enter 2 arguments: a lower bound, and an upper bound."
    echo "Error: only one argument supplied."
    echo "Usage: ./epic_blocktimes_by_range.sh <lowerbound> <upperbound>"
    echo "Exiting..."
    exit
fi

# check that upper bound is greater than lower bound
if [ $1 -ge $2 ]
then
    echo "Please ensure your upper bound ($2) is greater than lower bound ($1)"
    echo "Exiting..."
    exit
fi

# crunch block data
while [ $counter -le $2 ]
do
    getblock=$($getblocks$counter)
    getblockjson=$(echo $getblock)
    datetimestamp=$(jq -r .timestamp <<<"$getblockjson")
    powtype=$(jq -r .proof <<<"$getblockjson")
    timestamp=$(date +%s --date="$datetimestamp")
#    echo "$powtype"
#    echo "$timestamp"
    if [ $counter -eq $1 ]
    then
        timestamp1=$timestamp
        timestamp2=$timestamp
    else
        timestamp2=$timestamp
    fi
    difference=$(($timestamp2 - $timestamp1))
    if [ $difference -gt $outlierthreshold ]
    then
        ((numoutlierblocks++))
    fi
    if [ $difference -gt $upperbound ]
    then
        if [ $counter -gt $daawindow ]
        then
            # ignore outliers from genesis to DAA window
            upperbound=$difference
	    upperboundpowtype=$powtype
	    upperboundheight=$counter
        fi
    fi
    timestamp1=$timestamp
    echo "height = $counter, blocktime = $difference, PoW Type = $powtype"
    totaltime=$(($totaltime + $difference))
    ((counter++))
done


# provide summary of data
echo "total time = $totaltime"
echo "total blocks = $totalblks"
averagetime=$(($totaltime / $totalblks))
echo "average time = $averagetime"
echo "longest blocktime = $upperbound, PowType = $upperboundpowtype, at height = $upperboundheight"
echo "blocks with >$outlierthreshold sec solve time = $numoutlierblocks"
