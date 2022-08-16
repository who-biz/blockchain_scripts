#!/bin/bash

# Script to decode txs, where hex input is too large and triggers
# 'Argument list too long' error when attempting to enter in terminal
# Takes txid as argument
#
# @author who-biz

txhash=$1

chipscli="$HOME/chips10sec/src/verus -chain=chipstensec"
tx=$($chipscli getrawtransaction $txhash)
decode=$(echo -e "$tx" | $chipscli -stdin decoderawtransaction 2)
