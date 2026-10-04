-- @description WinSwitcher - Alt+Tab-style window switcher daemon for REAPER
-- @version 0.1
-- @author Mathieu CONAN
-- @changelog Initial release
-- @link GitHub repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about Run this background action to provide a window switcher for WinSwitcher_Trigger.lua.
--

--[[
=======================================================================
 REAPER - WinSwitcher Daemon
=======================================================================

 PURPOSE
 ----------------------------------------------------------------------
 This background action provides an Alt+Tab-style switcher for REAPER
 windows. Run it once, preferably when REAPER starts, then assign a
 keyboard shortcut to WinSwitcher_Trigger.lua.

 DEPENDENCIES
 ----------------------------------------------------------------------
 Install ReaImGui and js_ReaScriptAPI through ReaPack.

 HIGH-LEVEL FLOW
 ----------------------------------------------------------------------
 1. Track foreground REAPER windows to maintain a most-recently-used list.
 2. Read trigger messages written by WinSwitcher_Trigger.lua.
 3. Build and display a selectable window list when switching begins.
 4. Commit the selection when the trigger modifiers are released, or when
    the user presses Enter or clicks an item. Escape cancels the switch.

=======================================================================
]]

-----------------------------------------------------------------------
-- CONFIGURATION
-----------------------------------------------------------------------

-- ExtState section used to exchange the heartbeat and trigger message.
local EXT          = 'WinSwitcher'   -- ExtState section shared with the trigger
local OVERLAY_NAME = 'WinSwitcher'   -- ReaImGui window title

-- Delay before showing the overlay. A quick press and release switches
-- windows without displaying the list.
local SHOW_DELAY        = 0.15
local WIN_WIDTH         = 560
local MAX_ROWS          = 14
-- Set true to include all top-level windows on Windows for diagnostics.
local LIST_ALL_TOPLEVEL = false

-----------------------------------------------------------------------
-- CHECK DEPENDENCIES AND LOAD REAIMGUI
-----------------------------------------------------------------------

-- Check the API functions before calling them so missing extensions
-- produce a clear message instead of a Lua runtime error.
if not reaper.APIExists('ImGui_CreateContext') then
    reaper.MB('ReaImGui is required. Install it through ReaPack.', OVERLAY_NAME, 0)
    return
end
if not reaper.APIExists('JS_Window_ArrayAllTop') then
    reaper.MB('js_ReaScriptAPI is required. Install it through ReaPack.', OVERLAY_NAME, 0)
    return
end

-- ReaImGui ships its Lua module in a built-in directory. Try the current
-- API version first, then fall back to the older version supported here.
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ok, ImGui = pcall(function() return require 'imgui' '0.10' end)
if not ok then
    ok, ImGui = pcall(function() return require 'imgui' '0.9.3' end)
end
if not ok then
    reaper.MB('Unsupported ReaImGui version: ' .. tostring(ImGui), OVERLAY_NAME, 0)
    return
end

-----------------------------------------------------------------------
-- SHARED STATE
-----------------------------------------------------------------------

-- Keep both the main window handle and its address. The address is used
-- as a stable key when comparing handles returned by js_ReaScriptAPI.
local main     = reaper.GetMainHwnd()
local mainAddr = reaper.JS_Window_AddressFromHandle(main)
local isWin    = reaper.GetOS():find('Win') ~= nil
-- Map each window address to the most recent time it had foreground focus.
local mru      = {}
-- The active switch session contains its window list, selection, and UI state.
local state    = { open = false }
-- ReaImGui context is created on demand and discarded when the switch closes.
local ctx      = nil
-- Cached focus-tracking and heartbeat timestamps.
local lastFg, lastTrack, lastBeat = nil, 0, 0

-----------------------------------------------------------------------
-- WINDOW DISCOVERY AND ORDERING
-----------------------------------------------------------------------

-- Return an empty string when the native window has no readable title.
local function title_of(hwnd)
    return reaper.JS_Window_GetTitle(hwnd) or ''
end

local function ownedByReaper(hwnd)
    -- On Windows, ArrayAllTop can include windows from other applications.
    -- Walk the owner chain and accept only windows that ultimately belong
    -- to REAPER's main window. Other platforms do not use this filter here.
    if LIST_ALL_TOPLEVEL or not isWin then return true end
    local ownerWindow = hwnd
    for _ = 1, 8 do
        local owner = reaper.JS_Window_GetRelated(ownerWindow, 'OWNER')
        if not owner then return false end
        if reaper.JS_Window_AddressFromHandle(owner) == mainAddr then return true end
        ownerWindow = owner
    end
    return false
end

-- Collect visible REAPER windows, order them by recent use, and move the
-- current foreground window to the front when it is in the collected list.
local function collect()
    local items, mainZ = {}, 1e6
    local arr = reaper.new_array(2048)
    local n = reaper.JS_Window_ArrayAllTop(arr)

    -- ArrayAllTop returns native window addresses in z-order. Preserve each
    -- index as a fallback ordering when no MRU timestamp has been recorded.
    if n and n > 0 then
        local addrs = arr.table(1, n)
        for z = 1, n do
            local addr = addrs[z]
            if addr == mainAddr then
                mainZ = z
            else
                local hwnd = reaper.JS_Window_HandleFromAddress(addr)
                if hwnd and reaper.JS_Window_IsVisible(hwnd) then
                    local title = title_of(hwnd)
                    if title ~= '' and title ~= OVERLAY_NAME and ownedByReaper(hwnd) then
                        items[#items + 1] = { hwnd = hwnd, addr = addr, title = title, z = z }
                    end
                end
            end
        end
    end

    -- The main REAPER window is included even if it was not returned by
    -- ArrayAllTop. Include the current project name to distinguish it.
    local projectName = reaper.GetProjectName(0, '')
    items[#items + 1] = {
        hwnd = main,
        addr = mainAddr,
        z = mainZ,
        title = 'REAPER - ' .. (projectName ~= '' and projectName or 'untitled project'),
    }

    -- Prefer the most recently focused window. Use z-order to make the
    -- initial ordering deterministic for windows not yet seen by tracking.
    table.sort(items, function(a, b)
        local timeA, timeB = mru[a.addr] or 0, mru[b.addr] or 0
        if timeA ~= timeB then return timeA > timeB end
        return a.z < b.z
    end)

    -- Place the foreground window first so the initial forward selection
    -- naturally advances to the next window in the list.
    local hasCurrent = false
    local foreground = reaper.JS_Window_GetForeground()
    if foreground then
        local foregroundAddr = reaper.JS_Window_AddressFromHandle(foreground)
        for i, item in ipairs(items) do
            if item.addr == foregroundAddr then
                table.remove(items, i)
                table.insert(items, 1, item)
                hasCurrent = true
                break
            end
        end
    end
    return items, hasCurrent
end

-- Record foreground changes outside the overlay so the MRU list reflects
-- how windows were used before the current switch operation.
local function trackForeground(now)
    -- Do not let the overlay itself affect the MRU ordering. Throttle the
    -- native foreground query to avoid polling it on every defer cycle.
    if state.open or now - lastTrack < 0.1 then return end
    lastTrack = now
    local foreground = reaper.JS_Window_GetForeground()
    if not foreground then return end
    local addr = reaper.JS_Window_AddressFromHandle(foreground)
    if addr == lastFg then return end
    lastFg = addr

    -- Track the main window and titled child windows owned by REAPER only.
    local title = title_of(foreground)
    if addr == mainAddr or (title ~= '' and title ~= OVERLAY_NAME and ownedByReaper(foreground)) then
        mru[addr] = now
    end
end

-----------------------------------------------------------------------
-- SWITCH SESSION LIFECYCLE
-----------------------------------------------------------------------

local function openSwitcher(dir, mods, now)
    local items, hasCurrent = collect()
    local itemCount = #items
    if itemCount < 2 then return end

    -- Forward starts after the current window; reverse starts at the last
    -- item. If the foreground window was not found, start at the first item.
    local selection = (dir == 'prev') and itemCount or (hasCurrent and 2 or 1)
    -- With no commit modifier held, keep the list open until an explicit
    -- Enter, click, or Escape action is received.
    local sticky = (mods == 0)
    local anchor = hasCurrent and items[1].hwnd or main
    local _, left, top, right, bottom = reaper.JS_Window_GetRect(anchor)

    state = {
        open = true,
        items = items,
        sel = selection,
        mods = mods,
        sticky = sticky,
        showAt = sticky and now or (now + SHOW_DELAY),
        lastAdv = now,
        scroll = true,
        origin = hasCurrent and items[1].hwnd or nil,
        nx = ((left or 0) + (right or 0)) / 2,
        ny = ((top or 0) + (bottom or 0)) / 2,
    }
end

local function advance(dir, now)
    -- A key event can be observed by both the trigger and overlay. Ignore
    -- very closely spaced advances so one press does not count twice.
    if now - state.lastAdv < 0.12 then return end
    state.lastAdv = now
    local itemCount = #state.items
    state.sel = ((state.sel - 1 + (dir == 'prev' and -1 or 1)) % itemCount) + 1
    state.scroll = true
end

local function closeSwitcher(commit)
    -- On cancellation, restore the original foreground window. If no
    -- original window was collected, the target is nil and focus is left
    -- unchanged.
    local target = commit and state.items[state.sel].hwnd or state.origin
    state.open = false
    ctx = nil

    -- The native handle may have become invalid while the overlay was open.
    if target and reaper.JS_Window_IsWindow(target) then
        reaper.JS_Window_SetForeground(target)
        reaper.JS_Window_SetFocus(target)
        mru[reaper.JS_Window_AddressFromHandle(target)] = reaper.time_precise()
    end
end

-----------------------------------------------------------------------
-- SWITCHER OVERLAY
-----------------------------------------------------------------------

local function drawOverlay(now)
    -- Create the context only while the overlay is needed.
    if not ctx then ctx = ImGui.CreateContext(OVERLAY_NAME) end

    local rows = math.min(#state.items, MAX_ROWS)
    local lineHeight = ImGui.GetTextLineHeightWithSpacing(ctx)
    -- Convert the native window center into the coordinate space used by
    -- ReaImGui, then center the overlay over that point.
    local centerX, centerY = ImGui.PointConvertNative(ctx, state.nx, state.ny)
    ImGui.SetNextWindowPos(ctx, centerX, centerY, ImGui.Cond_Always, 0.5, 0.5)
    ImGui.SetNextWindowSize(ctx, WIN_WIDTH, lineHeight * (rows + 2) + 30, ImGui.Cond_Always)

    -- Keep the switcher compact, stationary, and above other windows.
    local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize
        | ImGui.WindowFlags_NoMove | ImGui.WindowFlags_NoCollapse
        | ImGui.WindowFlags_NoSavedSettings | ImGui.WindowFlags_NoDocking
        | ImGui.WindowFlags_TopMost

    local result
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 12, 10)
    local visible = ImGui.Begin(ctx, OVERLAY_NAME, nil, flags)
    if visible then
        ImGui.TextDisabled(ctx, 'Tab / Shift+Tab: navigate  -  Enter: select  -  Escape: cancel')
        ImGui.Separator(ctx)

        -- Each selectable row carries a stable hidden suffix so duplicate
        -- window titles still have distinct ImGui identifiers.
        for i, item in ipairs(state.items) do
            if ImGui.Selectable(ctx, item.title .. '##' .. i, i == state.sel) then
                state.sel = i
                result = 'commit'
            end
            if i == state.sel and state.scroll then ImGui.SetScrollHereY(ctx) end
        end
        state.scroll = false

        -- Also accept navigation from the overlay itself. Ignore Tab briefly
        -- after opening because the trigger already processed the first press.
        if now > state.showAt + 0.25 and ImGui.IsKeyPressed(ctx, ImGui.Key_Tab, true) then
            local shift = (ImGui.GetKeyMods(ctx) & ImGui.Mod_Shift) ~= 0
            advance(shift and 'prev' or 'next', now)
        end
        if ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow, true) then advance('next', now) end
        if ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow, true) then advance('prev', now) end
        if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false)
            or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter, false) then
            result = 'commit'
        end
        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then result = 'cancel' end

        ImGui.End(ctx)
    end
    ImGui.PopStyleVar(ctx)
    return result
end

-----------------------------------------------------------------------
-- BACKGROUND LOOP
-----------------------------------------------------------------------

-- Remember the current trigger value so an old message is not processed
-- again when this daemon starts or resumes.
local lastTrigger = reaper.GetExtState(EXT, 'trigger')

local function loop()
    local now = reaper.time_precise()

    -- The trigger checks this heartbeat to detect whether the daemon is
    -- running. Refresh it twice per second without writing persistent state.
    if now - lastBeat > 0.5 then
        reaper.SetExtState(EXT, 'alive', tostring(now), false)
        lastBeat = now
    end

    trackForeground(now)

    -- Trigger format: "timestamp|next-or-prev|modifier-mask". Each update
    -- either opens the switcher or advances the existing selection.
    local trigger = reaper.GetExtState(EXT, 'trigger')
    if trigger ~= lastTrigger then
        lastTrigger = trigger
        local _, direction, modifiers = trigger:match('^(.-)|(.-)|(.-)$')
        modifiers = tonumber(modifiers) or 0
        if state.open then
            advance(direction or 'next', now)
        else
            openSwitcher(direction or 'next', modifiers, now)
        end
    end

    if state.open then
        -- For Alt+Tab-style use, releasing every modifier captured by the
        -- trigger immediately commits the currently selected window.
        if not state.sticky and (reaper.JS_Mouse_GetState(state.mods) & state.mods) == 0 then
            closeSwitcher(true)
        elseif now >= state.showAt then
            local action = drawOverlay(now)
            if action == 'commit' then
                closeSwitcher(true)
            elseif action == 'cancel' then
                closeSwitcher(false)
            end
        end
    end

    -- Schedule the next pass without blocking REAPER's UI thread.
    reaper.defer(loop)
end

-----------------------------------------------------------------------
-- ACTION TOGGLE STATE AND CLEANUP
-----------------------------------------------------------------------

-- Keep the action's toolbar state synchronized while the deferred loop is
-- active, and clear both the toggle and heartbeat when REAPER stops it.
local _, _, sec, cmd = reaper.get_action_context()
reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)
reaper.atexit(function()
    reaper.SetToggleCommandState(sec, cmd, 0)
    reaper.RefreshToolbar2(sec, cmd)
    reaper.DeleteExtState(EXT, 'alive', false)
end)

loop()
