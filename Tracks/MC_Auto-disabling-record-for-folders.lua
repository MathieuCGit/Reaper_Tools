-- @description Auto-disabling record arm button and input for folders
-- @author Mathieu CONAN   
-- @version 0.1
-- @changelog init
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about Runs in background and prevent folders to be set to any input other than "none" and set record to disable. If the folder becomes a normal track, record options will be restored.

-- Checks if a track is a folder.
function is_folder(track)
    if not track then return false end
    local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    return folder_depth > 0
end

-- Table to store previous track states (key: track index)
local track_states = {}

-- Sets the record arm and input, storing or restoring the previous state as needed.
function set_record_arm_and_input(track, enable)
    if not track then return end

    local track_index = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

    if enable then
        -- Restore previous state if it exists.
        if track_states[track_index] then
            reaper.SetMediaTrackInfo_Value(track, "I_RECARM", track_states[track_index].rec_arm)
            reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", track_states[track_index].rec_input)
            track_states[track_index] = nil -- Remove the state from the table.
        end
    else
        -- Store current state before modifying (only if not already stored).
        if not track_states[track_index] then
            track_states[track_index] = {
                rec_arm = reaper.GetMediaTrackInfo_Value(track, "I_RECARM"),
                rec_input = reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT")
            }
        end

        -- Disable record arm and set input to none.
        reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 0)
        reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", -1)
    end
end

-- Main function to monitor tracks and apply record arm/input settings.
function Main()
    local num_tracks = reaper.CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        if track then
            set_record_arm_and_input(track, not is_folder(track))
        end
    end

    reaper.defer(Main) -- Reschedule the function.
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
reaper.Undo_EndBlock("Auto-disabling record arm button and input for folders", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)