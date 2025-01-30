--[[
Description: MIDI Editor - Set time selection to item length
Author: Mathieu CONAN   
Version: 0.0.1
Changelog:  initial release
Link: Github repository https://github.com/MathieuCGit/Reaper_Tools
About: Load this script as a midi editor one. Set mouse modifier to "MIDI ruler" > ctrl+double click > use this script
--]]

function Main()

	local getActiveMidiEditor = reaper.MIDIEditor_GetActive() -- Get opened midi editor informations
	local take=reaper.MIDIEditor_GetTake(getActiveMidiEditor) -- Get current take being edited in MIDI Editor

	-- Get take length in seconds from item
	item = reaper.GetMediaItemTake_Item(take) -- get item from take
	item_startPos=reaper.GetMediaItemInfo_Value( item, "D_POSITION")-- get start of item
	item_length=reaper.GetMediaItemInfo_Value( item, "D_LENGTH")-- get item length
	item_endPos=item_startPos+item_length -- get start of item
	
	--set time selection / loop
	reaper.GetSet_LoopTimeRange2( 0, 1, 1, item_startPos, item_endPos, 1 )

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
reaper.Undo_EndBlock("MIDI Editor - Set time selection to item length", - 1)

-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)