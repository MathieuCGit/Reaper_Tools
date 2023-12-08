-- @description Vertical zoom, minimize folder, keep track height locked, take care of cursor position (means if no item at cursor pos track will be minimized).
-- @version 0.2
-- @author Mathieu CONAN
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
		reaper.PreventUIRefresh(-1)
		local track = reaper.GetTrack(0, 0)
		
		--1st track size info and lock it
		local lockState=reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK") 
		local trackHeight=reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
		
		--minimization of 1rst track to minimum tarck height
		reaper.SetMediaTrackInfo_Value(track,"I_SELECTED ",0)
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", 1)
		reaper.TrackList_AdjustWindows(true)
		minimumHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
		
		--restore 1rst track size and unlock
		reaper.SetMediaTrackInfo_Value(track,"B_HEIGHTLOCK",lockState)
		reaper.SetMediaTrackInfo_Value(track,"I_HEIGHTOVERRIDE",trackHeight)
		reaper.TrackList_AdjustWindows(true)
		
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
	local trackInfoArray={}
	local minimumTrackHeight=minimumTrackHeight()
	local nbrOfTrackWithItems=0
	local nbrOfTrackWithOutItems=0

	
	for i=0,nbrOfTracks-1 do
	
		track=reaper.GetTrack( 0, i)
		curPos=reaper.GetCursorPositionEx(0) --current edit cursor position

		--get current track infos
		lockToggle=reaper.GetMediaTrackInfo_Value( track, "B_HEIGHTLOCK" )--current track lock state
		trackHeight=reaper.GetMediaTrackInfo_Value( track, "I_TCPH" )--current track height
		trackNum=reaper.GetMediaTrackInfo_Value( track, "IP_TRACKNUMBER" ) --current track number
		folderDepth=reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH" ) --current track folder depth
		areThereItems=HasCrossedItems(track,curPos) --is there item at edit cursor position

		
		if areThereItems == true then
			nbrOfTrackWithItems=nbrOfTrackWithItems+1
		elseif areThereItems == false then
			nbrOfTrackWithOutItems=nbrOfTrackWithOutItems+1
		end

		trackInfoArray[#trackInfoArray+1]=
		{
			trackNum=i+1, 
			trackHeight=trackHeight, 
			lockState=lockToggle, 
			folderDepth=folderDepth, 
			areThereItems=areThereItems
		}
	end
	
		
	heightToRemove=math.floor(minimumTrackHeight*nbrOfTrackWithOutItems)
	height,width=sizeOfArrangeView()
	newHeight=height-heightToRemove
	sizeOfEachTrack=math.floor(newHeight/nbrOfTrackWithItems)
	
	for i=0,nbrOfTracks-1 do
		track=reaper.GetTrack( 0, i)
			
		if trackInfoArray[i+1]["areThereItems"] == true and trackInfoArray[i+1]["folderDepth"] ~= 1 and trackInfoArray[i+1]["lockState"] ~= 1 then
			reaper.SetMediaTrackInfo_Value( track, "I_HEIGHTOVERRIDE", sizeOfEachTrack)
		else
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