--@noindex

--- ReaCAT - Write Data
--
-- This module aims to write chords symbols where you want to get them inputed into reaper.
-- @module WriteData

----------------
-- Define Class Attributes
-----------------------------

WriteData = {
	notation=true,
	text_event=true,
	text_item=true,
	text_event_and_notation=true
}

-----------------------------
-- Define Class Methods
-----------------------------

--- PRIVATE METHODS
-- @section private methods

	--- Find if a track named <code>name</code> exists
	--@tparam string name is the name of the track we are looking for
	function get_track_by_name(name)

		for trackIndex = 0, reaper.CountTracks(0) - 1 do

			local track = reaper.GetTrack(0, trackIndex)
			local ok, trackName = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)

			if ok and trackName == name then
				return track -- found it! stopping the search here
			end
		end

	end	

	--- This function aims to detect if we deal with a chord symbol or with another kind of string
	--@tparam string str is the string we want to know  if it's a chord or not
	--@treturn bool is set to 1 if **str** is a chord and 0 if it's not a chord
	--  @note The Lua regex is this one
	--
	--    @code
	--
	--        --Split parsing in several variables to make imrpovment, future combinations and debugging easier
	--        chord_root="[A-G][#]?[b]?"
	--        chord_min_sus_5="[s]?[u]?[s]?[2]?[4]?[m]?[5]?"
	--        chord_6_7="[M]?[6]?[7]?"
	--        chord_alt_5="[%(]?[#b]?[5]?[%)]?"
	--        chord_alt_9="[#b]?[9]?"
	--        chord_alt_11="[%/]?[#]?[11]?"
	--        chord_alt_13="[%/]?[b]?[13]?"
	--        chord_inverted="[%/]?[A-G]?[#b]?"
	--        -- combinations for text event lane and notation view
	--        chord_total_regex_text_event="^("..chord_root..chord_min_sus_5..chord_6_7..chord_alt_5..chord_alt_9..chord_alt_11..chord_alt_13..chord_inverted..")"
	--        chord_total_regex_notation=notationEventPrefix.."("..chord_root..chord_min_sus_5..chord_6_7..chord_alt_5..chord_alt_9..chord_alt_11..chord_alt_13..chord_inverted..")"
	--
	function is_a_chord(str)
	
			--detect UTF 8 sharp and flat characters in str and convert to ASCII
			str=string.gsub(str,utf8.char(9837),"b",3)
			str=string.gsub(str,utf8.char(9839),"#",3)
			
			--set parsing options
			notationEventPrefix="^TRAC text "
			
			-- Split parsing in several variables to make imrpovment, future combinations and debugging easier
			chord_root="[A-G][#]?[b]?"
			chord_min_sus_5="[s]?[u]?[s]?[2]?[4]?[m]?[5]?"
			chord_6_7="[M]?[6]?[7]?"
			chord_alt_5="[%(]?[#b]?[5]?[%)]?"
			chord_alt_9="[#b]?[9]?"
			chord_alt_11="[%/]?[#]?[11]?"
			chord_alt_13="[%/]?[b]?[13]?"
			chord_inverted="[%/]?[A-G]?[#b]?"
			
			-- combinations for text event lane and notation view
			chord_total_regex_text_event="^("..chord_root..chord_min_sus_5..chord_6_7..chord_alt_5..chord_alt_9..chord_alt_11..chord_alt_13..chord_inverted..")"
			chord_total_regex_notation=notationEventPrefix.."("..chord_root..chord_min_sus_5..chord_6_7..chord_alt_5..chord_alt_9..chord_alt_11..chord_alt_13..chord_inverted..")"
			
	local	is_a_chord=0
		if #str > 0 then
			if str:find(chord_total_regex_text_event) or str:find(chord_total_regex_notation) then is_a_chord= true
			else is_a_chord=false
			end
		end
		
	return is_a_chord
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

--- PUBLIC METHODS
-- @section public methods

	--- Remove existing chord items on "CHORDS" track.
	--@tparam number nbr_sel_items is the number of selected items on track.
	--
	-- @note 
	--    TODO: The start and end location for note selection should be in Collector class
	function WriteData:del_existing_chord_items(nbr_sel_items)
		--chords text items are on the CHORDS track, we select it.
		track = get_track_by_name("CHORDS")
		
		local cur_start=0
		local cur_end=0
		-- TODO: the following function should be integrated into Collector.lua
		--Check if MIDI editor is opened and if notes are selected into active midi take
		if reaper.MIDIEditor_GetActive() then
			--we get the current take
			take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
			--we check if notes are selected
			_, notes, _, _ = reaper.MIDI_CountEvts(take) -- count all notes(events)
			if notes > 0 then
				--find start of the selection in active MIDI take
				for i=notes-1, 0,-1  do
					_, sel,_,startppqpos,_,_,_,_ = reaper.MIDI_GetNote(take, i)
					if sel  then cur_start=startppqpos end
				end
				
				if cur_start ~=nil then 
					cur_start= reaper.MIDI_GetProjTimeFromPPQPos( take, cur_start )--convert ppq into seconds 
				end
				
				--find end of the selection in active MIDI take
				for i=0, notes-1 do
					_, sel,_,_,endppqpos,_,_,_ = reaper.MIDI_GetNote(take, i)
					if sel and cur_end < endppqpos then cur_end=endppqpos end
				end
				
				if cur_end ~=nil then
					cur_end= reaper.MIDI_GetProjTimeFromPPQPos( take, cur_end )--convert ppq into seconds
				end
			end
			
		end
		
			
		--if no notes are selected into the active MIDI take, we based our removal stuff on item context.
		if cur_start ==0 and cur_end==0 then
			--we need the start position of the first item in selection
			first_item = reaper.GetSelectedMediaItem(0, 0)
			if not first_item then return end
			start_first_item=reaper.GetMediaItemInfo_Value( first_item, "D_POSITION" )
		
			for i=0, nbr_sel_items-1 do
				item = reaper.GetSelectedMediaItem(0, i)
				start_cur_item=reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
				len_cur_item=reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
				end_last_item=start_cur_item+len_cur_item
			end
		else
		--else we use the start and end position from the active MIDI take note selection
			start_first_item=cur_start
			start_cur_item=cur_start
			end_last_item=cur_end
		end
		
		if track then
			--we will loop throught the entire track 
			nbr_item_on_track= reaper.CountTrackMediaItems(track)
			--we have to iterate backwards to avoid missing index in the loop as we potentialy remove item(s) on each loop
			for i=nbr_item_on_track-1,0,-1 do

				item=reaper.GetTrackMediaItem( track, i)
				start_cur_item=reaper.GetMediaItemInfo_Value( item, "D_POSITION" )

				if start_cur_item >= start_first_item and start_cur_item < end_last_item then
					reaper.DeleteTrackMediaItem(track, item)
				end

			end
		end
		
	end
	
	--- Remove existing chord symbols.
	--@tparam take take is a reaper take type data
	function WriteData:del_existing_chord_symbols(take)
	
		if take ~= nil then
			--get MIDI take infos from current take
			_, notes, _, textsyxevtcnt = reaper.MIDI_CountEvts(take)
			
			--Are we dealing with selected notes?
			if notes > 0 then
				while notes >= 0 do
					_, selected, _, startppqpos, _, _, _, _ = reaper.MIDI_GetNote( take, notes )
						if selected then
							ppqPointerSel=startppqpos
						end
				notes=notes-1
				end
			end

			--if we have selected chord we only delete selected chord
			if ppqPointerSel ~= nil then
				for i = textsyxevtcnt-1, 0, -1  do
					_, _, _, ppqpos, _, msg = reaper.MIDI_GetTextSysexEvt( take, i)
					if is_a_chord(msg) == true then
						if ppqpos == ppqPointerSel then
						--if textevent are at the ppq of the further left chord note
						--we delete it.
							reaper.MIDI_DeleteTextSysexEvt( take, i)
						end
					end
				end
			else
			--else we delete every chord symbol
				for i = textsyxevtcnt-1, 0, -1  do
					_, _, _, ppqpos, _, msg = reaper.MIDI_GetTextSysexEvt( take, i)
					if is_a_chord(msg) == true then
						reaper.MIDI_DeleteTextSysexEvt( take, i)
					end
				end
			end
		end
	end

	---Write chords name in the notation event lane.
	--@tparam take take is a reaper active take
	--@tparam string chord is a string contaning the chord name well formed by previous functions
	--@tparam number startpos is the place where the chords have to be written in ppq.
	function WriteData:notation(take,chord,startpos)	
		-- put the chord in notation view
		reaper.MIDI_InsertTextSysexEvt( take, false, false, startpos, 0xFF0F, "TRAC text ".. chord)
	end
	
	---Write chords name in the textevent lane AND in the notation event lane.
	--@tparam take take is a reaper active take
	--@tparam string chord is a string contaning the chord name well formed by previous functions
	--@tparam number startpos is the place where the chords have to be written in ppq.
	function WriteData:text_event_and_notation(take,chord,startpos)
		-- put the chord in notation view
		reaper.MIDI_InsertTextSysexEvt( take, false, false, startpos, 0xFF0F, "TRAC text ".. chord)
		-- put the chord as Text Event in MIDI Editor
		reaper.MIDI_InsertTextSysexEvt( take, false, false, startpos, 6, chord ) -- Text Event Type 6 Insert Midi Marker
	end
	
	---Write chords name in the textevent lane.
	--@tparam take take is a reaper active take
	--@tparam string chord is a string contaning the chord name well formed by previous functions
	--@tparam number startpos is the place where the chords have to be written in ppq.
	function WriteData:text_event(take,chord,startpos)
		-- put the chord as Text Event in MIDI Editor
		reaper.MIDI_InsertTextSysexEvt( take, false, false, startpos, 6, chord ) -- Text Event Type 6 Insert Midi Marker
	end

	--- Create a track named "CHORDS", It will contains text items with chords name as text.
	--@tparam take take is a reaper active take
	--@tparam string chord is a string contaning the chord name well formed by previous functions
	--@tparam number startpos is the start position of the text item in ppq
	--@tparam number endpos is the end position of the item (means startpos+ item length) in in ppq.
	function WriteData:text_item(take,chord,startpos,endpos)
	TRACK_COLOR={165,165,165} --> use RGB color mode
	TRACK_NAME="CHORDS"
	--TRACK_HEIGHT= 28 --height in pixel
	TRACK_LOCK=0 -- 1 means track height is locked, 0 means not locked	
	
		track = get_track_by_name(TRACK_NAME)
		if track then 
		--if track already exists
			reaper.SetOnlyTrackSelected(track)
			if TRACK_HEIGHT then
				--we set track height and lock the track height          
				reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", TRACK_HEIGHT);
			end
			reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK", TRACK_LOCK)
			--we disable the recordring
			reaper.SetMediaTrackInfo_Value(track, "I_RECMODE",2)
			--we disable the inputs
			reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT",-1)     
			--we disable monitor inputs
			reaper.SetMediaTrackInfo_Value(track, "I_RECMON",0)     
				
		else
		TRACK_HEIGHT= 28 --height in pixel
		--else we create a new track at TCP beginning
			--we create a new track at the project start, means track 1
			reaper.InsertTrackAtIndex(0, true)
			--we name it CHORDS
			track = reaper.GetTrack(0,0)
			reaper.GetSetMediaTrackInfo_String(track, "P_NAME", TRACK_NAME, true)
			--we add the default color
			color = reaper.ColorToNative(TRACK_COLOR[1],TRACK_COLOR[2],TRACK_COLOR[3])|0x1000000
			reaper.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", color)
			--we disable auto record armed
			reaper.SetMediaTrackInfo_Value(track, "I_RECARM",math.abs(1-reaper.GetMediaTrackInfo_Value(track, "I_RECARM")))
			--we disable the recordring
			reaper.SetMediaTrackInfo_Value(track, "I_RECMODE",2)
			--we disable the inputs
			reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT",-1)
			--we disable monitor inputs
			reaper.SetMediaTrackInfo_Value(track, "I_RECMON",0)     
			--we set track height and lock the track height
			reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", TRACK_HEIGHT);
			reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK",TRACK_LOCK)          
		end
		
		color = reaper.ColorToNative(TRACK_COLOR[1],TRACK_COLOR[2],TRACK_COLOR[3])|0x1000000
		--timing datas have to be convert from ppq to seconds. See preferences > Media > MIDI > "Ticks per quarter note for new MIDI items"
		
		startpos=reaper.MIDI_GetProjTimeFromPPQPos( take, startpos)
		endpos=(reaper.MIDI_GetProjTimeFromPPQPos( take, endpos ))
		length=endpos-startpos
		
		--Get item from the "CHORDS" track and not from the one with selected items
		item = reaper.AddMediaItemToTrack(track)
		reaper.SetMediaItemInfo_Value(item, "D_POSITION", startpos) --in seconds
		reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length) --in seconds

		if chord ~= nil then
			reaper.GetSetMediaItemInfo_String( item, "P_NOTES", chord, true )
			reaper.BR_SetMediaItemImageResource( item, imageIn,3) --set text note to fit item size (auto zoom in/out)
		end

		if color ~= nil then
			reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
		end
	end


-----------------------------
-- Define Class Constructor
-----------------------------

function WriteData:new(t)
	t=t or {}
	setmetatable(t,self)
	self.__index=self
	return t
end
