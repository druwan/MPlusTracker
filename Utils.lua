local MPT = _G.MPT

-- Print Stats
function MPT:Print(message, frameIndex)
	local chatFrame = _G["ChatFrame" .. frameIndex] or DEFAULT_CHAT_FRAME
	chatFrame:AddMessage("|cff00FF00MPT:|r " .. message)
end
