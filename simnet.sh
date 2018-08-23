#!/bin/sh
#

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
remove=0
daemon_only=0

while getopts "h?rd" opt; do
    case "$opt" in
    h|\?)
        echo "$(basename ""$0"") [-h] [-?] [-r] [-d] nodes_count"
        exit 0
        ;;
	r)	remove=1
		;;
	d)	daemon_only=1
		;;
    esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

# addresses and keys
MINING_ADDR=SUkMuEFAq5MgzrdFghNF6LB9N5W8e74Q81
MINING_SKEY=Fs2ezDkpassKCSG1UpDqcV2ib1sC5NQNgAZRBsgk2Xgwj7jxLrk3

# process OPTs
if [[ $remove -ne 0 ]]; then
	rm -rf "$LOCALAPPDATA/btcd/data/simnet"
	rm -rf "$LOCALAPPDATA/btcwallet/simnet"
fi

start btcd --simnet --rpcuser=a --rpcpass=a --miningaddr=$MINING_ADDR

sleep 2

if [[ $daemon_only -eq 0 ]]; then
	start btcwallet --simnet --connect=localhost --username=a --password=a --createtemp --appdata="$LOCALAPPDATA/btcwallet"

	sleep 5

	btcctl --simnet --rpcuser=a --rpcpass=a --skipverify --wallet walletpassphrase "password" 0 &&\
	btcctl --simnet --rpcuser=a --rpcpass=a --skipverify --wallet importprivkey $MINING_SKEY
fi
