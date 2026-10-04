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
-- Fallback hotkey defaults to Ctrl+Tab and is updated from the Trigger action
-- whenever its assigned shortcut is observed during normal REAPER input.
local DEFAULT_HOTKEY_VK = 0x09
local DEFAULT_HOTKEY_MODS = 4
local MODIFIER_MASK      = 4 | 16 | 32
-- Set true only for diagnostics; normal mode filters out other applications.
local LIST_ALL_TOPLEVEL = false
-- Ignore auxiliary windows whose native titles are not useful in the switcher.
local EXCLUDED_WINDOW_TITLES = {
    ['tb'] = true,
    ['track names display'] = true,
}

-- Write concise diagnostics to REAPER's ReaScript console. These messages
-- are emitted only at startup and when the switcher changes state.
local function debugLog(message)
    reaper.ShowConsoleMsg('[WinSwitcher Daemon] ' .. message .. '\n')
end

-----------------------------------------------------------------------
-- CHECK DEPENDENCIES AND LOAD REAIMGUI
-----------------------------------------------------------------------

-- Check the API functions before calling them so missing extensions
-- produce a clear message instead of a Lua runtime error.
if not reaper.APIExists('ImGui_CreateContext') then
    debugLog('Startup stopped: ReaImGui API is unavailable.')
    reaper.MB('ReaImGui is required. Install it through ReaPack.', OVERLAY_NAME, 0)
    return
end
if not reaper.APIExists('JS_Window_ArrayAllTop') then
    debugLog('Startup stopped: js_ReaScriptAPI is unavailable.')
    reaper.MB('js_ReaScriptAPI is required. Install it through ReaPack.', OVERLAY_NAME, 0)
    return
end
if not reaper.APIExists('JS_VKeys_GetDown') or not reaper.APIExists('JS_Mouse_GetState') then
    debugLog('Startup stopped: js_ReaScriptAPI keyboard-state functions are unavailable.')
    reaper.MB('Current js_ReaScriptAPI keyboard-state functions are required.', OVERLAY_NAME, 0)
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
    debugLog('Startup stopped: unsupported ReaImGui version: ' .. tostring(ImGui))
    reaper.MB('Unsupported ReaImGui version: ' .. tostring(ImGui), OVERLAY_NAME, 0)
    return
end
debugLog('Dependencies loaded; daemon is starting.')

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
-- Cursor for keyboard events and timestamps used to deduplicate the action trigger.
local lastKeyboardPoll = reaper.time_precise()
local lastActionTriggerTime, lastFallbackHotkeyTime = 0, 0
local hotkeyVk, hotkeyRequiredMods = DEFAULT_HOTKEY_VK, DEFAULT_HOTKEY_MODS
local savedHotkeyVk, savedHotkeyMods = reaper.GetExtState(EXT, 'hotkey'):match('^(%d+)|(%d+)$')
if savedHotkeyVk and savedHotkeyMods then
    hotkeyVk = tonumber(savedHotkeyVk) or hotkeyVk
    hotkeyRequiredMods = tonumber(savedHotkeyMods) or hotkeyRequiredMods
end

-----------------------------------------------------------------------
-- WINDOW DISCOVERY AND ORDERING
-----------------------------------------------------------------------

-- Return an empty string when the native window has no readable title.
local function title_of(hwnd)
    return reaper.JS_Window_GetTitle(hwnd) or ''
end

-- Return the center of the primary display, independent of the focused window.
local function primaryScreenCenter()
    local getViewport = reaper.JS_Window_GetViewportFromRect
        or reaper.JS_Window_MonitorFromRect
    if getViewport then
        -- On Windows, the primary display contains the screen origin (0, 0).
        local left, top, right, bottom = getViewport(0, 0, 1, 1, false)
        if left and top and right and bottom then
            local centerX, centerY = (left + right) / 2, (top + bottom) / 2
            debugLog(string.format(
                'Primary display bounds: (%s, %s)-(%s, %s); center=(%.1f, %.1f).',
                tostring(left), tostring(top), tostring(right), tostring(bottom), centerX, centerY))
            return centerX, centerY
        end
    end

    -- Older js_ReaScriptAPI builds may not expose monitor viewport queries.
    debugLog('Primary display query unavailable; falling back to the REAPER main window center.')
    local _, left, top, right, bottom = reaper.JS_Window_GetRect(main)
    local centerX = ((left or 0) + (right or 0)) / 2
    local centerY = ((top or 0) + (bottom or 0)) / 2
    debugLog(string.format('Fallback native center=(%.1f, %.1f).', centerX, centerY))
    return centerX, centerY
end

local function isExcludedTitle(title)
    return EXCLUDED_WINDOW_TITLES[title:lower()] == true
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
    -- Array APIs append to the current logical size. Resize to zero while
    -- retaining the allocated capacity for the returned window handles.
    arr.resize(0)
    local n = reaper.JS_Window_ArrayAllTop(arr)
    debugLog(string.format('JS_Window_ArrayAllTop returned %s handle(s).', tostring(n)))
    if n < 0 then
        debugLog(string.format(
            'Window enumeration failed: the output array needs at least %d free slot(s).',
            -n))
        n = 0
    end

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
                local visible = hwnd and reaper.JS_Window_IsVisible(hwnd) or false
                local title = hwnd and title_of(hwnd) or ''
                if hwnd and visible then
                    if title ~= '' and title ~= OVERLAY_NAME
                        and not isExcludedTitle(title) and ownedByReaper(hwnd) then
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
    if itemCount < 2 then
        debugLog(string.format('No switcher opened: only %d eligible window(s) found.', itemCount))
        return
    end

    -- Forward starts after the current window; reverse starts at the last
    -- item. If the foreground window was not found, start at the first item.
    local selection = (dir == 'prev') and itemCount or (hasCurrent and 2 or 1)
    -- With no commit modifier held, keep the list open until an explicit
    -- Enter, click, or Escape action is received.
    local sticky = (mods == 0)
    local centerX, centerY = primaryScreenCenter()

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
        nx = centerX,
        ny = centerY,
    }
    debugLog(string.format(
        'Switcher opened: %d windows; direction=%s; modifiers=%d; sticky=%s; current-found=%s.',
        itemCount, tostring(dir), mods, tostring(sticky), tostring(hasCurrent)))
    for index, item in ipairs(items) do
        debugLog(string.format('Switcher item #%d: %s', index, item.title))
    end
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
    local targetTitle = commit and state.items[state.sel].title or 'original foreground window'
    debugLog(string.format('Closing switcher: commit=%s; target=%s.',
        tostring(commit), tostring(targetTitle)))
    state.open = false
    ctx = nil

    -- The native handle may have become invalid while the overlay was open.
    if target and reaper.JS_Window_IsWindow(target) then
        reaper.JS_Window_SetForeground(target)
        reaper.JS_Window_SetFocus(target)
        mru[reaper.JS_Window_AddressFromHandle(target)] = reaper.time_precise()
    elseif target then
        debugLog('Target window is no longer valid; foreground was not changed.')
    end
end

-----------------------------------------------------------------------
-- SWITCHER OVERLAY
-----------------------------------------------------------------------

local function drawOverlay(now)
    -- Create the context only while the overlay is needed.
    if not ctx then ctx = ImGui.CreateContext(OVERLAY_NAME) end
    if not state.overlayLogged then
        debugLog('Drawing the ReaImGui switcher overlay.')
        state.overlayLogged = true
    end

    local rows = math.min(#state.items, MAX_ROWS)
    local lineHeight = ImGui.GetTextLineHeightWithSpacing(ctx)
    -- Convert the native window center into the coordinate space used by
    -- ReaImGui, then center the overlay over that point.
    local centerX, centerY = ImGui.PointConvertNative(ctx, state.nx, state.ny)
    if not state.positionLogged then
        debugLog(string.format(
            'Overlay position: native=(%.1f, %.1f); ReaImGui=(%.1f, %.1f).',
            state.nx, state.ny, centerX, centerY))
        state.positionLogged = true
    end
    ImGui.SetNextWindowPos(ctx, centerX, centerY, ImGui.Cond_Always, 0.5, 0.5)
    ImGui.SetNextWindowSize(ctx, WIN_WIDTH, lineHeight * (rows + 2) + 30, ImGui.Cond_Always)

    -- Keep the switcher compact, stationary, and above other windows.
    local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize
        | ImGui.WindowFlags_NoMove | ImGui.WindowFlags_NoCollapse
        | ImGui.WindowFlags_NoSavedSettings | ImGui.WindowFlags_NoDocking
        | ImGui.WindowFlags_TopMost

    local result
    -- A secondary REAPER window (such as the Action List) may still own
    -- focus on another monitor; explicitly focus the switcher while open.
    ImGui.SetNextWindowFocus(ctx)
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

local function dispatchTrigger(direction, modifiers, now)
    if state.open then
        advance(direction or 'next', now)
    else
        openSwitcher(direction or 'next', modifiers, now)
    end
end

local function loop()
    local now = reaper.time_precise()

    -- The trigger checks this heartbeat to detect whether the daemon is
    -- running. Refresh it twice per second without writing persistent state.
    if now - lastBeat > 0.5 then
        reaper.SetExtState(EXT, 'alive', tostring(now), false)
        if lastBeat == 0 then debugLog('Heartbeat published to ExtState.') end
        lastBeat = now
    end

    trackForeground(now)

    -- The Action List's filter box can consume shortcuts before REAPER runs
    -- the Trigger action. js_ReaScriptAPI's accelerator hook still records
    -- the key-down event, so use it as a fallback for the configured chord.
    local keyDownEvents = reaper.JS_VKeys_GetDown(lastKeyboardPoll)
    lastKeyboardPoll = now
    local keyState = reaper.JS_Mouse_GetState(4 | 8 | 16 | 32)
    local hotkeyPressed = type(keyDownEvents) == 'string'
        and string.byte(keyDownEvents, hotkeyVk) == 1
        and (keyState & hotkeyRequiredMods) == hotkeyRequiredMods

    -- Trigger format: "timestamp|next-or-prev|modifier-mask". Each update
    -- either opens the switcher or advances the existing selection.
    local trigger = reaper.GetExtState(EXT, 'trigger')
    local triggerReceived = trigger ~= lastTrigger
    if triggerReceived then
        lastTrigger = trigger
        debugLog('Received ExtState trigger: ' .. trigger)
        local timestamp, direction, modifiers = trigger:match('^(.-)|(.-)|(.-)$')
        modifiers = tonumber(modifiers) or 0
        timestamp = tonumber(timestamp) or now

        -- Learn the non-modifier key from a real shortcut invocation so the
        -- fallback can match the user's assigned chord inside text controls.
        if modifiers ~= 0 and type(keyDownEvents) == 'string' then
            for virtualKey = 1, 255 do
                local isModifier = virtualKey == 16 or virtualKey == 17 or virtualKey == 18
                    or (virtualKey >= 160 and virtualKey <= 165)
                if not isModifier and string.byte(keyDownEvents, virtualKey) == 1 then
                    hotkeyVk = virtualKey
                    hotkeyRequiredMods = modifiers
                    reaper.SetExtState(EXT, 'hotkey',
                        string.format('%d|%d', hotkeyVk, hotkeyRequiredMods), true)
                    debugLog(string.format(
                        'Learned fallback hotkey: VK=%d; required modifiers=%d.',
                        hotkeyVk, hotkeyRequiredMods))
                    break
                end
            end
        end

        -- Prefer the action message if both paths observed the same keypress.
        if now - lastFallbackHotkeyTime > 0.15 then
            dispatchTrigger(direction, modifiers, now)
        else
            debugLog('Ignored duplicate Trigger action for a polled hotkey.')
        end
        lastActionTriggerTime = timestamp
    end

    if hotkeyPressed and not triggerReceived
        and now - lastActionTriggerTime > 0.15
        and now - lastFallbackHotkeyTime > 0.12 then
        lastFallbackHotkeyTime = now
        local direction = (keyState & 8) ~= 0 and 'prev' or 'next'
        local modifiers = keyState & MODIFIER_MASK
        debugLog(string.format(
            'Detected fallback hotkey: VK=%d; modifiers=%d; direction=%s.',
            hotkeyVk, modifiers, direction))
        dispatchTrigger(direction, modifiers, now)
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
