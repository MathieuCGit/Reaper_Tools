-- @description collapse / uncollapse folder folder containing track under mouse cursor
-- @version 0.1
-- @author Mathieu CONAN
-- @changelog init
-- @about This script aims to provide fast way to collapse uncollapse folders, making it easier to switch from instrument groups (for example: drums, keys,strings,etc.). It works even if you have tracks selected accros multiple folders
-- @licence GPL v3

--
--[[ CORE ]]--
--
function Main()
	-- Get mouse position
	local mouseX, mouseY = reaper.GetMousePosition()
	-- Get track ID under mouse cursor
	local track, context, info = reaper.GetTrackFromPoint(mouseX, mouseY)

	-- if there is a track under mosue cursor
	if track then
	-- we check if the track is a folder
	local isFolder = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
	
		if isFolder > 0 then
			-- The track is a folder, we check if it's collpased or not
			local collapsed = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
			if collapsed == 0 then
				-- track is not collapsed do we collapse
				reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)
			else
				-- track is already collapsed so we uncollapsed
				reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
			end
		else
			-- The track is not a folder
			local parentTrack = reaper.GetParentTrack(track)
			if parentTrack then
				-- if thare is a parent track, current track is in a folder so we collapse
				reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERCOMPACT", 2)
			end
		end
	end
end

--
--
--[[ EXECUTION ]]--
--

-- clear console debug
reaper.ShowConsoleMsg("")

reaper.PreventUIRefresh(1)

-- Begining of the undo block. Leave it at the top of your main function.
reaper.Undo_BeginBlock() 

-- execute script core
Main()

-- End of the undo block. Leave it at the bottom of your main function.
reaper.Undo_EndBlock("MC_(un)collapse folders", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)