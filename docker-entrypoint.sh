#!/bin/bash
set -e

cd /opt/couchdb

# Run the official CouchDB entrypoint in the background
echo "Starting official CouchDB entrypoint..."
/docker-entrypoint.sh couchdb &
COUCHDB_PID=$!

if [ -z "$COUCHDB_PID" ]; then
  echo "Failed to start CouchDB"
  exit 1
fi

# Wait for CouchDB to be ready
echo "Waiting for CouchDB to start..."
wait_counter=0
until curl -s http://localhost:5984/ > /dev/null; do
  wait_counter=$((wait_counter + 1))
  if [ $((wait_counter % 150)) -eq 0 ]; then
    echo "Still waiting for CouchDB to start..."
    if [ $wait_counter -ge 450 ]; then
      echo "CouchDB startup timeout (15 minutes exceeded)"
      exit 1
    fi
  fi
  sleep 2
done

echo "CouchDB is running, applying custom configuration..."

# Copy local.ini if it doesn't exist
if [ -f /config/local.ini ] && [ ! -f /opt/couchdb/etc/local.ini ]; then
  cp /config/local.ini /opt/couchdb/etc/local.ini
  echo "Restarting CouchDB to apply local.ini configuration..."
  kill "$COUCHDB_PID"
  for i in {1..15}; do
    if ! kill -0 "$COUCHDB_PID" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  kill -9 "$COUCHDB_PID" 2>/dev/null || true

  /docker-entrypoint.sh couchdb &
  COUCHDB_PID=$!
  if [ -z "$COUCHDB_PID" ]; then
    echo "Failed to restart CouchDB"
    exit 1
  fi

  # Wait for CouchDB to be ready
  wait_counter=0
  until curl -s http://localhost:5984/ > /dev/null; do
    wait_counter=$((wait_counter + 1))
    if [ $((wait_counter % 150)) -eq 0 ]; then
      echo "Still waiting for CouchDB to start after config change..."
      if [ $wait_counter -ge 450 ]; then
        echo "CouchDB startup timeout after config (15 minutes exceeded)"
        exit 1
      fi
    fi
    sleep 2
  done
fi

# Handle peruser config if enabled
if [ -f /config/peruser.ini ] && [ ! -f /opt/couchdb/etc/local.d/a_local.ini ]; then
  if [ "${COUCHDB_PERUSER:-false}" = "true" ]; then
    if [ ! -d /opt/couchdb/etc/local.d ]; then
      mkdir -p /opt/couchdb/etc/local.d
    fi
    cp /config/peruser.ini /opt/couchdb/etc/local.d/a_local.ini

    echo "Restarting CouchDB to apply peruser configuration..."
    kill "$COUCHDB_PID"
    for i in {1..15}; do
      if ! kill -0 "$COUCHDB_PID" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    kill -9 "$COUCHDB_PID" 2>/dev/null || true

    /docker-entrypoint.sh couchdb &
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
        echo "Still waiting for CouchDB to start after peruser config..."
        if [ $wait_counter -ge 450 ]; then
          echo "CouchDB startup timeout after peruser (15 minutes exceeded)"
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
