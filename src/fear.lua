-- Fear Level Announcement Module
-- Provides screen reader announcements for total Fear level in Shrine of the Unseen

---@module fear
local fear = {}

-- Announce the total Fear level via TOLK
-- Called from shrine upgrade functions to inform player of cumulative Fear
function fear.AnnounceTotalFear()
	if not rom.tolk then
		return
	end

	if not GetTotalSpentShrinePoints then
		return
	end

	local totalFear = GetTotalSpentShrinePoints()
	rom.tolk.output("Fear: " .. totalFear, true)
end

-- Hook this into AnnounceShrineUpgradeState to announce Fear after shrine changes
-- Usage: Call fear.AnnounceTotalFear() at the end of AnnounceShrineUpgradeState function
--
-- Example integration in reload.lua:
-- function AnnounceShrineUpgradeState(button)
--     -- ... existing shrine upgrade announcement code ...
--
--     -- Announce total Fear level
--     if fear and fear.AnnounceTotalFear then
--         fear.AnnounceTotalFear()
--     end
-- end

return fear
