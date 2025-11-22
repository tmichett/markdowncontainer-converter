#!/usr/bin/env python3
"""
Process Mermaid diagrams in Markdown files by converting them to images.
"""
import re
import subprocess
import sys
import os

def process_mermaid_diagrams(input_file, output_file, basename, temp_dir="mermaid-temp"):
    """Extract Mermaid diagrams and convert them to PNG images."""
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all Mermaid code blocks (handles both ```mermaid and ``` mermaid)
    pattern = r'```\s*mermaid\s*\n(.*?)```'
    matches = list(re.finditer(pattern, content, re.DOTALL | re.IGNORECASE))
    
    if not matches:
        # No Mermaid diagrams, just copy the file
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
        return 0
    
    diagram_count = 0
    new_content_parts = []
    last_end = 0
    
    # Ensure temp directory exists
    os.makedirs(temp_dir, exist_ok=True)
    
    for match in matches:
        # Add content before the Mermaid block
        new_content_parts.append(content[last_end:match.start()])
        
        diagram_count += 1
        mermaid_code = match.group(1).strip()
        diagram_file = os.path.join(temp_dir, f"{basename}_diagram_{diagram_count}.mmd")
        image_file = os.path.join(temp_dir, f"{basename}_diagram_{diagram_count}.png")
        
        # Write Mermaid code to file
        with open(diagram_file, 'w', encoding='utf-8') as f:
            f.write(mermaid_code)
        
        # Convert to image using mermaid-cli
        try:
            # Add debugging output
            print(f"   Converting diagram {diagram_count}...")
            print(f"   Input: {diagram_file}")
            print(f"   Output: {image_file}")
            
            # Build mmdc command with puppeteer config if it exists
            mmdc_cmd = ['mmdc', '-i', diagram_file, '-o', image_file, '-b', 'transparent', '-w', '1200', '-H', '800']
            
            # Check if puppeteer-config.json exists in current directory
            if os.path.exists('puppeteer-config.json'):
                mmdc_cmd.extend(['-p', 'puppeteer-config.json'])
                print(f"   Using puppeteer-config.json")
            
            result = subprocess.run(
                mmdc_cmd,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0 and os.path.exists(image_file):
                # Get absolute path for LaTeX compatibility
                abs_image_path = os.path.abspath(image_file)
                # Also get file size for verification
                img_size = os.path.getsize(image_file)
                print(f"✅ Converted Mermaid diagram {diagram_count} to {image_file} ({img_size} bytes)")
                
                # Replace with image reference - use absolute path for better LaTeX compatibility
                # Add width constraint to ensure images fit on page
                new_content_parts.append(f"![Mermaid Diagram {diagram_count}]({abs_image_path}){{width=80%}}\n")
            else:
                # Keep original if conversion fails
                new_content_parts.append(f"```mermaid\n{mermaid_code}\n```")
                print(f"⚠️  Failed to convert Mermaid diagram {diagram_count}")
                print(f"   Return code: {result.returncode}")
                if result.stdout:
                    print(f"   Stdout: {result.stdout[:200]}")
                if result.stderr:
                    print(f"   Stderr: {result.stderr[:200]}")
        except subprocess.TimeoutExpired:
            new_content_parts.append(f"```mermaid\n{mermaid_code}\n```")
            print(f"⚠️  Timeout converting Mermaid diagram {diagram_count}")
        except FileNotFoundError:
            new_content_parts.append(f"```mermaid\n{mermaid_code}\n```")
            print(f"⚠️  mmdc command not found - Mermaid CLI may not be installed")
        except Exception as e:
            # Keep original on error
            new_content_parts.append(f"```mermaid\n{mermaid_code}\n```")
            print(f"⚠️  Error converting Mermaid diagram {diagram_count}: {type(e).__name__}: {e}")
        
        last_end = match.end()
    
    # Add remaining content
    new_content_parts.append(content[last_end:])
    
    # Write processed content
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(''.join(new_content_parts))
    
    return diagram_count

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: process_mermaid.py <input_file> <output_file> <basename>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    basename = sys.argv[3]
    
    if not os.path.exists(input_file):
        print(f"Error: Input file '{input_file}' not found")
        sys.exit(1)
    
    count = process_mermaid_diagrams(input_file, output_file, basename)
    print(f"Processed {count} Mermaid diagram(s)")

