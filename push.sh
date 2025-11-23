#!/bin/bash
# Push script for md2pdf container to GitHub Container Registry

set -e

# Detect GitHub username from git remote or use environment variable
if [ -z "$GITHUB_USER" ]; then
    GITHUB_USER=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[\/:]([^\/]+)\/.*/\1/' || echo "")
    if [ -z "$GITHUB_USER" ]; then
        echo "❌ Error: Could not detect GitHub username"
        echo ""
        echo "Please set GITHUB_USER environment variable:"
        echo "  export GITHUB_USER=your-username"
        echo ""
        echo "Or ensure git remote is configured:"
        echo "  git remote get-url origin"
        exit 1
    fi
fi

# Container image name and tag
IMAGE_NAME="${IMAGE_NAME:-md2pdf}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
GHCR_IMAGE_NAME="ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "📤 Pushing container image to GitHub Container Registry"
echo "   Image: $GHCR_IMAGE_NAME"
echo ""

# Check if image exists locally
if ! podman image exists "$GHCR_IMAGE_NAME" 2>/dev/null; then
    # Try local image name
    LOCAL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    if podman image exists "$LOCAL_IMAGE_NAME" 2>/dev/null; then
        echo "⚠️  Image not tagged for GHCR, tagging now..."
        podman tag "$LOCAL_IMAGE_NAME" "$GHCR_IMAGE_NAME"
    else
        echo "❌ Error: Container image '$GHCR_IMAGE_NAME' not found locally"
        echo ""
        echo "Please build the image first:"
        echo "  ./build.sh"
        exit 1
    fi
fi

# Check if already logged in to GHCR
if ! podman login --get-login ghcr.io &>/dev/null; then
    echo "🔐 Authentication required for GitHub Container Registry"
    echo ""
    echo "You can authenticate using:"
    echo "  1. GitHub Personal Access Token (recommended)"
    echo "  2. Username and password"
    echo ""
    
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Using GITHUB_TOKEN environment variable..."
        echo "$GITHUB_TOKEN" | podman login ghcr.io -u "$GITHUB_USER" --password-stdin
    else
        echo "Please login to GitHub Container Registry:"
        podman login ghcr.io
    fi
    
    if [ $? -ne 0 ]; then
        echo ""
        echo "❌ Failed to authenticate with GitHub Container Registry"
        echo ""
        echo "To create a Personal Access Token:"
        echo "  1. Go to https://github.com/settings/tokens"
        echo "  2. Generate new token (classic) with 'write:packages' permission"
        echo "  3. Use token as password when logging in"
        echo ""
        echo "Or set GITHUB_TOKEN environment variable:"
        echo "  export GITHUB_TOKEN=your-token"
        exit 1
    fi
else
    echo "✅ Already authenticated with GitHub Container Registry"
fi

echo ""
echo "📤 Pushing $GHCR_IMAGE_NAME..."
podman push "$GHCR_IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully pushed to GitHub Container Registry!"
    echo ""
    echo "Image is now available at:"
    echo "  https://github.com/${GITHUB_USER}?tab=packages"
    echo ""
    echo "To use this image, run:"
    echo "  ./run.sh"
    echo ""
    echo "Or pull manually:"
    echo "  podman pull $GHCR_IMAGE_NAME"
else
    echo ""
    echo "❌ Failed to push container image"
    exit 1
fi


