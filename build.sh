#!/bin/bash
# Build script for markdown-to-pdf container using podman

set -e

# Container image name and tag
IMAGE_NAME="${IMAGE_NAME:-markdown-to-pdf}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo "🔨 Building container image: $FULL_IMAGE_NAME"
echo ""

# Build the container
podman build -f Containerfile -t "$FULL_IMAGE_NAME" .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Container image built successfully: $FULL_IMAGE_NAME"
    echo ""
    echo "To run the container, use:"
    echo "  ./run.sh"
    echo ""
    echo "Or manually:"
    echo "  podman run --rm -v \$(pwd):/workspace:Z $FULL_IMAGE_NAME <input.md> <output.pdf>"
else
    echo ""
    echo "❌ Failed to build container image"
    exit 1
fi

