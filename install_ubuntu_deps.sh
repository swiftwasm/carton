#/bin/bash

set -ex

if [ -x "$(command -v sudo)" ]; then
  sudo apt-get install zlib1g-dev libsqlite3-dev
else
  apt-get install zlib1g-dev libsqlite3-dev
fi

BINARYEN_VERSION=105

curl -L -v -o binaryen.tar.gz https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-x86_64-linux.tar.gz
tar xzvf binaryen.tar.gz
cp binaryen-version_${BINARYEN_VERSION}/bin/* /usr/local/bin
