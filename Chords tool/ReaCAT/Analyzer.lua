--@noindex

---ReaCAT - Chord Analyzer.
--
--This module provides a bunch of mechanisms to analyze a chord and return a formated string like **G7(&flat;9)**.
--@module Analyzer
--
--The main public method is `Analyzer:get_chord(pitch_array,take)`.
--@see Analyzer:get_chord
--
--`pitch_array` structure should be:
-- @code
--  pitch_array={
--   [idx]=int,
--   [idx]=int,
--   [idx]=int,
--   [idx]=int,
--   [idx]=etc...}
--
--For example, here is a CM7.
-- @example
--   pitch_array={
--    [1]=60,
--    [2]=64,
--    [3]=67,
--    [4]=71
--    }
--

-----------------------------
-- Define Class Attributes
-----------------------------

Analyzer={
	--- The root of the chord.
	--
	-- @meta read-only
	-- @type string
	root="",
	
	--- The body/structure of the chord.
	--
	-- @meta read-only
	-- @type string
	structure="",
	
	--- If the chord is in an inverted form, bass is the lowest note. So either the root or the lowest note.
	--
	-- @meta read-only
	-- @type string
	bass=""	
}

	--- Interval reference table.
	-- @meta read-only
	-- @type table
	--@note Interval reference table.
	--  This is the main interval reference table.
	--  @code
	--    1:"" 
	--    2:"b2" 
	--    3:"sus2" 
	--    4:"m" 
	--    5:"" 
	--    6:"sus4" 
	--    7:"b5" 
	--    8:"" 
	--    9:"" 
	--    10:"6" 
	--    11:"7" 
	--    12:"M7" 
	--    13:"#5" 
	--    14:"b9" 
	--    15:"9" 
	--    16:"#9" 
	--    17:""  
	--    18:"11" 
	--    19:"#11" 
	--    20:"" 
	--    21:"b13" 
	--    22:"13" 
	--    23:"#13" 
	--    24:"" 
	--    25:"dim7"
	--    26:"5"
	--
	--
	-- A minor chord will returned as `{1,4,8}` with `1=""`, `4="m"` and `8=""`, so only the `"m"` symbol will be returned
	--
	-- An exception takes place at the 13th place of the table. As octave are never displayed, we put '#5' symbol in this place. 25th place is used as an extra slot for "dim7" chord symbol. We also add a 26 slot for the power chords.
	intervalReferenceTable = {"","b2","sus2","m","","sus4","b5","","","6","7","M7","#5","b9","9","#9","","11","#11","","b13","13","7","","dim7","5"}

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

	--- Get usual name from interval numbers, we got the name from the **intervalReferenceTable** defined at the beginning of the script.
	--
	--In tonal and occidental modal music, intervals are represented on 2 octaves.
	--So this array is a 24 cases + extra cases (for example 25 = *dim*)
	--for convenient displaying, I use the 13th case (8ve) to put the *#5*.
	--
	--@tparam tab array is an array containing a list of intervals.
	--@treturn string stringStruc a formated string like "m7" or "M79".
	--
	-- @note
	--  the value returns by this function is not yet polished and we have a parsing mechanism later.
	--  @see generic_chord_parser
	--
function chord_structure_func(array)
		local stringStruc=""
		for i=2, #array do
			for j=1, #intervalReferenceTable do
				if array[i] == j and array[i] <= 26 then
					stringStruc=stringStruc..intervalReferenceTable[j]
				end
			end
		end
	return stringStruc
	end

	---Actually Lua doesn't support table copy as expected in lots of other languages.
	--You **CAN'T** make `table2 = table1` and expect `table2` to be a new table with `table1` data.
	--Here is a snippet from [http://lua-users.org/wiki/CopyTable](http://lua-users.org/wiki/CopyTable)
	--making quite well the job.
	--@tparam tab orig is the array you want a copy
	--@treturn tab copy returns a NEW array with orig datas copied in
function deepcopy(orig)
		local orig_type = type(orig)
		local copy
		if orig_type == 'table' then
			copy = {}
			for orig_key, orig_value in next, orig, nil do
				copy[deepcopy(orig_key)] = deepcopy(orig_value)
			end
			setmetatable(copy, deepcopy(getmetatable(orig)))
		else -- number, string, boolean, etc
			copy = orig
		end
		return copy
	end

	---If size of Array is upper than 7 we have a non standard chord, means a cluster.
	--@tparam tab array is a table we have already removed duplicate note entries.
	--@treturn string a message saying this is detected as a cluster. Idealy this part should open a input box to let user name the chord as he would like with something like.
	--<code>retval, retvals_csv=reaper.GetUserInputs()</code>
function detect_cluster(array)
		local clusterString=""
		
		--if we get more than 7 notes in the chord
		if #array > 7 then
			clusterString=("( ")
			for index, value in ipairs(array) do
				clusterString=clusterString..tostring(value["name"]).." "
			end
		clusterString=clusterString..")"
		IsAcluster=1
		end
	return IsAcluster, clusterString
end
	
	---This function aims to check if a specific interval exists. If we have a 6 and a 7, 6 becomes a 13 and the chord is no more considered as an inversion. So we need to know if we have M7.
	--@tparam tab array is an array containing the chords numbers like for example : `array={1,5,8,11}` for a major7 chord.
	--@tparam number intervalSeeked is the number of the interval you want to detect in semi-tone. For example if we put 4, the function will return true and 1. True because we found the interval and 1 because we found it once.
	--@treturn bool isDetected is set to true if the interval exists in the array and false otherwise.
	--@treturn int nbr_interval_seeked count the number of time an interval is found.
function find_interval(array,intervalSeeked)
	local isDetected=false
	local nbr_interval_seeked=0
		
	if array then
		for _,v in pairs(array) do
			if v == intervalSeeked then
				nbr_interval_seeked=nbr_interval_seeked+1
				isDetected=true
			break
			end
		end	
	end
	return isDetected,nbr_interval_seeked
end

	---This function is the **core analysis** one.
	--@note Behaviour
	--  It aims to get chord intervals in the good order as a human would perform. A 6th is an inverted 3rd. So we have to treat 6th as 3rd. There are 3 exceptions:
	--  * if there are a 6 AND a 7 or 7M => 6th become a 13th and minor 6th become a b13
	--  * dimnished chords always have a major 6th, so be carefull of this case	to avoid infinite loop.
	--  * augmented chords always have a minor 6th, so be carefull of this case	to avoid infinite loop.	
	--
	--@tparam tab array 
	--@treturn tab pitch_role_and_name which contains notes in the right order and with right intervals
	--@treturn string the real root note (so even if the bass note **is not** the root note)
	--@see find_interval
	--@see array2Dsort
function find_the_real_root(array)
	local pitch_role_and_name=array
	pitch_role_and_name=array2Dsort(pitch_role_and_name,"pitch")
	
	if #pitch_role_and_name > 0 then

		-- check if the first note in the array is the root, otherwise, temporary flag it to 1
		--and recreate the array preserving intervals
		-- we arbitrary and temporary set the first note as the root one and calculate the value of other notes respecting intervals
		tmp_root=pitch_role_and_name[1].pitch%12+1 --find modulo of 1st note
		rebase_root=tmp_root-1 --get the interval to rebase this note to 1 (root)
		
		--[[ for every notes in the table we use the same interval as the one we previously found to place them relatively from this temp root note.
		 Example:
		pitch_role_and_name = {
						  [1] => (table: 0000000015ED35D0) {
							[name] => (string) "D#"
							[pitch] => (number) 63
						  }
						  [2] => (table: 0000000015ED50D0) {
							[name] => (string) "G"
							[pitch] => (number) 67
						  }
						  [3] => (table: 0000000015ED5110) {
							[name] => (string) "A#"
							[pitch] => (number) 70
						  }
						  [4] => (table: 0000000015ED4A90) {
							[name] => (string) "D"
							[pitch] => (number) 74
						  }
						}
		--if the first note modulo is 4, we look for the interval from this note (D#) to 1. So rebase_root is now 3. Then we remove 3 from every other modulo in the array and we got :
		1 (root)
		5 (major 3rd)
		8 (fifth)
		0 (???)
		As negative value and 0 aren't intervals, we add 12 if we found those values and now we have
		1 (root)
		5 (major 3rd)
		8 (fifth)
		12 (Major 7)
		]]--
		for i=1, #pitch_role_and_name do
			local base=pitch_role_and_name[i].pitch%12+1
			role=base-rebase_root
			if role <= 0 then role=role+12 end
			pitch_role_and_name[i].role=role
		end
		pitch_role_and_name=array2Dsort(pitch_role_and_name,"role")
		
		-- TODO We now need to remove dupplicates
		--remove duplicates
		local tmp={}
		local j=1
		for i=1,#pitch_role_and_name-1 do
			if pitch_role_and_name[i].role ~= pitch_role_and_name[i+1].role then
				tmp[j]=pitch_role_and_name[i]
				j=j+1
			end
			
		end
		-- TODO : This loop mechanism and the following line should be improve, a better method should be found.
		tmp[j]=pitch_role_and_name[#pitch_role_and_name] --add the last element as it's not treated by the previous loop
		pitch_role_and_name=tmp
		
		-- The method we used is based on "a 6th is a inverted 3rd" way of analysis
		-- BUT a diminished chord is only major 6th endlessly.
		-- AND a augmented chord is only minor 6th endlessly.
		-- so we have to know how many 3rd (or 6th) we have in the chord
		-- to avoid infinite loop and create a condition to stop looping.
		-- We use the fact that the bass note will appear a second time if
		-- we are in a endless loop.
		local interval_array = {}
		for i=1,#pitch_role_and_name do interval_array[i]=pitch_role_and_name[i].role end

		--Let's manage the 6th !
		i=1
		limit=#pitch_role_and_name+1
		ref_pitch=pitch_role_and_name[1].pitch
		
		while i < limit do
			if find_interval(pitch_role_and_name[i],9) and find_interval(pitch_role_and_name[i+1],10) == false then 
			--we only want ONE minor 6th
			--we avoid the case a chord has a minor 6th (9) AND a major 6th (10)
			--If we got both, we prefer the major one (see next condition).
			-- This happens rerely but for example a minor9(b5) inverted on its b5th has both
			-- Cm9(b5)/Gb => 1(Gb) 5(Bb) 7(C) 9(D) 10(Eb)
				
				for j=1, #pitch_role_and_name do
				--we change note place from a minor 6th (note 9) to the root (note 1)
					pitch_role_and_name[j].role=pitch_role_and_name[j].role-8  
					if pitch_role_and_name[j].role < 1 then
					--if note value goes under the root, we put it an octave higher
						pitch_role_and_name[j].role=pitch_role_and_name[j].role+12
					end				
				end
			
				--if the loop find the 1st note a second time, we break to avoid infinite loop.
				if pitch_role_and_name[i].pitch == ref_pitch then break end
				
				i=0 --array values are redefined so we start a new analysis
			
			elseif find_interval(pitch_role_and_name[i],10) then
			--if we found a Major 6th, it usually means we are facing a minor third
				for j=1, #pitch_role_and_name do
				--we change note place from a Major 6th (note 10) to the root (note 1)
					pitch_role_and_name[j].role=pitch_role_and_name[j].role-9 
					if pitch_role_and_name[j].role < 1 then
					--if note value goes under the root, we put it an octave higher
						pitch_role_and_name[j].role=pitch_role_and_name[j].role+12
					end				
				end
				
				--if the loop find the 1st note a second time, we break to avoid infinite loop.
				if pitch_role_and_name[i].pitch == ref_pitch then break end
				
				i=0 --array values are redefined so we start a new analysis
			end
		i=i+1	
		end
	end
	
	--The real root is the one with the role "1".
	for i=1, #pitch_role_and_name do
		if pitch_role_and_name[i].role == 1 then
			rootNote=pitch_role_and_name[i].name
		end
	end

	return pitch_role_and_name, rootNote
end
	
	---This function aims to provide a more conventional displaying for chords. By design it seems better to separate chords recognition from chord displaying because it lets us more possibilities.
	--
	-- @note 
	--   _Ebmb57_ would be more comprehensive if displayed as _Ebmin7(b5)_ and A major with a 3rd on bass is _AC#_ but will be _A/C#_ once processed.
	--
	--@tparam string rootNote is the real root note of the chord (not the potential inverted one)
	--@tparam string chordStructure is a string coming from intervalReferenceTable{}
	--@tparam string lowestNoteName is the lowest note find by pitch in the chord detection
	--@treturn string chord the structure of the chord
	--@treturn string rootNote is the rootNote
function generic_chord_parser(rootNote,chordStructure,lowestNoteName)

		chordStructure=string.gsub(chordStructure,"^mb56","dim7",1)
		chordStructure=string.gsub(chordStructure,"^m57$","m7",1)
		chordStructure=string.gsub(chordStructure,"mb57$","m7(b5)",1)
		chordStructure=string.gsub(chordStructure,"mb579$","m9(b5)",1)
		chordStructure=string.gsub(chordStructure,"b57","7(b5)",1)
		chordStructure=string.gsub(chordStructure,"#5","(#5)",1)
		chordStructure=string.gsub(chordStructure,"7#5","7(#5)",1)
		chordStructure=string.gsub(chordStructure,"M791113","M(13)",1)
		chordStructure=string.gsub(chordStructure,"M79","M9",1)
		chordStructure=string.gsub(chordStructure,"79$","9",1)
		chordStructure=string.gsub(chordStructure,"b9","(b9)",1)
		chordStructure=string.gsub(chordStructure,"#9","(#9)",1)
		chordStructure=string.gsub(chordStructure,"7911$","11",1)
		chordStructure=string.gsub(chordStructure,"^7913$","9(add13)",1)
		chordStructure=string.gsub(chordStructure,"711$","7(add11)",1)
		chordStructure=string.gsub(chordStructure,"911$","11",1)
		chordStructure=string.gsub(chordStructure,"^91113$","(add9/11/13)",1)
		chordStructure=string.gsub(chordStructure,"791113$","13",1)
		chordStructure=string.gsub(chordStructure,"7911b13$","11b13",1)
		chordStructure=string.gsub(chordStructure,"1113$","11/13",1)
		chordStructure=string.gsub(chordStructure,"b13","(b13)",1)
		chordStructure=string.gsub(chordStructure,"sus27","7sus2",1)
		chordStructure=string.gsub(chordStructure,"sus47","7sus4",1)
		chordStructure=string.gsub(chordStructure,"sus2M7","M7sus2",1)
		chordStructure=string.gsub(chordStructure,"sus4M7","M7sus4",1)
		chordStructure=string.gsub(chordStructure,"^dim79","dim7(9)",1)
		
		--power chord case
		if string.len(chordStructure) == 1 and string.find(chordStructure,"5") then
			chordStructure=string.gsub(chordStructure,"^5$","(5)",1)
		end

		--change ASCII b or # for a notation char
		chordStructure=string.gsub(chordStructure,"b",utf8.char(9837))
		chordStructure=string.gsub(chordStructure,"#",utf8.char(9839))


		if rootNote ~= nil and rootNote ~= lowestNoteName and lowestNoteName ~= nil and  string.match(lowestNoteName,"[A-G]") then

			--change ASCII b or # for a notation char
			rootNote=string.gsub(rootNote,"b",utf8.char(9837),1)
			rootNote=string.gsub(rootNote,"#",utf8.char(9839),1)

			lowestNoteName=string.gsub(lowestNoteName,"b",utf8.char(9837),1)
			lowestNoteName=string.gsub(lowestNoteName,"#",utf8.char(9839),1)

			lowestNoteName="/"..lowestNoteName

			chord=rootNote..chordStructure..lowestNoteName
		elseif rootNote ~= nil then
			--change ASCII b or # for a notation char
			rootNote=string.gsub(rootNote,"b",utf8.char(9837),1)
			rootNote=string.gsub(rootNote,"#",utf8.char(9839),1)
			chord=rootNote..chordStructure
		end
	return chord
	end

	---This function aims to manage some exception not as usual mathematical scheme but as a human being would.
	--
	--
	--   @note how it works
	--      if we have 4 and 5 semitones from the root note we haven't a minor AND a major chord, we have a major chord with a minor interval (4 semitones) considered as a #9.
	--   
	--      As each alteration can be understood in 2 octaves we will work on an array of 24 values.
	--
	--	
	--@tparam tab array contains notes interval already parsed and ordered.
	--@treturn tab interval_table with correct itnervals see comment in the function
	--@see find_interval
	--@see chord_structure_func	
function manage_standard_exceptions(array)
	local interval_table=array
	
	--b2 doesn't exists in standard notation but can be use in clusters, otherwise, we have a b9
	if (find_interval(interval_table,2)) then interval_table=replace_interval(interval_table,2,14) end
	--min => 2 & 4 if we have a minor 3rd, we can't have a 2nd or a 4th, we have a 9th and a 11th
	if (find_interval(interval_table,4) and find_interval(interval_table,3)) then interval_table=replace_interval(interval_table,3,15) end
	if (find_interval(interval_table,4) and find_interval(interval_table,6)) then interval_table=replace_interval(interval_table,6,18) end
	--maj 2 & 4 if we have a major 3rd, we can't have a 2nd or a 4th, we have a 9th and a 11th
	if (find_interval(interval_table,5) and find_interval(interval_table,3)) then interval_table=replace_interval(interval_table,3,15)end
	if (find_interval(interval_table,5) and find_interval(interval_table,6)) then interval_table=replace_interval(interval_table,6,18)end
	--min vs maj if we have a minor AND a major interval minor is considered as a #9
	if (find_interval(interval_table,5) and find_interval(interval_table,4)) then interval_table=replace_interval(interval_table,4,16)end
	--7M so we can't have a 7 we have a #13
	if (find_interval(interval_table,11) and find_interval(interval_table,12))then interval_table=replace_interval(interval_table,11,23) end
	--7 we can't have a 6, it's a 13
	if (find_interval(interval_table,10) and find_interval(interval_table,11))then interval_table=replace_interval(interval_table,10,22) end
	--M7 we can't have a 6th, it's a 13
	if (find_interval(interval_table,10) and find_interval(interval_table,12))then interval_table=replace_interval(interval_table,10,22) end
	-- b6 with a 7 or a M7 become a b13
	if find_interval(interval_table,9) and find_interval(interval_table,11) and find_interval(interval_table,8)  then interval_table=replace_interval(interval_table,9,21) end
	--5th and #5th => we can't have both, #5 becomes b13
	if find_interval(interval_table,7) and find_interval(interval_table,9) then interval_table=replace_interval(interval_table,9,21) end
	--b5th and #5th => we can't have both, #5 becomes b13
	if find_interval(interval_table,13) and find_interval(interval_table,8) then interval_table=replace_interval(interval_table,13,21) end
	--b5th and 5th => b5 becomes #11
	if find_interval(interval_table,7) and find_interval(interval_table,8) then interval_table=replace_interval(interval_table,7,19) end
	-- #5 : we have a 7th but no 5th so the #5 is not a b13
	if find_interval(interval_table,9) and find_interval(interval_table,8)== false then interval_table=replace_interval(interval_table,9,13) end
	-- Power chords case, we only get 5th
	if find_interval(interval_table,8) and #interval_table == 2 and find_interval(interval_table,5) == false then interval_table=replace_interval(interval_table,8,26) end	

	table.sort(interval_table)
	return interval_table

end	

	--- convert a note number value into a MIDI note
	-- @tparam int note midi note number (from 0 to 127)
	-- @treturn str midi note name such as C1 or F#3, etc...
	-- Snippet inspired from the awesome Reaticulate by Jason Tackaberry : [https://github.com/jtackaberry/reaticulate/blob/master/app/lib/utils.lua](https://github.com/jtackaberry/reaticulate/blob/master/app/lib/utils.lua)
function note_to_name(note)
	if note ~= nil then
		local notes = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'}
		return notes[(note % 12) + 1]
	end
end

	--- This function aims to replace a given interval value by another in a given array
	--@tparam tab array is the table we want to modify
	--@tparam string old is the existing value
	--@tparam string new is the value we want as the new one
	--@treturn tab array is the table modified with new values
function replace_interval(array,old,new)
	for i=0, #array do 
		if array[i] == old then array[i]=new end
	end
	return array
end

	--- Get lenght of an indexed table/array.
	--@tparam tab t i a table
	--@treturn int the table's lenght
function table_length(t)
	if t then
		local count = 0
			for _ in pairs(t) do count = count + 1 end
		return count
	end
end
	

--- PUBLIC METHODS
-- @section public methods
	
	---Perform analyse of pitch_array to determinate chord root, bass and structure. The table `pitch_array` **MUST** get this structure :
	-- @code
	--  pitch_array={
	--   [idx]=int,
	--   [idx]=int,
	--   [idx]=int,
	--   [idx]=int,
	--   [idx]=etc...}
	--
	--For example, here is a *CM7*.
	-- @example
	--   pitch_array={
	--    [1]=60, --C
	--    [2]=64, --E
	--    [3]=67, --G
	--    [4]=71  --B
	--    }
	--
	--@tparam tab pitch_array an array you got with Pitch_and_coordinates class. 
	--@tparam take take the active take where analysis must perform.
	--@treturn str chord is a printable string of the chord like for example G7(&flat;9).
function Analyzer:get_chord(pitch_array, take)
	if not pitch_array then return end --exit if pitch_array doesn't exist
		local array_lenght=table_length(pitch_array)
		if array_lenght < 2 then pitch_array={} return end --exit if we got no notes or only one note, we don't have a  chord.
		if take == nil then return end --exit if we got no take.
		local interval_array = {}
		local note_name_array = {}
		local pitch_and_name_array = {}
		
		--we get MIDI note number value
		if array_lenght > 0 then
			local j=1
			for i=1, array_lenght do
				note_name_array[j]=note_to_name(pitch_array[i])
				pitch_and_name_array[j]={pitch=pitch_array[i],name=note_to_name(pitch_array[i])}
				j=j+1
			end
		end
		
		--we sort by pitch to get the lowest note first
		pitch_and_name_array=array2Dsort(pitch_and_name_array,"pitch")
		self.bass=pitch_and_name_array[1].name
			
		
		--- @warning here is the core method @see find_the_real_root()
		pitch_role_and_name, self.root = find_the_real_root(pitch_and_name_array)
		
		-- More than 7 different notes in a chord is a cluster.
		--     CLUSTER CASES - AVOID INFINITE LOOP
		-- TODO : create a specific object to manage cluster cases
		IsACluster,clusterString=detect_cluster(pitch_role_and_name)		
		if IsACluster == 1 then return clusterString end	
		
		for i=1,#pitch_role_and_name do interval_array[i]=pitch_role_and_name[i].role end
		table.sort(interval_array)
		
		interval_array=manage_standard_exceptions(interval_array)
		
		self.structure=chord_structure_func(interval_array)
		chord=generic_chord_parser(self.root,self.structure,self.bass)
		return chord	
	end



-----------------------------
-- Define Class Constructor
-----------------------------

function Analyzer:new(t)
	t=t or {}
	setmetatable(t,self)
	self.__index=self
	return t
end
