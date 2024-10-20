-- @description Manage Multiple Sends Values (volume,mute,...)
-- @version 0.6
-- @author Mathieu CONAN
-- @link https://github.com/MathieuCGit/Reaper_Tools
-- @about
--   # Manage Multiple Sends Values
--   This script monitors send volume changes for the track under the mouse cursor and applies the same changes to other selected tracks. It uses logarithm approach to preserve relative volume in dedibel.
--    It also manage mute state for sends on selected tracks
-- @provides
--   [main] . > MC_manage-multiple-sends-values.lua
-- @changelog
--   Now takes care of channel settings to apply changes only on receive with exactly the same channel configuration

-- sends Channel informations
	-- Function to extract channel offset and count from I_SRCCHAN
	function get_channel_info(srcchan)
		if srcchan == -1 then
			return "No audio send", 0
		end
		
		-- Low 10 bits for offset
		local channel_offset = srcchan & 1023
		
		-- Higher bits (shift by 10) for channel count (0 = stereo, 1 = mono, 2 = 4-channel, etc.)
		local channel_count_code = srcchan >> 10
		local channel_count
		
		if channel_count_code == 0 then
			channel_count = 2  -- Stereo
		elseif channel_count_code == 1 then
			channel_count = 1  -- Mono
		else
			channel_count = (channel_count_code + 1) * 2  -- Multichannel (4, 6, 8, etc.)
		end
		
		return channel_offset, channel_count
	end

	-- Function to extract destination channel info from I_DSTCHAN
	function get_destination_channel_info(dstchan)
		-- Low 10 bits for destination index
		local destination_offset = dstchan & 1023
		
		-- Check if 1024 bit is set (mix to mono)
		local is_mixed_to_mono = (dstchan & 1024) ~= 0
		
		return destination_offset, is_mixed_to_mono
	end

-- Conversion functions Linear to dB and dB to linear
	function linearToDb(linear)
		if linear == 0 then
			return -math.huge
		else
			return 20 * math.log(linear, 10)
		end
	end

	function dbToLinear(db)
		return 10 ^ (db / 20)
	end

	-- Function to apply changes to other selected tracks
	function apply_changes(value, tag, cur_tr_rcv_num, cur_tr_guid, src_offset, num_src_channels, dst_offset, mix_to_mono)

		-- how many track are selected
		local tracks_count = reaper.CountSelectedTracks(0)
		-- for each track in this selection
		for i = 0, tracks_count - 1 do
			local cur_track = reaper.GetSelectedTrack(0, i)
			
			-- we avoid applying changes to the track we currently use as a reference by using its GUID
			if cur_tr_guid ~= reaper.GetTrackGUID(cur_track) then
				-------------------
				--VOLUME SEND CASE
				-------------------
				if tag == "volume" then
					-- we get send volume of the next track with a different GUID than the one we move the button on
					local send_count = reaper.GetTrackNumSends(cur_track, 0) -- 0 for normal sends
					for j = 0, send_count - 1 do
						-- for each send on this track
						local receive = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "P_DESTTRACK")
						local tr_rcv_num = reaper.GetMediaTrackInfo_Value(receive, "IP_TRACKNUMBER")
	
						
						-- if the destination track is the same as the track we are moving the button on
						if cur_tr_rcv_num == tr_rcv_num then
						
						--[[ MANAGE CHANNEL SETTINGS COMPARISON ]]--
							-- Get the source and destination channel values for current send
							dsttr_src_chan = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "I_SRCCHAN") -- source channel
							dsttr_dst_chan = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "I_DSTCHAN") -- destination channel
							-- Get source channel info (offset and channel count)
							dsttr_src_offset, dsttr_num_src_channels = get_channel_info(dsttr_src_chan)
							-- Get destination channel info (offset and mix to mono flag)
							dsttr_dst_offset, dsttr_mix_to_mono = get_destination_channel_info(dsttr_dst_chan)
							
							-- If channel settings for the current send is the same than for the reference track sends
							if src_offset == dsttr_src_offset and num_src_channels == dsttr_num_src_channels and dst_offset == dsttr_dst_offset and mix_to_mono == dsttr_mix_to_mono then
							
								-- we get the send volume of this track in dB
								local current_send_vol = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "D_VOL")
									
								-- we check if the send volume is -inf.
								if current_send_vol <= 0.0 or tonumber(current_send_vol) == nil then
									--if send vol is -inf, we give it a minimal value
									current_send_vol=0.00001
								end
								
								local current_send_vol_db = linearToDb(current_send_vol)
								-- and apply the delta in dB to its current send volume
								local new_send_vol_db = current_send_vol_db + value
								local new_send_vol = dbToLinear(new_send_vol_db)
								reaper.SetTrackSendInfo_Value(cur_track, 0, j, "D_VOL", new_send_vol)
							end
						end
					end
				-------------------
				--MUTE SEND CASE
				-------------------
				elseif tag == "mute" then
					-- we get mute state and change it to its new value for each sends on selected tracks
					local send_count = reaper.GetTrackNumSends(cur_track, 0) -- 0 for normal sends
					for j = 0, send_count - 1 do

						--[[ MANAGE CHANNEL SETTINGS COMPARISON ]]--
						-- Get the source and destination channel values for current send
						dsttr_src_chan = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "I_SRCCHAN") -- source channel
						dsttr_dst_chan = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "I_DSTCHAN") -- destination channel
						-- Get source channel info (offset and channel count)
						dsttr_src_offset, dsttr_num_src_channels = get_channel_info(dsttr_src_chan)
						-- Get destination channel info (offset and mix to mono flag)
						dsttr_dst_offset, dsttr_mix_to_mono = get_destination_channel_info(dsttr_dst_chan)
		
							-- If channel settings for the current send is the same than for the reference track sends
							if src_offset == dsttr_src_offset and num_src_channels == dsttr_num_src_channels and dst_offset == dsttr_dst_offset and mix_to_mono == dsttr_mix_to_mono then							
								reaper.SetTrackSendInfo_Value(cur_track, 0, j, "B_MUTE", value)
							end
					end
				
				end
			end
		end
	end

	-- Function to monitor send values for the track selected and under the mouse cursor
	function mon_send_values()

    -- get track under mouse cursor
    local cur_track = reaper.BR_TrackAtMouseCursor()
    
    if cur_track then
        -- if track exists, we get its GUID. It's the unique track number in the running project.
        cur_tr_guid = reaper.GetTrackGUID(cur_track)
        -- if no track has been previously selected, we use this one as a kind of the memory slot 1
        if prev_tr_guid == nil then prev_tr_guid = reaper.GetTrackGUID(cur_track) end
        
        -- if focused track change, we reset send values references table
        if prev_tr_guid ~= cur_tr_guid then
            -- reset send vol table
            prev_send_vol = {}
			-- reset mute state table
			prev_mute_state = {}
            -- put current into the previous track variable. This way, next time track will change, script will update the right track
            prev_tr_guid = reaper.GetTrackGUID(cur_track)
        end
        
        -- we work only on selected tracks
        local is_sel = reaper.GetMediaTrackInfo_Value(cur_track, "I_SELECTED")
        if is_sel == 1.0 then
            local send_count = reaper.GetTrackNumSends(cur_track, 0) -- 0 for normal sends
            
            -- for each send on the current track mouse is acting on
            for j = 0, send_count - 1 do
			-------------------
			--VOLUME SEND CASE
			-------------------
                -- we get send volume
                local send_vol = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "D_VOL") -- 0 for regular sends
				
				-- we check if the send volume is -inf.
				if send_vol <= 0.0 or tonumber(send_vol) == nil then
					--if send vol is -inf, we give it a minimal value
					send_vol=0.00001
				end
				
				--convert linear value to dB scale
                local send_vol_db = linearToDb(send_vol)
				
				-- Get the source and destination channel values for current send
				local src_chan = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "I_SRCCHAN") -- source channel
				local dst_chan = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "I_DSTCHAN") -- destination channel
				-- Get source channel info (offset and channel count)
				local src_offset, num_src_channels = get_channel_info(src_chan)
				-- Get destination channel info (offset and mix to mono flag)
				local dst_offset, mix_to_mono = get_destination_channel_info(dst_chan)

                -- Get destination track number
                local receive = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "P_DESTTRACK")
                local cur_tr_rcv_num = reaper.GetMediaTrackInfo_Value(receive, "IP_TRACKNUMBER")

                if prev_send_vol[cur_track] == nil then prev_send_vol[cur_track] = {} end
                if prev_send_vol[cur_track][j] == nil then prev_send_vol[cur_track][j] = send_vol_db end
                if prev_send_vol[cur_track][j] ~= send_vol_db then
                    
                    -- we calculate the delta between the initial send volume receive and the one we are now getting by moving the button
                    delta_vol_db = send_vol_db - prev_send_vol[cur_track][j]
                    prev_send_vol[cur_track][j] = send_vol_db
					
                    -- call to external function to apply changes to other selected tracks
                    apply_changes(delta_vol_db,"volume", cur_tr_rcv_num, cur_tr_guid, src_offset, num_src_channels, dst_offset, mix_to_mono)
                end
				
			-------------------
			--MUTE SEND CASE
			-------------------
			 -- we get mute state
                local mute_state = reaper.GetTrackSendInfo_Value(cur_track, 0, j, "B_MUTE") -- 0 for regular sends
			
                if prev_mute_state[cur_track] == nil then prev_mute_state[cur_track] = {} end
                if prev_mute_state[cur_track][j] == nil then prev_mute_state[cur_track][j] = mute_state end
                if prev_mute_state[cur_track][j] ~= mute_state then
                    
                    prev_mute_state[cur_track][j] = mute_state
                    
                    -- call to external function to apply changes to other selected tracks
                    apply_changes(mute_state,"mute", cur_tr_rcv_num, cur_tr_guid,src_offset, num_src_channels, dst_offset, mix_to_mono)
                end            
			end
        end
    end
    reaper.defer(mon_send_values)
end


-- Toggle state functions
	-- suggestion by HIPOX (https://forum.cockos.com/showpost.php?p=2807921&postcount=18) to get the toolbar button follow toggle state, thank you !
	function button_toggle_state(set) -- Set ToolBar Button State
	  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
	  reaper.SetToggleCommandState(sec, cmd, set or 0)
	  reaper.RefreshToolbar2(sec, cmd)
	end

	function Exit()
	  button_toggle_state()
	end

function Main()
    -- Start monitoring send values
    prev_tr_guid = nil
    delta_vol_db = 0
	prev_send_vol = {}
	prev_mute_state = {}
    mon_send_values()
	
	--toggle toolbar button state functions
	button_toggle_state(1)
	reaper.atexit(Exit)
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
reaper.Undo_EndBlock("MC_manage-multiple-sends-values", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)