local _, ns = ...
local CrossIgnore = ns.Addon
local GuildIgnore = {}
CrossIgnore.GuildIgnore = GuildIgnore

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_AFK", "CHAT_MSG_DND", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_COMMUNITIES_CHANNEL",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
}

local CHAT_EVENT_SET = {}
for _, event in ipairs(CHAT_EVENTS) do CHAT_EVENT_SET[event] = true end

local BUBBLE_EVENTS = {
    CHAT_MSG_SAY = true,
    CHAT_MSG_YELL = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
}

local FILTER = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
local SECONDS_PER_DAY = 86400
local CACHE_MAX = 2000
local RETENTION_DAYS = { [1] = true, [7] = true, [30] = true }
local guildByPlayer = {}
local guildCount = 0
local pendingBubbles = {}
local hiddenBubbles = {}
local bubbleTicker
local purgeQueued

local function Readable(value)
    return not canaccessvalue or canaccessvalue(value)
end

local function Clean(value)
    if not Readable(value) or type(value) ~= "string" then return nil end
    value = strtrim(value)
    return value ~= "" and value or nil
end

local function PlayerKey(name)
    name = Clean(name)
    if not name then return nil end
    local fullName = CrossIgnore:NormalizePlayerName(name)
    return fullName and fullName:lower()
end

local function Rules()
    return CrossIgnore.globalDB.global.guildIgnores
end

function GuildIgnore:GetRules()
    return Rules()
end

function GuildIgnore:GetRetentionDays(name)
    name = Clean(name)
    if not name then return 1 end
    local days = CrossIgnore.globalDB.global.guildRetention[name:lower()]
    return RETENTION_DAYS[days] and days or 1
end

function GuildIgnore:SetRetentionDays(name, days)
    name = Clean(name)
    if not name or not RETENTION_DAYS[days] or not self:IsGuildBlocked(name) then return false end
    local key = name:lower()
    CrossIgnore.globalDB.global.guildRetention[key] = days ~= 1 and days or nil
    local now = time()
    for player, record in pairs(guildByPlayer) do
        if type(record) == "table" and type(record.guild) == "string" and record.guild:lower() == key
            and (type(record.seen) ~= "number" or record.seen + days * SECONDS_PER_DAY < now) then
            guildByPlayer[player] = nil
            guildCount = guildCount - 1
        end
    end
    self:PurgeChat()
    return true
end

function GuildIgnore:GetKnownPlayersForGuild(name)
    name = Clean(name)
    if not name then return {} end
    local players = {}
    local now = time()
    local retention = self:GetRetentionDays(name) * SECONDS_PER_DAY
    for key, record in pairs(guildByPlayer) do
        if type(record) == "table" and type(record.guild) == "string" and type(record.seen) == "number"
            and record.seen + retention >= now and record.guild:lower() == name:lower() then
            players[#players + 1] = { name = record.name or key, seen = record.seen }
        end
    end
    table.sort(players, function(a, b) return a.name:lower() < b.name:lower() end)
    return players
end

function GuildIgnore:IsGuildBlocked(name)
    name = Clean(name)
    return name and Rules()[name:lower()] ~= nil or false
end

function GuildIgnore:DeclineBlockedGuildInvite(guildName)
    if CrossIgnore.globalDB.global.guildAutoDeclineInvites == false or not self:IsGuildBlocked(guildName) then return end
    DeclineGuild()
    StaticPopup_Hide("GUILD_INVITE")
    C_Timer.After(0, function() StaticPopup_Hide("GUILD_INVITE") end)
end

function GuildIgnore:AddGuild(name)
    name = Clean(name)
    if not name then return false end
    local key = name:lower()
    if Rules()[key] then return false end
    Rules()[key] = name
    self:PurgeChat()
    return true
end

function GuildIgnore:RemoveGuild(name)
    name = Clean(name)
    if not name or not Rules()[name:lower()] then return false end
    Rules()[name:lower()] = nil
    CrossIgnore.globalDB.global.guildRetention[name:lower()] = nil
    return true
end

function GuildIgnore:KnownGuild(name)
    local key = PlayerKey(name)
    local record = key and guildByPlayer[key]
    if not record then return nil end
    if record.seen + self:GetRetentionDays(record.guild) * SECONDS_PER_DAY < time() then
        guildByPlayer[key] = nil
        guildCount = guildCount - 1
        return nil
    end
    return record.guild
end

function GuildIgnore:Remember(name, guild)
    local key = PlayerKey(name)
    if not key or not Readable(guild) or type(guild) ~= "string" then return end
    guild = strtrim(guild)
    local displayName = CrossIgnore:NormalizePlayerName(name)
    local previous = guildByPlayer[key]
    if not previous then guildCount = guildCount + 1 end
    guildByPlayer[key] = { name = displayName, guild = guild, seen = time() }
    if guildCount > CACHE_MAX then
        local oldestKey, oldestTime
        for candidate, record in pairs(guildByPlayer) do
            if type(record) == "table" and type(record.seen) == "number" and (not oldestTime or record.seen < oldestTime) then
                oldestKey, oldestTime = candidate, record.seen
            end
        end
        if oldestKey then
            guildByPlayer[oldestKey] = nil
            guildCount = guildCount - 1
        end
    end
    if (not previous or previous.guild ~= guild) and self:IsGuildBlocked(guild) then
        self:PurgeChat()
    end
    local guildUI = ns.UI and ns.UI.GuildIgnore
    if guildUI and guildUI.selected and guildUI.panel and guildUI.panel:IsShown()
        and ((previous and previous.guild and previous.guild:lower() == guildUI.selected:lower()) or guild:lower() == guildUI.selected:lower()) then
        guildUI:RefreshMembers()
    end
end

function GuildIgnore:ObserveUnit(unit, authoritative)
    if not unit then return end
    local exists = UnitExists(unit)
    local isPlayer = UnitIsPlayer(unit)
    if not Readable(exists) or not Readable(isPlayer) or not exists or not isPlayer then return end
    local guild = GetGuildInfo(unit)
    if not Readable(guild) or (not Clean(guild) and not authoritative) then return end
    local name, realm = CrossIgnore:GetUnitPlayerName(unit)
    if not Clean(name) or not Readable(realm) then return end
    self:Remember(not CrossIgnore.isForever and realm and realm ~= "" and name .. "-" .. realm or name, guild or "")
end

function GuildIgnore:ObserveGroup()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do self:ObserveUnit("raid" .. i) end
    else
        for i = 1, GetNumSubgroupMembers() do self:ObserveUnit("party" .. i) end
    end
end

function GuildIgnore:HarvestWho()
    local countFunction = C_FriendList and C_FriendList.GetNumWhoResults or GetNumWhoResults
    local infoFunction = C_FriendList and C_FriendList.GetWhoInfo or GetWhoInfo
    if not countFunction or not infoFunction then return end
    local count = countFunction() or 0
    for i = 1, count do
        local first, second = infoFunction(i)
        if Readable(first) and type(first) == "table" then
            if Readable(first.fullName) and Readable(first.fullGuildName) then
                self:Remember(first.fullName, first.fullGuildName or "")
            end
        elseif Readable(first) and Readable(second) then
            self:Remember(first, second or "")
        end
    end
end

function GuildIgnore:LookUpPlayer(name)
    name = Clean(name)
    local sendWho = C_FriendList and C_FriendList.SendWho or SendWho
    if not name or not sendWho then return false end
    local ok = pcall(sendWho, 'n-"' .. name .. '"')
    return ok
end

function GuildIgnore:PurgeChat()
    if (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance()) then return end
    if purgeQueued then return end
    purgeQueued = true
    C_Timer.After(0, function()
        purgeQueued = false
        self:PurgeChatNow()
    end)
end

function GuildIgnore:PurgeChatNow()
    if (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance()) then return end
    if not CHAT_FRAMES then return end
    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame and frame.RemoveMessagesByPredicate then
            pcall(frame.RemoveMessagesByPredicate, frame, function(text, _, _, _, _, _, _, event, args)
                if not Readable(text) or type(text) ~= "string" then return false end
                if event and (not Readable(event) or not CHAT_EVENT_SET[event]) then return false end
                local argsReadable = Readable(args) and type(args) == "table" and (not canaccesstable or canaccesstable(args))
                local author = argsReadable and Readable(args[2]) and args[2] or text:match("|Hplayer:([^:|]+)")
                local guild = author and self:KnownGuild(author)
                local authorKey, selfKey = PlayerKey(author), PlayerKey(CrossIgnore:GetUnitPlayerName("player"))
                if authorKey and authorKey == selfKey then guild = GetGuildInfo("player") end
                return guild and self:IsGuildBlocked(guild) or false
            end)
        end
    end
end

local function ScanBubbles()
    if (IsInInstance and IsInInstance()) or (InCombatLockdown and InCombatLockdown()) then
        wipe(pendingBubbles)
        if not next(hiddenBubbles) and bubbleTicker then bubbleTicker:Cancel(); bubbleTicker = nil end
        return
    end
    local getBubbles = C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles or GetAllChatBubbles
    if not getBubbles then return end
    local now = GetTime()
    for text, expires in pairs(pendingBubbles) do
        if expires < now then pendingBubbles[text] = nil end
    end
    local bubbles = getBubbles(false)
    local seen = {}
    for _, bubble in pairs(bubbles or {}) do
        local frame = bubble.GetChildren and bubble:GetChildren()
        if frame and frame.String and not (frame.IsForbidden and frame:IsForbidden()) then
            seen[frame] = true
            local value = frame.String:GetText()
            if Readable(value) and type(value) == "string" then
                if hiddenBubbles[frame] and hiddenBubbles[frame] ~= value then
                    frame:SetAlpha(1)
                    hiddenBubbles[frame] = nil
                end
                if pendingBubbles[value] then
                    frame:SetAlpha(0)
                    hiddenBubbles[frame] = value
                end
            end
        end
    end
    for frame in pairs(hiddenBubbles) do
        if not seen[frame] then
            frame:SetAlpha(1)
            hiddenBubbles[frame] = nil
        end
    end
    if not next(pendingBubbles) and not next(hiddenBubbles) then
        bubbleTicker:Cancel()
        bubbleTicker = nil
    end
end

function GuildIgnore:HideBubble(event, message)
    if (IsInInstance and IsInInstance()) or (InCombatLockdown and InCombatLockdown()) then return end
    if not BUBBLE_EVENTS[event] or not Clean(message) or not ((C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) or GetAllChatBubbles) then return end
    pendingBubbles[message] = GetTime() + 1
    if not bubbleTicker then bubbleTicker = C_Timer.NewTicker(0.1, ScanBubbles) end
end

local function FilterChat(_, event, message, sender, _, _, _, _, _, _, _, _, _, guid)
    if not next(Rules()) then return false end
    local senderKey, selfKey = PlayerKey(sender), PlayerKey(CrossIgnore:GetUnitPlayerName("player"))
    local guild = GuildIgnore:KnownGuild(sender)
    if senderKey and senderKey == selfKey then
        guild = GetGuildInfo("player")
        if Clean(guild) then GuildIgnore:Remember(sender, guild) end
    end
    if not guild and (event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_OFFICER") then
        guild = GetGuildInfo("player")
        if Clean(guild) then GuildIgnore:Remember(sender, guild) end
    end
    if not guild and Readable(guid) and type(guid) == "string" and UnitTokenFromGUID then
        local unit = UnitTokenFromGUID(guid)
        if Readable(unit) and unit then
            GuildIgnore:ObserveUnit(unit)
            guild = GuildIgnore:KnownGuild(sender)
        end
    end
    if guild and GuildIgnore:IsGuildBlocked(guild) then
        GuildIgnore:HideBubble(event, message)
        return true
    end
    return false
end

function GuildIgnore:Initialize()
    local db = CrossIgnore.globalDB.global
    db.guildIgnores = db.guildIgnores or {}
    db.guildKnowledge = db.guildKnowledge or {}
    db.guildRetention = db.guildRetention or {}
    guildByPlayer = db.guildKnowledge
    for key, record in pairs(guildByPlayer) do
        if type(record) ~= "table" or type(record.guild) ~= "string" or type(record.seen) ~= "number"
            or record.seen + self:GetRetentionDays(record.guild) * SECONDS_PER_DAY < time() then
            guildByPlayer[key] = nil
        else
            guildCount = guildCount + 1
        end
    end
    if FILTER then
        for _, event in ipairs(CHAT_EVENTS) do pcall(FILTER, event, FilterChat) end
    end
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_FOCUS_CHANGED", "NAME_PLATE_UNIT_ADDED", "GROUP_ROSTER_UPDATE", "WHO_LIST_UPDATE", "PLAYER_GUILD_UPDATE", "GUILD_INVITE_REQUEST" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event, unit, guildName)
        if event == "GUILD_INVITE_REQUEST" then self:DeclineBlockedGuildInvite(guildName)
        elseif event == "WHO_LIST_UPDATE" then self:HarvestWho()
        elseif event == "NAME_PLATE_UNIT_ADDED" or event == "PLAYER_GUILD_UPDATE" then self:ObserveUnit(unit, event == "PLAYER_GUILD_UPDATE")
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then self:ObserveGroup()
        elseif event == "PLAYER_TARGET_CHANGED" then self:ObserveUnit("target")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then self:ObserveUnit("mouseover")
        elseif event == "PLAYER_FOCUS_CHANGED" then self:ObserveUnit("focus") end
    end)
    self.frame = frame
    self:ObserveGroup()
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            if plate.namePlateUnitToken then self:ObserveUnit(plate.namePlateUnitToken) end
        end
    end
end
