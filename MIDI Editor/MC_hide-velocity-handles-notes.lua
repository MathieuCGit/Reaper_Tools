--[[
Description: MIDI Editor - force option "View: Show velocity handles on notes" to off
Author: Mathieu CONAN   
Version: 0.1
Changelog:  initial release
Link: Github repository https://github.com/MathieuCGit/MC_VariousScripts
About: force the MIDI Editor option "View: Show velocity handles on notes" to toggle state off
--]]


function Main()

	local Command_ID = "40040" -- View: Show velocity handles on notes
	local section_id = 32060 --0/100=main/main alt, 32063=media explorer, 32060=midi editor, 32061=midi event list editor, 32062=midi inline editor)
	local active_midi_editor = reaper.MIDIEditor_GetActive() -- Get opened midi editor informations
	
	if section_id then --if we are focused on midi editor
		--and if the "Show velocity handles on notes" is on
		if reaper.GetToggleCommandStateEx(section_id, Command_ID) == 1 then
			--we switch it to off
			reaper.MIDIEditor_OnCommand( active_midi_editor, Command_ID )
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
reaper.Undo_EndBlock("MIDI Editor - Show velocity handles on notes", - 1)

-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)