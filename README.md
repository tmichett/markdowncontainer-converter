# Markdown to PDF Container Converter

A containerized solution for converting Markdown files to PDF with support for Mermaid diagrams, GitHub-style formatting, and PDF bookmarks.

## Features

- ✅ Converts Markdown files to PDF
- ✅ Supports Mermaid diagrams
- ✅ GitHub-style markdown rendering
- ✅ Automatic PDF bookmarks from markdown headings
- ✅ Custom CSS for better PDF pagination
- ✅ Containerized for easy deployment

## Prerequisites

- [Podman](https://podman.io/) (or Docker) installed
- Optional: `yq` for better YAML parsing (recommended)

## Quick Start

### 1. Build the Container

```bash
./build.sh
```

This will build a container image named `markdown-to-pdf:latest` using Podman.

### 2. Create Configuration File

Copy the example configuration file:

```bash
cp config.yaml.example config.yaml
```

Edit `config.yaml` to list your markdown files:

```yaml
files:
  - path: path/to/your/file.md
  - path: another/file.md
```

### 3. Run the Converter

```bash
./run.sh
```

This will:
- Read the `config.yaml` file
- Process each markdown file listed
- Generate PDF files in the same location with `.pdf` extension
- Add bookmarks based on markdown headings

## Configuration

### config.yaml Format

The configuration file uses YAML format:

```yaml
files:
  - path: relative/path/to/file.md
  - path: another/file.md
```

Paths are relative to the directory where you run `run.sh`.

### Environment Variables

You can customize the container image name and tag:

```bash
IMAGE_NAME=my-pdf-converter IMAGE_TAG=v1.0 ./build.sh
IMAGE_NAME=my-pdf-converter IMAGE_TAG=v1.0 ./run.sh
```

You can also specify a different config file:

```bash
CONFIG_FILE=my-config.yaml ./run.sh
```

## Manual Usage

You can also run the container manually:

```bash
podman run --rm \
  -v $(pwd):/workspace:Z \
  markdown-to-pdf:latest \
  /workspace/input.md \
  /workspace/output.pdf
```

## How It Works

1. **Container Build**: The `Containerfile` sets up an Ubuntu-based container with:
   - Node.js and npm
   - Chromium browser
   - Python 3 and pip
   - `md-to-pdf` npm package
   - `pypdf` Python package

2. **PDF Generation**: The container uses `md-to-pdf` to convert markdown to PDF with:
   - GitHub markdown CSS styling
   - Custom CSS for better pagination
   - Mermaid.js for diagram rendering
   - Custom JavaScript for Mermaid initialization

3. **Bookmarks**: A Python script extracts headings from the markdown file and adds them as PDF bookmarks for navigation.

## Files

- `Containerfile` - Container definition
- `build.sh` - Script to build the container with Podman
- `run.sh` - Script to process markdown files from config.yaml
- `entrypoint.sh` - Container entrypoint script
- `config.yaml.example` - Example configuration file
- `pdf-styles.css` - Custom CSS for PDF styling
- `.md-to-pdf.json` - Configuration for md-to-pdf
- `mermaid-init.js` - JavaScript for Mermaid diagram initialization
- `add_pdf_bookmarks.py` - Python script to add PDF bookmarks

## Troubleshooting

### Container image not found

If you get an error that the container image doesn't exist, run:

```bash
./build.sh
```

### YAML parsing issues

If you encounter YAML parsing errors, install `yq`:

```bash
# macOS
brew install yq

# Linux
# See https://github.com/mikefarah/yq#install
```

The script will fall back to basic parsing if `yq` is not available.

### Permission errors

Make sure the scripts are executable:

```bash
chmod +x build.sh run.sh entrypoint.sh
```

### File not found errors

Ensure that:
- The paths in `config.yaml` are relative to where you run `run.sh`
- The markdown files actually exist at those paths
- You have read permissions for the markdown files

## Based On

This container is based on the GitHub Actions workflow in `build-pdfs.yml`, which was originally designed to run in GitHub Actions. This containerized version allows you to run the same PDF generation process locally or in any container environment.
