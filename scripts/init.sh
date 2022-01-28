#!/usr/bin/bash

set -e

# On first start TeamSpeak writes out a sqlite db file. We're going to persist this file
# in a docker volume so that we decouple state from the volume. This way you can
# just build a newer container image for upgrades.

# The TeamSpeak server on first run generates a set of credentials for a serveradmin account
# and for the server query interface. This script's only purpose is to persist these
# credentials in the docker volume associated with this container so that they can
# be retrieved by the user at a later date.

cd /var/ts3server;

# Background w/ stderr redirect. ts3 dumps the keys to stderr.
/opt/ts3server/entrypoint.sh ts3server 2> /var/ts3server/keys.txt &

server_pid=$!
sleep 5
kill -s SIGINT "${server_pid}"


echo "=========================================================="
echo "Database generated and credentials saved to docker volume."
echo "=========================================================="