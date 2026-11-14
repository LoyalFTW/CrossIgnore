local addonName, ns = ...
local CrossIgnore = ns.Addon

local Core = ns.CoreInternals
local MakeKey = Core.MakeKey

local REMOVE_TTL_SECONDS = 30 * 86400
local PURGE_BATCH_SIZE = 50

function CrossIgnore:DelayedUpdateIgnoreList()
    if self.updateScheduled then return end
    self.updateScheduled = true
    C_Timer.After(0.5, function()
        self.updateScheduled = false
        self:UpdateIgnoreList()
    end)
end

function CrossIgnore:StartPurgeRemovedIgnores()
    local savedData = self.globalDB and self.globalDB.sv
    if not savedData or not savedData.players then return end
    if self._purgeTicker then return end

    local now = time()
    local cutoff = now - REMOVE_TTL_SECONDS
    local index = #savedData.players

    self._purgeTicker = C_Timer.NewTicker(0.02, function()
        local removed = 0

        while index > 0 and removed < PURGE_BATCH_SIZE do
            local entry = savedData.players[index]

            if entry
               and entry.markedAt
               and entry.markedAt <= cutoff
            then
                table.remove(savedData.players, index)
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
            local _, base, realm = self:NormalizePlayerName(blizzName)

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

function CrossIgnore:RemoveIgnoredPlayer(name)
    local fullName, base, realm = self:NormalizePlayerName(name)
    if not fullName then return false end

    local removed = self:RemoveFromAllAddonLists(fullName, base, realm)
    for i = 1, C_FriendList.GetNumIgnores() do
        local listedName = self:NormalizePlayerName(C_FriendList.GetIgnoreName(i))
        if listedName and strcmputf8i(listedName, fullName) == 0 then
            C_FriendList.DelIgnoreByIndex(i)
            return true
        end
    end
    return removed
end

function CrossIgnore:ProcessPendingRemovals()
    local myChar = self:GetCurrentCharacterKey()
    if not myChar then return end
    local function processList(pendingList)
        for i = #pendingList, 1, -1 do
            local rem = pendingList[i]
            if rem.addedBy == myChar then
                self:RemoveIgnoredPlayer(self:GetStoredIgnoreName(rem))
                table.remove(pendingList, i)
            end
        end
    end
    processList(self.charDB.profile.pendingRemovals)
    processList(self.globalDB.global.pendingRemovals)
end

function CrossIgnore:CheckExpiredIgnores()
    local now = time()
    local expired, seen = {}, {}
    local function CollectExpired(list)
        for _, entry in ipairs(list) do
            if entry.expires and entry.expires > 0 and entry.expires <= now then
                local fullName = self:GetStoredIgnoreName(entry)
                if fullName and not seen[fullName] then
                    seen[fullName] = true
                    expired[#expired + 1] = fullName
                end
            end
        end
    end
    local players, overLimitPlayers, globalPlayers, globalOverLimitPlayers = self:GetAllLists()
    CollectExpired(players)
    CollectExpired(overLimitPlayers)
    CollectExpired(globalPlayers)
    CollectExpired(globalOverLimitPlayers)

    for _, fullName in ipairs(expired) do
        self:RemoveIgnoredPlayer(fullName)
    end
    if #expired > 0 then self:RefreshBlockedList() end
end
