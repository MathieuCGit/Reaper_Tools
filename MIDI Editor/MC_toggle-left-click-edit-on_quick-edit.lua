-- @description MIDI Editor - Quick edit: Toggle the left click between entering notes or default behaviour (move edit cursor)
-- @link Github repository  https://forum.cockos.com/member.php?u=153781
-- @author Mathieu CONAN
-- @changelog initial release
-- @about This script aims to provide a quic way to enter notes in the midi editor by toggling between the default behaviour (left click move edit cursor), and a mouse modifier option : left click enter note
-- @licence GPL v3

--
--[[ CORE ]]--
--
function Main()
	
--Modifier flag is a number from 0 to 15: add 1 for shift, 2 for control, 4 for alt, 8 for win.	
	local context = "MIDI Piano Roll left click"                  
	local modifier = 0                                        
	local firstActionID = "4 m" 
	local secondActionID = "1 m"

	--get the current state of button
	local _,_,_,currentCommandID = reaper.get_action_context()

	if reaper.GetMouseModifier(context, modifier) == secondActionID then
		--change the mouse modifier action
		reaper.SetMouseModifier(context, modifier, firstActionID)
		-- change action toggle state in action lists
		reaper.SetToggleCommandState(0, currentCommandID, 1)
	else
	  reaper.SetMouseModifier(context, modifier, secondActionID)
	  reaper.SetToggleCommandState(0, currentCommandID, 0)
	end

	--refresh MIDI piano roll toolbar
	reaper.RefreshToolbar2(0, currentCommandID)
	
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
reaper.Undo_EndBlock("Quick Edit Toggle", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
