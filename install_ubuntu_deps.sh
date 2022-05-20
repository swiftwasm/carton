#/bin/bash

set -ex

if [ -x "$(command -v sudo)" ]; then
  sudoCommand=(sudo)
else
  sudoCommand=()
fi

$sudoCommand apt-get update -y
$sudoCommand apt-get install -y zlib1g-dev libsqlite3-dev libcurl4-openssl-dev

if [ -x "$(command -v sudo)" ]; then
  aptGet=(sudo apt-get)
else
  aptGet=apt-get
fi

if ! [ -x "$(command -v swift)" ]; then
  curl -s https://archive.swiftlang.xyz/install.sh | $sudoCommand bash
fi

BINARYEN_VERSION=105

curl -L -v -o binaryen.tar.gz https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-x86_64-linux.tar.gz
tar xzvf binaryen.tar.gz
cp binaryen-version_${BINARYEN_VERSION}/bin/* /usr/local/bin

WABT_VERSION=1.0.27

curl -L -v -o wabt.tar.gz https://github.com/WebAssembly/wabt/releases/download/${WABT_VERSION}/wabt-${WABT_VERSION}-ubuntu.tar.gz
tar xzvf wabt.tar.gz
cp wabt-${WABT_VERSION}/bin/* /usr/local/bin
