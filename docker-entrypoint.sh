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
if [ -z "$COUCHDB_PID" ]; then
  echo "Failed to capture CouchDB process ID"
  exit 1
fi

# Wait for CouchDB to be ready
echo "Waiting for CouchDB to start..."
wait_counter=0
until curl -s http://localhost:5984/ > /dev/null; do
  wait_counter=$((wait_counter + 1))
  if [ $((wait_counter % 150)) -eq 0 ]; then
    echo "(Initial) Still waiting for CouchDB to start..."
    if [ $wait_counter -ge 450 ]; then
      echo "CouchDB startup timeout (15 minutes exceeded)"
      exit 1
    fi
  fi
  sleep 2
done

# Because single_node is set to true in the CouchDB ini file, we need to restart once to complete setup
echo "Restarting CouchDB to complete single-node setup..."
kill "$COUCHDB_PID"
for i in {1..15}; do
  if ! kill -0 "$COUCHDB_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done
# Force kill if still running
kill -9 "$COUCHDB_PID" 2>/dev/null || true

# Start CouchDB again
/opt/couchdb/bin/couchdb &
COUCHDB_PID=$!
if [ -z "$COUCHDB_PID" ]; then
  echo "Failed to restart CouchDB"
  exit 1
fi

# Wait for CouchDB to be ready again
wait_counter=0
until curl -s http://localhost:5984/ > /dev/null; do
  wait_counter=$((wait_counter + 1))
  if [ $((wait_counter % 150)) -eq 0 ]; then
    echo "(Restart 1) Still waiting for CouchDB to start..."
    if [ $wait_counter -ge 450 ]; then
      echo "CouchDB restart timeout (15 minutes exceeded)"
      exit 1
    fi
  fi
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
    if [ ! -d /opt/couchdb/etc/local.d ]; then
      mkdir -p /opt/couchdb/etc/local.d
    fi
    cp /config/peruser.ini /opt/couchdb/etc/local.d/a_local.ini

    # Restart CouchDB to apply configuration changes
    echo "Restarting CouchDB to apply 'DB per User' configuration..."
    kill "$COUCHDB_PID"
    for i in {1..15}; do
      if ! kill -0 "$COUCHDB_PID" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    # Force kill if still running
    kill -9 "$COUCHDB_PID" 2>/dev/null || true

    # Start CouchDB again
    /opt/couchdb/bin/couchdb &
    COUCHDB_PID=$!
    if [ -z "$COUCHDB_PID" ]; then
      echo "Failed to restart CouchDB for peruser config"
      exit 1
    fi

    # Wait for CouchDB to be ready
    wait_counter=0
    until curl -s http://localhost:5984/ > /dev/null; do
      wait_counter=$((wait_counter + 1))
      if [ $((wait_counter % 150)) -eq 0 ]; then
        echo "(Restart 2) Still waiting for CouchDB to start..."
        if [ $wait_counter -ge 450 ]; then
          echo "CouchDB peruser config timeout (15 minutes exceeded)"
          exit 1
        fi
      fi
      sleep 2
    done
  fi
fi

echo "CouchDB is ready!"

# Keep CouchDB running in the foreground
wait "$COUCHDB_PID"
