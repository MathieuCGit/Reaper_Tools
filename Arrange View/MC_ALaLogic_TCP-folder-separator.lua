--[[--
Description: Draw separator on folder track - aka A la Logic X
Author: Mathieu CONAN   
Version: 0.0.2
Changelog: Fix : check for already existing data on folder track now check every kind of data and not only MIDI.
Link: Github repository https://github.com/MathieuCGit/MC_VariousScripts
About: This script aims to reproduce the folder separation in a way Logic X does it.

   ### Draw separator on folder track

   This script aimes to provide a mechanism similar to the one in LogicProX to separate 
   folders in the Arrange View.

   ---
   ### Options

   Actually you have to customize your preferences directly into the script.


   **``TRACK_HEIGHT``**
    This **MUST** be **AT LEAST** 2 pixels higher than the size defined in Preferences > Apparence > Media > "Hide labels for items when item take lane height is less than". 
    You also have to uncheck "draw labels above items, rather than within items"
    _Default value is **``28``**_ but I got better result with 20pixels.
   - Default 6 and dafault 5 theme TRACK_HEIGHT=25. 
   - 25 Also works with Jane, Funktion.
   - iLogic V2 = 28
   - iLogic V3 = 24
   - Flat Madness and CubeXD= 22

   **``TRACK_COLOR_SINGLE``**
    Do you want all the item folder to get the same color ? Otherwise, default folder track color will be used. _Default is **``0``**_

   **``TRACK_COLOR``**
    Use RGB color code. _Default is **``{111,121,131}``**_

   **``TRACK_COLOR_DARKER_STEP``**
    This is the amount of darkness yo uwant to apply to default track color. 0 means NO darkness. _Default is **``25``**_
  
   ---
]]--


--
--[[ USER CUSTOMIZATION ]]--
--

-- See About section above to learn more about those options
TRACK_HEIGHT=22
TRACK_COLOR_SINGLE=0
TRACK_COLOR={111,121,131}
TRACK_COLOR_DARKER_STEP = 25
ITEM_LOCK=1

--
--[[ Various Functions]]
--

	--- Various Scripts
	-- @module Various_Scripts
	
	--- TCP - Create a folder separator in arrange view
	-- @section TCP_folder_separator
	
	---Debug function - display messages in reaper console
	--@tparam string String aims to be displayed in the reaper console
	function dbg(String)

	  reaper.ShowConsoleMsg(tostring(String).."\n")
	end


	---create item on track passd in argument
	-- @tparam track track a reaper track ressource
	function createLogicXItem (track)
		--We need the end's position of the last element in the arrange view timeline.
		lastElementTimeEnd=getLastElementTimeEnd()--See getLastElementTimeEnd() functions
		
		_,trackName = reaper.GetSetMediaTrackInfo_String( track, "P_NAME",0,0)-- get track name and 
		
		endTime=lastElementTimeEnd+50 -- margin to the end of the separator.
		endTime=math.floor(endTime+0.5) -- we need an integer so we round the float
		startTime=0 --well...separator starts at project's start
		_, _ = reaper.GetSet_ArrangeView2( 0, 1, startTime, endTime )

		-- and create an item which is project lenght
		reaper.AddMediaItemToTrack(track)
		item = reaper.GetTrackMediaItem(track,0)
		reaper.SetMediaItemInfo_Value(item, "D_LENGTH", endTime)

		--we need at least one active take to get the track name as a label on items
		nbrOfTake = reaper.CountTakes( item )
		if nbrOfTake == 0 then
		--So if we have no take, we create one
			reaper.AddTakeToMediaItem( item )--add a new take
			take = reaper.GetActiveTake(item) -- make it active   
			reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", trackName, 1); --rename active take into track name
		end

		-- Reaper doesn't prevent an item of being splited even if the item is locked
		-- so this option isn't really useful for now but should be in the future
		-- it only offers a darker color so for now we'd rather to disable it
		-- reaper.SetMediaItemInfo_Value( item, "C_LOCK", ITEM_LOCK )

		if TRACK_COLOR_SINGLE == 1 then
		-- If we want one background color for every items instead of defaut folder color
			color=reaper.ColorToNative(TRACK_COLOR[1],TRACK_COLOR[2],TRACK_COLOR[3])|0x1000000
			reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
		end

		if TRACK_COLOR_DARKER_STEP > 0 and TRACK_COLOR_SINGLE == 0 then
		-- If we want one background color for every items instead of defaut folder color
		
			intTrackColor=reaper.GetMediaTrackInfo_Value( track, "I_CUSTOMCOLOR" )
			red, green, blue = reaper.ColorFromNative( intTrackColor )
			-- Debug("red : "..red.." green: "..green.." blue : "..blue)

			R=red - TRACK_COLOR_DARKER_STEP 
			if R < 0 then R =255 - R end
			G=green - TRACK_COLOR_DARKER_STEP 
			if G < 0 then G =255 - G end
			B=blue - TRACK_COLOR_DARKER_STEP 
			if B < 0 then B =255 - B end

			-- Debug("R : "..R.." G: "..G.." B : "..B)
			color=reaper.ColorToNative(R,G,B)|0x1000000
			reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
		end    

		-- we set track height and lock the track height
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", TRACK_HEIGHT);
		reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK",1)
	end
  
	---remove all items from arrange view. This function is called with reaper.atexit()
	function cleanArrangeView()
		nbrOfTrack =  reaper.CountTracks(0)--nbre of track in the project

		for i=0, nbrOfTrack-1 do
		-- for each track
		track =  reaper.GetTrack( 0, i ) --we get info from the current track
		trackFolderDepth = reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH") --we check if it's a folder or not

			if trackFolderDepth > 0.0 then -- if we are on a folder track
			deleteEmptyItemsOnTracks(track)
			reaper.SetMediaTrackInfo_Value(track, "B_HEIGHTLOCK",0)--unlock track height
			end
		end
	end
  
	--- Delete empty item on the track passed
	-- @tparam track track a reaper track ressource
    function deleteEmptyItemsOnTracks(track)
        local nbrOfItems= reaper.GetTrackNumMediaItems(track)--get nbre of items on this track

		if nbrOfItems > 1 then
		--if we have at least one item
			for i=0, nbrOfItems-1 do --for each item on this track
				item =  reaper.GetTrackMediaItem( track, i )--we get current item info

				if doesItemContainsData(item) == false then
				-- If the item doesn't contain MIDI data (ite means it's an empty item)
					reaper.DeleteTrackMediaItem( track, item ) -- we delete selcted item
				end
			end
        end
    end

	--- check if an item located on folder track is really empty or contains audio or midi data
	-- @tparam item item a Reaper media item
	-- @see deleteEmptyItemsOnTracks()
	function doesItemContainsData(item)
		if item ~= nil then
		take=reaper.GetActiveTake(item) -- we get the active take from it
			if take ~= nil then --if there is an active take
				p_source= reaper.GetMediaItemTake_Source(take)
				typeOfSource = reaper.GetMediaSourceType(p_source)
				--this check is very impotant to prevent removing already existing items with content onto folder tracks
				if typeOfSource == "EMPTY" then
					return false --if item is empty we return false, understood as "item doesn't contain data"
				else
					return true -- else we return that item contains data
				end
			end
		end
	end
  
  
	---We get the end of the lastest element in the project. Element means items, markers and regions
    -- @treturn int lastElementTimeEnd is the time in second of the end of the last element on the timeline
	function getLastElementTimeEnd()
		local lastElementTimeEnd=0
		local lastItemTimeEnd=0
		nbrOfTrack =  reaper.CountTracks(0)--nbre of track in the project

		
		--  
		--	[[ First we look for the end of the last item ]]
		-- 
			for i=0, nbrOfTrack-1 do
			--for each track
				track =  reaper.GetTrack( 0, i ) --we get info from the current track
				trackFolderDepth = reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH") --we check if it's a folder or not

				if trackFolderDepth <= 0.0 then 
				--if track is NOT a folder (normal=0) or the last track of a folder (negative values)
				nbrOfItems= reaper.GetTrackNumMediaItems(track)--get nbre of items on this track

					for j=0, nbrOfItems-1 do
					--for each item 
					item =  reaper.GetTrackMediaItem( track, j )--we get current item info
					itemStart = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
					itemLen = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
					itemEnd = itemStart+itemLen

						if item ~=nil and itemEnd > lastItemTimeEnd then
						--if the selected item ends later than the previous, we use this end time as new project end time
						lastItemTimeEnd = itemEnd
						end

					end
				end
			end


		--  
		--	[[ Then we look for the end of the last marker and/or region ]]
		-- 	
			local lastMarkerRegionTimeEnd=0
			local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)-- we need numner of region/markers
			local markerJumper=0
			local regionJumper=0
			
			for i=0, retval-1 do
			--for each marker and/or region
				_, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( 0,i)--we get position and end infos
				
				if pos > markerJumper then
				--we get the last marker position
					markerJumper = pos
				end
				
				if rgnend > regionJumper then
				--we get the last region end time
					regionJumper = rgnend
				end
				
			end

			-- if marker position is higher than region end position
			-- the marker is later than region end
			--otherwise, the region end is later.
			if markerJumper > regionJumper then
				lastMarkerRegionTimeEnd=markerJumper
			else
				lastMarkerRegionTimeEnd=regionJumper
			end

		--
		--  [[ we return the highest value]]
		--
		if lastItemTimeEnd > lastMarkerRegionTimeEnd then
			lastElementTimeEnd=lastItemTimeEnd
		else
			lastElementTimeEnd=lastMarkerRegionTimeEnd
		end
		
	-- Debug(lastElementTimeEnd)
	return lastElementTimeEnd
	end

	-- Allow us to make the script toggled (on/off) in the action list. This way it can be use easier in toolbars
	-- this function is a total and unshamed copy/paste from awesome Lokasenna - Track selection follows item selection
	-- https://raw.githubusercontent.com/ReaTeam/ReaScripts/master/Items Properties/Lokasenna_Track selection follows item selection.lua
	(function()
		local _, _, sectionId, cmdId = reaper.get_action_context()

		if sectionId ~= -1 then
			--if script is running
			cleanArrangeView()--clean folder track from every empty items except those with MIDI data
			reaper.SetToggleCommandState(sectionId, cmdId, 1)--set toggle state to On in action list
			reaper.RefreshToolbar2(sectionId, cmdId) --set toggle State to On in toolbar

				reaper.atexit(function()
				--before script totaly stop
				reaper.SetToggleCommandState(sectionId, cmdId, 0) --set toggle state to Off in action list
				reaper.RefreshToolbar2(sectionId, cmdId)--set toggle State to Off in toolbar
				cleanArrangeView()--clean folder track from every empty items except those with MIDI data
				end)
		end
	end)()
    
--
--[[ CORE ]]--
--
function Main()
	nbrOfTrack =  reaper.CountTracks(0)--nbre of track in the project
	
    for i=0, nbrOfTrack-1 do
    -- for each track
    track =  reaper.GetTrack( 0, i ) --we get info from the current track
    trackFolderDepth = reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH") --we check if it's a folder or not

        if trackFolderDepth > 0.0 then -- if we are on a folder track   
			deleteEmptyItemsOnTracks(track)--we clean the tracks from empty items
            createLogicXItem(track)-- Once track is cleared from empty items but still has items with MIDI data, we create an empty item
        end
    end
    
reaper.defer(Main)
end

--
--[[ EXECUTION ]]--
--

-- clear console debug
reaper.ShowConsoleMsg("")

reaper.PreventUIRefresh(1)

-- execute script core
Main()

-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
