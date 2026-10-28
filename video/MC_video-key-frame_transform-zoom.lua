-- @description Video - Transform and zoom selected video items in the preview
-- @version 0.1
-- @author Mathieu CONAN
-- @changelog Initial release
-- @link GitHub repository https://github.com/MathieuCGit/Reaper_Tools/tree/main/video
-- @about
--   Adjust a selected video's position and zoom directly in REAPER's video preview.
--   The script uses the native Video processor preset "Image overlay" and writes
--   keyframes to its X offset, Y offset, and zoom parameter envelopes.
--
--   Requirements:
--   - REAPER 7 or newer
--   - js_ReaScriptAPI, available through ReaPack
--   - The native "Image overlay" preset for the Video processor
--
--   Start this action and leave it running while using the mouse gestures below.
--   Select the video item to edit in the arrange view before interacting with
--   the video preview.
--
--   Gestures over the video preview:
--   - Left-drag: move the image. Unanimated parameters are changed as static
--     values; animated parameters receive a keyframe at the playhead.
--   - Shift + left-drag: move the image more slowly for fine adjustments.
--   - Ctrl + mouse wheel: change zoom and always insert or update a zoom keyframe.
--   - Ctrl + left-click: insert or update X/Y keyframes using the current position.
--   - Alt + left-click: copy the preceding X/Y position to the playhead.
--   New keyframes are aligned to the nearest project video frame.
--
--   Configuration:
--   Edit CFG below to change the zoom step, fine-drag speed, drag direction,
--   automatic FX insertion, or the interpolation shape of new envelope points.
--
--   The mouse interception is provided by js_ReaScriptAPI. The native preset
--   makes this script usable without third-party video-control presets.
-- @license GPL v3

------------------------------------------------------------------------------
-- User-adjustable gesture and preset settings.
------------------------------------------------------------------------------
local CFG = {
  PRESET_NAME    = "Image overlay",
  PARAM_NAMES    = { x = "X offset", y = "Y offset", zoom = "zoom" },
  AUTO_ADD_FX    = true,              -- Add the native preset when a gesture targets an item without it.
  ALLOWED_SOURCE = { VIDEO = true },  -- Source types that are allowed to receive the preset automatically.
  INVERT_X       = false,             -- Reverse horizontal drag direction if it feels backwards.
  INVERT_Y       = false,             -- Reverse vertical drag direction if it feels backwards.
  SCALE_STEP     = 1.05,              -- Zoom multiplier for one mouse-wheel detent (5 percent).
  SHIFT_FINE     = 0.2,               -- Shift-drag movement multiplier for finer positioning.
  KEY_SHAPE      = 0,                 -- REAPER envelope shape: 0 linear, 1 square, 2 slow, 3 fast start, 4 fast end, 5 Bezier.
  DRAG_THRESHOLD = 0.004,             -- Normalized pointer movement needed to begin a drag.
  DEFAULTS       = { x = 0, y = 0, zoom = 0 },
}

-- Shared ExtState section for the heartbeat and optional shortcut commands.
local EXT = "VideoKF"
-- REAPER's native class names distinguish the preview container from its GL surface.
local CLASS_MAIN = "REAPERVideoMainwnd"
local CLASS_GL   = "REAPERVideoGLView"

-- Mouse-window detection and input polling require js_ReaScriptAPI.
if not reaper.JS_Window_FromPoint then
  reaper.MB("js_ReaScriptAPI is required (install it through ReaPack).", "VideoKF", 0)
  return
end

------------------------------------------------------------------------------
-- SMALL HELPERS
------------------------------------------------------------------------------
-- Write diagnostic output to REAPER's ReaScript console.
local function log(s) reaper.ShowConsoleMsg(s .. "\n") end

-- Some JS API calls return a success boolean before their useful values.
local function strip_bool(...)
  local t = { ... }
  if type(t[1]) == "boolean" then return table.unpack(t, 2) end
  return table.unpack(t)
end

-- Normalize APIs that return a string in different positions across versions.
local function first_string(...)
  for _, v in ipairs({ ... }) do
    if type(v) == "string" then return v end
  end
  return ""
end

-- Return a window's native class name, or an empty string for a missing handle.
local function class_of(h) return first_string(reaper.JS_Window_GetClassName(h)) end

-- Get the client area size, excluding the window frame and title bar.
local function client_size(h)
  local w, hh = strip_bool(reaper.JS_Window_GetClientSize(h))
  return w or 0, hh or 0
end

-- WM_MOUSEWHEEL stores its signed delta in the low 16 bits of a word.
local function s16(v) if v > 32767 then return v - 65536 end return v end

-- Show short status and error messages next to the current mouse pointer.
local function tip(msg)
  local mx, my = reaper.GetMousePosition()
  reaper.TrackCtl_SetToolTip(msg, mx + 16, my + 16, true)
end

------------------------------------------------------------------------------
-- VIDEO PREVIEW WINDOWS (container for wheel messages, GL surface for clicks)
------------------------------------------------------------------------------
local main, gl = nil, nil
local last_wheel_time = nil

-- Always release interception before switching windows or stopping the script.
local function release_wheel()
  if main then reaper.JS_WindowMessage_Release(main, "WM_MOUSEWHEEL") end
end

-- Remember the preview windows and observe wheel messages without blocking them.
local function lock(m, g)
  release_wheel()
  main, gl = m, g
  last_wheel_time = nil
  reaper.JS_WindowMessage_Intercept(main, "WM_MOUSEWHEEL", true)  -- Pass through the wheel message after reading it.
end

-- Find the preview and its OpenGL child when the script starts.
local function autofind()
  local m = reaper.JS_Window_Find("Video Window", true)
  if not m then return end
  local ok, g = pcall(function()
    local arr = reaper.new_array({}, 64)
    local n = reaper.JS_Window_ArrayAllChild(m, arr)
    local addrs = arr.table()
    for i = 1, n do
      local h = reaper.JS_Window_HandleFromAddress(addrs[i])
      if class_of(h) == CLASS_GL then return h end
    end
  end)
  if ok and g then lock(m, g) end
end

-- Convert screen pixels to normalized coordinates in the GL preview surface.
-- Values outside 0..1 are retained so dragging can continue beyond the picture.
local function screen_to_video(mx, my)
  local cw, ch = client_size(gl)
  if cw <= 0 or ch <= 0 then return nil end
  local cx, cy = strip_bool(reaper.JS_Window_ScreenToClient(gl, mx, my))
  if not cx then return nil end
  return cx / cw, cy / ch
end

------------------------------------------------------------------------------
-- TARGET: SELECTED ITEM AND ITS NATIVE "IMAGE OVERLAY" VIDEO PROCESSOR
------------------------------------------------------------------------------
local function find_fx(take)
  local want = {}
  for key, name in pairs(CFG.PARAM_NAMES) do want[name:lower()] = key end
  -- Some Video processor builds expose the script variable names instead
  -- of the user-facing parameter labels.
  want.xoffs, want.yoffs = "x", "y"
  for fx = 0, reaper.TakeFX_GetCount(take) - 1 do
    local idx = {}
    for p = 0, reaper.TakeFX_GetNumParams(take, fx) - 1 do
      local name = first_string(reaper.TakeFX_GetParamName(take, fx, p)):lower()
      local key = want[name]
      if key then idx[key] = p end
    end
    if idx.x and idx.y and idx.zoom then return fx, idx end
  end
end

local function add_fx(take)
  -- Add the built-in Video processor and select its bundled image overlay preset.
  local fx = reaper.TakeFX_AddByName(take, "Video processor", -1)
  if not fx or fx < 0 then return nil end
  if not reaper.TakeFX_SetPreset(take, fx, CFG.PRESET_NAME) then
    -- Do not leave an unconfigured processor behind if the preset is unavailable.
    reaper.TakeFX_Delete(take, fx)
    return nil
  end
  return fx
end

-- Resolve the selected item's active take and its transform parameters.
-- Gestures may add the preset; explicit commands only operate on an existing FX.
local function get_target(allow_add)
  local item = reaper.GetSelectedMediaItem(0, 0)
  if not item then return nil, "No media item is selected" end
  local take = reaper.GetActiveTake(item)
  if not take then return nil, "The selected item has no active take" end
  local fx, idx = find_fx(take)
  if not fx then
    if not (allow_add and CFG.AUTO_ADD_FX) then return nil, 'No "Image overlay" preset found on this item' end
    local stype = first_string(reaper.GetMediaSourceType(reaper.GetMediaItemTake_Source(take))):upper()
    if not CFG.ALLOWED_SOURCE[stype] then return nil, "Unsupported media source type: " .. stype end
    local newfx = add_fx(take)
    if not newfx then return nil, 'Could not load the "' .. CFG.PRESET_NAME .. '" preset' end
    fx, idx = find_fx(take)
    if not fx then return nil, "The processor was added, but its transform parameters could not be found" end
  end
  -- Cache item timing data because it is needed to convert project time
  -- into the take FX envelope's local time.
  return {
    item = item, take = take, fx = fx, idx = idx,
    pos  = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
    len  = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
    rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
  }
end

------------------------------------------------------------------------------
-- PROJECT TIME AND TAKE-ENVELOPE TIME
------------------------------------------------------------------------------
local function proj_time()
  -- Follow playback when REAPER is running; otherwise use the edit cursor.
  if (reaper.GetPlayState() & 1) == 1 then return reaper.GetPlayPosition() end
  return reaper.GetCursorPosition()
end

-- Convert project time to take-envelope time, or return nil outside the item.
local function env_time(tg, pt)
  -- Take FX envelopes use media time, not project time. Apply the item's
  -- playback rate, and reject edit/play positions outside the item bounds.
  local t = (pt - tg.pos) * tg.rate
  local tmax = tg.len * tg.rate
  if t < -1e-6 or t > tmax + 1e-6 then
    return nil, "playhead is outside the selected item"
  end
  local fps = reaper.TimeMap_curFrameRate(0)
  if not fps or fps <= 0 then fps = 25 end

  -- Keep points on the project video-frame grid, while ensuring the snapped
  -- time remains inside the item even when its edges fall between frames.
  local first_frame = math.ceil(tg.pos * fps - 1e-9)
  local last_frame = math.floor((tg.pos + tg.len) * fps + 1e-9)
  if first_frame > last_frame then
    return nil, "no video frame falls inside the selected item"
  end
  local frame = math.floor(pt * fps + 0.5)
  frame = math.max(first_frame, math.min(last_frame, frame))
  return math.max(0, (frame / fps - tg.pos) * tg.rate)
end

local function frame_eps(tg)
  -- Treat points within half a video frame as the same keyframe.
  local fps = reaper.TimeMap_curFrameRate(0)
  if not fps or fps <= 0 then fps = 25 end
  return 0.5 / fps * tg.rate
end

------------------------------------------------------------------------------
-- VIDEO-PROCESSOR PARAMETERS AND TAKE FX ENVELOPES
------------------------------------------------------------------------------
local function pidx(tg, key) return tg.idx[key] end

local function clamp_param(tg, key, v)
  -- Keep values within the range declared by the Video processor parameter.
  local _, mn, mx = reaper.TakeFX_GetParamEx(tg.take, tg.fx, pidx(tg, key))
  if mn and mx then return math.max(mn, math.min(mx, v)) end
  return v
end

local function get_env(tg, key, create)
  -- Reuse an existing envelope or ask REAPER to create it when requested.
  return reaper.TakeFX_GetEnvelope(tg.take, tg.fx, pidx(tg, key), create)
end

local function is_animated(tg, key)
  -- An envelope only counts as animated when it contains at least one point.
  local env = get_env(tg, key, false)
  return env ~= nil and reaper.CountEnvelopePoints(env) > 0
end

local function zoom_factor(zoom)
  -- The native preset expresses zoom in decibels: 0 dB = 1x, 20 dB = 10x.
  return 10 ^ (zoom / 10)
end

local function eval_param(tg, key, t)
  -- Envelope_Evaluate returns the parameter's raw value at local take time.
  -- If there is no animated envelope, use the processor's static parameter value.
  local env = get_env(tg, key, false)
  if env and t and reaper.CountEnvelopePoints(env) > 0 then
    local _, value = reaper.Envelope_Evaluate(env, t, 0, 0)
    return value
  end
  return (reaper.TakeFX_GetParam(tg.take, tg.fx, pidx(tg, key)))
end

local function find_point(env, t, eps)
  -- Find an existing point close enough to update instead of creating a duplicate.
  for i = 0, reaper.CountEnvelopePoints(env) - 1 do
    local ok, pt = reaper.GetEnvelopePointEx(env, -1, i)
    if ok and math.abs(pt - t) <= eps then return i end
  end
end

-- Create or update one envelope point without changing the FX's static parameter.
local function put_key(tg, key, t, value)
  local env = get_env(tg, key, false)
  -- REAPER may create a default point along with a new envelope. Remove those
  -- defaults so the only point left is the one explicitly requested below.
  local initialize = not env or reaper.CountEnvelopePoints(env) == 0
  if not env then
    env = get_env(tg, key, true)
    if not env then return false end
  end
  if initialize then
    for i = reaper.CountEnvelopePoints(env) - 1, 0, -1 do
      reaper.DeleteEnvelopePointEx(env, -1, i)
    end
  end
  value = clamp_param(tg, key, value)
  local i = find_point(env, t, frame_eps(tg))
  if i then
    -- Preserve the existing point's time and interpolation shape.
    reaper.SetEnvelopePointEx(env, -1, i, nil, value, nil, nil, nil, true)
  else
    -- InsertEnvelopePointEx stores the parameter value in the envelope.
    reaper.InsertEnvelopePointEx(env, -1, t, value, CFG.KEY_SHAPE, 0, false, true)
    reaper.Envelope_SortPoints(env)
  end
  return true
end

-- Change an animated parameter at the playhead, or its static value if unanimated.
local function set_value(tg, key, t, raw)
  if is_animated(tg, key) then
    if not t then return false end
    return put_key(tg, key, t, raw)
  end
  reaper.TakeFX_SetParam(tg.take, tg.fx, pidx(tg, key), clamp_param(tg, key, raw))
  return true
end

------------------------------------------------------------------------------
-- KEYFRAME COMMANDS
------------------------------------------------------------------------------
local function fmt_t(tg, t) return ("%.2f s"):format(tg.pos + t / tg.rate) end

-- Insert or update X and Y points at the current edit/play position.
-- Evaluating the parameters first makes this an identity operation: creating
-- a keyframe alone must not move the image.
local function cmd_key_position()
  local tg, err = get_target(false)
  if not tg then tip("VideoKF: " .. err); return end
  local t, time_err = env_time(tg, proj_time())
  if not t then tip("VideoKF: " .. time_err); return end
  reaper.Undo_BeginBlock()
  local x, y = eval_param(tg, "x", t), eval_param(tg, "y", t)
  put_key(tg, "x", t, x); put_key(tg, "y", t, y)
  reaper.Undo_EndBlock("VideoKF: keyframe position", -1)
  reaper.UpdateArrange()
  tip(("Position keyframe @ %s"):format(fmt_t(tg, t)))
end

-- Copy the most recent earlier X/Y pose to the current playhead.
-- The nearest point on either axis determines the source time; both axes
-- are evaluated there so the pair represents one coherent image position.
local function cmd_copy_previous_position()
  local tg, err = get_target(false)
  if not tg then tip("VideoKF: " .. err); return end
  local t, time_err = env_time(tg, proj_time())
  if not t then tip("VideoKF: " .. time_err); return end

  local previous
  -- Search both envelopes because X and Y points do not have to share times.
  -- A keyframe on either axis marks the most recent saved pose.
  for _, key in ipairs({ "x", "y" }) do
    local env = get_env(tg, key, false)
    if env then
      for i = 0, reaper.CountEnvelopePoints(env) - 1 do
        local ok, point_time = reaper.GetEnvelopePointEx(env, -1, i)
        if ok and point_time < t - 1e-6 and (not previous or point_time > previous) then
          previous = point_time
        end
      end
    end
  end

  if not previous then
    tip("VideoKF: no preceding X/Y keyframe")
    return
  end

  reaper.Undo_BeginBlock()
  local x, y = eval_param(tg, "x", previous), eval_param(tg, "y", previous)
  put_key(tg, "x", t, x); put_key(tg, "y", t, y)
  reaper.Undo_EndBlock("VideoKF: copy preceding position", -1)
  reaper.UpdateArrange()
  tip(("Previous position copied @ %s"):format(fmt_t(tg, t)))
end

-- Insert an identity keyframe for zoom at the current playhead.
local function cmd_key_scale()
  local tg, err = get_target(false)
  if not tg then tip("VideoKF: " .. err); return end
  local t, time_err = env_time(tg, proj_time())
  if not t then tip("VideoKF: " .. time_err); return end
  reaper.Undo_BeginBlock()
  local zoom = eval_param(tg, "zoom", t)
  put_key(tg, "zoom", t, zoom)
  reaper.Undo_EndBlock("VideoKF: keyframe zoom", -1)
  reaper.UpdateArrange()
  tip(("Zoom keyframe @ %s"):format(fmt_t(tg, t)))
end

-- Return all project-time key positions across the three transform envelopes.
local function key_times(tg)
  -- Combine times from all transform axes so navigation stops at every
  -- transform key, even when X, Y, and zoom are keyed independently.
  local times = {}
  for _, key in ipairs({ "x", "y", "zoom" }) do
    local env = get_env(tg, key, false)
    if env then
      for i = 0, reaper.CountEnvelopePoints(env) - 1 do
        local ok, pt = reaper.GetEnvelopePointEx(env, -1, i)
        -- Envelope point times are local to the item; convert them to project time.
        if ok then times[#times + 1] = tg.pos + pt / tg.rate end
      end
    end
  end
  table.sort(times)
  return times
end

-- Move the edit cursor to the next or previous transform keyframe.
local function cmd_nav(direction)
  local tg, err = get_target(false)
  if not tg then tip("VideoKF: " .. err); return end
  local cur, found = proj_time(), nil
  local times = key_times(tg)
  if direction > 0 then
    -- Require a small gap so the current key is not selected repeatedly.
    for _, tm in ipairs(times) do if tm > cur + 1e-4 then found = tm; break end end
  else
    for i = #times, 1, -1 do if times[i] < cur - 1e-4 then found = times[i]; break end end
  end
  if found then reaper.SetEditCurPos(found, true, false)
  else tip("VideoKF: no more keyframes in that direction") end
end

-- Remove X, Y, and zoom points at the playhead, within half a video frame.
local function cmd_delete()
  local tg, err = get_target(false)
  if not tg then tip("VideoKF: " .. err); return end
  local t, time_err = env_time(tg, proj_time())
  if not t then tip("VideoKF: " .. time_err); return end
  local eps, removed = frame_eps(tg), 0
  reaper.Undo_BeginBlock()
  for _, key in ipairs({ "x", "y", "zoom" }) do
    local env = get_env(tg, key, false)
    if env then
      local i = find_point(env, t, eps)
      while i do
        -- Recheck after each deletion because later point indices shift down.
        reaper.DeleteEnvelopePointEx(env, -1, i)
        removed = removed + 1
        i = find_point(env, t, eps)
      end
    end
  end
  reaper.Undo_EndBlock("VideoKF: delete keyframe", -1)
  reaper.UpdateArrange()
  tip(removed > 0 and ("%d keyframe(s) deleted"):format(removed) or "No keyframes here")
end

-- Reset all three parameters. Animated parameters get a point at the playhead;
-- unanimated parameters are reset as static FX values.
local function cmd_reset()
  local tg, err = get_target(false)
  if not tg then tip("VideoKF: " .. err); return end
  local t, time_err = env_time(tg, proj_time())
  if time_err == "no video frame falls inside the selected item" then
    tip("VideoKF: " .. time_err)
    return
  end
  reaper.Undo_BeginBlock()
  for _, key in ipairs({ "x", "y", "zoom" }) do
    set_value(tg, key, t, CFG.DEFAULTS[key])
  end
  reaper.Undo_EndBlock("VideoKF: reset transform", -1)
  reaper.UpdateArrange()
  tip("Position and zoom reset")
end

-- Command names are the ExtState messages sent by optional shortcut scripts.
local COMMANDS = {
  key_pos = cmd_key_position, key_scale = cmd_key_scale,
  next_key = function() cmd_nav(1) end, prev_key = function() cmd_nav(-1) end,
  del_key = cmd_delete, reset = cmd_reset,
}

------------------------------------------------------------------------------
-- MOUSE GESTURES
------------------------------------------------------------------------------
-- Drag state is created on mouse-down and completed on mouse-up. The first
-- few pixels are ignored to avoid turning an ordinary click into a movement.
local drag = nil            -- { nx0, ny0, last_nx, last_ny, started, tg, t, x, y }
local was_left = false

local function drag_begin(d)
  -- Resolve the current target only after the pointer has moved far enough
  -- to count as a drag, so a plain click does not add the FX.
  local tg, err = get_target(true)
  if not tg then tip("VideoKF: " .. err); d.dead = true; return end
  local t, time_err = env_time(tg, proj_time())
  if (is_animated(tg, "x") or is_animated(tg, "y") or is_animated(tg, "zoom")) and not t then
    tip("VideoKF: " .. time_err); d.dead = true; return
  end
  reaper.Undo_BeginBlock()
  d.undo_open = true
  d.tg, d.t = tg, t
  d.x, d.y = eval_param(tg, "x", t), eval_param(tg, "y", t)
  d.started = true
end

local function drag_update(d, nx, ny, fine)
  -- Image overlay offsets move the rendered image by a zoom-dependent amount.
  -- Compensate for zoom so the image follows the pointer at different scales.
  local k = fine and CFG.SHIFT_FINE or 1
  local z = zoom_factor(eval_param(d.tg, "zoom", d.t))
  local offset_scale = 2 / (1 + z)
  local dx = (nx - d.last_nx) * k * offset_scale * (CFG.INVERT_X and -1 or 1)
  local dy = (ny - d.last_ny) * k * offset_scale * (CFG.INVERT_Y and -1 or 1)
  -- Keep the previous pointer position so each update applies only its delta.
  d.last_nx, d.last_ny = nx, ny
  d.x, d.y = d.x + dx, d.y + dy
  set_value(d.tg, "x", d.t, d.x)
  set_value(d.tg, "y", d.t, d.y)
end

local function drag_end(d)
  if d.undo_open then
    reaper.Undo_EndBlock("VideoKF: move image", -1)
    reaper.UpdateArrange()
  end
end

-- Group a burst of wheel events into one undo step.
local wheel_undo_open, wheel_last = false, 0

local function wheel_scale(delta)
  -- Wheel gestures may add the preset, unlike explicit keyboard commands.
  local tg, err = get_target(true)
  if not tg then tip("VideoKF: " .. err); return end
  local t, time_err = env_time(tg, proj_time())
  if not t then tip("VideoKF: " .. time_err); return end
  if not wheel_undo_open then
    reaper.Undo_BeginBlock()
    wheel_undo_open = true
  end
  wheel_last = reaper.time_precise()
  local cur = eval_param(tg, "zoom", t)
  -- Convert a multiplicative zoom step to the preset's logarithmic zoom value.
  local new = cur + 10 * math.log(CFG.SCALE_STEP) / math.log(10) * (delta / 120)
  put_key(tg, "zoom", t, new)
  tip(("Zoom %.0f%%  (keyframe @ %s)"):format(
    zoom_factor(reaper.TakeFX_GetParam(tg.take, tg.fx, tg.idx.zoom)) * 100, fmt_t(tg, t)))
end

local function wheel_flush(force)
  if wheel_undo_open and (force or reaper.time_precise() - wheel_last > 0.5) then
    reaper.Undo_EndBlock("VideoKF: zoom keyframe", -1)
    reaper.UpdateArrange()
    wheel_undo_open = false
  end
end

------------------------------------------------------------------------------
-- DEFERRED INPUT AND COMMAND LOOP
------------------------------------------------------------------------------
local last_under, last_alive = nil, 0

local function loop()
  -- Companion actions use this heartbeat to determine whether this loop is alive.
  -- The timestamp is refreshed once per second and is not saved across REAPER runs.
  local now_s = os.time()
  if now_s ~= last_alive then
    last_alive = now_s
    reaper.SetExtState(EXT, "alive", tostring(now_s), false)
  end

  -- Process at most one pending command message per loop iteration.
  local cmd = reaper.GetExtState(EXT, "cmd")
  if cmd ~= "" then
    reaper.DeleteExtState(EXT, "cmd", false)
    if COMMANDS[cmd] then COMMANDS[cmd]() end
  end

  local mx, my = reaper.GetMousePosition()
  local under = reaper.JS_Window_FromPoint(mx, my)

  -- If startup discovery failed or the preview was recreated, lock onto it
  -- when the pointer first enters its OpenGL surface.
  if under and under ~= last_under then
    last_under = under
    if class_of(under) == CLASS_GL and under ~= gl then
      local parent = reaper.JS_Window_GetParent(under)
      if parent and class_of(parent) == CLASS_MAIN then lock(parent, under) end
    end
  end

  if gl then
    -- js_ReaScriptAPI uses bit flags to report the currently held buttons
    -- and modifiers: left=1, Ctrl=4, Shift=8, and Alt=16.
    local st = reaper.JS_Mouse_GetState(1 + 4 + 8 + 16)
    local left, ctrl, shift, alt =
      (st & 1) ~= 0, (st & 4) ~= 0, (st & 8) ~= 0, (st & 16) ~= 0
    local nx, ny = screen_to_video(mx, my)

    -- Read wheel events from the preview container without consuming them.
    local ok, _, time, wlow, whigh = reaper.JS_WindowMessage_Peek(main, "WM_MOUSEWHEEL")
    if ok and time and time ~= 0 and time ~= last_wheel_time then
      last_wheel_time = time
      if (wlow & 8) ~= 0 then
        local delta = s16(whigh)
        if delta ~= 0 then wheel_scale(delta) end
      end
    end
    wheel_flush(false)

    -- Mouse buttons are polled so drags continue even after leaving the preview.
    if left and not was_left then
      if under == gl and nx then
        if alt then
          cmd_copy_previous_position()             -- Alt + left-click copies the preceding pose.
        elseif ctrl then
          cmd_key_position()                       -- Ctrl + left-click inserts identity X/Y points.
        else
          -- Delay starting the undo block until the drag threshold is crossed.
          drag = { nx0 = nx, ny0 = ny, last_nx = nx, last_ny = ny, started = false }
        end
      end
    elseif left and was_left and drag and not drag.dead and nx then
      if not drag.started then
        -- Start only after the pointer has moved enough to distinguish a drag
        -- from a click intended to insert or copy a keyframe.
        if math.abs(nx - drag.nx0) + math.abs(ny - drag.ny0) > CFG.DRAG_THRESHOLD then
          drag_begin(drag)
          if drag.started then drag.last_nx, drag.last_ny = nx, ny end
        end
      else
        drag_update(drag, nx, ny, shift)
      end
    elseif not left and was_left and drag then
      if drag.started then drag_end(drag) end
      drag = nil
    end
    was_left = left
  end

  reaper.defer(loop)
end

------------------------------------------------------------------------------
-- STARTUP AND CLEANUP
------------------------------------------------------------------------------
local _, _, sec, cmdid = reaper.get_action_context()

reaper.atexit(function()
  -- Close open undo blocks and release JS API hooks if the action is stopped.
  if drag and drag.undo_open then reaper.Undo_EndBlock("VideoKF: move image", -1) end
  wheel_flush(true)
  release_wheel()
  reaper.SetToggleCommandState(sec, cmdid, 0)
  reaper.RefreshToolbar2(sec, cmdid)
end)

reaper.SetToggleCommandState(sec, cmdid, 1)
reaper.RefreshToolbar2(sec, cmdid)
autofind()
loop()