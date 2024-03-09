-- @description Reaticulate - create a filter to prevent reaticulate shows up when using toggle instrument on/off
-- @version 0.1
-- @author Mathieu CONAN
-- @changelog Take care of env lane height but do not change env lane height
-- @about It prevent reaticulate window to be popped up when you use SWS "SWS/S&M: Toggle float FX 1 for selected tracks" to show your VST instrument GUI. Author URI: https://forum.cockos.com/member.php?u=153781
-- @licence GPL v3

--
--[[ CORE ]]--
--
function Main()
	track = reaper.GetSelectedTrack( 0, 0)
	_, fx_name = reaper.TrackFX_GetFXName( track, 0 )
	if fx_name == "JS: Reaticulate" then
		reaper.Main_OnCommand(  reaper.NamedCommandLookup('_S&M_TOGLFLOATFX2'), 0)--SWS/S&M: Toggle float FX 2 for selected tracks
	else
		reaper.Main_OnCommand(  reaper.NamedCommandLookup('_S&M_TOGLFLOATFX1'), 0) --SWS/S&M: Toggle float FX 1 for selected tracks
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
reaper.Undo_EndBlock("MC_Reaticulate - create a filter to prevent reaticulate shows up", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
