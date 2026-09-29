local _, ns = ...
ns.Locales = ns.Locales or {}

local locale = GetLocale()
ns.L = ns.Locales[locale] or ns.Locales["enUS"]
