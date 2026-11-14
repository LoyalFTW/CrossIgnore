local _, ns = ...
local CrossIgnore = ns.Addon
local ChatFilter = CrossIgnore.ChatFilter
local LibDeflate = LibStub("LibDeflate")
local CopyEntry = ns.CoreInternals.CopyEntry
local PREFIX = "CrossIgnore:1:"

local function WordDetails(entry)
    if type(entry) == "string" then return entry, false end
    if type(entry) == "table" then return entry.word, entry.strict == true end
end

local function ReadLegacyWords(text)
    if text == "" then return nil end
    local words = {}
    for channelPair in text:gmatch("[^;]+") do
        local channel, entries = channelPair:match("^([^:]+):(.*)$")
        if not channel then return nil end
        for entry in entries:gmatch("[^,]+") do
            local word, strict = entry:match("^(.+)|(%a+)$")
            if not word or (strict ~= "true" and strict ~= "false") then return nil end
            words[#words + 1] = { channel = channel, word = word, strict = strict == "true" }
        end
    end
    return { words = words, rules = {}, players = {}, guilds = {} }
end

local function IsText(value)
    return type(value) == "string" and value:find("%S") ~= nil
end

local function IsTimestamp(value)
    return type(value) == "number" and value >= 0 and value < math.huge
end

local function IsPlayerName(value)
    return IsText(value) and not value:find("%c")
end

local function ValidateList(list, valid)
    if type(list) ~= "table" then return false end
    local count = 0
    for index, entry in pairs(list) do
        if type(index) ~= "number" or index < 1 or index > #list or index % 1 ~= 0
            or type(entry) ~= "table" or not valid(entry) then
            return false
        end
        count = count + 1
    end
    return count == #list
end

local function ValidateTransfer(data)
    return type(data) == "table" and type(data.forever) == "boolean"
        and ValidateList(data.words, function(entry)
            return IsText(entry.channel) and IsText(entry.word) and type(entry.strict) == "boolean"
        end)
        and ValidateList(data.rules, function(rule)
            return IsText(rule.name) and #rule.name <= 120 and type(rule.enabled) == "boolean"
                and (rule.preset == nil or type(rule.preset) == "string")
                and ChatFilter:CompileRule(rule.expression) ~= nil
        end)
        and ValidateList(data.players, function(entry)
            return IsPlayerName(entry.name)
                and type(entry.note) == "string" and IsTimestamp(entry.expires) and IsTimestamp(entry.added)
        end)
        and ValidateList(data.guilds, function(entry)
            return IsText(entry.name) and (entry.days == 1 or entry.days == 7 or entry.days == 30)
        end)
end

function CrossIgnore:ExportLists()
    local data = { forever = self.isForever, words = {}, rules = {}, players = {}, guilds = {} }

    for channel, list in pairs(ChatFilter:GetFilters()) do
        for _, entry in ipairs(list) do
            local word, strict = WordDetails(entry)
            if IsText(word) then
                data.words[#data.words + 1] = { channel = ChatFilter:NormalizeChannelKey(channel), word = word, strict = strict }
            end
        end
    end

    for _, rule in ipairs(ChatFilter:GetRuleList()) do
        data.rules[#data.rules + 1] = {
            preset = rule.default and rule.id or nil,
            name = rule.name,
            expression = rule.expression,
            enabled = rule.enabled,
        }
    end

    local now, seen = time(), {}
    local function addPlayer(name, note, expires, added)
        if not name or seen[name:lower()] then return end
        seen[name:lower()] = true
        if expires > 0 and expires <= now then return end
        data.players[#data.players + 1] = { name = name, note = note, expires = expires, added = added }
    end

    for _, list in ipairs({self:GetAllLists()}) do
        for _, entry in ipairs(list) do
            if not entry.markedAt and entry.ignored ~= false then
                addPlayer(self:GetStoredIgnoreName(entry), entry.note or "", entry.expires or 0, entry.added or now)
            end
        end
    end
    for name in pairs(self:GetBlizzardIgnoreSet()) do
        addPlayer(name, "", 0, now)
    end

    for _, name in pairs(self.GuildIgnore:GetRules()) do
        data.guilds[#data.guilds + 1] = { name = name, days = self.GuildIgnore:GetRetentionDays(name) }
    end

    local serialized = C_EncodingUtil.SerializeJSON(data)
    if not serialized then return nil end
    return PREFIX .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
end

local function ReadTransfer(text)
    text = text:gsub("%s", "")
    local versioned = text:sub(1, #PREFIX) == PREFIX
    local decoded = LibDeflate:DecodeForPrint(versioned and text:sub(#PREFIX + 1) or text)
    if not decoded then return nil end
    local payload, remaining = LibDeflate:DecompressDeflate(decoded)
    if not payload or remaining ~= 0 then return nil end
    if not versioned then return ReadLegacyWords(payload) end

    local data = C_EncodingUtil.DeserializeJSON(payload)
    if ValidateTransfer(data) then return data end
end

local function MergeWords(words)
    local filters = ChatFilter:GetFilters()
    local byChannel = {}
    for _, entry in ipairs(words) do
        local channel = ChatFilter:NormalizeChannelKey(entry.channel)
        local list = filters[channel] or {}
        filters[channel] = list
        local positions = byChannel[channel]
        if not positions then
            positions = {}
            byChannel[channel] = positions
            for index, existing in ipairs(list) do
                local word = WordDetails(existing)
                if IsText(word) then positions[word:lower()] = index end
            end
        end

        local normalized = entry.word:lower()
        local index = positions[normalized] or #list + 1
        positions[normalized] = index
        list[index] = { word = entry.word, strict = entry.strict, normalized = normalized }
    end
end

local function MergeRules(rules)
    local presets, custom = {}, {}
    for _, preset in ipairs(ChatFilter.presets) do
        presets[preset.id] = true
    end
    for _, rule in ipairs(ChatFilter:GetRuleList()) do
        if not rule.default then
            custom[rule.name] = custom[rule.name] or {}
            custom[rule.name][rule.expression] = rule.id
        end
    end

    local skipped = 0
    for _, rule in ipairs(rules) do
        local name = strtrim(rule.name)
        local matching = custom[name]
        local preset = presets[rule.preset] and rule.preset
        local id = preset or (matching and matching[rule.expression])
        local saved = ChatFilter:SaveRule(id, name, rule.expression, rule.enabled, true)
        if saved and not preset then
            custom[name] = matching or {}
            custom[name][rule.expression] = saved
        elseif not saved then
            skipped = skipped + 1
        end
    end
    return skipped
end

local function MergePlayers(addon, players)
    local profile = addon.charDB.profile
    local limit = profile.settings.maxIgnoreLimit or 50
    local slots = limit - C_FriendList.GetNumIgnores()
    local localEntries, globalEntries, native = {}, {}, {}
    for name in pairs(addon:GetBlizzardIgnoreSet()) do native[name:lower()] = true end
    for index, list in ipairs({addon:GetAllLists()}) do
        local entries = index <= 2 and localEntries or globalEntries
        for _, entry in ipairs(list) do
            local name = addon:GetStoredIgnoreName(entry)
            if name then entries[name:lower()] = { entry = entry, list = list } end
        end
    end

    local now, skipped = time(), 0
    local addedBy = addon:GetCurrentCharacterKey()
    for _, incoming in ipairs(players) do
        local fullName, base, realm = addon:NormalizePlayerName(incoming.name)
        if not fullName or (not addon.isForever and base:find("%s")) then
            skipped = skipped + 1
        elseif incoming.expires > 0 and incoming.expires <= now then
            skipped = skipped + 1
        else
            local key = fullName:lower()
            local present = localEntries[key]
            local shared = globalEntries[key]
            local entry = present and present.entry or (shared and CopyEntry(shared.entry)) or {
                name = base,
                server = realm,
                firstName = addon.isForever and base:match("^(%S+)") or nil,
                lastName = addon.isForever and base:match("(%S+)$") or nil,
                type = "player",
                ignored = true,
                note = incoming.note,
                expires = incoming.expires,
                added = incoming.added,
            }
            local inWoW = native[key]
            if not inWoW and slots > 0 and addon:TryAddBlizzardIgnore(fullName, limit) then
                slots = slots - 1
                native[key] = true
                inWoW = true
            end

            if not present or (inWoW and present.list == profile.overLimitPlayers) then
                if present then
                    for index, existing in ipairs(present.list) do
                        if existing == entry then
                            table.remove(present.list, index)
                            break
                        end
                    end
                end
                entry.addedBy = addedBy
                addon:StoreLocalIgnore(entry, inWoW)
                localEntries[key] = { entry = entry, list = inWoW and profile.players or profile.overLimitPlayers }
            end
        end
    end
    return skipped
end

function CrossIgnore:ImportLists(text, selected)
    if not IsText(text) then return nil end
    local ok, data = pcall(ReadTransfer, text)
    if not ok or not data then return nil end

    selected = selected or { words = true, rules = true, players = true, guilds = true }
    local words = selected.words and #data.words > 0
    local rules = selected.rules and #data.rules > 0
    local players = selected.players and #data.players > 0
    local guilds = selected.guilds and #data.guilds > 0
    if not (words or rules or players or guilds) then return false end

    if words then MergeWords(data.words) end
    local skippedRules = rules and MergeRules(data.rules) or 0
    if words or rules then
        ChatFilter:UpdateEventRegistration()
        if rules and ChatFilter.OnRulesChanged then ChatFilter.OnRulesChanged() end
        self:UpdateWordsList()
    end

    local sameVersion = data.forever == self.isForever
    local skippedPlayers = 0
    if players then
        skippedPlayers = sameVersion and MergePlayers(self, data.players) or #data.players
        self:RefreshBlockedList()
    end
    if guilds then
        for _, guild in ipairs(data.guilds) do
            if self.GuildIgnore:AddGuild(guild.name) then
                self.GuildIgnore:SetRetentionDays(guild.name, guild.days)
            end
        end
        if ns.UI.GuildIgnoreBuilt then ns.UI.GuildIgnore:Refresh() end
    end

    return true, skippedRules, skippedPlayers
end
