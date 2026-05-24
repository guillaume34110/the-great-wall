# syntax=docker/dockerfile:1
# Build Luanti depuis sources vendored localement (./engine, ./games)

ARG DOCKER_IMAGE=alpine:3.23

# ---------- Étape 1 : deps de build ----------
FROM $DOCKER_IMAGE AS dev

ENV LUAJIT_VERSION=v2.1

RUN apk add --no-cache git build-base cmake curl-dev zlib-dev zstd-dev \
        sqlite-dev postgresql-dev hiredis-dev leveldb-dev \
        gmp-dev jsoncpp-dev ninja

WORKDIR /usr/src/

ADD https://github.com/jupp0r/prometheus-cpp.git#master /usr/src/prometheus-cpp
ADD https://github.com/libspatialindex/libspatialindex.git#main /usr/src/libspatialindex
ADD --keep-git-dir https://luajit.org/git/luajit.git#${LUAJIT_VERSION} /usr/src/luajit

RUN cd prometheus-cpp && \
        cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local \
            -DCMAKE_BUILD_TYPE=Release -DENABLE_TESTING=0 -GNinja && \
        cmake --build build && cmake --install build && \
    cd /usr/src/libspatialindex && \
        cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local && \
        cmake --build build && cmake --install build && \
    cd /usr/src/luajit && \
        make amalg && make install

# ---------- Étape 2 : build du serveur Luanti ----------
FROM dev AS builder

COPY engine/CMakeLists.txt          /usr/src/luanti/CMakeLists.txt
COPY engine/README.md               /usr/src/luanti/README.md
COPY engine/minetest.conf.example   /usr/src/luanti/minetest.conf.example
COPY engine/builtin                 /usr/src/luanti/builtin
COPY engine/cmake                   /usr/src/luanti/cmake
COPY engine/doc                     /usr/src/luanti/doc
COPY engine/fonts                   /usr/src/luanti/fonts
COPY engine/lib                     /usr/src/luanti/lib
COPY engine/misc                    /usr/src/luanti/misc
COPY engine/po                      /usr/src/luanti/po
COPY engine/src                     /usr/src/luanti/src
COPY engine/irr                     /usr/src/luanti/irr
COPY engine/textures                /usr/src/luanti/textures

WORKDIR /usr/src/luanti
RUN cmake -B build \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        -DVERSION_EXTRA=tgw \
        -DBUILD_SERVER=TRUE \
        -DENABLE_PROMETHEUS=TRUE \
        -DBUILD_UNITTESTS=FALSE -DBUILD_BENCHMARKS=FALSE \
        -DBUILD_CLIENT=FALSE \
        -GNinja && \
    cmake --build build && \
    cmake --install build

# ---------- Étape 3 : runtime minimal ----------
FROM $DOCKER_IMAGE AS runtime

RUN apk add --no-cache curl gmp libstdc++ libgcc libpq jsoncpp zstd-libs \
            sqlite-libs postgresql hiredis leveldb su-exec && \
    adduser -D minetest --uid 30000 -h /var/lib/minetest && \
    chown -R minetest:minetest /var/lib/minetest

WORKDIR /var/lib/minetest

COPY --from=builder /usr/local/share/luanti                                   /usr/local/share/luanti
COPY --from=builder /usr/local/bin/luantiserver                               /usr/local/bin/luantiserver
COPY --from=builder /usr/local/share/doc/luanti/minetest.conf.example         /etc/minetest/minetest.conf.example
COPY --from=builder /usr/local/lib/libspatialindex*                           /usr/local/lib/
COPY --from=builder /usr/local/lib/libluajit*                                 /usr/local/lib/

# Installe le game The Great Wall (vendored, fork élagué de minetest_game)
COPY --chown=minetest:minetest games/the_great_wall /usr/local/share/luanti/games/the_great_wall

# Config serveur baked dans l'image
COPY config/minetest.conf /etc/minetest/minetest.conf

# Entrypoint qui fixe les droits du volume monté avant de drop les privilèges
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 30000/udp 30000/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["--config", "/etc/minetest/minetest.conf", \
     "--world", "/var/lib/minetest/.minetest/worlds/world", \
     "--gameid", "the_great_wall"]
