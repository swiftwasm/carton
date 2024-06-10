#!/bin/bash
set -ue
cd "$(dirname "$0")/../.."

mkdir -p install
cd install

set -x
pwd
curl -fLO https://download.swift.org/${SWIFT_DIR}/${SWIFT_VERSION}/${SWIFT_VERSION}-osx.pkg
installer -target CurrentUserHomeDirectory -pkg ${SWIFT_VERSION}-osx.pkg

toolchain=~/Library/Developer/Toolchains/${SWIFT_VERSION}.xctoolchain

set +x
swift_id=$(plutil -extract CFBundleIdentifier raw ${toolchain}/Info.plist)

set -x
echo "TOOLCHAINS=${swift_id}" >> $GITHUB_ENV

# https://github.com/apple/swift/issues/73327#issuecomment-2120481479
find ${toolchain}/usr/bin -type f | xargs -n 1 -I {} \
  sudo codesign --force --preserve-metadata=identifier,entitlements --sign - {}

echo "DYLD_LIBRARY_PATH=${toolchain}/usr/lib/swift/macosx" >> $GITHUB_ENV
