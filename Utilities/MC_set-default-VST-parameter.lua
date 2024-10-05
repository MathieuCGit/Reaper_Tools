-- @description Set VST parameters fo portable install (Vital)
-- @author Mathieu CONAN   
-- @version 0.4.2
-- @changelog FIX: prevent freeze/lag/flickering when folder already exists
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about Set some default preferences for some VST instruments. It aims to provide a default environment for portable reaper installation (typicaly on an USB stick or on the Desktop). 
--    Actualy supported:
--	  - Vital synth
--

--
--
--[[	FILES AND FOLDERS FUNCTIONS	]]--
--
--
	--- Check if a file or directory exists in this path
	function exists(file)
	   local ok, err, code = os.rename(file, file)
	   if not ok then
		  if code == 13 then
			 -- Permission denied, but it exists
			 return true
		  end
	   end
	   return ok, err
	end


	--This method attempts to rename the path to itself, which will succeed for files but fail for directories on some systems.
	-- Function to check if a path is a file, folder, or does not exist (cross-platform)
	function is_file_or_folder(path)
		local file = io.open(path, "r")

		-- If it can be opened, it's a file
		if file then
			file:close()
			return "file"
		else
			-- Try os.rename, which behaves differently for files and folders
			local ok, err, code = os.rename(path, path)
			if ok then
				return "folder"
			elseif code == 13 then
				-- Permission denied, but it exists (likely a folder)
				return "folder"
			else
				return "does not exist"
			end
		end
	end

	-- Function to create a new directory, cross-platform
	function create_directory(dir_path)
		local current_os = reaper.GetOS()
		local command

		-- Use "mkdir -p" for Unix-based systems (macOS, Linux), and "mkdir" for Windows
		if current_os == "Win64" then
			command = 'mkdir "' .. dir_path .. '"'
		else 
			command = 'mkdir -p "' .. dir_path .. '"'
		end

		-- Execute the command
		local result = os.execute(command)

		-- Check result and print error if directory creation failed
		if result == 0 or result == true then
			return true
		else
			return false
		end
	end

	-- Function to read all files and directories in a directory
	function get_items_in_directory(dir_path)
		local items = {}
		local current_os = reaper.GetOS()

		-- Use the appropriate command for each operating system
		local p
		if current_os == "Win64" then
			p = io.popen('dir "' .. dir_path .. '" /b /a')  -- For Windows: /b (bare format), /a (include directories)
		else
			p = io.popen('ls -A "' .. dir_path .. '"')  -- For Unix-like systems: -A (show all except . and ..)
		end

		-- Collect the results with the full file name and extension
		for item in p:lines() do
			table.insert(items, item)
		end
		p:close()

		return items
	end

	-- Function to copy a file, preserving its extension
	function copy_file(src, dest)
		-- Open the source file in binary mode for reading
		local input_file = io.open(src, "rb")
		if not input_file then
			return false
		end

		-- Open the destination file in binary mode for writing
		local output_file = io.open(dest, "wb")
		if not output_file then
			input_file:close()
			return false
		end

		-- Read the entire content of the source file
		local content = input_file:read("*all")

		-- Handle case where content is nil (should be rare)
		if content == nil then
			content = ""  -- Treat as an empty file
		end

		-- Write content to the destination file
		output_file:write(content)

		-- Close both files
		input_file:close()
		output_file:close()

		return true
	end

	-- Recursive function to copy all files and subdirectories from one directory to another
	function copy_directory_recursive(src_dir, dest_dir)
	
		--if we are in windows, separator = \ else separator = /
		local current_os=reaper.GetOS()
		local sep = current_os:match('Win') and '\\' or '/'
	
		-- Ensure both directories end with a separator (works on every system including Windows)
		if string.sub(src_dir, -1) ~= '/' then src_dir = src_dir .. '/' end
		if string.sub(dest_dir, -1) ~= '/' then dest_dir = dest_dir .. '/' end

		-- Create the destination directory
		create_directory(dest_dir)

		-- Get the list of items in the source directory
		local items = get_items_in_directory(src_dir)

		-- Copy each item to the destination directory
		for _, item in ipairs(items) do
			local src_path = src_dir .. item  -- Full path to the source item
			local dest_path = dest_dir .. item -- Full path to the destination item

			-- Check if the source is a file or directory
			local item_type = is_file_or_folder(src_path)
			if item_type == "file" then
				-- It's a file; copy it
				copy_file(src_path, dest_path)
			elseif item_type == "folder" then
				create_directory(dest_dir..sep..item)
				-- It's a directory; recursively copy it
				copy_directory_recursive(src_path, dest_path)
			end
		end
	end


function Main()

	--[[
	OSX : ~/Library/Application Support/vital/Vital.config
	Win:C:\Users\YOURNAME\AppData\Roaming\vital
	Linux:/home/user/.local/share/vital
	]]--

	local current_os=reaper.GetOS()
	--if we are in windows, separator = \ else separator = /
	local sep = current_os:match('Win') and '\\' or '/'

--[[ VITAL CONFIGURATION ]]--
	--Ressources location in the portable Reaper folder
	local vital_def_preset_path= reaper.GetResourcePath()..sep.."presets"..sep.."VST3 Presets"..sep.."Vital"..sep
	if current_os == "Win64" then
		vital_config_path=os.getenv("HOMEDRIVE")..os.getenv("HOMEPATH").."\\AppData\\Roaming\\vital\\"
		vital_preset_path=os.getenv("HOMEDRIVE")..os.getenv("HOMEPATH").."\\Documents\\Vital\\"
	elseif current_os == "OSX64" then
		vital_config_path=os.getenv("HOME").."/Library/Application Support/Vital/"
		vital_preset_path=os.getenv("HOME").."/Library/Audio/Presets/Vital/"
	end

	--if preset path doesn't  exists we create it
	if not exists(vital_preset_path) and is_file_or_folder(vital_preset_path) ~= "folder" then
		create_directory(vital_preset_path)
	else
		--if folder exists we stop the script
		return true
	end

	-- copy files recursively
	if current_os == "Win64" then
		copy_directory_recursive(vital_def_preset_path, vital_preset_path)
	elseif current_os == "OSX64" then
		os.execute("cp -rf \""..vital_def_preset_path.."\" \""..vital_preset_path.."\"")			
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
reaper.Undo_EndBlock("MC_MathieuC_SandBox", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)

