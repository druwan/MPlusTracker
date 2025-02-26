local MPT = _G.MPT

function MPT:Print(message, frameIndex)
	local chatFrame = _G["ChatFrame" .. frameIndex] or DEFAULT_CHAT_FRAME
	chatFrame:AddMessage("|cff1784d1MPT:|r " .. message)
end

function MPT:WriteRunToFile(lines)
	local file = io.open(MPT.Config.syncFile, "a")
	if not file then
		MPT:Print("Error opening sync file")
		return false
	end
	for _, line in ipairs(lines) do
		file:write(line .. "\n")
	end
	file:close()
	return true
end

function MPT:SerializeRun(run)
	local function escape(str)
		return '"' .. string.gsub(str or "", '"', '""') .. '"'
	end
	local function memberStr(member)
		return member and string.format("%s:%s:%s", member.name, member.class, member.spec or "") or ""
	end

	-- CSV: started, mapName, keyLvl, affixNames, completed, keyUpgradeLvl, numDeaths, timeLost, tank, healer, dps1, dps2, dps3,
	-- completionTime,oldOverallDungeonScore,newOverallDungeonScore,

	return string.format(
		"%s,%s,%d,%s,%s,%d,%d,%s,%s,%s,%s,%s,%d,%d,%d",
		escape(run.startTime),       -- %s
		escape(run.mapName),         --%s
		run.keyLvl,                  -- %d
		escape(run.affixNames),      --%s
		tostring(run.completed),     --%s
		run.keystoneUpgradeLevels,   --%d
		run.numDeaths,               --%d
		escape(run.timeLost),        --%s
		escape(memberStr(run.tank)), --%s
		escape(memberStr(run.healer)), --%s
		escape(memberStr(run.dps1)), --%s
		escape(memberStr(run.dps2)), --%s
		escape(memberStr(run.dps3)), --%s
		run.completionTime or 0,     --%d
		run.oldOverallDungeonScore,  --%d
		run.newOverallDungeonScore   --%d
	)
end
