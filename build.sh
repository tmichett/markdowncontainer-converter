#!/bin/bash
# Build script for markdown-to-pdf container using podman

set -e

# Detect GitHub username from git remote or use environment variable
if [ -z "$GITHUB_USER" ]; then
    GITHUB_USER=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[\/:]([^\/]+)\/.*/\1/' || echo "")
    if [ -z "$GITHUB_USER" ]; then
        echo "⚠️  Warning: Could not detect GitHub username"
        echo "Set GITHUB_USER environment variable or ensure git remote is configured"
        echo ""
        read -p "Enter GitHub username (or press Enter to use 'md2pdf' as image name only): " GITHUB_USER
    fi
fi

# Container image name and tag
IMAGE_NAME="${IMAGE_NAME:-md2pdf}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Build local image name
LOCAL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Build GHCR image name if GitHub user is set
if [ -n "$GITHUB_USER" ]; then
    GHCR_IMAGE_NAME="ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
    echo "🔨 Building container image: $LOCAL_IMAGE_NAME"
    echo "   Will also tag as: $GHCR_IMAGE_NAME"
else
    echo "🔨 Building container image: $LOCAL_IMAGE_NAME"
fi
echo ""

# Build the container
podman build -f Containerfile -t "$LOCAL_IMAGE_NAME" .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Container image built successfully: $LOCAL_IMAGE_NAME"
    
    # Tag for GHCR if GitHub user is set
    if [ -n "$GITHUB_USER" ]; then
        podman tag "$LOCAL_IMAGE_NAME" "$GHCR_IMAGE_NAME"
        echo "✅ Tagged as: $GHCR_IMAGE_NAME"
        echo ""
        echo "To push to GitHub Container Registry, use:"
        echo "  ./push.sh"
    fi
    
    echo ""
    echo "To run the container, use:"
    echo "  ./run.sh"
    echo ""
    echo "Or manually:"
    echo "  podman run --rm -v \$(pwd):/workspace:Z $LOCAL_IMAGE_NAME <input.md> <output.pdf>"
else
    echo ""
    echo "❌ Failed to build container image"
    exit 1
fi

