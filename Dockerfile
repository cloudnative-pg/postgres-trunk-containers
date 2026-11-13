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
ARG BASE=debian:13.7-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

FROM $BASE AS minimal

ARG PG_REPO=https://git.postgresql.org/git/postgresql.git
ARG PG_BRANCH=master
ARG PG_MAJOR=20

ENV PATH=/usr/lib/postgresql/$PG_MAJOR/bin:$PATH

# Install runtime and build dependencies
RUN --mount=type=bind,source=build-deps.txt,target=/build-deps.txt \
	--mount=type=bind,source=git-clone-retry.sh,target=/git-clone-retry.sh \
	apt-get update && \
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
	/git-clone-retry.sh -b "$PG_BRANCH" --single-branch "$PG_REPO" /usr/src/postgresql && \
	cd /usr/src/postgresql && \
	export LLVM_CONFIG="/usr/lib/llvm-19/bin/llvm-config" && \
	export CLANG=clang-19 && \
	./configure \
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
		--libdir=/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/ \
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

# Install all locales
RUN apt-get update && \
	apt-get install -y --no-install-recommends locales-all && \
	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*

USER 26

FROM standard AS postgis
USER root
ARG POSTGIS_REPO=https://github.com/postgis/postgis.git
ARG POSTGIS_BRANCH=master
# PostGIS 3.7 moved these extensions out of the main repository
ARG ADDRESS_STANDARDIZER_REPO=https://github.com/postgis/address_standardizer.git
ARG ADDRESS_STANDARDIZER_BRANCH=main
ARG POSTGIS_TIGER_GEOCODER_REPO=https://git.osgeo.org/postgis/postgis_tiger_geocoder.git
ARG POSTGIS_TIGER_GEOCODER_BRANCH=main

RUN --mount=type=bind,source=build-deps.txt,target=/build-deps.txt \
	--mount=type=bind,source=git-clone-retry.sh,target=/git-clone-retry.sh \
	apt-get update && \
	apt-get install -y --no-install-recommends \
		$(cat /build-deps.txt) \
		# runtime deps
		libproj25 \
		libpq5 \
		libgdal36 \
		libgeos-c1t64 \
		libsfcgal2 \
		libpcre2-8-0 \
	&& \
	export PG_CONFIG=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config && \
	mkdir -p /usr/src/postgis && \
	git clone -b "$POSTGIS_BRANCH" --single-branch --depth 1 "$POSTGIS_REPO" /usr/src/postgis && \
	cd /usr/src/postgis && \
	./autogen.sh && \
	./configure --with-pgconfig="$PG_CONFIG" --with-sfcgal && \
	make -j$(nproc) && \
	make install && \
	git clone -b "$ADDRESS_STANDARDIZER_BRANCH" --single-branch --depth 1 "$ADDRESS_STANDARDIZER_REPO" /usr/src/address_standardizer && \
	make -C /usr/src/address_standardizer -j$(nproc) PG_CONFIG="$PG_CONFIG" && \
	make -C /usr/src/address_standardizer PG_CONFIG="$PG_CONFIG" install && \
	/git-clone-retry.sh -b "$POSTGIS_TIGER_GEOCODER_BRANCH" --single-branch --depth 1 "$POSTGIS_TIGER_GEOCODER_REPO" /usr/src/postgis_tiger_geocoder && \
	make -C /usr/src/postgis_tiger_geocoder -j$(nproc) PG_CONFIG="$PG_CONFIG" && \
	make -C /usr/src/postgis_tiger_geocoder PG_CONFIG="$PG_CONFIG" install && \
	apt-get purge -y --auto-remove $(cat /build-deps.txt) && \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
	rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/* /usr/src/postgis /usr/src/address_standardizer /usr/src/postgis_tiger_geocoder

USER 26
