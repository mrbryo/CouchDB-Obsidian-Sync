FROM debian:bookworm-slim

# Add CouchDB repository and install
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    && curl https://couchdb.apache.org/repo/keys.asc | gpg --dearmor > /usr/share/keyrings/couchdb-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/couchdb-archive-keyring.gpg] https://apache.jfrog.io/artifactory/couchdb-deb/ bookworm main" | tee /etc/apt/sources.list.d/couchdb.sources.list > /dev/null \
    && apt-get update \
    && apt-get install -y couchdb \
    && rm -rf /var/lib/apt/lists/*

# Expose CouchDB port
EXPOSE 5984

# Start CouchDB in foreground
CMD ["couchdb", "-n"]
