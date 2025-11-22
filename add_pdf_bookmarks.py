#!/usr/bin/env python3
"""
Add PDF bookmarks (outlines) based on markdown headings.
This creates the navigation sidebar in PDF readers.
"""
import sys
import re
from pypdf import PdfReader, PdfWriter

def extract_headings_from_markdown(md_file):
    """Extract headings from markdown file."""
    headings = []
    with open(md_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for line_num, line in enumerate(lines, 1):
        # Match markdown headings (# ## ### etc.)
        match = re.match(r'^(#{1,6})\s+(.+)$', line.strip())
        if match:
            level = len(match.group(1))  # Number of # symbols
            title = match.group(2).strip()
            # Remove markdown formatting from title
            title = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', title)  # Remove links
            title = re.sub(r'[*_`]', '', title)  # Remove emphasis
            headings.append({
                'level': level,
                'title': title,
                'line': line_num
            })
    
    return headings

def add_bookmarks_to_pdf(pdf_path, headings):
    """Add bookmarks to existing PDF."""
    try:
        reader = PdfReader(pdf_path)
        writer = PdfWriter()
        
        # Copy all pages
        for page in reader.pages:
            writer.add_page(page)
        
        # Estimate page numbers (rough calculation)
        # Assume ~50 lines per page for markdown content
        total_pages = len(reader.pages)
        
        # Add bookmarks
        bookmark_stack = [None] * 7  # Support up to 6 levels of headings
        
        for heading in headings:
            level = heading['level']
            title = heading['title']
            
            # Estimate which page this heading is on
            # This is approximate - PDFs don't preserve line numbers
            estimated_page = min(int((heading['line'] / 50.0)), total_pages - 1)
            estimated_page = max(0, estimated_page)
            
            # Add bookmark
            parent = bookmark_stack[level - 1] if level > 1 else None
            
            bookmark = writer.add_outline_item(
                title=title,
                page_number=estimated_page,
                parent=parent
            )
            
            # Store this bookmark for potential children
            bookmark_stack[level] = bookmark
            # Clear any deeper level bookmarks
            for i in range(level + 1, 7):
                bookmark_stack[i] = None
        
        # Write the updated PDF
        with open(pdf_path, 'wb') as output_file:
            writer.write(output_file)
        
        print(f"✅ Added {len(headings)} bookmarks to {pdf_path}")
        return True
        
    except Exception as e:
        print(f"❌ Error adding bookmarks to {pdf_path}: {e}")
        return False

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: add_pdf_bookmarks.py <markdown_file> <pdf_file>")
        sys.exit(1)
    
    md_file = sys.argv[1]
    pdf_file = sys.argv[2]
    
    print(f"Processing {md_file} -> {pdf_file}")
    
    # Extract headings from markdown
    headings = extract_headings_from_markdown(md_file)
    print(f"Found {len(headings)} headings")
    
    for h in headings[:5]:  # Show first 5
        indent = "  " * (h['level'] - 1)
        print(f"  {indent}{'#' * h['level']} {h['title']}")
    
    if len(headings) > 5:
        print(f"  ... and {len(headings) - 5} more")
    
    # Add bookmarks to PDF
    if headings:
        success = add_bookmarks_to_pdf(pdf_file, headings)
        sys.exit(0 if success else 1)
    else:
        print("⚠️  No headings found, skipping bookmark generation")
        sys.exit(0)

