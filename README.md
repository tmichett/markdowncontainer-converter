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

This will build a container image named `md2pdf:latest` using Podman. If your git remote is configured with GitHub, it will also tag the image for GitHub Container Registry (ghcr.io).

### 2. (Optional) Push to GitHub Container Registry

If you want to publish the container image to GitHub Container Registry:

```bash
./push.sh
```

This will:
- Authenticate with GitHub Container Registry (if needed)
- Push the image to `ghcr.io/YOUR_USERNAME/md2pdf:latest`
- Make it available for others to use

**Note**: You'll need a GitHub Personal Access Token with `write:packages` permission. Set it as:
```bash
export GITHUB_TOKEN=your-token
```

Or login interactively when prompted.

### 3. Create Configuration File

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

### 4. Run the Converter

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
  - path: /absolute/path/to/file.md
```

Paths can be:
- **Relative** - Relative to the directory where you run `run.sh`
- **Absolute** - Full system paths (e.g., `/Users/username/project/file.md`)

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

**GitHub Container Registry**:
- The scripts automatically detect your GitHub username from git remote
- Or set `GITHUB_USER` environment variable
- To use local-only mode (skip GHCR): `USE_GHCR=false ./run.sh`
- To use a different GitHub user: `GITHUB_USER=other-user ./run.sh`

## Manual Usage

You can also run the container manually:

**Using local image:**
```bash
podman run --rm \
  -v $(pwd):/workspace:Z \
  md2pdf:latest \
  /workspace/input.md \
  /workspace/output.pdf
```

**Using GitHub Container Registry image:**
```bash
podman run --rm \
  -v $(pwd):/workspace:Z \
  ghcr.io/YOUR_USERNAME/md2pdf:latest \
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
- `push.sh` - Script to push container to GitHub Container Registry
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

### GitHub Container Registry issues

**Problem**: Cannot pull image from GHCR
- **Solution**: 
  - Ensure the image has been pushed: `./push.sh`
  - Check that `GITHUB_USER` is set correctly
  - Verify the image exists at: `https://github.com/YOUR_USERNAME?tab=packages`
  - Try pulling manually: `podman pull ghcr.io/YOUR_USERNAME/md2pdf:latest`

**Problem**: Authentication failed when pushing
- **Solution**:
  - Create a GitHub Personal Access Token with `write:packages` permission
  - Set it as: `export GITHUB_TOKEN=your-token`
  - Or login interactively: `podman login ghcr.io`

**Problem**: Script can't detect GitHub username
- **Solution**:
  - Set it manually: `export GITHUB_USER=your-username`
  - Or ensure git remote is configured: `git remote get-url origin`

## Documentation

For detailed documentation on the container architecture, build process, and advanced usage, see [CONTAINER_DOCUMENTATION.md](CONTAINER_DOCUMENTATION.md).

## Based On

This container is based on the GitHub Actions workflow in `build-pdfs.yml`, which was originally designed to run in GitHub Actions. This containerized version allows you to run the same PDF generation process locally or in any container environment.
