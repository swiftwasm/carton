FROM ubuntu AS build

ADD https://github.com/swiftwasm/swift/releases/download/\
swift-wasm-5.3-SNAPSHOT-2020-10-21-a/\
swift-wasm-5.3-SNAPSHOT-2020-10-21-a-ubuntu20.04_x86_64.tar.gz \
  /swift-wasm-5.3-SNAPSHOT.tar.gz
RUN mkdir -p /home/builder/.carton/sdk && cd /home/builder/.carton/sdk && \
  tar xzf /swift-wasm-5.3-SNAPSHOT.tar.gz && \
  mv swift-wasm-5.3-SNAPSHOT-2020-10-21-a wasm-5.3-SNAPSHOT-2020-10-21-a && \
  cd wasm-5.3-SNAPSHOT-2020-10-21-a/usr/bin && rm *-test swift-refactor sourcekit-lsp

# Container image that runs your code
FROM ubuntu:20.04

LABEL maintainer="SwiftWasm Maintainers <hello@swiftwasm.org>"
LABEL Description="Carton is a watcher, bundler, and test runner for your SwiftWasm apps"

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && apt-get -q update && \
    apt-get -q install -y \
    git \
    curl \
    sudo \
    libatomic1 \
    libcurl4 \
    libxml2 \
    libedit2 \
    libsqlite3-0 \
    libsqlite3-dev \
    libc6-dev \
    binutils \
    libgcc-10-dev \
    libstdc++-10-dev \
    libz3-4 \
    zlib1g-dev \
    unzip \
    libpython2.7 \
    tzdata \
    pkg-config \
  && export WASMER_DIR=/usr/local && curl https://get.wasmer.io -sSfL | sh && \
  rm -r /var/lib/apt/lists/*

COPY --from=build /home/builder/.carton /root/.carton

RUN ln -s /root/.carton/sdk/wasm-5.3-SNAPSHOT-2020-10-21-a/usr/bin/swift /usr/bin/swift

COPY . carton/

RUN cd carton && \
  ./install_ubuntu_deps.sh && \
  swift build -c release && \
  cd TestApp && ../.build/release/carton test && cd .. && \
  mv .build/release/carton /usr/bin && \
  cd .. && \
  rm -rf carton /tmp/wasmer*

# Set the default command to run
CMD ["carton --help"]
