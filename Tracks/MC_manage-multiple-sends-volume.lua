-- @description Manage Multiple Sends Volume
-- @version 0.1
-- @author Mathieu CONAN
-- @link https://github.com/MathieuCGit/Reaper_Tools
-- @about
--   # Manage Multiple Sends Volume
--   This script monitors send volume changes for the track under the mouse cursor and applies the same changes to other selected tracks. It uses logarithm approach to preserve relative volume in dedibel.
-- @provides
--   [main] . > Manage Multiple Sends Volume.lua
-- @changelog
--   Initial release.

-- Function to apply changes to other selected tracks
function apply_changes(delta_vol, cur_tr_rcv_num,cur_tr_guid)
	-- how many track are selected
    local tracks_count = reaper.CountSelectedTracks(0)
	
	--for each track in this selection
    for i = 0, tracks_count - 1 do
        local cur_track = reaper.GetSelectedTrack(0, i)
        
		--we avoid applying changes to the track we currently use as a reference by using its GUID
		if cur_tr_guid ~= reaper.GetTrackGUID(cur_track) then
			--we get send volume of the next track with a differnte GUID than the one we move the button on
			local send_count = reaper.GetTrackNumSends(cur_track, 0) -- 0 for normal sends
			for j = 0, send_count - 1 do
				--for each send on this track
				local receive = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "P_DESTTRACK")
				local tr_rcv_num = reaper.GetMediaTrackInfo_Value(receive, "IP_TRACKNUMBER")
				
				-- if the destination track is the same as the track we are moving the button on
				if cur_tr_rcv_num == tr_rcv_num then
					--we get the send volume of this track
					local current_send_vol = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "D_VOL")
					-- and apply the delta to its current send volume
					reaper.SetTrackSendInfo_Value(cur_track, 0, j, "D_VOL", current_send_vol + delta_vol)
				end
			end
		end
    end
end

-- Function to monitor send volume for the track selected and under the mouse cursor
function mon_send_vol()

	--get track under mouse curosor
    local cur_track = reaper.BR_TrackAtMouseCursor()
	
    
    if cur_track then
		--if track exists, we get its GUID. It's the unique track number in the running project.
		cur_tr_guid = reaper.GetTrackGUID(cur_track)
		--if no track has been previously selected, we use this one as a kind of the memory slot 1
		if prev_tr_guid == nil then prev_tr_guid = reaper.GetTrackGUID(cur_track) end
		
		--if focused track change, we reset send volume table
		if prev_tr_guid ~= cur_tr_guid then
			--reset send vol table
			prev_send_vol={}
			--put current into the previous track variable. This way, next time track will change, script will update the right track
			prev_tr_guid=reaper.GetTrackGUID(cur_track)
		end
       
	   --we work only on selected tracks
        local is_sel = reaper.GetMediaTrackInfo_Value(cur_track, "I_SELECTED")
        if is_sel == 1.0 then
            local send_count = reaper.GetTrackNumSends(cur_track, 0) -- 0 for normal sends
			
			--for each send on the current track mouse is acting on
            for j = 0, send_count - 1 do
				--we get send volume
                local send_vol = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "D_VOL") -- 0 for regular sends
				--but also track destination
                local receive = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "P_DESTTRACK")
                local cur_tr_rcv_num = reaper.GetMediaTrackInfo_Value(receive, "IP_TRACKNUMBER")

                -- Check if the send volume has changed
                if prev_send_vol[cur_track] == nil then prev_send_vol[cur_track] = {} end
                if prev_send_vol[cur_track][j] == nil then prev_send_vol[cur_track][j] = send_vol end
                if prev_send_vol[cur_track][j] ~= send_vol then
				
					--we calculate the delta between the initial send volume receive and the one we are now getting by moving the button
					delta_vol=send_vol - prev_send_vol[cur_track][j]
					prev_send_vol[cur_track][j] = send_vol
					
                    -- call to external function to apply changes to other selected tracks
                    apply_changes(delta_vol, cur_tr_rcv_num,cur_tr_guid)
				end
            end
        end
    end
	reaper.defer(mon_send_vol) --keep script running
end

function Main()
    -- initial values
    prev_send_vol = {}
	prev_tr_guid=nil
	delta_vol=0
	--start monitoring
    mon_send_vol()
end

--
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
reaper.Undo_EndBlock("MC_manage-multiple-sends-volume", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)