-- @description WinSwitcher - keyboard trigger for the REAPER window switcher
-- @version 0.1
-- @author Mathieu CONAN
-- @changelog Initial release
-- @link GitHub repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about Assign this action to a shortcut to cycle through REAPER windows.
--

--[[
=======================================================================
 REAPER - WinSwitcher Trigger
=======================================================================

 PURPOSE
 ----------------------------------------------------------------------
 Assign this action to a keyboard shortcut, such as Ctrl+Tab. Assigning
 Ctrl+Shift+Tab as well makes it possible to cycle in the reverse order.

 The trigger sends a short message to WinSwitcher_Daemon.lua, which must
 already be running in the background. The daemon handles the window
 list, overlay, and final focus change.

 The modifier keys held when this action runs determine when the daemon
 commits the selected window: releasing those keys accepts the selection.
 Shift reverses the navigation direction and is not part of that release
 check.

 SETUP
 ----------------------------------------------------------------------
 Add this script to a shortcut from REAPER's Action List. Start the
 daemon separately, preferably when REAPER starts.

=======================================================================
]]

-----------------------------------------------------------------------
-- CONFIGURATION
-----------------------------------------------------------------------

-- ExtState section shared with the background daemon.
local EXT = 'WinSwitcher'

-- Use REAPER's monotonic clock for the heartbeat and trigger timestamp.
local now = reaper.time_precise()

-----------------------------------------------------------------------
-- CHECK THAT THE DAEMON IS RUNNING
-----------------------------------------------------------------------

-- The daemon refreshes this timestamp twice per second. Treat a missing
-- or stale timestamp as an inactive daemon and show a setup reminder.
local alive = tonumber(reaper.GetExtState(EXT, 'alive') or '')
if not alive or now - alive > 2 then
    reaper.MB(
        'WinSwitcher_Daemon.lua is not running.\nStart it from the Action List, '
            .. 'ideally when REAPER starts.',
        'WinSwitcher',
        0
    )
    return
end

-----------------------------------------------------------------------
-- READ MODIFIER KEYS AND CHOOSE A DIRECTION
-----------------------------------------------------------------------

-- JS_Mouse_GetState uses bit flags for modifier keys. Keep Shift separate:
-- it changes direction, while Ctrl, Alt, and Windows are release-to-commit
-- modifiers passed to the daemon.
local mods, shift = 0, false
if reaper.APIExists('JS_Mouse_GetState') then
    local keyState = reaper.JS_Mouse_GetState(4 | 8 | 16 | 32)
    mods = keyState & (4 | 16 | 32)
    shift = (keyState & 8) ~= 0
end

-----------------------------------------------------------------------
-- SEND THE TRIGGER MESSAGE
-----------------------------------------------------------------------

-- The daemon watches this persistent ExtState value. The timestamp makes
-- successive presses distinguishable even when direction and modifiers
-- are identical. Persistence is disabled because this is runtime state.
local trigger = string.format('%.6f|%s|%d', now, shift and 'prev' or 'next', mods)
reaper.SetExtState(EXT, 'trigger', trigger, false)
