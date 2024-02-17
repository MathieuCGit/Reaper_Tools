-- @description Convert MIDI arp to chord
-- @author Mathieu CONAN   
-- @version 0.2
-- @changelog Fix random issue due to Reaper overlapping action implementation
-- @about This script aims to convert a bunch of selected notes into a chord into the active MIDI editor, according to grid division settings.

--
--[[ FUNCTIONS ]]--
--
	--- Get the number of selected note in a MIDI take.
	--@tparam take take is a Reaper take
	--@treturn int is the number of selected notes
	function nbr_selected_notes(take)
		local numSel=0
		if take ~= nil then
			_, notes, _, _ = reaper.MIDI_CountEvts(take) -- count all notes(events)
			if notes > 0 then
				for i=0, notes-1 do
					_, sel,_,_,_,_,_,_ = reaper.MIDI_GetNote(take, i)
					if sel == true then
						numSel=numSel+1
					end
				end
			end
		end
		return numSel
	end
--
--[[ CORE ]]--
--
function Main()

	--Get the opened MIDI editor
	active_midi_editor=reaper.MIDIEditor_GetActive()
	--Get the active take for this MIDI editor
	take= reaper.MIDIEditor_GetTake(active_midi_editor)
	--Get the related item (parent) for the actual take
	item= reaper.GetMediaItemTake_Item( take )
	-- Ticks per quater note will be the unit used instead of second.
	grid_div, _, _ = reaper.MIDI_GetGrid(take)
	--we need the number of tick per quater note for each grid division
	ppq_in_grid_div = grid_div * 960
	
	--We need to know the number of ticks per quater note for the entire take
	item_start=reaper.GetMediaItemInfo_Value( item, "D_POSITION")
	item_len=reaper.GetMediaItemInfo_Value( item, "D_LENGTH")
	item_end=item_start+item_len
	ppq_in_take = reaper.MIDI_GetPPQPosFromProjTime(take, item_end)
	
	--now we can get the number of grid division we will have to loop throught
	nbr_grid_div=ppq_in_take/ppq_in_grid_div
	
	--nbr of midi notes in the active take
	_, nbr_notes, _, _ = reaper.MIDI_CountEvts(take)
	
	grid_div_start=0
	grid_div_end=ppq_in_grid_div

	if nbr_selected_notes(take) == 0 then
		reaper.MB( "Please select at least one note", "No note selected", 0)
	else
		--for example, for each half note (grid div=2)
		for i=1, nbr_grid_div do
			--we go throught every notes in the active take
			for j=0, nbr_notes do
				--and get some informations. Is the note selected, its start position and end position
				_, selected, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote( take, j )
				if selected and startppqpos >= grid_div_start and endppqpos <= grid_div_end then
					--we change note information to set its start and end at the grid div (for example half note)
					reaper.MIDI_SetNote( take, j, 1,0, grid_div_start, grid_div_end)
				end
			end
			
			--prepare next section start and end. For example if grid_div is set to 2.0 (half notes) we take start and end of next half note.
			--Once the loop will have run 2 times we have got throught 1 measure.
			grid_div_start=grid_div_start+ppq_in_grid_div
			grid_div_end=grid_div_end+ppq_in_grid_div

		end
		
		--join selected overlapping notes
		reaper.MIDIEditor_OnCommand( active_midi_editor, 40456 ) --Edit: Join notes
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
reaper.Undo_EndBlock("Convert MIDI arp to chord", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)