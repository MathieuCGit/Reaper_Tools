-- @description Vertical zoom, minimize folder, keeps track height locked, takes care of cursor position (means if no item at cursor pos track will be minimized).
-- @version 0.5
-- @author Mathieu CONAN
-- @changelog fix takes care of folders with items
-- @about Author URI: https://forum.cockos.com/member.php?u=153781
-- @licence GPL v3
 
 --
--[[ FUNCTIONS ]]--
--
	--- Function copy/pasted and a bit of tweaking from awesome MPL "Script: mpl_Toggle show tracks if edit cursor crossing any of their items.lua"
	-- @tparam tr track is a reaper track
	-- @tparam curpos float is the edit cursor current position
	function HasCrossedItems(track, curpos)
		nbrOfItems=reaper.CountTrackMediaItems(track)
		local areThereItems=""
		
		--if tracks contains at least one item
		if nbrOfItems > 0 then
			for i = 0, nbrOfItems-1 do
				local item = reaper.GetTrackMediaItem( track, i )
				local it_pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION')
				local it_len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH')			
				
				--check if the cursor is between the start and the end of the item
				if it_pos <= curpos and it_pos + it_len >= curpos then
					areThereItems = true 
					break --once we are the cursor pos we can break the loop
				else 
					areThereItems = false 
				end
			end
		else --if no items on track, return false
			areThereItems = false
		end
	
	return areThereItems
	end	
	
	--- get the minimum track height on a project. This size is theme related so it may change from on theme to another.
	-- this is a workaround by CFillion : [https://forum.cockos.com/showpost.php?p=2283520&postcount=17](https://forum.cockos.com/showpost.php?p=2283520&postcount=17)
	function minimumTrackHeight()
		--get first track avoiding folders
		nbrTracks= reaper.CountTracks(0)
		for i=0, nbrTracks-1 do
			track=reaper.GetTrack(0, i)
			if reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH") ~= 1 and  reaper.IsTrackVisible(track,false )then
				track=reaper.GetTrack(0, i)
				break
			end
		end
		
		--1st track size info and lock it
		local lockState=reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK") 
		local trackHeight=reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
		
		--remove potential refresh lock state. Potentialy toggling "reaper.TrackList_AdjustWindows(true)" function in a disable state
		reaper.PreventUIRefresh(-1)	
		--minimization of 1rst track to minimum tarck height
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", 1)
		reaper.TrackList_AdjustWindows(true)
		minimumHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
		
		--restore 1rst track size and unlock
		reaper.SetMediaTrackInfo_Value(track,"B_HEIGHTLOCK",lockState)
		reaper.SetMediaTrackInfo_Value(track,"I_HEIGHTOVERRIDE",trackHeight)
		reaper.TrackList_AdjustWindows(true)
		
		--return to previous refresh UI state
		reaper.PreventUIRefresh(1)
		return minimumHeight
	end	

	--- This function use Julian Sader method to get arrange view height and width
	function sizeOfArrangeView()
		local _, left, top, right, bottom = reaper.JS_Window_GetClientRect( reaper.JS_Window_FindChildByID( reaper.GetMainHwnd(), 1000) )
		widthOfArrangeView = right - left
		heightOfArrangeView = bottom - top
		return heightOfArrangeView, widthOfArrangeView
	end
	
--
--[[ CORE ]]--
--

function Main()

	local nbrOfTracks=reaper.CountTracks(0)
	local nbrOfVisibleTracks=0	
	local trackInfoArray={}
	local minimumTrackHeight=minimumTrackHeight()
	local nbrOfTrackWithItems=0
	local nbrOfTrackWithOutItems=0
	local nbrOfFolder=0
	local nbrOfSpacer=0
	
	--with Reaper 7, spacer appears and have to be considered
	retval, buf = reaper.get_config_var_string('trackgapmax') -- get the default spacer height in the preference ini file.
	if not retval then
		--if no spacer or reaper version under 7.0
		spacerHeight=0
	else
		--get spacer defaut size
		spacerHeight= tonumber(buf)
	end
	
	for i=0,nbrOfTracks-1 do
	
		track=reaper.GetTrack( 0, i)
		curPos=reaper.GetCursorPositionEx(0) --current edit cursor position

		--get current track infos
		lockToggle=reaper.GetMediaTrackInfo_Value( track, "B_HEIGHTLOCK" )--current track lock state
		trackHeight=reaper.GetMediaTrackInfo_Value( track, "I_TCPH" )--current track height
		trackNum=reaper.GetMediaTrackInfo_Value( track, "IP_TRACKNUMBER" ) --current track number
		folderDepth=reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH" ) --current track folder depth
		areThereItems=HasCrossedItems(track,curPos) --is there item at edit cursor position
		--is it shown in TCP !!WARNING : output value is 0.0 or 1.0 NOT true of false
		isVisibleTCP=reaper.GetMediaTrackInfo_Value( track, "B_SHOWINTCP")
		
		--if the track is a folder BUT it gets at least one item, it becomes a track and need to be zoomed
		if folderDepth == 1 and areThereItems == true then
			folderDepth = 0
		end
		
		trackInfoArray[#trackInfoArray+1]=
		{
			trackNum=i+1, 
			trackHeight=trackHeight, 
			lockState=lockToggle, 
			folderDepth=folderDepth, 
			areThereItems=areThereItems,
			isVisibleTCP=isVisibleTCP
		}
		
		if isVisibleTCP == 1.0 then
			nbrOfVisibleTracks=nbrOfVisibleTracks+1
		end
		
		if folderDepth == 1 and isVisibleTCP == 1.0 then
			nbrOfFolder = nbrOfFolder+1
		end
		
		if isVisibleTCP == 1.0 and areThereItems == true then
			nbrOfTrackWithItems=nbrOfTrackWithItems+1
		end
		
		if isVisibleTCP == 1.0 and areThereItems == false and folderDepth ~= 1 then
			nbrOfTrackWithOutItems=nbrOfTrackWithOutItems+1
		end
		
		-- if there is a spacer above the current track
		if reaper.GetMediaTrackInfo_Value( track, "I_SPACER" ) == 1 then
			--we increment the number of spacer
			nbrOfSpacer=nbrOfSpacer+1
		end			
		
	end
	
	totalFolderHeight=nbrOfFolder*minimumTrackHeight
	totalSpacerHeight=spacerHeight*nbrOfSpacer
	totalTrackWithoutItemHeight=nbrOfTrackWithOutItems*minimumTrackHeight
	
	heightToRemove=totalFolderHeight+totalSpacerHeight+totalTrackWithoutItemHeight
	
	height,width=sizeOfArrangeView()
	height=height-heightToRemove
	--we get the size of each track
	sizeOfEachTrack=math.floor(height/(nbrOfVisibleTracks-(nbrOfFolder+nbrOfTrackWithOutItems)))
	
	for i=0,nbrOfTracks-1 do
		track=reaper.GetTrack( 0, i)
			
		if trackInfoArray[i+1]["areThereItems"] ==true and trackInfoArray[i+1]["folderDepth"] ~= 1 and trackInfoArray[i+1]["lockState"] ~= 1 then
			reaper.SetMediaTrackInfo_Value( track, "I_HEIGHTOVERRIDE", sizeOfEachTrack)
		else
			--if track has no items, or is a folder or is locked, we minimize it.
			reaper.SetMediaTrackInfo_Value( track, "I_HEIGHTOVERRIDE", 1)

		end
	end

	--We need to update tracklist view in addition to update arrange
	--function argument "isMinor=false" updates both TCP and MCP. "isMinor=true" updates TCP only. 
	reaper.TrackList_AdjustWindows(true)

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
reaper.Undo_EndBlock("Vertical zoom minimize folder keep track lock height", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)