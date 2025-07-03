#!/bin/bash

set -e

# Default values
VERSION="${INPUT_VERSION:-latest}"
API_KEY="${INPUT_API_KEY:-}"
INSTALL_ONLY="${INPUT_INSTALL_ONLY:-false}"

# Platform detection
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Normalize architecture names
case $ARCH in
    x86_64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Normalize OS names
case $OS in
    linux)
        OS="linux"
        BINARY_NAME="stakpak"
        ;;
    darwin)
        OS="darwin"
        BINARY_NAME="stakpak"
        ;;
    mingw*|msys*|cygwin*)
        OS="windows"
        BINARY_NAME="stakpak.exe"
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

# Set up installation directory
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# Determine download URL
REPO="stakpak/agent"
if [ "$VERSION" = "latest" ]; then
    echo "Fetching latest release information..."
    RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
else
    echo "Fetching release information for version $VERSION..."
    RELEASE_URL="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
fi

# Get release information
RELEASE_INFO=$(curl -s "$RELEASE_URL")
if [ $? -ne 0 ]; then
    echo "Failed to fetch release information"
    exit 1
fi

# Extract version and download URL
ACTUAL_VERSION=$(echo "$RELEASE_INFO" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
if [ -z "$ACTUAL_VERSION" ]; then
    echo "Failed to extract version from release information"
    exit 1
fi

# Construct asset name based on platform
if [ "$OS" = "darwin" ]; then
    if [ "$ARCH" = "aarch64" ]; then
        ASSET_NAME="stakpak-darwin-aarch64.tar.gz"
    else
        ASSET_NAME="stakpak-darwin-x86_64.tar.gz"
    fi
elif [ "$OS" = "linux" ]; then
    ASSET_NAME="stakpak-linux-x86_64.tar.gz"
elif [ "$OS" = "windows" ]; then
    ASSET_NAME="stakpak-windows-x86_64.zip"
fi

# Find download URL for the asset
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o '"browser_download_url": "[^"]*'$ASSET_NAME'"' | cut -d'"' -f4)
if [ -z "$DOWNLOAD_URL" ]; then
    echo "Failed to find download URL for asset: $ASSET_NAME"
    echo "Available assets:"
    echo "$RELEASE_INFO" | grep -o '"name": "[^"]*\.tar\.gz"' | cut -d'"' -f4
    echo "$RELEASE_INFO" | grep -o '"name": "[^"]*\.zip"' | cut -d'"' -f4
    exit 1
fi

echo "Downloading Stakpak $ACTUAL_VERSION..."
echo "Asset: $ASSET_NAME"
echo "URL: $DOWNLOAD_URL"

# Download the asset
TEMP_DIR=$(mktemp -d)
DOWNLOAD_FILE="$TEMP_DIR/$ASSET_NAME"

curl -L -o "$DOWNLOAD_FILE" "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "Failed to download Stakpak"
    exit 1
fi

# Extract the binary
echo "Extracting Stakpak..."
cd "$TEMP_DIR"

if [[ "$ASSET_NAME" == *.tar.gz ]]; then
    tar -xzf "$DOWNLOAD_FILE"
elif [[ "$ASSET_NAME" == *.zip ]]; then
    unzip -q "$DOWNLOAD_FILE"
fi

# Find the binary (it might be in a subdirectory)
BINARY_PATH=$(find . -name "$BINARY_NAME" -type f | head -1)
if [ -z "$BINARY_PATH" ]; then
    echo "Failed to find binary $BINARY_NAME in extracted files"
    ls -la
    exit 1
fi

# Install the binary
echo "Installing Stakpak to $INSTALL_DIR..."
cp "$BINARY_PATH" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Clean up
rm -rf "$TEMP_DIR"

# Set outputs
echo "version=$ACTUAL_VERSION" >> $GITHUB_OUTPUT
echo "path=$INSTALL_DIR/$BINARY_NAME" >> $GITHUB_OUTPUT

# Cache hit is handled in the action.yml
if [ -n "$CACHE_HIT" ]; then
    echo "cache_hit=$CACHE_HIT" >> $GITHUB_OUTPUT
fi

echo "Stakpak CLI $ACTUAL_VERSION installed successfully!"
echo "Binary location: $INSTALL_DIR/$BINARY_NAME"

# Configure API key if provided and not in install-only mode
if [ -n "$API_KEY" ] && [ "$INSTALL_ONLY" != "true" ]; then
    echo "Configuring API key..."
    
    # Create config directory and set environment variable
    mkdir -p "$HOME/.stakpak"
    export STAKPAK_API_KEY="$API_KEY"
    
    # Run login command
    "$INSTALL_DIR/$BINARY_NAME" login
    echo "API key configured successfully"
fi

# Verify installation
echo "Verifying installation..."
"$INSTALL_DIR/$BINARY_NAME" version || echo "Version check failed - this may be expected without API key"