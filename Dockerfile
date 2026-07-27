FROM couchdb:latest

COPY docker-entrypoint.sh /docker-entrypoint-supplement.sh
COPY config/ /config/

RUN chmod +x /docker-entrypoint-supplement.sh
RUN mkdir -p /opt/couchdb/etc/local.d

CMD ["/docker-entrypoint-supplement.sh"]
