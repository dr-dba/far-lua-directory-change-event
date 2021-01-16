--[[
-- LE({...})
if true then return end --]]

--[[!	@Xer0X & CitRix CopyLeft 2020
	White Power Resistance Commando@line team
	Presenting to you:

	This script gives saves and restores
	last paths and current items on both
	right and left panels of FAR Manager
	between restarts

based on the code of Gene.Pavlovsky:
https://forum.farmanager.com/viewtopic.php?t=10521

Put the script here:
%FARPROFILE%\Macros\scripts\ContentColumn+ExitFAREvent_PanelChangeDir.@Xer0X.Lua
]]

local sz_own_file, sz_some_load_code = ...

-- Timer poll interval in milliseconds:
local POLL_INTERVAL = 1000
local POLL_INT_PNL_CHK = 3000
local POLL_INT_TMP_CHK = 5000
local POLL_INT_CLK_CHK = 10000
local WRITE_LOG = false
local UPD_TIME_VAR = false
local CHK_TEMP_VAR = false
local REDRAW_SHELL = false --! to update prompt clock
local USE_TIMER =
	true
--	false
local CONT_COL_DIR_CALC_LIM = 5000
local SYNC_STORE_LIMIT = 30000
local SQL_OUT =
	"NUL"
--!	"c:\\sqlite.out"

-- local SQLITE = 'C:\\cygwin\\bin\\setsid.exe C:\\cygwin\\bin\\sqlite3.exe' -- Run sqlite3 in background (returns immediately, best performance).
-- local SQLITE = -- Run sqlite3 directly (blocks execution until transaction has finished).
-- 'C:\\cygwin64\\bin\\sqlite3.exe'

local SQLITE = 'sqlite3.exe'
local LOCALCONFIG_DB = '%FARLOCALPROFILE%\\LocalConfig.db'
--[[
local LOCALCONFIG_DB = win.GetEnv('FARLOCALPROFILE')..'\\localconfig.db' --]]

LOCALCONFIG_DB = LOCALCONFIG_DB:gsub("%%(.-)%%", win.GetEnv)
SQLITE = SQLITE:gsub("%%(.-)%%", win.GetEnv)

if not	mf.fexist(SQLITE)
then	local sqlite_path, sqlite_name = win.SearchPath(nil, SQLITE, ".exe")
	if sqlite_path then SQLITE = sqlite_path end
end

local Curr_ActvLeft
local Curr_LeftPath
local Curr_LeftPhsP
local Curr_LeftItem
local Curr_RghtPath
local Curr_RghtPhsP
local Curr_RghtItem
local Prev_ActvLeft
local Prev_LeftPath
local Prev_LeftPhsP
local Prev_LeftItem
local Prev_RghtPath
local Prev_RghtPhsP
local Prev_RghtItem

local dt_tmp_chk = -1
local dt_clk_chk = -1
local dt_pnl_chk = -1

local tmp_dir_must
local log_file_loc
local log_line_fmt

local PanHostFile
local panel_prefx
local Act_UNC_Path
local Pas_UNC_Path
local dt_chg = 0
local dt_now = 0
local dt_now_str
local uncommitted = 0
local L_Panel
local R_Panel

--[[ UNCOMMENT
--[[ XeRoX's internal stuff here ]]
--[[ End of the XeRoX's internal stuff ]]
-- UNCOMMENT ]]

local function fnc_save_panel_state(pnl_evt_dat)
--	dbg.print('commit')
--	if true then return end
--	local L_Panel = APanel.Left and APanel or PPanel
--	local R_Panel = APanel.Left and PPanel or APanel
--[[
Curr_ActvLeft,
Curr_LeftPath,
Curr_LeftItem,
Curr_RghtPath,
Curr_RghtItem,
--]]
	local sqld = ([[
BEGIN TRANSACTION;
DELETE FROM 'general_config';
INSERT INTO 'general_config' VALUES('Panel.Left',	'CurFile',	'%s');
INSERT INTO 'general_config' VALUES('Panel.Left',	'Folder',	'%s');
INSERT INTO 'general_config' VALUES('Panel.Right',	'CurFile',	'%s');
INSERT INTO 'general_config' VALUES('Panel.Right',	'Folder',	'%s');
INSERT INTO 'general_config' VALUES('Panel',		'LeftFocus',	 %s );
COMMIT;]]
		):format(
			pnl_evt_dat.Curr_LeftItem:gsub("'", "''"),
			L_Panel.Path0:gsub("'", "''"),
			pnl_evt_dat.Curr_RghtItem:gsub("'", "''"),
			R_Panel.Path0:gsub("'", "''"),
			(pnl_evt_dat.Curr_ActvLeft and 1 or 0)
				):gsub("[\r\n\t]+", " ")
--	gsub("\t", " "):gsub("  ", " "):
--	panel.GetUserScreen()
--	local exec_res = os.execute(SQLITE..' "'..LOCALCONFIG_DB..'" "'..sqld..'"')
--	local sql_cmd =('@start "sqlcmd" /min %s "%s" "%s"'):format(SQLITE, LOCALCONFIG_DB, sqld)
	local sql_cmd = ('""""%s" "%s" "%s" """ >> %s 2>&1'):format(SQLITE, LOCALCONFIG_DB, sqld, SQL_OUT)
--	sql_cmd = '"'..string.gsub(sql_cmd, '"', '"')..'"'
--	wopds("sql_cmd: %s", sql_cmd)
	local exec_res, exec_msg = win.system(sql_cmd)
--	wopds("exec_res: %s", exec_res)
--	Xer0X.fnc_popen_proc(sql_cmd)
--	wopds("WRITTEN!!")
--	local exec_res = Xer0X.fnc_popen_proc(sql_cmd)
--	wopds(exec_res)
--	if exec_res == 0 or true then
--[[
	if false then
		wopds("sqlite3 exec result: "..exec_res)
		wopds(sql_cmd)
		_dump_tbl(split_v2(sqld, ";"))
	end
--]]
--	panel.SetUserScreen()
	return exec_res, exec_msg
end

local function fnc_evt_dir_chg(evt_data)
--[[ XeRoX's internal stuff here ]]
	Xer0X.pnl_evt_dat_last = evt_data
	local the_dir_new
	local	is_dir_chg =
		evt_data.chg_path_L or
		evt_data.chg_path_R
	if	is_dir_chg then
		the_dir_new = evt_data.chg_path_L and
			Curr_LeftPath or
			Curr_RghtPath
	--	far.Message(the_dir_new, "DIRECTORY changed!")
	end
--[[ End of the XeRoX's internal stuff ]]
--!	LE(evt_data)
--[[ UNCOMMENT
	local was_change = false
	local chg_str = ""
	for key, val in pairs(evt_data) do
		if type(val) == "boolean" and val and string.match(key, "^chg_") then
			was_change = true
			chg_str = chg_str..tostring(key).." = "..tostring(val).."\n"
		end
	end
	if was_change
	then	far.Message(chg_str, "Something changed!")
	else	far.Message("Nothing changed?!")
	end
-- UNCOMMENT ]]
end

local function fnc_check_panel_state(force_save)

	L_Panel = APanel.Left and APanel or PPanel
	R_Panel = APanel.Left and PPanel or APanel

	local	Prev_ActvLeft = Curr_ActvLeft

	local	Prev_LeftPath = Curr_LeftPath
	local	Prev_RghtPath = Curr_RghtPath
	local	Prev_LeftPhsP = Curr_LeftPhsP
	local	Prev_RghtPhsP = Curr_RghtPhsP
	local	Prev_LeftItem = Curr_LeftItem
	local	Prev_RghtItem = Curr_RghtItem

	Curr_ActvLeft = APanel.Left
	Curr_LeftPath = L_Panel.UNCPath
	Curr_RghtPath = R_Panel.UNCPath
	Curr_LeftPhsP = L_Panel.Path0
	Curr_RghtPhsP = R_Panel.Path0
	Curr_LeftItem = L_Panel.HostFile ~= "" and L_Panel.HostFile:match("([^/\\]-([^.]+))$") or L_Panel.Current
	Curr_RghtItem = R_Panel.HostFile ~= "" and R_Panel.HostFile:match("([^/\\]-([^.]+))$") or R_Panel.Current
--	wopds(Curr_LeftItem, "Curr_LeftItem")
--	wopds(Curr_RghtItem, "Curr_RghtItem")

	local	chg_actv_P = Prev_ActvLeft ~= Curr_ActvLeft
	local	chg_path_L = Prev_LeftPath ~= Curr_LeftPath
	local	chg_path_R = Prev_RghtPath ~= Curr_RghtPath
	local	chg_phsp_L = Prev_LeftPhsP ~= Curr_LeftPhsP
	local	chg_phsp_R = Prev_RghtPhsP ~= Curr_RghtPhsP
	local	chg_item_L = Prev_LeftItem ~= Curr_LeftItem
	local	chg_item_R = Prev_RghtItem ~= Curr_RghtItem

	local tbl_evt_data = {
		chg_actv_P = chg_actv_P, Prev_ActvLeft = Prev_ActvLeft,	Curr_ActvLeft = Curr_ActvLeft,
		chg_path_L = chg_path_L, Prev_LeftPath = Prev_LeftPath,	Curr_LeftPath = Curr_LeftPath,
		chg_path_R = chg_path_R, Prev_RghtPath = Prev_RghtPath,	Curr_RghtPath = Curr_RghtPath,
		chg_phsp_L = chg_phsp_L, Prev_LeftPhsP = Prev_LeftPhsP,	Curr_LeftPhsP = Curr_LeftPhsP,
		chg_phsp_R = chg_phsp_R, Prev_RghtPhsP = Prev_RghtPhsP,	Curr_RghtPhsP = Curr_RghtPhsP,
		chg_item_L = chg_item_L, Prev_LeftItem = Prev_LeftItem,	Curr_LeftItem = Curr_LeftItem,
		chg_item_R = chg_item_R, Prev_RghtItem = Prev_RghtItem,	Curr_RghtItem = Curr_RghtItem,
			}

	local chg_any =
		chg_actv_P or
		chg_path_L or
		chg_path_R or
		chg_phsp_L or
		chg_phsp_R or
		chg_item_L or
		chg_item_R

	local chg_dir =
		chg_actv_P or
		chg_path_L or
		chg_path_R or
		chg_phsp_L or
		chg_phsp_R

	if chg_any
	then
		fnc_evt_dir_chg(tbl_evt_data)
		if	uncommitted == 0
		then	dt_chg = dt_now
			uncommitted = 1
		else    uncommitted = uncommitted + 1
		end
	end

	local cmt_res, cmt_msg
	if 	force_save or
		uncommitted > 0 and (dt_now - dt_chg > SYNC_STORE_LIMIT)
	then
		uncommitted = 0
		cmt_res, cmt_msg = fnc_save_panel_state(tbl_evt_data)
	end

	return	chg_any, chg_dir, cmt_res == 0, tbl_evt_data
end -- of fnc_check_panel_state

local function fnc_prep_for_now()
	dt_now = Far.UpTime
	dt_now_str =
	--!	mf.date("%Y.%m0.%d %H:%M:%S")
		os.date("%Y-%m-%d %H:%M:%S")
--	is_boosted = dt_now - (dt_boosted or 0) < BOOST_OFF_INTERVAL
--[[ XeRoX's internal stuff here ]]
	if WRITE_LOG or CHK_TEMP_VAR then
		if not tmp_dir_must then tmp_dir_must = Xer0X.fnc_set_tmp_dir_var("temp") end
	if WRITE_LOG then
		if not log_line_fmt then log_line_fmt = "%s "..Far.PID.." %-8s %4s %s\n" end
		if not log_file_loc then log_file_loc = (tmp_dir_must.."\\check_env_%s.txt"):format(dt_now_str:gsub("[.]", ""):sub(1, 10)) end
	end end
--[[ End of the XeRoX's internal stuff ]]
end

--[[ XeRoX's internal stuff here ]]

if not Xer0X then _G.Xer0X = {} end

local function fnc_fix_plugin_cmd_prompt(force_check, pan_redraw)
	local	res_fix, was_redraw
	local	Act_UNC_Path_old = Act_UNC_Path
	local	Pas_UNC_Path_old = Pas_UNC_Path
	local	Act_UNC_Path_new = APanel.UNCPath
	local	Pas_UNC_Path_new = PPanel.UNCPath
	local	act_unc_ch = Act_UNC_Path_old ~= Act_UNC_Path_new
	local	pas_unc_ch = Pas_UNC_Path_old ~= Pas_UNC_Path_new
	local	any_unc_ch = pas_unc_ch or act_unc_ch
	if	act_unc_ch or force_check
	then
	--	wopds(Act_UNC_Path)
	--	wopds(APanel.UNCPath)
		Act_UNC_Path = Act_UNC_Path_new
		Pas_UNC_Path = Pas_UNC_Path_new
		res_fix = true
		if	Act_UNC_Path ~= "" and
			APanel.HostFile ~= "" and (
				APanel.Prefix ~= "" or
				APanel.Plugin
					)
		then 	PanHostFile = far.TruncPathStr(
			--!	mf.replace(Act_UNC_Path, "/"..APanel.Path, ""),
				Xer0X.fnc_str_replace(Act_UNC_Path, "/"..APanel.Path, ""),
				40
					)
			panel_prefix = APanel.Prefix == "" and "" or "::"..APanel.Prefix..":"
		elseif	false and
			APanel.UNCPath == "" and
			PanHostFile == "" and
			APanel.Prefix ~= ""
		then	PanHostFile = ""
			panel_prefix = APanel.Prefix..":"
		else	PanHostFile = ""
			panel_prefix = ""
		end
		win.SetEnv("panel_host_file",	PanHostFile)
		win.SetEnv("panel_prefix",	panel_prefix)
		if	Area.Shell and APanel.Visible and pan_redraw
		then
		--	wopds("??????????????????", APanel.CurPos)
			Panel.SetPosIdx(0, APanel.CurPos)
			panel.RedrawPanel(1)
			was_redraw = true
		end
	end
	return	true, res_fix, was_redraw
end -- fnc_fix_plugin_cmd_prompt

local function fnc_write_log(act_done, ts_duration)
	if ts_duration == 0 and act_done == "" then return end
	Xer0X.fnc_file_append(log_file_loc, log_line_fmt:format(dt_now_str:gsub("[:.]", ""), act_done, ts_duration, ""))
end

--[[ End of the XeRoX's internal stuff ]]

-- #####

local function fnc_timer_poll(tmr_sender, force_check, force_save, who_sent)

-- #####

if USE_TIMER and tmr_sender and not tmr_sender.Closed then tmr_sender.Enabled = false end

fnc_prep_for_now();

local	pnl_evt_dat, itm_ch, dir_ch, saved, has_prep, tmp_dir, tmp_fix, pfx_chk, pfx_fix, is_init, was_redraw
local 	act_done = who_sent or "?"

if	dt_now - dt_pnl_chk > POLL_INT_PNL_CHK or force_check or force_save
then	dt_pnl_chk = dt_now
	itm_ch, dir_ch, saved, pnl_evt_dat = fnc_check_panel_state(force_save)
	act_done = act_done..(saved and (itm_ch or dir_ch) and "$" or saved and "S" or (itm_ch or dir_ch) and "C" or "c")
--[[ XeRoX's internal stuff here ]]
	if	dir_ch
	then	act_done = act_done.."D"
		pfx_chk, pfx_fix, was_redraw = fnc_fix_plugin_cmd_prompt(false, true)
		if pfx_fix then act_done = act_done.."P" end
		if was_redraw then act_done = act_done.."R" end
	end
--[[ End of the XeRoX's internal stuff ]]
end

--[[ XeRoX's internal stuff here ]]

if	CHK_TEMP_VAR and (dt_now - dt_tmp_chk > POLL_INT_TMP_CHK or force_check)
then	dt_tmp_check = dt_now
	tmp_dir = win.GetEnv("TEMP"):upper()
	if	tmp_dir ~= tmp_dir_must
	then
		Xer0X.fnc_set_tmp_dir_var("TMP", 2)
		Xer0X.fnc_set_tmp_dir_var("TMPDIR", 2)
		Xer0X.fnc_set_tmp_dir_var("TEMP", 2)
		act_done = act_done.."T"
	end
end

if	UPD_TIME_VAR and (dt_now - dt_clk_chk > POLL_INT_CLK_CHK or force_check)
then
	local	dt_clk_new_str = dt_now_str:sub(12)
	if	dt_clk_str ~= dt_clk_new_str
	then
	--	wopds("clock: %s (%s)", dt_clk_str, dt_now - dt_clk_chk)
		dt_clk_chk = dt_now
		dt_clk_str = dt_clk_new_str
		win.SetEnv("time_short_x", dt_clk_str)
		act_done = act_done.."K"
		if not	was_redraw and REDRAW_SHELL and APanel.Visible and Area.Shell
		then	was_redraw = true
			local APCP = APanel.CurPos
			local pnlinf_pre = panel.GetPanelInfo(nil, 1)
		--	Current panel is !! 00000 !! here:
		--	Panel.SetPosIdx(0, APanel.CurPos)
			local ppv = PPanel.Visible
			Panel.Select(ppv and 1 or 0, 2, 1, 1)
			panel.RedrawPanel(ppv and 0 or 1)
			if	APanel.CurPos == 0 and APCP ~= 0
			then	local tmr_poll = far.Timer(5, function(sender)
					local paninf = panel.GetPanelInfo(nil, 1)
					local p = math.min(APCP, paninf.ItemsNumber);
				--	wopds("in timer Should be: "..p.." Prev:"..APCP.." IC:"..paninf.ItemsNumber.." CP:"..paninf.CurrentItem)
					if	paninf.CurrentItem == p
					then 	sender:Close()
					else	panel.RedrawPanel(1, { CurrentItem = p, TopPanelItem = pnlinf_pre.TopPanelItem })
					--	Panel.SetPosIdx(0, p)
					end
						end)
			end
			act_done = act_done.."R"
		end
	end
end

if WRITE_LOG then fnc_write_log(act_done, Far.UpTime - dt_now) end

--[[ End of the XeRoX's internal stuff ]]

if 	USE_TIMER and
	tmr_sender and not
	tmr_sender.Closed
then	tmr_sender.Enabled = true
--	tmr_sender.Interval = is_boosted and BOOST_INTERVAL or REGULAR_INTERVAL
end

return pnl_evt_dat

-- @@@ fnc_timer_poll

end

local panel_costs = {}
--[[ XeRoX's internal stuff here ]]
Xer0X.tbl_panel_costs = panel_costs
--[[ End of the XeRoX's internal stuff ]]
local panel_plugin_costs = {}
local last_cont_col_dir

local function fnc_eat_evt(file_path, who_sent)
	local	evt_dat = fnc_timer_poll(tmr_poll, true, false, who_sent)
	local	chg_dir =
		evt_dat.chg_path_L or
		evt_dat.chg_path_R
	local	is_plugin, file_plugin_dir, path_dir
	if 	file_path
	then	path_dir = file_path:match("^(.+[\\/])"):match("^(.+)\\$")
	else	path_dir = -- Need to be WITHOUT BACKSLASH AT THE END!!
			evt_dat.chg_path_L and evt_dat.Curr_LeftPath or
			evt_dat.chg_path_R and evt_dat.Curr_RghtPath
	end
	local panel_cont_first_run = not panel_costs[path_dir]
	if not (chg_dir or panel_cont_first_run) then return path_dir end
	is_plugin = file_path and file_path:sub(1, 4) == "\\\\?\\"
	if	is_plugin
	then	file_plugin_dir = file_path:sub(5, -2)
		path_dir	= path_dir :sub(5, -1)
	elseif	file_path and APanel.Plugin
	then	is_plugin = true
	--	far.Message("CHECK IT AAAA IUIII SSIS!!!!")
		file_plugin_dir = mf.fsplit(file_path, 3):sub(1, -2)
	end
	local host_file_L_dir = is_plugin and L_Panel.Path0:find(file_plugin_dir, nil, "plain") == 1 and L_Panel.Path0 == file_plugin_dir and file_plugin_dir
	local host_file_R_dir = is_plugin and R_Panel.Path0:find(file_plugin_dir, nil, "plain") == 1 and R_Panel.Path0 == file_plugin_dir and file_plugin_dir
	if 	evt_dat.chg_path_L or
		panel_cont_first_run
	then	if	panel_costs[L_Panel.Path0]
		then	panel_costs[L_Panel.Path0].dt_start = dt_now
			panel_costs[L_Panel.Path0].items_cnt = 0
			panel_costs[L_Panel.Path0].dt_said_cost = nil
		else	panel_costs[L_Panel.Path0] = { cost = 0, items_cnt = 0, items_calc_cnt = 0, dt_start = dt_now, dt_created = dt_now, path_dir = L_Panel.Path0, host_file_dir = host_file_L_dir and true or false, is_left = true, who_sent = who_sent}
		end
	end
	if 	evt_dat.chg_path_R or
		panel_cont_first_run
	then	if	panel_costs[R_Panel.Path0]
		then	panel_costs[R_Panel.Path0].dt_start = dt_now
			panel_costs[R_Panel.Path0].items_cnt = 0
			panel_costs[R_Panel.Path0].dt_said_cost = nil
		else	panel_costs[R_Panel.Path0] = { cost = 0, items_cnt = 0, items_calc_cnt = 0, dt_start = dt_now, dt_created = dt_now, path_dir = R_Panel.Path0, host_file_dir = host_file_R_dir and true or false, is_left = false, who_sent = who_sent}
		end
	end
	if panel_cont_first_run then panel_cont_first_run = false end
	if is_plugin then panel_costs[file_plugin_dir] = panel_costs[host_file_L_dir or host_file_R_dir] end
	return path_dir
end; -- of fnc_eat_evt

local ContCol_v2 =
-- ContentColumns
	{
-- ###
--[[ XeRoX's internal stuff here --]]
--[[
GetOpenPanelInfo = function(param1, param2, param3)
	wopds("not works here (param1: %s, param2: %s, param3: %s)", param1, param2, param3)
end;
--]]
--[[ End of the XeRoX's internal stuff ]]
GetContentFields = function(col_set, param2)
--	_dump_tbl(col_set, "in ColNames GetContentFields")
--	wopds("GetContentFields(param1: %s, param2: %s, param3: %s)", col_set, param2)
--	wopds("APanel %s", APanel.UNCPath)
--	wopds("PPanel %s", PPanel.UNCPath)
	local new_dir = fnc_eat_evt(nil, "P_")
--[[ UNCOMMENT
	return true
-- UNCOMMENT ]]
--[[ XeRoX's internal stuff here --]]
	if true then return true end
	Xer0X.fnc_trans_msg(new_dir or "???", "NEW DIR !?")
	for	ii,	val in ipairs(col_set)
	do	local	col = string.lower(val)
		if	col == "link"
		or	col == "i"
		or	col == "i2"
		or	col == "x"
		or	col == "n"
		then 	return true
		end
	end
--[[ End of the XeRoX's internal stuff ]]
end;

GetContentData = function(path_file, col_set)
--	_dump_tbl(col_set, "col_set")
--	wopds("path_file: %s", path_file)
	local	col_dat = {}
--	if true then return col_dat end;
--[[	experimentally disabled:
	if	string.sub(path_file, -1) == "\\" then fnc_eat_evt(path_file) end
--]]
	local	new_dir = string.match(path_file, ".?\\$") and true or false
	local	path_fold = string.sub(string.match(path_file, "^(.+[\\/])"), 1, -2)
	if	string.sub(path_file, 1, 4) == "\\\\?\\"
	then	-- Plugin?
		path_fold = string.sub(path_fold, 5)
	end
	if	path_fold:sub(1, 4) == "UNC\\"
	then	-- Network?
		path_fold = "\\"..path_fold:sub(4)
	end
	local is_root, path_root, unc_host
	unc_host = string.match(path_fold, "^\\\\([^\\]+)")
	path_root = unc_host and
		string.match(path_fold, "^\\\\.-\\[^\\]+[^\\]") or
		string.match(path_fold, "^[^\\]:") -- or :match("^%u:$")
	is_root = path_root == path_fold
	if	is_root
	then	path_fold = path_fold.."\\"
	end
	local	pan_cost = panel_costs[path_fold]
	local	last_cont_col_dir_chg = path_fold ~= last_cont_col_dir or new_dir or not pan_cost
	if	last_cont_col_dir_chg
	then	fnc_eat_evt(path_file, "C_")
	--	wopds("%s <???> %s", path_fold, last_cont_col_dir)
		last_cont_col_dir_chg = true
		last_cont_col_dir = path_fold
		--[[ just some debug:
		local req_loc = {L_Panel, R_Panel, evt_dat, evt_d, last_cont_col_dir}
		_dump_tbl(col_set, "UNEXPECTED COL SET")
                -- end of some debug block ]]
		pan_cost = panel_costs[path_fold]
	end
--	wopds("t5655555")
	if	pan_cost.host_file_dir
	then--	wopds("no calculations in plugin paths");
		return
	end
--	wopds("6666666666")
--	if true then return col_dat end
	local	too_costy = pan_cost.cost > CONT_COL_DIR_CALC_LIM
	local	dt_calc_start = Far.UpTime
	local	the_col
	for	ii, val in ipairs(col_set)
	do	the_col = string.lower(val)
		if	too_costy
		then	col_dat[ii] = "."
			if not	pan_cost.dt_said_cost
			then	pan_cost.dt_said_cost = Far.UpTime
			--	wopds("cost %s of %s (%s)", pan_cost.cost, path_fold, pan_cost.dt_said_cost)
			end
		else	if	the_col == "i" -- empty?
			then	local	f_attr = win.GetFileAttr(path_file)
			--	wopds("ATTTRIBS", f_attr)
				if	f_attr
				then	local	is_dir = string.find(f_attr, "d") and true or false
				--	local	is_dir = f_attr:find("d") and true or false
					local 	is_lnk = string.find(f_attr, "e") and true or false
					local 	is_arc = string.find(f_attr, "a") and true or false
					if	is_dir and not is_lnk
					then	local found_cnt = 0
						local found_file, got_tmOt = far.RecursiveSearch(
							path_file, '*.*', function(item)
-- ###
-- _dump_tbl(item, "IN SEARCH");
-- if true then return true end
found_cnt = found_cnt + 1
if not	string.match(item.FileAttributes, "d")
then	return true
elseif	found_cnt % 25 == 0 and Far.UpTime - dt_calc_start > CONT_COL_DIR_CALC_LIM
then -- wopds("timeouted on %s, took %s", item.FileName, Far.UpTime - dt_calc_start)
	return true, true
end
-- @@@
								end, far.Flags.FRS_RECUR
									)
						if got_tmOt then wopds("TIMEOUT? %s, found %s", tostring(got_tmOt), found_cnt) end
						col_dat[ii] = got_tmOt and "." or found_file and "" or found_cnt > 0 and "e" or "E"
					else 	local link_cnt = far.GetNumberOfLinks(path_file)
						col_dat[ii] = link_cnt > 1 and tostring(link_cnt) or ""
					end
					if not	col_dat[ii]
					or	col_dat[ii] == ""
						then	if	is_lnk
							then	col_dat[ii] = ">"
							-- ..far.GetReparsePointInfo(path_file)
							elseif 	is_arc and not is_dir
							then	col_dat[ii] = "a"
							end
					end
				end
			--	col_dat[ii] = "X"
			elseif 	the_col == "i2"
			then
			elseif	the_col == "x"
			then
			--	col_dat[ii] = APanel.Left and "L" or "R"
			--	wopds(the_col.." path_file: %s", path_file)
			end
			pan_cost.items_calc_cnt = pan_cost.items_calc_cnt + 1
			pan_cost.dt_calc = Far.UpTime
		end
	--	if not col_dat[ii] then col_dat[ii] = "" end
	end
	pan_cost.items_cnt = pan_cost.items_cnt + 1
	pan_cost.cost = pan_cost.cost + (Far.UpTime - dt_calc_start)
	pan_cost.dt_walk = Far.UpTime
--	wopds("COST %s of %s", pan_cost.cost, path_dir)
	return col_dat
end;
-- @@@ c0_v2
	}

if not	Far
then	for k, v in pairs(ContCol_v2) do export[k] = v; end
elseif	ContentColumns
then	ContentColumns(ContCol_v2)
end

local tmr_poll
if USE_TIMER then
	tmr_poll = far.Timer(POLL_INTERVAL, fnc_timer_poll, false, false, "T_")
end

local	FAR_EXIT_MSG_DLG_ID_TXT = "4EBBEFC8-2084-4B7F-94C0-692CE136894D"
local	FAR_EXIT_MSG_DLG_ID_BIN = win.Uuid(FAR_EXIT_MSG_DLG_ID_TXT)

Event { description = "FAR exit detection";
	group = "DialogEvent";
	action = function(evt, prm)
-- ###
if	prm.Msg == far.Flags.DN_INITDIALOG and evt == far.Flags.DE_DLGPROCINIT
then	local	dlg_info = prm.hDlg:send(far.Flags.DM_GETDIALOGINFO)
	if	dlg_info and win.Uuid(dlg_info.Id):upper() == FAR_EXIT_MSG_DLG_ID_TXT
	then
	--	wopds("?????????????????????????", win.Uuid(dlg_info.Id):upper(), FAR_EXIT_MSG_DLG_ID_TXT)
		fnc_timer_poll(tmr_poll, false, true, "E_")
	end
end
--[[ XeRoX's internal stuff here --]]
if true then return end
local	msg, hDlg = prm.Msg, prm.hDlg
local	DLG_MSG_EXIT_FAR = "Do you want to quit Far?"
if	msg ==	far.Flags.DN_INITDIALOG and evt == far.Flags.DE_DLGPROCINIT
then	local	elm_text = far.SendDlgMessage(hDlg, far.Flags.DM_GETTEXT, 2);
	if	elm_text == DLG_MSG_EXIT_FAR
	then	fnc_timer_poll(tmr_poll, false, true, "X_")
	end
elseif	msg ==	far.Flags.DN_RESIZECONSOLE
then	if	evt == far.Flags.DE_DLGPROCINIT
	and	Menu.Id == "whatever"
	then	hDlg:send(far.Flags.DM_CLOSE, -1, 0)
		smtg1:calcProps()
	end
elseif	msg == far.Flags.DN_INITDIALOG
and	evt == far.Flags.DE_DLGPROCINIT
and	whatever
then	local	info = hDlg:send(far.Flags.DM_GETDIALOGINFO)
	if 	info and info.Id == win.Uuid("hehehehehehe")
	then	local rect = hDlg:send(far.Flags.DM_GETITEMPOSITION, 1)
		hDlg:send(far.Flags.DM_SETITEMPOSITION, 1, { Left = rect.Left - 2, Top = rect.Top - 1, Right = rect.Right - 2, Bottom = rect.Bottom - 1 })
		rect = hDlg:send(far.Flags.DM_GETDLGRECT)
		hDlg:send(far.Flags.DM_RESIZEDIALOG,	0, { Y = rect.Bottom - rect.Top - 1, X = rect.Right - rect.Left - 3 })
		hDlg:send(far.Flags.DM_MOVEDIALOG,	0, { X = 2, Y = smtg1.Pos == "Bottom" and 1 or 0 })
	end
end
--[[ End of the XeRoX's internal stuff ]]
-- @@@
	end;
}

Event { description = "PanelChangeDir: Clean up timer on exit";
	group = "ExitFAR";
	action = function()
-- ###
if	tmr_poll
then	if	tmr_poll.Enabled	then tmr_poll.Enabled = false; end;
	if not	tmr_poll.Closed		then tmr_poll:Close(); end;
	tmr_poll = nil;
end
-- fnc_timer_poll(nil, false, true)
-- @@@
	end;
}

Macro { description = "detect panel change";
	area = "Shell"; key = "Tab Enter CtrlU CtrlF1 CtrlF2 CtrlPgUp CtrlPgDn";
	condition = function()
-- ###
if not (APanel.Visible or PPanel.Visible) then return end
far.Timer(5, function(sender) sender.Enabled = false; sender:Close(); fnc_eat_evt(nil, "M_") end)
return false;
-- @@@
	end;
	action = function()
--[[ XeRoX's internal stuff here --]]
-- ###
for k, v in pairs(Editor) do print(k.."\n"..tostring(v).."\n\n") end
for k, v in pairs(Editor.properties) do print(k.."\n"..tostring(v).."\n\n") end
-- @@@
--[[ End of the XeRoX's internal stuff ]]
	end
}
