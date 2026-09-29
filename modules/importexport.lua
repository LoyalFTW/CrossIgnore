local _, ns = ...
local CrossIgnore = ns.Addon

function CrossIgnore:SerializeHuman(filters)
    local parts = {}
    for channel, list in pairs(filters) do
        if type(list) == "table" then
            local entries = {}
            for _, entry in ipairs(list) do
                if type(entry) == "table" and entry.word ~= nil and entry.strict ~= nil then
                    entries[#entries+1] = entry.word .. "|" .. tostring(entry.strict)
                end
            end
            parts[#parts+1] = channel .. ":" .. table.concat(entries, ",")
        end
    end
    return table.concat(parts, ";")
end

function CrossIgnore:DeserializeHuman(str)
    if not str or str == "" then return nil end
    local filters = {}
    for channelPair in string.gmatch(str, "([^;]+)") do
        local channel, wordStr = channelPair:match("([^:]+):(.*)")
        if channel then
            filters[channel] = filters[channel] or {}
            for wordEntry in string.gmatch(wordStr, "([^,]+)") do
                local word, strictStr = wordEntry:match("([^|]+)|?(.*)")
                if word then
                    filters[channel][#filters[channel] + 1] = {
                        word = word,
                        strict = strictStr == "true",
                        normalized = string.lower(word)
                    }
                end
            end
        end
    end
    return filters
end
