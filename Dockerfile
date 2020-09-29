FROM alpine:latest as unzip-apk
RUN apk update && apk add unzip
COPY data /opt/binbase-test-data/data
RUN unzip /opt/binbase-test-data/data/\*.zip -d /opt/binbase-test-data/data/unzip

FROM dr2.rbkmoney.com/rbkmoney/binbase:8faa3606076e044b62f141d2cb1060b719491618 as binbase-test-data
FROM dr2.rbkmoney.com/rbkmoney/build:f3732d29a5e622aabf80542b5138b3631a726adb as build

MAINTAINER Pavel Popov <p.popov@rbkmoney.com>

COPY --from=binbase-test-data / /tmp/portage-root/


ENV PGDATA "/etc/postgresql-9.6/"
ENV DATA_DIR "/var/lib/postgresql/9.6/data"
ENV PG_INITDB_OPTS "--username=postgres --auth-host=trust --auth-local=trust --locale=en_US.UTF-8"

ENV ROOT=/tmp/portage-root

ENV LD_LIBRARY_PATH=$ROOT/usr/lib64/

RUN mkdir -p /etc/postgresql-9.6/ && echo dev-db/postgresql server > /etc/portage/package.use/postgresql \
    && git clone git://git.bakka.su/gentoo-mirror --depth 1 /usr/portage \
    && /sbin/ldconfig /$ROOT/usr/lib64/ \
    && emerge --usepkgonly --binpkg-respect-use dev-db/postgresql:9.6 \
    && emerge --config dev-db/postgresql:9.6

FROM dr2.rbkmoney.com/rbkmoney/binbase:8faa3606076e044b62f141d2cb1060b719491618
ENV LOG_PATH /tmp/
COPY --from=build /tmp/portage-root/ /
COPY --from=build /var/lib/postgresql/9.6/data /var/lib/postgresql/9.6/data
COPY --from=build /etc/postgresql-9.6 /etc/postgresql-9.6
COPY entrypoint.sh /opt/binbase-test-data/entrypoint.sh
COPY --from=unzip-apk /opt/binbase-test-data/data/unzip /opt/binbase-test-data/data

RUN echo postgres:x:70: >> /etc/group \
    && echo postgres:x:70:70::/var/lib/postgresql:/bin/sh >> /etc/passwd \
    && echo postgres:!:17725:::::: >> /etc/shadow \
    && mkdir /run /run/postgresql

RUN chmod 0700 -R /var/lib/postgresql/9.6/data \
    && chown postgres:postgres -R \
        /var/lib/postgresql/9.6/data \
        /etc/postgresql-9.6\
        /run/postgresql \
        /opt/binbase-test-data \
    && chmod +x /opt/binbase-test-data/entrypoint.sh

USER postgres
RUN pg_ctl -D /var/lib/postgresql/9.6/data start -w \
    && psql --command "ALTER USER postgres WITH SUPERUSER PASSWORD 'postgres';" \
    && createdb -O postgres binbase \
    && java -jar /opt/binbase/binbase.jar com.rbkmoney.binbase.config.BatchConfig binBaseJob --logging.level.com.rbkmoney.binbase=ERROR --logging.level.com.rbkmoney.binbase.batch.listener.DefaultChunkListener=INFO --batch.file_path=file:/opt/binbase-test-data/data --batch.shutdown_after_execute=true \
    && pg_ctl -D /var/lib/postgresql/9.6/data stop -w \
    && rm -rf /opt/binbase-test-data/data/*

WORKDIR /opt/binbase-test-data
ENTRYPOINT ["/opt/binbase-test-data/entrypoint.sh"]
CMD ["java", "-Xmx256m", "-jar","/opt/binbase/binbase.jar", "--spring.batch.job.enabled=false"]

EXPOSE 8022
