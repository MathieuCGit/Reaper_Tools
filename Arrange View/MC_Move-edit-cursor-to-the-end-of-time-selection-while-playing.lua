--[[--
Description: Move edit cursor to the end of time selection while playing
Author: Mathieu CONAN   
Version: 0.0.1
Changelog: Initial release
Link: Github repository https://github.com/MathieuCGit/MC_VariousScripts
About: This script aims to improve video derush by constantly moving edit cursor at the end of time selecion while playing.

   ### Move edit cursor to the end of time selection while playing

   This script aimes to replace edit cursor at the end time selection while we are playing.
   
   I mainly use it to improve video derush as it let me keep playing and create regions and if I stop, it restart from the end of my newly created region (which match with time selection here).
   
   It runs in background (reaper.defer()) and acts as a toggle. So it constantly replace the cursor while playing.

   ---
]]--


--
--[[ Various Functions]]
--

	--- Various Scripts
	-- @module Various_Scripts
	
	--- TCP - Move edit cursor to the end of time selection while playing
	-- @section TCP_Move_edit_cursor
	
	--- Debug function - display messages in reaper console
	-- @tparam string String aims to be displayed in the reaper console
	function Debug(String)
		reaper.ShowConsoleMsg(tostring(String).."\n")
	end


	--- Move the edit cursor at end of time selecion
	function moveEditCursorToEnd()
		local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

		if start_time ~= end_time then
			reaper.SetEditCurPos2(0, end_time, 1, 0)
		end
	end

	--- Check if a time selection exists.
	-- @treturn bool True if a time selection exists, orhterwise returns false
	function checkTimeSelection()
		starttime, endtime = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
		if starttime == endtime then
		  doesExists = false
		else
		  doesExists = true
		end
		
		return doesExists
	end


	-- Allow us to make the script toggled (on/off) in the action list. this way it can be use easier in toolbars
	-- this function is a total and unshamed copy/paste from awesome Lokasenna - Track selection follows item selection
	-- https://raw.githubusercontent.com/ReaTeam/ReaScripts/master/Items Properties/Lokasenna_Track selection follows item selection.lua
	(function()
		local _, _, sectionId, cmdId = reaper.get_action_context()

		if sectionId ~= -1 then
			--if script is running
			reaper.SetToggleCommandState(sectionId, cmdId, 1)--set toggle state to On in action list
			reaper.RefreshToolbar2(sectionId, cmdId) --set toggle State to On in toolbar

				reaper.atexit(function()
				--before script totaly stop
				reaper.SetToggleCommandState(sectionId, cmdId, 0) --set toggle state to Off in action list
				reaper.RefreshToolbar2(sectionId, cmdId)--set toggle State to Off in toolbar
				end)
		end
	end)()
    
--
--[[ CORE ]]--
--
	
function Main()

	--we check if time selection exist or not
	isThereTimeSelection = checkTimeSelection()
    
	--if time selection exists and we play the project
	if isThereTimeSelection == true and  reaper.GetPlayState() == 1 then
		moveEditCursorToEnd()--every time we will draw a time selection it will move edit cursor at the end
	end
	
reaper.defer(Main)
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

-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
