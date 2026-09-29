local _, ns = ...
local CrossIgnore = ns.Addon

function CrossIgnore:ShowBlockedIconOnTooltip()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            local _, unit = tooltip:GetUnit()
            if unit and UnitIsPlayer(unit) then
                local name, realm = UnitName(unit)
                if name then
                    addon:CheckTooltipForIgnoredPlayer(tooltip, name, realm)
                end
            end
        end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            local _, unit = tooltip:GetUnit()
            if unit and UnitIsPlayer(unit) then
                local name, realm = UnitName(unit)
                if name then
                    addon:CheckTooltipForIgnoredPlayer(tooltip, name, realm)
                end
            end
    end)
    end
end
