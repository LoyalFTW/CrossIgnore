local _, ns = ...
local CrossIgnore = ns.Addon

function CrossIgnore:ShowBlockedIconOnTooltip()
    local function OnTooltipUnit(tooltip)
        local unit = CrossIgnore:GetTooltipUnit(tooltip)
        if unit and UnitIsPlayer(unit) then
            local name, realm = UnitName(unit)
            if name then
                CrossIgnore:CheckTooltipForIgnoredPlayer(tooltip, name, realm)
            end
        end
    end

    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipUnit)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipUnit)
    end
end
