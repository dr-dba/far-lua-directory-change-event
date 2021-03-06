
--[[	@Xer0X & CitRix CopyLeft 2020
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
local REDRAW_SHELL = false -- to update prompt clock
local USE_TIMER =
	true
local CONT_COL_DIR_CALC_LIM = 5000
local SYNC_STORE_LIMIT = 30000
local SQL_OUT =
	"NUL"
--	"c:\\sqlite.out"


local SQLITE = 'sqlite3.exe'
local LOCALCONFIG_DB = '%FARLOCALPROFILE%\\LocalConfig.db'

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


local function fnc_save_panel_state(pnl_evt_dat)
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
	local sql_cmd = ('""""%s" "%s" "%s" """ >> %s 2>&1'):format(SQLITE, LOCALCONFIG_DB, sqld, SQL_OUT)
	local exec_res, exec_msg = win.system(sql_cmd)
	return exec_res, exec_msg
end

local function fnc_evt_dir_chg(evt_data)
--	LE(evt_data)
	local was_change = false
	local chg_str = ""
	for key, val in pairs(evt_data) 
	do	if	val
		and	type(val) == "boolean" 
		and	string.match(key, "^chg_") 
		then	was_change = true
			chg_str = chg_str..tostring(key).." = "..tostring(val).."\n"
		end
	end
	if was_change
	then	far.Message(chg_str, "Something changed!")
	else	far.Message("Nothing changed?!")
	end
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
	--	mf.date("%Y.%m0.%d %H:%M:%S")
		os.date("%Y-%m-%d %H:%M:%S")
end


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
end


if	USE_TIMER 
and	tmr_sender 
and not tmr_sender.Closed
then	tmr_sender.Enabled = true
end

return pnl_evt_dat

-- @@@ fnc_timer_poll

end

local panel_costs = {}
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
	else	path_dir =
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
end;

local ContCol_v2 =
	{
-- ###
GetContentFields = function(col_set, param2)
	local new_dir = fnc_eat_evt(nil, "P_")
	return true
end;

GetContentData = function(path_file, col_set)
	local	col_dat = {}
	local	new_dir = string.match(path_file, ".?\\$") and true or false
	local	path_fold = string.sub(string.match(path_file, "^(.+[\\/])"), 1, -2)
	if	string.sub(path_file, 1, 4) == "\\\\?\\"
	then
		path_fold = string.sub(path_fold, 5)
	end
	if	path_fold:sub(1, 4) == "UNC\\"
	then
		path_fold = "\\"..path_fold:sub(4)
	end
	local is_root, path_root, unc_host
	unc_host = string.match(path_fold, "^\\\\([^\\]+)")
	path_root = unc_host and
		string.match(path_fold, "^\\\\.-\\[^\\]+[^\\]") or
		string.match(path_fold, "^[^\\]:")
	is_root = path_root == path_fold
	if	is_root
	then	path_fold = path_fold.."\\"
	end
	local	pan_cost = panel_costs[path_fold]
	local	last_cont_col_dir_chg = path_fold ~= last_cont_col_dir or new_dir or not pan_cost
	if	last_cont_col_dir_chg
	then	fnc_eat_evt(path_file, "C_")
		last_cont_col_dir_chg = true
		last_cont_col_dir = path_fold
		
		pan_cost = panel_costs[path_fold]
	end
	if	pan_cost.host_file_dir
	then
		return
	end
	local	too_costy = pan_cost.cost > CONT_COL_DIR_CALC_LIM
	local	dt_calc_start = Far.UpTime
	local	the_col
	for	ii, val in ipairs(col_set)
	do	the_col = string.lower(val)
		if	too_costy
		then	col_dat[ii] = "."
			if not	pan_cost.dt_said_cost
			then	pan_cost.dt_said_cost = Far.UpTime
			end
		else	if	the_col == "i"
			then	local	f_attr = win.GetFileAttr(path_file)
				if	f_attr
				then	local	is_dir = string.find(f_attr, "d") and true or false
					local 	is_lnk = string.find(f_attr, "e") and true or false
					local 	is_arc = string.find(f_attr, "a") and true or false
					if	is_dir and not is_lnk
					then	local found_cnt = 0
						local found_file, got_tmOt = far.RecursiveSearch(
							path_file, '*.*', function(item)
-- ###
found_cnt = found_cnt + 1
if not	string.match(item.FileAttributes, "d")
then	return true
elseif	found_cnt % 25 == 0 and Far.UpTime - dt_calc_start > CONT_COL_DIR_CALC_LIM
then
	return true, true
end
-- @@@
								end, far.Flags.FRS_RECUR
									)
						col_dat[ii] = got_tmOt and "." or found_file and "" or found_cnt > 0 and "e" or "E"
					else 	local link_cnt = far.GetNumberOfLinks(path_file)
						col_dat[ii] = link_cnt > 1 and tostring(link_cnt) or ""
					end
					if not	col_dat[ii]
					or	col_dat[ii] == ""
						then	if	is_lnk
							then	col_dat[ii] = ">"
							elseif 	is_arc and not is_dir
							then	col_dat[ii] = "a"
							end
					end
				end
			elseif 	the_col == "i2"
			then
			elseif	the_col == "x"
			then
			end
			pan_cost.items_calc_cnt = pan_cost.items_calc_cnt + 1
			pan_cost.dt_calc = Far.UpTime
		end
	end
	pan_cost.items_cnt = pan_cost.items_cnt + 1
	pan_cost.cost = pan_cost.cost + (Far.UpTime - dt_calc_start)
	pan_cost.dt_walk = Far.UpTime
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
		fnc_timer_poll(tmr_poll, false, true, "E_")
	end
end
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
	end
}
