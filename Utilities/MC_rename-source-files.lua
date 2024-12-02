-- @description Rename Audio Source Files
-- @author Mathieu CONAN   
-- @version 0.2
-- @changelog FIX: Auto install rtk.lua library (adding repository and install rtk.lua)
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about Renames audio source files according to the pattern user enter. Wildcards available are $project, $tracknumber, $track, $take

-------------------------------
--[[ 	DEFAULT PARAMETERS ]]--
-------------------------------

-- Default renaming pattern
	local DEFAULT_RENAMING_PATTERN = "$project_$tracknumber-$track_$take"

---------------------------------
--[[ 	BACKGROUND FUNCTIONS ]]--
---------------------------------

-- Sanitize file name
function sanitize_file_name(name)
    -- Replace invalid characters and dots with safe alternatives
    return name:gsub("[<>:\"/\\|%?%*%.]", "-"):gsub("%s+", "_")
end

-- Copy file using Lua I/O (means os independant)
function copy_file(src, dest)
    local inputFile = io.open(src, "rb")
    if not inputFile then
        return false, "Unable to open source file: " .. src
    end

    local outputFile = io.open(dest, "wb")
    if not outputFile then
        inputFile:close()
        return false, "Unable to create destination file: " .. dest
    end

    -- Copy content
    local content = inputFile:read("*all")
    outputFile:write(content)

    -- Close files
    inputFile:close()
    outputFile:close()

    return true
end

-- parse input var and replace wildcards
function replace_placeholders(pattern, replacements)
	return (pattern:gsub("%$(%w+)", function(key)
		return replacements[key] or "$" .. key
	end))
end

function rename_source_file(new_name_pattern)

    -- Use default pattern if no custom pattern is provided
    if not new_name_pattern or new_name_pattern == "" then
        new_name_pattern = DEFAULT_RENAMING_PATTERN
	end
	
    -- Get the project name
    local project_path = reaper.GetProjectPathEx(0, "")
    local project_name = reaper.GetProjectName(0, "")
    project_name = project_name:gsub("%.rpp$", "") -- Remove the .rpp extension
	
    -- Loop through selected items
    local count = reaper.CountSelectedMediaItems(0)
    if count == 0 then
		reaper.MB( "No items selected.", "No items selected.", 0 )
        return
    else
        for i = 0, count - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            if item then

				-- Get the track and track number
				local track = reaper.GetMediaItemTrack(item)
				local track_number = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
				local _, track_name = reaper.GetTrackName(track)

				-- Get the active take
				local take = reaper.GetActiveTake(item)
				local take_name = "[No Take]"
				if take then
					take_name = reaper.GetTakeName(take)				
				end

				-- Default names if missing
				if not track_name or track_name == "" then track_name = "Track" .. tostring(track_number) end
				if not take_name or take_name == "" then take_name = "Take" .. tostring(i + 1) end

				-- Sanitize names for safe file naming
				track_name = sanitize_file_name(track_name)
				take_name = sanitize_file_name(take_name)

                -- Prepare replacements table
                local replacements = {
                    track = track_name,
                    take = take_name,
                    tracknumber = string.format("%02d", track_number), -- Zero-padded track number and 2 digit track number
                    project = project_name
                }

				-- Construct the new name
				 local new_name = replace_placeholders(new_name_pattern, replacements)

				if take and not reaper.TakeIsMIDI(take) then
					-- Get the source file for the take
					local source = reaper.GetMediaItemTake_Source(take)
					local source_path = reaper.GetMediaSourceFileName(source, "")

					-- Get the directory and file extension
					local dir = source_path:match("^(.*[/\\])")
					local ext = source_path:match("^.+(%..+)$")

					if dir and ext then
						-- Generate new file path
						local new_path = dir .. new_name .. ext

						-- Copy the file using Lua native I/O
						local success, err_msg = copy_file(source_path, new_path)
						if success then

							-- Update the active take's source to the new file
							local new_source = reaper.PCM_Source_CreateFromFile(new_path)
							if new_source then
								reaper.SetMediaItemTake_Source(take, new_source)
								
								 -- Rebuild peaks for the new source
								reaper.Main_OnCommand(41743, 0) -- Rebuild all peaks
							else
								reaper.MB( "Failed to create new source for: " .. new_path .. "\n", "ERROR", 0 )
							end
						end
					end
				end
			end
		end
	end
end

-----------------------
--[[ 	RTK WINDOW ]]--
-----------------------

function show_rename_ui()

    -- Create the main window
    local window = rtk.Window{
        w = 400, h = 250,
        title = "Rename Audio Source Files",
        resizable = false
    }
	--create vertical box
	box=window:add(rtk.VBox({       
		spacing = 10, 
        lpadding = 20, 
        rpadding = 20, 
        tpadding = 20, 
        bpadding = 20
	}))
    
    -- Add renaming information to the box
    box:add(rtk.Text{
        text = "Enter a renaming scheme for the audio source files.\n\n" ..
               "Available Wildcards:\n" ..
               "  $project - Project name\n" ..
               "  $tracknumber - Track number (zero-padded)\n" ..			   
               "  $track - Track name\n" ..
               "  $take - Take name\n" .. 
			   "Default Pattern: " .. DEFAULT_RENAMING_PATTERN,
        fontsize = 18,
        wrap = true
    })

	
	--add the input text field
	local entry = box:add(rtk.Entry{placeholder='enter the file name scheme here', textwidth=20})
	entry.onkeypress = function(self, event)
		if event.keycode == rtk.keycodes.ESCAPE then
			self:clear()
			self:animate{'bg', dst=rtk.Attribute.DEFAULT}
		elseif event.keycode == rtk.keycodes.ENTER then
			self:animate{'bg', dst='hotpink'}
		end
	end
	
	-- Add buttons (OK and Cancel)
    local hbox = rtk.HBox{spacing = 10, halign = "center"}
    hbox:add(rtk.Button{
        label = "OK",
        onclick = function()
            input_text = entry.value
			rename_source_file(input_text)--call background function
            window:close()
        end
    })
    hbox:add(rtk.Button{
        label = "Cancel",
        onclick = function()
            input_text = nil
            window:close()
        end
    })
	
	--load window and box
    box:add(hbox)	
	window:open()
end
-------------------------------------
------------- RTK END ---------------
-------------------------------------


function Main()

 -- Determine the appropriate path separator based on the operating system
    local separator = package.config:sub(1, 1)
    local rtk_path = table.concat({reaper.GetResourcePath(), "Scripts", "rtk", "1", "rtk.lua"}, separator)
	local file = io.open(rtk_path, "r")
 
    if file then
        file:close()		
        -- Load rtk
        package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
        local rtk = require('rtk')

        -- Show the UI to gather the renaming scheme
        rtk.call(show_rename_ui)
    else
        local userinput = reaper.MB("Required library 'rtk.lua' is missing." .. "\n\n" ..
            "You need to install the 'rtk' library to run this script." .. "\n\n".."Do you want to install?",
            "MC_rename-source-files.lua", 4)
        
        if userinput == 6 then
            if reaper.APIExists('ReaPack_BrowsePackages') then
                -- Check if the repository is already set in user ReaPack preferences
                local repo_exists = reaper.ReaPack_AboutRepository("https://reapertoolkit.dev/index.xml")
                
                if repo_exists then
                    -- If yes, browse for rtk
                    reaper.ReaPack_BrowsePackages("rtk")
                else
                    -- If repo doesn't exist, install repo
                    local retval, error = reaper.ReaPack_AddSetRepository(
                        "rtk",
                        "https://reapertoolkit.dev/index.xml",
                        true,
                        1
                    )
                    reaper.ReaPack_ProcessQueue(true)
                end
            else
                reaper.ShowConsoleMsg("ReaPack not found. Opening the website to install the ReaPack plugin extension...\n")
                OpenURL("https://reapack.com/")
            end
        end
    end
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
reaper.Undo_EndBlock("Rename Audio Source Files", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)