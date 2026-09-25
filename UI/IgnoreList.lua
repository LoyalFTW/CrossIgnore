local addonName, addonTable = ...
local L = addonTable.L
addonTable.UI = addonTable.UI or {}
local UI = addonTable.UI
addonTable.Data = addonTable.Data or {}
local Data = addonTable.Data

local Theme = UI.Theme
local W = UI.Widgets
local TableWidget = UI.TableWidget

local M = {}
UI.IgnoreList = M

local function FormatElapsedTime(added)
  local tsNum = tonumber(added)
  if not tsNum or tsNum == 0 then return L["NA_TEXT"] end
  local elapsed = time() - tsNum
  if elapsed < 0 then elapsed = 0 end
  local days = math.floor(elapsed / 86400)
  local hours = math.floor((elapsed % 86400) / 3600)
  local minutes = math.floor((elapsed % 3600) / 60)
  if days > 0 then
    if hours > 0 then return string.format("%dd %dh", days, hours) end
    return string.format("%dd", days)
  elseif hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  elseif minutes > 0 then
    return string.format("%dm", minutes)
  end
  return L["TIME_HEADER"]
end

local function FormatExpiresTime(expires)
  local tsNum = tonumber(expires)
  if not tsNum or tsNum == 0 then return L["TIME_HEADER2"] end
  local remaining = tsNum - time()
  if remaining <= 0 then return L["TIME_HEADER3"] end
  local days = math.floor(remaining / 86400)
  local hours = math.floor((remaining % 86400) / 3600)
  local minutes = math.floor((remaining % 3600) / 60)
  if days > 0 then
    return string.format("%dd %dh", days, hours)
  elseif hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  elseif minutes > 0 then
    return string.format("%dm", minutes)
  end
  return L["TIME_HEADER4"]
end

local function NoteTooltipOnEnter(cell, entry)
  local noteText = entry.note or entry.notes or ""
  if noteText == "" then return end
  GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["NOTE_HEADER"], 1, 1, 1)
  GameTooltip:AddLine(noteText, nil, nil, nil, true)
  GameTooltip:Show()
end

function M:Build(panel, CrossIgnore)
  self.panel = panel
  self.CrossIgnore = CrossIgnore

  local searchBox = W:CreateEditBox(panel, 425, 24, "TOPLEFT", 15, -10)
  W:AttachPlaceholder(searchBox, L["SEARCH_PLACEHOLDER"])
  searchBox:SetScript("OnTextChanged", function(selfBox)
    local t = selfBox:GetText() or ""
    UI.State.ignoreFilterText = t
    CrossIgnore:RefreshBlockedList(t)
  end)

  local counterLabel = W:CreateLabel(panel, string.format(L["TOTAL_BLOCKED"], 0), "TOPLEFT", 10, -45)
  CrossIgnore.counterLabel = counterLabel

  local accountWideLabel = W:CreateLabel(panel, L["ACCOUNT_WIDE_LABEL"], "TOPRIGHT", -50, -43, "GameFontNormal")
  local accountWideCheckbox = CreateFrame("CheckButton", "CrossIgnoreAccountWideCheckbox", panel, "ChatConfigCheckButtonTemplate")
  accountWideCheckbox:SetPoint("LEFT", accountWideLabel, "RIGHT", 10, 0)
  accountWideCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.useGlobalIgnore)
  accountWideCheckbox:SetScript("OnClick", function(btn)
    CrossIgnore.charDB.profile.settings.useGlobalIgnore = btn:GetChecked()
    CrossIgnore:RefreshBlockedList(UI.State.ignoreFilterText or "")
  end)
  UI.Frames.accountWideCheckbox = accountWideCheckbox

  local columns
  if CrossIgnore.isForever then
    columns = {
      { key="firstName", label=L["FOREVER_FIRST_NAME"] or "First Name", width=100 },
      { key="lastName", label=L["FOREVER_LAST_NAME"] or "Last Name", width=100 },
      { key="added", label=L["ADDED_HEADER"], width=60, format=function(v) return FormatElapsedTime(v) end },
      { key="expires", label=L["EXPIRES_HEADER"], width=60, format=function(v) return FormatExpiresTime(v) end },
      { key="note", label=L["NOTE_HEADER"], width=80, format=function(_, e) return e.note or e.notes or "" end, noWrap=true, maxLines=1, onEnter=NoteTooltipOnEnter },
    }
  else
    columns = {
      { key="name", label=L["PLAYER_NAME_HEADER"], width=100 },
      { key="server", label=L["SERVER_HEADER"], width=80, format=function(_, e) return e.server or e.realm or "" end },
      { key="added", label=L["ADDED_HEADER"], width=60, format=function(v) return FormatElapsedTime(v) end },
      { key="expires", label=L["EXPIRES_HEADER"], width=60, format=function(v) return FormatExpiresTime(v) end },
      { key="note", label=L["NOTE_HEADER"], width=60, format=function(_, e) return e.note or e.notes or "" end, noWrap=true, maxLines=1, onEnter=NoteTooltipOnEnter },
    }
  end

  self.table = TableWidget:New(panel, {
    columns = columns,
    width = 410,
    height = 320 + Theme.header.height,
    defaultSortKey = CrossIgnore.isForever and "firstName" or "name",
    defaultSortAsc = true,
  })
  self.table:GetFrame():SetPoint("TOPLEFT", 10, -70)

  self.table:SetOnSelectionChanged(function(entry)
    UI.State.selectedPlayer = entry
    CrossIgnore.selectedPlayer = entry
  end)

  self.table:SetOnRowRightClick(function(row, entry)
    if CrossIgnore.ShowContextMenu then
      CrossIgnore:ShowContextMenu(row, entry)
    else
      print(L["CONTEXT_NOT_LOADED"])
    end
  end)

  local footer = CreateFrame("Frame", nil, panel)
  footer:SetPoint("BOTTOMLEFT", 10, 8)
  footer:SetPoint("BOTTOMRIGHT", -10, 8)
  footer:SetHeight(34)

  local divider = footer:CreateTexture(nil, "OVERLAY")
  divider:SetPoint("TOPLEFT")
  divider:SetPoint("TOPRIGHT")
  divider:SetHeight(1)
  divider:SetColorTexture(0.35, 0.35, 0.35, 0.6)

  local function RemoveSelectedPlayer()
    local p = UI.State.selectedPlayer or CrossIgnore.selectedPlayer
    if not p or not p.name then
      print(L["NO_PLAYER_SELECTED"])
      return
    end
    local combined = p.name .. (p.server and p.server ~= "" and ("-" .. p.server) or "")
    local fullName = CrossIgnore:NormalizePlayerName(combined)
    CrossIgnore:DelIgnore(fullName)

    UI.State.selectedPlayer = nil
    CrossIgnore.selectedPlayer = nil
    CrossIgnore:RefreshBlockedList(UI.State.ignoreFilterText or "")
  end

  local addPlayerBtn = W:CreateButton(footer, L["ADD_PLAYER_BTN"] or "Add Player", "LEFT", 0, 0, 120, 26, function()
    UI:ShowAddPlayerPopup(CrossIgnore)
  end)

  local removeSelectedBtn = W:CreateButton(footer, L["REMOVE_SELECTED_BTN"], "LEFT", 130, 0, 150, 26, RemoveSelectedPlayer)
  UI.Frames.removePlayerBtn = removeSelectedBtn

  local removeAllBtn = W:CreateButton(footer, L["REMOVE_ALL_BTN"] or "Remove All", "RIGHT", 0, 0, 80, 26, function()
    StaticPopup_Show("CROSSIGNORE_CONFIRM_REMOVE_ALL_PLAYERS")
  end)
  removeAllBtn:GetFontString():SetTextColor(1, 0.45, 0.45)
  removeAllBtn:HookScript("OnEnter", function(selfBtn) selfBtn:GetFontString():SetTextColor(1, 0.25, 0.25) end)
  removeAllBtn:HookScript("OnLeave", function(selfBtn) selfBtn:GetFontString():SetTextColor(1, 0.45, 0.45) end)

  UI.Frames.ignoreSearchBox = searchBox
  UI.Frames.addPlayerBtn = addPlayerBtn
end

function M:Refresh(filterText)
  local CrossIgnore = self.CrossIgnore
  if not self.table or not CrossIgnore then return end

  filterText = filterText or UI.State.ignoreFilterText or ""
  local list = Data.BuildPlayerList(CrossIgnore, filterText)

  if CrossIgnore.counterLabel then
    CrossIgnore.counterLabel:SetText(string.format(L["TOTAL_BLOCKED"], #list))
  end

  local selected = UI.State.selectedPlayer
  self.table:SetData(list)
  if selected then
    self.table:SelectByPredicate(function(entry) return Data.MatchSelectedPlayer(selected, entry) end)
  end
end

return M
