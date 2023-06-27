-- @metapackage
-- @noindex

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
		if string.match(take_name, "_%d+%.%w+$") then
			take_name = string.gsub(take_name, "_%d+%.%w+$", "")  
		elseif string.match(take_name, " %d+%.%w+$") then
			take_name = string.gsub(take_name, " %d+%.%w+$", "")			 	
		elseif string.match(take_name, "_%d+$") then
			take_name = string.gsub(take_name, "_%d+$", "")                  
		elseif string.match(take_name, " %d+$") then
			take_name = string.gsub(take_name, " %d+$", "")
		elseif string.match(take_name, "%.%w+$") then
			take_name = string.gsub(take_name, "%.%w+$", "")            
		end
	end
	return take_name
end

------------------------------------------------------------------------------------
-- SECONDARY FUNCTIONS
------------------------------------------------------------------------------------

function SaveItemsSelection()
	local t_selection = {}
	local counter = 1
	local sel_item_nb = reaper.CountSelectedMediaItems(0)
	for i=1, sel_item_nb do
        local item = reaper.GetSelectedMediaItem(0, i-1)
        if item ~= nil then
            t_selection[counter] = item
            counter = counter + 1
        end
    end
    return t_selection
end

function ReselectItems(t)
	for i=1, #t do
		local item = t[i]
		local val = reaper.ValidatePtr2(0, item, "MediaItem*")
		if val == true then
			reaper.SetMediaItemSelected(item, 1)
		end
	end	
end

function RemoveSkipMark(t)
	for i=1, #t do
		local item = t[i]
		local val = reaper.ValidatePtr2(0, item, "MediaItem*")
		if val == true then
			reaper.GetSetMediaItemInfo_String(item, "P_EXT:vf_reposition_items", "", 1)
		end
	end	
end	

function Unsel_item()
	local offset = 0
	for i=0, reaper.CountSelectedMediaItems(0)-1 do
		local item = reaper.GetSelectedMediaItem(0, i-offset)
		reaper.SetMediaItemSelected(item, 0)
		offset = offset + 1
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

function MarkOrSelectOverlappingItems_Core(item, select, mark)
	if select == true then
		reaper.SetMediaItemSelected(item, 1)
		if FI_IsFolderItem(item) then
			FI_MarkOrSelectChildrenItems(item, true)
		end
	else
		reaper.GetSetMediaItemInfo_String(item, "P_EXT:vf_reposition_items", "Skip", 1)						
		if FI_IsFolderItem(item) then
			FI_MarkOrSelectChildrenItems(item, false)
		end
	end	
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
				MarkOrSelectOverlappingItems_Core(item_check, select, item_mark)		
				extend_len = true
			end
		end		
		if adjacent == true then
			if CheckFloatEquality(item_check_start, last_end) then
				--t_overlap_items[counter] = item_check			
				MarkOrSelectOverlappingItems_Core(item_check, select, item_mark)					
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

	--[[
	if not reaper.APIExists("ReaPack_BrowsePackages") then	
		reaper.MB("Please install ReaPack from Cfillion to install other dependencies'.\n\nThen restart REAPER and run the script again.\n", "You must install ReaPack extension", 0)
		reaper.CF_ShellExecute('https://reapack.com')
		return false
	end

	if not reaper.APIExists("JS_Localize") then
		reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n\nThen restart REAPER and run the script again.\n", "You must install JS_ReaScriptAPI", 0)
		reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
		return false
	end

	if not reaper.ImGui_CreateContext then
		reaper.MB("Please right-click and install 'ReaImGui: ReaScript binding for Dear ImGui'.\n\nThen restart REAPER and run the script again.\n", "You must install ReaImGui API", 0)
		reaper.ReaPack_BrowsePackages("ReaImGui")
		return false
	end	

	dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.6')
	]]

	UpdateFolderItem()
	t_initial_selection = SaveItemsSelection()
	t_tracks = SaveSelItemsTracks()
	previous_interval = nil
	previous_offset_state = nil
	previous_non_linear = nil
	previous_toggle_val = nil
	previous_mode_val = nil
	
	autoxfade_option = reaper.GetToggleCommandState(40041) -- Options: Auto-crossfade media items when editing		

	--[[
	ctx = reaper.ImGui_CreateContext('Smart Export')
	font = reaper.ImGui_CreateFont('sans-serif', 13)
	reaper.ImGui_Attach(ctx, font)
	]]

	-- Restore saved parameters & settings
	interval_sec = reaper.GetExtState("vf_reposition_items", "interval_sec_noGUI")
	if interval_sec == "" then interval_sec = nil end
	interval_sec = tonumber(interval_sec)
	interval_frame = reaper.GetExtState("vf_reposition_items", "interval_frame_noGUI")
	if interval_frame == "" then interval_frame = nil end
	interval_frame = tonumber(interval_frame)
	interval_beats = reaper.GetExtState("vf_reposition_items", "interval_beats_noGUI")
	if interval_beats == "" then interval_beats = nil end
	interval_beats = tonumber(interval_beats)
	interval_mode = reaper.GetExtState("vf_reposition_items", "interval_mode_noGUI")
	if interval_mode == "" then interval_mode = nil end			
	interval_mode = tonumber(interval_mode)
	offset_val = reaper.GetExtState("vf_reposition_items", "offset_val_noGUI")
	if offset_val == "" then offset_val = nil end
	offset_val = tonumber(offset_val)
	offset_state = reaper.GetExtState("vf_reposition_items", "offset_state_noGUI")
	if offset_state == "" then offset_state = nil end
	if offset_state == "true" then offset_state = true end
	if offset_state == "false" then offset_state = false end	
	toggle_val = reaper.GetExtState("vf_reposition_items", "toggle_val_noGUI")
	if toggle_val == "" then toggle_val = nil end
	toggle_val = tonumber(toggle_val)
	mode_val = reaper.GetExtState("vf_reposition_items", "mode_val_noGUI")
	if mode_val == "" then mode_val = nil end
	mode_val = tonumber(mode_val)
	overlap = reaper.GetExtState("vf_reposition_items", "overlap_noGUI")
	if overlap == "" then overlap = nil end
	if overlap == "true" then overlap = true end
	if overlap == "false" then overlap = false end	
	adjacent = reaper.GetExtState("vf_reposition_items", "adjacent_noGUI")
	if adjacent == "" then adjacent = nil end		
	if adjacent == "true" then adjacent = true end
	if adjacent == "false" then adjacent = false end	

	autoxfade = reaper.GetExtState("vf_reposition_items", "autoxfade_noGUI")
	if autoxfade == nil then autoxfade = true end -- To avoid error with old version of script 
	if autoxfade == "" then autoxfade = nil end
	if autoxfade == "true" then autoxfade = true end
	if autoxfade == "false" then autoxfade = false end	

	group_offset_option = reaper.GetExtState("vf_reposition_items_settings", "group_offset_option_noGUI")
	if group_offset_option == "" then group_offset_option = nil end
	if group_offset_option == "true" then group_offset_option = true end
	if group_offset_option == "false" then group_offset_option = false end		

	if not interval_sec then interval_sec = 1 end
	if not interval_frame then interval_frame = 1 end
	if not interval_beats then interval_beats = 5 end
	if not interval_mode then interval_mode = 0 end
	if offset_state == nil then offset_state = false end
	if not offset_val then offset_val = 3 end	
	if not toggle_val then toggle_val = 1 end
	if not mode_val then mode_val = 0 end
	if overlap == nil then overlap = false end
	if adjacent == nil then adjacent = false end
	if autoxfade == nil then autoxfade = true end
	if group_offset_option == nil then group_offset_option = true end

	return true
end

function Post()
	RemoveSkipMark(t_initial_selection)
	if autoxfade_option == 1 then
		Command(41118) -- Options: Enable auto-crossfades
	else
		Command(41119) -- Options: Disable auto-crossfades
	end
end

function Main()

	count_sel_items = reaper.CountSelectedMediaItems(0)
	if count_sel_items < 0 then return end	

	reaper.PreventUIRefresh(1)

	if autoxfade == true then
		Command(41118) -- Options: Enable auto-crossfades
	else
		Command(41119) -- Options: Disable auto-crossfades
	end		

	-- Get interval in seconds
	if interval_mode == 0 then
		interval = interval_sec
	elseif interval_mode == 1 then
		local framerate, dropFrameOut = reaper.TimeMap_curFrameRate(0)	
		interval = interval_frame * (1/framerate)
	elseif interval_mode == 2 then		
		local beats_to_whole_note = {8,4,2,1,0.5,0.25,0.125,0.0625, 0.03125}
		local whole_note = reaper.TimeMap2_QNToTime(0, 4)	
		interval = beats_to_whole_note[interval_beats+1] * whole_note
	end		

	-- Get group offset if active
	offset = offset_val
	if offset_state == false then offset = 0 end			

	-- Get toggle value
	if toggle_val == 0 then toggle = "start"
	elseif toggle_val == 1 then toggle = "end" end	

	-- Get mode value
	if mode_val == 0 then mode = "track"
	elseif mode_val == 1 then mode = "queue"
	elseif mode_val == 2 then mode = "timeline" end	

	local initial_cur_pos = reaper.GetCursorPositionEx(0)

	local loop_nb = 1
	if mode == "track" then
		loop_nb = #t_tracks
	end
	
	for i=1, loop_nb do
		local previous_take_name
		local diff_name_offset = 0
		local item_next_start
		local item_next_end               

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
				local take_name = reaper.GetTakeName(reaper.GetActiveTake(item))
				if group_offset_option == true then
					take_name = StripNumbersAndExtensions(take_name)
				end
				if previous_take_name and (take_name ~= previous_take_name) then
					diff_name_offset = diff_name_offset + offset                    
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

		ReselectItems(t_initial_selection)							
	end	

	RemoveSkipMark(t_initial_selection)	

	UpdateFolderItem()
	reaper.SetEditCurPos2(0, initial_cur_pos, 0, 0) -- Restore edit cursor pos
	apply = false
	reaper.UpdateArrange()
	reaper.PreventUIRefresh(-1)
end


reaper.Undo_BeginBlock2(0)

--local start = reaper.time_precise()

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 2 then
	--reaper.ShowMessageBox("Please, select at least two items to use this script", "Advanced items repositioning", 0)
	return
end	

if Init() == true then
	Main()
	Post()
end

-- local elapsed = reaper.time_precise() - start
-- Print("Script executed in ".. elapsed .." seconds")

scrName = ({reaper.get_action_context()})[2]:match(".+[/\\](.+)")
reaper.Undo_EndBlock2(0, scrName, -1)

