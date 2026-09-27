local addonName, addonTable = ...
local L = addonTable.L
addonTable.UI = addonTable.UI or {}
local UI = addonTable.UI
addonTable.Data = addonTable.Data or {}
local Data = addonTable.Data

local W = UI.Widgets
local Theme = UI.Theme
local TableWidget = UI.TableWidget

local M = {}
UI.WordFilter = M

local function safeString(value)
  return type(value) == "string" and value or ""
end

local function CapitalizeWords(str)
  str = safeString(str)
  return (str:gsub("(%a)([%w_']*)", function(first, rest)
    return first:upper() .. rest:lower()
  end))
end

local function UpdateChannelDropdown(CrossIgnoreDB)
  local channelList = {
    L["CHANNEL_ALL"],
    L["CHANNEL_SAY"], L["CHANNEL_YELL"], L["CHANNEL_WHISPER"],
    L["CHANNEL_GUILD"], L["CHANNEL_OFFICER"],
    L["CHANNEL_PARTY"], L["CHANNEL_RAID"], L["CHANNEL_INSTANCE"],
  }

  local channels = { GetChannelList() }
  local seen = {}
  for i = 1, #channels, 3 do
    local channelNumber = channels[i]
    if channelNumber then
      local name, displayName = GetChannelName(channelNumber)
      local finalName = (type(name) == "string" and name) or displayName
      if finalName then
        local clean = finalName:gsub("^%d+%.%s*", "")
        if not seen[clean:lower()] then
          channelList[#channelList+1] = clean
          seen[clean:lower()] = true
        end
      end
    end
  end
  return channelList
end

local function CreateChannelDropdown(parent, CrossIgnoreDB, onChanged)
  if Menu and MenuUtil then
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(185, 25)
    dropdown:SetDefaultText(L["CHANNEL_ALL"])
    dropdown:SetupMenu(function(_, rootDescription)
      for _, channel in ipairs(UpdateChannelDropdown(CrossIgnoreDB)) do
        rootDescription:CreateRadio(channel, function(value)
          return (CrossIgnoreDB.selectedChannel or L["CHANNEL_ALL"]) == value
        end, function(value)
          CrossIgnoreDB.selectedChannel = value
          if onChanged then onChanged(value) end
        end, channel)
      end
    end)
    return dropdown
  end

  local dropdown = CreateFrame("Frame", "CrossIgnoreChannelDropdown", parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dropdown, 200)

  local function OnClick(self)
    CrossIgnoreDB.selectedChannel = self.value
    UIDropDownMenu_SetSelectedValue(dropdown, self.value)
    UIDropDownMenu_SetText(dropdown, self.value)
    ToggleDropDownMenu(1, nil, dropdown)
    ToggleDropDownMenu(1, nil, dropdown)
    if onChanged then onChanged(self.value) end
  end

  UIDropDownMenu_Initialize(dropdown, function(self, level)
    if level ~= 1 then return end
    local channels = UpdateChannelDropdown(CrossIgnoreDB)
    local selectedChannel = CrossIgnoreDB.selectedChannel or L["CHANNEL_ALL"]
    for _, channel in ipairs(channels) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = channel
      info.value = channel
      info.func = OnClick
      info.checked = (channel == selectedChannel)
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  UIDropDownMenu_SetSelectedValue(dropdown, CrossIgnoreDB.selectedChannel or L["CHANNEL_ALL"])
  UIDropDownMenu_SetText(dropdown, CrossIgnoreDB.selectedChannel or L["CHANNEL_ALL"])
  return dropdown
end

function M:Build(panel, CrossIgnore, CrossIgnoreDB)
  self.panel = panel
  self.CrossIgnore = CrossIgnore
  self.CrossIgnoreDB = CrossIgnoreDB

  local searchBox = W:CreateEditBox(panel, 425, 24, "TOPLEFT", 15, -10)
  W:AttachPlaceholder(searchBox, L["SEARCH_PLACEHOLDER"])
  searchBox:SetScript("OnTextChanged", function(selfBox)
    local t = selfBox:GetText() or ""
    UI.State.wordFilterText = t
    CrossIgnore:UpdateWordsList(t)
  end)

  local columns = {
    { key="word",    label=L["BANNED_WORDS_HEADER2"], width=180 },
    { key="channel", label=L["CHAT_TYPE_HEADER"],     width=140, format=function(v) return CapitalizeWords(v) end },
    { key="strict",  label=L["STRICT_BAN_HEADER"],    width=80, type="check",
      tooltipTitle=L["STRICT_BAN_HEADER"],
      tooltipText=L["STRICT_BAN_TOOLTIP_TEXT"],
      onToggle=function(entry, newVal)
        local db = CrossIgnoreDB
        if entry and db and db.global and db.global.filters and db.global.filters.words then
          local channelTable = db.global.filters.words[entry.channelName]
          if channelTable and channelTable[entry.wordIndex] then
            if type(channelTable[entry.wordIndex]) == "table" then
              channelTable[entry.wordIndex].strict = newVal
            else
              local existingWord = safeString(channelTable[entry.wordIndex])
              channelTable[entry.wordIndex] = {
                word = existingWord,
                normalized = existingWord:lower(),
                strict = newVal
              }
            end
          end
        end
        if CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.SetWordStrict then
          CrossIgnore.ChatFilter:SetWordStrict(entry.word, entry.channelName, newVal)
        end
      end
    },
  }

  self.table = TableWidget:New(panel, {
    columns = columns,
    width = 410,
    height = 320 + Theme.header.height,
    defaultSortKey = "word",
    defaultSortAsc = true,
  })
  self.table:GetFrame():SetPoint("TOPLEFT", 10, -45)

  self.table:SetOnSelectionChanged(function(entry)
    UI.State.selectedWord = entry
    CrossIgnore.selectedWord = entry
  end)

  self.table:SetOnRowRightClick(function(row, entry)
    if CrossIgnore.ShowWordContextMenu then
      CrossIgnore:ShowWordContextMenu(row, entry)
    else
      print(L["WORD_CONTEXT_NOT_LOADED"])
    end
  end)

  local newWordInput = W:CreateEditBox(self.table.scrollFrame, 200, 24, "BOTTOMLEFT", 5, -35)
  W:AttachPlaceholder(newWordInput, L["SEARCH_PLACEHOLDERINPUT"])
  newWordInput:SetScript("OnEnterPressed", function(selfBox)
    self:AddNewWord(newWordInput)
    selfBox:ClearFocus()
  end)

  local dropdown = CreateChannelDropdown(panel, CrossIgnoreDB, function()
    CrossIgnore:UpdateWordsList(UI.State.wordFilterText or "")
  end)
  dropdown:SetPoint("TOPLEFT", newWordInput, "TOPRIGHT", -10, 0)

  local addBtn = W:CreateButton(newWordInput, L["ADD_WORD_BTN"], "BOTTOMLEFT", -5, -30, 90, 24, function()
    self:AddNewWord(newWordInput)
  end)
  local removeBtn = W:CreateButton(newWordInput, L["REMOVE_WORD_BTN"], "BOTTOMLEFT", 85, -30, 90, 24, function()
    self:RemoveSelectedWord()
  end)
  local removeAllBtn = W:CreateButton(newWordInput, L["REMOVE_ALL_BTN"], "BOTTOMLEFT", 170, -30, 90, 24, function()
    StaticPopup_Show("CROSSIGNORE_CONFIRM_REMOVE_ALL_WORDS")
  end)

  UI.Frames.wordSearchBox = searchBox
  UI.Frames.newWordInput = newWordInput
  UI.Frames.channelDropdown = dropdown
end

function M:AddNewWord(newWordInput)
  local CrossIgnore = self.CrossIgnore
  local CrossIgnoreDB = self.CrossIgnoreDB
  if not newWordInput then return end
  local word = newWordInput:GetText() or ""
  if word == "" then return end

  local channel = CrossIgnoreDB.selectedChannel or "all channels"
  local strict = UI.Frames.strictCheckBox and UI.Frames.strictCheckBox:GetChecked()

  if CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.NormalizeChannelKey then
    channel = CrossIgnore.ChatFilter:NormalizeChannelKey(channel):lower()
  else
    channel = safeString(channel):lower()
  end

  CrossIgnore.ChatFilter:AddWord(word, channel, strict)
  CrossIgnore:UpdateWordsList(UI.State.wordFilterText or "")
  newWordInput:SetText("")
end

function M:RemoveSelectedWord()
  local CrossIgnore = self.CrossIgnore
  local sw = UI.State.selectedWord or CrossIgnore.selectedWord
  if not sw then return end

  local channel = sw.channel or L["CHANNEL_ALL"]
  if CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.NormalizeChannelKey then
    channel = CrossIgnore.ChatFilter:NormalizeChannelKey(channel)
  end

  CrossIgnore.ChatFilter:RemoveWord(sw.word, channel)

  UI.State.selectedWord = nil
  CrossIgnore.selectedWord = nil
  CrossIgnore:UpdateWordsList(UI.State.wordFilterText or "")
end

function M:Refresh(searchText)
  local CrossIgnoreDB = self.CrossIgnoreDB
  local CrossIgnore = self.CrossIgnore
  if not self.table then return end

  local list = Data.BuildWordList(CrossIgnoreDB)
  list = Data.FilterWords(list, searchText or UI.State.wordFilterText or "")

  self.table:SetData(list)

  local selected = UI.State.selectedWord
  if selected then
    self.table:SelectByPredicate(function(e)
      return e.word == selected.word and e.channel == selected.channel
    end)
  end
end

return M
