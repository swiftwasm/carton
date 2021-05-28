#/bin/bash

set -ex

sudo apt-get install zlib1g-dev
curl -L -v -o binaryen.tar.gz https://github.com/WebAssembly/binaryen/releases/download/version_97/binaryen-version_97-x86_64-linux.tar.gz
tar xzvf binaryen.tar.gz
cp binaryen-version_97/bin/* /usr/local/bin
