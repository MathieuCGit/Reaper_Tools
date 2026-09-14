-- @description Rename items to folder and track name item position number in the track
-- @author Mathieu CONAN
-- @version 0.4
-- @changelog:
--   0.4 - Added real ON/OFF toggle support for Action List and toolbars.
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about
--   This script renames items with:
--      - folder name (if track is in a folder)
--      - track name
--      - item position number in the track
--
--   The script runs continuously in the background.
--
--   It can be used as a toggle action in REAPER toolbars.
--
--   ### USER OPTIONS
--
--   SHOW_PARENT_FOLDER
--      1 = show parent folder name
--      0 = don't show parent folder name
--
--   SHOW_TRACK_NAME
--      1 = show track name
--      0 = don't show track name
--
--   SHOW_ITEM_NBR
--      1 = show item number
--      0 = don't show item number
--

--
--[[ USER OPTIONS ]]
--

SHOW_PARENT_FOLDER = 1
SHOW_TRACK_NAME    = 1
SHOW_ITEM_NBR      = 1


--
--[[ TOGGLE MANAGEMENT ]]
--

-- Get the Action List context.
--
-- sectionId identifies the Action List section in which the script
-- is running.
--
-- cmdId identifies this particular script/action.
--

local _, _, sectionId, cmdId = reaper.get_action_context()


-- This function changes the visual ON/OFF state of the action.
--
-- IMPORTANT:
-- SetToggleCommandState() does NOT start or stop a script.
-- It only tells REAPER how the action should be displayed.
--
-- The actual persistence of this script is handled by reaper.defer()
-- below, as in the original script.

local function SetToggleState(state)

    if sectionId ~= -1 then

        reaper.SetToggleCommandState(
            sectionId,
            cmdId,
            state
        )

        reaper.RefreshToolbar2(
            sectionId,
            cmdId
        )

    end
end


-- When the script starts, show it as ON.

SetToggleState(1)


-- When the script is stopped by REAPER, make sure the action
-- is displayed as OFF.

reaper.atexit(function()

    SetToggleState(0)

end)


--
--[[ CORE ]]
--

function Main()

    ------------------------------------------------------------------
    -- Iterate through all tracks in the project
    ------------------------------------------------------------------

    for i = 0, reaper.CountTracks(0) - 1 do


        ----------------------------------------------------------------
        -- Get current track
        ----------------------------------------------------------------

        local track =
            reaper.GetTrack(0, i)


        ----------------------------------------------------------------
        -- Number of items on this track
        ----------------------------------------------------------------

        local nbrOfItemsOnTrack =
            reaper.CountTrackMediaItems(track)


        ----------------------------------------------------------------
        -- PARENT FOLDER NAME
        ----------------------------------------------------------------

        local parentFolderName = ""


        if SHOW_PARENT_FOLDER == 1 then

            -- Get parent folder track.

            local parentTrack =
                reaper.GetParentTrack(track)


            if parentTrack ~= nil then

                -- Get parent folder name.

                _, parentFolderName =
                    reaper.GetSetMediaTrackInfo_String(
                        parentTrack,
                        "P_NAME",
                        "",
                        false
                    )


                -- Add underscore after folder name.

                parentFolderName =
                    parentFolderName .. "_"

            end
        end


        ----------------------------------------------------------------
        -- TRACK NAME
        ----------------------------------------------------------------

        local trackName = ""


        if SHOW_TRACK_NAME == 1 then

            -- Get track name.

            _, trackName =
                reaper.GetSetMediaTrackInfo_String(
                    track,
                    "P_NAME",
                    "",
                    false
                )


            -- If folder names are enabled,
            -- add underscore before track name.

            if SHOW_PARENT_FOLDER == 1 then

                trackName =
                    "_" .. trackName

            end


            -- If the track has no name,
            -- use its track number instead.

            if trackName == "" then

                trackName =
                    reaper.GetMediaTrackInfo_Value(
                        track,
                        "IP_TRACKNUMBER"
                    )


                -- Convert floating-point track number
                -- to integer.

                trackName =
                    math.floor(trackName)

            end

        end


        ----------------------------------------------------------------
        -- FINAL BASE NAME
        ----------------------------------------------------------------

        local finalName =
            parentFolderName .. trackName


        ----------------------------------------------------------------
        -- RENAME ITEMS
        ----------------------------------------------------------------

        if nbrOfItemsOnTrack > 0 then

            for j = 0, nbrOfItemsOnTrack - 1 do


                --------------------------------------------------------
                -- Get item
                --------------------------------------------------------

                local item =
                    reaper.GetTrackMediaItem(
                        track,
                        j
                    )


                --------------------------------------------------------
                -- Get active take
                --------------------------------------------------------

                local take =
                    reaper.GetActiveTake(item)


                if take ~= nil then


                    ----------------------------------------------------
                    -- Build final item name
                    ----------------------------------------------------

                    local itemName


                    if SHOW_ITEM_NBR == 1 then

                        itemName =
                            finalName .. "_" .. (j + 1)

                    else

                        itemName =
                            finalName

                    end


                    ----------------------------------------------------
                    -- Rename active take
                    ----------------------------------------------------

                    reaper.GetSetMediaItemTakeInfo_String(
                        take,
                        "P_NAME",
                        itemName,
                        true
                    )

                end
            end
        end
    end


    ------------------------------------------------------------------
    -- IMPORTANT:
    --
    -- This is what makes the script persistent.
    --
    -- REAPER calls Main() again after returning to its event loop.
    ------------------------------------------------------------------

    reaper.defer(Main)

end


--
--[[ EXECUTION ]]
--

-- Clear console debug output.

reaper.ClearConsole()


-- Prevent unnecessary UI refresh while processing.

reaper.PreventUIRefresh(1)


-- Execute the main function.

Main()


-- Update arrange view.

reaper.UpdateArrange()


-- Restore normal UI refresh.

reaper.PreventUIRefresh(-1)