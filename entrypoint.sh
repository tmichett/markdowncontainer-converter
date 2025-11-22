#!/bin/bash
# Entrypoint script for the markdown-to-pdf container
# This script processes a single markdown file and converts it to PDF

set -e

if [ $# -lt 2 ]; then
    echo "Usage: entrypoint.sh <input_markdown_file> <output_pdf_file>"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Error: Input file '$INPUT_FILE' does not exist"
    exit 1
fi

# Get directory of output file
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [ "$OUTPUT_DIR" != "." ] && [ "$OUTPUT_DIR" != "" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Get basename for temporary PDF (md-to-pdf creates PDF in same directory as input)
INPUT_DIR=$(dirname "$INPUT_FILE")
INPUT_BASENAME=$(basename "$INPUT_FILE" .md)
TEMP_PDF="$INPUT_DIR/${INPUT_BASENAME}.pdf"

echo "📄 Processing $INPUT_FILE..."

# Check for Mermaid blocks
mermaid_count=$(grep -c '```mermaid' "$INPUT_FILE" 2>/dev/null || echo "0")
echo "Found $mermaid_count Mermaid diagram(s)"

# Convert markdown to PDF
# Use config from /app/config if available, otherwise try /workspace
CONFIG_FILE="/app/config/.md-to-pdf.json"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="/workspace/.md-to-pdf.json"
fi

echo "Converting to PDF (using config: $CONFIG_FILE)..."
md-to-pdf "$INPUT_FILE" \
    --config-file "$CONFIG_FILE" \
    || {
    echo "❌ Failed to convert $INPUT_FILE to PDF"
    exit 1
}

# Check if PDF was created
if [ ! -f "$TEMP_PDF" ]; then
    echo "❌ Error: PDF was not created at $TEMP_PDF"
    exit 1
fi

# Move to output location (only if different)
if [ "$TEMP_PDF" != "$OUTPUT_FILE" ]; then
    mv "$TEMP_PDF" "$OUTPUT_FILE"
else
    echo "PDF already at target location: $OUTPUT_FILE"
fi

file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
echo "✅ Successfully created $OUTPUT_FILE ($file_size)"

# Add PDF bookmarks from markdown headings
# Use script from /app if available, otherwise try /workspace
BOOKMARK_SCRIPT="/app/add_pdf_bookmarks.py"
if [ ! -f "$BOOKMARK_SCRIPT" ]; then
    BOOKMARK_SCRIPT="/workspace/add_pdf_bookmarks.py"
fi

echo "Adding PDF bookmarks for navigation..."
python3 "$BOOKMARK_SCRIPT" "$INPUT_FILE" "$OUTPUT_FILE" || {
    echo "⚠️  Warning: Failed to add bookmarks, but PDF was created"
}

file_size_after=$(du -h "$OUTPUT_FILE" | cut -f1)
echo "📑 PDF with bookmarks: $OUTPUT_FILE ($file_size_after)"
echo "✅ Conversion complete!"

