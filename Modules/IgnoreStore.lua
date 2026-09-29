local _, ns = ...
local CrossIgnore = ns.Addon

local Core = ns.CoreInternals
local MakeKey = Core.MakeKey
local CopyEntry = Core.CopyEntry

function CrossIgnore:GetActivePlayerTables()
    if self.charDB.profile.settings.useGlobalIgnore then
        return self.globalDB.global.players, self.globalDB.global.overLimitPlayers or {}
    else
        return self.charDB.profile.players, self.charDB.profile.overLimitPlayers
    end
end

function CrossIgnore:GetAllLists()
    return self.charDB.profile.players,
           self.charDB.profile.overLimitPlayers,
           self.globalDB.global.players,
           self.globalDB.global.overLimitPlayers or {}
end

local function ListHas(list, base, realm)
    if not list then return false end
    for _, p in ipairs(list) do
        if p.name == base and p.server == realm then return true end
    end
    return false
end

function CrossIgnore:IsPlayerInAnyList(base, realm)
    if not base or not realm then return false end
    local c, co, g, go = self:GetAllLists()
    if ListHas(c, base, realm) then return true end
    if ListHas(co, base, realm) then return true end
    if ListHas(g, base, realm) then return true end
    if ListHas(go, base, realm) then return true end
    return false
end

function CrossIgnore:EnsureGlobalPresence(entry, maxIgnoreLimit)
    local g = self.globalDB.global
    g.players = g.players or {}
    g.overLimitPlayers = g.overLimitPlayers or {}

    local key = MakeKey(entry.name, entry.server)

    local function updateIfFound(list)
        for _, p in ipairs(list) do
            if MakeKey(p.name, p.server) == key then
                if entry.note ~= p.note then
                    if (entry.lastModifiedNote or 0) > (p.lastModifiedNote or 0) then
                        p.note = entry.note
                        p.lastModifiedNote = entry.lastModifiedNote or time()
                    else
                        entry.note = p.note
                        entry.lastModifiedNote = p.lastModifiedNote or time()
                    end
                end

                if entry.expires ~= p.expires then
                    if (entry.lastModifiedExpires or 0) > (p.lastModifiedExpires or 0) then
                        p.expires = entry.expires
                        p.lastModifiedExpires = entry.lastModifiedExpires or time()
                    else
                        entry.expires = p.expires
                        entry.lastModifiedExpires = p.lastModifiedExpires or time()
                    end
                end

                if entry.added and (not p.added or entry.added < p.added) then
                    p.added = entry.added
                elseif p.added and (not entry.added or p.added < entry.added) then
                    entry.added = p.added
                end

                if entry.addedBy then p.addedBy = entry.addedBy end
                if entry.firstName then p.firstName = entry.firstName end
                if entry.lastName then p.lastName = entry.lastName end
                if entry.source   then p.source   = entry.source end
                if entry.type     then p.type     = entry.type end
                if entry.ignored ~= nil then p.ignored = entry.ignored end

                return true
            end
        end
        return false
    end

    if updateIfFound(g.players) then return end
    if updateIfFound(g.overLimitPlayers) then return end

    local e = CopyEntry(entry)
    e.lastModifiedNote = e.lastModifiedNote or time()
    e.lastModifiedExpires = e.lastModifiedExpires or time()

    if #g.players < (maxIgnoreLimit or 50) then
        table.insert(g.players, e)
    else
        table.insert(g.overLimitPlayers, e)
    end
end

function CrossIgnore:SyncLocalToGlobal()
    local max = (self.charDB.profile.settings and self.charDB.profile.settings.maxIgnoreLimit) or 50
    self.charDB.profile.players = self.charDB.profile.players or {}
    self.charDB.profile.overLimitPlayers = self.charDB.profile.overLimitPlayers or {}
    self.globalDB.global.players = self.globalDB.global.players or {}
    self.globalDB.global.overLimitPlayers = self.globalDB.global.overLimitPlayers or {}

    for _, entry in ipairs(self.charDB.profile.players) do
        self:EnsureGlobalPresence(entry, max)
    end
    for _, entry in ipairs(self.charDB.profile.overLimitPlayers) do
        self:EnsureGlobalPresence(entry, max)
    end
end

function CrossIgnore:RemoveFromAllAddonLists(base, realm)
    local function removeFromList(list)
        local removed = false
        for i = #list, 1, -1 do
            local p = list[i]
            if p.name == base and p.server == realm then
                if self.maybeMarkPendingRemoval then self:maybeMarkPendingRemoval(base, realm, p.addedBy) end
                table.remove(list, i)
                removed = true
            end
        end
        return removed
    end

    local removed = removeFromList(self.charDB.profile.players)
    removed = removeFromList(self.charDB.profile.overLimitPlayers or {}) or removed
    removed = removeFromList(self.globalDB.global.players or {}) or removed
    removed = removeFromList(self.globalDB.global.overLimitPlayers or {}) or removed
    return removed
end
