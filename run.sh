#!/bin/bash
# Run script that processes markdown files from config.yaml

set -e

# Default values
CONFIG_FILE="${CONFIG_FILE:-config.yaml}"
IMAGE_NAME="${IMAGE_NAME:-md2pdf}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Detect GitHub username from git remote or use environment variable
if [ -z "$GITHUB_USER" ]; then
    GITHUB_USER=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[\/:]([^\/]+)\/.*/\1/' || echo "")
fi

# Determine which image to use
# Priority: 1) GHCR if GITHUB_USER set and USE_GHCR not false, 2) Local image
# Allow override to force local-only mode
if [ "${USE_GHCR:-true}" != "false" ] && [ -n "$GITHUB_USER" ]; then
    FULL_IMAGE_NAME="ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
    USE_GHCR=true
else
    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    USE_GHCR=false
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Config file '$CONFIG_FILE' not found"
    echo ""
    echo "Please create a config.yaml file with the following format:"
    echo "  files:"
    echo "    - path: path/to/file.md"
    echo "    - path: another/file.md"
    echo ""
    echo "Or copy the example:"
    echo "  cp config.yaml.example config.yaml"
    exit 1
fi

# Check if container image exists, pull from GHCR if needed
if ! podman image exists "$FULL_IMAGE_NAME" 2>/dev/null; then
    if [ "$USE_GHCR" = true ]; then
        echo "⚠️  Container image '$FULL_IMAGE_NAME' not found locally"
        echo "Attempting to pull from GitHub Container Registry..."
        echo ""
        
        # Try to pull from GHCR
        if podman pull "$FULL_IMAGE_NAME" 2>/dev/null; then
            echo "✅ Successfully pulled image from GitHub Container Registry"
            echo ""
        else
            echo "❌ Failed to pull image from GitHub Container Registry"
            echo ""
            echo "The image may not exist yet. You can:"
            echo "  1. Build and push the image:"
            echo "     ./build.sh && ./push.sh"
            echo ""
            echo "  2. Build locally only:"
            echo "     USE_GHCR=false ./run.sh"
            echo ""
            echo "  3. Use a different image:"
            echo "     IMAGE_NAME=your-image GITHUB_USER=your-user ./run.sh"
            exit 1
        fi
    else
        echo "⚠️  Container image '$FULL_IMAGE_NAME' not found"
        echo "Building container image locally..."
        echo ""
        ./build.sh
        echo ""
    fi
fi

# Check if yq is available (for parsing YAML)
if ! command -v yq &> /dev/null; then
    echo "⚠️  Warning: 'yq' not found. Attempting to parse YAML with basic tools..."
    USE_YQ=false
else
    USE_YQ=true
fi

echo "🚀 Starting PDF generation from $CONFIG_FILE"
echo ""

# Track build status
failed_builds=()
successful_builds=()

# Function to determine mount point and adjust paths
determine_mount() {
    local file_path="$1"
    
    # Check if path is absolute
    if [[ "$file_path" = /* ]]; then
        # Absolute path - find a suitable mount point
        # Try to find common parent (like /Users, /home, etc.)
        if [[ "$file_path" = /Users/* ]]; then
            echo "/Users"
        elif [[ "$file_path" = /home/* ]]; then
            echo "/home"
        else
            # Use root as fallback (less ideal but works)
            echo "/"
        fi
    else
        # Relative path - use current directory
        echo "$(pwd)"
    fi
}

# Function to convert absolute path to container path
to_container_path() {
    local file_path="$1"
    local mount_point="$2"
    
    if [[ "$file_path" = /* ]]; then
        # Absolute path - use as-is (mounted at root)
        echo "$file_path"
    else
        # Relative path - prepend /workspace
        echo "/workspace/$file_path"
    fi
}

# Parse config file and process each markdown file
if [ "$USE_YQ" = true ]; then
    # Use yq to parse YAML
    file_count=$(yq eval '.files | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    
    if [ "$file_count" -eq 0 ]; then
        echo "❌ Error: No files found in config.yaml or invalid format"
        exit 1
    fi
    
    for i in $(seq 0 $((file_count - 1))); do
        file_path=$(yq eval ".files[$i].path" "$CONFIG_FILE")
        
        if [ -z "$file_path" ] || [ "$file_path" = "null" ]; then
            continue
        fi
        
        # Check if file exists
        if [ ! -f "$file_path" ]; then
            echo "⚠️  Warning: $file_path not found, skipping..."
            failed_builds+=("$file_path (not found)")
            continue
        fi
        
        # Generate output PDF path (same location, .pdf extension)
        # Remove any existing .pdf extension first, then remove .md/.MD, then add .pdf
        output_pdf="${file_path%.pdf}"  # Remove .pdf if present
        output_pdf="${output_pdf%.md}"   # Remove .md
        output_pdf="${output_pdf%.MD}"  # Remove .MD
        output_pdf="${output_pdf}.pdf"   # Add .pdf
        
        # Determine mount point
        if [[ "$file_path" = /* ]]; then
            # Absolute path - mount parent directory
            if [[ "$file_path" = /Users/* ]]; then
                MOUNT_POINT="/Users"
                CONTAINER_INPUT="$file_path"
                CONTAINER_OUTPUT="$output_pdf"
            elif [[ "$file_path" = /home/* ]]; then
                MOUNT_POINT="/home"
                CONTAINER_INPUT="$file_path"
                CONTAINER_OUTPUT="$output_pdf"
            else
                # Fallback: mount root (requires root access, not ideal)
                MOUNT_POINT="/"
                CONTAINER_INPUT="$file_path"
                CONTAINER_OUTPUT="$output_pdf"
            fi
        else
            # Relative path - mount current directory
            MOUNT_POINT="$(pwd)"
            CONTAINER_INPUT="/workspace/$file_path"
            CONTAINER_OUTPUT="/workspace/$output_pdf"
        fi
        
        echo "📄 Processing $file_path -> $output_pdf"
        
        # Run container to convert markdown to PDF
        if podman run --rm \
            -v "$MOUNT_POINT:$MOUNT_POINT:Z" \
            "$FULL_IMAGE_NAME" \
            "$CONTAINER_INPUT" \
            "$CONTAINER_OUTPUT"; then
            echo "✅ Successfully created $output_pdf"
            successful_builds+=("$output_pdf")
        else
            echo "❌ Failed to create PDF for $file_path"
            failed_builds+=("$file_path")
        fi
        echo ""
    done
else
    # Basic YAML parsing without yq (assumes simple format)
    # This is a fallback that looks for lines like "  - path: file.md"
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Look for path: entries
        if [[ "$line" =~ path:[[:space:]]+(.+) ]]; then
            file_path="${BASH_REMATCH[1]}"
            file_path="${file_path// /}"  # Remove spaces
            
            # Check if file exists
            if [ ! -f "$file_path" ]; then
                echo "⚠️  Warning: $file_path not found, skipping..."
                failed_builds+=("$file_path (not found)")
                continue
            fi
            
            # Generate output PDF path (same location, .pdf extension)
            # Remove any existing .pdf extension first, then remove .md/.MD, then add .pdf
            output_pdf="${file_path%.pdf}"  # Remove .pdf if present
            output_pdf="${output_pdf%.md}"   # Remove .md
            output_pdf="${output_pdf%.MD}"  # Remove .MD
            output_pdf="${output_pdf}.pdf"   # Add .pdf
            
            # Determine mount point
            if [[ "$file_path" = /* ]]; then
                # Absolute path - mount parent directory
                if [[ "$file_path" = /Users/* ]]; then
                    MOUNT_POINT="/Users"
                    CONTAINER_INPUT="$file_path"
                    CONTAINER_OUTPUT="$output_pdf"
                elif [[ "$file_path" = /home/* ]]; then
                    MOUNT_POINT="/home"
                    CONTAINER_INPUT="$file_path"
                    CONTAINER_OUTPUT="$output_pdf"
                else
                    # Fallback: mount root (requires root access, not ideal)
                    MOUNT_POINT="/"
                    CONTAINER_INPUT="$file_path"
                    CONTAINER_OUTPUT="$output_pdf"
                fi
            else
                # Relative path - mount current directory
                MOUNT_POINT="$(pwd)"
                CONTAINER_INPUT="/workspace/$file_path"
                CONTAINER_OUTPUT="/workspace/$output_pdf"
            fi
            
            echo "📄 Processing $file_path -> $output_pdf"
            
            # Run container to convert markdown to PDF
            if podman run --rm \
                -v "$MOUNT_POINT:$MOUNT_POINT:Z" \
                "$FULL_IMAGE_NAME" \
                "$CONTAINER_INPUT" \
                "$CONTAINER_OUTPUT"; then
                echo "✅ Successfully created $output_pdf"
                successful_builds+=("$output_pdf")
            else
                echo "❌ Failed to create PDF for $file_path"
                failed_builds+=("$file_path")
            fi
            echo ""
        fi
    done < "$CONFIG_FILE"
fi

# Summary
echo ""
echo "=== Build Summary ==="
echo ""
echo "Successful: ${#successful_builds[@]}"
for pdf in "${successful_builds[@]}"; do
    echo "  ✅ $pdf"
done
echo ""
echo "Failed: ${#failed_builds[@]}"
for file in "${failed_builds[@]}"; do
    echo "  ❌ $file"
done
echo ""

# Exit with error if no PDFs were generated
if [ ${#successful_builds[@]} -eq 0 ]; then
    echo "❌ ERROR: No PDFs were successfully generated!"
    exit 1
fi

# Warn if some failed
if [ ${#failed_builds[@]} -gt 0 ]; then
    echo "⚠️  WARNING: Some PDFs failed to build, but continuing with successful ones"
    exit 1
else
    echo "🎉 All PDFs built successfully!"
    exit 0
fi

