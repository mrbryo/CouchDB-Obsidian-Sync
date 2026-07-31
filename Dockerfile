# using the (un)official apache docker image
FROM apache/couchdb:latest

# copy over my config
COPY config/ /config/

# make the config.sh script executable
RUN chmod +x /config/config.sh

# execute the script to copy of the local.ini into the local.d folder and update the environment placeholders
RUN /config/config.sh

# launch the database
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD []