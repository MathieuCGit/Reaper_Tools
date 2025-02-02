--[[
Description: Envelope - edit selected envelope point (modal window)
Author: Mathieu CONAN   
Version: 0.2
Changelog:  2023-06-13 : FIX : now keep the envelope shape and can be used for track/fx env in addition to item/take env
Link: Github repository https://github.com/MathieuCGit/
About: instead of having to right click a point then go to "set envelope point value..." assign this script to a shortcut and directly get a modal window to change point value. It opens a modal windowsfor each point, sequentialy. I mainly use it to tweak Video processor automation.
--]]

function Main()
	-- Get the selected take envelope
	local env = reaper.GetSelectedEnvelope(0)

	if env then
		-- Get envelope name
		 _, env_name = reaper.GetEnvelopeName( env )
		 --check the parent track to know if it's a item/take env or a track/fx env
		parent_track = reaper.GetEnvelopeInfo_Value( env, "P_TRACK" )
		parent_item = reaper.GetEnvelopeInfo_Value( env, "P_ITEM" )
		
		-- if it's a take/item envelope
		if  parent_item ~= 0.0 then
			-- get current take from envolpe informations
			take, _, _ = reaper.Envelope_GetParentTake( env )
			--get current item from take informations
			item= reaper.GetMediaItemTake_Item( take )

			-- Get the number of points in the envelope
			local num_points = reaper.CountEnvelopePoints(env)
			-- Get the item start position in second
			item_start= reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
			-- Round the time in format 0.000 seconds
			item_start= tonumber(string.format("%.3f",item_start))

			-- Check each point to see if it's selected
			for i = 0, num_points - 1 do
				-- Get the envelope point
				local retval, ptime, value, shape, tension, selected = reaper.GetEnvelopePoint(env, i)
				
				-- If the point is selected, open the "Set Envelope Point Value" window
				if selected == true then
					-- Round the time in format 0.000 seconds
					ptime=tonumber(string.format("%.3f",ptime))
					-- Get the start time of the current point in seconds
					point_pos=item_start+ptime
					-- Open a dialog showing actual value and letting user change this value
					_,new_val =reaper.GetUserInputs( "Set point value", 1, "Enter point value : " , value )
					-- Set the new value to the selected point
					reaper.SetEnvelopePoint( env, i, ptime, new_val, shape, tension, 0, 0 )
				end
			end
		-- if it's a track envelope (volume, pan,...) or FX param envelope
		elseif parent_track ~= 0.0 then
			--total number of points in the envelope
			num_points= reaper.CountEnvelopePoints( env )
			-- Check each point to see if it's selected
			for i = 0, num_points - 1 do
				-- Get each envelope point informations
				local retval, ptime, value, shape, tension, selected = reaper.GetEnvelopePoint(env, i)
				
				-- If the point is selected, open the "Set Envelope Point Value" window
				if selected == true then
					-- Open a dialog showing actual value and letting user change this value
					_,new_val =reaper.GetUserInputs( "Set point value", 1, "Enter point value : " , value )
					-- Set the new value to the selected point
					reaper.SetEnvelopePoint( env, i, ptime, new_val, shape, tension, 0, 0 )
				end
			end
		end
	else
		 reaper.MB( "Select one point enveloppe.", "No point selected", 0 )
	end
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
reaper.Undo_EndBlock("Envelope - edit selected envelope point (modal window)", - 1)

-- update arrange view UI
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
