# CrossIgnore

## Unreleased (2026-09-29)

- Reorganized the addon into Core, Modules, Data, UI, Locales, and Media folders.
- Split startup, database handling, ignore synchronization, chat filtering, menus, and settings into focused files.
- Standardized file names, indentation, and internal namespace usage.
- Corrected locale file paths for English, French, and Russian.
- Preserved existing saved settings and public addon methods across the reorganization.

## [v12.0.34](https://github.com/LoyalFTW/CrossIgnore/tree/v12.0.34) (2026-09-27)
[Full Changelog](https://github.com/LoyalFTW/CrossIgnore/compare/v12.0.33...v12.0.34) [Previous Releases](https://github.com/LoyalFTW/CrossIgnore/releases)

- Forever Updates  
    * Added an option to automatically decline invites and requests from muted guilds and known guild members.  
    * Extended existing automatic replies to blocked guild members.  
    * Updated WoW Forever support for first and last names.  
    * Prevented an empty Blizzard ignore list from clearing CrossIgnore’s saved entries.  
    * Reworked right-click Block/Unblock controls to address the Copy Character Name error.  
    * Matched the CrossIgnore section’s font to Blizzard’s menu and kept it at the bottom.  
    * Applied these changes to both Retail and WoW Forever.  
