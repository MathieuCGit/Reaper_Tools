--[[--
   * ReaScript Name: MC_Toggle solo track under mouse
   * Lua script for Cockos REAPER
   * Author: Mathieu CONAN
   * Author URI: https://forum.cockos.com/member.php?u=153781
   * Licence: GPL v3
   * REAPER: 7.0
   * version: 0.1
   * Extensions: None
--]]

--

--
--[[ CORE ]]--
--
function Main()

	--get the mouse context to be sure the cursor is over a track
	_, segment, _ = reaper.BR_GetMouseCursorContext()
	
	reaper.Main_OnCommand( 41110, 0 ) --Track: Select track under mouse
	track=reaper.GetSelectedTrack( 0, 0 )
	
	if segment == "track" then
		if reaper.GetMediaTrackInfo_Value(track, 'I_SOLO') == 0 then
			reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
		else
			reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
		end
	end

end


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
reaper.Undo_EndBlock("MC_Toggle solo track under mouse", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
