#/bin/bash

set -ex

curl -L -v -o wabt.tar.gz https://github.com/WebAssembly/wabt/releases/download/1.0.19/wabt-1.0.19-ubuntu.tar.gz
tar xzvf wabt.tar.gz
sudo cp wabt-1.0.19/bin/* /usr/local/bin

curl -L -v -o binaryen.tar.gz https://github.com/WebAssembly/binaryen/releases/download/version_97/binaryen-version_97-x86_64-linux.tar.gz
tar xzvf binaryen.tar.gz
sudo cp binaryen-version_97/bin/* /usr/local/bin
