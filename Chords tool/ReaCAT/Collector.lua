-- @noindex

--- ReaCAT - Collector
--
-- This module aims to get the notes (selected, not selected, all item notes,etc.)in a chord.
-- It only works for the active take passed as an argument.
-- @module Collector

-------------------
-- Define Class Attributes
-----------------------------

Collector = {
	--- Start of the chord in ppq
	--
	-- @meta read-only
	-- @type number
	chord_start=0,
	
	--- end of the chord in ppq
	--
	-- @meta read-only
	-- @type number
	chord_end=0
}

-----------------------------
-- Define Class Methods
-----------------------------

--- PRIVATE METHODS
-- @section private methods

--- *table.sort()* is a very limited  and unstable function in lua while dealing with multidimensionnal array
--so we made another method.
--@tparam tab array array containing the datas you want to sort
--@tparam mixed idx can a number or a string depending on array construction. For example : array[2]["name"] work if you previously construct your array with a string (here "name").
--@treturn tab array is an array containing datas sorted
--
--@note
--   more informations can ba found here : [http://www.lua.org/manual/5.4/manual.html#pdf-table.sort](http://www.lua.org/manual/5.4/manual.html#pdf-table.sort)
function array2Dsort(array,idx)
		local tmp={}
		for i=1, #array do
			for j=1, #array do
				if array[i][idx] < array[j][idx] then
					tmp[i]=array[i]
					array[i]=array[j]
					array[j]=tmp[i]
				end
			end
		end
	return array
end	

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

		--if no notes are selected, it's the same as if all notes were selected
		-- if numSel == 0 then
			-- numSel = notes
		-- end
	end
	return numSel
end

--- Basic function to rebuild a 2D array index as LUA use tables and tables are not indexed the same way an array is.
--@tparam tab array is the array you want to rebuild the index
--@treturn tab new_array is the array reindexed from 1
--@see array2Dsort()
function rebuild_index(array)
	local new_array={}
	j=1
		for i, v in pairs(array) do
			new_array[j]={pitch = v.pitch,startppqpos=v.startppqpos,endppqpos=v.endppqpos,pos_idx=v.pos_idx}
			j=j+1
		end
	
	new_array=array2Dsort(new_array,"pitch")
	return new_array
end

--- PUBLIC METHODS
-- @section public methods

---This method aims to provide various informations about grid (division, number of PPQ per grid divisoin unit).
-- @example 
--  for example, if we have a 4/4 metric, grid division is 1.
--
--@tparam take take the active take in current midi editor
--@treturn int grid_division 
--@treturn int nbr_ppq_in_grid_division
function Collector:grid_infos(take)

 	-- get grid division used by user
		item = reaper.GetMediaItemTake_Item(take)
		item_startPos=reaper.GetMediaItemInfo_Value( item, "D_POSITION")
		_, _, cml, _, cdenom = reaper.TimeMap2_timeToBeats(0,item_startPos) --Get time signature
		grid_division, _, _ = reaper.MIDI_GetGrid(take)

	--if cml value is upper than 4 (for example 5/4 or 7/4) we use it as reference
	if cml > 4 and grid_division == 4 then
		nbr_ppq_in_grid_division=cml * 960
	else
		nbr_ppq_in_grid_division = grid_division * 960
	end
	
	return grid_division,nbr_ppq_in_grid_division
end

--- This method aims to create a pitch indexed array of notes in the active take. If no notes are selected, the entire active take notes are put into the array.
--
--@tparam take take is the active take (mainly means midi editor opened take)
--@treturn tab indexed_pitch_array is an array containing notes pitch. Index array start at 1.
--@see nbr_selected_notes()
function Collector:get_pitch_array(take)
	nbrSelNotes=nbr_selected_notes(take) --get nbr of selected notes in the active take. See related function
	
	-- Get notes pitch in an array
	local pitch_array={}
	_, notes, _, _ = reaper.MIDI_CountEvts(take)
	if notes > 0 then
		if nbrSelNotes > 0 then
		--if there are selected notes
			for i=0, notes - 1 do
				_, selected, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote( take, i )
				if selected then -- and the current one is selected
					--we put it in pitch_array
					pitch_array[i]={pitch = pitch,startppqpos=startppqpos,endppqpos=endppqpos}
				end
			end
		else --otherwise there are no notes selected so we put every notes in the take into pitch_array
			for i=0, notes - 1 do
				_, _, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote( take, i )
				pitch_array[i]={pitch = pitch,startppqpos=startppqpos,endppqpos=endppqpos}
			end
		end
	end
	
	-- because table are not indexed array and we want an array behaviour we have to avoid gap in table, we need to rebuild an index. for example, pitch_array can be : {[5]=33,[6]=40,[8]=42} and we want it to be {[1]=33,[2]=40,[3]=42}
	indexed_pitch_array=rebuild_index(pitch_array)
	return indexed_pitch_array
	
end

--- This method creates a new field in the indexed_pitch_array containing the chord index position start and end. The method take care of human input, if there is less than a 32th note between to notes, they are parts of the same chord.
--
--@tparam tab indexed_pitch_array
--@tparam take a Reaper take
--
--@treturn tab sorted_by_startppqpos is a table of chords indexed by their position
function Collector:chord_pos(indexed_pitch_array,take)

	sorted_by_startppqpos=array2Dsort(indexed_pitch_array,"startppqpos")
	
	--Put a chord index into pitch_array
	pos_idx=1 -- Here is the first chord index
	human_input=119 -- while a human inputs notes, startppqpos and endppqpos aren't as precise as quantized inputs. Default reaper ppqn = 960, means 960 midi ticks per quarter note. 120 is 960 / 8, means thirty-two notes of precision. So if the inputed notes are separate by less than a 32th notes (119), we consider them as part of the same chord.
	for i=1, #sorted_by_startppqpos -1 do
		sorted_by_startppqpos[i].pos_idx=pos_idx
		if sorted_by_startppqpos[i+1].startppqpos-human_input > sorted_by_startppqpos[i].startppqpos then
			pos_idx=pos_idx+1
		elseif sorted_by_startppqpos["#sorted_by_startppqpos"] == nil  then --last table value
			sorted_by_startppqpos[i+1].pos_idx=pos_idx
		end
	end
	return sorted_by_startppqpos
end



-----------------------------
-- Define Class Constructor
-----------------------------

function Collector:new(t)
	t=t or {}
	setmetatable(t,self)
	self.__index=self
	return t
end
