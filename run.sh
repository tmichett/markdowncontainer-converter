#!/bin/bash
# Run script that processes markdown files from config.yaml

set -e

# Default values
CONFIG_FILE="${CONFIG_FILE:-config.yaml}"
IMAGE_NAME="${IMAGE_NAME:-markdown-to-pdf}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

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

# Check if container image exists
if ! podman image exists "$FULL_IMAGE_NAME" 2>/dev/null; then
    echo "⚠️  Container image '$FULL_IMAGE_NAME' not found"
    echo "Building container image..."
    echo ""
    ./build.sh
    echo ""
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
        output_pdf="${file_path%.md}.pdf"
        output_pdf="${output_pdf%.MD}.pdf"
        
        echo "📄 Processing $file_path -> $output_pdf"
        
        # Run container to convert markdown to PDF
        if podman run --rm \
            -v "$(pwd):/workspace:Z" \
            "$FULL_IMAGE_NAME" \
            "/workspace/$file_path" \
            "/workspace/$output_pdf"; then
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
            output_pdf="${file_path%.md}.pdf"
            output_pdf="${output_pdf%.MD}.pdf"
            
            echo "📄 Processing $file_path -> $output_pdf"
            
            # Run container to convert markdown to PDF
            if podman run --rm \
                -v "$(pwd):/workspace:Z" \
                "$FULL_IMAGE_NAME" \
                "/workspace/$file_path" \
                "/workspace/$output_pdf"; then
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

