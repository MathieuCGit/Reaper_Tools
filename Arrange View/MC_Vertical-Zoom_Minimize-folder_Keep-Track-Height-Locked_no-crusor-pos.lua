-- @description Vertical zoom minimizes folders, keeps track lock height, doesn't take care of cursor position (means operate for all arrange view lenght) BUT takes care of tracks without items.
-- @version 0.5
-- @author Mathieu CONAN
-- @changelog fix minimum track height calculation issue
-- @about Author URI: https://forum.cockos.com/member.php?u=153781
-- @licence GPL v3
 
 --
--[[ FUNCTIONS ]]--
--

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

		--get current track infos
		lockToggle=reaper.GetMediaTrackInfo_Value( track, "B_HEIGHTLOCK" )--current track lock state
		trackHeight=reaper.GetMediaTrackInfo_Value( track, "I_TCPH" )--current track height
		trackNum=reaper.GetMediaTrackInfo_Value( track, "IP_TRACKNUMBER" ) --current track number
		folderDepth=reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH" ) --current track folder depth
		nbrOfItems= reaper.CountTrackMediaItems( track ) --is there item on track
		--is it shown in TCP !!WARNING : output value is 0.0 or 1.0 NOT true of false
		isVisibleTCP=reaper.GetMediaTrackInfo_Value( track, "B_SHOWINTCP")

		--if the track is a folder BUT it gets at least one item, it becomes a track and need to be zoomed
		if folderDepth == 1 and nbrOfItems > 0 then
			folderDepth = 0
		end
		
		if nbrOfItems > 0 then 
			areThereItems = true
		else 
			areThereItems = false
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
		
		if folderDepth == 1 and isVisibleTCP == 1.0 and areThereItems == false then
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