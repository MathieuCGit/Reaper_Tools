--[[
Description: Remove time selection if exist, otherwise close MIDI editor.
Author: Mathieu CONAN   
Version: 0.1
Changelog:  initial release
Link: Github repository https://github.com/MathieuCGit/Reaper_Tools
About: In tha active MIDI editor window, this script chekc if a time selection exists. If yes, it remove it. Otherwise, it mimicks the default Reaper behaviour by closing the midi editor window.
Be aware that time selection is also removed from main Arrange view.
--]]

function Main()
 
	-- Get active midi editor HWND
	local hwnd = reaper.MIDIEditor_GetActive()

	-- Get current take being edited in MIDI Editor
	local take = reaper.MIDIEditor_GetTake(hwnd)
    if not take or not reaper.TakeIsMIDI(take) then return end
	
	-- get current time selection values
	startOut, endOut = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false) 

	if startOut == 0 and endOut == 0 then 
		reaper.MIDIEditor_OnCommand(hwnd, 40477) --Misc: Close window if not docked, otherwise pass to main window
	else
		reaper.MIDIEditor_OnCommand(hwnd, 40467) --Time selection: Remove time selection and loop points
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
reaper.Undo_EndBlock("Remove time selection if exist, otherwise close MIDI editor", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)