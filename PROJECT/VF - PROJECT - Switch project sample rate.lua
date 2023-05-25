-- @ReaScript Name Switch project sample rate
-- @Author VF
-- @Links https://github.com/Infrabass/Reascripts
-- @Version 1.0
-- @Changelog Initial release
-- @About 
--   # Switch project sample rate
--   - Quickly switch project sample rate via a popup menu
--   - Pretty handy when added to the main toolbar


function Print(var) reaper.ShowConsoleMsg(tostring(var) .. "\n") end
function Command(var) reaper.Main_OnCommandEx(tostring(var), 0, 0) end
function CommandEx(var) reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_" .. string.sub(var, 2)), 0, 0) end

--------------------------------------------------------------------------

function Main()

	local ar_sr = {"44100","48000","96000","192000"}

	local menu = ""
	for i = 1, #ar_sr do
	  menu = menu .. ar_sr[i] .. "|"
	end

	local title = "Hidden gfx window for showing the template showmenu"
	gfx.init( title, 0, 0, 0, 0, 0 )
	gfx.x, gfx.y = gfx.mouse_x-52, gfx.mouse_y-70
	local selection = gfx.showmenu(menu)
	gfx.quit()

	if selection > 0 then
		sample_rate = tonumber(ar_sr[selection])

		reaper.GetSetProjectInfo(0, 'PROJECT_SRATE', sample_rate, 1 )
		reaper.Audio_Quit()
		reaper.Audio_Init()		
	end
	::exit::
end


reaper.Undo_BeginBlock2(0)

Main()

scrName = ({reaper.get_action_context()})[2]:match(".+[/\\](.+)")
reaper.Undo_EndBlock2(0, scrName, -1)
--reaper.defer(function() end)

