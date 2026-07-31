# using the (un)official apache docker image
FROM apache/couchdb:latest

# copy over my config
COPY config/ /config/

# make the config.sh script executable
RUN chmod +x /config/config.sh

# make the entrypoint script executable
RUN chmod +x /docker-entrypoint-wrapper.sh

# launch the database
ENTRYPOINT [ "/docker-entrypoint-wrapper.sh" ]
CMD []