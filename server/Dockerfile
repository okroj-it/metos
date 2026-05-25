FROM node:22-alpine AS frontend

WORKDIR /app/frontend
COPY server/frontend/package.json server/frontend/package-lock.json* ./
RUN npm install
COPY server/frontend/ .
RUN npx tsc && npx vite build

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
