# vim:set ft=dockerfile:
#
# Copyright The CloudNativePG Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

FROM debian:bullseye-slim

# Do not split the description, otherwise we will see a blank space in the labels
LABEL name="PostgreSQL Container Images" \
      vendor="The CloudNativePG Contributors" \
      version="16-devel" \
      summary="PostgreSQL Container images." \
      description="This Docker image contains a snapshot image of PostgreSQL compiled from Master and Barman Cloud based on Debian bullseye-slim."

COPY build-deps.txt /

# Install runtime and build dependencies
RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		gnupg \
		dirmngr \
		ca-certificates \
		ssl-cert \
		libnss-wrapper \
		libxml2 \
		libllvm11 \
		libxslt1.1 \
		xz-utils \
		zstd \
		$(cat /build-deps.txt); \
	rm -rf /var/lib/apt/lists/*;
# explicitly set user/group IDs
RUN set -eux; \
	groupadd -r postgres --gid=999; \
# https://salsa.debian.org/postgresql/postgresql-common/blob/997d842ee744687d99a2b2d95c1083a2615c79e8/debian/postgresql-common.postinst#L32-35
	useradd -r -g postgres --uid=26 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
# also create the postgres user's home directory with appropriate permissions
# see https://github.com/docker-library/postgres/issues/274
	mkdir -p /var/lib/postgresql; \
	chown -R postgres:postgres /var/lib/postgresql

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.14
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN set -eux; \
	if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
# if this file exists, we're likely in "debian:xxx-slim", and locales are thus being excluded so we need to remove that exclusion (since we need locales)
		grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
		sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
		! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
	fi; \
	apt-get update; apt-get install -y --no-install-recommends locales; rm -rf /var/lib/apt/lists/*; \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

ENV PG_MAJOR 16
ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin

# Build PostgreSQL
# Partially refer to https://github.com/docker-library/postgres/blob/master/15/alpine/Dockerfile#L29-L147
RUN set -eux ; \
	mkdir -p /usr/src/postgresql ; \
	git clone -b master --single-branch https://git.postgresql.org/git/postgresql.git /usr/src/postgresql ; \
	cd /usr/src/postgresql ; \
	./configure \
		--build=x86_64-linux-gnu \
		--prefix=/usr \
		--enable-debug \
		--enable-cassert \
		--enable-nls \
		--enable-thread-safety \
		--enable-dtrace \
		--enable-tap-tests \
		--disable-rpath \
		--with-tcl \
		--with-perl \
		--with-python \
		--with-pam \
		--with-openssl \
		--with-libxml \
		--with-libxslt \
		--with-uuid=e2fs \
		--with-gnu-ld \
		--with-gssapi \
		--with-ldap \
		--with-pgport=5432 \
		--with-system-tzdata=/usr/share/zoneinfo \
		--with-icu \
		--with-llvm \
		--with-lz4 \
		--with-systemd \
		--with-selinux \
		--with-zstd \
		--datarootdir=/usr/share/ \
		--infodir=/usr/share/info \
		--localstatedir=/var \
		--sysconfdir=/etc/postgresql-common \
		--libexecdir=/usr/lib/postgresql/ \
		--includedir=/usr/include/postgresql/ \
		--mandir=/usr/share/postgresql/$PG_MAJOR/man \
		--docdir=/usr/share/doc/postgresql-doc-$PG_MAJOR \
		--datadir=/usr/share/postgresql/$PG_MAJOR \
		--bindir=/usr/lib/postgresql/$PG_MAJOR/bin \
		--libdir=/usr/lib/x86_64-linux-gnu/ \
		CFLAGS="-g -Og -fstack-protector-strong -Wformat -Werror=format-security -fno-omit-frame-pointer" \
		LDFLAGS="-Wl,-z,relro -Wl,-z,now" \
		CPPFLAGS="-Wdate-time -D_FORTIFY_SOURCE=2" \
		CXXFLAGS="-g -Og -fstack-protector-strong -Wformat -Werror=format-security" \
	; \
	make -j "$(nproc)" world-bin ; \
	make install-world-bin ; \
	cd / ; \
	rm -rf /usr/src/postgresql ; \
	postgres --version

# Build PgAudit
# See to https://github.com/pgaudit/pgaudit/blob/master/README.md#compile-and-install
# TODO: reinstate PgAudit once v16 support is ready
RUN set -eux ; \
	mkdir -p /usr/src/pgaudit ; \
	git clone -b dev/pg16 --single-branch  https://github.com/gbartolini/pgaudit.git /usr/src/pgaudit ; \
	cd /usr/src/pgaudit ; \
	make install USE_PGXS=1 PG_CONFIG=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config ; \
	cd / ; \
	rm -rf /usr/src/pgaudit

# Purge build dependencies
RUN set -xe ; \
	apt-get purge -y --autoremove $(cat /build-deps.txt)

# Even though we compile from source, we still need PGDG to gather an updated version of psycopg2
RUN set -ex; \
	key='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8'; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	gpg --batch --export "$key" > /etc/apt/trusted.gpg.d/postgres.gpg; \
	command -v gpgconf > /dev/null && gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	apt-key list

# Install barman-cloud
RUN set -xe; \
	echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main $PG_MAJOR" > /etc/apt/sources.list.d/pgdg.list; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		python3-pip \
		python3-psycopg2 \
		python3-setuptools \
	; \
	pip3 install --upgrade pip; \
	pip3 install barman[cloud,azure,snappy,google]; \
	rm -rf /var/lib/apt/lists/*;

# make the sample config easier to munge (and "correct by default")
RUN set -eux; \
	dpkg-divert --add --rename --divert "/usr/share/postgresql/postgresql.conf.sample.dpkg" "/usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample"; \
	cp -v /usr/share/postgresql/postgresql.conf.sample.dpkg /usr/share/postgresql/postgresql.conf.sample; \
	ln -sv ../postgresql.conf.sample "/usr/share/postgresql/$PG_MAJOR/"; \
	sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample; \
	grep -F "listen_addresses = '*'" /usr/share/postgresql/postgresql.conf.sample

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
# this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/postgresql/data

# DoD 2.3 - remove setuid/setgid from any binary that not strictly requires it, and before doing that list them on the stdout
RUN find / -not -path "/proc/*" -perm /6000 -type f -exec ls -ld {} \; -exec chmod a-s {} \; || true

USER 26

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

# We set the default STOPSIGNAL to SIGINT, which corresponds to what PostgreSQL
# calls "Fast Shutdown mode" wherein new connections are disallowed and any
# in-progress transactions are aborted, allowing PostgreSQL to stop cleanly and
# flush tables to disk, which is the best compromise available to avoid data
# corruption.
#
# Users who know their applications do not keep open long-lived idle connections
# may way to use a value of SIGTERM instead, which corresponds to "Smart
# Shutdown mode" in which any existing sessions are allowed to finish and the
# server stops when all sessions are terminated.
#
# See https://www.postgresql.org/docs/12/server-shutdown.html for more details
# about available PostgreSQL server shutdown signals.
#
# See also https://www.postgresql.org/docs/12/server-start.html for further
# justification of this as the default value, namely that the example (and
# shipped) systemd service files use the "Fast Shutdown mode" for service
# termination.
#
STOPSIGNAL SIGINT
#
# An additional setting that is recommended for all users regardless of this
# value is the runtime "--stop-timeout" (or your orchestrator/runtime's
# equivalent) for controlling how long to wait between sending the defined
# STOPSIGNAL and sending SIGKILL (which is likely to cause data corruption).
#
# The default in most runtimes (such as Docker) is 10 seconds, and the
# documentation at https://www.postgresql.org/docs/12/server-start.html notes
# that even 90 seconds may not be long enough in many instances.

EXPOSE 5432
CMD ["postgres"]
