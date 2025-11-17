-- Debug helper to test which controls work in which contexts
-- Outputs to TOLK when non-navigation/activation controls are pressed

local controlsToTest = {
	"Codex",
	"Gift",
	"AdvancedTooltip",
	"Shout",
	"Rush",
	"Inventory",
	"Assist",
	"LockOn",
	"Reload",
	"Cancel"
}

-- Function to get current context/location description
local function GetCurrentContext()
	local context = "unknown"

	-- Check for active screen
	if ActiveScreens and next(ActiveScreens) then
		for screenName, _ in pairs(ActiveScreens) do
			context = screenName
			break
		end
	end

	-- Check for current room/location
	if CurrentRun and CurrentRun.CurrentRoom then
		local roomName = CurrentRun.CurrentRoom.Name or "unnamed_room"
		if context == "unknown" then
			context = roomName
		else
			context = context .. "_" .. roomName
		end
	end

	-- Check if at arcana altar (MetaUpgrade screen)
	if ScreenAnchors and ScreenAnchors.MetaUpgradeScreen then
		context = "arcana_altar"
	end

	-- Check for other specific locations
	if MapState then
		if MapState.OfferedExitDoors and #MapState.OfferedExitDoors > 0 then
			if context == "unknown" then
				context = "room_with_exits"
			end
		end
	end

	return context
end

-- Debug function to announce control press
function DebugAnnounceControlPress(controlName)
	if not rom.tolk then return end

	local context = GetCurrentContext()
	local message = string.format("In %s: %s control activated", context, controlName)

	rom.tolk.output(message, true)
	print("[DEBUG] " .. message)
end

-- Register control listeners for all test controls
for _, controlName in ipairs(controlsToTest) do
	OnControlPressed { controlName, function(triggerArgs)
		-- Prevent spam from holding key
		if triggerArgs and triggerArgs.Repeat then return end

		DebugAnnounceControlPress(controlName)
	end }
end

print("[DEBUG] Control testing enabled for: " .. table.concat(controlsToTest, ", "))
