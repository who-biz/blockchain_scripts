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

counter=$1
timestamp1=0
timestamp2=0
totalblks=$(($2 - $1))
totaltime=0
upperbound=0
numblocksgt100s=0

while [ $counter -le $2 ]
do
    getblock=$($getblocks$counter)
    datetimestamp=$(echo $getblock | jq -r .timestamp)
    timestamp=$(date +%s --date="$datetimestamp")
    echo "$timestamp"
    if [ $counter -eq $1 ]
    then
        timestamp1=$timestamp
        timestamp2=$timestamp
    else
        timestamp2=$timestamp
    fi
    difference=$(($timestamp2 - $timestamp1))
    if [ $difference -gt 100 ]
    then
        ((numblksgt100s++))
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
    echo "$counter, $difference"
    totaltime=$(($totaltime + $difference))
    ((counter++))
done

echo "total time = $totaltime"
echo "total blocks = $totalblks"
averagetime=$(($totaltime / $totalblks))
echo "average time = $averagetime"
echo "longest = $upperbound"
echo "blocks with >100s solve time = $numblksgt100s"