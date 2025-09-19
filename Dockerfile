FROM --platform=$BUILDPLATFORM ghcr.io/valitydev/binbase:sha-633c44f as build

USER root
RUN apt update \
    && apt install -y \
    postgresql \
    unzip \
    && rm -rf /var/lib/apt/lists/*

COPY data /opt/binbase-test-data/data
RUN unzip /opt/binbase-test-data/data/\*.zip -d /opt/binbase-test-data/data/unzip

USER postgres
RUN service postgresql start \
    && psql --command "CREATE DATABASE binbase;" \
    && psql --command "ALTER USER postgres WITH SUPERUSER PASSWORD 'postgres';" \
    && java -jar /opt/binbase/binbase.jar dev.vality.binbase.config.BatchConfig binBaseJob --logging.level.dev.vality.binbase=ERROR --logging.level.dev.vality.binbase.batch.listener.DefaultChunkListener=INFO --batch.file_path=file:/opt/binbase-test-data/data/unzip --batch.shutdown_after_execute=true  --server.port=0 --batch.strict_mode=false \
    && psql --command "SELECT pg_size_pretty(pg_database_size('binbase'));" \
    && psql --command "VACUUM FULL;" \
    && psql --command "SELECT pg_size_pretty(pg_database_size('binbase'));" \
    && service postgresql stop

FROM ghcr.io/valitydev/binbase:sha-633c44f

COPY entrypoint.sh /opt/binbase-test-data/entrypoint.sh

USER root
RUN apt update \
    && apt install -y \
    postgresql \
    && rm -rf /var/lib/apt/lists/* \
    && chmod +x /opt/binbase-test-data/entrypoint.sh

USER postgres

COPY --chown=postgres:postgres --from=build /var/lib/postgresql/ /var/lib/postgresql/
COPY --chown=postgres:postgres --from=build /etc/postgresql/ /etc/postgresql/

WORKDIR /opt/binbase-test-data
ENTRYPOINT ["/opt/binbase-test-data/entrypoint.sh"]
CMD ["java", "-Xmx256m", "-jar","/opt/binbase/binbase.jar", "--spring.batch.job.enabled=false --batch.strict_mode=false"]

EXPOSE 8022
