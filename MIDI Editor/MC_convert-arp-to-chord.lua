-- @description Convert MIDI arp to chord
-- @author Mathieu CONAN   
-- @version 0.3
-- @changelog Total rebuild with stronger implementation ( first part = data collect then second part = remove selected notes then, last part = write new data).
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

	-- Function to remove duplicates based on pitch, start, and endppqpos values.
	--@tparam inputTable data a table like inputTable={{pitch=48, endppqpos=3840.0, start=0, sel=true}{pitch=55, endppqpos=3840.0, start=0, sel=true} etc..}
	--@treturn result table with duplicates removed
	function removeDuplicates(inputTable)
		local seen = {} -- Table to store encountered entries
		local result = {} -- Table to store unique entries

		for _, entry in ipairs(inputTable) do
			local subEntry = entry[1] -- Assuming the relevant fields are in the first sub-table
			if subEntry then
				local pitch = subEntry.pitch
				local start = subEntry.start
				local endppqpos = subEntry.endppqpos

				if pitch and start and endppqpos then
					--we create a new string pattern we will check into for duplicates
					local key = tostring(pitch) .. "_" .. tostring(start) .. "_" .. tostring(endppqpos)
					if not seen[key] then
						table.insert(result, entry)
						seen[key] = true
					end
				end
			end
		end

		return result
	end
	
--
--[[ CORE ]]--
--
function Main()

----------------------------------------
--[[	COLLECTING TAKE/ITEM DATA	]]--
----------------------------------------
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
	
	--we start at the beginning of the take and use the grid division as 1srt end
	grid_div_start=0
	grid_div_end=ppq_in_grid_div


	------------------------------------
	--[[	COLLECTING NOTES DATA	]]--
	------------------------------------	
	if nbr_selected_notes(take) == 0 then
		reaper.MB( "Please select at least one note", "No note selected", 0)
	else
		--This array will contain collected data
		local notes_array={}
		--This array wil contain data with duplicates removed
		local cleaned_arr={}
			
		for l=1, nbr_grid_div do
		--for example, for each half note (grid div=2)
			--we go throught every notes in the active take
			for j=0, nbr_notes do
				--and get some informations. Is the note selected, its start position and end position
				_, j_sel, _, j_start, j_end, _, j_pitch, _ = reaper.MIDI_GetNote( take, j )
				if j_sel and j_start >= grid_div_start and j_end <= grid_div_end then
					--we change note information to set its start and end at the grid div (for example half note)
					entry={{sel=j_sel,start=grid_div_start,endppqpos=grid_div_end,pitch=j_pitch}}
					table.insert(notes_array,entry)
				end
			end
			
			--prepare next section start and end. For example if grid_div is set to 2.0 (half notes) we take start and end of next half note.
			--Once the loop will have run 2 times we have got throught 1 measure.
			grid_div_start=grid_div_start+ppq_in_grid_div
			grid_div_end=grid_div_end+ppq_in_grid_div
		end


	 --------------------------------------------
	 --[[	CLEAN AND REMOVE DUPLICATES		]]--
	 --------------------------------------------		
		--remove duplicates entries from the table
		cleaned_arr=removeDuplicates(notes_array)
		
		--remove selected notes from MIDI take
		reaper.MIDIEditor_OnCommand( active_midi_editor,40002) --Edit: Delete notes


	 ----------------------------------------
	 --[[	POPULATE TAKE WITH NEW DATA	]]--
	 ----------------------------------------		
		--we populate the empty MIDI take with data from our cleaned array
		for _, entry in ipairs(cleaned_arr) do
			local subEntry = entry[1] -- Assuming the relevant fields are in the first sub-table
			if subEntry then
				local sel = subEntry.sel
				local pitch = subEntry.pitch
				local start = subEntry.start
				local endppqpos = subEntry.endppqpos
				
				reaper.MIDI_InsertNote(take, 
						sel, -- Selected flag
						false, -- Muted flag
						start, -- Start position
						endppqpos, -- End position
						0, -- Channel (0-based)
						pitch, -- Pitch
						100, --velocity
						true --No sort
						)
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
reaper.Undo_EndBlock("Convert MIDI arp to chord", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)