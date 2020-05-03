FROM perl:5.30-slim

COPY bin/ /app/bin/
COPY lib/ /app/lib/
COPY Build.PL cpanfile* /app/

WORKDIR /app

ARG DEBIAN_FRONTEND=noninteractive
ARG APT_LISTCHANGES_FRONTEND=none

RUN apt-get update \
	&& apt-get -y --no-install-recommends install ca-certificates curl gcc libc6-dev libssl1.1 libssl-dev libxml2 libxml2-dev make zlib1g-dev \
	&& cpanm -n --no-man-pages --installdeps . \
	&& perl Build.PL \
	&& perl Build \
	&& rm -rf ~/.cpanm \
	&& apt-get -y purge curl gcc libc6-dev libssl-dev libxml2-dev make zlib1g-dev \
	&& apt-get -y autoremove \
	&& apt-get -y clean \
	&& rm -rf /var/cache/apt/* /var/lib/apt/lists/*

ENTRYPOINT ["perl", "-Ilib", "bin/hafas-m"]
