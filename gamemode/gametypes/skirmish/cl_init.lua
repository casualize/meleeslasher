net.Receive("ms_gt_skirmish_sync_gameinfo", function()
	GT_SKIRMISH.cl_tr_s = net.ReadUInt(8) -- red team score
	GT_SKIRMISH.cl_tb_s = net.ReadUInt(8) -- blue team score
	GT_SKIRMISH.cl_winning = net.ReadInt(8) -- which team won this round: 0 - timeout, -1 - don't tell, TEAM_WHATEVER - the team that won
	GT_SKIRMISH.cl_state = DEF_GT_SKIRMISH_STATES[net.ReadUInt(8)] -- state
	GT_SKIRMISH.cl_timeoutend = net.ReadFloat() -- next timeout end
	
	-- print(GT_SKIRMISH.cl_tr_s .. "-" .. GT_SKIRMISH.cl_tb_s .. " w-(" .. GT_SKIRMISH.cl_winning .. ") state=" .. GT_SKIRMISH.cl_state .. " nexttimer=" .. GT_SKIRMISH.cl_timeoutend)
end)