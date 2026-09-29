local _, ns = ...
local UI = ns.UI

local W = {}
UI.Widgets = W

function W:CreateLabel(parent, text, point, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint(point, x or 0, y or 0)
    fs:SetText(text or "")
    return fs
end

function W:CreateButton(parent, text, point, x, y, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 80, height or 22)
    btn:SetPoint(point, x or 0, y or 0)
    btn:SetText(text or "")
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

function W:CreateEditBox(parent, width, height, point, x, y, template)
    local box = CreateFrame("EditBox", nil, parent, template or "InputBoxTemplate")
    box:SetSize(width or 200, height or 24)
    box:SetPoint(point, x or 0, y or 0)
    box:SetAutoFocus(false)
    box:SetText("")
    return box
end

function W:AttachPlaceholder(editBox, placeholderText)
    local ph = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", editBox, "LEFT", 6, 0)
    ph:SetText(placeholderText or "")
    ph:EnableMouse(false)

    local function refresh()
        local t = editBox:GetText() or ""
        if t == "" and not editBox:HasFocus() then
            ph:Show()
        else
            ph:Hide()
        end
    end

    editBox:HookScript("OnTextChanged", refresh)
    editBox:HookScript("OnEditFocusGained", refresh)
    editBox:HookScript("OnEditFocusLost", refresh)
    refresh()
    return ph
end

function W:CreateScrollFrame(parent, width, height, point, x, y)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetSize(width or 300, height or 300)
    sf:SetPoint(point, x or 0, y or 0)

    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(width or 300, height or 300)
    sf:SetScrollChild(child)

    return sf, child
end

return W
