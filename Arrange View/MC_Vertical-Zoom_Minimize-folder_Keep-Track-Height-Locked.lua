-- @description Vertical zoom, minimize folder, keeps track height locked, takes care of cursor position (means if no item at cursor pos track will be minimized).
-- @version 1.0
-- @author Mathieu CONAN
-- @changelog Total rewriting. Now works with spacer, folder collapsed ("small and hidden" preferences only), takes locked track.
-- @about This script aims to provide a mechanism to resize tracks height. it maximizes the tracks with items height and takes care of track without items (they are minimized too). It also takes care of cursor position. Author URI: https://forum.cockos.com/member.php?u=153781
-- @licence GPL v3
 
 --
--[[ FUNCTIONS ]]--
--
	--- Function copy/pasted and a bit of tweaking from awesome MPL "Script: mpl_Toggle show tracks if edit cursor crossing any of their items.lua"
	-- @tparam tr track is a reaper track
	-- @tparam curpos float is the edit cursor current position
	function HasCrossedItems(track, curpos)
		nbrOfItems=reaper.CountTrackMediaItems(track)
		local areThereItems=0
		
		--if tracks contains at least one item
		if nbrOfItems > 0 then
			for i = 0, nbrOfItems-1 do
				local item = reaper.GetTrackMediaItem( track, i )
				local it_pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION')
				local it_len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH')

				--check if the cursor is between the start and the end of the item
				if it_pos <= curpos and it_pos + it_len >= curpos then
					areThereItems = 1 
					break --once we are at the cursor pos we can break the loop
				else 
					areThereItems = 0 
				end
			end
		else --if no items on track, return 0
			areThereItems = 0
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
	
	---This function returns the number of spacer in the project and the size of a spacer
	function nbr_spacer()
		local nbrOfTracks=reaper.CountTracks(0)
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
		
		for i=0, nbrOfTracks-1 do
			
			track=reaper.GetTrack( 0, i)
			-- if there is a spacer above the current track
			if reaper.GetMediaTrackInfo_Value( track, "I_SPACER" ) == 1 then
				--we increment the number of spacer
				nbrOfSpacer=nbrOfSpacer+1
			end
		end
		
		return nbrOfSpacer,spacerHeight
	end
	
	---This function get the top level track folder from a given track even if there are other folders in the between
	function get_top_level_track(track)
		while true do
			local parent = reaper.GetParentTrack(track)
			if parent then
				track = parent
			else
				return track
			end
		end
	end
	
--
--[[ CORE ]]--
--
function Main()

	local nbr_tr_proj=reaper.CountTracks(0)
	local is_in_collapsed=0
	local tr_infos_array={}
	local minimum_tr_height=minimumTrackHeight()
	local spacer_in_collapsed=0
	local curPos=reaper.GetCursorPositionEx(0) --current edit cursor position
	
--------------------------------------------------------------------------	
	--[[ 		GET TRACKS INFORMATIONS IN A TABLE	]]--
--------------------------------------------------------------------------	
	for i=0,nbr_tr_proj-1 do
	
		tr=reaper.GetTrack( 0, i)
		
		--get current track infos		
		tr_lock_state=reaper.GetMediaTrackInfo_Value( tr, "B_HEIGHTLOCK" )--current track lock state
		tr_visible_state=reaper.GetMediaTrackInfo_Value( tr, "B_SHOWINTCP") --is it shown in TCP !!WARNING : output value is 0.0 or 1.0 NOT true of false
		tr_height=reaper.GetMediaTrackInfo_Value( tr, "I_TCPH" )--current track height
		nbr_items=HasCrossedItems(tr,curPos) --is there item at edit cursor position

		top_level_tr=get_top_level_track(tr) --find the top level folder if exists
		parent= reaper.GetParentTrack(tr) --get the parent folder track
		if parent then
		--if parent folder track exists
			if reaper.GetMediaTrackInfo_Value( top_level_tr, "I_FOLDERCOMPACT" ) > 0 or reaper.GetMediaTrackInfo_Value( parent, "I_FOLDERCOMPACT" ) > 0 then
			-- if there is a parent track and this parent track is a collapsed folder or the top level track is a collapsed folder
				is_in_collapsed=1
				if reaper.GetMediaTrackInfo_Value( tr, "I_SPACER" ) == 1 then
					spacer_in_collapsed=spacer_in_collapsed+1
				end
			end
		else
			is_in_collapsed=0
		end
		
		tr_infos_array[#tr_infos_array+1]=
		{	
			tr_lock_state=tr_lock_state,
			tr_visible_state=tr_visible_state,
			tr_height=tr_height,
			is_in_collapsed=is_in_collapsed,
			nbr_items=nbr_items
		}	
	end
	
	-- dbg(dumpvar(tr_infos_array))

--------------------------------------------------------------------------	
	--[[ 		COUNT VISIBLE TRACKS	]]--
--------------------------------------------------------------------------
	local tr_count=0
	local tr_vis_no_item=0
	for i=1, #tr_infos_array do
		if tr_infos_array[i]["tr_lock_state"] == 0.0 and
			tr_infos_array[i]["tr_visible_state"] == 1.0 and
			tr_infos_array[i]["is_in_collapsed"] == 0 and
			tr_infos_array[i]["nbr_items"] == 1 then
				
				--nbr of track not locked, visible, not in a collapsed folder and with at least one item
				tr_count=tr_count+1
		elseif tr_infos_array[i]["tr_visible_state"] == 1.0 and 
				tr_infos_array[i]["nbr_items"] == 0 and
				tr_infos_array[i]["is_in_collapsed"] == 0 then
				
					--nbr of track visible but without items
					tr_vis_no_item=tr_vis_no_item+1
		end
	end

--------------------------------------------------------------------------	
	--[[ 		GET SPACERS INFORMATIONS 	]]--
--------------------------------------------------------------------------	

	--get spacer numbers and default spacer height
	total_spacers,spacer_height=nbr_spacer()
	
	--remove spacers that are inside collapsed folders from total spacer count
	total_spacers=total_spacers-spacer_in_collapsed
	
--------------------------------------------------------------------------	
	--[[ 		GET ARRANGE VIEW SIZE	]]--
--------------------------------------------------------------------------
	--we get the arrangeview size (height and width)
	height,width=sizeOfArrangeView()
	
	--remove visible track with no items height from total height of arrange view (means height left for other tracks)
	height=height-(tr_vis_no_item*minimum_tr_height)

	--get total height lock for track height locked and remove it from height
	local total_locked_height=0
	for i=1,#tr_infos_array do
		track=reaper.GetTrack( 0, i-1)	
		if tr_infos_array[i]["tr_lock_state"] == 1.0 then
			total_locked_height=total_locked_height+tr_infos_array[i]["tr_height"]
		end
	end
	
	--we remove locked track height from total height of arrange view (means height left for other tracks)
	height=height-total_locked_height
	
	--we remove the spacers height from total height of arrange view (means height left for other tracks)
	height=height-(total_spacers*spacer_height)
	
	--we divide the height of the arrange view by the track count
	sizeOfEachTrack=math.floor(height/tr_count)

--------------------------------------------------------------------------	
	--[[ 		APPLY NEW TRACK HEIGHT	]]--
--------------------------------------------------------------------------	
	--resizing each track regarding state lock and other criteras
	for i=1,#tr_infos_array do
		track=reaper.GetTrack( 0, i-1)	
		if tr_infos_array[i]["tr_lock_state"] == 0.0 and
			tr_infos_array[i]["tr_visible_state"] == 1.0 and
			tr_infos_array[i]["is_in_collapsed"] == 0 and
			tr_infos_array[i]["nbr_items"] == 1 then
			
			--if track is not locked, is visible in TCP, is not in collapsed folder and has at least one item we apply the new track height
			reaper.SetMediaTrackInfo_Value( track, "I_HEIGHTOVERRIDE", sizeOfEachTrack)
		elseif tr_infos_array[i]["tr_lock_state"] == 0.0 then
			reaper.SetMediaTrackInfo_Value( track, "I_HEIGHTOVERRIDE", 1)
		else
			reaper.SetMediaTrackInfo_Value( track, "I_HEIGHTOVERRIDE", minimum_tr_height)
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