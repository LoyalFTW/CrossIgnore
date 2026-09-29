local _, ns = ...
local CrossIgnore = ns.Addon

local currentRealm = not CrossIgnore.isForever and GetNormalizedRealmName() or nil

local function StripRealm(name) return (name and name:match("^[^%-]+")) or name end
local function MakeKey(base, realm) if not base or realm == nil then return nil end return realm ~= "" and (base .. "-" .. realm) or base end
local function ToSafeString(value)
    if value == nil or (canaccessvalue and not canaccessvalue(value)) then
        return nil
    end

    return tostring(value)
end

local function NormalizeRealmToken(value)
    local safeValue = ToSafeString(value)
    if not safeValue then
        return nil
    end

    local realm = strtrim(safeValue)
    if realm == "" then
        return nil
    end

    return realm:gsub("%s+", "")
end

function CrossIgnore:RefreshKnownRealms()
    if self.isForever then
        self.knownRealms = {}
        return self.knownRealms
    end
    local realms, seen = {}, {}

    local function addRealm(value)
        local realm = NormalizeRealmToken(value)
        if not realm or seen[realm] then
            return
        end

        seen[realm] = true
        realms[#realms + 1] = realm
    end

    addRealm(GetNormalizedRealmName and GetNormalizedRealmName() or nil)
    addRealm(GetRealmName and GetRealmName() or nil)

    if type(GetAutoCompleteRealms) == "function" then
        local ok, result1, result2, result3, result4, result5, result6, result7, result8 = pcall(GetAutoCompleteRealms)
        if ok then
            if type(result1) == "table" then
                for _, realm in ipairs(result1) do
                    addRealm(realm)
                end
            else
                addRealm(result1)
                addRealm(result2)
                addRealm(result3)
                addRealm(result4)
                addRealm(result5)
                addRealm(result6)
                addRealm(result7)
                addRealm(result8)
            end
        end
    end

    table.sort(realms, function(a, b)
        return a:lower() < b:lower()
    end)

    self.knownRealms = realms
    return realms
end

function CrossIgnore:GetKnownRealms()
    if not self.knownRealms or #self.knownRealms == 0 then
        return self:RefreshKnownRealms()
    end

    return self.knownRealms
end

function CrossIgnore:NormalizePlayerName(name)
    local safeName = ToSafeString(name)
    if not safeName or safeName == "" then return nil, nil, nil end

    safeName = strtrim(safeName)
    if self.isForever then
        local first, last = safeName:match("^([^%s%-]+)[%s%-]+([^%s%-]+)$")
        if not first then
            first, last = safeName:match("^([^%s%-]+)[%s%-]+([^%s%-]+)%-[^%s%-]+$")
        end
        if not first or not last then return nil, nil, nil end
        local fullName = first .. " " .. last
        return fullName, fullName, ""
    end

    local base, realm = strsplit("-", safeName)
    if not base or base == "" then return nil, nil, nil end
    realm = realm or currentRealm or GetNormalizedRealmName() or "Unknown"
    return base .. "-" .. realm, base, realm
end

local function ShallowCopy(tbl)
    local t = {}
    for k, v in pairs(tbl or {}) do t[k] = v end
    return t
end

local function CopyEntry(entry)
    if CopyTable then return CopyTable(entry) end
    return ShallowCopy(entry)
end

function CrossIgnore:GetUnitPlayerName(unit)
    local firstName, secondName = UnitName(unit)
    if canaccessvalue and (not canaccessvalue(firstName) or not canaccessvalue(secondName)) then return nil end
    if not firstName or firstName == "" or firstName == "Unknown" then return nil end
    if self.isForever then
        if not secondName or secondName == "" then return nil end
        return firstName .. " " .. secondName
    end
    return firstName, secondName
end

function CrossIgnore:GetCurrentCharacterKey()
    local name = self:GetUnitPlayerName("player")
    if not name then return nil end
    if self.isForever then return name end
    local realm = GetNormalizedRealmName()
    return realm and name .. "-" .. realm or nil
end

ns.CoreInternals.StripRealm = StripRealm
ns.CoreInternals.MakeKey = MakeKey
ns.CoreInternals.ToSafeString = ToSafeString
ns.CoreInternals.NormalizeRealmToken = NormalizeRealmToken
ns.CoreInternals.CopyEntry = CopyEntry
