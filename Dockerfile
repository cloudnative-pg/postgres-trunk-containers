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
FROM debian:12.10-slim

ARG PG_REPO=https://git.postgresql.org/git/postgresql.git
ARG PG_BRANCH=master
ARG PG_MAJOR=18

# Do not split the description, otherwise we will see a blank space in the labels
LABEL name="PostgreSQL Container Images" \
      vendor="The CloudNativePG Contributors" \
      version="$PG_MAJOR-devel" \
      summary="PostgreSQL Container images." \
      description="This Docker image contains a snapshot image of PostgreSQL compiled from Master and Barman Cloud based on Debian bookworm-slim."

COPY build-deps.txt /

# Install runtime and build dependencies
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		gnupg \
		dirmngr \
		ca-certificates \
		locales-all \
		ssl-cert \
		libnss-wrapper \
		libxml2 \
		libllvm16 \
		libxslt1.1 \
		xz-utils \
		zstd \
		$(cat /build-deps.txt) && \
	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*

# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 && \
	useradd -r -g postgres --uid=26 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres && \
	mkdir -p /var/lib/postgresql && \
	chown -R postgres:postgres /var/lib/postgresql

ENV PG_MAJOR=$PG_MAJOR
ENV PATH=/usr/lib/postgresql/$PG_MAJOR/bin:$PATH

# Build PostgreSQL
# Partially refer to https://github.com/docker-library/postgres/blob/master/16/alpine3.21/Dockerfile#L119-L159
RUN mkdir -p /usr/src/postgresql && \
	git clone -b "$PG_BRANCH" --single-branch "$PG_REPO" /usr/src/postgresql && \
	cd /usr/src/postgresql && \
	export LLVM_CONFIG="/usr/lib/llvm-16/bin/llvm-config" && \
	export CLANG=clang-16 && \
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
		--with-extra-version=-$(git rev-parse --short HEAD) \
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
	&& \
	make -j "$(nproc)" world-bin && \
	make install-world-bin && \
	rm -rf /usr/src/postgresql

# TODO: re-enable once https://github.com/pgaudit/pgaudit/issues/257 is fixed
# Build PgAudit
# See to https://github.com/pgaudit/pgaudit/blob/master/README.md#compile-and-install
# RUN mkdir -p /usr/src/pgaudit && \
#	git clone -b main --single-branch https://github.com/pgaudit/pgaudit.git /usr/src/pgaudit && \
#	cd /usr/src/pgaudit && \
#	make install USE_PGXS=1 PG_CONFIG=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config && \
#	rm -rf /usr/src/pgaudit

# Purge build dependencies
RUN apt-get purge -y --autoremove $(cat /build-deps.txt)

# Install barman-cloud
RUN key='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' && \
	export GNUPGHOME="$(mktemp -d)" && \
	mkdir -p /usr/local/share/keyrings/ && \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" && \
	gpg --batch --export --armor "$key" > /usr/local/share/keyrings/postgres.gpg.asc && \
	gpgconf --kill all && \
	rm -rf "$GNUPGHOME" && \
	aptRepo="[ signed-by=/usr/local/share/keyrings/postgres.gpg.asc ] http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main $PG_MAJOR" && \
	echo "deb $aptRepo" > /etc/apt/sources.list.d/pgdg.list && \
	apt-get update && \
	apt-get install -y --no-install-recommends \
		python3-pip \
		python3-psycopg2 \
		python3-setuptools \
	&& \
	pip3 install --break-system-packages --upgrade pip && \
	pip3 install --break-system-packages barman[cloud,azure,google,snappy,zstandard,lz4]==3.12.1 boto3==1.35.99 && \
	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*

# DoD 2.3 - remove setuid/setgid from any binary that not strictly requires it, and before doing that list them on the stdout
RUN find / -not -path "/proc/*" -perm /6000 -type f -exec ls -ld {} \; -exec chmod a-s {} \; || true

USER 26
