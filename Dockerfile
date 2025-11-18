# vim:set ft=dockerfile:
#
# Copyright © contributors to CloudNativePG, established as
# CloudNativePG a Series of LF Projects, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#
ARG BASE=debian:13.2-slim

FROM $BASE AS minimal

ARG PG_REPO=https://git.postgresql.org/git/postgresql.git
ARG PG_BRANCH=master
ARG PG_MAJOR=19

COPY build-deps.txt /

ENV PATH=/usr/lib/postgresql/$PG_MAJOR/bin:$PATH

# Install runtime and build dependencies
RUN apt-get update && \
	apt-get install -y --no-install-recommends -o Dpkg::::="--force-confdef" -o Dpkg::::="--force-confold" \
		gnupg \
		dirmngr \
		ca-certificates \
		ssl-cert \
		libnss-wrapper \
		libgssapi-krb5-2 \
		libprotobuf-c1 \
		libnuma1 \
		liburing2 \
		libxml2 \
		libllvm19 \
		libxslt1.1 \
		xz-utils \
		zstd \
		libicu76 \
		postgresql-common \
		$(cat /build-deps.txt) \
	&& \
	usermod -u 26 postgres && \
	# Build PostgreSQL
	mkdir -p /usr/src/postgresql && \
	git clone -b "$PG_BRANCH" --single-branch "$PG_REPO" /usr/src/postgresql && \
	cd /usr/src/postgresql && \
	export LLVM_CONFIG="/usr/lib/llvm-19/bin/llvm-config" && \
	export CLANG=clang-19 && \
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
		--with-liburing \
		--with-libnuma \
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
	apt-get purge -y --auto-remove $(cat /build-deps.txt) && \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/* /usr/src/postgresql

USER 26

FROM minimal AS standard
USER root

# Build PgAudit
# See to https://github.com/pgaudit/pgaudit/blob/master/README.md#compile-and-install
# TODO: uncomment when https://github.com/pgaudit/pgaudit/issues/257 is fixed
#RUN apt-get update && \
#	apt-get install -y --no-install-recommends \
#		build-essential \
#		git \
#		libssl-dev \
#		libkrb5-dev \
#	&& \
#	mkdir -p /usr/src/pgaudit && \
#	git clone -b main --single-branch https://github.com/pgaudit/pgaudit.git /usr/src/pgaudit && \
#	cd /usr/src/pgaudit && \
#	make install USE_PGXS=1 PG_CONFIG=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config && \
#	apt-get purge -y --auto-remove \
#		build-essential \
#		git \
#		libssl-dev \
#		libkrb5-dev \
#	&& \
#	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
#	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/* /usr/src/pgaudit

# Install all locales
RUN apt-get update && \
	apt-get install -y --no-install-recommends locales-all && \
	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*

USER 26

FROM standard AS postgis
USER root
ARG POSTGIS_REPO=https://github.com/postgis/postgis.git
ARG POSTGIS_BRANCH=master

RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		$(cat /build-deps.txt) \
		# runtime deps
		libproj25 \
		libpq5 \
		libgdal36 \
		libgeos-c1t64 \
		libsfcgal2 \
	&& \
	mkdir -p /usr/src/postgis && \
	git clone -b "$POSTGIS_BRANCH" --single-branch "$POSTGIS_REPO" /usr/src/postgis && \
	cd /usr/src/postgis && \
	./autogen.sh && \
	./configure --with-pgconfig=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config --with-sfcgal && \
	make -j$(nproc) && \
	make install && \
	apt-get purge -y --auto-remove $(cat /build-deps.txt) && \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/* /usr/src/postgis

USER 26
