-- @description Convert empty item notes to markers
-- @author Mathieu CONAN   
-- @version 0.1
-- @changelog init
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about This script convert text notes from the empty media item to markers
--

--
--
--[[ CORE ]]--
--

function Main()

  local project = 0
  local num_items = reaper.CountMediaItems(project)

  for i = 0, num_items - 1 do
    local item = reaper.GetMediaItem(project, i)
    local take = reaper.GetActiveTake(item)

    -- Check if the item is an "empty item"
    if not take then
      local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local note = reaper.ULT_GetMediaItemNote(item) -- Récupère la note de l'item

      if note and note ~= "" then
        -- create a marker at item start with the text contains in item text note
        reaper.AddProjectMarker(project, false, position, 0, note, -1)
      end

    end
  end

end


--
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
reaper.Undo_EndBlock("MC_sandbox", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)