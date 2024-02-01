<<--[[--
   * ReaScript Name: Toggle solo track under mouse
   * Lua script for Cockos REAPER
   * Author: Mathieu CONAN
   * Author URI: https://forum.cockos.com/member.php?u=153781
   * Licence: GPL v3
   * REAPER: 7.0
   * version: 0.3
   * Extensions: None
--]]

--

--
--[[ CORE ]]--
--
function Main()

	reaper.Main_OnCommand( 41110, 0 ) --Track: Select track under mouse
	track=reaper.GetSelectedTrack( 0, 0 )

	if reaper.GetMediaTrackInfo_Value(track, 'B_MUTE') == 1 then
		reaper.SetMediaTrackInfo_Value(track, 'B_MUTE', 0)
	else
		reaper.SetMediaTrackInfo_Value(track, 'B_MUTE', 1)
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
