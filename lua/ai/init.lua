--local copilot = require("ai.copilot")
local antigravity = require("ai.antigravity")
--local claudecode = require("ai.claudecode")
--local ollama = require("ai.ollama")

--copilot.setup()
--ollama.setup()

local specs = {}

--for _, spec in ipairs(copilot.specs) do table.insert(specs, spec) end

for _, spec in ipairs(antigravity.specs) do
  table.insert(specs, spec)
end

--for _, spec in ipairs(claudecode.specs) do table.insert(specs, spec) end

--for _, spec in ipairs(ollama.specs) do table.insert(specs, spec) end

return specs

