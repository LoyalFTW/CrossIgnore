local _, ns = ...
local ChatFilter = ns.Addon.ChatFilter

local function ContainsEastAsianText(text)
    for sequence in text:gmatch("[\194-\244][\128-\191]+") do
        local a, b, c, d = sequence:byte(1, 4)
        local codepoint
        if a < 224 and #sequence == 2 then
            codepoint = (a - 192) * 64 + b - 128
        elseif a < 240 and #sequence == 3 then
            codepoint = (a - 224) * 4096 + (b - 128) * 64 + c - 128
        elseif a >= 240 and #sequence == 4 then
            codepoint = (a - 240) * 262144 + (b - 128) * 4096 + (c - 128) * 64 + d - 128
        end
        if codepoint and (
            (codepoint >= 0x1100 and codepoint <= 0x11FF)
            or (codepoint >= 0x2E80 and codepoint <= 0x2FDF)
            or (codepoint >= 0x3040 and codepoint <= 0x312F)
            or (codepoint >= 0x3130 and codepoint <= 0x318F)
            or (codepoint >= 0x31A0 and codepoint <= 0x31BF)
            or (codepoint >= 0x31F0 and codepoint <= 0x31FF)
            or (codepoint >= 0x3400 and codepoint <= 0x4DBF)
            or (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
            or (codepoint >= 0xA960 and codepoint <= 0xA97F)
            or (codepoint >= 0xAC00 and codepoint <= 0xD7AF)
            or (codepoint >= 0xD7B0 and codepoint <= 0xD7FF)
            or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
            or (codepoint >= 0xFF66 and codepoint <= 0xFFDC)
            or (codepoint >= 0x20000 and codepoint <= 0x323AF)
        ) then return true end
    end
    return false
end

ChatFilter.ContainsEastAsianText = ContainsEastAsianText

ChatFilter.presets = {
    { id = "nonLatin", label = "FILTER_PRESET_NON_LATIN", expression = "[nonlatin]" },
    { id = "guildRecruitment", label = "FILTER_PRESET_GUILD", expression = "(([contains=guild] or [guild] or [guildname]) and ([contains=recruit] or [contains=looking for] or [contains=seeking] or [contains=join us] or [contains=apply] or [contains=members])) or (([guild] or [guildname]) and ([contains=raid] or [contains=progress] or [contains=mythic]))" },
    { id = "communityRecruitment", label = "FILTER_PRESET_COMMUNITY", expression = "[community] or (([contains=community] or [contains=communities]) and ([contains=recruit] or [contains=looking for] or [contains=seeking] or [contains=join us] or [contains=apply] or [contains=members]))" },
    { id = "boostSellers", label = "FILTER_PRESET_BOOST",
        previousExpression = "([word=wts] or [contains=selling] or [contains=sell] or [contains=offer] or [contains=cheap] or [contains=starting]) and ([contains=m+] or [contains=boost] or [contains=carry] or [contains=raid] or [contains=mythic] or [contains=keys])",
        expression = "([word=wts] or [contains=selling] or [contains=sell] or [contains=offer] or [contains=cheap] or [contains=starting] or [contains=buyers] or [contains=buyer only] or [contains=pay in raid] or [contains=armor stack] or [contains=armour stack] or [contains=free specific key] or [contains=gold only] or [contains=gold-only]) and ([contains=m+] or [contains=boost] or [contains=carry] or [contains=raid] or [contains=mythic] or [contains=keys] or [contains=keystone] or [contains=heroic] or [word=ksm] or [word=ksh] or [word=ksl])" },
    { id = "craftingSellers", label = "FILTER_PRESET_CRAFTING", expression = "([contains=lfw] or [contains=craft] or [contains=order] or [contains=mats] or [contains=tip]) and ([trade] or [item] or [word=lfw] or [word=wts])" },
    { id = "levelingSellers", label = "FILTER_PRESET_LEVELING", expression = "([word=wts] or [contains=service] or [contains=sell] or [contains=fast] or [contains=afk]) and ([contains=power] or [contains=pwr]) and ([contains=level] or [contains=lvl])" },
}

function ChatFilter:GetRuleStore()
    if not CrossIgnoreDB then return { rules = {}, counts = {}, history = {} } end
    self:GetFilters()
    local filters = CrossIgnoreDB.global.filters
    filters.ruleStore = filters.ruleStore or { rules = {}, counts = {}, history = {}, nextID = 1 }
    local store = filters.ruleStore
    store.rules = store.rules or {}
    store.counts = store.counts or {}
    store.history = store.history or {}
    filters.presets = filters.presets or {}
    for _, preset in ipairs(self.presets) do
        if filters.presets[preset.id] == nil then filters.presets[preset.id] = false end
        if store.rules[preset.id] == nil then
            store.rules[preset.id] = { id = preset.id, expression = preset.expression, enabled = filters.presets[preset.id] == true }
        elseif preset.previousExpression and store.rules[preset.id].expression == preset.previousExpression then
            store.rules[preset.id].expression = preset.expression
        end
    end
    return store
end

function ChatFilter:GetRuleList()
    local store = self:GetRuleStore()
    local list, known = {}, {}
    for _, preset in ipairs(self.presets) do
        known[preset.id] = true
        local rule = store.rules[preset.id]
        if rule and not rule.deleted then
            list[#list + 1] = { id = rule.id, name = rule.name or ns.L[preset.label], expression = rule.expression,
                enabled = rule.enabled == true, count = store.counts[rule.id] or 0, default = true }
        end
    end
    local custom = {}
    for id, rule in pairs(store.rules) do
        if not known[id] and not rule.deleted then
            custom[#custom + 1] = { id = id, name = rule.name, expression = rule.expression,
                enabled = rule.enabled == true, count = store.counts[id] or 0 }
        end
    end
    table.sort(custom, function(a, b) return a.id < b.id end)
    for _, rule in ipairs(custom) do list[#list + 1] = rule end
    return list
end

function ChatFilter:GetPresetSettings()
    local settings = {}
    for _, rule in ipairs(self:GetRuleList()) do settings[rule.id] = rule.enabled end
    return settings
end

function ChatFilter:SetPresetEnabled(id, enabled)
    local rule = self:GetRuleStore().rules[id]
    if not rule or rule.deleted then return end
    rule.enabled = enabled and true or false
    CrossIgnoreDB.global.filters.presets[id] = rule.enabled
    self:UpdateEventRegistration()
    if self.OnRulesChanged then self.OnRulesChanged() end
end

function ChatFilter:SaveRule(id, name, expression, enabled)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil, "Enter a filter name." end
    local compiled, err = self:CompileRule(expression)
    if not compiled then return nil, err end
    local store = self:GetRuleStore()
    if not id then
        local total = 0
        for _ in pairs(store.rules) do total = total + 1 end
        if total >= 128 then return nil, "The limit is 128 filters." end
        store.nextID = store.nextID or 1
        repeat
            id = "custom" .. store.nextID
            store.nextID = store.nextID + 1
        until not store.rules[id]
    elseif not store.rules[id] then
        return nil, "Filter not found."
    end
    store.rules[id] = { id = id, name = name:sub(1, 120), expression = expression, enabled = enabled and true or false }
    CrossIgnoreDB.global.filters.presets[id] = enabled and true or false
    self:UpdateEventRegistration()
    if self.OnRulesChanged then self.OnRulesChanged() end
    return id
end

function ChatFilter:RemoveRule(id)
    local store = self:GetRuleStore()
    if not store.rules[id] then return end
    for _, preset in ipairs(self.presets) do
        if preset.id == id then
            store.rules[id].deleted = true
            store.rules[id].enabled = false
            CrossIgnoreDB.global.filters.presets[id] = false
            self:UpdateEventRegistration()
            if self.OnRulesChanged then self.OnRulesChanged() end
            return
        end
    end
    store.rules[id] = nil
    CrossIgnoreDB.global.filters.presets[id] = nil
    self:UpdateEventRegistration()
    if self.OnRulesChanged then self.OnRulesChanged() end
end

function ChatFilter:RestoreDefaultRule(id)
    for _, preset in ipairs(self.presets) do
        if preset.id == id then
            return self:SaveRule(id, ns.L[preset.label], preset.expression, false)
        end
    end
end

function ChatFilter:HasEnabledPresets()
    self.activeRules = {}
    for _, rule in ipairs(self:GetRuleList()) do
        if rule.enabled and self:CompileRule(rule.expression) then
            self.activeRules[#self.activeRules + 1] = rule
        end
    end
    return #self.activeRules > 0
end

function ChatFilter:MatchPreset(message)
    if type(message) ~= "string" then return nil end
    if not self.activeRules then self:HasEnabledPresets() end
    for _, rule in ipairs(self.activeRules) do
        if self:TestRule(rule.expression, message) == true then
            return rule.name, rule.id, rule.expression
        end
    end
    return nil
end

function ChatFilter:RecordBlockedMessage(entry, ruleID)
    local store = self:GetRuleStore()
    entry.ruleID = ruleID or ("word:" .. entry.channel .. ":" .. entry.word)
    store.counts[entry.ruleID] = (store.counts[entry.ruleID] or 0) + 1
    table.insert(store.history, 1, entry)
    if #store.history > 200 then table.remove(store.history) end
    if self.OnRulesChanged then self.OnRulesChanged() end
end

function ChatFilter:GetBlockHistory(ruleID)
    local history = self:GetRuleStore().history
    if not ruleID then return history end
    local entries = {}
    for _, entry in ipairs(history) do
        if entry.ruleID == ruleID then entries[#entries + 1] = entry end
    end
    return entries
end
