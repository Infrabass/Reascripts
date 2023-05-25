-- @ReaScript Name Quick Access - Fav FX
-- @Author VF
-- @Links https://github.com/Infrabass/Reascripts
-- @Version 1.0
-- @Changelog Initial release
-- @About 
--   # Quick Access - Fav FX
--   - Popup menu for favorite FX
--   - Can also be used to trigger any other actions
--   - Open the script in a text editor to read the instructions and customize your popup menu


local function Print(var) reaper.ShowConsoleMsg(tostring(var) .. "\n") end
local function Command(var) reaper.Main_OnCommandEx(tostring(var), 0, 0) end
local function CommandEx(var) reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_" .. string.sub(var, 2)), 0, 0) end

--------------------------------------------------------------------------
-- USER INSTRUCTIONS
--------------------------------------------------------------------------

-- First step is to add a keyboard shortcut to an effect in the FX browser (right click > Edit Shortcut)
-- Then open the action menu, find the new action that have been created and copy the action name and command id (right click > Copy selected action text, right click > Copy selected action command ID)

-- To add and entry in the popup menu:
-- 	 1. Duplicate a line in the t table and rename as you want, this is the text that will appear in the popup menu
-- 	 2. Duplicate a line in the id table and paste the action name before the comma, then paste the command id of the action after the comma
--   3. The order of the entries is important so be sure to duplicate those lines at the correct place

-- To add a separator in the popup menu:
-- 	 Add a line with an empty string between curvy bracket followed by a comma '{""},'

-- To add a submenu in the popup menu:
-- 	 1. Add this character before the text '>' of the submenu name to start the submenu
-- 	 2. Add entries like normal
--   3. Add this character before the text '<' of the last submenu entry to close the submenu


--------------------------------------------------------------------------
-- SCRIPT
--------------------------------------------------------------------------

function Main()
	local t = {
		{"ReaEQ"},
		{""},
		{">Submenu Example"},
		{"ReaComp"},
		{"<ReaPitch"},
	}

    local id = {
    	{"ReaEQ", "_FX843a89145dc9d6c5c85ccac77059e075dcc0c142"},
        {"ReaComp", "_FX2d7aaa4b9aed47cb9019fd1c55c216d413ea8dca"},
        {"ReaPitch", "_FX6cbf07acce949a5e7989e026a053bf9d0bb677f4"},
    }    

	local menu = ""
	for i = 1, #t do
	  menu = menu .. t[i][1] .. "|"
	end

	local title = "Hidden gfx window for showing the template showmenu"
	gfx.init( title, 0, 0, 0, 0, 0 )
	gfx.x, gfx.y = gfx.mouse_x-52, gfx.mouse_y-70
	local key = gfx.showmenu(menu)
    local selection
   	gfx.quit()
    if key > 0 then
        selection = id[key][2]
        CommandEx(selection)
    end

	::exit::
end


reaper.Undo_BeginBlock2(0)

--local start = reaper.time_precise()

Main()

-- local elapsed = reaper.time_precise() - start
-- Print("Script executed in ".. elapsed .." seconds")

scrName = ({reaper.get_action_context()})[2]:match(".+[/\\](.+)")
reaper.Undo_EndBlock2(0, scrName, -1)
--reaper.defer(function() end)
