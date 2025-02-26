local MPT = _G.MPT

MPT.inspectQueue = {}
MPT.inspectInProgress = false
MPT.pendingInspect = nil

function MPT:RequestInspect(unit, name)
	if CanInspect(unit) then
		table.insert(MPT.inspectQueue, { unit = unit, name = name })
		self.ProcessNextInspect()
	else
		MPT:Print("Error inspecting: " .. name)
	end
end

function MPT:ProcessNextInspect()
	if MPT.inspectInProgress or #MPT.inspectQueue == 0 then
		return
	end
	local nextInspect = table.remove(MPT.inspectQueue, 1)
	MPT.inspectInProgress = true
	C_Timer.After(1, function()
		if not CanInspect(nextInspect.unit) then
			MPT:Print("Unable to inspect: " .. nextInspect.name)
			MPT.inspectInProgress = false
			MPT:ProcessNextInspect()
			return
		end
		MPT:Print("Inspecting: " .. nextInspect.name)
		NotifyInspect(nextInspect.unit)
		MPT.pendingInspect = nextInspect.unit
		C_Timer.After(2, function()
			MPT.inspectInProgress = false
			MPT:ProcessNextInspect()
		end)
	end)
end

function MPT:OnInspectReady()
	if not MPT.pendingInspect then
		return
	end
	local unit = MPT.pendingInspect
	local specID = GetInspectSpecialization(unit)
	local specName = specID and GetSpecializationNameForSpecID(specID) or "Unknown"
	for _, member in ipairs(MPT.currentRun.party) do
		if string.find(member.name, GetUnitName(unit, true), 1, true) then
			member.spec = specName
			MPT:Print("Updated spec for " .. member.name .. " to " .. specName)
			break
		end
	end
	MPT.pendingInspect = nil
	MPT:UpdateUI()
end
