local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

function CrossIgnore:InitDB()
    self.globalDB = LibStub("AceDB-3.0"):New("CrossIgnoreDB", {
        global = {
            minimap = { hide = false },
            players = {},
            overLimitPlayers = {},
            pendingRemovals = {},
            guildIgnores = {},
            guildKnowledge = {},
            guildRetention = {},
            guildAutoDeclineInvites = true,
            filters = {
                totalFilteredMessages = 0,
                presets = {},
                words = {
                    ["All Channels"] = {},
                    ["Say"] = {},
                    ["Yell"] = {},
                    ["Whisper"] = {},
                    ["Guild"] = {},
                    ["Officer"] = {},
                    ["Party"] = {},
                    ["Raid"] = {},
                    ["Instance"] = {},
                    ["Custom"] = {},
                },
                selectedChannel = "All Channels",
                defaultsLoaded = false,
                removedDefaults = false,
            },
        },
    }, true)

    self.charDB = LibStub("AceDB-3.0"):New("CrossIgnoreSingleDB", {
        profile = {
            settings = {
                LFGBlock = not self.isForever,
                lfgExpireDays = 1,
                UnitBlock = true,
                useGlobalIgnore = false,
                maxIgnoreLimit = 50,
                autoReplyEnabled = true,
                autoReplyMessage = L["AUTO_REPLY_DEFAULT"]
            },
            players = {},
            overLimitPlayers = {},
            pendingRemovals = {},
        },
    }, true)

    self.db = self.charDB
end
