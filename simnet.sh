#!/bin/sh
#

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
interactive=1
debug=0

while getopts "h?bd" opt; do
    case "$opt" in
    h|\?)
        echo "simnet.sh [-h] [-?] [-b] [-d] nodes_count"
        exit 0
        ;;
	b)	interactive=0
		;;
	d)	debug=1
		;;
    esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

# non-opts arguments
NODES_COUNT=$1

# process OPTs
if [[ $debug -ne 0 ]]; then
	CMD_PREFIX=winpty
else
	CMD_PREFIX=start
fi

if [[ $interactive -ne 0 ]]; then
	CMD_IT=-it
	CMD_IA=-ia
else
	CMD_IT=
	CMD_IA=
fi

NETWORK=YggChain

# make sure the network is initilized
if [ ! "$(docker network ls | grep YggChain)" ]; then
	docker network create $NETWORK
fi

# default port (unused)
PORT=18555

# accumulated peers list
ADDPEER=

# expose a random node to the host
#PUBLISH_NODE=$((2 + $RANDOM % NODES_COUNT))

MINING_ADDRS=(SSwMMZKdfuK7oPjhEGuzVPtGVuGQfaG6Tb					SgPcNHf5PNCwqcg9236t4MEjF9STGCGP6A						SQiWJ4nGKfU1DtSejWBpSSAbaxgHheQaFK						Sbd1cibMeFwbR3eAJimJBHV9EVCLT2WJJX						SQiWJ4nGKfU1DtSejWBpSSAbaxgHheQaFK						SUkMuEFAq5MgzrdFghNF6LB9N5W8e74Q81)
MINING_SKEYS=(FudTNM3XSmTHzxHVkHHXHGAidcaYACK2hKiVLtZAmsuELsf7xShq	FqLdJtGRLBtcR2byJkoXyLryab6ZyuLbXiZpNiNQmmwQ4ES4MsJy	FtFziNXGxvRpAbWsXz8edWatFKirABA6GDZ8w2qCzmyrMpvFK22B	Fu7NBsxm27hMkFLzXZEoSQZGR9hZR4uEBYw1sUT7RqzLEVm7sCQH	FtFziNXGxvRpAbWsXz8edWatFKirABA6GDZ8w2qCzmyrMpvFK22B	Fs2ezDkpassKCSG1UpDqcV2ib1sC5NQNgAZRBsgk2Xgwj7jxLrk3)

for ((i=0; i<NODES_COUNT; i++))
do
	NAME=node$i
	PORT=$((18000+i))
	RPCPORT=$((19000+i))
	echo "Node: $NAME"
	if [ ! "$(docker ps -qaf name=$NAME)" ]; then
		$CMD_PREFIX docker run $CMD_IT --name=$NAME --network=$NETWORK --publish=$PORT:$PORT --publish=$RPCPORT:$RPCPORT\
				btcsuite/btcd:alpine\
				btcd --simnet --listen=:$PORT --miningaddr=${MINING_ADDRS[$i]}\
				--rpclisten=:$RPCPORT --rpcuser=a --rpcpass=a\
				--nobanning $ADDPEER
	else
		$CMD_PREFIX docker start $CMD_IA $NAME
	fi
	sleep 2
	IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $NAME`
	echo "	at $IP:$PORT"
	ADDPEER="$ADDPEER --addpeer=$IP:$PORT"

	# start wallets up
	WALLET_RPCPORT=$((20000+i))

	$CMD_PREFIX docker run $CMD_IT --rm --name=wallet$i --network=$NETWORK --publish=$WALLET_RPCPORT:$WALLET_RPCPORT\
			btcsuite/btcwallet:alpine\
			btcwallet --simnet\
			--usespv\
			--rpcconnect=$IP:$RPCPORT\
			--rpclisten=:$WALLET_RPCPORT --username=a --password=a\
			--createtemp --appdata=/tmp/btcwallet
	echo "	Wallet RPC at $IP:$WALLET_RPCPORT"
done

sleep 5

# import private key to wallets
for ((i=0; i<NODES_COUNT; i++))
do
	WALLET_RPCPORT=$((20000+i))
	btcctl --simnet --rpcuser=a --rpcpass=a --skipverify -s localhost:$WALLET_RPCPORT --wallet\
			walletpassphrase "password" 0
	btcctl --simnet --rpcuser=a --rpcpass=a --skipverify -s localhost:$WALLET_RPCPORT --wallet\
			importprivkey ${MINING_SKEYS[$i]}
	echo "Import PrvKey: ${MINING_SKEYS[$i]}"
done
