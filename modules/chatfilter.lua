local ChatFilter = CrossIgnore.ChatFilter or {}
CrossIgnore.ChatFilter = ChatFilter

local AddMessageEventFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
local RemoveMessageEventFilter = (ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter) or ChatFrame_RemoveMessageEventFilter

local CHAT_EVENTS = {
    Say          = { "CHAT_MSG_SAY" },
    Yell         = { "CHAT_MSG_YELL" },
    Whisper      = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" },
    Guild        = { "CHAT_MSG_GUILD" },
    Officer      = { "CHAT_MSG_OFFICER" },
    Party        = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" },
    Raid         = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" },
    Instance     = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" },
    Battleground = { "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER" },
    Emote        = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" },
    Channel      = { "CHAT_MSG_CHANNEL" },
}

local channelCache = {}

local function safeString(value)
    return type(value) == "string" and value or ""
end

local function safeLower(value)
    local text = safeString(value)
    if text == "" then
        return ""
    end
    return text:lower()
end

local function RefreshChannelCache()
    wipe(channelCache)
    local chList = { GetChannelList() }
    for i = 1, #chList, 3 do
        local num = chList[i]
        local name = safeString(chList[i + 1])
        if name ~= "" then
            local cleanName = safeLower(name)
            if type(num) == "number" then
                channelCache[tostring(num)] = cleanName
            end
            channelCache[cleanName] = cleanName
            channelCache[name] = cleanName
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHANNEL_UI_UPDATE")
f:RegisterEvent("CHANNEL_COUNT_UPDATE")
f:RegisterEvent("CHANNEL_ROSTER_UPDATE")
f:SetScript("OnEvent", RefreshChannelCache)
RefreshChannelCache()

local function NormalizeChannelKey(channel)
    local key
    if type(channel) == "number" then
        key = tostring(channel)
    else
        key = safeString(channel)
    end
    if key == "" then
        return "all channels"
    end
    local normalized = channelCache[safeLower(key)] or key
    return safeLower(normalized)
end
function ChatFilter:NormalizeChannelKey(ch)
    return NormalizeChannelKey(ch)
end

local function GetChannelCategory(event, ...)
    if event == "CHAT_MSG_CHANNEL" then
        for i = 1, select("#", ...) do
            local a = select(i, ...)
            if type(a) == "string" and a ~= "" then
                local clean = safeLower(a:gsub("^%d+%.%s*", ""))
                return channelCache[clean] or clean
            end
        end
        return nil
    end

    for channelName, events in pairs(CHAT_EVENTS) do
        for _, ev in ipairs(events) do
            if ev == event then
                return channelName:lower()
            end
        end
    end

    return nil
end

function ChatFilter:GetFilters()
    if not CrossIgnoreDB then return {} end
    CrossIgnoreDB.global = CrossIgnoreDB.global or {}
    CrossIgnoreDB.global.filters = CrossIgnoreDB.global.filters or {}
    CrossIgnoreDB.global.filters.words = CrossIgnoreDB.global.filters.words or {}
    CrossIgnoreDB.global.filters.words["all channels"] =
        CrossIgnoreDB.global.filters.words["all channels"] or {}

    for key, list in pairs(CrossIgnoreDB.global.filters.words) do
        if type(list) ~= "table" then
            CrossIgnoreDB.global.filters.words[key] = {}
        end
    end

    return CrossIgnoreDB.global.filters.words
end

local function EscapeForPattern(text)
    return (text:gsub("(%W)", "%%%1"))
end

local function buildStrictCore(wordLower)
    local chars = {}
    for c in wordLower:gmatch(".") do
        chars[#chars+1] = EscapeForPattern(c)
    end
    if #chars == 0 then return nil end
    if #chars == 1 then
        return "%f[%z\1-\255]" .. chars[1] .. "%f[%z\1-\255]"
    end
    return table.concat(chars, "[%s%p]*")
end

local function buildNonStrictList(wordLower)
    local out = {}
    local exact = EscapeForPattern(wordLower)
    local chars = {}
    for c in wordLower:gmatch(".") do
        chars[#chars+1] = EscapeForPattern(c)
    end
    local spaced
    if #chars >= 2 then
        spaced = chars[1]
        for i = 2, #chars do
            spaced = spaced .. "%s+" .. chars[i]
        end
    end

    local function pushBoundaryVariants(core)
        out[#out+1] = "^" .. core .. "%s+"
        out[#out+1] = "^" .. core .. "$"
        out[#out+1] = "%s+" .. core .. "%s+"
        out[#out+1] = "%s+" .. core .. "$"
    end

    pushBoundaryVariants(exact)
    if spaced then
        pushBoundaryVariants(spaced)
    end
    return out
end

local compiledMatchers = {}
local reusableBuckets = {} 

local function buildMatcherForChannel(channelKey, patterns)
    if not patterns or #patterns == 0 then
        compiledMatchers[channelKey] = nil
        return
    end

    local bucket = reusableBuckets[channelKey] or {}
    reusableBuckets[channelKey] = bucket
    wipe(bucket)

    for i = 1, #patterns do
        bucket[#bucket+1] = patterns[i]
    end
    compiledMatchers[channelKey] = bucket
end

local function CompilePatternsForChannel(channelKey)
    local filters = ChatFilter:GetFilters()
    local list = filters[channelKey]

    if type(list) ~= "table" or #list == 0 then
        compiledMatchers[channelKey] = nil
        return
    end

    local bucket = reusableBuckets[channelKey] or {}
    reusableBuckets[channelKey] = bucket
    wipe(bucket)

    for _, entry in ipairs(list) do
        if type(entry) == "table" or type(entry) == "string" then
            local wordLower = (type(entry) == "table" and entry.normalized) or (type(entry) == "string" and entry:lower())
            if wordLower and wordLower ~= "" then
                if type(entry) == "table" and entry.strict then
                    local core = buildStrictCore(wordLower)
                    if core then bucket[#bucket+1] = core end
                else
                    local plist = buildNonStrictList(wordLower)
                    for i = 1, #plist do
                        bucket[#bucket+1] = plist[i]
                    end
                end
            end
        end
    end

    compiledMatchers[channelKey] = bucket
end

local function CompilePatterns()
    for channelKey, _ in pairs(ChatFilter:GetFilters()) do
        CompilePatternsForChannel(channelKey)
    end
end

local function IsFilteredMessage(msg, sender, event, ...)
    msg = safeString(msg)
    sender = safeString(sender)
    local msgLower = safeLower(msg)
    local senderLower = safeLower(sender)

    local filters = ChatFilter:GetFilters()

    local function findMatchedWord(key)
        local patterns = compiledMatchers[key] or {}

        for _, pattern in ipairs(patterns) do
            if msgLower:find(pattern) or senderLower:find(pattern) then
                return pattern, false
            end
        end

        local list = filters[key] or {}
        for _, entry in ipairs(list) do
            local word = (type(entry) == "table" and entry.normalized) or (type(entry) == "string" and entry:lower())
            local strict = type(entry) == "table" and entry.strict or false
            if word then
                if strict then
                    local strippedMsg = msgLower:gsub("[%s%p]", "")
                    local strippedWord = word:gsub("[%s%p]", "")
                    if strippedMsg:find(strippedWord, 1, true) then
                        return word, true
                    end
                else
                    if msgLower:find(word, 1, true) or senderLower:find(word, 1, true) then
                        return word, false
                    end
                end
            end
        end

        return nil, false
    end

    local allMatchedWord, allIsStrict = findMatchedWord("all channels")
    if allMatchedWord then
        return true, allMatchedWord, allIsStrict
    end

    local channelKey = GetChannelCategory(event, ...)
    if channelKey then
        channelKey = NormalizeChannelKey(channelKey)
        local channelMatchedWord, channelIsStrict = findMatchedWord(channelKey)
        if channelMatchedWord then
            return true, channelMatchedWord, channelIsStrict
        end
    end

    return false, nil, false
end

local MAX_LOG_ENTRIES = 500
local logIndex = 1

local function AddLog(entry)
    CrossIgnore.ChatFilter.blockedMessages = CrossIgnore.ChatFilter.blockedMessages or {}
    local logs = CrossIgnore.ChatFilter.blockedMessages

    logs[logIndex] = entry
    logIndex = logIndex + 1
    if logIndex > MAX_LOG_ENTRIES then
        logIndex = 1
    end
end

local recentMessages = {}
local DUPLICATE_EXPIRY = 60 

local function IsDuplicate(msg, sender)
    msg = safeString(msg)
    sender = safeString(sender)
    local now = time()
    recentMessages[sender] = recentMessages[sender] or {}
    local senderMessages = recentMessages[sender]

    if senderMessages[msg] and now - senderMessages[msg] < DUPLICATE_EXPIRY then
        return true
    end

    senderMessages[msg] = now
    return false
end

local cleanupFrame = CreateFrame("Frame")
cleanupFrame.elapsed = 0
cleanupFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 30 then return end 
    self.elapsed = 0

    local now = time()
    for sender, messages in pairs(recentMessages) do
        for msg, ts in pairs(messages) do
            if now - ts >= DUPLICATE_EXPIRY then
                messages[msg] = nil
            end
        end
        if not next(messages) then
            recentMessages[sender] = nil
        end
    end
end)

local function IsFilteredForChannel(msg, sender, channelKey)
    msg = safeString(msg)
    sender = safeString(sender)
    local msgLower = safeLower(msg)
    local senderLower = safeLower(sender)

    local filters = CrossIgnore.ChatFilter:GetFilters()
    local list = filters[channelKey] or {}

    for _, entry in ipairs(list) do
        local word = (type(entry) == "table" and entry.normalized) or (type(entry) == "string" and entry:lower())
        local strict = type(entry) == "table" and entry.strict or false
        if word then
            if strict then
                if (msgLower:gsub("[%s%p]", "")):find(word:gsub("[%s%p]", ""), 1, true) then
                    return word, true
                end
            else
                if msgLower:find(word, 1, true) or senderLower:find(word, 1, true) then
                    return word, false
                end
            end
        end
    end

    return nil, false
end

function ChatFilter:SetDebugActive(state)
    self.debugActive = state and true or false
end

function ChatFilter:IsDebugActive()
    return self.debugActive == true
end


function ChatFilter:ClearLog()
    if not self.blockedMessages then
        self.blockedMessages = {}
        return
    end

    for i = #self.blockedMessages, 1, -1 do
        table.remove(self.blockedMessages, i)
    end

    if self.RefreshRightPanel then
        self:RefreshRightPanel()
    end
end

local function ChatEventFilter(_, event, msg, sender, ...)
    local blocked, matchedWord, isStrict, matchedKey = false, nil, false, nil

    local keysToCheck = { "all channels" }
    local channelKey = GetChannelCategory(event, ...)
    if channelKey then
        table.insert(keysToCheck, CrossIgnore.ChatFilter:NormalizeChannelKey(channelKey))
    end

    for _, key in ipairs(keysToCheck) do
        local word, strict = IsFilteredForChannel(msg, sender, key)
        if word then
            matchedKey = key
            matchedWord = word
            isStrict = strict
            blocked = true
            break
        end
    end

    if blocked then
        local now = time()
        local entry = {
            message   = msg,
            sender    = sender,
            channel   = matchedKey,
            word      = matchedWord,
            strict    = isStrict,
            event     = event,
            time      = date("%Y-%m-%d %H:%M:%S", GetServerTime()),
            timestamp = now,
        }

    if ChatFilter.debugActive then
        AddLog(entry)
		if not IsDuplicate(msg, sender) and CrossIgnore.ChatFilter.OnBlockedMessageAdded then
				for _, callback in ipairs(CrossIgnore.ChatFilter.OnBlockedMessageAdded) do
					callback(entry)
				end
			end
		end
	end

    return blocked
end

function ChatFilter:UpdateEventRegistration()
    for _, events in pairs(CHAT_EVENTS) do
        for _, ev in ipairs(events) do
            if RemoveMessageEventFilter then
                pcall(RemoveMessageEventFilter, ev, ChatEventFilter)
            end
        end
    end

    CompilePatterns()

    local haveAny = next(compiledMatchers) ~= nil
    if not haveAny then return end

    for channelName, events in pairs(CHAT_EVENTS) do
        local shouldHook = false
        local keyLower = channelName:lower()

        if compiledMatchers["all channels"] then
            shouldHook = true
        end

        if not shouldHook and compiledMatchers[keyLower] then
            shouldHook = true
        end

        if not shouldHook and channelName == "Channel" then
            for key, _ in pairs(compiledMatchers) do
                if key ~= "all channels" and not CHAT_EVENTS[key] then
                    shouldHook = true
                    break
                end
            end
        end

        if shouldHook then
            for _, ev in ipairs(events) do
                if AddMessageEventFilter then
                    pcall(AddMessageEventFilter, ev, ChatEventFilter)
                end
            end
        end
    end
end

function ChatFilter:AddWord(word, channel, strict)
    if not word or word == "" then return end
    local filters = self:GetFilters()
    local key = NormalizeChannelKey(channel or "all channels")
    filters[key] = filters[key] or {}
    local normWord = word:lower()

    for _, v in ipairs(filters[key]) do
        local existing = (type(v) == "table" and v.normalized) or (type(v) == "string" and v:lower())
        if existing == normWord then
            if type(v) == "table" then
                v.strict = not not strict
            else
                for i, e in ipairs(filters[key]) do
                    if e == v then
                        filters[key][i] = { word = v, normalized = existing, strict = not not strict }
                        break
                    end
                end
            end
            self:UpdateEventRegistration()
            return
        end
    end

    table.insert(filters[key], { word = word, normalized = normWord, strict = not not strict })
    self:UpdateEventRegistration()
end

function ChatFilter:RemoveWord(word, channel)
    if not word or word == "" then return end
    local filters = self:GetFilters()
    local key = NormalizeChannelKey(channel or "all channels")
    local list = filters[key]
    if type(list) ~= "table" then return end

    local lowered = word:lower()
    for i = #list, 1, -1 do
        local entry = list[i]
        local normalized = (type(entry) == "table" and entry.normalized) or (type(entry) == "string" and entry:lower()) or ""
        if normalized == lowered then
            table.remove(list, i)
            break
        end
    end

    self:UpdateEventRegistration()
end

function ChatFilter:SetWordStrict(word, channel, strict)
    if not word or word == "" then return end
    local filters = self:GetFilters()
    local key = NormalizeChannelKey(channel or "all channels")
    filters[key] = filters[key] or {}

    for idx, entry in ipairs(filters[key]) do
        if (type(entry) == "table" and entry.word and entry.word:lower() == word:lower())
        or (type(entry) == "string" and entry:lower() == word:lower()) then
            if type(entry) == "table" then
                entry.strict = not not strict
            else
                local normalized = entry:lower()
                filters[key][idx] = { word = entry, normalized = normalized, strict = not not strict }
            end
            break
        end
    end

    self:UpdateEventRegistration()
end

function ChatFilter:Initialize()
    self:UpdateEventRegistration()
end

function ChatFilter:CompilePatterns()
    CompilePatterns()
end

function ChatFilter:IsFilteredMessage(msg, sender, event, ...)
    return IsFilteredMessage(msg, sender, event, ...)
end

return ChatFilter
