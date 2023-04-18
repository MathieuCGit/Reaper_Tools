-- @description ReaCAT - Reaper Chord Adding Tool - Chord Track
-- @author Mathieu CONAN   
-- @version 0.2-alpha
-- @provides
--    [main=main,midi_editor] .
--    [nomain] Analyzer.lua
--    [nomain] Collector.lua
--    [nomain] MergingTool.lua
--    [nomain] SharpOrFlat.lua
--    [nomain] WriteData.lua
-- @changelog Add MergingTool class it allows to detect chords across multiple tracks.
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main/Chords%20tool/ReaCAT
-- @about ReaCAT aims to provide a tool to perform and use chords in Reaper. It consists mainly in analysis chords in different ways and adding them in different places (text event, notation chords, item text note...). it's a MIDI tool, you can't find chords from audio with it.
--
--  Minimal Reaper version is 6.73 with SWS pre-release 2.13.1 (https://www.sws-extension.org/download/pre-release/)


-- CONST
WRITE_CHORD_TRACK=true --create a track named CHORDS containing item text with chord name
WRITE_TEXT_EVENT_AND_NOTATION=true --add chord name to texte event and notation
WRITE_TEXT_EVENT=false --add chord name to text even only
WRITE_NOTATION=false --add chord name to notation only

--- ReaCAT - Reaper Chord Adding Tool
--
-- @module ReaCAT
-- This modules is the main one loaded in Reaper.

-- load modules

	-- find the program path
	local sep = package.config:sub(1, 1) -- separators depend on operating system, windows = \, linux and osX = /
	local script = debug.getinfo(1, 'S').source:sub(2) --absolute path + filename of current running script
	local pattern = "(.*" .. sep .. ")" -- every char before sep
	local basedir = script:match(pattern) -- rootpath of current running script
	local filename_without_ext = script:match("(.+)%.[^%.]+$")
	package.path =string.format(basedir.."?.lua")

	--load desire modules
	--require 'lib.dbg'
	require 'Analyzer'
	require 'Collector'
	require 'MergingTool'
	require 'SharpOrFlat'
	require 'WriteData'

--
--[[ CORE ]]--
--
function Main()
	--if an item is selected
	-- TODO: it has to be improve because if more than one item are selected this detection should be into the Collector.lua class.
	nbr_sel_items= reaper.CountSelectedMediaItems(0)
	
	--we clean CHORDS track.
	write_data=WriteData:new()
	write_data:del_existing_chord_items(nbr_sel_items)
	
	--We check if there are items selected across multiple tracks
	MergingTool=MergingTool:new()
	is_there_mt=MergingTool:detect_multi_track()
	
	--If there are items on multiple tracks, we merge them
	if is_there_mt == true then
		MergingTool:merge()
	end
	
	if nbr_sel_items > 0 then
		for i=0, nbr_sel_items-1 do
			--we get the selected media item
			item=reaper.GetSelectedMediaItem( 0, i)
			
			-- if the midi editor is opened
			-- TODO: improve this mechanism. A midi editor can be opened but the media selected is not the one in the midi editor.
			if reaper.MIDIEditor_GetActive() then
				--we get the current take
				take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
			end
			
			--we check if is a midi media item
			if item and reaper.TakeIsMIDI(reaper.GetMediaItemTake(item, 0)) then
				--we get the take from this selected media item
				take= reaper.GetMediaItemTake(item, 0)
			end

			--TODO: comment this part
			chord=Collector:new()
			pitch_array_new=chord:get_pitch_array(take)
			pitch_array=chord:chord_pos(pitch_array_new,take)
			
			write_data:del_existing_chord_symbols(take)

			-- sometimes while clicking in MIDI editor we select only one note. A chord is at least 2 notes
			if #pitch_array > 1 then 
				nbr_of_chords_in_take = pitch_array[#pitch_array-1].pos_idx -- wee take the last index reference
			else
				local msg = "Please select at least 2 notes, or no notes for a full item processing."
				reaper.MB(msg, "Invalid selection", 0)
				return
			end

			chord_idx=1
			chord_start_pos=pitch_array[1].startppqpos -- first chord position

			for k=1, nbr_of_chords_in_take do
			
				result=""
				chord_to_analyze={}
				j=1
				--agregate pitch of the same chord in one new table to fit the Analyzer class input format (see Analyzer class documentation)
				for i=1, #pitch_array do
					--create an array of pitch for each chords
					if pitch_array[i].pos_idx == chord_idx then
						chord_to_analyze[j]=pitch_array[i].pitch
						chord_end_pos=pitch_array[i].endppqpos
						j=j+1
					end
				end
				
				-- Perform a chord analysis from pitch array
				new_chord=Analyzer:new()
				result=new_chord:get_chord(chord_to_analyze, take)
				
				-- Detect and use the correct key signature (sharp or flat in chords name)
				sharp_or_flat=SharpOrFlat:new()
				if result ~= nil and result ~= current_chord then 
					chord=sharp_or_flat:apply_keysign(result,take)
					
					if WRITE_NOTATION == true then
						-- write ONLY notation
						write_data:notation(take,chord,chord_start_pos)
					end
					
					if WRITE_TEXT_EVENT == true then
						-- write ONLY text event
						write_data:text_event(take,chord,chord_start_pos)
					end
					
					if WRITE_TEXT_EVENT_AND_NOTATION == true then
						-- write chords as a text event and a in the notation view
						write_data:text_event_and_notation(take,chord,chord_start_pos)
					end
					
					if WRITE_CHORD_TRACK == true then
						-- write chords in text item on a new track "CHORDS"
						write_data:text_item(take,chord,chord_start_pos,chord_end_pos)
					end
				end
				
				-- find the start of the next chord
				-- TODO: Improve this mechanism
				for i=1, #pitch_array do
					if pitch_array[i].pos_idx == chord_idx+1 then
						chord_start_pos=pitch_array[i].startppqpos
						break
					end
				end          
				
				-- go to the next chord
				chord_idx=chord_idx+1
				--this keeps the current chord in memory and avoid duplicate entries
				current_chord=result 
			end
		end
	else
	--no item is selected. return error message window.
		local msg = "No item selected"
		reaper.MB(msg, "Invalid selection", 0)
		return
	end
end
--
--[[ EXECUTION ]]--
--

-- clear console dbg:str
reaper.ShowConsoleMsg("")

reaper.PreventUIRefresh(1)

-- Begining of the undo block. Leave it at the top of your main function.
reaper.Undo_BeginBlock()

-- execute script core
Main()

-- End of the undo block. Leave it at the bottom of your main function.
reaper.Undo_EndBlock("MIDI Editor Get chords from active take or selected notes", - 1)

-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
