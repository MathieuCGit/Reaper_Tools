-- @description Vertical zoom minimizes folders, keeps track lock height, doesn't take care of cursor position (means operate for all arrange view lenght) AND doesn't take care of tracks without items.
-- @version 2.0
-- @author Mathieu CONAN
-- @about This script aims to provide a mechanism to resize tracks height. it maximizes the tracks with items height and doesn't take care of track without items. It doesn't take care of cursor position.Author URI: https://forum.cockos.com/member.php?u=153781
-- @licence GPL v3
-- @changelog Now have a better behaviour with fixed item lanes
 
--
--[[ FUNCTIONS ]]--
--
	--- get the minimum track height on a project. This size is theme related so it may change from on theme to another.
	-- this is a workaround by CFillion : [https://forum.cockos.com/showpost.php?p=2283520&postcount=17](https://forum.cockos.com/showpost.php?p=2283520&postcount=17)
	-- @warning due to the workaround use here, screen will quickly blink once while looking for min track height.
	function minimumTrackHeight()
		--get first track avoiding folders and fixed lanes
		local nbr_tr= reaper.CountTracks(0)		
		
		for i=0, nbr_tr-1 do
			track=reaper.GetTrack(0, i)
			tr_lock_state=reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK") 
			tr_height=reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
			is_tr_fil, _ = reaper.GetSetMediaTrackInfo_String( track, "P_LANENAME:0", "", 0 ) -- check track to get FIL true/false
			
			if reaper.GetMediaTrackInfo_Value( track, "I_FOLDERDEPTH") ~= 1 and  
			reaper.IsTrackVisible(track,false ) and
			tr_lock_state == 0.0 and
			is_tr_fil == false then
			--if the track is not a folder, is visible and hasn't lanes wee keep it
				track=reaper.GetTrack(0, i)
				break
			end
		end
		
		--remove potential refresh lock state. Potentialy toggling "reaper.TrackList_AdjustWindows(true)" function in a disable state
		reaper.PreventUIRefresh(-1)	
		--minimization of 1rst track to minimum tarck height
		reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", 1)
		reaper.TrackList_AdjustWindows(true)
		minimumHeight = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
		
		--restore 1rst track size and unlock
		reaper.SetMediaTrackInfo_Value(track,"B_HEIGHTLOCK",tr_lock_state)
		reaper.SetMediaTrackInfo_Value(track,"I_HEIGHTOVERRIDE",tr_height)
		reaper.TrackList_AdjustWindows(true)
		
		--return to previous refresh UI state
		reaper.PreventUIRefresh(1)
		return minimumHeight
	end

	--- This function use Julian Sader method to get arrange view height and width
	function sizeOfArrangeView()
		local _, left, top, right, bottom = reaper.JS_Window_GetClientRect( reaper.JS_Window_FindChildByID( reaper.GetMainHwnd(), 1000) )
		
		if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" or reaper.GetOS() == "Other" then
		    heightOfArrangeView = bottom - top
		elseif reaper.GetOS() == "OSX32" or reaper.GetOS() == "OSX64" or "macOS-amd64" then
			heightOfArrangeView = top - bottom
		end
		widthOfArrangeView = right - left
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

	---This function rounds the number passed in argument to the upper interger
	function round(num) 
		return math.floor(num + 0.5)
	end
--
--[[ CORE ]]--
--
function Main()
	--we can't get the master track real height so we use a 
	local master_tr_height = 74
	local master_tr_vis = reaper.GetMasterTrackVisibility()
	local nbr_tr_proj=reaper.CountTracks(0)
	local tr_infos_array={}
	local minimum_tr_height=minimumTrackHeight()
	local spacer_in_collapsed=0
	local spacer_before_invisible=0
	
--------------------------------------------------------------------------	
	--[[	GET TRACKS INFORMATIONS IN A TABLE	]]--
--------------------------------------------------------------------------	
	for i=0,nbr_tr_proj-1 do
	
		tr=reaper.GetTrack( 0, i)
		--current track lock state
		tr_lock_state=reaper.GetMediaTrackInfo_Value( tr, "B_HEIGHTLOCK" )		
		--is it shown in TCP !!WARNING : output value is 0.0 or 1.0 NOT true of false
		tr_visible_state=reaper.GetMediaTrackInfo_Value( tr, "B_SHOWINTCP") 
		--current track height
		tr_height=reaper.GetMediaTrackInfo_Value( tr, "I_TCPH" )
		--Track is a folder
		if reaper.GetMediaTrackInfo_Value( tr, "I_FOLDERDEPTH" ) == 1 then tr_is_folder= 1 else tr_is_folder= 0 end
		--number of items on the current track
		nbr_items=reaper.CountTrackMediaItems(tr)


	--[[ MANAGE COLLAPSED FOLDERS ]]--
		local is_in_collapsed=0
		--find the top level folder if exists
		top_level_tr=get_top_level_track(tr)
		tr_depth=reaper.GetTrackDepth(tr)

        if tr_depth >= 1 and tr_visible_state == 1.0 then
			parent=reaper.GetParentTrack(tr)				
            while parent do
                --if there is a parent track and this parent track is a collapsed folder or the top level track is a collapsed folder
                if reaper.GetMediaTrackInfo_Value( parent, "I_FOLDERCOMPACT" ) > 0 then
                    is_in_collapsed=1
                end
            parent=reaper.GetParentTrack(parent)
            end
        else
            is_in_collapsed=0
		end
		
	--[[ SPACERS BEFORE CURRENT TRACK ]]--
		if reaper.GetMediaTrackInfo_Value( tr, "I_SPACER" ) == 1 then
			has_spacer=1
		else
			has_spacer=0
		end
				
	--[[ MANAGE FIXED ITEM LANES TRACK (multiple lanes) ]]--
		-- check track to get FIL true/false
		is_tr_fil, _ = reaper.GetSetMediaTrackInfo_String( tr, "P_LANENAME:0", "", 0 ) 
		
		--if we are on a fixed item lane track
		if is_tr_fil then 
			num_items = reaper.CountTrackMediaItems(tr)
			item_for_height=reaper.GetTrackMediaItem(tr, 0)
			if item_for_height then
				--we check lane height with any items on track
				nbr_fil_lanes = round(1 / reaper.GetMediaItemInfo_Value(item_for_height, 'F_FREEMODE_H')) 
			else
				nbr_fil_lanes=0
			end
		end

	--[[ MANAGE ENVELOPE (visible and in lanes or not) ]]--
	--for each track we check if there is at least one envelope
		nbr_env= reaper.CountTrackEnvelopes(tr)
		nbr_env_lane=0
		envs_height_per_tr=0
		
		if nbr_env > 0 then
			--for each envelope on the track we get its height
			for i=0, nbr_env-1 do
				env= reaper.GetTrackEnvelope( tr, i)
				br_env=reaper.BR_EnvAlloc( env, true )
				_, visible, _, inLane, _, _, _, _, _, _, _, _ = reaper.BR_EnvGetProperties( br_env )
				if inLane and visible then
					--keep env lane height
					lane_height = reaper.GetEnvelopeInfo_Value( env, "I_TCPH" )
					envs_height_per_tr=envs_height_per_tr+lane_height
					nbr_env_lane=nbr_env_lane+1

				end
				--free ressource, as indicate by reaper.BR_EnvAlloc documentation
				reaper.BR_EnvFree( bf_env, true )
			end
		end
			
		--put everything in an array
		tr_infos_array[#tr_infos_array+1]=
		{	
			tr_lock_state=tr_lock_state,
			tr_visible_state=tr_visible_state,
			tr_height=tr_height,
			tr_is_folder=tr_is_folder,
			is_in_collapsed=is_in_collapsed,
			is_tr_fil=is_tr_fil,
			nbr_fil_lanes=nbr_fil_lanes,
			nbr_items=nbr_items,
			has_spacer=has_spacer,
			nbr_env_lane=nbr_env_lane,
			envs_height_per_tr=envs_height_per_tr			
		}	
	end

------------------------------------------------------------	
	--[[		GET TOTAL HEIGHT OF VISIBLE ENVELOPE	]]--
------------------------------------------------------------

	--count the total height (in pixel) for every envelopes in lane
	proj_envs_height=0
	for i=1, #tr_infos_array do
		if tr_infos_array[i]["nbr_env_lane"] > 0 and
			tr_infos_array[i]["is_in_collapsed"] == 0 then
			proj_envs_height= proj_envs_height +tr_infos_array[i]["envs_height_per_tr"]
		end
	end

--------------------------------------------------------------------------	
	--[[		COUNT FOLDERS WITHOUT ITEMS 		]]--
--------------------------------------------------------------------------
	local empty_folder_cnt=0
	for i=1, #tr_infos_array do
		if tr_infos_array[i]["tr_lock_state"] == 0.0 and
			tr_infos_array[i]["tr_visible_state"] == 1.0 and
			tr_infos_array[i]["is_in_collapsed"] == 0 and
			tr_infos_array[i]["tr_is_folder"] == 1 and
			tr_infos_array[i]["nbr_items"] == 0 then
			
				--nbr of folder not locked, visible, not in a collapsed folder and with no items
				empty_folder_cnt=empty_folder_cnt+1
		end
	end
--------------------------------------------------------------------------	
	--[[		COUNT VISIBLE TRACKS	]]--
--------------------------------------------------------------------------
	local tr_count=0
	for i=1, #tr_infos_array do
		if tr_infos_array[i]["tr_lock_state"] == 0.0 and
			tr_infos_array[i]["tr_visible_state"] == 1.0 and
			tr_infos_array[i]["is_in_collapsed"] == 0 then
			
				--nbr of track not locked, visible, not in a collapsed folder
				tr_count=tr_count+1
		end
	end
	--we remove folder with no items from the track count (we will minimize those folders)
	tr_count=tr_count-empty_folder_cnt
	
--------------------------------------------------------------------------	
	--[[		GET SPACERS INFORMATIONS 	]]--
--------------------------------------------------------------------------	

	--get spacer numbers and default spacer height
	_,spacer_height=nbr_spacer()
	
	--nbr of spacer to remove (they are inside collapsed folders or before invisible tracks)
	local spacer_to_remove=0
	for i=1, #tr_infos_array do
		if tr_infos_array[i]["has_spacer"] == 1 and
		   tr_infos_array[i]["tr_visible_state"] == 1.0 and
		   tr_infos_array[i]["is_in_collapsed"] == 0 then
		 
				spacer_to_remove = spacer_to_remove+1
		end
	end
	
--------------------------------------------------------------------------	
	--[[		GET ARRANGE VIEW SIZE	]]--
--------------------------------------------------------------------------
	--we get the arrangeview size (height and width)
	height,width=sizeOfArrangeView()

	--if master track is visible, we remove its height from total height and we minimize it
	if master_tr_vis == 1 then
		height=height-master_tr_height
		mst_tr= reaper.GetMasterTrack(0)
		reaper.SetTrackSelected( mst_tr, true )
		reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_MINTRACKS'),0)--SWS: Minimize selected track(s)
	end	
	
	--get total height lock for track height locked and remove it from height
	local total_locked_height=0
	local tr_locked_count=0
	for i=1,#tr_infos_array do
		track=reaper.GetTrack( 0, i-1)	
		if tr_infos_array[i]["tr_lock_state"] == 1.0 then
		tr_locked_count=tr_locked_count+1
			total_locked_height=total_locked_height+tr_infos_array[i]["tr_height"]
		end
	end
	height=height-total_locked_height

	--we remove empty folder track total height
	height = height - (empty_folder_cnt*minimum_tr_height)

	--we remove minimized track envelope's height
	height=height-proj_envs_height
	
	--we remove the spacers height from height
	height=height-(spacer_to_remove*spacer_height)
	
	--we divide the height of the arrange view by the track count
	size_of_each_track=math.floor(height/tr_count)
	
--------------------------------------------------------------------------	
	--[[ 		APPLY NEW TRACK HEIGHT	]]--
--------------------------------------------------------------------------	
	--resizing each track regarding state lock and other criteras
	for i=1,#tr_infos_array do
		tr=reaper.GetTrack( 0, i-1)
		
		--if track is not locked, is visible in TCP, is not in collapsed folder we apply the new track height
		if tr_infos_array[i]["tr_lock_state"] == 0.0 and
			tr_infos_array[i]["tr_visible_state"] == 1.0 and
			tr_infos_array[i]["is_in_collapsed"] == 0 then

			--if the track is a folder and has no items, we minimize it
			if tr_infos_array[i]["tr_is_folder"] == 1 and tr_infos_array[i]["nbr_items"] == 0 then
				reaper.SetMediaTrackInfo_Value( tr, "I_HEIGHTOVERRIDE", 1)
			else
				reaper.SetMediaTrackInfo_Value( tr, "I_HEIGHTOVERRIDE", size_of_each_track)
			end
				
		elseif tr_infos_array[i]["tr_lock_state"] == 0.0 then
		
			reaper.SetMediaTrackInfo_Value( tr, "I_HEIGHTOVERRIDE", 1)
			
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
reaper.ClearConsole()

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