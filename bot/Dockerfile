FROM alpine:3.21 AS build

# Pinned to match minimum_zig_version in build.zig.zon. Bump together.
# ziglang.org prunes old dev builds; if 404, re-pin to a current master version.
ARG ZIG_VERSION=0.17.0-dev.340+c02d39a21
RUN apk add --no-cache curl xz
RUN ARCH=$(uname -m) && \
    curl -fsSL "https://ziglang.org/builds/zig-${ARCH}-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt --strip-components=1
ENV PATH="/opt:${PATH}"

WORKDIR /app
COPY bot/deps/ deps/
COPY bot/build.zig bot/build.zig.zon ./
COPY bot/src/ src/
COPY core/ ../core/

RUN zig build -Doptimize=ReleaseSafe

FROM alpine:3.21

RUN apk add --no-cache ca-certificates
COPY --from=build /app/zig-out/bin/metos-bot /usr/local/bin/metos-bot

WORKDIR /data
ENTRYPOINT ["metos-bot"]
