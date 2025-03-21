local MPT = _G.MPT

MPT.inspectQueue = {}
MPT.inspectInProgress = false
MPT.pendingInspect = nil

function MPT:RequestInspect(unit, name)
	if CanInspect(unit) then
		table.insert(MPT.inspectQueue, { unit = unit, name = name })
		MPT:ProcessNextInspect()
	else
		print("Error inspecting: " .. name)
	end
end

function MPT:ProcessNextInspect()
	if MPT.inspectInProgress or #MPT.inspectQueue == 0 then return end
	local nextInspect = table.remove(MPT.inspectQueue, 1)
	MPT.inspectInProgress = true
	C_Timer.After(1, function()
		if not CanInspect(nextInspect.unit) then
			print("Unable to inspect: " .. nextInspect.name)
			MPT.inspectInProgress = false
			MPT:ProcessNextInspect()
			return
		end
		print("Inspecting: " .. nextInspect.name)
		NotifyInspect(nextInspect.unit)
		MPT.pendingInspect = nextInspect.unit
		C_Timer.After(2, function()
			MPT.inspectInProgress = false
			MPT:ProcessNextInspect()
		end)
	end)
end

function MPT:OnInspectReady()
	if not MPT.pendingInspect then return end
	local unit = MPT.pendingInspect
	local specID = GetInspectSpecialization(unit)
	local specName = specID and GetSpecializationNameForSpecID(specID) or "Unknown"
	local name = GetUnitName(unit, true)
	for _, roleKey in ipairs({ "tank", "healer", "dps1", "dps2", "dps3" }) do
		local member = MPT.currentRun[roleKey]
		if member and string.find(member.name, name, 1, true) then
			member.spec = specName
			print("Updated spec for " .. member.name .. " to " .. specName)
			break
		end
	end
	MPT.pendingInspect = nil
	MPT:UpdateUI()
end
