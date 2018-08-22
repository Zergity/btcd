#!/bin/sh
#

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
remove=1
daemon_only=0

while getopts "h?nd" opt; do
    case "$opt" in
    h|\?)
        echo "$(basename ""$0"") [-h] [-?] [-n] [-d] nodes_count"
        exit 0
        ;;
	n)	remove=0
		;;
	d)	daemon_only=1
		;;
    esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

# addresses and keys
MINING_ADDRS=(SSwMMZKdfuK7oPjhEGuzVPtGVuGQfaG6Tb					SgPcNHf5PNCwqcg9236t4MEjF9STGCGP6A						SQiWJ4nGKfU1DtSejWBpSSAbaxgHheQaFK						Sbd1cibMeFwbR3eAJimJBHV9EVCLT2WJJX						SQiWJ4nGKfU1DtSejWBpSSAbaxgHheQaFK						SUkMuEFAq5MgzrdFghNF6LB9N5W8e74Q81)
MINING_SKEYS=(FudTNM3XSmTHzxHVkHHXHGAidcaYACK2hKiVLtZAmsuELsf7xShq	FqLdJtGRLBtcR2byJkoXyLryab6ZyuLbXiZpNiNQmmwQ4ES4MsJy	FtFziNXGxvRpAbWsXz8edWatFKirABA6GDZ8w2qCzmyrMpvFK22B	Fu7NBsxm27hMkFLzXZEoSQZGR9hZR4uEBYw1sUT7RqzLEVm7sCQH	FtFziNXGxvRpAbWsXz8edWatFKirABA6GDZ8w2qCzmyrMpvFK22B	Fs2ezDkpassKCSG1UpDqcV2ib1sC5NQNgAZRBsgk2Xgwj7jxLrk3)

# non-opts arguments
if [ "$#" -eq 1 ]; then
    NODES_COUNT=$1
else
	NODES_COUNT=${#MINING_ADDRS[@]}
fi

# process OPTs
if [[ $remove -ne 0 ]]; then
	CMD_RM=--rm
else
	CMD_RM=
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

for ((i=0; i<NODES_COUNT; i++))
do
	NAME=node$i
	PORT=$((18000+i))
	RPCPORT=$((19000+i))
	echo "Node: $NAME"
	if [ ! "$(docker ps -qaf name=$NAME)" ]; then
		docker run -d --name=$NAME --network=$NETWORK --publish=$PORT:$PORT --publish=$RPCPORT:$RPCPORT\
				btcsuite/btcd:alpine\
				btcd --simnet --listen=:$PORT --miningaddr=${MINING_ADDRS[$i]}\
				--rpclisten=:$RPCPORT --rpcuser=a --rpcpass=a\
				--nobanning $ADDPEER
	else
		docker start $NAME
	fi
	sleep 2
	IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $NAME`
	echo "	at $IP:$PORT"
	ADDPEER="$ADDPEER --addpeer=$IP:$PORT"

	if [[ $daemon_only -eq 0 ]]; then
		# start wallets up
		WALLET_NAME=wallet$i
		WALLET_RPCPORT=$((20000+i))

		if [ ! "$(docker ps -qaf name=$WALLET_NAME)" ]; then
			docker run -d --name=$WALLET_NAME --network=$NETWORK --publish=$WALLET_RPCPORT:$WALLET_RPCPORT\
					$CMD_RM\
					btcsuite/btcwallet:alpine\
					btcwallet --simnet\
					--usespv\
					--connect=$IP:$PORT\
					--rpclisten=:$WALLET_RPCPORT --username=a --password=a\
					--createtemp --appdata=/tmp/btcwallet
		else
			docker start $WALLET_NAME
		fi
		echo "	Wallet RPC at $IP:$WALLET_RPCPORT"
	fi
done

if [[ $daemon_only -eq 0 ]]; then
	sleep 5

	# import private key to wallets
	for ((i=0; i<NODES_COUNT; i++))
	do
		WALLET_RPCPORT=$((20000+i))
		btcctl --simnet --rpcuser=a --rpcpass=a --skipverify -s localhost:$WALLET_RPCPORT --wallet\
				walletpassphrase "password" 0 &&\
		btcctl --simnet --rpcuser=a --rpcpass=a --skipverify -s localhost:$WALLET_RPCPORT --wallet\
				importprivkey ${MINING_SKEYS[$i]} &&\
		echo "PrvKey imported: ${MINING_SKEYS[$i]}"
	done
fi
