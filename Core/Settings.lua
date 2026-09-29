local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

local options = {
    name = "CrossIgnore",
    handler = CrossIgnore,
    type = "group",
    args = {
        ui = {
            name = L["OPEN_UI"],
            desc = L["OPEN_UI_DESC"],
            type = "execute",
            func = function() CrossIgnore:ToggleGUI() end,
        },
        useGlobalIgnore = {
            type = "toggle",
            name = L["USE_GLOBAL_IGNORE"],
            desc = L["USE_GLOBAL_IGNORE_DESC"],
            get = function() return CrossIgnore.db.profile.settings.useGlobalIgnore end,
            set = function(_, value) CrossIgnore.db.profile.settings.useGlobalIgnore = value end,
        },
        showMinimapIcon = {
            type = "toggle",
            name = L["SHOW_MINIMAP_ICON"],
            desc = L["SHOW_MINIMAP_ICON_DESC"],
            get = function()
                return not CrossIgnore.iconDB.profile.minimap.hide
            end,
            set = function(_, value)
                CrossIgnore.iconDB.profile.minimap.hide = not value
                if value then
                    LibStub("LibDBIcon-1.0"):Show("CrossIgnore")
                else
                    LibStub("LibDBIcon-1.0"):Hide("CrossIgnore")
                end
            end,
        },
    },
}

ns.Options = options
