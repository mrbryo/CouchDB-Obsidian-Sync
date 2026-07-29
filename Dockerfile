FROM debian:bookworm-slim

# Install CouchDB from Debian apt repository
RUN apt-get update && apt-get install -y \
    couchdb \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Expose CouchDB port
EXPOSE 5984

# Start CouchDB in foreground
CMD ["couchdb", "-n"]
