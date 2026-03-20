FROM node:22-alpine AS frontend

WORKDIR /app/frontend
COPY server/frontend/package.json server/frontend/package-lock.json* ./
RUN npm install
COPY server/frontend/ .
RUN npx tsc && npx vite build

FROM alpine:3.21 AS build

RUN apk add --no-cache curl xz jq
RUN ARCH=$(uname -m) && \
    case "$ARCH" in aarch64) ZIG_ARCH="aarch64-linux" ;; *) ZIG_ARCH="x86_64-linux" ;; esac && \
    ZIG_URL=$(curl -fsSL https://ziglang.org/download/index.json \
    | jq -r ".master[\"${ZIG_ARCH}\"].tarball") && \
    curl -fsSL "$ZIG_URL" | tar -xJ -C /opt --strip-components=1
ENV PATH="/opt:${PATH}"

WORKDIR /app
COPY server/deps/ deps/
COPY server/build.zig server/build.zig.zon ./
COPY server/embedded_ui.zig ./
COPY server/src/ src/
COPY core/ ../core/
COPY --from=frontend /app/ui/ ui/

RUN zig build -Doptimize=ReleaseSafe -Dskip-frontend

FROM alpine:3.21

RUN apk add --no-cache ca-certificates
COPY --from=build /app/zig-out/bin/metos-server /usr/local/bin/metos-server

WORKDIR /data
EXPOSE 3000
ENTRYPOINT ["metos-server"]
