-- @description If top level folder is collapsed, script uncollapsed (and vice versa)
-- @version 0.1
-- @author Mathieu CONAN
-- @changelog init
-- @about This script aims to provide fast way to collapse uncollapse top level folders (often BUS folders), making it easier to switch from instrument groups (for example: drums, keys,strings,etc.). It works even if you have tracks selected accros multiple folders
-- @licence GPL v3
 
 
---This function get the top level track folder from a given track even if there are other folders in the between
function get_top_level_track(track)
	while true do
		local parent = reaper.GetParentTrack(track)
		if parent then
			track = parent
		else
			return track
		end
	end
end
	
--
--[[ CORE ]]--
--
function Main()

	nbr_sel_tr= reaper.CountSelectedTracks2( 0, 0 )
	
	-- set a token to know if next track is in the same top level folder as previous track
	local token = 1
	for i=0, nbr_sel_tr-1 do
	--for each selected track we get infos
		track= reaper.GetSelectedTrack2( 0, i, 0)
		folder= get_top_level_track(track)
		folder_guid= reaper.GetTrackGUID( folder )

		--get the track GUID for next track 
		if reaper.GetSelectedTrack2(0,i+1,0) then
			next_track= reaper.GetSelectedTrack2( 0, i+1, 0)
			next_folder= get_top_level_track(next_track)
			next_folder_guid =  reaper.GetTrackGUID(next_folder)
		end

		--if toek is set to 1 we toggle collapsed state (it means either we are in one top level folder or in another top level folder if we have selected tracks accross top level folders)
		if token == 1 then
			collapsed_state=reaper.GetMediaTrackInfo_Value( folder, "I_FOLDERCOMPACT" )
			if collapsed_state == 0.0 then
				reaper.SetMediaTrackInfo_Value( folder, "I_FOLDERCOMPACT", 2.0 )
			elseif collapsed_state == 2.0 then
				reaper.SetMediaTrackInfo_Value( folder, "I_FOLDERCOMPACT", 0.0 )
			end
		--we reset the token for next track analysis
		token =0
		end
		
		--the token switch to 1 if we are not in the same top level. This case is for tracks selected accross multiples folders
		if folder_guid ~= next_folder_guid then
			token=1
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
reaper.Undo_EndBlock("MC_(un)collapse top level folders", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)