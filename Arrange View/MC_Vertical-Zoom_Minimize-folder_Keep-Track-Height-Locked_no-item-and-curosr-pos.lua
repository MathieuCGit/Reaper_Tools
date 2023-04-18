-- @description Vertical zoom minimize folder keep track lock height doesn't care about cursor position (means operate for all arranvge view lenght) and doesn't care about items on track or not.
-- @version 0.3
-- @author Mathieu CONAN
-- @about Author URI: https://forum.cockos.com/member.php?u=153781
-- @licence GPL v3
-- @changelog improve vertical resizing to better fit he arrange view.
 
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
	local trackInfoArray={}
	local minimumTrackHeight=minimumTrackHeight()
	local nbrOfFolder=0
	
	for i=0,nbrOfTracks-1 do
	
		track=reaper.GetTrack( 0, i)

		--get current track infos
		lockToggle=reaper.GetMediaTrackInfo_Value( track, "B_HEIGHTLOCK" )--current track lock state
		trackHeight=reaper.GetMediaTrackInfo_Value( track, "I_TCPH" )--current track height
		trackNum=reaper.GetMediaTrackInfo_Value( track, "IP_TRACKNUMBER" ) --current track number
		folderDepth=reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH" ) --current track folder depth
	
		trackInfoArray[#trackInfoArray+1]=
		{
			trackNum=i+1, 
			trackHeight=trackHeight, 
			lockState=lockToggle, 
			folderDepth=folderDepth
		}
		
		if folderDepth == 1 then
			nbrOfFolder = nbrOfFolder+1
		end
	end
	
	--We get the total height of every folder height summed
	totalFolderHeight=nbrOfFolder*minimumTrackHeight
	--we get the arrange view dimensions
	height,width=sizeOfArrangeView()
	--we remove the folder height from the arrange view height
	height=height-totalFolderHeight
	--we get the size of each track
	sizeOfEachTrack=math.floor(height/(nbrOfTracks-nbrOfFolder))
	
	for i=0,nbrOfTracks-1 do
		track=reaper.GetTrack( 0, i)
			
		if trackInfoArray[i+1]["folderDepth"] ~= 1 and trackInfoArray[i+1]["lockState"] ~= 1 then
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