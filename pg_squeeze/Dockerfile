FROM ghcr.io/cloudnative-pg/postgresql-trunk:18-cf-4913 AS builder

USER 0

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
		libllvm16 \
		libxslt1.1 \
		xz-utils \
		zstd \
		$(cat ../build-deps.txt); \
	rm -rf /var/lib/apt/lists/*;

# Build pgvector
RUN set -eux ; \
	mkdir -p /usr/src/pg_squeeze ; \
	mkdir -p /opt/extension ; \
	git clone -b master --single-branch https://github.com/cybertec-postgresql/pg_squeeze.git /usr/src/pg_squeeze ; \
	cd /usr/src/pg_squeeze ; \
	make install USE_PGXS=1 PG_CONFIG=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config datadir=/opt/extension/share/ pkglibdir=/opt/extension/lib/

FROM scratch

COPY --from=builder /opt/extension/lib/* /18/lib/
COPY --from=builder /opt/extension/share/extension/* /18/share/
