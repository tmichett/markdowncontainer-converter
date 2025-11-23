# Markdown to PDF Container Documentation

## Overview

This containerized solution converts Markdown files to PDF with support for:
- **Mermaid diagrams** - Renders Mermaid code blocks as diagrams
- **GitHub-style markdown** - Uses GitHub's markdown CSS for consistent styling
- **PDF bookmarks** - Automatically generates navigation bookmarks from markdown headings
- **Emoji support** - Renders emojis using Noto Color Emoji fonts
- **Custom pagination** - CSS rules to prevent awkward page breaks

The container is based on the GitHub Actions workflow (`build-pdfs.yml`) and provides the same functionality in a portable, reusable container format.

## Architecture

### Container Components

The container is built from a `Containerfile` (Docker/Podman compatible) and includes:

#### Base System
- **Ubuntu** (latest) - Base operating system
- **Node.js & npm** - JavaScript runtime and package manager
- **Python 3** - For PDF bookmark generation
- **Chromium dependencies** - Libraries required for headless browser operation
- **Font packages** - Including Noto Color Emoji for emoji rendering

#### Installed Tools
- **md-to-pdf** (npm global) - Converts markdown to PDF using Puppeteer/Chromium
- **pypdf** (Python package) - Adds PDF bookmarks/outlines from markdown headings

#### Configuration Files
Located in `/app/config/` (persistent, not overwritten by volume mounts):

1. **`.md-to-pdf.json`** - Main configuration for md-to-pdf
   - GitHub markdown CSS styling
   - Custom CSS for pagination (`pdf-styles.css`)
   - Mermaid.js integration
   - Chromium launch options
   - PDF format settings (A4, margins, etc.)

2. **`pdf-styles.css`** - Custom CSS for better PDF output
   - Prevents page breaks inside code blocks, tables, diagrams
   - Controls heading placement
   - Better spacing for lists and images

3. **`mermaid-init.js`** - JavaScript for Mermaid diagram initialization
   - Converts Mermaid code blocks to rendered diagrams
   - Handles diagram rendering after page load
   - Applies styling for proper page breaks

4. **`add_pdf_bookmarks.py`** - Python script for PDF bookmarks
   - Extracts headings from markdown files
   - Creates PDF outline/bookmarks for navigation
   - Estimates page numbers for bookmark placement

#### Entrypoint Script
**`/app/entrypoint.sh`** - Main entry point for the container
- Accepts two arguments: input markdown file and output PDF path
- Validates input file exists
- Runs md-to-pdf conversion
- Adds PDF bookmarks using Python script
- Handles errors gracefully

## Build Process

### Prerequisites
- **Podman** (or Docker) installed
- Access to the internet (for downloading packages and npm packages)

### Building the Container

Run the build script:

```bash
./build.sh
```

Or manually with Podman:

```bash
podman build -f Containerfile -t markdown-to-pdf:latest .
```

Or with Docker:

```bash
docker build -f Containerfile -t markdown-to-pdf:latest .
```

### Build Steps

1. **Base Image**: Starts with `ubuntu:latest`

2. **System Dependencies**: Installs:
   - Node.js and npm
   - Python 3 and pip
   - Chromium runtime dependencies (libraries, not Chromium itself)
   - Font packages (Liberation, Noto Color Emoji, etc.)
   - Font configuration tools

3. **Tool Installation**:
   - Installs `md-to-pdf` globally via npm
   - Installs `pypdf` Python package (with `--break-system-packages` flag for newer Python)

4. **Configuration Setup**:
   - Creates `/app/config/` directory
   - Copies configuration files to `/app/config/`
   - Copies Python bookmark script to `/app/`
   - Copies entrypoint script to `/app/`
   - Makes scripts executable

5. **Font Cache**: Updates font cache so Chromium can find installed fonts

### Customizing the Build

You can customize the image name and tag:

```bash
IMAGE_NAME=my-pdf-converter IMAGE_TAG=v1.0 ./build.sh
```

## Run Process

### Configuration File

Create a `config.yaml` file listing markdown files to convert:

```yaml
files:
  - path: path/to/file.md
  - path: another/file.md
  - path: /absolute/path/to/file.md
```

Paths can be:
- **Relative** - Relative to the directory where you run `run.sh`
- **Absolute** - Full system paths (e.g., `/Users/username/project/file.md`)

### Running the Converter

#### Using the Run Script (Recommended)

```bash
./run.sh
```

The script will:
1. Check if `config.yaml` exists
2. Check if container image exists (builds if missing)
3. Parse `config.yaml` to get list of markdown files
4. For each file:
   - Determine mount point (based on absolute vs relative path)
   - Run container with appropriate volume mounts
   - Convert markdown to PDF
   - Generate PDF in same location with `.pdf` extension
5. Display summary of successful and failed conversions

#### Custom Configuration File

```bash
CONFIG_FILE=my-config.yaml ./run.sh
```

#### Custom Image Name/Tag

```bash
IMAGE_NAME=my-pdf-converter IMAGE_TAG=v1.0 ./run.sh
```

### Manual Container Execution

You can also run the container manually:

```bash
podman run --rm \
  -v /path/to/mount:/path/to/mount:Z \
  markdown-to-pdf:latest \
  /path/to/mount/input.md \
  /path/to/mount/output.pdf
```

**Important**: The volume mount path must match the parent directory of your input/output files.

For example, if converting `/Users/john/docs/file.md`:
```bash
podman run --rm \
  -v /Users:/Users:Z \
  markdown-to-pdf:latest \
  /Users/john/docs/file.md \
  /Users/john/docs/file.pdf
```

## How It Works

### Conversion Process

1. **Input Validation**
   - Entrypoint script checks if input markdown file exists
   - Validates output directory exists (creates if needed)

2. **PDF Generation**
   - `md-to-pdf` is called with the input file and config
   - Puppeteer launches Chromium headless browser
   - Markdown is rendered as HTML with GitHub CSS
   - Mermaid diagrams are initialized and rendered
   - HTML is converted to PDF using Chromium's PDF engine
   - PDF is saved to temporary location (same directory as input)

3. **Bookmark Addition**
   - Python script reads the original markdown file
   - Extracts all headings (# ## ### etc.)
   - Creates PDF outline/bookmarks with estimated page numbers
   - Writes updated PDF with bookmarks

4. **File Management**
   - If temp PDF and output PDF are different paths, moves temp to output
   - If same path, skips move (already in correct location)

### Path Handling

The `run.sh` script intelligently handles paths:

- **Absolute paths** (starting with `/`):
  - For `/Users/*` paths: Mounts `/Users` directory
  - For `/home/*` paths: Mounts `/home` directory
  - Uses paths as-is in container (since parent is mounted)

- **Relative paths**:
  - Mounts current working directory as `/workspace`
  - Prepends `/workspace/` to paths in container

### Volume Mounts

The container uses volume mounts to access files on the host:
- **Read access**: To read markdown files
- **Write access**: To write PDF output files
- **Z flag**: For SELinux compatibility (Podman)

## Configuration Details

### md-to-pdf Configuration

The `.md-to-pdf.json` file configures:

- **Stylesheets**: GitHub markdown CSS + custom pagination CSS
- **PDF Options**: A4 format, 20mm margins, background printing enabled
- **Mermaid Support**: Loads Mermaid.js library and initialization script
- **Chromium Options**: No-sandbox mode (required for containers), GPU disabled
- **Timeout**: 60 seconds for page load

### Custom CSS (pdf-styles.css)

Key features:
- Prevents page breaks inside code blocks, tables, Mermaid diagrams
- Keeps headings with following content (orphan/widow control)
- Better spacing around images and diagrams
- Prevents awkward breaks in lists

### Mermaid Initialization

The `mermaid-init.js` script:
- Waits for page to fully load
- Finds all Mermaid code blocks
- Converts them to `<div class="mermaid">` elements
- Initializes Mermaid renderer
- Renders all diagrams before PDF generation

### PDF Bookmarks

The `add_pdf_bookmarks.py` script:
- Parses markdown to extract headings
- Removes markdown formatting from heading text
- Creates hierarchical bookmark structure
- Estimates page numbers (approximate, based on line count)
- Adds bookmarks to PDF using pypdf library

## Troubleshooting

### Container Build Issues

**Problem**: Package not found errors
- **Solution**: Some packages have different names in different Ubuntu versions. The Containerfile handles this with fallbacks.

**Problem**: Python externally-managed-environment error
- **Solution**: Already handled with `--break-system-packages` flag.

**Problem**: Chromium snap installation error
- **Solution**: Container uses Puppeteer's bundled Chromium instead of system Chromium.

### Runtime Issues

**Problem**: "Input file does not exist"
- **Solution**: Check that:
  - File path in config.yaml is correct
  - Volume mount includes the file's parent directory
  - Path is absolute or relative correctly

**Problem**: "PDF already at target location" or move errors
- **Solution**: This is normal when input and output are in the same directory. The script handles this automatically.

**Problem**: Emojis not rendering
- **Solution**: Ensure container has latest fonts installed. Rebuild container if needed.

**Problem**: Mermaid diagrams not rendering
- **Solution**: Check that:
  - Mermaid code blocks use correct syntax (```mermaid)
  - Network access is available (Mermaid.js loads from CDN)
  - Check container logs for Mermaid initialization errors

**Problem**: Permission errors
- **Solution**: 
  - Ensure scripts are executable: `chmod +x build.sh run.sh entrypoint.sh`
  - Check file permissions on input/output directories
  - On SELinux systems, ensure Z flag is used in volume mounts

### Performance

- **First run**: May be slower as Puppeteer downloads Chromium
- **Subsequent runs**: Faster as Chromium is cached in container
- **Large files**: May take longer, especially with many Mermaid diagrams
- **Network**: Requires internet for Mermaid.js and GitHub CSS (CDN)

## File Structure

```
markdowncontainer-converter/
├── Containerfile              # Container definition
├── build.sh                  # Build script
├── run.sh                    # Run script
├── entrypoint.sh             # Container entrypoint
├── config.yaml.example       # Example configuration
├── pdf-styles.css            # Custom CSS
├── .md-to-pdf.json           # md-to-pdf configuration
├── mermaid-init.js           # Mermaid initialization
├── add_pdf_bookmarks.py      # PDF bookmark script
├── README.md                 # Quick start guide
└── CONTAINER_DOCUMENTATION.md # This file
```

## Differences from GitHub Actions Workflow

The container version differs from the GitHub Actions workflow in:

1. **Chromium Source**: Uses Puppeteer's bundled Chromium instead of system Chromium
2. **Font Installation**: Explicitly installs emoji fonts (GitHub Actions may have them pre-installed)
3. **Path Handling**: Supports both absolute and relative paths (workflow uses relative)
4. **Volume Mounts**: Requires explicit volume mounting for file access
5. **Configuration Location**: Config files in `/app/config/` to survive volume mounts

## Best Practices

1. **Use relative paths** in config.yaml when possible (simpler)
2. **Keep config.yaml** in the same directory as run.sh
3. **Rebuild container** after updating configuration files
4. **Check file permissions** before running
5. **Review PDF output** to ensure Mermaid diagrams rendered correctly
6. **Use version tags** for container images in production: `IMAGE_TAG=v1.0`

## Advanced Usage

### Batch Processing

Process multiple config files:

```bash
for config in configs/*.yaml; do
  CONFIG_FILE="$config" ./run.sh
done
```

### Custom Fonts

To add custom fonts:
1. Copy font files to container during build
2. Install fonts in Containerfile
3. Update font cache

### Environment Variables

The container respects:
- `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD` - Already set to true (uses bundled)
- `PUPPETEER_EXECUTABLE_PATH` - Not needed (uses bundled)

## Support

For issues or questions:
1. Check this documentation
2. Review error messages carefully
3. Check container logs: `podman logs <container-id>`
4. Verify file paths and permissions
5. Ensure all dependencies are installed


