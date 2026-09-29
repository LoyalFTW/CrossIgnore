local _, ns = ...
local UI = ns.UI

UI.Theme = UI.Theme or {
    header = {
        bg      = {0.12, 0.12, 0.12, 0.95},
        border  = {0.35, 0.35, 0.35, 1.00},
        text    = {0.90, 0.90, 0.90, 1.00},
        hover   = {1.00, 0.82, 0.00, 1.00},
        active  = {1.00, 0.82, 0.00, 1.00},
        height  = 24,
        font    = "GameFontNormal",
    },
    row = {
        normal  = {0.10, 0.10, 0.10, 0.80},
        alt     = {0.15, 0.15, 0.15, 0.80},
        hover   = {0.30, 0.30, 0.30, 0.80},
        select  = {0.40, 0.40, 0.40, 0.80},
        font    = "GameFontNormalSmall",
        height  = 20,
        padX    = 5,
    },
    frame = {
        width  = 630,
        height = 520,
    }
}
