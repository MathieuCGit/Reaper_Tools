-- @description Media Explorer embeded database rescan/rebuild (for portable install)
-- @author Mathieu CONAN   
-- @version 0.1
-- @changelog Initial release
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about This script aims to rebuild embeded database for portable installation
--
--   ### Rebuild embeded database for portable installation
--
--   This script aims to rebuild the media explorer database for portable reaper installation. 
--   For example, you may have a Reaer portable installation on an USB stick
--
--   **``SAMPLE_LIB_FOLDER``**
--
--    This constant points to the folder you've created at reaper portable root folder (generally "REAPER"). In other words, inside the portable installation, samples are in SAMPLE_LIB_FOLDER folder.
--
--   You can also add this script to you reaper __startup.lua file, in this case it will automaticaly update your portable database when reaper starts.


--
--[[ USER CUSTOMIZATION ]]--
--
SAMPLE_LIB_FOLDER="SampleLib"

--
--[[ FUNCTION ]]--
--
	
-- Function to read a file and replace FILE paths. It parse file path to avoid special chars
function replace_file_paths_in_db(file_path, old_path, new_path)
	local file = io.open(file_path, "r") -- Open the file in read mode
	--if no file we quit
	if not file then return	end

	-- Read the entire content of the file and put it in a string variable
	local content = file:read("*all") 
	file:close() -- Close the file

	-- Escape special characters in old_path
	local escaped_old_path = old_path:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1")

	-- Replace the old path with the new path
	local new_content = string.gsub(content, escaped_old_path, new_path)

	-- Open the file in write mode and write the modified content
	file = io.open(file_path, "w")
	--if no file we quit
	if not file then return end

	-- Write the modified content to the file
	file:write(new_content) 
	file:close() -- Close the file

end

--
--[[ CORE ]]--
--
function Main()

	-- separators depend on operating system, windows = \, linux and osX = /
	local sep = package.config:sub(1, 1) 
	
	--Reaper current executable file -> means the portable folder
	exec_path = reaper.GetExePath()

	-- Inside the portable installation, samples are in SAMPLE_LIB_FOLDER folder
	sample_lib_path=exec_path..sep..SAMPLE_LIB_FOLDER
	
	--Get db file path with file name (default Reaper DB)
	db_path=exec_path..sep.."MediaDB"..sep.."00.ReaperFileList"
	
	--  Read the file
	local db_file = io.open(db_path, "r")
	local content = db_file:read("*all")
	db_file:close()

	_,idx_end=string.find(content, "PATH ")
	old_path=string.sub(string.match(content,"[^\r\n]+",idx_end+2),1,-2)

	replace_file_paths_in_db(db_path, old_path, sample_lib_path)

	--rescan all files with new path
	--snippet from Julian Sader : <https://forum.cockos.com/showpost.php?p=2398335&postcount=3>
	explorerHWND = reaper.OpenMediaExplorer("", false)
	reaper.JS_Window_OnCommand(explorerHWND, 42050) -- Media Explore : Rescan all files in database	
	reaper.JS_Window_OnCommand(explorerHWND, 42087) --Remove missing files from all databases
	reaper.JS_Window_OnCommand(explorerHWND, 42085) --Scan all databases for new files
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
reaper.Undo_EndBlock("MC_Media Explorer embeded database rescan/rebuild", - 1) 
  
-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
