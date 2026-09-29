local _, ns = ...
local UI = ns.UI
local Theme = UI.Theme
local W = UI.Widgets

local TableWidget = {}
TableWidget.__index = TableWidget
UI.TableWidget = TableWidget

local function SafeLower(s)
    if type(s) ~= "string" then return "" end
    return s:lower()
end

function TableWidget:New(parent, opts)
    local o = setmetatable({}, self)
    o.parent = parent
    o.opts = opts or {}
    o.columns = assert(o.opts.columns, "TableWidget requires columns")
    o.rowHeight = o.opts.rowHeight or Theme.row.height
    o.width = o.opts.width or 420
    o.height = o.opts.height or 340

    o.sortKey = o.opts.defaultSortKey or (o.columns[1] and o.columns[1].key) or "name"
    o.sortAsc = (o.opts.defaultSortAsc ~= false)

    o.rowPool = {}
    o.activeRows = {}
    o.data = {}
    o.selected = nil

    o.frame = CreateFrame("Frame", nil, parent)
    o.frame:SetSize(o.width, o.height)

    o.header = CreateFrame("Frame", nil, o.frame)
    o.header:SetPoint("TOPLEFT", 0, 0)
    o.header:SetSize(o.width, Theme.header.height)

    o.header.bg = o.header:CreateTexture(nil, "BACKGROUND")
    o.header.bg:SetAllPoints()
    o.header.bg:SetColorTexture(unpack(Theme.header.bg))

    o.header.border = o.header:CreateTexture(nil, "OVERLAY")
    o.header.border:SetPoint("BOTTOMLEFT")
    o.header.border:SetPoint("BOTTOMRIGHT")
    o.header.border:SetHeight(1)
    o.header.border:SetColorTexture(unpack(Theme.header.border))

    o.header.cols = {}
    o:_BuildHeader()

    o.scrollFrame, o.scrollChild = W:CreateScrollFrame(o.frame, o.width, o.height - Theme.header.height, "TOPLEFT", 0, -Theme.header.height)
    o.scrollFrame:SetPoint("TOPLEFT", 0, -Theme.header.height)

    return o
end

function TableWidget:GetFrame()
    return self.frame
end

function TableWidget:SetOnRowLeftClick(fn) self.onRowLeftClick = fn end
function TableWidget:SetOnRowRightClick(fn) self.onRowRightClick = fn end
function TableWidget:SetOnSelectionChanged(fn) self.onSelectionChanged = fn end

function TableWidget:SetSort(key, asc)
    if key then self.sortKey = key end
    if asc ~= nil then self.sortAsc = asc end
    self:Refresh()
end

function TableWidget:SetData(data)
    self.data = data or {}
    self:Refresh()
end

function TableWidget:SelectByPredicate(pred)
    if type(pred) ~= "function" then return end
    for _, row in ipairs(self.activeRows) do
        if row.entry and pred(row.entry) then
            self:_SelectRow(row)
            break
        end
    end
end

function TableWidget:_BuildHeader()
    local x = 0
    for i, col in ipairs(self.columns) do
        local w = col.width or 100
        local btn = CreateFrame("Button", nil, self.header)
        btn:SetSize(w, Theme.header.height)
        btn:SetPoint("LEFT", x, 0)

        local fs = btn:CreateFontString(nil, "OVERLAY", Theme.header.font)
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", Theme.row.padX, 0)
        fs:SetJustifyH("LEFT")

        fs:SetText(col.label or col.key or ("Col"..i))
        fs:SetTextColor(Theme.header.text[1], Theme.header.text[2], Theme.header.text[3], Theme.header.text[4])
        btn.text = fs

        local key = col.key
        btn:SetScript("OnEnter", function()
            fs:SetTextColor(unpack(Theme.header.hover))
        end)

        btn:SetScript("OnLeave", function()
            if self.sortKey == key then
                fs:SetTextColor(unpack(Theme.header.active))
            else
                fs:SetTextColor(unpack(Theme.header.text))
            end
        end)

        btn:SetScript("OnClick", function()
            if not key then return end
            if self.sortKey == key then
                self.sortAsc = not self.sortAsc
            else
                self.sortKey = key
                self.sortAsc = true
            end
            self:Refresh()
        end)

        self.header.cols[i] = btn
        x = x + w
    end
end

function TableWidget:_UpdateHeaderColors()
    for _, btn in ipairs(self.header.cols) do
        local colKey = nil
    end
    for i, btn in ipairs(self.header.cols) do
        local key = self.columns[i] and self.columns[i].key
        if key and self.sortKey == key then
            btn.text:SetTextColor(unpack(Theme.header.active))
        else
            btn.text:SetTextColor(unpack(Theme.header.text))
        end
    end
end

local function compareValues(sortKey, a, b)
    local va = a[sortKey]
    local vb = b[sortKey]
    if sortKey == "added" or sortKey == "expires" then
        va = tonumber(va) or 0
        vb = tonumber(vb) or 0
        return va, vb, true
    end
    va = SafeLower(va)
    vb = SafeLower(vb)
    return va, vb, false
end

function TableWidget:_SortData()
    local key = self.sortKey
    if not key then return end
    table.sort(self.data, function(a, b)
        local va, vb = compareValues(key, a, b)
        if self.sortAsc then
            return va < vb
        else
            return va > vb
        end
    end)
end

function TableWidget:_AcquireRow()
    local row = table.remove(self.rowPool)
    if row then
        row:Show()
        return row
    end

    row = CreateFrame("Button", nil, self.scrollChild)
    row:SetHeight(self.rowHeight)
    row:SetWidth(self.width)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.cells = {}
    local x = 0

    for i, col in ipairs(self.columns) do
        local w = col.width or 100

        if col.type == "check" then
            local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            cb:SetSize(20, 20)
            cb:SetPoint("LEFT", x + (col.padX or 10), 0)
            row.cells[i] = cb
        else
            local fs = row:CreateFontString(nil, "OVERLAY", Theme.row.font)
            fs:SetPoint("LEFT", x + Theme.row.padX, 0)
            fs:SetWidth(w - (Theme.row.padX * 2))
            fs:SetJustifyH(col.justifyH or "LEFT")
            if col.maxLines then fs:SetMaxLines(col.maxLines) end
            if col.noWrap then
                fs:SetWordWrap(false)
                fs:SetNonSpaceWrap(false)
            end
            row.cells[i] = fs
        end

        x = x + w
    end

    row:SetScript("OnEnter", function(selfRow)
        selfRow.bg:SetColorTexture(unpack(Theme.row.hover))
    end)

    row:SetScript("OnLeave", function(selfRow)
        if self.selected == selfRow then
            selfRow.bg:SetColorTexture(unpack(Theme.row.select))
        else
            local c = (selfRow.alt and Theme.row.alt) or Theme.row.normal
            selfRow.bg:SetColorTexture(unpack(c))
        end
    end)

    row:SetScript("OnClick", function(selfRow, button)
        if button == "LeftButton" then
            self:_SelectRow(selfRow)
            if self.onRowLeftClick then self.onRowLeftClick(selfRow, selfRow.entry) end
        elseif button == "RightButton" then
            self:_SelectRow(selfRow)
            if self.onRowRightClick then self.onRowRightClick(selfRow, selfRow.entry) end
        end
    end)

    return row
end

function TableWidget:_ReleaseAllRows()
    for _, row in ipairs(self.activeRows) do
        row:Hide()
        row.entry = nil
        table.insert(self.rowPool, row)
    end
    wipe(self.activeRows)
end

function TableWidget:_SelectRow(row)
    if self.selected and self.selected ~= row then
        local old = self.selected
        local c = (old.alt and Theme.row.alt) or Theme.row.normal
        old.bg:SetColorTexture(unpack(c))
    end
    self.selected = row
    if row then row.bg:SetColorTexture(unpack(Theme.row.select)) end
    if self.onSelectionChanged then self.onSelectionChanged(row and row.entry or nil) end
end

function TableWidget:Refresh()
    self:_UpdateHeaderColors()
    self:_ReleaseAllRows()
    self:_SortData()

    local y = 0
    for idx, entry in ipairs(self.data) do
        local row = self:_AcquireRow()
        row.entry = entry
        row.alt = (idx % 2 == 0)
        local c = (row.alt and Theme.row.alt) or Theme.row.normal
        if self.selected and self.selected.entry == entry then
            row.bg:SetColorTexture(unpack(Theme.row.select))
            self.selected = row
        else
            row.bg:SetColorTexture(unpack(c))
        end

        for i, col in ipairs(self.columns) do
            local cell = row.cells[i]
            if col.type == "check" then
                local val = entry[col.key] and true or false
                cell:SetChecked(val)
                cell:EnableMouse(true)

                if col.tooltipTitle or col.tooltipText then
                    cell:SetScript("OnEnter", function(selfCB)
                        GameTooltip:SetOwner(selfCB, "ANCHOR_RIGHT")
                        if col.tooltipTitle then GameTooltip:AddLine(col.tooltipTitle, 1, 1, 1) end
                        if col.tooltipText then GameTooltip:AddLine(col.tooltipText, nil, nil, nil, true) end
                        GameTooltip:Show()
                    end)
                    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
                else
                    cell:SetScript("OnEnter", nil)
                    cell:SetScript("OnLeave", nil)
                end

                cell:SetScript("OnClick", function(selfCB)
                    local newVal = selfCB:GetChecked() and true or false
                    entry[col.key] = newVal
                    if col.onToggle then col.onToggle(entry, newVal, row) end
                end)
            else
                local raw = entry[col.key]
                local txt = raw
                if col.format then
                    txt = col.format(raw, entry)
                end
                cell:SetText(txt or "")
                if col.onEnter then
                    cell:SetScript("OnEnter", function() col.onEnter(cell, entry) end)
                    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
                else
                    cell:SetScript("OnEnter", nil)
                    cell:SetScript("OnLeave", nil)
                end
            end
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(self.width)
        row:Show()

        self.activeRows[#self.activeRows + 1] = row
        y = y + self.rowHeight
    end

    self.scrollChild:SetHeight(math.max(y + 10, self.height - Theme.header.height))
end

return TableWidget
