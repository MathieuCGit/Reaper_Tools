-- @description Vertical zoom minimizes folders, keeps track lock height, doesn't take care of cursor position (means operate for all arranvge view lenght) AND doesn't take care of tracks without items.
-- @version 0.5
-- @author Mathieu CONAN
-- @about Author URI: https://forum.cockos.com/member.php?u=153781
-- @licence GPL v3
-- @changelog Now takes care of spacer in total arrange view height (Reaper 7 update)
 
--
--[[ FUNCTIONS ]]--
--

	--- get the minimum track height on a project. This size is theme related so it may change from on theme to another.
	-- this is a workaround by CFillion : [https://forum.cockos.com/showpost.php?p=2283520&postcount=17](https://forum.cockos.com/showpost.php?p=2283520&postcount=17)
	function minimumTrackHeight()
		local track = reaper.GetTrack(nil, 0)
		
		lockState=reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK") 
		trackHeight=reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
		
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", 1)
		reaper.TrackList_AdjustWindows(true)
		minimumHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
		
		reaper.SetMediaTrackInfo_Value(track,"B_HEIGHTLOCK",lockState)
		reaper.SetMediaTrackInfo_Value(track,"I_TCPH",trackHeight)
		reaper.TrackList_AdjustWindows(true)
		
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
		 --is it shown in TCP !!WARNING : output value is 0.0 or 1.0 NOT true of false
		isVisibleTCP=reaper.GetMediaTrackInfo_Value( track, "B_SHOWINTCP")
		
	
		trackInfoArray[#trackInfoArray+1]=
		{
			trackNum=i+1, 
			trackHeight=trackHeight, 
			lockState=lockToggle, 
			folderDepth=folderDepth,
			isVisibleTCP=isVisibleTCP
		}
		
		if isVisibleTCP == 1.0 then
			nbrOfVisibleTracks=nbrOfVisibleTracks+1
		end
		
		if folderDepth == 1 and isVisibleTCP == 1.0 then
			nbrOfFolder = nbrOfFolder+1
		end
		-- if there is a spacer above the current track
		if reaper.GetMediaTrackInfo_Value( track, "I_SPACER" ) == 1 then
			--we increment the number of spacer
			nbrOfSpacer=nbrOfSpacer+1
		end		
	end
	
	--We get the total height of every folder height summed
	totalFolderHeight=nbrOfFolder*minimumTrackHeight
	--we get the arrange view dimensions
	height,width=sizeOfArrangeView()
	--we remove the folder height from the arrange view height
	height=height-totalFolderHeight
	-- we remove the total size of spacer from the arrange view height
	height= height - (spacerHeight*nbrOfSpacer)
	--we get the size of each track
	sizeOfEachTrack=math.floor(height/(nbrOfVisibleTracks-nbrOfFolder))
	
	for i=0,nbrOfTracks-1 do
		track=reaper.GetTrack( 0, i)
		
		if trackInfoArray[i+1]["folderDepth"] ~= 1 and trackInfoArray[i+1]["lockState"] ~= 1 and trackInfoArray[i+1]["isVisibleTCP"] == 1.0 then
			reaper.SetMediaTrackInfo_Value( track, "I_HEIGHTOVERRIDE", sizeOfEachTrack)
		else
			reaper.SetMediaTrackInfo_Value( track, "I_HEIGHTOVERRIDE", minimumTrackHeight)

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