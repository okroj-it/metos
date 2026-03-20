FROM alpine:3.21 AS build

RUN apk add --no-cache curl xz jq
RUN ARCH=$(uname -m) && \
    case "$ARCH" in aarch64) ZIG_ARCH="aarch64-linux" ;; *) ZIG_ARCH="x86_64-linux" ;; esac && \
    ZIG_URL=$(curl -fsSL https://ziglang.org/download/index.json \
    | jq -r ".master[\"${ZIG_ARCH}\"].tarball") && \
    curl -fsSL "$ZIG_URL" | tar -xJ -C /opt --strip-components=1
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
