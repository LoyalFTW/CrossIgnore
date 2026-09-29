local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

local Core = ns.CoreInternals
local StripRealm = Core.StripRealm
local MakeKey = Core.MakeKey
local CopyEntry = Core.CopyEntry

function CrossIgnore:ClearAllIgnoredPlayers()
    local players, overLimitPlayers = self:GetActivePlayerTables()

    local snapshot = {}

    local function collect(list)
        for _, entry in ipairs(list or {}) do
            local name = entry.name
            local realm = entry.server or entry.realm
            if name and realm ~= nil then
                snapshot[#snapshot + 1] = MakeKey(name, realm)
            end
        end
    end

    collect(players)
    collect(overLimitPlayers)

    for _, fullName in ipairs(snapshot) do
        self:maybeMarkPendingRemoval(fullName)
    end

    for _, fullName in ipairs(snapshot) do
        self:DelIgnore(fullName)
    end

    self.selectedPlayer = nil
    self.selectedRow = nil

    if CrossIgnoreUI and CrossIgnoreUI.searchBox then
        self:RefreshBlockedList(CrossIgnoreUI.searchBox:GetText())
    else
        self:RefreshBlockedList()
    end
end

function CrossIgnore:AddIgnore(name, note, duration)
    local fullName, base, realm = self:NormalizePlayerName(name)
    if not base or realm == nil then
        if self.isForever then return end
        realm = GetNormalizedRealmName()
        if not base or realm == nil then return end
    end

    if self:IsPlayerInAnyList(base, realm) then return end

    local maxIgnoreLimit = self.charDB.profile.settings.maxIgnoreLimit or 50

    local dur = tonumber(duration)
    if not dur then
        local defaultDays = self.charDB.profile.settings.defaultExpireDays or 0
        dur = (defaultDays > 0) and (defaultDays * 86400) or 0
    end

    local expiresAt = (dur > 0) and (time() + dur) or 0

    local entry = {
        name       = base,
        server     = realm,
        firstName  = self.isForever and base:match("^(%S+)") or nil,
        lastName   = self.isForever and base:match("^%S+%s+(%S+)$") or nil,
        added      = time(),
        ignored    = true,
        source     = "blizzard",
        type       = "player",
        note       = note or "",
        expires    = expiresAt,
        addedBy    = self:GetCurrentCharacterKey(),
    }

    if #self.charDB.profile.players < maxIgnoreLimit then
        C_FriendList.AddIgnore(fullName)
        entry.source = "blizzard"
        table.insert(self.charDB.profile.players, CopyEntry(entry))
    else
        entry.source = "addon"
        table.insert(self.charDB.profile.overLimitPlayers, CopyEntry(entry))
    end

    self:EnsureGlobalPresence(entry, maxIgnoreLimit)

    self:Print(string.format(L["ADD_PLAYER_SUCCESS"] or "Added %s to CrossIgnore.", fullName))

    if CrossIgnoreUI and CrossIgnoreUI:IsShown() then
        self:RefreshBlockedList()
    end
end

function CrossIgnore:maybeMarkPendingRemoval(base, realm, addedBy)
    local myChar = self:GetCurrentCharacterKey()
    if not myChar then return false end
    if addedBy and addedBy ~= myChar then
        local t = self.charDB.profile.settings.useGlobalIgnore and self.globalDB.global.pendingRemovals or self.charDB.profile.pendingRemovals
        table.insert(t, { name = base, server = realm, addedBy = addedBy, markedBy = myChar, markedAt = time() })
        return true
    end
    return false
end

function CrossIgnore:DelIgnore(name)
    local fullName, base, realm = self:NormalizePlayerName(name)
    if not base or realm == nil then return end

    local removedAny = self:RemoveFromAllAddonLists(base, realm)

    for i = 1, C_FriendList.GetNumIgnores() do
        local nameOnList = C_FriendList.GetIgnoreName(i)
        if nameOnList then
            local _, b, r = self:NormalizePlayerName(nameOnList)
            if b == base and r == realm then
                C_FriendList.DelIgnore(nameOnList)
                removedAny = true
                break
            elseif not self.isForever and StripRealm(nameOnList):lower() == base:lower() then
                C_FriendList.DelIgnore(nameOnList)
                removedAny = true
                break
            end
        end
    end

    if removedAny then
        if CrossIgnoreUI and CrossIgnoreUI:IsShown() then self:RefreshBlockedList() end
    end
end

function CrossIgnore:AddOrDelIgnore(name)
    if self:IsPlayerBlocked(name) then
        self:DelIgnore(name)
    else
        self:AddIgnore(name)
    end
    self:RefreshBlockedList()

    if LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsShown() then
        LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel)
    end
end

function CrossIgnore:IsPlayerBlocked(playerName)
    local _, name, server = self:NormalizePlayerName(playerName)
    if not name or server == nil then return false end
    return self:IsPlayerInAnyList(name, server)
end
