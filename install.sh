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
    echo "API key length: ${#API_KEY}"
    echo "Running login command..."
    
    # Ensure binary is executable and in PATH
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    
    # Run login command with error handling
    if "$INSTALL_DIR/$BINARY_NAME" login --api-key "$API_KEY"; then
        echo "API key configured successfully"
        echo "Verifying config file..."
        if [ -f "$HOME/.stakpak/config.toml" ]; then
            echo "Config file created successfully"
        else
            echo "Warning: Config file not found at $HOME/.stakpak/config.toml"
        fi
    else
        echo "Error: Login command failed"
        echo "Attempting to create config directory..."
        mkdir -p "$HOME/.stakpak"
        
        # Try login again
        if "$INSTALL_DIR/$BINARY_NAME" login --api-key "$API_KEY"; then
            echo "API key configured successfully on second attempt"
        else
            echo "Error: Login failed twice. Check API key validity."
            exit 1
        fi
    fi
elif [ -n "$API_KEY" ]; then
    echo "Install-only mode: API key will be configured later"
fi

# Verify installation
echo "Verifying installation..."
if [ -n "$API_KEY" ]; then
    # API key is available, try version check
    echo "Testing CLI with API key..."
    "$INSTALL_DIR/$BINARY_NAME" version || echo "Version check failed - CLI installed but may need different authentication"
else
    # No API key provided, skip version check
    echo "No API key provided - skipping version check"
    echo "Binary installed successfully but version check requires API key"
fi