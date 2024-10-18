-- @description Go to marker labeled "=START" or at project start if no marker
-- @author Mathieu CONAN   
-- @version 0.2
-- @changelog fix marker  up to 1 but no =START
-- @link Github repository https://github.com/MathieuCGit/Reaper_Tools/tree/main
-- @about This script inspired from Stephen "_Stevie_" Romer (https://forums.cockos.com/showthread.php?t=200614) let you go to =START marker if it exists and goes to beginning of the timeline if no marker exists.


function Main()

local marker_num = reaper.CountProjectMarkers(0)

	if marker_num > 0 then 
		for i=0, marker_num-1 do
			local _, _, pos, _, name, _ = reaper.EnumProjectMarkers(i)
			if name == "=START" then
				reaper.SetEditCurPos(pos, true, false)
			else
				--if no marker exists, edit cursor goes to start of the project
				reaper.Main_OnCommand( 40042, -1)				
			end
		end
	else
		--if no marker exists, edit cursor goes to start of the project
		reaper.Main_OnCommand( 40042, -1)
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
