local addonName, ns = ...

local CrossIgnore = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
ns.Addon = CrossIgnore
_G.CrossIgnore = CrossIgnore
CrossIgnore.ns = ns

local interfaceVersion = tonumber((select(4, GetBuildInfo()))) or 0
CrossIgnore.isForever = interfaceVersion >= 16000 and interfaceVersion < 20000
ns.CoreInternals = {}
ns.Data = {}
ns.UI = {}
