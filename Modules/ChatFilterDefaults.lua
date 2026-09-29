local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

function CrossIgnore:LoadDefaultBlockedWords()
    local filters = self.ChatFilter:GetFilters()
    local L = ns.L

    local oldKey, newKey = L.OLD_CHANNEL_SERVICES, L.CHANNEL_SERVICES

    filters[newKey] = filters[newKey] or {}

    if filters[oldKey] then
        for _, entry in ipairs(filters[oldKey]) do
            local word = type(entry) == "table" and entry.word or entry
            local strict = type(entry) == "table" and entry.strict or true
            local normalized = word:lower()

            local exists = false
            for _, e in ipairs(filters[newKey]) do
                local n = type(e) == "table" and e.normalized or e
                if n and n:lower() == normalized then
                    exists = true
                    break
                end
            end

            if not exists then
                table.insert(filters[newKey], {
                    word       = word,
                    normalized = normalized,
                    strict     = strict,
                })
            end
        end
        filters[oldKey] = nil
    end

    if not filters.defaultsLoaded and not filters.removedDefaults then
        local wordsToBlock = { "WTS", "WTB", "BOOST", "CARRY", "STARTING NOW", "GOOD PRICES" }
        local existing = {}
        for _, entry in ipairs(filters[newKey]) do
            local n = type(entry) == "table" and entry.normalized or entry
            if n then existing[n:lower()] = true end
        end

        for _, word in ipairs(wordsToBlock) do
            local lower = word:lower()
            if not existing[lower] then
                table.insert(filters[newKey], {
                    word       = word,
                    normalized = lower,
                    strict     = true,
                })
                existing[lower] = true
            end
        end
        filters.defaultsLoaded = true
    end
end
