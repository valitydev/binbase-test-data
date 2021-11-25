FROM dr2.rbkmoney.com/rbkmoney/binbase:05910a0cf3634ad3d8826b7b70d3a8b70444c2f4 as build

MAINTAINER Pavel Popov <p.popov@rbkmoney.com>

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
    && java -jar /opt/binbase/binbase.jar com.rbkmoney.binbase.config.BatchConfig binBaseJob --logging.level.com.rbkmoney.binbase=ERROR --logging.level.com.rbkmoney.binbase.batch.listener.DefaultChunkListener=INFO --batch.file_path=file:/opt/binbase-test-data/data/unzip --batch.shutdown_after_execute=true \
    && psql --command "SELECT pg_size_pretty(pg_database_size('binbase'));" \
    && psql --command "VACUUM FULL;" \
    && psql --command "SELECT pg_size_pretty(pg_database_size('binbase'));" \
    && service postgresql stop

FROM dr2.rbkmoney.com/rbkmoney/binbase:05910a0cf3634ad3d8826b7b70d3a8b70444c2f4

COPY entrypoint.sh /opt/binbase-test-data/entrypoint.sh

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
CMD ["java", "-Xmx256m", "-jar","/opt/binbase/binbase.jar", "--spring.batch.job.enabled=false"]

EXPOSE 8022
