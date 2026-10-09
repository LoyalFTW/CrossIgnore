local _, ns = ...
local ChatFilter = ns.Addon.ChatFilter
local cache = {}

local flags = { nonlatin = true, guild = true, guildname = true, community = true, item = true,
    trade = true, link = true, achievement = true, journal = true }

function ChatFilter:CompileRule(expression)
    if type(expression) ~= "string" or expression:match("^%s*$") then return nil, "Enter a filter expression." end
    if #expression > 4096 then return nil, "Filter expressions must be 4096 characters or less." end
    if cache[expression] then return cache[expression] end
    local tokens, position = {}, 1
    while position <= #expression do
        local character = expression:sub(position, position)
        if character:match("%s") then
            position = position + 1
        elseif character == "(" or character == ")" then
            tokens[#tokens + 1] = character
            position = position + 1
        elseif character == "[" then
            local finish, parts = position + 1, {}
            while finish <= #expression and expression:sub(finish, finish) ~= "]" do
                local value = expression:sub(finish, finish)
                if value == "\\" then
                    finish = finish + 1
                    if finish > #expression then return nil, "Missing closing ]." end
                    value = expression:sub(finish, finish)
                end
                parts[#parts + 1] = value
                finish = finish + 1
            end
            if finish > #expression then return nil, "Missing closing ]." end
            local content = table.concat(parts)
            local key, value = content:match("^([%a]+)=(.+)$")
            key = (key or content):lower()
            if value then
                if key ~= "contains" and key ~= "word" and key ~= "item" and key ~= "words" then
                    return nil, "Unknown condition: " .. key
                end
                if (key == "item" or key == "words") and not value:match("^%d+$") then
                    return nil, key .. " requires a number."
                end
            elseif not flags[key] then
                return nil, "Unknown condition: " .. key
            end
            tokens[#tokens + 1] = { key = key, value = value and value:lower() }
            position = finish + 1
        else
            local operator = expression:sub(position):match("^(%a+)")
            if not operator or (operator:lower() ~= "and" and operator:lower() ~= "or" and operator:lower() ~= "not") then
                return nil, "Expected a condition, and, or, not, or parentheses."
            end
            tokens[#tokens + 1] = operator:lower()
            position = position + #operator
        end
        if #tokens > 256 then return nil, "Filter expression is too complex." end
    end
    local index, depth = 1, 0
    local parseOr, parseAnd, parsePrimary
    parsePrimary = function()
        depth = depth + 1
        if depth > 32 then error("Too many nested conditions.", 0) end
        local token = tokens[index]
        local node
        if token == "not" then
            index = index + 1
            node = { operator = "not", left = parsePrimary() }
        elseif token == "(" then
            index = index + 1
            node = parseOr()
            if tokens[index] ~= ")" then error("Missing closing parenthesis.", 0) end
            index = index + 1
        elseif type(token) == "table" then
            node = token
            index = index + 1
        else
            error("Expected a condition.", 0)
        end
        depth = depth - 1
        return node
    end
    parseAnd = function()
        local node = parsePrimary()
        while tokens[index] == "and" do
            index = index + 1
            node = { operator = "and", left = node, right = parsePrimary() }
        end
        return node
    end
    parseOr = function()
        local node = parseAnd()
        while tokens[index] == "or" do
            index = index + 1
            node = { operator = "or", left = node, right = parseAnd() }
        end
        return node
    end
    local ok, node = pcall(parseOr)
    if not ok then return nil, node end
    if index <= #tokens then return nil, "Unexpected condition or parenthesis." end
    local size = 0
    for _ in pairs(cache) do size = size + 1 end
    if size >= 128 then wipe(cache) end
    cache[expression] = node
    return node
end

local function Evaluate(node, text, raw)
    if node.operator == "and" then return Evaluate(node.left, text, raw) and Evaluate(node.right, text, raw) end
    if node.operator == "or" then return Evaluate(node.left, text, raw) or Evaluate(node.right, text, raw) end
    if node.operator == "not" then return not Evaluate(node.left, text, raw) end
    local key, value = node.key, node.value
    if key == "contains" then return text:find(value, 1, true) ~= nil end
    if key == "word" then
        local escaped = value:gsub("(%W)", "%%%1")
        return text:find("%f[%w]" .. escaped .. "%f[%W]") ~= nil
    end
    if key == "nonlatin" then return ChatFilter.ContainsEastAsianText(text) end
    if key == "guildname" then return text:find("<[^>]+>") ~= nil end
    if key == "words" then
        local count = 0
        for _ in text:gmatch("%S+") do count = count + 1 end
        return count == tonumber(value)
    end
    if key == "link" then return raw:find("|h", 1, true) ~= nil end
    if key == "guild" then return raw:find("|hguild", 1, true) ~= nil end
    if key == "community" then return raw:find("|hclubticket:", 1, true) ~= nil end
    if key == "item" and value then return raw:find("|hitem:" .. value .. ":", 1, true) ~= nil or raw:find("|hitem:" .. value .. "|h", 1, true) ~= nil end
    return raw:find("|h" .. key .. ":", 1, true) ~= nil
end

function ChatFilter:TestRule(expression, message)
    local compiled, err = self:CompileRule(expression)
    if not compiled then return nil, err end
    if type(message) ~= "string" then return false end
    local text = message:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    return Evaluate(compiled, text, message:lower()) and true or false
end
