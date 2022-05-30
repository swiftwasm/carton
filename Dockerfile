FROM ghcr.io/swiftwasm/swift:5.6-focal

LABEL maintainer="SwiftWasm Maintainers <hello@swiftwasm.org>"
LABEL Description="Carton is a watcher, bundler, and test runner for your SwiftWasm apps"
LABEL org.opencontainers.image.source https://github.com/swiftwasm/carton

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && apt-get -q update && \
  apt-get -q install -y \
  build-essential \
  libncurses5 \
  libsqlite3-0 \
  libsqlite3-dev \
  libxkbcommon0 \
  curl unzip \
  && export WASMER_DIR=/usr/local && curl https://get.wasmer.io -sSfL | sh -s "2.2.1" && \
  rm -r /var/lib/apt/lists/*

ENV CARTON_ROOT=/root/.carton
ENV CARTON_DEFAULT_TOOLCHAIN=wasm-5.6.0-RELEASE

RUN mkdir -p $CARTON_ROOT/sdk && \
  mkdir -p $CARTON_ROOT/sdk/$CARTON_DEFAULT_TOOLCHAIN && \
  ln -s /usr $CARTON_ROOT/sdk/$CARTON_DEFAULT_TOOLCHAIN/usr

COPY . carton/

ENV NODE_VERSION=18.1.0 

RUN curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" && \
    tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner

RUN cd carton && \
  ./install_ubuntu_deps.sh && \
  swift build -c release --static-swift-stdlib && \
  mv .build/release/carton /usr/bin && \
  cd .. && \
  rm -rf carton /tmp/wasmer*

# Set the default command to run
CMD ["carton --help"]
