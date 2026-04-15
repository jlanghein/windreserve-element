#!/bin/bash
# Download Element Web release

set -e

ELEMENT_VERSION="${1:-v1.12.15}"
ELEMENT_DIR="./element"

echo "Downloading Element Web ${ELEMENT_VERSION}..."

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download and extract
curl -sL "https://github.com/element-hq/element-web/releases/download/${ELEMENT_VERSION}/element-${ELEMENT_VERSION}.tar.gz" \
    -o "$TEMP_DIR/element.tar.gz"

# Extract to element directory
mkdir -p "$ELEMENT_DIR"
tar -xzf "$TEMP_DIR/element.tar.gz" -C "$TEMP_DIR"
cp -r "$TEMP_DIR/element-${ELEMENT_VERSION}"/* "$ELEMENT_DIR/"

# Keep our custom config.json
echo "Element Web ${ELEMENT_VERSION} downloaded to ${ELEMENT_DIR}"
echo "Remember to check/update config.json if needed"
