--@noindex

--- ReaCAT - Merge items
--
-- This module aims to merge items that lived on separate tracks and merge them onto one track. Analysis will be performed on this track. It can be either a folder track or a new created track.
-- @module MergingTool

----------------
-- Define Class Attributes
-----------------------------

MergingTool = {

}

-----------------------------
-- Define Class Methods
-----------------------------

--- PRIVATE METHODS
-- @section private methods
--

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

	--- Find if a track named <code>name</code> exists
	--@tparam string name is the name of the track we are looking for
	function get_track_by_name(name)

		for trackIndex = 0, reaper.CountTracks(0) - 1 do

			local track = reaper.GetTrack(0, trackIndex)
			local ok, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

			if ok and trackName == name then
				return track -- found it! stopping the search here
			end
		end

	end

	---This function Duplicate selected items to selected track.
	--@note SNIPPET FROM [me2beats](https://forum.cockos.com/member.php?u=100851) - Duplicate selected items to selected track *version 1.0*
	-- author [me2beats](https://forum.cockos.com/member.php?u=100851) [https://forum.cockos.com/showthread.php?t=186999](https://forum.cockos.com/showthread.php?t=186999)
	--
	--@warning This function use the `reaper.ApplyNudge()` which implies rounded values to the millisecond instead of 11 decimal value precision used by default in Reaper API. It impacts function such as `reaper.GetMediaItemInfo_Value(item, 'D_POSITION'` for example.
	function duplicate_sel_item_to_sel_track()
		local items = reaper.CountSelectedMediaItems(0)
		if items > 0 then
			local tracks = reaper.CountSelectedTracks(0)

			for y = 0, tracks-1 do
				local tr = reaper.GetSelectedTrack(0,y)
				local tr_num = reaper.GetMediaTrackInfo_Value(tr, 'IP_TRACKNUMBER')
				local more = 0
				local less = 0

				for i_0 = 0, items-1 do
					local it_0 = reaper.GetSelectedMediaItem(0, i_0)
					local tr_0 = reaper.GetMediaItemTrack(it_0)
					local tr_0_num = reaper.GetMediaTrackInfo_Value(tr_0, 'IP_TRACKNUMBER')
					if tr_num > tr_0_num then more = 1 end
					if tr_num < tr_0_num then less = 1 end
				end

				if more == 1 and less == 1 then
					reaper.MB("Can't do this. My coder will fix this latereaper.", '', 0)
				elseif more+less == 1 then
					ok = 1

					if reaper.GetToggleCommandState(41117) == 1 then  -- Options: Toggle trim content behind media items when editing
						local trim = 1
						reaper.Main_OnCommand(41117, 0)
					end

					reaper.ApplyNudge(0, 0, 5, 0, 1, 0, 0)
					for i = 0, items-1 do
						if more == 0 then x = i else x = 0 end
						local it = reaper.GetSelectedMediaItem(0, x)
						reaper.MoveMediaItemToTrack(it, tr)
					end

					reaper.ApplyNudge(0, 0, 0, 0, -1, 0, 0)
					if trim == 1 then
						reaper.Main_OnCommand(41117, 0)
					end
				end
			end
		end
		--[[END SNIPPET]]--
	end

	--- There is no build-in math.round() function in Lua so we found one here : <http://lua-users.org/wiki/SimpleRound>
	--@tparam number num is the number you want to round.
	--@tparam number numDecimalPlaces is the number of values you want next the coma.
	function round(num, numDecimalPlaces)
		local mult = 10^(numDecimalPlaces or 0)
		return math.floor(num * mult + 0.5) / mult
	end

--- PUBLIC METHODS
-- @section public methods

--- Detect if selected items are on more than one track
--@treturn true if there are items selected across tracks, otherwise it returns false
function MergingTool:detect_multi_track()

	nbr_of_items=reaper.CountSelectedMediaItems(0)
	
	if nbr_of_items > 1 then 
		--we take the 1srt item track as a reference to wompre with
		item1=reaper.GetSelectedMediaItem(0,0)
		track1= reaper.GetMediaItem_Track(item1)
		
		--we loop throught every items selected
		for i=0, nbr_of_items-1 do
			item_next=reaper.GetSelectedMediaItem( 0, i)
			track_next= reaper.GetMediaItem_Track( item_next)
			
			--if at least one of them is on a different track, we return TRUE
			if track1 ~= track_next then
				flag=true
			else
				flag=false
			end
		end
	return flag
	end
end

--- Merge items across tracks in to either a folder track (if already exists) or a new track called CHORDS_sub
function MergingTool:merge()
	local TRACK_COLOR={255,255,119} --> use RGB color mode
	local TRACK_NAME="CHORDS_sub"
	local TRACK_HEIGHT= 44 --height in pixel
	local TRACK_LOCK=1 -- 1 means track height is locked, 0 means not locked
	
	reaper.Main_OnCommand(40057, 0) -- Edit: Copy items/tracks/envelope points (depending on focus) ignoring time selection

	nbr_of_items = reaper.CountSelectedMediaItems()
	if nbr_of_items == 0 then 
		reaper.MB("No item selected.", "ERROR", 0)
	return
	end
	
	--we need the first track of selected items
	item= reaper.GetSelectedMediaItem( 0,0)
	track= reaper.GetMediaItem_Track(item)
	trackNum=reaper.GetMediaTrackInfo_Value( track, "IP_TRACKNUMBER" )

	--[[
	if the selected items are on a tracks inside folder,
	we will puit the chords on this folder track
	otherwise, we put the chords on a new specific track name
	TRACK_NAME (CHORDS_sub by default)
	!! This behaviour could be discussed as user could prefer to
	put chords in a new track above selected items tracks !!
	]]--
	if reaper.GetParentTrack(track) then
		track=reaper.GetParentTrack(track)
		trackNum=reaper.GetMediaTrackInfo_Value( track, "IP_TRACKNUMBER" )
	else
		track=get_track_by_name(TRACK_NAME)
	end

	if track then 	
		--select only one track and deselect others
		reaper.SetOnlyTrackSelected(track)
		--we set track height and lock the track height		
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", TRACK_HEIGHT);
		reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK", TRACK_LOCK)
		--we disable record armed
		reaper.SetMediaTrackInfo_Value(track, "I_RECARM",0)		
		--we disable the recordring
		reaper.SetMediaTrackInfo_Value(track, "I_RECMODE",2)
		--we disable the inputs
		reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT",-1)	
		--we disable monitor inputs
		reaper.SetMediaTrackInfo_Value(track, "I_RECMON",0)	
			
	else
		--we create a new track just above the track with selected items
		reaper.InsertTrackAtIndex(trackNum-1, true)
		track = reaper.GetTrack(0,trackNum-1)

		--select only one track and deselect others
		reaper.SetOnlyTrackSelected(track)
		
		reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', TRACK_NAME, true)
		--we disable armed
		reaper.SetMediaTrackInfo_Value(track, "I_RECARM",0)
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
	
	items_pos_infos = {}
	for i = 0, nbr_of_items-1 do
		item = reaper.GetSelectedMediaItem(0,i)
		item_start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
		item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
		item_end = item_start + item_length
		
		items_pos_infos[i+1]={i_start=item_start, i_length = item_length, i_end = item_end}
	end
	
	--get the earlier item start position
	array2Dsort(items_pos_infos,"i_start")
	start_first_item=items_pos_infos[1].i_start
	
	--get the lastest item end position
	array2Dsort(items_pos_infos,"i_end")
	end_last_item=items_pos_infos[#items_pos_infos].i_end

	--get the new chord track or folder track
	chordTrack=reaper.GetSelectedTrack( 0, 0)
	nbr_of_items2= reaper.CountTrackMediaItems(chordTrack)
	
	--if an item already exists we delete it
	nbr_item_on_track= reaper.CountTrackMediaItems(chordTrack)
	--we have to iterate backwards to avoid missing index in the loop as we potentialy remove item(s) on each loop
	for i=nbr_item_on_track-1,0,-1 do
		item=reaper.GetTrackMediaItem( chordTrack, i)
		start_cur_item=reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
		
		--be carefull of the round() function here. Because of the way duplicate_sel_item_to_sel_track() function works we need to round some values. @see duplicate_sel_item_to_sel_track()
		if start_cur_item >= round(start_first_item) and start_cur_item < end_last_item then
			reaper.DeleteTrackMediaItem(chordTrack, item)
		end

	end
	
	--Using me2beats code here.
	duplicate_sel_item_to_sel_track()
	
	reaper.Main_OnCommand(40919, 0) -- Item: Set item mix behavior to always mix
	reaper.Main_OnCommand(40362, 0) --Item: Glue items, ignoring time selection
	reaper.Main_OnCommand(40922, 0) --Item: Set item mix behavior to project default
end


-----------------------------
-- Define Class Constructor
-----------------------------

function MergingTool:new(t)
	t=t or {}
	setmetatable(t,self)
	self.__index=self
	return t
end