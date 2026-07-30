#!/bin/bash
set -e

# Logging function with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $1"
}

log "=========================================="
log "CouchDB for Obsidian Sync Entrypoint Script started"
log "=========================================="

# Local Vars
FAILEDTOSTART=1
LOCALINIMISSING=2
VMARGSMISSING=3
PERUSERMISSING=4

# Ensure the local.d directory exists
if [ ! -d /opt/couchdb/etc/local.d ] ; then
  mkdir -p /opt/couchdb/etc/local.d
  chmod 755 /opt/couchdb/etc/local.d
  log "local.d directory created and permissions updated!"
fi

# Ensure the default.d directory exists
if [ ! -d /opt/couchdb/etc/default.d ] ; then
  mkdir -p /opt/couchdb/etc/default.d
  chmod 755 /opt/couchdb/etc/default.d
  log "default.d directory created and permissions updated!"
fi

# put an empty ini file in default.d to resolve issue from couchdb repo grep error, only if directory is empty
if ! ls /opt/couchdb/etc/default.d/*.ini >/dev/null 2>&1; then
  echo "# OK to delete this file after placing your own ini files. This file created to resolve grep error from CouchDB docker-entrypoint.sh error." > /opt/couchdb/etc/default.d/fake.ini
  log "Since '/opt/couchdb/etc/default.d' is empty, created a fake ini file to resolve a grep error in the CouchDB docker-entrypoint.sh."
else
  log "Skipping Fake INI File..."
fi

# Copy our local.ini into local.d on each restart in case user changes values
if [ -f /config/local.ini ] ; then
  cp /config/local.ini /opt/couchdb/etc/local.d/a_local.ini

  # Substitute environment variables
  sed -i "s|{COUCHDB_LOG_LEVEL}|${COUCHDB_LOG_LEVEL:-info}|g" /opt/couchdb/etc/local.d/a_local.ini
  sed -i "s|{COUCHDB_USER}|${COUCHDB_USER:-admin}|g" /opt/couchdb/etc/local.d/a_local.ini
  sed -i "s|{COUCHDB_PASSWORD}|${COUCHDB_PASSWORD:-MustSetPassword!}|g" /opt/couchdb/etc/local.d/a_local.ini
else
  log "Important Note: /config/local.ini is missing. See the README.md for all the details."
fi

# check for missing vm.args file to resolve issue: Failed to open arguments file "/opt/couchdb/bin/../etc/vm.args" at "/opt/couchdb": No such file or directory
if [ ! -f /opt/couchdb/etc/vm.args ] ; then
  # vm.args found in /opt/couchdb/releases
  if [ -f /opt/couchdb/releases/vm.args ] ; then
    cp /opt/couchdb/releases/vm.args /opt/couchdb/etc/vm.args
  else
    log "vm.args file is missing in '/opt/couchdb/releases'."
    # exit $VMARGSMISSING
  fi
else
  log "vm.args was found in '/opt/couchdb/etc'; no need to copy it."
fi

# change to working directory
cd /opt/couchdb

# Run the official CouchDB entrypoint in the background
log "Starting official CouchDB entrypoint..."
/docker-entrypoint.sh couchdb < /dev/null &
COUCHDB_PID=$!

if [ -z "$COUCHDB_PID" ]; then
  log "Failed to start CouchDB"
  exit $FAILEDTOSTART
fi

# Wait for CouchDB to be ready
log "Waiting for CouchDB to start..."
wait_counter=0
until curl -s http://localhost:5984/ > /dev/null; do
  wait_counter=$((wait_counter + 1))
  if [ $wait_counter -ge 450 ]; then
      log "CouchDB startup timeout (15 minutes exceeded)"
      exit $FAILEDTOSTART
  elif [ $((wait_counter % 150)) -eq 0 ]; then
    log "Still waiting for CouchDB to start..."
  fi
  sleep 2
done

log "CouchDB is running, waiting for authentication to be ready..."
wait_counter=0
until curl -s -u ${COUCHDB_USER}:${COUCHDB_PASSWORD} http://localhost:5984/_session > /dev/null 2>&1; do
  wait_counter=$((wait_counter + 1))
  if [ $wait_counter -ge 450 ]; then
      log "CouchDB authentication timeout (15 minutes exceeded)"
      exit $FAILEDTOSTART
  elif [ $((wait_counter % 150)) -eq 0 ]; then
    log "Still waiting for authentication to be ready..."
  fi
  sleep 2
done

log "CouchDB is ready, applying custom configuration..."

# Ensure system databases exist for single-node setup
log "Creating system databases..."
log "Attempting to create _users database..."
curl -m 10 -v -X PUT -u ${COUCHDB_USER}:${COUCHDB_PASSWORD} http://localhost:5984/_users || log "Database may already exist (this is normal)"
log ""
log "Attempting to create _replicator database..."
curl -m 10 -v -X PUT -u ${COUCHDB_USER}:${COUCHDB_PASSWORD} http://localhost:5984/_replicator || log "Database may already exist (this is normal)"
log ""
sleep 2

# Handle peruser config if enabled
if [ -f /config/peruser.ini ] ; then
  if [ "${COUCHDB_PERUSER:-false}" = "true" ]; then
    if [ ! -f /opt/couchdb/etc/local.d/b_local.ini ]; then
      if [ ! -d /opt/couchdb/etc/local.d ]; then
        mkdir -p /opt/couchdb/etc/local.d
      fi
      cp /config/peruser.ini /opt/couchdb/etc/local.d/b_local.ini

      log "Restarting CouchDB to apply peruser configuration..."
      kill "$COUCHDB_PID"
      for i in {1..15}; do
        if ! kill -0 "$COUCHDB_PID" 2>/dev/null; then
          break
        fi
        sleep 1
      done
      kill -9 "$COUCHDB_PID" 2>/dev/null || true

      /docker-entrypoint.sh couchdb < /dev/null &
      COUCHDB_PID=$!
      if [ -z "$COUCHDB_PID" ]; then
        log "Failed to restart CouchDB for peruser config"
        exit $FAILEDTOSTART
      fi

      # Wait for CouchDB to be ready
      wait_counter=0
      until curl -s http://localhost:5984/ > /dev/null; do
        wait_counter=$((wait_counter + 1))
        if [ $wait_counter -ge 450 ]; then
            log "CouchDB startup timeout after peruser (15 minutes exceeded)"
            exit $FAILEDTOSTART
        elif [ $((wait_counter % 150)) -eq 0 ]; then
          log "Still waiting for CouchDB to start after peruser config..."
        fi
        sleep 2
      done

      # Wait for authentication to be ready
      wait_counter=0
      until curl -s -u ${COUCHDB_USER}:${COUCHDB_PASSWORD} http://localhost:5984/_session > /dev/null 2>&1; do
        wait_counter=$((wait_counter + 1))
        if [ $wait_counter -ge 450 ]; then
            log "CouchDB authentication timeout after peruser (15 minutes exceeded)"
            exit $FAILEDTOSTART
        elif [ $((wait_counter % 150)) -eq 0 ]; then
          log "Still waiting for authentication after peruser config..."
        fi
        sleep 2
      done
    else
      log "Per User config file already exists in local.d folder; skipping!"
    fi
  else
    log "Per User is not enabled; skipping! For more details see README.md."
  fi
else
  log "Our Per User config file is missing! Exiting script..."
  exit $PERUSERMISSING
fi

log "CouchDB is ready!"

# Keep CouchDB running in the foreground
wait "$COUCHDB_PID"
