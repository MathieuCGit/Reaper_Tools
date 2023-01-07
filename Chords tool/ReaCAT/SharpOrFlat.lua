--@noindex

--- ReaCAT - Sharp or Flat
--
-- This module aims to detect the key signature we are working with. It also provides methods to manipulate chords according to the key signature detected.
-- @module SharpOrFlat

-----------------------------
-- Define Class Attributes
-----------------------------

SharpOrFlat = {

}

-----------------------------
-- Define Class Methods
-----------------------------

--- PRIVATE METHODS
-- @section private methods

	--- This function let us convert flat and sharp symbols from ASCII to UTF8
	--@tparam string str generally the chord name is passed in argument.
	--@treturn string str a converted to UTF8 sharp or flat symbol.
	function ascii_to_utf8(str)
		--change ASCII b or # for an UTF-8 notation char
		str=string.gsub(str,"b",utf8.char(9837))
		str=string.gsub(str,"#",utf8.char(9839))
		
		return str
	end

	--- This function let us convert flat and sharp symbols from UTF8 to ASCII
	--@tparam string str generally the chord name is passed in argument.
	--@treturn string str a converted to ASCII sharp or flat symbol.
	function utf8_to_ascii(str)
		--change ASCII b or # for an UTF-8 notation char
		str=string.gsub(str,utf8.char(9837),"b")
		str=string.gsub(str,utf8.char(9839),"#")
		
		return str
	end
	
	--- Find if we already have a key signature at ppq parameter, +-10 ticks
	--
	--@tparam take take is a valid reaper take
	--@tparam number pos is the start of the measure and/or item take in ppqp (generaly 0)
	--@treturn  int event id. Returns -1 if no MIDI key signature msg in the take
	--@treturn string event msg containing MIDI raw data message
	--@see sharp_or_flat
	--
	--  @note SNIPPET from [bFooz](https://forum.cockos.com/member.php?u=24199) here
	--    [https://forum.cockos.com/showpost.php?p=2445234&postcount=8](https://forum.cockos.com/showpost.php?p=2445234&postcount=8)
	--
	--  @warning WARNING
	--    You **MUST** right click on key at start of staves and verify that "*Key signature changes affect all tracks*" is **UNCHECK**
	--
	function get_key_sign_at_ppq(take,pos)
		local _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts( take )
		local event_num = 2*notecnt + ccevtcnt + textsyxevtcnt --why mulpliying notecnt by 2 ??
		local return_id, return_msg = -1, "" --event id and msg of existing key signature if found

		for e=0, event_num-1 do
			local retval, selected, muted, ppqpos, msg = reaper.MIDI_GetEvt( take, e,  0, 0, pos, 0 )
			--check if this message is a key signature
			local byte1, byte2 = string.unpack("BB", msg)
			--if we have a key signature, store message and break
			if byte1==255 and byte2==89 then
				return_id = e
				return_msg = msg
			end
		end
		return return_id, return_msg
	end
	
	--- Fix for refresh and for writing into all midi items (because does not always work when the cursor is at the start of emasure)
	--
	--  @note SNIPPET
	--    from [bFooz](https://forum.cockos.com/member.php?u=24199) here : [https://forum.cockos.com/showpost.php?p=2445234&postcount=8](https://forum.cockos.com/showpost.php?p=2445234&postcount=8)
	--
	function refresh_fix()

		reaper.MIDIEditor_OnCommand( editor, 40048 ) --move cursor right by grid

		--turn on key snap and add to all items
		reaper.MIDIEditor_OnCommand( editor, 40757 ) --select next key signature
		reaper.MIDIEditor_OnCommand( editor, 40756 ) --select previous key signature

		reaper.MIDIEditor_OnCommand( editor, 40047 ) --move cursor left by grid
	end	



--- PUBLIC METHODS
-- @section public methods
	
	--- This method aims to determine if reaCAT has to use sharp or flat in chords name. It uses item keysignature.
	--@see get_key_sign_at_ppq
	--
	--@tparam take take is a valid reaper MIDI take
	-- 
	--@treturn tab acc_ref_table is the basic array containing either sharp or flat notes once the script has proceed
	--@treturn str accidentals is a (#) or a (b) symbol. We can use this variable information to know if we use sharp or flat
	function SharpOrFlat:sharp_or_flat(take)

		item=reaper.GetSelectedMediaItem(0,0)
		take=reaper.GetActiveTake(item)

		-- this is the basic chromatic scale.
		-- acc_ref_table_sharp = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
		acc_ref_table_sharp = {"F#","C#","G#","D#","A#","E#","B#"}
		-- acc_ref_table_flat = {"C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"}
		acc_ref_table_flat = {"Bb","Eb","Ab","Db","Gb","Cb","Fb"}

		--Refresh inforamtions while key sig is store within items
		refresh_fix()

		-- calculate nbre of sharp or flat from an event using [bFooz](https://forum.cockos.com/member.php?u=24199) method
		-- see here https://forum.cockos.com/showpost.php?p=2445234&postcount=8
		local keyId, keyMsg = get_key_sign_at_ppq(take,0)
		local byte = {}
		local acc_id_num=0
		if string.len(keyMsg) > 0 then
			byte[1], byte[2], byte[3], byte[4], byte[5] = string.unpack("BBBBB", tostring(keyMsg))
			acc_id_num = (byte[4])
		end



		if acc_id_num >= 1 and acc_id_num <=7 then
			acc_ref_table=acc_ref_table_sharp
			accidentals = "#"
			nbr_of_accidentals=acc_id_num
		elseif acc_id_num >= 249 and acc_id_num <= 255 then
		-- from 255 to 250 we get major scale F (255), Bb(254), Eb(253), Ab(252), Db(251), Gb(250)  and Cb(249). jump is caused by Hex to decimal conversion
			acc_ref_table = acc_ref_table_flat
			accidentals="b"
			nbr_of_accidentals=256-acc_id_num
		elseif acc_id_num == 0 then
			acc_ref_table={}
			accidentals=""
			nbr_of_accidentals=0
		end

		-- we send only the accidentals we need. For example, in D major we only need F# and C#.
		sum_up_acc_ref_table={}
		for i=1, nbr_of_accidentals do
			sum_up_acc_ref_table[i]=acc_ref_table[i]
		end

		return sum_up_acc_ref_table,accidentals,nbr_of_accidentals
	end
	
	---This method  toggle enharmonic value on already existing chords symbols according to key signature detection
	--@see sharp_or_flat
	--
	--@tparam sting chord the chord you want to process. Chord has to be in a english form with letter (ex: Am7/9 or F7/D#), latin form aren't supported (ex: Lam7/9 or Fa7/Re#).
	--@tparam take take is a Reaper take
	--
	--@treturn string chord the chord processed
	function SharpOrFlat:apply_keysign(chord,take)
		--here we first get the key signature from reaper notation
		acc_ref_table, accidentals,nbr_of_accidentals=self:sharp_or_flat(take)
		
		--we convert the chord sharp or flat in an ASCII character
		chord=utf8_to_ascii(chord)
		--we create a table containing flat or sharp symbol from chords
		local chord_explode={}
		if chord ~= nil then
			chord_explode[0]=string.sub(chord,0,2) --root note
			chord_explode[1]=string.sub(chord,-2) -- inverted chord bass note
			chord_explode[1]=string.gsub(chord_explode[1],"%/","",1)
		end
		
		---create enharmonic table for sharp / flat correspondence
		local enharmonic_table_sharp={
		{"F#","Gb"},
		{"C#","Db"},
		{"G#","Ab"},
		{"D#","Eb"},
		{"A#","Bb"},
		{"E#","F"},
		{"B#","C"}
		}
		
		local enharmonic_table_flat={
		{"Bb","A#"},
		{"Eb","D#"},
		{"Ab","G#"},
		{"Db","C#"},
		{"Gb","F#"},
		{"Cb","B"},
		{"Fb","E"}
		}
		
		--we replace sharp with flat or flat with sharp
		for i=0,#chord_explode do
			for j=1, nbr_of_accidentals do
				if accidentals == "b" and chord_explode[i] == enharmonic_table_flat[j][2] then
					chord=string.gsub(chord,chord_explode[i],enharmonic_table_flat[j][1])
				elseif accidentals == "#" and chord_explode[i] == enharmonic_table_sharp[j][2] then
					chord=string.gsub(chord,chord_explode[i],enharmonic_table_sharp[j][1])
					--manage specific double # (B## and E##)
					chord=string.gsub(chord,"##","#",1)
				end
			end
		end
	return chord
	end	

-----------------------------
-- Define Class Constructor
-----------------------------

function SharpOrFlat:new(t)
	t=t or {}
	setmetatable(t,self)
	self.__index=self
	return t
end
