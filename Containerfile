# Containerfile for Markdown to PDF conversion
# Based on the GitHub Actions workflow build-pdfs.yml

FROM ubuntu:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
        nodejs \
        npm \
        chromium-browser \
        curl \
        python3 \
        python3-pip \
        && \
    rm -rf /var/lib/apt/lists/*

# Install md-to-pdf globally
RUN npm install -g md-to-pdf

# Install pypdf for PDF bookmarks
RUN pip3 install pypdf

# Create working directory and config directory
WORKDIR /workspace
RUN mkdir -p /app/config

# Copy configuration files to /app/config (won't be overwritten by volume mounts)
COPY pdf-styles.css /app/config/pdf-styles.css
COPY .md-to-pdf.json /app/config/.md-to-pdf.json
COPY mermaid-init.js /app/config/mermaid-init.js
COPY add_pdf_bookmarks.py /app/add_pdf_bookmarks.py

# Make scripts executable
RUN chmod +x /app/add_pdf_bookmarks.py

# Create entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]

