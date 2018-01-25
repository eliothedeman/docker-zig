FROM debian:stable as builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        cmake \
        build-essential \
        zlib1g-dev \
        python \
        wget \
        xz-utils \
        libquadmath0

RUN mkdir -p /deps

# llvm
WORKDIR /deps
RUN wget http://releases.llvm.org/5.0.1/llvm-5.0.1.src.tar.xz
RUN tar xf llvm-5.0.1.src.tar.xz
RUN mkdir -p /deps/llvm-5.0.1.src/build
WORKDIR /deps/llvm-5.0.1.src/build
RUN cmake .. -DCMAKE_INSTALL_PREFIX=/deps/local -DCMAKE_PREFIX_PATH=/deps/local -DCMAKE_BUILD_TYPE=Release
RUN make install

# clang
WORKDIR /deps
RUN wget http://releases.llvm.org/5.0.1/cfe-5.0.1.src.tar.xz
RUN tar xf cfe-5.0.1.src.tar.xz
RUN mkdir -p /deps/cfe-5.0.1.src/build
WORKDIR /deps/cfe-5.0.1.src/build
RUN cmake .. -DCMAKE_INSTALL_PREFIX=/deps/local -DCMAKE_PREFIX_PATH=/deps/local -DCMAKE_BUILD_TYPE=Release
RUN make install

# zig
ARG ZIG_BRANCH=master

WORKDIR /deps
RUN git clone --branch $ZIG_BRANCH --depth 1 https://github.com/zig-lang/zig
RUN mkdir -p /deps/zig/build
WORKDIR /deps/zig/build
# Install to /usr and mirror this on the copy
RUN cmake .. \
    -DZIG_LIBC_LIB_DIR=$(dirname $(cc -print-file-name=crt1.o))            \
    -DZIG_LIBC_INCLUDE_DIR=$(echo -n | cc -E -x c - -v 2>&1 |              \
                             grep -B1 "End of search list." |              \
                             head -n1 | cut -c 2- | sed "s/ .*//")         \
    -DZIG_LIBC_STATIC_LIB_DIR=$(dirname $(cc -print-file-name=crtbegin.o)) \
    -DCMAKE_BUILD_TYPE=Release                                             \
    -DCMAKE_PREFIX_PATH=/deps/local                                        \
    -DCMAKE_INSTALL_PREFIX=/usr
RUN make install

FROM debian:stable-slim
COPY --from=builder /usr/bin/zig /usr/bin/zig
COPY --from=builder /usr/lib/zig /usr/lib/zig
WORKDIR /z

ENTRYPOINT ["zig"]
