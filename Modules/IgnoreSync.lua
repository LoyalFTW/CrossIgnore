local addonName, ns = ...
local CrossIgnore = ns.Addon

local Core = ns.CoreInternals
local StripRealm = Core.StripRealm
local MakeKey = Core.MakeKey

function CrossIgnore:DelayedUpdateIgnoreList()
    if self.updateScheduled then return end
    self.updateScheduled = true
    C_Timer.After(0.5, function()
        self.updateScheduled = false
        self:UpdateIgnoreList()
    end)
end

function CrossIgnore:StartPurgeRemovedIgnores()
    if not CrossIgnoreDB or not CrossIgnoreDB.players then return end
    if self._purgeTicker then return end

    local now = time()
    local cutoff = now - REMOVE_TTL_SECONDS
    local index = #CrossIgnoreDB.players

    self._purgeTicker = C_Timer.NewTicker(0.02, function()
        local removed = 0

        while index > 0 and removed < PURGE_BATCH_SIZE do
            local entry = CrossIgnoreDB.players[index]

            if entry
               and entry.markedAt
               and entry.markedAt <= cutoff
            then
                table.remove(CrossIgnoreDB.players, index)
                removed = removed + 1
            end

            index = index - 1
        end

        if index <= 0 then
            self._purgeTicker:Cancel()
            self._purgeTicker = nil
        end
    end)
end

function CrossIgnore:GetBlizzardIgnoreSet()
    local ignoreSet = {}
    local numIgnored = C_FriendList.GetNumIgnores()
    for i = 1, numIgnored do
        local playerName = C_FriendList.GetIgnoreName(i)
        if playerName then
            local _, name, server = self:NormalizePlayerName(playerName)
            if name and server ~= nil then ignoreSet[MakeKey(name, server)] = true end
        end
    end
    return ignoreSet
end

function CrossIgnore:GetAddonIgnoreSet()
    local addonSet = {}
    for _, player in ipairs(self.charDB.profile.players) do
        if player.name and player.server then
            addonSet[MakeKey(player.name, player.server)] = true
        end
    end
    return addonSet
end

function CrossIgnore:UpdateIgnoreList()
    local blizzSet = self:GetBlizzardIgnoreSet()
    local addonSet = self:GetAddonIgnoreSet()
    local changed = false

    for blizzName in pairs(blizzSet) do
        if not addonSet[blizzName] then changed = true break end
    end
    if not changed then
        for addonName in pairs(addonSet) do
            if not blizzSet[addonName] then changed = true break end
        end
    end

    if not changed then
        self:SyncLocalToGlobal()
        self:RefreshBlockedList()
        return
    end

    local list = self.charDB.profile.players

    for blizzName in pairs(blizzSet) do
        if not addonSet[blizzName] then
            local base, realm
            if self.isForever then
                base, realm = blizzName, ""
            else
                base, realm = strsplit("-", blizzName)
            end

            local existingNote, existingExpires = "", 0

            for _, existing in ipairs(list) do
                if existing.name == base and existing.server == realm then
                    if existing.note ~= nil then existingNote = existing.note end
                    if existing.expires ~= nil then existingExpires = existing.expires end
                    break
                end
            end

            if (existingNote == "" or existingExpires == 0)
            and self.globalDB and self.globalDB.global and self.globalDB.global.players then
                for _, existing in ipairs(self.globalDB.global.players) do
                    if existing.name == base and existing.server == realm then
                        if existing.note ~= nil then existingNote = existing.note end
                        if existing.expires ~= nil then existingExpires = existing.expires end
                        break
                    end
                end
            end

            if existingExpires == 0 then
                local defaultDays = self.charDB.profile.settings.defaultExpireDays or 0
                if defaultDays > 0 then
                    existingExpires = time() + (defaultDays * 86400)
                end
            end

            local entry = {
                name     = base,
                server   = realm,
                firstName = self.isForever and base:match("^(%S+)") or nil,
                lastName = self.isForever and base:match("^%S+%s+(%S+)$") or nil,
                added    = time(),
                ignored  = true,
                source   = "blizzard",
                type     = "player",
                note     = existingNote,
                expires  = existingExpires,
                addedBy  = self:GetCurrentCharacterKey(),
            }

            table.insert(list, entry)

            self:EnsureGlobalPresence(entry, self.charDB.profile.settings.maxIgnoreLimit or 50)
        end
    end

    self:SyncLocalToGlobal()
    self:RefreshBlockedList()
end

function CrossIgnore:ProcessPendingRemovals()
    local myChar = self:GetCurrentCharacterKey()
    if not myChar then return end
    local function processList(pendingList)
        for i = #pendingList, 1, -1 do
            local rem = pendingList[i]
            if rem.addedBy == myChar then
                self:RemoveFromAllAddonLists(rem.name, rem.server)
                for j = 1, C_FriendList.GetNumIgnores() do
                    local nameOnList = C_FriendList.GetIgnoreName(j)
                    local _, listedName, listedRealm = self:NormalizePlayerName(nameOnList)
                    if nameOnList and ((listedName == rem.name and listedRealm == rem.server) or (not self.isForever and StripRealm(nameOnList) == rem.name)) then
                        C_FriendList.DelIgnore(nameOnList)
                        break
                    end
                end
                table.remove(pendingList, i)
            end
        end
    end
    processList(self.charDB.profile.pendingRemovals)
    processList(self.globalDB.global.pendingRemovals)
end

function CrossIgnore:CheckExpiredIgnores()
    local now = time()
    local function CheckAndRemove(list)
        for i = #list, 1, -1 do
            local entry = list[i]
            if entry.expires and entry.expires > 0 and entry.expires <= now then
                local base, realm = entry.name, entry.server
                self:RemoveFromAllAddonLists(base, realm)
                for j = 1, C_FriendList.GetNumIgnores() do
                    local nameOnList = C_FriendList.GetIgnoreName(j)
                    local _, listedName, listedRealm = self:NormalizePlayerName(nameOnList)
                    if nameOnList and ((listedName == base and listedRealm == realm) or (not self.isForever and StripRealm(nameOnList) == base)) then
                        C_FriendList.DelIgnore(nameOnList)
                        break
                    end
                end
            end
        end
    end
    CheckAndRemove(self.charDB.profile.players)
    CheckAndRemove(self.charDB.profile.overLimitPlayers)
    CheckAndRemove(self.globalDB.global.players)
    self:RefreshBlockedList()
end
