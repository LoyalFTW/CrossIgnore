local _, ns = ...
local CrossIgnore = ns.Addon

local UI = ns.UI

UI.State = UI.State or {
    activePanel = "ignoreList",
    ignoreFilterText = "",
    wordFilterText = "",
    selectedPlayer = nil,
    selectedWord = nil,
}
UI.Frames = UI.Frames or {}
