#!/bin/bash

set -e

echo
echo -e "$PREFIX Building daemon..."

sed -i -e "0,/version.*$/ s/version.*$/version\ =\ \"${REPO_VERSION}\"/" $BUILD_DIR/daemon/Cargo.toml

cargo build --verbose --color=always --manifest-path=$BUILD_DIR/daemon/Cargo.toml $CARGO_ARGS

echo 
echo -e "$PREFIX Building daemon deb..."

mkdir -p /build/daemon/packaging/xsd/
cp -r $BUILD_DIR/sdk/src/data_validation/xml/xsd/product /build/daemon/packaging/xsd/product

# Copy the debug version to release so deb package creation can proceed
mkdir -p $CARGO_TARGET_DIR/release
cp $CARGO_TARGET_DIR/debug/gridd $CARGO_TARGET_DIR/release/gridd

cargo deb --fast --no-build --deb-version $REPO_VERSION --manifest-path $BUILD_DIR/daemon/Cargo.toml

echo 
echo -e "$PREFIX Building cli..."

sed -i -e "0,/version.*$/ s/version.*$/version\ =\ \"${REPO_VERSION}\"/" $BUILD_DIR/cli/Cargo.toml

cargo build --verbose --color=always --manifest-path=$BUILD_DIR/cli/Cargo.toml $CARGO_ARGS

echo 
echo -e "$PREFIX Building cli deb..."

# Copy the debug version to release so deb package creation can proceed.
# Attempting not to modify any of the scripts in grid source,
# but we also ideally want to build the debug version.
# This is a compromise.
cp $CARGO_TARGET_DIR/debug/grid $CARGO_TARGET_DIR/release/grid

cargo deb --fast --no-build --deb-version $REPO_VERSION --manifest-path $BUILD_DIR/cli/Cargo.toml
