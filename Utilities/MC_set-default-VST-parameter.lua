-- @description set VST parameters fo portable install (Vital)
-- @author Mathieu CONAN   
-- @version 0.1
-- @changelog Initial release
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
	-- Function to create a new directory, cross-platform
	function create_dir(dir_path)
		-- Detect the operating system
		local isWindows = package.config:sub(1,1) == '\\'
		
		-- Command to create the directory
		local command
		
		if isWindows then
			command = 'mkdir "' .. dir_path .. '"'
		else
			command = 'mkdir -p "' .. dir_path .. '"'
		end

		-- Execute the command
		local result = os.execute(command)
		
		if result == 0 then
			print("Directory created:", dir_path)
			return true
		else
			print("Failed to create directory:", dir_path)
			return false
		end
	end

	function file_exists(name)
	   local f=io.open(name,"r")
	   if f~=nil then io.close(f) return true else return false end
	end

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

	--- Check if a directory exists in this path
	function isdir(path)
	   -- "/" works on both Unix and Windows
	   return exists(path.."/")
	end

	-- Check if folder exists --
	function FolderExists(strFolderName)
	  local fileHandle, strError = io.open(strFolderName.."\\*.*","r")
	  if fileHandle ~= nil then
		io.close(fileHandle)
		return true
	  else
		if string.match(strError,"No such file or directory") then
		  return false
		else
		  return true
		end
	  end
	end

	--This method attempts to rename the path to itself, which will succeed for files but fail for directories on some systems.
	function is_file_or_folder(path)
		-- Try to open the path as a file
		local file = io.open(path, "r")

		if file then
			file:close()

			-- Check if it can be renamed to itself (works on most systems)
			if os.rename(path, path) then
				return "file"
			else
				return "folder"
			end
		else
			-- If opening fails, check if it's a directory
			if os.rename(path, path) then
				return "folder"
			else
				return "does not exist"
			end
		end
	end

	-- Function to create a new directory, cross-platform
	function create_directory(dir_path)
		local is_windows = package.config:sub(1,1) == '\\'
		local command
		
		if is_windows then
			command = 'mkdir "' .. dir_path .. '"'
		else
			command = 'mkdir -p "' .. dir_path .. '"'
		end
		
		local result = os.execute(command)
		
		if result == 0 then
			return true
		else
			print("Failed to create directory:", dir_path)
			return false
		end
	end

	-- Function to read all files and directories in a directory
	function get_items_in_directory(dir_path)
		local items = {}
		local p = io.popen('dir "' .. dir_path .. '" /b /a')  -- For Windows: /b (bare format), /a (include directories)
		if not p then
			p = io.popen('ls -A "' .. dir_path .. '"')  -- For Unix-like systems: -A (show all except . and ..)
		end
		for item in p:lines() do
			table.insert(items, item)
		end
		p:close()
		return items
	end

	-- Function to copy a file
	function copy_file(src, dest)
		local input_file = io.open(src, "rb")
		if not input_file then
			print("Error: Cannot open source file:", src)
			return false
		end

		local output_file = io.open(dest, "wb")
		if not output_file then
			print("Error: Cannot open destination file:", dest)
			input_file:close()
			return false
		end

		local content = input_file:read("*all")
		output_file:write(content)

		input_file:close()
		output_file:close()

		return true
	end

	-- Recursive function to copy all files and subdirectories from one directory to another
	function copy_directory_recursive(src_dir, dest_dir)
		-- Ensure both directories end with a separator (works on every systems including Windows)
		if string.sub(src_dir, -1) ~= '/' then src_dir = src_dir .. '/' end
		if string.sub(dest_dir, -1) ~= '/' then dest_dir = dest_dir .. '/' end

		-- Create the destination directory
		create_directory(dest_dir)

		-- Get the list of items in the source directory
		local items = get_items_in_directory(src_dir)
		
		-- Copy each item to the destination directory
		for _, item in ipairs(items) do
			local src_path = src_dir .. item
			local dest_path = dest_dir .. item
			
			if io.open(src_path, "rb") then
				-- It's a file; copy it
				copy_file(src_path, dest_path)
			else
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
	
	--Ressources location in the portable Reaper folder
	local vital_def_preset_path= reaper.GetResourcePath()..sep.."presets"..sep.."VST3 Presets"..sep.."Vital"..sep
	
	
	if current_os == "Win64" then
		--vital
		vital_config_path=os.getenv("HOMEDRIVE")..os.getenv("HOMEPATH").."\\AppData\\Roaming\\vital\\"
		vital_preset_path=os.getenv("HOMEDRIVE")..os.getenv("HOMEPATH").."\\Documents\\Vital\\"
		
	elseif current_os == "OSX64" then
		--vital
		vital_config_path=os.getenv("HOME").."/Library/Application Support/Vital/"
		vital_preset_path=os.getenv("HOME").."/Library/Audio/Presets/Vital/"
	end

	-- vst_table={
		-- {vst_name="vital",
		-- preset_path=vital_preset_path,
		-- config_path=vital_config_path,
		-- },
		-- {vst_name="decent",
		-- preset_win=0,
		-- preset_osx=1,
		-- dest_preset_win=2,
		-- dest_preset_osx=3
		-- }
	-- }
	-- dbg(dumpvar(vst_table))

	
	--if preset path doesn't  exists we create it
	if not exists(vital_preset_path) and is_file_or_folder(vital_preset_path) ~= "folder" then
		create_dir(vital_preset_path)
	end
	
	-- Example usage
	local src_dir = vital_def_preset_path
	local dest_dir = vital_preset_path
	copy_directory_recursive(src_dir, dest_dir)
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

