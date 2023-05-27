-- @ReaScript Name Advanced items repositioning
-- @Screenshot https://imgur.com/vI4pc5B
-- @Author VF
-- @Links https://github.com/Infrabass/Reascripts
-- @Version 1.2
-- @Changelog
--   Time interval can now be set in seconds, frames or beats
--   Add buttons to preserve overlapping & adjacent items 
--   UI improvements
-- @About 
--   # Advanced items repositioning
--   - Use start or end of items to reposition
--   - 3 modes: TRACK, QUEUE & TIMELINE
--   - Set interval between items in seconds, frames or beats
--   - Optionally add time offset between groups of items with the same name
--   - Non-linear factor to create rallentando & accelerando
--   - Toggle to preserve overlapping items
--   - Toggle to preserve adjacent items
--   - Realtime mode to visualize result in realtime
--   - Support moving envelope points with items
--   - Support NVK folder items
--   - Support ripple edit
--   
--   ## Dependencies
--   - Requires ReaImGui


--[[
Special thanks to
- Nvk for the envelope points hack and autorisation to release with Folder Items support
- Cfillion for the help with ReaImGui and ReaPack setup (this is my first script released via my repository, woot woot!)
]]

------------------------------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------------------------------

function Print(var) reaper.ShowConsoleMsg(tostring(var) .. "\n") end

function Command(var) reaper.Main_OnCommandEx(tostring(var), 0, 0) end

function CheckFloatEquality(a,b)
	return (math.abs(a-b)<0.00001)
end

function sort_func(a,b)
	if (a.pos == b.pos) then
		return a.track < b.track
	end
	if (a.pos < b.pos) then
		return true
	end
end

function CheckTableEquality(t1,t2)
    for i,v in next, t1 do if t2[i]~=v then return false end end
    for i,v in next, t2 do if t1[i]~=v then return false end end
    return true
end

function UpdateFolderItem()
	reaper.SetExtState("nvk_FOLDER_ITEMS", "settingsChanged", 1, 0)
end

function PrintWindowSize()
	w, h = reaper.ImGui_GetWindowSize( ctx )
	Print(w.."\n"..h)		
end

function StripNumbersAndExtensions(take_name)
	if not string.match(take_name, "L_%d$") then -- If take name doesn't end with layers suffix at the end (like sfx_blabla_L1)
		if string.match(take_name, "_%d+$") then
			take_name = string.gsub(take_name, "_%d+$", "")
		elseif string.match(take_name, "_%d+%.%a+$") then
			take_name = string.gsub(take_name, "_%d+%.%a+$", "")                    
		elseif string.match(take_name, " %d+$") then
			take_name = string.gsub(take_name, " %d+$", "")
		elseif string.match(take_name, " %d+%.%a+$") then
			take_name = string.gsub(take_name, " %d+%.%a+$", "")
		elseif string.match(take_name, "%.%a+$") then
			take_name = string.gsub(take_name, "%.%a+$", "")            
		end
	end
	return take_name
end

------------------------------------------------------------------------------------
-- SECONDARY FUNCTIONS
------------------------------------------------------------------------------------

function ResetSavedParameters()
	reaper.SetExtState("vf_reposition_items", "interval_sec", "", true)
	reaper.SetExtState("vf_reposition_items", "interval_frame", "", true)
	reaper.SetExtState("vf_reposition_items", "interval_beats", "", true)
	reaper.SetExtState("vf_reposition_items", "interval_mode", "", true)
	reaper.SetExtState("vf_reposition_items", "offset_val", "", true)	
	reaper.SetExtState("vf_reposition_items", "offset_state", "", true)	
	reaper.SetExtState("vf_reposition_items", "toggle_val", "", true)
	reaper.SetExtState("vf_reposition_items", "mode_val", "", true)
	reaper.SetExtState("vf_reposition_items", "overlap", "", true)
	reaper.SetExtState("vf_reposition_items", "adjacent", "", true)
end	

function SaveInitialState()
	FI_detected = false
	t_initial = {}
	local sel_item_nb = reaper.CountSelectedMediaItems(0)
	for i=1, sel_item_nb do
		t_initial[i] = {}
        local item = reaper.GetSelectedMediaItem(0, i-1)
        if item ~= nil then
        	if FI_IsFolderItem(item) then
        		FI_detected = true
        		FI_MarkOrSelectChildrenItems(item, true)
        	end
            t_initial[i].item = item
            t_initial[i].pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        end
    end
end

function RestoreInitialState()	
	for i=1, #t_initial do
        local item = t_initial[i].item
        if item ~= nil then
        	local current_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        	t_initial[i].current_pos = current_pos
        end
    end

    -- Move items at the end of the project before repositioning them (smart hack from NVK to avoid messing the automation points)
	for i=1, #t_initial do
		RepositionItems(t_initial[i].item, t_initial[i].current_pos + 10000000)
	end

	for i=1, #t_initial do
		RepositionItems(t_initial[i].item, t_initial[i].pos)
	end	

	-- Reselect items
	for i=1, #t_initial_selection do
		reaper.SetMediaItemSelected(t_initial_selection[i], 1)
	end	
    cancel = false
end

function SaveInitialItemSelection()
	t_initial_selection = {}
	local sel_item_nb = reaper.CountSelectedMediaItems(0)
	for i=1, sel_item_nb do
        local item = reaper.GetSelectedMediaItem(0, i-1)
        if item ~= nil then
            t_initial_selection[i] = item
        end
    end
end

function SaveItemSelection()
	local t_selection = {}
	local sel_item_nb = reaper.CountSelectedMediaItems(0)
	for i=1, sel_item_nb do
        local item = reaper.GetSelectedMediaItem(0, i-1)
        if item ~= nil then
            t_selection[i] = item
        end
    end
    return t_selection
end

function Unsel_item()
	for i=1, #t_initial_selection do
		local item = t_initial_selection[i]
		reaper.SetMediaItemSelected(item, 0)
	end
end

function ForceSelectItems()
	Unsel_item()
	for i=1, #t_initial do
        local item = t_initial[i].item
        if item ~= nil then
            reaper.SetMediaItemSelected(item, 1)
        end
    end
end	

function RepositionItems(item, pos)
	Unsel_item()
	reaper.SetMediaItemSelected(item, 1)
	if FI_IsFolderItem(item) then
		FI_MarkOrSelectChildrenItems(item, true)
	end
	MarkOrSelectOverlappingItems(item, true)
	reaper.SetEditCurPos(pos, 0, 0)
	Command(41205) -- Item edit: Move position of item to edit cursor
end

function SaveSelItemsTracks()
	local t = {}
	local sel_item_nb = reaper.CountSelectedMediaItems(0)
	for i = 0, sel_item_nb - 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		local track = reaper.GetMediaItem_Track(item)
		local skip = 0
		for j = 1, #t do
			local track_check = t[j]
			if track == track_check then
				skip = 1
			end
		end
		if skip == 0 then
			table.insert(t, track)
		end
	end
	return t
end

function GetItemPos()
	local t = {}
	local counter = 1
	for i = 1, reaper.CountSelectedMediaItems(0) do
		local item = reaper.GetSelectedMediaItem(0, i-1)
		if item ~= nil then
			local _, item_mark = reaper.GetSetMediaItemInfo_String(item, "P_EXT:vf_reposition_items", "", 0)
			if item_mark ~= "Skip" then
				if FI_IsFolderItem(item) then
					FI_MarkOrSelectChildrenItems(item, false)
				end
				local total_len = MarkOrSelectOverlappingItems(item, false)
				local track = reaper.GetMediaItem_Track(item)
				t[counter] = {}				
				t[counter].item = item
				t[counter].pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
				t[counter].len = total_len
				t[counter].track = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
				t[counter].snapoffset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")		
				reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", 0) -- Remove snapoffset because native action use this instead of item start position
				counter = counter + 1
			end
		end
	end
	return t
end

function GetTrackItemPos(track)
	local t = {}
	local counter = 1	
	for i = 1, reaper.CountTrackMediaItems(track) do
		local item = reaper.GetTrackMediaItem(track, i-1)
		if item ~= nil then	
			if reaper.IsMediaItemSelected(item) then
				local _, item_mark = reaper.GetSetMediaItemInfo_String(item, "P_EXT:vf_reposition_items", "", 0)
				if item_mark ~= "Skip" then
					if FI_IsFolderItem(item) then
						FI_MarkOrSelectChildrenItems(item, false)
					end
					local total_len = MarkOrSelectOverlappingItems(item, false)
					t[counter] = {}
					t[counter].item = item
					t[counter].pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
					t[counter].len = total_len
					t[counter].snapoffset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")			
					reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", 0) -- Remove snapoffset because native action use this instead of item start position				
					counter = counter + 1
				end
			end
		end
	end
	return t
end

function FI_IsFolderItem(item)
	local retval, str = reaper.GetItemStateChunk(item, "", false)
	local stringStart, stringEnd = string.find(str, "SOURCE EMPTY")
	if stringStart then
		return true
	else
		return false
	end
end

function FI_MarkOrSelectChildrenItems(item, select)
    --local ar_child_items = {}
    
    local parentTrack = reaper.GetMediaItem_Track(item)
    local columnStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local columnEnd = columnStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    local parentDepth = reaper.GetTrackDepth(parentTrack)
    local trackidx = reaper.GetMediaTrackInfo_Value(parentTrack, "IP_TRACKNUMBER")
    local track = reaper.GetTrack(0, trackidx)
    if track then
        local depth = reaper.GetTrackDepth(track)
        local trackCount = reaper.GetNumTracks()
        while depth > parentDepth do
            for i = 0, reaper.CountTrackMediaItems(track) - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local itemEnd = itemPos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                if (itemPos >= columnStart and itemPos + 0.00001 < columnEnd) or (itemEnd - 0.0001 > columnStart and itemEnd <= columnEnd) then                	
                    --ar_child_items[#ar_child_items+1] = item
                    if select == true then
                    	reaper.SetMediaItemSelected(item, 1)
                    else
                    	reaper.GetSetMediaItemInfo_String(item, "P_EXT:vf_reposition_items", "Skip", 1)
                    end
                end
            end
            trackidx = trackidx + 1
            if trackidx == trackCount then
                break
            end -- if no more tracks
            track = reaper.GetTrack(0, trackidx)
            depth = reaper.GetTrackDepth(track)
        end
    end
    --return ar_child_items
end

function MarkOrSelectOverlappingItems(item, select)
	--local t_overlap_items = {}
	local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
	local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
	local item_end = item_start + item_len
	local last_end = item_end
	local total_len = item_len	
	local item_id = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
	local item_track = reaper.GetMediaItemTrack(item)
	local counter = 1
	local item_track_nb = reaper.CountTrackMediaItems(item_track)
	for i=0, reaper.CountTrackMediaItems(item_track)-1-item_id-counter do
		local extend_len
		local item_check = reaper.GetTrackMediaItem(item_track, i+item_id+1)
		local item_check_start = reaper.GetMediaItemInfo_Value(item_check, "D_POSITION")
		local item_check_end = item_check_start + reaper.GetMediaItemInfo_Value(item_check, "D_LENGTH")
		if overlap == true then
			if (item_check_start >= item_start and item_check_start + 0.00001 < last_end) then
				--t_overlap_items[counter] = item_check
				if select == true then
					reaper.SetMediaItemSelected(item_check, 1)
					if FI_IsFolderItem(item_check) then
						FI_MarkOrSelectChildrenItems(item_check, true)
					end
				else
					reaper.GetSetMediaItemInfo_String(item_check, "P_EXT:vf_reposition_items", "Skip", 1)
					if FI_IsFolderItem(item_check) then
						FI_MarkOrSelectChildrenItems(item_check, false)
					end
				end
				extend_len = true
			end
		end		
		if adjacent == true then
			if CheckFloatEquality(item_check_start, last_end) then
				--t_overlap_items[counter] = item_check			
				if select == true then
					reaper.SetMediaItemSelected(item_check, 1)
					if FI_IsFolderItem(item_check) then
						FI_MarkOrSelectChildrenItems(item_check, true)
					end
				else
					reaper.GetSetMediaItemInfo_String(item_check, "P_EXT:vf_reposition_items", "Skip", 1)
					if FI_IsFolderItem(item_check) then
						FI_MarkOrSelectChildrenItems(item_check, false)
					end
				end				
				extend_len = true
			end
		end
		if extend_len == true then
			last_end = item_check_end
		else
			break
		end
		total_len = last_end - item_start
		counter = counter + 1
	end
	--return t_overlap_items, total_len
	return total_len
end

------------------------------------------------------------------------------------
-- MAIN FUNCTIONS
------------------------------------------------------------------------------------

function Init()

	if not reaper.SNM_GetIntConfigVar then
		local retval = reaper.ShowMessageBox("This script requires the SWS Extension.\n\nDo you want to download it now?", "Warning", 1)
		if retval == 1 then
			reaper.CF_ShellExecute('http://www.sws-extension.org/download/pre-release/')
		end
		return false
	end

	if not reaper.APIExists("ReaPack_BrowsePackages") then	
		reaper.MB("Please install ReaPack from Cfillion to install other dependencies'.\n\nThen restart REAPER and run the script again.\n", "You must install ReaPack extension", 0)
		reaper.CF_ShellExecute('https://reapack.com')
		return false
	end

	--[[
	if not reaper.APIExists("JS_Localize") then
		reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n\nThen restart REAPER and run the script again.\n", "You must install JS_ReaScriptAPI", 0)
		reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
		return false
	end
	]]

	if not reaper.ImGui_CreateContext then
		reaper.MB("Please right-click and install 'ReaImGui: ReaScript binding for Dear ImGui'.\n\nThen restart REAPER and run the script again.\n", "You must install ReaImGui API", 0)
		reaper.ReaPack_BrowsePackages("ReaImGui")
		return false
	end	

	dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.6')

	SaveInitialState()
	SaveInitialItemSelection()
	t_tracks = SaveSelItemsTracks()
	previous_interval = nil
	previous_offset_state = nil
	previous_non_linear = nil
	previous_toggle_val = nil
	previous_mode_val = nil
	
	autoxfade_option = reaper.GetToggleCommandState(40041) -- Options: Auto-crossfade media items when editing		

	ctx = reaper.ImGui_CreateContext('Smart Export')
	font = reaper.ImGui_CreateFont('sans-serif', 13)
	reaper.ImGui_Attach(ctx, font)

	-- Restore saved parameters & settings
	interval_sec = reaper.GetExtState("vf_reposition_items", "interval_sec")
	if interval_sec == "" then interval_sec = nil end
	interval_frame = reaper.GetExtState("vf_reposition_items", "interval_frame")
	if interval_frame == "" then interval_frame = nil end
	interval_beats = reaper.GetExtState("vf_reposition_items", "interval_beats")
	if interval_beats == "" then interval_beats = nil end
	interval_mode = reaper.GetExtState("vf_reposition_items", "interval_mode")
	if interval_mode == "" then interval_mode = nil end			
	offset_val = reaper.GetExtState("vf_reposition_items", "offset_val")
	if offset_val == "" then offset_val = nil end
	offset_state = reaper.GetExtState("vf_reposition_items", "offset_state")
	if offset_state == "" then offset_state = nil end
	if offset_state == "true" then offset_state = true end
	if offset_state == "false" then offset_state = false end	
	toggle_val = reaper.GetExtState("vf_reposition_items", "toggle_val")
	if toggle_val == "" then toggle_val = nil end
	mode_val = reaper.GetExtState("vf_reposition_items", "mode_val")
	if mode_val == "" then mode_val = nil end
	overlap = reaper.GetExtState("vf_reposition_items", "overlap")
	if overlap == "" then overlap = nil end
	if overlap == "true" then overlap = true end
	if overlap == "false" then overlap = false end	
	adjacent = reaper.GetExtState("vf_reposition_items", "adjacent")
	if adjacent == "" then adjacent = nil end		
	if adjacent == "true" then adjacent = true end
	if adjacent == "false" then adjacent = false end	

	save_settings = reaper.GetExtState("vf_reposition_items_settings", "save_settings")
	if save_settings == "" then save_settings = nil end		
	if save_settings == "true" then save_settings = true end
	if save_settings == "false" then save_settings = false end	
	close_window = reaper.GetExtState("vf_reposition_items_settings", "close_window")
	if close_window == "" then close_window = nil end			
	if close_window == "true" then close_window = true end
	if close_window == "false" then close_window = false end
	disable_autoxfade = reaper.GetExtState("vf_reposition_items_settings", "disable_autoxfade")
	if disable_autoxfade == "" then disable_autoxfade = nil end
	if disable_autoxfade == "true" then disable_autoxfade = true end
	if disable_autoxfade == "false" then disable_autoxfade = false end	
	hide_tooltip = reaper.GetExtState("vf_reposition_items_settings", "hide_tooltip")	
	if hide_tooltip == "" then hide_tooltip = nil end		
	if hide_tooltip == "true" then hide_tooltip = true end
	if hide_tooltip == "false" then hide_tooltip = false end				

	return true
end

function Post()
	if autoxfade_option == 1 then
		Command(41118) -- Options: Enable auto-crossfades
	end
end

function Main(interval, offset, non_linear)

	count_sel_items = reaper.CountSelectedMediaItems(0)
	if count_sel_items < 0 then return end

	local initial_cur_pos = reaper.GetCursorPositionEx(0)
	init_interval = interval

	local loop_nb = 1
	if mode == "track" then
		loop_nb = #t_tracks
	end
	
	for i=1, loop_nb do
		local previous_take_name
		local diff_name_offset = 0
		local item_next_start
		local item_next_end

		interval = init_interval                 

		local item_list = {}
		local track
		if mode == "track" then
			track = t_tracks[i]
			item_list = GetTrackItemPos(track)
		else
			item_list = GetItemPos()
			if mode == "timeline" then
				table.sort(item_list, sort_func)
			end						
		end

		for j=1, #item_list do
			local item = item_list[j].item

			-- Add position offset if new group of item is detected (different take name)
			if offset_state == true then
				local take_name = StripNumbersAndExtensions(reaper.GetTakeName(reaper.GetActiveTake(item)))
				if previous_take_name and (take_name ~= previous_take_name) then
					diff_name_offset = diff_name_offset + offset   
					interval = init_interval                  
				end
				previous_take_name = take_name 
			end

			if j > 1 then
				if toggle == "end" then
					item_list[j].new_pos = item_next_end + interval + diff_name_offset
				elseif toggle == "start" then
					item_list[j].new_pos = item_next_start + interval + diff_name_offset
				end
				diff_name_offset = 0
				interval = interval * non_linear
			end

			if j > 1 then
				item_next_start = item_list[j].new_pos
			else
				item_next_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
			end
			item_next_end = item_next_start + item_list[j].len
		end

		-- Move items at the end of the project before repositioning them (smart hack from NVK to avoid messing the automation points)
		for j=2, #item_list do
			local item = item_list[j].item
			RepositionItems(item_list[j].item, item_list[j].pos + 10000000)
		end

		-- Reposition item & restore snapoffset
		for j=1, #item_list do
			local item = item_list[j].item
			if j > 1 then
				RepositionItems(item, item_list[j].new_pos)
			end
			reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", item_list[j].snapoffset)
		end	

		-- Restore item selection
		for j=1, #t_initial_selection do
			reaper.SetMediaItemSelected(t_initial_selection[j], 1)
		end						
	end	

	-- Remove skip item mark
	for j=1, #t_initial_selection do
		reaper.GetSetMediaItemInfo_String(t_initial_selection[j], "P_EXT:vf_reposition_items", "", 1)
	end		

	UpdateFolderItem()
	reaper.SetEditCurPos2(0, initial_cur_pos, 0, 0) -- Restore edit cursor pos
	apply = false
end

------------------------------------------------------------------------------------
-- GUI
------------------------------------------------------------------------------------

function ToolTip(text)
	if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
		reaper.ImGui_BeginTooltip(ctx)
		reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
		reaper.ImGui_Text(ctx, text)
		reaper.ImGui_PopTextWrapPos(ctx)
		reaper.ImGui_EndTooltip(ctx)
	end
end

function ResetOnDoubleClick(id, value, default)
	if reaper.ImGui_IsItemDeactivated(ctx) and reset[id] then
		reset[id] = nil
		return default
	elseif reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
		reset[id] = true
	end
	return value
end

function SliderDouble(id, value, min, max, default_value)
	local rv
	rv,value = reaper.ImGui_SliderDouble(ctx, id, value, min, max, "%.2f")
	value = ResetOnDoubleClick(id, value, default_value)
	local changed
	if not changed then changed = reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) end
	return changed, value
end

function ResetOnAltClick(id, value, default)
	if reaper.ImGui_IsItemDeactivated(ctx) and reset[id] then
		reset[id] = nil
		return default
	elseif reaper.ImGui_IsItemClicked(ctx, 0) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
		reset[id] = true
	end
	return value
end

function DragDouble(id, value, min, max, default_value)
	local rv
	rv, value = reaper.ImGui_DragDouble(ctx, id, value, 0.001, min, max, "%.2f")
	--rv,value = reaper.ImGui_SliderDouble(ctx, id, value, min, max, "%.2f")
	value = ResetOnAltClick(id, value, default_value)
	local changed
	--if not changed then changed = reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) end
	if not changed then changed = reaper.ImGui_IsItemDeactivated(ctx) end
	return changed, value
end

function DoubleInputDisabled(label, value, step, default_value, format, state, tooltip)
	local flags = 0
	if state == false then
		flags = flags | reaper.ImGui_InputTextFlags_ReadOnly()
		local textDisabled = reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_TextDisabled())
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), textDisabled);
	end	

	if not value then value = default_value end
	local rv, value = reaper.ImGui_InputDouble(ctx, "##" .. label, value, step, step_fastIn, format, flags)
	reaper.ImGui_SameLine(ctx)
	reaper.ImGui_Text(ctx, label)

	local hover
	if reaper.ImGui_IsItemHovered(ctx) then
		hover = true
	end

	local click
	if reaper.ImGui_IsItemClicked(ctx) then
		click = true
	end

	if hide_tooltip == false then
		ToolTip(tooltip)
	end

	if state == false then
		reaper.ImGui_PopStyleColor(ctx)
	end

	if click then
		if state == false then state = true else state = false end
	end
	return rv, value, state
end

function ToggleButton(ctx, label, selected, size_w, size_h)
  if selected then
    local col_active = reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_ButtonActive())
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), col_active)
  end
  local toggled = reaper.ImGui_Button(ctx, label, size_w, size_h)
  if selected then reaper.ImGui_PopStyleColor(ctx) end
  if toggled then selected = not selected end
  return toggled, selected
end

function Frame()
	-- Initialize
	update_items = false
	local rv
	if not interval_sec then interval_sec = 1 end
	if not interval_frame then interval_frame = 1 end
	if not interval_beats then interval_beats = 5 end
	if not interval_mode then interval_mode = 0 end
	if not offset_state then offset_state = false end
	if not non_linear_default_value then non_linear_default_value = 1 end
	if not non_linear then non_linear = non_linear_default_value end
	if not reset then reset = {} end
	if not toggle_val then toggle_val = 1 end
	if not mode_val then mode_val = 0 end
	if not overlap then overlap = false end
	if not adjacent then adjacent = false end
	if not apply then apply = false end
	if not realtime then realtime = false end
	if not save_settings then save_settings = false end	
	if not close_window then close_window = false end
	if not disable_autoxfade then disable_autoxfade = false end
	if not hide_tooltip then hide_tooltip = false end	

	-- Check if item selection have changed, if yes save new initial state to restore if cancel button is clicked
	local t_current_selection = SaveItemSelection()
	local same_item_selection = CheckTableEquality(t_current_selection, t_initial_selection)
	if same_item_selection == false then
		SaveInitialState()
		SaveInitialItemSelection()
		if mode == "track" then
			t_tracks = SaveSelItemsTracks()
		end
	end

	if disable_autoxfade == true then
		Command(41119) -- Options: Disable auto-crossfades
	end	

	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 10, val2In)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(), 10, val2In)

	reaper.ImGui_BeginTabBar(ctx, "MyTabs")

	-- Main Tab
	if reaper.ImGui_BeginTabItem(ctx, "Main", false) then
		reaper.ImGui_Dummy(ctx, 0, 0)

		-- Interval
		reaper.ImGui_PushItemWidth(ctx, 90)
		reaper.ImGui_PushStyleVar(ctx,  reaper.ImGui_StyleVar_FramePadding(), 6, 4)
		if toggle_val == 0 then					
			local button_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.5, 0.5, 1.0, 0.7)
			local hover_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.5, 0.5, 1.0, 1.0)
			local active_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.5, 0.4, 1.0, 1.0)
			local bg_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.5, 0.5, 1.0, 0.3)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), button_new_color)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover_new_color)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), active_new_color)			
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), bg_new_color)
		end

		if interval_mode == 0 then
			rv_interval_sec, interval_sec = reaper.ImGui_InputDouble(ctx, '##Interval', interval_sec, 0.5, 0.1, '%.1f')
			if interval_sec < 0 then interval_sec = 0 end
			if save_settings == true then
				reaper.SetExtState("vf_reposition_items", "interval_sec", tostring(interval_sec), true)
			end
			interval = interval_sec
		elseif interval_mode == 1 then
			rv_interval_frame, interval_frame = reaper.ImGui_InputInt(ctx, '##Interval', interval_frame, 1, 1)
			if interval_frame < 0 then interval_frame = 0 end
			if save_settings == true then
				reaper.SetExtState("vf_reposition_items", "interval_frame", tostring(interval_frame), true)
			end		
			local framerate, dropFrameOut = reaper.TimeMap_curFrameRate(0)	
			interval = interval_frame * (1/framerate)
		elseif interval_mode == 2 then
			local beats = "8/1\0".."4/1\0".."2/1\0".."1/1\0".."1/2\0".."1/4\0".."1/8\0".."1/16\0".."1/32\0"
			rv_interval_beats, interval_beats = reaper.ImGui_Combo(ctx, "##Interval", interval_beats, beats, 9)
			if save_settings == true then
				reaper.SetExtState("vf_reposition_items", "interval_beats", tostring(interval_beats), true)
			end			
			local beats_to_whole_note = {8,4,2,1,0.5,0.25,0.125,0.0625, 0.03125}
			local whole_note = reaper.TimeMap2_QNToTime(0, 4)	
			interval = beats_to_whole_note[interval_beats+1] * whole_note
		end		
		reaper.ImGui_PopItemWidth(ctx)
		reaper.ImGui_SameLine(ctx)
		reaper.ImGui_PushItemWidth(ctx, 72)
		local interval_modes = "secs\0frames\0beats\0"
		if not interval_mode then interval_mode = 0 end
		rv_interval_mode, interval_mode = reaper.ImGui_Combo(ctx, "##interval_mode", interval_mode, interval_modes)		
		if save_settings == true then
			reaper.SetExtState("vf_reposition_items", "interval_mode", tostring(interval_mode), true)
		end				
		reaper.ImGui_PopItemWidth(ctx)
		reaper.ImGui_PopStyleVar(ctx)
		reaper.ImGui_SameLine(ctx)
		reaper.ImGui_Text(ctx, "Interval")
		reaper.ImGui_Dummy(ctx, 0, 0)
		
		-- Group offset double input
		reaper.ImGui_PushStyleVar(ctx,  reaper.ImGui_StyleVar_FramePadding(), 6, 4)
		reaper.ImGui_PushItemWidth(ctx, 170)
		if not offset_state then offset_state = false end
		rv_offset_val, offset_val, offset_state = DoubleInputDisabled("Group Offset", offset_val, 1, 3, '%.1f sec', offset_state, "Time offset between items with unique name, useful to separate group of items with the same name")
		if save_settings == true then
			reaper.SetExtState("vf_reposition_items", "offset_val", tostring(offset_val), true)
			reaper.SetExtState("vf_reposition_items", "offset_state", tostring(offset_state), true)
		end
		offset = offset_val
		if offset_state == false then offset = 0 end		
		reaper.ImGui_Dummy(ctx, 0, 0)

		--- Non-linear factor horizontal float
		rv_non_linear, non_linear = DragDouble('##Non-linear Factor', non_linear, 0, 10, non_linear_default_value)
		--rv, non_linear = SliderDouble('##Non-linear Factor', non_linear, 0.5, 1.5, non_linear_default_value)
		reaper.ImGui_SameLine(ctx)
		reaper.ImGui_Text(ctx, "Non-linear Factor")
		if hide_tooltip == false then
			ToolTip("Value > 1 will create a rallentando and value < 1 will create an accelerando\nAlt+click to reset\nShift+drag for larger increment")
		end
		reaper.ImGui_PopStyleVar(ctx)		
		reaper.ImGui_PopItemWidth(ctx)
		if toggle_val == 0 then	
			reaper.ImGui_PopStyleColor(ctx, 4)			
		end			
		reaper.ImGui_Dummy(ctx, 0, 0)

		--- Start/End radio
		if FI_detected == true and realtime == true then
			toggle_val = 1
			reaper.ImGui_BeginDisabled(ctx, 1)
		end		
		rv_toggle_val, toggle_val = reaper.ImGui_RadioButtonEx(ctx, 'Start', toggle_val, 0); reaper.ImGui_SameLine(ctx)
		if FI_detected == true and realtime == true then
			reaper.ImGui_EndDisabled(ctx)
		end
		rv_toggle_val, toggle_val = reaper.ImGui_RadioButtonEx(ctx, 'End', toggle_val, 1)
		if save_settings == true then
			reaper.SetExtState("vf_reposition_items", "toggle_val", tostring(toggle_val), true)
		end
		if toggle_val == 0 then toggle = "start"
		elseif toggle_val == 1 then toggle = "end" end
		reaper.ImGui_Dummy(ctx, 0, 0)

		-- Mode radio
		rv_mode_val, mode_val = reaper.ImGui_RadioButtonEx(ctx, 'Track', mode_val, 0); reaper.ImGui_SameLine(ctx)
		rv_mode_val, mode_val = reaper.ImGui_RadioButtonEx(ctx, 'Queue', mode_val, 1); reaper.ImGui_SameLine(ctx)
		rv_mode_val, mode_val  = reaper.ImGui_RadioButtonEx(ctx, 'Timeline', mode_val, 2)  
		if save_settings == true then
			reaper.SetExtState("vf_reposition_items", "mode_val", tostring(mode_val), true)
		end
		if mode_val == 0 then mode = "track"
		elseif mode_val == 1 then mode = "queue"
		elseif mode_val == 2 then mode = "timeline" end
		if hide_tooltip == false then
			ToolTip("Track mode = for each track, start at first item's position\nQueue mode = for each track, start at last repositioned item position in previous track\nTimeline mode = Reposition accross tracks")
		end
		reaper.ImGui_Dummy(ctx, 0, 0)

		-- Realtime Button
		local button_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.5, 0.5, 1.0, 0.5)
		local hover_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.5, 0.5, 1.0, 1.0)
		local active_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.5, 0.4, 1.0, 1.0)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), button_new_color)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover_new_color)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), active_new_color)					
		rv_realtime, realtime = ToggleButton(ctx, 'Realtime mode', realtime, 100, 20)
		if hide_tooltip == false then
			ToolTip("Reposition selected items in realtime\nItem selection can't be changed while this mode is active\nStart button is disabled if at least one nvk folder items is selected")
		end	
		reaper.ImGui_PopStyleColor(ctx, 3)
		if realtime == true then
			ForceSelectItems()
		end
		reaper.ImGui_SameLine(ctx)

		-- Overlap & Adjacent Buttons
		rv_overlap, overlap = ToggleButton(ctx, 'Overlap', overlap, 80, 20)
		if save_settings == true then
			reaper.SetExtState("vf_reposition_items", "overlap", tostring(overlap), true)
		end		
		if hide_tooltip == false then
			ToolTip("Preserve overlapping items")
		end	
		reaper.ImGui_SameLine(ctx)
		rv_adjacent, adjacent = ToggleButton(ctx, 'Adjacent', adjacent, 80, 20)
		if save_settings == true then
			reaper.SetExtState("vf_reposition_items", "adjacent", tostring(adjacent), true)
		end				
		if hide_tooltip == false then
			ToolTip("Preserve adjacent items")
		end						
		reaper.ImGui_Dummy(ctx, 0, 4)

		local sel_item_nb = tostring(reaper.CountSelectedMediaItems(0))
		reaper.ImGui_SeparatorText(ctx, tostring(sel_item_nb).." selected item(s)")
		reaper.ImGui_Dummy(ctx, 0, 4)

		-- Apply/Cancel Buttons
		local button_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.3, 0.3, 0.3, 1.0)
		local hover_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.4, 0.4, 0.4, 1.0)
		local active_new_color = reaper.ImGui_ColorConvertDouble4ToU32(0.5, 0.5, 0.5, 1.0)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), button_new_color)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover_new_color)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), active_new_color)
		rv_apply = reaper.ImGui_Button(ctx, 'Apply', 75, 20)
		if rv_apply then
			apply = true
			if close_window == true then
				open = false
			end
		end
		reaper.ImGui_SameLine(ctx)	
		rv_cancel = reaper.ImGui_Button(ctx, 'Cancel', 75, 20) 
		if rv_cancel then
			--PrintWindowSize()	
			cancel = true
			if close_window == true then
				open = false
			end
			if realtime == true then realtime = false end
		end
		if hide_tooltip == false then
			ToolTip("Cancel repositioning since last item selection change")
		end				
		reaper.ImGui_PopStyleColor(ctx, 3)

		if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
			apply = true
			if close_window == true then
				open = false
			end
		end
		reaper.ImGui_EndTabItem(ctx)

		if rv_cancel or rv_apply or rv_adjacent or rv_overlap or rv_realtime or (previous_mode_val ~= mode_val) or (previous_toggle_val ~= toggle_val) or rv_offset_val or (previous_offset_state ~= offset_state) or (previous_interval ~= interval) then
			update_items = true
		end

		if count_sel_items > 250 then
			if rv_non_linear then update_items = true end
		else
			if previous_non_linear ~= non_linear then update_items = true end
		end

		previous_interval = interval
		previous_offset_state = offset_state
		previous_non_linear = non_linear	
		previous_toggle_val = toggle_val
		previous_mode_val = mode_val	
	end

	-- Settings Tab
	if reaper.ImGui_BeginTabItem(ctx, "Settings", false) then
		save_settings_toggled, save_settings = reaper.ImGui_Checkbox(ctx, "Save last settings", save_settings)
		if save_settings_toggled == true and save_settings == false then
			ResetSavedParameters()
		end
		reaper.SetExtState("vf_reposition_items_settings", "save_settings", tostring(save_settings), true)
		rv, close_window = reaper.ImGui_Checkbox(ctx, "Close window after applying or cancelling", close_window)
		reaper.SetExtState("vf_reposition_items_settings", "close_window", tostring(close_window), true)
		rv, disable_autoxfade = reaper.ImGui_Checkbox(ctx, "Disable auto-crossfade", disable_autoxfade)
		reaper.SetExtState("vf_reposition_items_settings", "disable_autoxfade", tostring(disable_autoxfade), true)		
		rv, hide_tooltip = reaper.ImGui_Checkbox(ctx, "Hide help tooltip", hide_tooltip)
		reaper.SetExtState("vf_reposition_items_settings", "hide_tooltip", tostring(hide_tooltip), true)
		reaper.ImGui_EndTabItem(ctx)	
	end

	if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
		open = false
	end	
	reaper.ImGui_PopStyleVar(ctx, 2)
	reaper.ImGui_EndTabBar(ctx)
end

function Loop()
	reaper.ImGui_PushFont(ctx, font)
	reaper.ImGui_SetNextWindowSize(ctx, 309, 293, reaper.ImGui_Cond_FirstUseEver()) 
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 10, val2In)
	--visible, open = reaper.ImGui_Begin(ctx, 'Items Reposition', true, reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoResize())	
	visible, open = reaper.ImGui_Begin(ctx, 'Advanced Items Repositioning', true, reaper.ImGui_WindowFlags_NoCollapse())
	if visible then
		Frame()
		if apply == true or (realtime == true and update_items == true) then	
			Main(interval, offset, non_linear)
		end
		reaper.ImGui_End(ctx)
	end
	reaper.ImGui_PopFont(ctx)
	reaper.ImGui_PopStyleVar(ctx, 1)

	if cancel then
		RestoreInitialState()
	end

	if open then
		reaper.defer(Loop)
	end
end


reaper.Undo_BeginBlock2(0)

--local start = reaper.time_precise()

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 1 then return end	

if Init() == true then
	reaper.defer(Loop)
end
reaper.atexit(Post)

-- local elapsed = reaper.time_precise() - start
-- Print("Script executed in ".. elapsed .." seconds")

scrName = ({reaper.get_action_context()})[2]:match(".+[/\\](.+)")
reaper.Undo_EndBlock2(0, scrName, -1)

