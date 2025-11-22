--[[
Pandoc Lua filter to convert Mermaid diagrams to images
This filter processes mermaid code blocks and converts them to images using mermaid-cli
]]

local system = require 'pandoc.system'

local mermaid_count = 0

function CodeBlock(block)
  -- Check if this is a mermaid code block
  if block.classes[1] ~= "mermaid" then
    return nil
  end
  
  mermaid_count = mermaid_count + 1
  
  -- Create temp file names
  local input_file = string.format("mermaid-temp/diagram_%d.mmd", mermaid_count)
  local output_file = string.format("mermaid-temp/diagram_%d.png", mermaid_count)
  
  -- Write Mermaid code to file
  local f = io.open(input_file, 'w')
  f:write(block.text)
  f:close()
  
  -- Build mmdc command
  local cmd = string.format(
    'mmdc -i "%s" -o "%s" -b transparent -w 1200 -H 800 -p puppeteer-config.json 2>&1',
    input_file,
    output_file
  )
  
  -- Run the command
  io.stderr:write(string.format("Converting Mermaid diagram %d...\n", mermaid_count))
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  -- Check if image was created
  local img_file = io.open(output_file, 'r')
  if img_file ~= nil then
    img_file:close()
    io.stderr:write(string.format("✅ Successfully converted diagram %d\n", mermaid_count))
    
    -- Get absolute path
    local abs_path = pandoc.pipe('realpath', {output_file}, '')
    abs_path = abs_path:gsub("%s+$", "") -- trim whitespace
    
    -- Return an image instead of the code block
    return pandoc.Para({
      pandoc.Image(
        {pandoc.Str(string.format("Mermaid Diagram %d", mermaid_count))},
        abs_path,
        "",
        {width = "80%"}
      )
    })
  else
    io.stderr:write(string.format("⚠️  Failed to convert diagram %d\n", mermaid_count))
    io.stderr:write(result)
    -- Return the original code block or a note
    return pandoc.Para({
      pandoc.Strong({pandoc.Str("[Mermaid Diagram - See online version]")})
    })
  end
end

return {
  {CodeBlock = CodeBlock}
}

