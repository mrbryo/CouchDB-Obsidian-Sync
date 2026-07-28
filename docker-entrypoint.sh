#!/bin/bash
set -e

# Local Vars
FAILEDTOSTART=1
LOCALINIMISSING=2
VMARGSMISSING=3
PERUSERMISSING=4

# Ensure the local.d directory exists
if [ ! -d /opt/couchdb/etc/local.d ] ; then
  mkdir -p /opt/couchdb/etc/local.d
  chmod 755 /opt/couchdb/etc/local.d
  echo "local.d directory created and permissions updated!"
fi

# Ensure the default.d directory exists
if [ ! -d /opt/couchdb/etc/default.d ] ; then
  mkdir -p /opt/couchdb/etc/default.d
  chmod 755 /opt/couchdb/etc/default.d
  echo "default.d directory created and permissions updated!"
fi

# put an empty ini file in local.d to resolve issue from couchdb repo grep error: grep: /opt/couchdb/etc/default.d/*.ini: No such file or directory
echo "# OK to delete this file after placing your own ini files. This file created to resolve grep error from CouchDB docker-entrypoint.sh error." > /opt/couchdb/etc/default.d/fake.ini

# Copy our local.ini if it doesn't exist into local.d folder.
if [ -f /config/local.ini ] ; then
  if [ ! -f /opt/couchdb/etc/local.d/a_local.ini ]; then
    cp /config/local.ini /opt/couchdb/etc/local.d/a_local.ini
  fi
else
  echo "Our local.ini file is missing! Exiting script..."
  exit $LOCALINIMISSING
fi

# check for missing vm.args file to resolve issue: Failed to open arguments file "/opt/couchdb/bin/../etc/vm.args" at "/opt/couchdb": No such file or directory
if [ ! -f /opt/couchdb/etc/vm.args ] ; then
  # vm.args found in /opt/couchdb/releases
  if [ -f /opt/couchdb/releases/vm.args ] ; then
    cp /opt/couchdb/releases/vm.args /opt/couchdb/etc/vm.args
  else
    echo "vm.args file is missing in '/opt/counchdb/releases'."
    # exit $VMARGSMISSING
  fi
else
  echo "vm.args was found in '/opt/couchdb/etc'; no need to copy it."
fi

# change to working directory
cd /opt/couchdb

# Run the official CouchDB entrypoint in the background
echo "Starting official CouchDB entrypoint..."
/docker-entrypoint.sh couchdb &
COUCHDB_PID=$!

if [ -z "$COUCHDB_PID" ]; then
  echo "Failed to start CouchDB"
  exit $FAILEDTOSTART
fi

# Wait for CouchDB to be ready
echo "Waiting for CouchDB to start..."
wait_counter=0
until curl -s http://localhost:5984/ > /dev/null; do
  wait_counter=$((wait_counter + 1))
  if [ $wait_counter -ge 450 ]; then
      echo "CouchDB startup timeout (15 minutes exceeded)"
      exit $FAILEDTOSTART
  elif [ $((wait_counter % 150)) -eq 0 ]; then
    echo "Still waiting for CouchDB to start..."
  fi
  sleep 2
done

echo "CouchDB is running, applying custom configuration..."

# Handle peruser config if enabled
if [ -f /config/peruser.ini ] ; then
  if [ "${COUCHDB_PERUSER:-false}" = "true" ]; then
    if [ ! -f /opt/couchdb/etc/local.d/b_local.ini ]; then
      if [ ! -d /opt/couchdb/etc/local.d ]; then
        mkdir -p /opt/couchdb/etc/local.d
      fi
      cp /config/peruser.ini /opt/couchdb/etc/local.d/b_local.ini

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
        exit $FAILEDTOSTART
      fi

      # Wait for CouchDB to be ready
      wait_counter=0
      until curl -s http://localhost:5984/ > /dev/null; do
        wait_counter=$((wait_counter + 1))
        if [ $wait_counter -ge 450 ]; then
            echo "CouchDB startup timeout after peruser (15 minutes exceeded)"
            exit $FAILEDTOSTART
        elif [ $((wait_counter % 150)) -eq 0 ]; then
          echo "Still waiting for CouchDB to start after peruser config..."
        fi
        sleep 2
      done
    else
      echo "Per User config file already exists in local.d folder; skipping!"
    fi
  else
    echo "Per User is not enabled; skipping...however!"
    echo "Ff this was ever enabled in the past the config file was never removed."
    echo "Who knows what could go wrong if the config file is removed after the DB went through this setup?"
  fi
else
  echo "Our Per User config file is missing! Exiting script..."
  exit $PERUSERMISSING
fi

echo "CouchDB is ready!"

# Keep CouchDB running in the foreground
wait "$COUCHDB_PID"
