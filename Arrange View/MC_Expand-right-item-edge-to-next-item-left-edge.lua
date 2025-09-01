-- @description Extend right edge of selected items until the left edge of the next item.
-- @version 0.1
-- @author Mathieu CONAN
-- @changelog init
-- @about This script extends the right edge of each selected item until the left edge of the next item on the same track.  
--        It works across multiple tracks: each item is extended independently within its own track.  
--        Useful to automatically fill gaps between items without overlapping.
-- @license GPL v3

--
--[[ CORE ]]--
--
function Main()


  -- Get the number of selected items in the project
  local count = reaper.CountSelectedMediaItems(0)

  -- Store all selected items in a table
  local items = {}
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(items, item)
  end

  -- Process each selected item independently
  for i, item in ipairs(items) do
    local track = reaper.GetMediaItemTrack(item)
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") -- item start position
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")   -- item length
    local item_end = item_pos + item_len                               -- item end position

    -- Search for the closest item to the right on the same track
    local next_item_start = nil
    local track_items = reaper.CountTrackMediaItems(track)
    for j = 0, track_items - 1 do
      local it = reaper.GetTrackMediaItem(track, j)
      if it ~= item then
        local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
        -- Check if this item is after the current one, and if it is closer than any previously found
        if pos >= item_end and (not next_item_start or pos < next_item_start) then
          next_item_start = pos
        end
      end
    end

    -- If a next item exists, extend current item to its left edge
    if next_item_start then
      local new_len = next_item_start - item_pos
      if new_len > 0 then
        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", new_len)
      end
    end
  end
end


--
--[[ EXECUTION ]]--
--

-- clear console debug
reaper.ClearConsole()

reaper.PreventUIRefresh(1)

-- Begining of the undo block. Leave it at the top of your main function.
reaper.Undo_BeginBlock() 

-- execute script core
Main()

-- End of the undo block. Leave it at the bottom of your main function.
reaper.Undo_EndBlock("Extend right edge of selected items until the left edge of the next item", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)