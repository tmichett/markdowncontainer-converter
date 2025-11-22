(function() {
  // Add styles for better Mermaid rendering and page breaks
  const style = document.createElement('style');
  style.textContent = `
    .mermaid {
      display: flex;
      justify-content: center;
      margin: 1.5em auto;
      padding: 1em 0;
      page-break-inside: avoid !important;
      break-inside: avoid !important;
      page-break-before: auto;
      page-break-after: auto;
    }
    .mermaid svg {
      max-width: 100%;
      max-height: 800px;
      height: auto;
      page-break-inside: avoid !important;
    }
    /* Ensure content after diagram stays close */
    .mermaid + h1,
    .mermaid + h2,
    .mermaid + h3,
    .mermaid + p {
      margin-top: 1em;
      page-break-before: avoid;
    }
  `;
  document.head.appendChild(style);
  
  // Wait for everything to be ready
  function initMermaid() {
    console.log('[Mermaid Init] Starting initialization...');
    
    // Check if Mermaid is loaded
    if (typeof mermaid === 'undefined') {
      console.error('[Mermaid Init] ERROR: Mermaid library not loaded!');
      console.log('[Mermaid Init] Available globals:', Object.keys(window).filter(k => k.toLowerCase().includes('mermaid')));
      return;
    }
    
    console.log('[Mermaid Init] Mermaid library loaded, version:', mermaid.version || 'unknown');
    
    // Find all code blocks
    const codeBlocks = document.querySelectorAll('pre code.language-mermaid, code.language-mermaid, pre code[class*="mermaid"]');
    console.log('[Mermaid Init] Found', codeBlocks.length, 'code blocks with mermaid class');
    
    if (codeBlocks.length === 0) {
      console.log('[Mermaid Init] No Mermaid code blocks found. Checking all code blocks...');
      const allCode = document.querySelectorAll('pre code, code');
      console.log('[Mermaid Init] Total code blocks:', allCode.length);
      allCode.forEach((block, i) => {
        const classes = block.className;
        const text = block.textContent.substring(0, 50);
        console.log(`  [${i}] class="${classes}" content="${text}..."`);
      });
    }
    
    // Convert code blocks to mermaid divs
    let converted = 0;
    codeBlocks.forEach(function(codeBlock, index) {
      try {
        const pre = codeBlock.closest('pre') || codeBlock.parentElement;
        const mermaidCode = codeBlock.textContent.trim();
        
        console.log(`[Mermaid Init] Processing block ${index + 1}:`, mermaidCode.substring(0, 50) + '...');
        
        // Create div for mermaid
        const div = document.createElement('div');
        div.className = 'mermaid';
        div.textContent = mermaidCode;
        div.id = 'mermaid-' + index;
        
        // Replace the pre/code with the div
        if (pre && pre.tagName === 'PRE') {
          pre.parentNode.replaceChild(div, pre);
        } else {
          codeBlock.parentNode.replaceChild(div, codeBlock);
        }
        
        converted++;
        console.log(`[Mermaid Init] ✓ Converted block ${index + 1}`);
      } catch (e) {
        console.error(`[Mermaid Init] ERROR converting block ${index + 1}:`, e);
      }
    });
    
    console.log(`[Mermaid Init] Converted ${converted} blocks to mermaid divs`);
    
    // Initialize and render Mermaid
    try {
      console.log('[Mermaid Init] Initializing Mermaid...');
      mermaid.initialize({
        startOnLoad: false,
        theme: 'default',
        securityLevel: 'loose',
        fontFamily: 'arial, sans-serif',
        logLevel: 'debug'
      });
      
      console.log('[Mermaid Init] Running mermaid.run()...');
      
      // Get all mermaid divs
      const mermaidDivs = document.querySelectorAll('.mermaid');
      console.log('[Mermaid Init] Found', mermaidDivs.length, 'mermaid divs to render');
      
      if (mermaidDivs.length > 0) {
        mermaid.run({
          nodes: mermaidDivs
        }).then(() => {
          console.log('[Mermaid Init] ✓✓✓ All diagrams rendered successfully!');
        }).catch(e => {
          console.error('[Mermaid Init] ERROR rendering diagrams:', e);
        });
      }
    } catch (e) {
      console.error('[Mermaid Init] ERROR during mermaid initialization:', e);
    }
  }
  
  // Try multiple approaches to ensure it runs
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initMermaid);
  } else {
    // DOM already loaded
    initMermaid();
  }
  
  // Also try after a short delay as fallback
  setTimeout(initMermaid, 500);
})();

