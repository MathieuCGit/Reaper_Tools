--[[
Description: Regions - insert region to time selection / selected items / razor edit areas
Author: Mathieu CONAN   
Version: 0.1
Changelog:  initial release
Link: Github repository https://github.com/MathieuCGit/
About: Insert a region to selected items, time selection and razor edit areas.
--]]

function Main()
	----------------------------
	-- TIME SELECTION SECTION --
	----------------------------
	-- Check if there is a time selection
	local startTimeSelection, endTimeSelection = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
	local refFound = false
	
	-- Loop through all project regions
	for i = 0, reaper.CountProjectMarkers(0) - 1 do
		--get information for each marker/region
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
		
		-- If we are facing a region
		-- and if the marker/region has the same start and end time as the current time selection,
		-- then it already exists as a region in the project, so don't create a new region
		if isrgn and pos == startTimeSelection and rgnend == endTimeSelection then
			refFound=true -- set flag to true because we found a region withe time selection start and end
			break -- Exit the loop since we don't need to check any more markers/regions
		end
	end
	
	-- If we don't have an already existing region we create one
	if refFound == false then
		reaper.Main_OnCommandEx(40174, 0, 0) --Markers: Insert region from time selection
	end

	-----------------------------
	-- SELECTED ITEMS SECTION ---
	-----------------------------	
	-- check if there are selected items
	-- Get selected items
	local selectedItems = {}
	for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		table.insert(selectedItems, item)
	end

	--if at least one item is selected
	if #selectedItems > 0 then
		--we loop throught items table
		for i=1, #selectedItems do
			-- Calculate region start and end time
			local regionStart = reaper.GetMediaItemInfo_Value(selectedItems[i], "D_POSITION")
			local regionEnd = reaper.GetMediaItemInfo_Value(selectedItems[i], "D_POSITION") + reaper.GetMediaItemInfo_Value(selectedItems[i], "D_LENGTH")

			-- Insert a new region with the calculated start and end times
			reaper.AddProjectMarker2(0, true, regionStart, regionEnd, "", -1, 0)
		end
	end

	------------------------
	-- RAZOR EDIt SECTION --
	-------------------------
	-- Loop through all tracks in the project
	for i = 0, reaper.CountTracks(0) - 1 do
		local track = reaper.GetTrack(0, i)

		-- Get the razor edit string from the track
		local _, razorEditString = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)

		-- Loop through each line in the razor edit string
		for startRzeTime, endRzeTime in razorEditString:gmatch("([%d%.]+) ([%d%.]+)") do
			-- Convert the start and end times to numbers
			startRzeTime = tonumber(startRzeTime)
			endRzeTime = tonumber(endRzeTime)

			-- Loop through all markers and regions in the project
			local refFound = false -- variable to track if a region that matches the current razor edit area has been found
			local numMarkers = reaper.CountProjectMarkers(0)
			for j = 0, numMarkers - 1 do
				local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(j)

				-- If the marker/region has the same start and end time as the current razor edit area,
				-- then it already exists as a region in the project, so don't create a new one
				if isrgn and pos == startRzeTime and rgnend == endRzeTime then
					refFound = true
					break -- Exit the loop since we don't need to check any more markers/regions
				end
			end

			if not refFound then
				-- Create a region for the razor edit area
				local regionIndex = reaper.AddProjectMarker2(0, true, startRzeTime, endRzeTime, "", -1, 0)
			end
		end
	end

end

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
reaper.Undo_EndBlock("Regions - insert region to time selection / selected items / razor edit areas", - 1)

-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)