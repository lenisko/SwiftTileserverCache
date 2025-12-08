# ================================
# Build image
# ================================
FROM swift:6.0 AS build
WORKDIR /build

# Copy required folders into container
COPY Sources Sources
COPY Tests Tests
COPY Resources Resources
COPY Package.swift Package.swift

# Compile with optimizations
RUN swift build \
    --enable-test-discovery \
    -c release \
    -Xswiftc -g

# ================================
# Run image
# ================================
FROM swift:6.0-slim
WORKDIR /SwiftTileserverCache

# Install imagemagick
RUN apt-get -y update && apt-get install -y imagemagick

# Install tippecanoe requirements
RUN apt-get -y update && apt-get -y install build-essential libsqlite3-dev zlib1g-dev git

RUN git clone https://github.com/mapbox/tippecanoe.git -b 1.36.0 \
 && cd tippecanoe \
 && make -j \
 && make install \
 && rm -rf tippecanoe

# Install fontnik requirements
RUN apt-get -y update && apt-get -y install nodejs npm curl

# Install fontnik (arm64 needs custom build with relaxed compiler warnings)
RUN if [ "$(dpkg --print-architecture)" = "arm64" ]; then \
        git clone -b fix-build-errors-node14 https://github.com/lenisko/node-fontnik.git ./fontnik \
        && cd fontnik \
        && mkdir .toolchain \
        && CXXFLAGS="-Wno-error=maybe-uninitialized" npm install --build-from-source \
        && npm link; \
    else \
        npm install -g fontnik@0.7.4; \
    fi

# Copy build artifacts
COPY --from=build /build/.build/release /SwiftTileserverCache
# Copy Resources
COPY --from=build /build/Resources /SwiftTileserverCache/Resources

ENTRYPOINT ["./SwiftTileserverCacheApp"]
CMD ["serve", "--env", "production", "--log", "info", "--hostname", "0.0.0.0", "--port", "9000"]
