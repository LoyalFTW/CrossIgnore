local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L
local PREFIX = "CrossIgnoreShare"
local LINK_TYPE = "crossignore"
local LINK = LINK_TYPE .. ":"
local TOKEN = "[CrossIgnore:"
local TOKEN_PATTERN = "%[CrossIgnore:(%d+):([^%[%]:|%c]+)%]"
local PROMPT = "CROSSIGNORE_REVIEW_SHARE"
local OFFER_SECONDS = 300
local TRANSFER_SECONDS = 120
local CHUNK_SIZE = 190
local MAX_CHUNKS = 480
local MAX_OFFERS = 20
local MAX_OUTGOING = 3
local sent, outgoing = {}, {}
local outgoingCount = 0
local nextID = 0
local activeTransfer
local registered

local function NewID()
    nextID = nextID + 1
    return ("%d%06d%d"):format(time(), math.random(100000, 999999), nextID)
end

local function ValidID(id)
    return id and #id <= 24 and id:match("^%d+$")
end

local function Readable(value)
    return not canaccessvalue or canaccessvalue(value)
end

local function PlayerName(name)
    if not Readable(name) or type(name) ~= "string" or #name > 80 or name:find("[%c|:%[%]]") then return end
    local full, base = CrossIgnore:NormalizePlayerName(name)
    if not full or (not CrossIgnore.isForever and base:find("%s")) then return end
    return full
end

local function SendMessage(text, target)
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "WHISPER", target)
    if not ok then return false end
    return result == true or result == 0, result == 3
end

local function InsertChatToken(token)
    local getActiveWindow = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or _G["ChatEdit_GetActiveWindow"]
    local openChat = ChatFrameUtil and ChatFrameUtil.OpenChat or _G["ChatFrame_OpenChat"]
    local editBox = getActiveWindow and getActiveWindow()
    if editBox then
        editBox:Insert(token)
    elseif openChat then
        openChat(token)
    else
        return false
    end
    return true
end

local function ShowChatLinks(_, _, message, sender, ...)
    if not Readable(message) or type(message) ~= "string" or not message:find(TOKEN, 1, true) then return end

    local display, replaced = message:gsub(TOKEN_PATTERN, function(id, owner)
        local name = ValidID(id) and PlayerName(owner)
        if not name or CrossIgnore:IsPlayerBlocked(name) then return end
        return ("|cff71d5ff|H%s%s:%s|h[%s]|h|r"):format(LINK, id, name, L["OPTIONS_SHARE_LINK_TEXT"])
    end)
    if replaced > 0 and display ~= message then return false, display, sender, ... end
end

local function SendChunks(offer, request, target)
    local key = target:lower()
    if outgoing[key] then return end
    if outgoingCount >= MAX_OUTGOING then
        SendMessage("E:" .. request .. ":busy", target)
        return
    end

    outgoing[key] = true
    outgoingCount = outgoingCount + 1
    local index = 1
    local expires = GetTime() + TRANSFER_SECONDS
    local function finish()
        outgoing[key] = nil
        outgoingCount = outgoingCount - 1
    end
    local function sendNext()
        if GetTime() >= expires then
            finish()
            return
        end
        local first = (index - 1) * CHUNK_SIZE + 1
        local chunk = offer.text:sub(first, first + CHUNK_SIZE - 1)
        local ok, throttled = SendMessage(("D:%s:%d:%d:%s"):format(request, index, offer.total, chunk), target)
        if throttled then
            C_Timer.After(1, sendNext)
        elseif ok and index < offer.total then
            index = index + 1
            C_Timer.After(0.15, sendNext)
        else
            finish()
        end
    end
    sendNext()
end

function CrossIgnore:ShareListsInChat()
    local owner = PlayerName(self:GetCurrentCharacterKey())
    if not registered or not owner then
        self:Print(L["OPTIONS_SHARE_FAILED"])
        return
    end

    local ok, text = pcall(self.ExportLists, self)
    if not ok or not text then
        self:Print(L["OPTIONS_EXPORT_FAILED"])
        return
    end
    local total = math.ceil(#text / CHUNK_SIZE)
    if total > MAX_CHUNKS then
        self:Print(L["OPTIONS_SHARE_TOO_LARGE"])
        return
    end
    local now, count = GetTime(), 0
    for id, offer in pairs(sent) do
        if offer.expires <= now then
            sent[id] = nil
        else
            count = count + 1
        end
    end
    if count >= MAX_OFFERS then
        self:Print(L["OPTIONS_SHARE_BUSY"])
        return
    end

    local id = NewID()
    sent[id] = { text = text, total = total, expires = now + OFFER_SECONDS }
    if not InsertChatToken(TOKEN .. id .. ":" .. owner .. "]") then
        sent[id] = nil
        self:Print(L["OPTIONS_SHARE_FAILED"])
    end
end

function CrossIgnore:OnListShareMessage(_, prefix, message, channel, sender)
    if not Readable(prefix) or not Readable(channel) or not Readable(message)
        or prefix ~= PREFIX or channel ~= "WHISPER" or type(message) ~= "string" or #message > 255 then return end
    local name = PlayerName(sender)
    if not name or self:IsPlayerBlocked(name) then return end
    local command, id, rest = message:match("^([RDE]):(%d+):(.*)$")
    if not ValidID(id) then return end

    if command == "R" then
        if not ValidID(rest) then return end
        local offer = sent[id]
        if not offer or offer.expires <= GetTime() then
            SendMessage("E:" .. rest .. ":expired", name)
            return
        end
        SendChunks(offer, rest, name)
        return
    end

    local transfer = activeTransfer
    if not transfer or transfer.request ~= id or transfer.owner:lower() ~= name:lower() then return end
    if command == "E" then
        activeTransfer = nil
        self:Print(L[rest == "busy" and "OPTIONS_SHARE_BUSY" or "OPTIONS_SHARE_EXPIRED"])
        return
    end

    local index, total, chunk = rest:match("^(%d+):(%d+):([%w():]+)$")
    index, total = tonumber(index), tonumber(total)
    if not index or not total or total < 1 or total > MAX_CHUNKS or index < 1 or index > total
        or #chunk > CHUNK_SIZE or (index < total and #chunk ~= CHUNK_SIZE)
        or (transfer.total and transfer.total ~= total) or transfer.chunks[index] then return end
    transfer.total = total
    transfer.chunks[index] = chunk
    transfer.count = transfer.count + 1
    if transfer.count == total then
        activeTransfer = nil
        self:ReviewSharedLists(table.concat(transfer.chunks))
    end
end

function CrossIgnore:InitializeListSharing()
    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    registered = ok and (result == true or result == 0 or result == 1)
    if not registered then return end
    self:RegisterEvent("CHAT_MSG_ADDON", "OnListShareMessage")

    StaticPopupDialogs[PROMPT] = {
        text = L["OPTIONS_SHARE_CONFIRM"],
        button1 = L["OPTIONS_SHARE_REVIEW_BUTTON"],
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, offer)
            if self:IsPlayerBlocked(offer.owner) then return end
            local current = PlayerName(self:GetCurrentCharacterKey())
            if current and current:lower() == offer.owner:lower() then
                local own = sent[offer.id]
                if own and own.expires > GetTime() then
                    self:ReviewSharedLists(own.text)
                else
                    self:Print(L["OPTIONS_SHARE_EXPIRED"])
                end
                return
            end
            if activeTransfer then
                self:Print(L["OPTIONS_SHARE_BUSY"])
                return
            end
            local transfer = { owner = offer.owner, request = NewID(), chunks = {}, count = 0 }
            activeTransfer = transfer
            if not SendMessage("R:" .. offer.id .. ":" .. transfer.request, offer.owner) then
                activeTransfer = nil
                self:Print(L["OPTIONS_SHARE_FAILED"])
                return
            end
            C_Timer.After(TRANSFER_SECONDS, function()
                if activeTransfer ~= transfer then return end
                activeTransfer = nil
                self:Print(L["OPTIONS_SHARE_TIMEOUT"])
            end)
        end,
    }

    local function onLink(link)
        if not Readable(link) or type(link) ~= "string" or link:sub(1, #LINK) ~= LINK then return end
        local id, owner = link:sub(#LINK + 1):match("^(%d+):(.+)$")
        owner = ValidID(id) and PlayerName(owner)
        if not owner or self:IsPlayerBlocked(owner) then return end
        if IsModifiedClick("CHATLINK") then
            InsertChatToken(TOKEN .. id .. ":" .. owner .. "]")
        else
            StaticPopup_Show(PROMPT, owner, nil, { id = id, owner = owner })
        end
    end

    if LinkUtil and LinkUtil.RegisterLinkHandler then
        LinkUtil.RegisterLinkHandler(LINK_TYPE, onLink)
    end
    if not (LinkUtil and LinkUtil.IsLinkHandlerRegistered and LinkUtil.IsLinkHandlerRegistered(LINK_TYPE)) then
        hooksecurefunc("SetItemRef", onLink)
    end

    local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or _G["ChatFrame_AddMessageEventFilter"]
    if addFilter then
        for _, event in ipairs({
            "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
            "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
            "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
        }) do
            addFilter(event, ShowChatLinks)
        end
    end
end
