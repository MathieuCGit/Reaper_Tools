--[[
 * ReaScript Name: Item Tracking During Playback
 * Version: 0.1
 * Author: Mathieu CONAN
 * Description: This script continuously selects the item on selected track at the play cursor position. It acts as a toggle script.
]]

-- Define a global variable to keep track of the last selected item
local last_selected_item = nil

-- Function to update item selection at play cursor
function selectItemAtPlayCursor()
  -- Get the current position of the play cursor
  local play_cursor_pos = reaper.GetPlayPosition()
  
  -- Count the number of selected tracks
  local selected_tracks_count = reaper.CountSelectedTracks(0)

  -- Variable to store the item at play cursor
  local item_at_play_cursor = nil
  
  -- Loop through each selected track
  for i = 0, selected_tracks_count - 1 do
    -- Get the selected track
    local track = reaper.GetSelectedTrack(0, i)
    
    -- Count the number of items on the track
    local item_count = reaper.CountTrackMediaItems(track)
    
    -- Loop through each item on the track
    for j = 0, item_count - 1 do
      -- Get the item
      local item = reaper.GetTrackMediaItem(track, j)
      
      -- Get the position and length of the item
      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      
      -- Check if the play cursor is within the item
      if play_cursor_pos >= item_pos and play_cursor_pos <= (item_pos + item_len) then
        item_at_play_cursor = item
        break
      end
    end
    
    -- Exit the loop early if we found the item at the play cursor
    if item_at_play_cursor then
      break
    end
  end
  
  -- Update selection only if the item has changed
  if item_at_play_cursor ~= last_selected_item then
    -- Unselect all items
    reaper.Main_OnCommand(40289, 0) -- Unselect all items
    
    if item_at_play_cursor then
      -- Select the new item
      reaper.SetMediaItemSelected(item_at_play_cursor, true)
      last_selected_item = item_at_play_cursor
    else
      last_selected_item = nil
    end
    
    -- Update the arrange view to reflect the selection
    reaper.UpdateArrange()
  end

  -- Defer the function to run again
  reaper.defer(selectItemAtPlayCursor)
end

-- Toggle script
local is_new_value, filename, sectionID, cmdID, mode, resolution, val = reaper.get_action_context()
local state = reaper.GetToggleCommandState(cmdID)
if state == 1 then
  -- If script is running, stop it
  reaper.SetToggleCommandState(sectionID, cmdID, 0)
else
  -- If script is not running, start it
  last_selected_item = nil -- Reset last selected item
  reaper.SetToggleCommandState(sectionID, cmdID, 1)
  reaper.defer(selectItemAtPlayCursor)
end
reaper.RefreshToolbar2(sectionID, cmdID)
