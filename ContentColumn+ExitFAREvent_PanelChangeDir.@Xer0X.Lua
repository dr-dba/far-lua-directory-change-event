
--[[	@Xer0X & CitRix CopyLeft 2020
	White Power Resistance Commando@line team
	Presenting to you:

	This script gives saves and restores
	last paths and current items on both
	right and left panels of FAR Manager
	between restarts

based on the code of Gene.Pavlovsky:
https://forum.farmanager.com/viewtopic.php?t=10521

FarForum discussion page:
https://forum.farmanager.com/viewtopic.php?t=12437

GitHub home:
https://github.com/dr-dba/far-lua-directory-change-event
Put the script here:
%FARPROFILE%\Macros\scripts\ContentColumn+ExitFAREvent_PanelChangeDir.@Xer0X.Lua
%APPDATA%\Far Manager\Profile\Macros\scripts\ContentColumn+ExitFAREvent_PanelChangeDir.@Xer0X.Lua

DEPENDS ON THE LUA MODULE:
https://github.com/dr-dba/far-lua-general-utils
Put the Lua module here:
%FARPROFILE%\Macros\modules\Lib-Common-@Xer0X.Lua

You may use custom script for panel change events trackings:
%FARPROFILE%\Macros\scripts\ContentColumn+ExitFAREvent_PanelChangeDir.@Xer0X.Lua.Cfg
An example of custom script can be seen or taken from the GitHub page
]]

local sz_own_file, sz_some_load_code = ...

local Xer0X = Xer0X or require("Lib-Common-@Xer0X")

local F = far.Flags
local DN_INITDIALOG	= F.DN_INITDIALOG
local DM_GETDIALOGINFO	= F.DM_GETDIALOGINFO
local DM_GETTEXT	= F.DM_GETTEXT
local DE_DLGPROCINIT	= F.DE_DLGPROCINIT
local DM_GETDLGRECT	= F.DM_GETDLGRECT
local DM_RESIZEDIALOG	= F.DM_RESIZEDIALOG
local DM_MOVEDIALOG	= F.DM_MOVEDIALOG
local DM_SETITEMPOSITION= F.DM_SETITEMPOSITION
local DM_GETITEMPOSITION= F.DM_GETITEMPOSITION
local DN_RESIZECONSOLE	= F.DN_RESIZECONSOLE
local FRS_RECUR		= F.FRS_RECUR
local DM_CLOSE		= F.DM_CLOSE

local string_lower	= string.lower
local string_format	= string.format
local string_find	= string.find
local string_match	= string.match
local string_gsub	= string.gsub
local string_sub	= string.sub

local far_GetNumberOfLinks	
			= far.GetNumberOfLinks
local far_SendDlgMessage	
			= far.SendDlgMessage
local far_RecursiveSearch	
			= far.RecursiveSearch
local far_TruncPathStr	= far.TruncPathStr
local far_Timer		= far.Timer

local panel_GetPanelInfo= panel.GetPanelInfo
local panel_RedrawPanel	= panel.RedrawPanel
local Panel_SetPosIdx	= Panel.SetPosIdx
local Panel_Select	= Panel.Select

local win_GetFileAttr	= win.GetFileAttr
local win_SearchPath	= win.SearchPath
local win_SetEnv	= win.SetEnv
local win_GetEnv	= win.GetEnv
local win_system	= win.system
local win_Uuid		= win.Uuid

local mf_fsplit		= mf.fsplit
local os_date		= os.date
local math_min		= math.min
local math_max		= math.max

local fnc_str_replace   = Xer0X.fnc_str_replace
local fnc_set_tmp_dir_var
			= Xer0X.fnc_set_tmp_dir_var
local fnc_file_append	= Xer0X.fnc_file_append
local fnc_trans_msg	= Xer0X.fnc_trans_msg

-- Timer poll interval in milliseconds:
local POLL_INTERVAL	= 1000
local POLL_INT_PNL_CHK	= 3000
local POLL_INT_TMP_CHK	= 5000
local POLL_INT_CLK_CHK	= 10000

local TMP_DIR_MUST	= fnc_set_tmp_dir_var("temp") 
local WRITE_LOG		= true

local LOG_LINE_FMT	= "%s "..Far.PID.." %-8s %4s %s\n"
local LOG_FILE_LOC	= TMP_DIR_MUST..("\\check_env_%s.txt"):format(os_date("%Y-%m-%d %H:%M:%S"):gsub("[.]", ""):sub(1, 10))

local UPD_TIME_VAR	= false
local CHK_TEMP_VAR	= false
local REDRAW_SHELL	= false -- to update prompt clock
local STORE_PANEL_PATHS	= true
local USE_TIMER		= true
local CONT_COL_DIR_CALC_LIM
			= 5000
local SYNC_STORE_LIMIT	= 10000
local SQLITE_OUTPUT	= 
			"NUL"
		--	"%TEMP%\\sqlite.out"
local API_ACT_PNL = 1
local API_PAS_PNL = 0
local MCR_ACT_PNL = 0
local MCR_PAS_PNL = 1

local FAR_EXIT_MSG_DLG_ID_TXT = "4EBBEFC8-2084-4B7F-94C0-692CE136894D"
local FAR_EXIT_MSG_DLG_ID_BIN = win_Uuid(FAR_EXIT_MSG_DLG_ID_TXT)

local CUSTOM_CHANGE_SCRIPT_PATH = sz_own_file..'.Cfg'
local SQLITE_EXE_PATH	= 'sqlite3.exe'
local LOCALCONFIG_DB	= '%FARLOCALPROFILE%\\LocalConfig.db'

LOCALCONFIG_DB	= LOCALCONFIG_DB :gsub("%%(.-)%%", win_GetEnv)
SQLITE_EXE_PATH = SQLITE_EXE_PATH:gsub("%%(.-)%%", win_GetEnv)
SQLITE_OUTPUT	= SQLITE_OUTPUT	: gsub("%%(.-)%%", win_GetEnv)

if not mf.fexist(SQLITE_EXE_PATH)
then	local	sqlite_path, 
		sqlite_name 
			= win.SearchPath(nil, SQLITE_EXE_PATH, ".exe")
	if	sqlite_path 
	then	SQLITE_EXE_PATH = sqlite_path 
	end
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

local PanHostFile
local panel_prefx
local Act_UNC_Path
local Pas_UNC_Path
local dt_chg = 0
local dt_now = Far.UpTime
local dt_now_str = os_date("%Y-%m-%d %H:%M:%S")
local uncommitted = 0
local L_Panel
local R_Panel
local tmr_poll, last_cont_col_dir

local function fnc_save_panel_state(pnl_evt_dat)
	local sqld = ([[
BEGIN TRANSACTION;
DELETE FROM 'general_config';
INSERT INTO 'general_config' VALUES('Panel.Left' , 'CurFile'	, '%s');
INSERT INTO 'general_config' VALUES('Panel.Left' , 'Folder'	, '%s');
INSERT INTO 'general_config' VALUES('Panel.Right', 'CurFile'	, '%s');
INSERT INTO 'general_config' VALUES('Panel.Right', 'Folder'	, '%s');
INSERT INTO 'general_config' VALUES('Panel'	 , 'LeftFocus'	,  %s );
COMMIT;]]       ):format(
			pnl_evt_dat.Curr_LeftItem:gsub("'", "''"), L_Panel.Path0:gsub("'", "''"),
			pnl_evt_dat.Curr_RghtItem:gsub("'", "''"), R_Panel.Path0:gsub("'", "''"),
			pnl_evt_dat.Curr_ActvLeft and 1 or 0
		):gsub("[\r\n\t]+", " ")
	local sql_cmd = ('""""%s" "%s" "%s" """ >> %s 2>>&1'):format(SQLITE_EXE_PATH, LOCALCONFIG_DB, sqld, SQLITE_OUTPUT)
	local exec_res, exec_msg = win_system(sql_cmd)
	return exec_res, exec_msg
end

local fnc_custom_change_proc = nil
if mf.fexist(CUSTOM_CHANGE_SCRIPT_PATH) 
then	local	cust_func = loadfile(CUSTOM_CHANGE_SCRIPT_PATH)
	if type(cust_func) == 'function' 
	then	cust_func = cust_func()
		if type(cust_func) == 'function' 
		then fnc_custom_change_proc = cust_func
		end
	end
end

local function fnc_evt_dir_chg(evt_data)
	if	fnc_custom_change_proc
	then	fnc_custom_change_proc(evt_data)
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

	local chg_dir =
		chg_actv_P or
		chg_path_L or
		chg_path_R or
		chg_phsp_L or
		chg_phsp_R

	local chg_any = 
		chg_item_L or
		chg_item_R or
		chg_dir

	local tbl_evt_data = {
		chg_actv_P = chg_actv_P, Prev_ActvLeft = Prev_ActvLeft,	Curr_ActvLeft = Curr_ActvLeft,
		chg_path_L = chg_path_L, Prev_LeftPath = Prev_LeftPath,	Curr_LeftPath = Curr_LeftPath,
		chg_path_R = chg_path_R, Prev_RghtPath = Prev_RghtPath,	Curr_RghtPath = Curr_RghtPath,
		chg_phsp_L = chg_phsp_L, Prev_LeftPhsP = Prev_LeftPhsP,	Curr_LeftPhsP = Curr_LeftPhsP,
		chg_phsp_R = chg_phsp_R, Prev_RghtPhsP = Prev_RghtPhsP,	Curr_RghtPhsP = Curr_RghtPhsP,
		chg_item_L = chg_item_L, Prev_LeftItem = Prev_LeftItem,	Curr_LeftItem = Curr_LeftItem,
		chg_item_R = chg_item_R, Prev_RghtItem = Prev_RghtItem,	Curr_RghtItem = Curr_RghtItem,
		chg_dir = chg_dir,
		chg_any = chg_any,
	}

	if chg_any
	then
		fnc_evt_dir_chg(tbl_evt_data)
		if	uncommitted == 0
		then	dt_chg = dt_now
			uncommitted = 1
		else    uncommitted = uncommitted + 1
		end
	end

	local	cmt_res, cmt_msg
	if 	STORE_PANEL_PATHS
	and (	force_save 
	or 	uncommitted > 0 
	and 	dt_now - dt_chg > SYNC_STORE_LIMIT)
	then	uncommitted = 0
		cmt_res, cmt_msg = fnc_save_panel_state(tbl_evt_data)
	end

	return	chg_any, chg_dir, cmt_res == 0, tbl_evt_data
end -- of fnc_check_panel_state

-- #####

local function fnc_redraw_panel_to_show_time_in_prompt(sender, ActPanCurPos, TopPanelItem)
	local paninf = panel_GetPanelInfo(nil, 1)
	local pos_to_set = math_min(ActPanCurPos, paninf.ItemsNumber)
	if	paninf.CurrentItem == pos_to_set
	then 	sender:Close()
	else	panel_RedrawPanel(API_ACT_PNL, { CurrentItem = pos_to_set, TopPanelItem = TopPanelItem })
	end
end


local function fnc_timer_poll(tmr_sender, force_check, force_save, who_sent)

-- ###

if	USE_TIMER 
and	tmr_sender 
and not tmr_sender.Closed 
then	tmr_sender.Enabled = false 
end
dt_now = Far.UpTime
dt_now_str = os_date("%Y-%m-%d %H:%M:%S")

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

local panel_costs = { }
local panel_plugin_costs = { }

local function fnc_eat_evt(file_path, who_sent)
	local	evt_dat = fnc_timer_poll(tmr_poll, true, false, who_sent)
	local	chg_dir = evt_dat.chg_dir
	local	file_plugin_dir, path_dir
	if 	file_path
	then	path_dir = file_path -- Need to be WITHOUT BACKSLASH AT THE END!!
			:match("^(.+[\\/])")
			:match("^(.+)\\$")
	else	path_dir = 
			evt_dat.chg_path_L and evt_dat.Curr_LeftPath or
			evt_dat.chg_path_R and evt_dat.Curr_RghtPath
	end
	local panel_cont_first_run = not panel_costs[path_dir]
	if not (chg_dir or panel_cont_first_run) then return path_dir end
	local	is_plugin = file_path and string_sub(file_path, 1, 4) == "\\\\?\\"
	if	is_plugin
	then	file_plugin_dir = string_sub(file_path	, 5, -2)
		path_dir	= string_sub(path_dir	, 5, -1)
	elseif	file_path and APanel.Plugin
	then	is_plugin = true
		file_plugin_dir = mf_fsplit(file_path, 3):sub(1, -2)
	end
	local host_file_L_dir = is_plugin and string_find(L_Panel.Path0, file_plugin_dir, nil, "plain") == 1 and L_Panel.Path0 == file_plugin_dir and file_plugin_dir
	local host_file_R_dir = is_plugin and string_find(R_Panel.Path0, file_plugin_dir, nil, "plain") == 1 and R_Panel.Path0 == file_plugin_dir and file_plugin_dir
	if evt_dat.chg_path_L or panel_cont_first_run
	then	if	panel_costs[L_Panel.Path0]
		then	panel_costs[L_Panel.Path0].dt_start = dt_now
			panel_costs[L_Panel.Path0].items_cnt = 0
			panel_costs[L_Panel.Path0].dt_said_cost = nil
		else	panel_costs[L_Panel.Path0] = { cost = 0, items_cnt = 0, items_calc_cnt = 0, dt_start = dt_now, dt_created = dt_now, path_dir = L_Panel.Path0, host_file_dir = host_file_L_dir and true or false, is_left = true, who_sent = who_sent }
		end
	end
	if evt_dat.chg_path_R or panel_cont_first_run
	then	if	panel_costs[R_Panel.Path0]
		then	panel_costs[R_Panel.Path0].dt_start = dt_now
			panel_costs[R_Panel.Path0].items_cnt = 0
			panel_costs[R_Panel.Path0].dt_said_cost = nil
		else	panel_costs[R_Panel.Path0] = { cost = 0, items_cnt = 0, items_calc_cnt = 0, dt_start = dt_now, dt_created = dt_now, path_dir = R_Panel.Path0, host_file_dir = host_file_R_dir and true or false, is_left = false,who_sent = who_sent }
		end
	end
	if	panel_cont_first_run 
	then	panel_cont_first_run = false 
	end
	if is_plugin then panel_costs[file_plugin_dir] = panel_costs[host_file_L_dir or host_file_R_dir] end
	return path_dir
end; 

local found_cnt
local function fnc_file_item_check(tbl_file_item, str_file_name, dt_col_calc_start)
	found_cnt = found_cnt + 1
	if not	string_match(tbl_file_item.FileAttributes, "d")
	then	return true, false -- found a file
	elseif	found_cnt % 10 == 0 
	and	Far.UpTime - dt_col_calc_start > CONT_COL_DIR_CALC_LIM
	then    -- timeouted lookinf in the directory
		return true, true
	end
end

local ContCol_v2 =
{
-- ###
GetContentFields = function(col_set, param2)
	local new_dir = fnc_eat_evt(nil, "P_")
	return true
end,

GetContentData = function(path_file, col_set)
	local	col_dat = { }
	local	new_dir = string_match(path_file, ".?\\$") and true or false
	local	path_fold = string_sub(string_match(path_file, "^(.+[\\/])"), 1, -2)
	if	string_sub(path_file, 1, 4) == "\\\\?\\"
	then	-- Plugin?
		path_fold = string_sub(path_fold, 5)
	end
	if	path_fold:sub(1, 4) == "UNC\\"
	then	-- Network?
		path_fold = "\\"..path_fold:sub(4)
	end
	local	unc_host = string_match(path_fold, "^\\\\([^\\]+)")
	local	path_root = unc_host 
			and	string_match(path_fold, "^\\\\.-\\[^\\]+[^\\]") 
			or	string_match(path_fold, "^[^\\]:") 
	local	is_root = path_root == path_fold
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
	then	return
	end
	local	is_too_costy_dir_scan = pan_cost.cost > CONT_COL_DIR_CALC_LIM
	local	dt_col_calc_start = Far.UpTime
	for ii, ii_val in ipairs(col_set)
	do	
		local	the_col = string_lower(ii_val)
		if	the_col == "i"
		then	
			if	is_too_costy_dir_scan
			then	
				col_dat[ii] = "."
				if not	pan_cost.dt_said_cost
				then	pan_cost.dt_said_cost = Far.UpTime
				end
			else	
				local	f_attr = win_GetFileAttr(path_file)
				if	f_attr
				then	
					local	is_dir = string_find(f_attr, "d") and true or false
					local 	is_lnk = string_find(f_attr, "e") and true or false
					local 	is_arc = string_find(f_attr, "a") and true or false
					if	is_dir 
					and not is_lnk
					then	found_cnt = 0
						local found_file, timed_out 
							= far_RecursiveSearch(path_file, '*.*', fnc_file_item_check, FRS_RECUR, dt_col_calc_start)
						col_dat[ii] =	timed_out	and "T" 
							or	found_file	and "" 
							or	found_cnt > 0	and "e" 
							or	"E"
					else 	local link_cnt = far_GetNumberOfLinks(path_file)
						col_dat[ii] = link_cnt > 1 and tostring(link_cnt) or ""
					end
					if not	col_dat[ii]
					or	col_dat[ii] == ""
						then	if	is_lnk
							then	col_dat[ii] = ">"
							elseif	is_arc 
							and not is_dir
							then	col_dat[ii] = "a"
							end
					end
				else
					col_dat[ii] = "?"
				end
				pan_cost.items_calc_cnt = pan_cost.items_calc_cnt + 1
				pan_cost.dt_calc = Far.UpTime
			end
		elseif 	
			the_col == "i2"
		then	
			-- probably we should use it as a status column...
		end
	end
	-- just to count panel items:
	pan_cost.items_cnt = pan_cost.items_cnt + 1
	-- last a single one item visited:
	pan_cost.dt_walk = Far.UpTime 
	-- add up the single item cost to total cost:
	pan_cost.cost = pan_cost.cost + (pan_cost.dt_walk - dt_col_calc_start) 
	return col_dat
end;
-- @@@ c0_v2
}

if not Far
then	for k, v in pairs(ContCol_v2) 
	do export[k] = v
	end
elseif	ContentColumns
then	ContentColumns(ContCol_v2)
end
if	USE_TIMER 
then	tmr_poll = far_Timer(POLL_INTERVAL, fnc_timer_poll, false, false, "T_")
end

Event { description = "FAR exit detection";
	group = "DialogEvent";
	action = function(evt, prm)
-- ###
if	evt	== DE_DLGPROCINIT
and	prm.Msg == DN_INITDIALOG 
then	local	dlg_info = prm.hDlg:send(DM_GETDIALOGINFO)
	if	dlg_info and win_Uuid(dlg_info.Id):upper() == FAR_EXIT_MSG_DLG_ID_TXT
	then	fnc_timer_poll(tmr_poll, false, true, "E_")
	end
end
-- @@@
	end
}

Event { description = "PanelChangeDir: Clean up timer on exit",
	group = "ExitFAR",
	action = function()
-- ###
if tmr_poll
then	if	tmr_poll.Enabled then tmr_poll.Enabled = false	end
	if not	tmr_poll.Closed	 then tmr_poll:Close()		end
	tmr_poll = nil
end
-- @@@
	end
}

Macro { description = "detect panel change";
	area = "Shell";
	key = "Tab Enter CtrlU CtrlF1 CtrlF2 CtrlPgUp CtrlPgDn";
	condition = function()
-- ###
if not (APanel.Visible or PPanel.Visible) then return end
far_Timer(5, function(sender) sender.Enabled = false; sender:Close(); fnc_eat_evt(nil, "M_") end)
return false;
-- @@@
	end;
	action = function()
	end
}

-- @@@@@
