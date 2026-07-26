#!/bin/bash
set -e

# Start CouchDB in the background
/opt/couchdb/bin/couchdb &
COUCHDB_PID=$!

# if local.ini doesn't exist then copy it over to /opt/couchdb/etc/
if [ ! -f /opt/couchdb/etc/local.ini ] ;  then
  cp ./config/local.ini /opt/couchdb/etc/local.ini
  STATUS=$?
fi

# TODO: Need to allow user to adjust port.

# Wait for CouchDB to be ready
echo "Waiting for CouchDB to start..."
until curl -s http://localhost:5984/ > /dev/null; do
  sleep 5
done

# Because single_node is set to true in the CouchDB ini file, we need to restart once to complete setup of the environment as stated here: https://docs.couchdb.org/en/stable/setup/single-node.html#single-node-setup
# TODO: Add ability to do clusters? Wait on feedback? For myself, it isn't needed.
echo "Restarting CouchDB to apply configuration changes..."
kill $COUCHDB_PID
wait $COUCHDB_PID || true

# Start CouchDB again
/opt/couchdb/bin/couchdb &
COUCHDB_PID=$!

# Wait for CouchDB to be ready
until curl -s http://localhost:5984/ > /dev/null; do
  sleep 5
done

# Should be able to remove the DB inilization since the local.ini has single_node = true; this is supposed to create the system database on restart. We still need to add couch_peruser if COUCHDB_PERUSER environment variable is set to true but must still happen after creation of user DB.
# # Create required system databases (skip _global_changes per CouchDB docs)
# echo "Initializing system databases..."

# curl -X PUT http://localhost:5984/_users \
#   -H "Content-Type: application/json" \
#   -u ${COUCHDB_USER}:${COUCHDB_PASSWORD} || true

# curl -X PUT http://localhost:5984/_replicator \
#   -H "Content-Type: application/json" \
#   -u ${COUCHDB_USER}:${COUCHDB_PASSWORD} || true

# echo "System databases initialized successfully"

# Add couch_peruser configuration to local.ini; must be done after the user database is created as per CouchDB documentation: https://docs.couchdb.org/en/stable/config/couch-peruser.html#database-per-user-options
if [ ! -f /opt/couchdb/etc/local.d/a_local.ini ] && [ ${COUCHDB_PERUSER} -eq "true" ] ; then
  cp ./config/peruser.ini /opt/couchdb/etc/local.d/a_local.ini
  STATUS=$?

  # Restart CouchDB to apply configuration changes
  echo "Restarting CouchDB to apply 'DB per User' configuration changes..."
  kill $COUCHDB_PID
  wait $COUCHDB_PID || true

  # Start CouchDB again
  /opt/couchdb/bin/couchdb &
  COUCHDB_PID=$!

  # Wait for CouchDB to be ready
  until curl -s http://localhost:5984/ > /dev/null; do
    sleep 5
  done
else
  echo "couch_peruser configuration already present in local.ini"
fi

echo "CouchDB Restarted Successfully!"

# Wait for the background CouchDB process
wait $COUCHDB_PID
