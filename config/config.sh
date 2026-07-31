#!/bin/bash

# tells bash script to exist immediatly if any command exists with a non-zero status (fails); for example, this way the script fails if the copy fails
set -e

# Copy our local.ini into local.d on each restart in case user changes values
cp /config/local.ini /opt/couchdb/etc/local.d/a_local.ini

# Substitute environment variables
sed -i "s|{COUCHDB_LOG_LEVEL}|${COUCHDB_LOG_LEVEL:-info}|g" /opt/couchdb/etc/local.d/a_local.ini
sed -i "s|{COUCHDB_USER}|${COUCHDB_USER:-admin}|g" /opt/couchdb/etc/local.d/a_local.ini
sed -i "s|{COUCHDB_PASSWORD}|${COUCHDB_PASSWORD:-MustSetPassword!}|g" /opt/couchdb/etc/local.d/a_local.ini
sed -i "s|{COUCHDB_DATA_DIR}|${COUCHDB_DATA_DIR:-/mnt/user/appdata/ObsidianSync/data}|g" /opt/couchdb/etc/local.d/a_local.ini
sed -i "s|{COUCHDB_SECRET}|${COUCHDB_SECRET:-$(openssl rand -hex 16)}|g" /opt/couchdb/etc/local.d/a_local.ini
