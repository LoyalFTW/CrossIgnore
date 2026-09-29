local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("CrossIgnore", {
    type = "data source",
    text = "CrossIgnore",
    icon = "Interface\\AddOns\\CrossIgnore\\Media\\icon",
    OnClick = function(_, button)
        if button == "LeftButton" then CrossIgnore:ToggleGUI() end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("CrossIgnore")
        tooltip:AddLine(L["LEFT_CLICK_OPEN_UI"], 1, 1, 1)
    end,
})

function CrossIgnore:InitMinimap()
    self.iconDB = LibStub("AceDB-3.0"):New("CrossIgnoreMinimapDB", {
        profile = { minimap = { hide = false } }
    })

    LibStub("LibDBIcon-1.0"):Register("CrossIgnore", LDB, self.iconDB.profile.minimap)
end
