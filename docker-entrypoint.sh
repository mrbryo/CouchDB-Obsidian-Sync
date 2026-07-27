#!/bin/bash
set -e

cd /opt/couchdb

# Copy local.ini if it doesn't exist
if [ ! -f /opt/couchdb/etc/local.ini ] ; then
  cp /config/local.ini /opt/couchdb/etc/local.ini
fi

# Start CouchDB in the background for initialization
echo "Starting CouchDB for initialization..."
/opt/couchdb/bin/couchdb &
COUCHDB_PID=$!

# Wait for CouchDB to be ready
echo "Waiting for CouchDB to start..."
until curl -s http://localhost:5984/ > /dev/null; do
  sleep 2
done

# Because single_node is set to true in the CouchDB ini file, we need to restart once to complete setup
echo "Restarting CouchDB to complete single-node setup..."
kill $COUCHDB_PID
wait $COUCHDB_PID || true

# Start CouchDB again
/opt/couchdb/bin/couchdb &
COUCHDB_PID=$!

# Wait for CouchDB to be ready again
until curl -s http://localhost:5984/ > /dev/null; do
  sleep 2
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

# Add couch_peruser configuration if enabled
if [ -f /config/peruser.ini ] && [ ! -f /opt/couchdb/etc/local.d/a_local.ini ]; then
  if [ "${COUCHDB_PERUSER:-false}" = "true" ]; then
    cp /config/peruser.ini /opt/couchdb/etc/local.d/a_local.ini

    # Restart CouchDB to apply configuration changes
    echo "Restarting CouchDB to apply 'DB per User' configuration..."
    kill $COUCHDB_PID
    wait $COUCHDB_PID || true

    # Start CouchDB again
    /opt/couchdb/bin/couchdb &
    COUCHDB_PID=$!

    # Wait for CouchDB to be ready
    until curl -s http://localhost:5984/ > /dev/null; do
      sleep 2
    done
  fi
fi

echo "CouchDB is ready!"

# Keep CouchDB running in the foreground
wait $COUCHDB_PID
