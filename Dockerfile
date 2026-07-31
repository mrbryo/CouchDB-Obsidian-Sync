# using the (un)official apache docker image
FROM apache/couchdb:latest

# copy over my config
COPY config/ /config/

# copy over my wrapper script
COPY docker-entrypoint-wrapper.sh /docker-entrypoint-wrapper.sh

# make the entrypoint script executable
RUN chmod +x /docker-entrypoint-wrapper.sh

# launch the database
ENTRYPOINT [ "/docker-entrypoint-wrapper.sh" ]
CMD []