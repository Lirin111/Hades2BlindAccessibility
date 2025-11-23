---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- this file will be reloaded if it changes during gameplay,
-- 	so only assign to values or define things here.

-- Import the fear module for Fear level announcements
---@module 'fear'
fear = import 'fear.lua'

-- Fallback function in case CollapseTableOrderedByKeys doesn't exist
function CollapseTableOrderedByKeys(tableArg)
	if tableArg == nil then
		return {}
	end
	if CollapseTableOrdered then
		return CollapseTableOrdered(tableArg)
	end
	-- Fallback if CollapseTableOrdered doesn't exist either
	local collapsed = {}
	for k, v in pairs(tableArg) do
		table.insert(collapsed, v)
	end
	return collapsed
end

-- NumUseableObjects function replacement
function NumUseableObjects(objects)
	local count = 0
	if objects ~= nil then
		for k, v in pairs(objects) do
			if IsUseable({ Id = v.ObjectId }) then
				count = count + 1
			end
		end
	end
	return count
end

-- HP tracking variables for audio notifications
-- Initialize tracking variables
lastHPPercentage = 100
hpThresholdsPlayed = {}

-- Boss/Mini-boss tracking
bossHealthTracking = {}

-- HP thresholds that trigger sounds (in descending order)
local hpThresholds = {100, 90, 80, 70, 60, 50, 40, 30, 20, 10}

-- Function to check and announce HP thresholds using TOLK
function CheckAndPlayHPSound()
	print("CheckAndPlayHPSound called")

	-- Check if player HP announcements are enabled (default to true if config not available)
	if config and config.AnnouncePlayerHP == false then
		print("HP announcements disabled by config")
		return
	end

	-- Safety checks
	if not CurrentRun or not CurrentRun.Hero then
		print("CurrentRun or Hero not available")
		return
	end

	local hero = CurrentRun.Hero
	if not hero.Health or not hero.MaxHealth or hero.MaxHealth == 0 then
		print("Hero health data not available")
		return
	end

	-- Calculate current HP percentage
	local currentHPPercentage = math.floor((hero.Health / hero.MaxHealth) * 100)
	print("Current HP: " .. currentHPPercentage .. "%, Last HP: " .. tostring(lastHPPercentage))

	-- Initialize lastHPPercentage if not set
	if not lastHPPercentage then
		lastHPPercentage = currentHPPercentage
		hpThresholdsPlayed = {}
		print("Initialized HP tracking at " .. currentHPPercentage .. "%")
		return
	end

	-- Check each threshold
	for _, threshold in ipairs(hpThresholds) do
		-- If we've crossed this threshold downward and haven't played it yet
		if currentHPPercentage <= threshold and lastHPPercentage > threshold then
			-- Mark this threshold as played
			if not hpThresholdsPlayed[threshold] then
				hpThresholdsPlayed[threshold] = true
				print("HP threshold crossed: " .. threshold .. "%")

				-- Use TOLK to announce the HP percentage via screen reader
				if rom and rom.tolk and rom.tolk.output then
					print("Announcing via TOLK: Health " .. threshold .. " percent")
					rom.tolk.output("Health " .. threshold .. " percent", true)
				else
					print("TOLK not available!")
				end

				-- Sound removed to prevent FMOD crash during boss fights
				-- PlaySound({ Name = "/SFX/Player Sounds/PlayerTakeDamageShieldBreak" })

				break -- Only announce one threshold per damage event
			end
		-- If HP increases above a threshold, reset that threshold
		elseif currentHPPercentage > threshold and hpThresholdsPlayed[threshold] then
			hpThresholdsPlayed[threshold] = nil
		end
	end

	-- Update last HP percentage
	lastHPPercentage = currentHPPercentage
end

-- Function to check and announce boss/mini-boss HP
function CheckBossHealth(enemy)
	print("CheckBossHealth called")

	-- Safety checks
	if not enemy or not enemy.ObjectId then
		print("Enemy or ObjectId not available")
		return
	end

	-- Only track bosses and elites
	if not (enemy.IsBoss or enemy.IsElite) then
		return
	end

	print("Enemy is Boss: " .. tostring(enemy.IsBoss) .. ", Elite: " .. tostring(enemy.IsElite))

	-- Skip if enemy has no health or max health
	if not enemy.Health or not enemy.MaxHealth or enemy.MaxHealth == 0 then
		print("Enemy health data not available")
		return
	end

	-- Distinguish between actual mini-bosses and regular elite enemies
	-- Regular enemies typically have MaxHealth < 1000, mini-bosses have significantly more
	local isActualMiniBoss = false
	if enemy.IsElite and not enemy.IsBoss then
		-- Check if this is a true mini-boss based on health threshold
		-- Mini-bosses typically have 1000+ MaxHealth, regular elites have less
		if enemy.MaxHealth >= 1000 then
			isActualMiniBoss = true
			print("Detected mini-boss with MaxHealth: " .. enemy.MaxHealth)
		else
			-- This is just a regular elite enemy, not a mini-boss, skip it
			print("Skipping regular elite with MaxHealth: " .. enemy.MaxHealth)
			return
		end
	end

	-- Check if boss/mini-boss HP announcements are enabled based on enemy type (default to true if config not available)
	if enemy.IsBoss and config and config.AnnounceBossHP == false then
		print("Boss HP announcements disabled by config")
		return
	end
	if isActualMiniBoss and config and config.AnnounceMiniBossHP == false then
		print("Mini-boss HP announcements disabled by config")
		return
	end

	-- If enemy is dead, clean up and return
	if enemy.Health <= 0 then
		CleanupBossTracking(enemy)
		return
	end

	-- Calculate current HP percentage
	local currentHPPercentage = math.floor((enemy.Health / enemy.MaxHealth) * 100)
	print("Boss/Enemy HP: " .. currentHPPercentage .. "%")

	-- Get or create tracking data for this enemy
	local trackingKey = tostring(enemy.ObjectId)
	if not bossHealthTracking[trackingKey] then
		bossHealthTracking[trackingKey] = {
			lastHP = 100,
			thresholdsPlayed = {},
			name = enemy.Name or "Unknown",
			isBoss = enemy.IsBoss or false,
			isMiniBoss = isActualMiniBoss
		}
		print("Initialized boss tracking for: " .. (enemy.Name or "Unknown"))
	end

	local tracking = bossHealthTracking[trackingKey]

	-- Check each threshold
	for _, threshold in ipairs(hpThresholds) do
		-- If enemy HP crossed this threshold downward and hasn't been announced
		if currentHPPercentage <= threshold and tracking.lastHP > threshold then
			if not tracking.thresholdsPlayed[threshold] then
				tracking.thresholdsPlayed[threshold] = true

				-- Get enemy type for announcement
				local enemyType = "Enemy"
				if tracking.isBoss then
					enemyType = "Boss"
				elseif tracking.isMiniBoss then
					enemyType = "Mini-boss"
				end

				print("Boss HP threshold crossed: " .. threshold .. "%")

				-- Announce via TOLK
				if rom and rom.tolk and rom.tolk.output then
					print("Announcing via TOLK: " .. enemyType .. " " .. threshold .. " percent")
					rom.tolk.output(enemyType .. " " .. threshold .. " percent", true)
				else
					print("TOLK not available!")
				end

				-- Sound removed to prevent FMOD crash during boss fights
				-- PlaySound({ Name = "/SFX/Player Sounds/PlayerTakeDamageShieldBreak" })

				break -- Only announce one threshold per damage event
			end
		-- Reset threshold if HP increases
		elseif currentHPPercentage > threshold and tracking.thresholdsPlayed[threshold] then
			tracking.thresholdsPlayed[threshold] = nil
		end
	end

	-- Update last HP
	tracking.lastHP = currentHPPercentage
end

-- Clean up tracking for dead enemies
function CleanupBossTracking(enemy)
	if enemy and enemy.ObjectId then
		local trackingKey = tostring(enemy.ObjectId)
		bossHealthTracking[trackingKey] = nil
	end
end

function wrap_InventoryScreenDisplayCategory(screen, categoryIndex, args)
	args = args or {}

	-- Ensure proper navigation settings for inventory/planting screen
	-- Reset any settings that might have been changed by other menus
	SetConfigOption({ Name = "FreeFormSelectWrapY", Value = true })

	local components = screen.Components
	local category = screen.ItemCategories[categoryIndex]
	if category.Locked then
		return
	end
	if category.OpenFunctionName ~= nil then
		return
	end
	local slotName = category.Name

	for i, resourceName in ipairs(category) do
		local resourceData = ResourceData[resourceName]
		--mod menu
		if not resourceData then
			goto continue
		end
		if CanShowResourceInInventory( resourceData ) then
			local textLines = nil
			local wantsToBeGifted = false
			local canBeGifted = false
			local wantsToBePlanted = 0 --0 for not a plant, 1 for a plant but not plantable, 2 for yes but not enough resources, 3 for yes
			if screen.Args.PlantTarget ~= nil then
				wantsToBePlanted = 1
				if GardenData.Seeds[resourceName] then
					wantsToBePlanted = 2
					if HasResource(resourceName, 1) then
						wantsToBePlanted = 3
					end
				end
			elseif screen.Args.GiftTarget ~= nil then
				wantsToBeGifted = true
				if screen.Args.GiftTarget.UnlimitedGifts ~= nil and screen.Args.GiftTarget.UnlimitedGifts[resourceName] then
					canBeGifted = true
				else
					local spending = {}
					spending[resourceName] = 1
					textLines = GetRandomEligibleTextLines(screen.Args.GiftTarget,
						screen.Args.GiftTarget.GiftTextLineSets,
						GetNarrativeDataValue(screen.Args.GiftTarget, "GiftTextLinePriorities"), { Spending = spending })
					if textLines ~= nil then
						canBeGifted = true
					end
				end
			end

			local button = components[resourceName]

			local statusText = ""
			if wantsToBeGifted then
				statusText = GetDisplayName({ Text = "Menu_Gift", IgnoreSpecialFormatting = true }) .. ": "
				if canBeGifted then
					statusText = statusText .. GetDisplayName({ Text = "ExitConfirm_Confirm", IgnoreSpecialFormatting = true })
				else
					statusText = statusText ..
					GetDisplayName({ Text = "InventoryScreen_GiftNotWanted", IgnoreSpecialFormatting = true })
				end
				statusText = statusText .. ", "
			elseif wantsToBePlanted ~= 0 then
				statusText = GetDisplayName({ Text = "Menu_Plant", IgnoreSpecialFormatting = true }) .. ": "
				if wantsToBePlanted == 1 then
					statusText = statusText ..
					GetDisplayName({ Text = "InventoryScreen_SeedNotWanted", IgnoreSpecialFormatting = true })
				elseif wantsToBePlanted == 2 then
					statusText = statusText ..
					GetDisplayName({ Text = "InventoryScreen_GiftNotAvailable", IgnoreSpecialFormatting = true })
				elseif wantsToBePlanted == 3 then
					statusText = statusText .. GetDisplayName({ Text = "ExitConfirm_Confirm", IgnoreSpecialFormatting = true })
				end
				statusText = statusText .. ", "
			end

			-- Create the main text box with name, amount, and status
			ModifyTextBox({
				Id = button.Id, Text = GetDisplayName({ Text = resourceName, IgnoreSpecialFormatting = true }) .. ": " .. (GameState.Resources[resourceName] or 0) .. ", " .. statusText, UseDescription = false
		})

		-- Add invisible description text for screen reader
		CreateTextBox({
			Id = button.Id,
			Text = resourceName,
			UseDescription = true,
			Color = Color.Transparent,
		})

		-- Add invisible details text for screen reader (location sources)
		local detailsKey = resourceName .. "_Details"
		CreateTextBox({
			Id = button.Id,
			Text = detailsKey,
			UseDescription = true,
			Color = Color.Transparent,
		})

		-- Add invisible extra details text for screen reader (NPC offerings, etc.) - only if it exists
		local extraDetailsKey = resourceName .. "_ExtraDetails1"
		local extraDetailsText = GetDisplayName({ Text = extraDetailsKey })
		if extraDetailsText ~= nil and extraDetailsText ~= extraDetailsKey then
			CreateTextBox({
				Id = button.Id,
				Text = extraDetailsKey,
				UseDescription = true,
				Color = Color.Transparent,
			})
		end

		-- Add invisible flavor text for screen reader
		local flavorKey = resourceName .. "_Flavor"
		CreateTextBox({
			Id = button.Id,
			Text = flavorKey,
			UseDescription = true,
			Color = Color.Transparent,
		})
		end
		::continue::
	end
end

function OnInventoryPress()
	if not IsScreenOpen("TraitTrayScreen") then
		return
	end

	-- Check if we're in Asphodel (has CapturePointSwitch)
	local hasAsphodelExit = false
	local capturePointIds = GetIdsByType({ Name = "CapturePointSwitch" })
	if capturePointIds and #capturePointIds > 0 then
		for _, id in ipairs(capturePointIds) do
			if IsUseable({ Id = id }) then
				hasAsphodelExit = true
				break
			end
		end
	end

	-- Check if we're in Tartarus, Olympus, or Surface
	local curMap = GetMapName()
	local inTartarus = curMap and curMap:find("I_") == 1
	local inOlympus = curMap and curMap:find("P_") == 1
	local inSurface = curMap and curMap:find("F_") == 1

	-- Don't return early if we're in Tartarus, Olympus, or Surface (allow menu to open even without doors)
	if TableLength(MapState.OfferedExitDoors) == 0 and GetMapName() ~= "Hub_Main" and not hasAsphodelExit and not inTartarus and not inOlympus and not inSurface then
		return
	elseif TableLength(MapState.OfferedExitDoors) == 1 and string.find(GetMapName(), "D_Hub") then
		finalBossDoor = CollapseTable(MapState.OfferedExitDoors)[1]
		if finalBossDoor.Room.Name:find("D_Boss", 1, true) == 1 and GetDistance({ Id = 547487, DestinationId = 551569 }) ~= 0 then
			return
		end
	end
	if IsScreenOpen("TraitTrayScreen") then
		if CurrentRun.CurrentRoom.ExitsUnlocked then
			TraitTrayScreenClose(ActiveScreens.TraitTrayScreen)
			OpenAssesDoorShowerMenu(CollapseTable(MapState.OfferedExitDoors))
		elseif MapState.ShipWheels then
			TraitTrayScreenClose(ActiveScreens.TraitTrayScreen)
			OpenAssesDoorShowerMenu(CollapseTable(MapState.ShipWheels))
		elseif hasAsphodelExit then
			-- Open menu for Asphodel with empty doors list, will be populated by AddAsphodelExit
			TraitTrayScreenClose(ActiveScreens.TraitTrayScreen)
			OpenAssesDoorShowerMenu({})
		elseif inTartarus or inOlympus or inSurface then
			-- Open menu for Tartarus/Olympus/Surface even without doors unlocked (works like Crossroads)
			TraitTrayScreenClose(ActiveScreens.TraitTrayScreen)
			OpenAssesDoorShowerMenu(CollapseTable(MapState.OfferedExitDoors))
		end
	end
end

function OpenAssesDoorShowerMenu(doors)
	local curMap = GetMapName()
	local screen = DeepCopyTable(ScreenData.BlindAccesibilityDoorMenu)

	if IsScreenOpen(screen.Name) then
		return
	end
	OnScreenOpened(screen)
	if ShowingCombatUI then
		HideCombatUI(screen.Name)
	end
	-- FreezePlayerUnit()
	SetConfigOption({ Name = "FreeFormSelectWrapY", Value = false })
	SetConfigOption({ Name = "FreeFormSelectStepDistance", Value = 8 })
	SetConfigOption({ Name = "FreeFormSelectSuccessDistanceStep", Value = 8 })
	SetConfigOption({ Name = "FreeFormSelectRepeatDelay", Value = 0.6 })
	SetConfigOption({ Name = "FreeFormSelectRepeatInterval", Value = 0.1 })
	SetConfigOption({ Name = "FreeFormSelecSearchFromId", Value = 0 })

	PlaySound({ Name = "/SFX/Menu Sounds/BrokerMenuOpen" })
	local components = screen.Components

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Asses_UI" })

	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Asses_UI_Backing", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackgroundDim.Id, OffsetX = 0, OffsetY = 440 })
	components.CloseButton.OnPressedFunctionName = "BlindAccessCloseAssesDoorShowerScreen"
	components.CloseButton.ControlHotkeys        = { "Cancel" }
	components.CloseButton.MouseControlHotkeys   = { "Cancel" }

	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = { 0, 0, 0, 1 } })

	-- Add points of interest (NPCs, inspect points, wells, etc.) to the doors list
	local pointsOfInterest = ProcessTable({})
	local allInteractables = ShallowCopyTable(doors)
	for _, poi in ipairs(pointsOfInterest) do
		table.insert(allInteractables, poi)
	end

	CreateAssesDoorButtons(screen, allInteractables)
	screen.KeepOpen = true
	-- thread( HandleWASDInput, screen )
	HandleScreenInput(screen)
	SetConfigOption({ Name = "ExclusiveInteractGroup", Value = "Asses_UI" })
end

function GetMapName()
	-- Add nil checks for CurrentRun to prevent crashes when interacting with certain NPCs/areas
	if CurrentRun ~= nil and CurrentRun.Hero ~= nil and CurrentRun.Hero.IsDead and CurrentHubRoom ~= nil then
		return CurrentHubRoom.Name
	elseif CurrentRun ~= nil and CurrentRun.CurrentRoom ~= nil then
		return CurrentRun.CurrentRoom.Name
	end
	return nil
end

function CreateAssesDoorButtons(screen, doors)
	local startX = 960
	local startY = 150
	local yIncrement = 75
	local curX = startX
	local curY = startY
	local components = screen.Components
	local isFirstButton = true

	local inCityHub = GetMapName() == "N_Hub"
	local inCityRoom = GetMapName():find("N_") == 1 and not inCityHub
	local inShip = GetMapName():find("O_") == 1
	local inTartarus = GetMapName():find("I_") == 1
	local inOlympus = GetMapName():find("P_") == 1
	local inSurface = GetMapName():find("F_") == 1
	if inCityHub then
		curX = 500
		local doorSortValue = function(door)
			local v = GetDisplayName({ Text = getDoorSound(door, false):gsub("Room", ""), IgnoreSpecialFormatting = true })
			if v:find(" ") == 1 then
				v = v:sub(2)
			end
			return v
		end
		table.sort(doors, function(a, b) return doorSortValue(a) < doorSortValue(b) end)
	end

	local healthKey = "AssesResourceMenuInformationHealth"
	components[healthKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[healthKey].Id, Table = components[healthKey] })

	CreateTextBox({
		Id = components[healthKey].Id,
		Text = GetDisplayName({ Text = "Health", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0),
		FontSize = 24,
		OffsetX = -100,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement

	local armorKey = "AssesResourceMenuInformationArmor"
	components[armorKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[armorKey].Id, Table = components[armorKey] })
	CreateTextBox({
		Id = components[armorKey].Id,
		Text = GetDisplayName({ Text = "Armor", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.HealthBuffer or 0),
		FontSize = 24,
		OffsetX = -100,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement

	local goldKey = "AssesResourceMenuInformationGold"
	components[goldKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[goldKey].Id, Table = components[goldKey] })
	CreateTextBox({
		Id = components[goldKey].Id,
		Text = GetDisplayName({ Text = "Money", IgnoreSpecialFormatting = true }) .. ": " .. (GameState.Resources["Money"] or 0),
		FontSize = 24,
		OffsetX = -100,
		-- OffsetY = yIncrement * 2,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement

	local manaKey = "AssesResourceMenuInformationMana"
	components[manaKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[manaKey].Id, Table = components[manaKey] })
	CreateTextBox({
		Id = components[manaKey].Id,
		Text = GetDisplayName({ Text = "Mana", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.Mana or 0) .. "/" .. (CurrentRun.Hero.MaxMana or 0),
		FontSize = 24,
		OffsetX = -100,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement

	local deathDefianceKey = "AssesResourceMenuInformationDeathDefiance"
	components[deathDefianceKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[deathDefianceKey].Id, Table = components[deathDefianceKey] })
	local deathDefianceCount = 0
	if CurrentRun.Hero.LastStands then
		for i, v in pairs(CurrentRun.Hero.LastStands) do
			deathDefianceCount = deathDefianceCount + 1
		end
	end
	CreateTextBox({
		Id = components[deathDefianceKey].Id,
		Text = GetDisplayName({ Text = "ExtraChance", IgnoreSpecialFormatting = true }) .. ": " .. deathDefianceCount,
		FontSize = 24,
		OffsetX = -100,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement + 30
	for k, door in pairs(doors) do
		local showDoor = true
		local isPOI = (door.Room == nil) -- POI objects don't have a Room property

		if string.find(GetMapName(), "D_Hub") and not isPOI then
			if door.Room and door.Room.Name:find("D_Boss", 1, true) == 1 and GetDistance({ Id = 547487, DestinationId = 551569 }) ~= 0 then
				showDoor = false
			end
		end
		if showDoor then
			local displayText = ""

			-- Handle POI objects (NPCs, inspect points, wells, etc.)
			if isPOI then
				displayText = door.Name or "Unknown"
			elseif inShip then
				if door.Name == "ShipsExitDoor" or door.Name == "ShipsPostBossDoor" then
					if door.RewardPreviewAnimName == "ShopPreview" then
						displayText = GetDisplayName({ Text = "UseStore", IgnoreSpecialFormatting = true })
					else
						displayText = displayText ..
						GetDisplayName({ Text = getDoorSound(door, false), IgnoreSpecialFormatting = true })
					end
				else
					displayText = GetDisplayName({ Text = door.ChosenRewardType, IgnoreSpecialFormatting = true })
				end
			elseif inCityRoom then
				if door.Name == "EphyraExitDoorReturn" or door.ReturnToPreviousRoomName == "N_Hub" then
					displayText = GetDisplayName({ Text = "BiomeN", IgnoreSpecialFormatting = true })
				else
					displayText = GetDisplayName({ Text = "RoomAlt", IgnoreSpecialFormatting = true })
				end
			else
				if door.Room.ChosenRewardType == "Devotion" then
					displayText = displayText ..
					GetDisplayName({ Text = getDoorSound(door, false), IgnoreSpecialFormatting = true }) .. " "
					displayText = displayText ..
					GetDisplayName({ Text = getDoorSound(door, true), IgnoreSpecialFormatting = true })
				else
					displayText = displayText ..
					GetDisplayName({ Text = getDoorSound(door, false), IgnoreSpecialFormatting = true })
				end

				if door.Name == "FieldsExitDoor" and door.Room.CageRewards then
					displayText = ""
					for k, reward in pairs(door.Room.CageRewards) do
						displayText = displayText ..
						GetDisplayName({ Text = reward.RewardType:gsub("Room", ""), IgnoreSpecialFormatting = true }) ..
						", "
					end
					displayText = displayText:sub(0, -3)
				else
					if displayText == "ElementalBoost" then
						displayText = "Boon_Infusion"
					end
					displayText = GetDisplayName({ Text = displayText:gsub("Room", ""):gsub("Drop", ""), IgnoreSpecialFormatting = true })
				end

				if displayText == "ClockworkGoal" and CurrentRun.RemainingClockworkGoals then
					displayText = GetDisplayName({ Text = "ChamberMoverUsed", IgnoreSpecialFormatting = true }) ..
					" " .. CurrentRun.RemainingClockworkGoals
				end

				local args = { RoomData = door.Room }
				local rewardOverrides = args.RoomData.RewardOverrides or {}
				local encounterData = args.RoomData.Encounter or {}
				local previewIcon = rewardOverrides.RewardPreviewIcon or encounterData.RewardPreviewIcon or
					args.RoomData.RewardPreviewIcon

				-- Check for boss/miniboss/elite indicators
				if previewIcon ~= nil then
					if previewIcon == "RoomRewardSubIcon_Boss" then
						displayText = displayText .. " (Boss)"
					elseif previewIcon == "RoomRewardSubIcon_Miniboss" then
						displayText = displayText .. " (Mini-Boss)"
					elseif string.find(previewIcon, "Elite") then
						-- Legacy support for Elite preview icons
						if previewIcon == "RoomElitePreview4" then
							displayText = displayText .. " (Boss)"
						elseif previewIcon == "RoomElitePreview2" then
							displayText = displayText .. " (Mini-Boss)"
						elseif previewIcon == "RoomElitePreview3" then
							if not string.find(displayText, "(Infernal Gate)") then
								displayText = displayText .. " (Infernal Gate)"
							end
						else
							displayText = displayText .. " (Elite)"
						end
					end
				end

				-- Check for Infernal Gate (Challenge encounter)
				if door.Room.Encounter and door.Room.Encounter.EncounterType == "Challenge" then
					if not string.find(displayText, "(Infernal Gate)") then
						displayText = displayText .. " (Infernal Gate)"
					end
				end
				if door.HealthCost and door.HealthCost ~= 0 then
					displayText = displayText .. " -" .. door.HealthCost .. "{!Icons.Health}"
				end
				if door.EncounterCost ~= nil then
					displayText = displayText .. " (Sealed)"
				end
			end
			local buttonKey = "AssesResourceMenuButton" .. k

			components[buttonKey] =
				CreateScreenComponent({
					Name = "ButtonDefault",
					Group = "Asses_UI",
					Scale = 0.8,
					X = curX,
					Y = curY
				})
			SetScaleX({ Id = components[buttonKey].Id, Fraction = 1 })
			components[buttonKey].OnPressedFunctionName = "BlindAccessAssesDoorMenuSoundSet"
			components[buttonKey].door = door
			AttachLua({ Id = components[buttonKey].Id, Table = components[buttonKey] })
			-- components[buttonKey].OnMouseOverFunctionName = "MouseOver"
			--Attach({ Id = components[buttonKey].Id, DestinationId = components.ShopBackgroundDim.Id, OffsetX = xPos, OffsetY = curY })

			CreateTextBox({
				Id = components[buttonKey].Id,
				Text = displayText,
				FontSize = 24,
				OffsetX = 0,
				OffsetY = 0,
				Color = Color.White,
				Font = "P22UndergroundSCMedium",
				Group = "Asses_UI",
				ShadowBlur = 0,
				ShadowColor = { 0, 0, 0, 1 },
				ShadowOffset = { 0, 2 },
				Justification = "Center",
			})

			if isFirstButton then
				TeleportCursor({ OffsetX = curX + 300, OffsetY = curY })
				wait(0.2)
				TeleportCursor({ OffsetX = curX, OffsetY = curY })
				isFirstButton = false
			end
			curY = curY + yIncrement
			-- Support unlimited columns by wrapping to a new column when Y exceeds limit
			if curY > 900 then
				curY = startY + yIncrement * 3 + 30
				curX = curX + 250
			end
		end
	end
end

function rom.game.BlindAccessCloseAssesDoorShowerScreen(screen, button)
	-- Reset config options back to defaults to prevent affecting other menus
	SetConfigOption({ Name = "ExclusiveInteractGroup", Value = nil })
	SetConfigOption({ Name = "FreeFormSelectWrapY", Value = true })
	OnScreenCloseStarted(screen)
	CloseScreen(GetAllIds(screen.Components), 0.15)
	OnScreenCloseFinished(screen)
	notifyExistingWaiters(screen.Name)
	ShowCombatUI(screen.Name)
end

function rom.game.BlindAccessAssesDoorMenuSoundSet(screen, button)
	PlaySound({ Name = "/SFX/Menu Sounds/ContractorItemPurchase" })
	rom.game.BlindAccessCloseAssesDoorShowerScreen(screen, button)
	if button.door then
		doDefaultSound(button.door)
	end
end

function doDefaultSound(door)
	local offsetX = door.DestinationOffsetX or 0
	local offsetY = door.DestinationOffsetY or 0

	-- If no specific offset is set, use better defaults
	if offsetX == 0 and offsetY == 0 then
		offsetY = -120 -- Stand in front of doors by default
		offsetX = 0    -- Centered
	end

	-- Special cases for specific doors
	if door.Name == "ChronosBossDoor" then
		offsetX = 200
		offsetY = -140
	elseif door.Name and door.Name:find("Exit") then
		offsetY = 50 -- Further back for exit doors
	elseif door.Name and door.Name:find("N_SubRoom") then
		offsetY = 250 -- For sub rooms in Ephyra
	elseif door.Name and door.Name:find("Shop") then
		offsetY = -100 -- Good distance for shop doors
	end

	Teleport({ Id = CurrentRun.Hero.ObjectId, DestinationId = door.ObjectId, OffsetX = offsetX, OffsetY = offsetY })
end

function getDoorSound(door, devotionSlot)
	local room = door.Room
	if not room then
		return "Unknown"
	end
	if GetMapName():find("O_") == 1 then
		return "MetaUpgrade_UpgradesAvailable_Close"
	elseif door.Room.Name == "FinalBossExitDoor" or door.Room.Name == "E_Intro" then
		return "Greece"
	elseif room.NextRoomSet and room.Name:find("D_Boss", 1, true) ~= 1 then
		return "Stairway"
	elseif room.Name:find("_Intro", 1, true) ~= nil then
		local i = room.Name:find("_Intro", 1, true)
		local prefix = room.Name:sub(1, i - 1)
		return "Biome" .. prefix
	elseif HasHeroTraitValue("HiddenRoomReward") then
		return "ChaosHiddenRoomRewardCurse"
	elseif room.ChosenRewardType == nil then
		return "ChaosHiddenRoomRewardCurse"
	elseif room.ChosenRewardType == "Boon" and room.ForceLootName then
		if LootData[room.ForceLootName].DoorIcon ~= nil then
			local godName = LootData[room.ForceLootName].DoorIcon
			godName = godName:gsub("BoonDrop", "")
			godName = godName:gsub("Preview", "Upgrade")
			if door.Name == "ShrinePointDoor" then
				godName = godName .. " (Infernal Gate)"
			end
			return godName
		end
	elseif room.ChosenRewardType == "Devotion" then
		local devotionLootName = room.Encounter.LootAName
		if devotionSlot == true then
			devotionLootName = room.Encounter.LootBName
		end
		devotionLootName = devotionLootName:gsub("Progress", ""):gsub("Drop", ""):gsub("Run", ""):gsub("Upgrade", "")
		return devotionLootName
	else
		local resourceName = room.ChosenRewardType --:gsub("Progress", ""):gsub("Drop", ""):gsub("Run", "")
		if door.Name == "ShrinePointDoor" then
			resourceName = resourceName .. " (Infernal Gate)"
		end
		return resourceName
	end
end

local mapPointsOfInterest = {
	Hub_Main = {
		AddNPCs = true,
		SetupFunction = function(t)
			local copy = ShallowCopyTable(t)
			local name = ""
			local objectId = nil
			for k, plot in pairs(GameState.GardenPlots) do
				if plot.GrowTimeRemaining == 0 then
					objectId = plot.ObjectId
					if plot.StoredGrows and plot.StoredGrows > 0 then
						name = GetDisplayName({ Text = "GardenPlots", IgnoreSpecialFormatting = true }) ..
						" - Harvestable"
						break
					else
						name = GetDisplayName({ Text = "GardenPlots", IgnoreSpecialFormatting = true }) .. " - Plantable"
					end
				end
			end
			if name ~= "" then
				table.insert(copy, { Name = name, ObjectId = objectId, DestinationOffsetX = 100 })
			end

			-- Add rubbish piles (Eris's trash) if they exist
			local rubbishIds = GetIdsByType({ Name = "TrashPointsDrop" })
			if rubbishIds then
				for i, rubbishId in ipairs(rubbishIds) do
					if IsUseable({ Id = rubbishId }) then
						local rubbishName = GetDisplayName({ Text = "TrashPoints", IgnoreSpecialFormatting = true })
						if rubbishName == "TrashPoints" then
							-- If translation doesn't exist, use a fallback
							rubbishName = "Rubbish"
						end
						table.insert(copy, { Name = rubbishName .. " " .. i, ObjectId = rubbishId })
					end
				end
			end

			-- Add lore interactables (InspectPoints) for Crossroads
			copy = AddInspectPoints(copy)
			return copy
		end,
		Objects = {
			{ Name = "QuestLog_Unlocked_Subtitle", ObjectId = 560662, DestinationOffsetY = -120 },
			{ Name = "GhostAdminScreen_Title",     ObjectId = 567390, DestinationOffsetY = 137, RequireUseable = false },
			{ Name = "Broker",                     ObjectId = 558096, DestinationOffsetX = 140, DestinationOffsetY = 35 },
			{ Name = "MailboxScreen_Title",                ObjectId = 583652, DestinationOffsetX = 117, DestinationOffsetY = -64 }, --No direct translation in sjson
			{ Name = "Training Ground",            ObjectId = 587947, RequireUseable = false } --No direct translation in sjson
			--we're cheating a little here as this is the telport to the stair object in the loading zone, as every once in a while the actual loading zone has not been found
		}
	},
	Hub_PreRun = {
		AddNPCs = true,
		SetupFunction = function(t)
			local copy = ShallowCopyTable(t)
			for index, weaponName in ipairs(WeaponSets.HeroPrimaryWeapons) do
				local suffix = ""
				if IsBonusUnusedWeapon(weaponName) then
					suffix = " - " .. GetDisplayName({ Text = "UnusedWeaponBonusTrait", IgnoreSpecialFormatting = true })
				end
				if IsUseable({ Id = MapState.WeaponKitIds[index] }) then
					table.insert(copy,
						{ Name = GetDisplayName({ Text = "WeaponSet" }) ..
						" " .. GetDisplayName({ Text = weaponName }) .. suffix, ObjectId = MapState.WeaponKitIds[index] })
				end
			end

			-- Tools system was reworked in Hades II 1.0 - ToolOrderData and ToolKitIds no longer exist
			-- Tool interactions are now handled differently and don't need explicit teleportation
			if ToolOrderData and MapState.ToolKitIds then
				for index, toolName in ipairs(ToolOrderData) do
					local kitId = MapState.ToolKitIds[index]
					if IsUseable({ Id = kitId }) then
						table.insert(copy,
							{ Name = GetDisplayName({ Text = "Tool", IgnoreSpecialFormatting = true }) ..
							" " .. GetDisplayName({ Text = toolName, IgnoreSpecialFormatting = true }), ObjectId = kitId })
					end
				end
			end
			-- Add lore interactables (InspectPoints) for pre-run area
			copy = AddInspectPoints(copy)
			return copy
		end,
		Objects = {
			{ Name = "TraitTray_Category_MetaUpgrades", ObjectId = 587228, RequireUseable = false },
			{ Name = "WeaponShop",                      ObjectId = 558210, RequireUseable = false },
			{ Name = "BountyBoard",                     ObjectId = 561146, DestinationOffsetX = -17, DestinationOffsetY = 82 },
			{ Name = "Keepsakes",                       ObjectId = 421320, DestinationOffsetX = 119, DestinationOffsetY = 30 },
			{ Name = "BiomeF",                          ObjectId = 587938, DestinationOffsetX = 263, DestinationOffsetY = -293, RequireUseable = false },
			{ Name = "BiomeN",                          ObjectId = 587935, DestinationOffsetX = -162, DestinationOffsetY = 194, RequireUseable = false },
			{ Name = "Shrine",                      ObjectId = 589694, DestinationOffsetY = 90 },
			{ Name = "Hub",                             ObjectId = 588689, RequireUseable = false },
		}
	},
	Flashback_DeathAreaBedroomHades = {
		InFlashback = true,
		Objects = {
			{ Name = "BiomeHouse",                      ObjectId = 487893, RequireUseable = false }
		}
	},
	Flashback_DeathArea = {
		InFlashback = true,
		Objects = {
			{ Name = "CharNyx",                      ObjectId = 370010, RequireUseable = true, DestinationOffsetX = 100, DestinationOffsetY = 100 }
		},
		SetupFunction = function(t)
			if not IsUseable({ Id = 370010 }) then
				t = AddNPCs(t)
			end
			-- Add lore interactables for flashback area
			t = AddInspectPoints(t)
			return t
		end
	},
	Flashback_Hub_Main = {
		InFlashback = true,
		Objects = {
			{ Name = "Speaker_Homer",                      ObjectId = 583651, RequireUseable = true, DestinationOffsetX = 100, DestinationOffsetY = 100 }
		},
		SetupFunction = function(t)
			if not IsUseable({ Id = 583651 }) then
				t = AddNPCs(t)
			end
			for k,v in pairs(t) do
				DebugPrintTable(v)
				if v.Name == "Hecate" then
					v.DestinationOffsetY = 50
					print(GetDistance({Id = v.ObjectId, DestinationId = 558435}))
					if GetDistance({Id = v.ObjectId, DestinationId = 558435}) < 400 then
						v.DestinationOffsetX = 50
					else
						v.DestinationOffsetX = -50
					end
				end
			end
			-- Add lore interactables for flashback hub
			t = AddInspectPoints(t)
			return t
		end
	},
	-- Tartarus biome rooms (I_ prefix)
	["I_*"] = {
		AddNPCs = true,
		SetupFunction = function(t)
			-- Add lore interactables (InspectPoints) for Tartarus rooms
			t = AddInspectPoints(t)
			return t
		end,
		Objects = {}
	},
	-- Olympus biome rooms (P_ prefix)
	["P_*"] = {
		AddNPCs = true,
		SetupFunction = function(t)
			-- Add lore interactables (InspectPoints) for Olympus rooms
			t = AddInspectPoints(t)
			return t
		end,
		Objects = {}
	},
	-- Surface biome rooms (F_ prefix)
	["F_*"] = {
		AddNPCs = true,
		SetupFunction = function(t)
			-- Add lore interactables (InspectPoints) for Surface rooms
			t = AddInspectPoints(t)
			return t
		end,
		Objects = {}
	},
	-- Post-Typhon boss rooms (after defeating Typhon)
	Q_PostBoss01 = {
		AddNPCs = true,
		SetupFunction = function(t)
			-- Add lore interactables (InspectPoints) for post-Typhon area
			t = AddInspectPoints(t)
			-- Add palace entrance/forcefield gate (always present)
			if IsUseable({ Id = 792642 }) then
				table.insert(t, { Name = "Palace Entrance", ObjectId = 792642, DestinationOffsetY = -200 })
			end
			return t
		end,
		Objects = {}
	},
	Q_Story01 = {
		AddNPCs = true,
		SetupFunction = function(t)
			-- Add lore interactables (InspectPoints) for Zeus's Palace area
			t = AddInspectPoints(t)
			-- Add palace exit point (activated after talking to Apollo)
			if IsUseable({ Id = 792347 }) then
				table.insert(t, { Name = "Exit", ObjectId = 792347, DestinationOffsetY = -150 })
			end
			return t
		end,
		Objects = {}
	},
	-- Post-Chronos boss rooms (after defeating Chronos in Tartarus)
	I_PostBoss01 = {
		AddNPCs = true,
		SetupFunction = function(t)
			-- Add lore interactables (InspectPoints) for post-Chronos area
			t = AddInspectPoints(t)
			-- Add bed to enter flashback (always present)
			if IsUseable({ Id = 310036 }) then
				table.insert(t, { Name = "Bed", ObjectId = 310036, DestinationOffsetY = -150 })
			end
			-- Adds the mirror of night
			if IsUseable({ Id = 741588 }) and not IsUseable({ Id = 310036 }) then
				table.insert(t, { Name = "Mirror", ObjectId = 741588, DestinationOffsetY = 150 })
			end
			-- Adds Zagreus's voiceline trigger to not miss out on dialogue
			if not IsUseable({ Id = 741588 }) and not IsUseable({ Id = 310036 }) then
				table.insert(t, { Name = "ZagreusVoicelineTrigger", ObjectId = 772206, DestinationOffsetY = -150 })
			end
			return t
		end,
		Objects = {}
	},
	I_ChronosFlashback01 = {
		AddNPCs = true,
		SetupFunction = function(t)
			-- Add lore interactables (InspectPoints) for Chronos flashback
			t = AddInspectPoints(t)
			-- Add exit door to Death Area
			if IsUseable({ Id = 420896 }) then
				table.insert(t, { Name = "Exit", ObjectId = 420896, DestinationOffsetY = -150 })
			end
			return t
		end,
		Objects = {}
	},
	I_DeathAreaRestored = {
		AddNPCs = true,
		SetupFunction = function(t)
			-- Add lore interactables (InspectPoints) for restored Death Area
			t = AddInspectPoints(t)
			-- Add family rescue point (activated after exploring)
			if IsUseable({ Id = 774464 }) then
				table.insert(t, { Name = "Family Rescue", ObjectId = 774464, DestinationOffsetY = -200 })
			end
			return t
		end,
		Objects = {}
	},
	-- Default room config for all biomes with NPCs
	["*"] = {
		AddNPCs = true,
		Objects = {}
	}
}

function ProcessTable(objects, blockIds)
	-- Add all exit doors to blockIds to prevent them from appearing in rewards
	blockIds = blockIds or {}
	if MapState.OfferedExitDoors then
		for doorId, door in pairs(MapState.OfferedExitDoors) do
			blockIds[doorId] = true
		end
	end

	local t = InitializeObjectList(objects, blockIds)

	local currMap = GetMapName()
	for map_name, map_data in pairs(mapPointsOfInterest) do
		local mapMatches = false
		if map_name == currMap or map_name == "*" then
			mapMatches = true
		elseif map_name:find("*", 1, true) then
			-- Handle wildcard patterns like "I_*" or "P_*"
			local pattern = map_name:gsub("%*", "")
			if currMap and currMap:find(pattern, 1, true) == 1 then
				mapMatches = true
			end
		end

		if mapMatches then
			DebugPrintTable(map_data.Objects)
			for _, object in pairs(map_data.Objects) do
				if object.RequireUseable == false or IsUseable({ Id = object.ObjectId }) then
					local o = ShallowCopyTable(object)
					o.Name = GetDisplayName({ Text = o.Name, IgnoreSpecialFormatting = true })
					table.insert(t, o)
				end
			end
			print(GameState.Flags.InFlashback)
			if map_data.AddNPCs and not map_data.InFlashback then
				t = AddNPCs(t)
			end

			if map_data.SetupFunction ~= nil then
				t = map_data.SetupFunction(t)
			end
		end
	end

	table.sort(t, function(a, b) return a.Name < b.Name end)

	-- Check if we're in Asphodel (has CapturePointSwitch)
	local inAsphodel = false
	local capturePointIds = GetIdsByType({ Name = "CapturePointSwitch" })
	if capturePointIds and #capturePointIds > 0 then
		for _, id in ipairs(capturePointIds) do
			if IsUseable({ Id = id }) then
				inAsphodel = true
				break
			end
		end
	end

	-- Always check for Asphodel exit (doesn't require ExitsUnlocked)
	t = AddAsphodelExit(t)
	t = AddPoisonCure(t)
	t = AddGiftRack(t)

	-- Always add these items - they check IsUseable internally so only useable items will be added
	t = AddTrove(t)
	t = AddStand(t)
	t = AddWell(t)
	t = AddSurfaceShop(t)
	t = AddPool(t)
	t = AddAetherFont(t)
	t = AddOlympianStatues(t)
	-- Only add inspect points if exits are unlocked OR in Asphodel (to avoid duplicates from SetupFunction)
	if CurrentRun and CurrentRun.CurrentRoom and (CurrentRun.CurrentRoom.ExitsUnlocked or inAsphodel) then
		t = AddInspectPoints(t)
	end

	return t
end

function InitializeObjectList(objects, blockIds)
	local initTable = CollapseTableOrderedByKeys(objects) or {}
	local copy = {}
	for i, v in ipairs(initTable) do
		if blockIds == nil or blockIds[v.ObjectId] == nil then
			table.insert(copy, { ["ObjectId"] = v.ObjectId, ["Name"] = v.Name })
		end
	end
	return copy
end

local function GetChallengeDisplayName(rawName)
	if not rawName then
		return "ChallengeSwitch"
	end

	-- Strip reward suffix (anything after first underscore)
	local baseName = string.match(rawName, "^(%a+ChallengeSwitch)") or "ChallengeSwitch"

	-- Map internal base names to the game’s localization IDs
	local locMap = {
		TimeChallengeSwitch = "ChallengeSwitch",       -- Infernal Trove
		EliteChallengeSwitch = "EliteChallengeSwitch", -- Moon Monument
		PerfectClearChallengeSwitch = "PerfectClearChallengeSwitch", -- Unseen Sigil
	}

	local locId = locMap[baseName] or "ChallengeSwitch"

	-- Debug: log what we found
	print(string.format("Debug: rawName=%s, baseName=%s, locId=%s", rawName, baseName, locId))

	-- Return localized text
	return GetDisplayName({ Text = locId, IgnoreSpecialFormatting = true })
end

function AddTrove(objects)
	local switchData = CurrentRun.CurrentRoom.ChallengeSwitch
	if not (switchData and IsUseable({ Id = switchData.ObjectId })) then
		return objects
	end

	local copy = ShallowCopyTable(objects)
	local displayName = GetChallengeDisplayName(switchData.Name)
	local rewardType = GetDisplayName({ Text = switchData.RewardType, IgnoreSpecialFormatting = true })

	local switch = {
		ObjectId = switchData.ObjectId,
		Name = string.format("%s (%s)", displayName, rewardType),
	}

	if not ObjectAlreadyPresent(switch, copy) then
		table.insert(copy, switch)
	end
	return copy
end

function AddAsphodelExit(objects)
	-- Look for CapturePointSwitch (sand vortex orb in Asphodel)
	local capturePointIds = GetIdsByType({ Name = "CapturePointSwitch" })
	if not capturePointIds or #capturePointIds == 0 then
		return objects
	end

	local copy = ShallowCopyTable(objects)
	for _, id in ipairs(capturePointIds) do
		if IsUseable({ Id = id }) then
			local exitPoint = {
				["ObjectId"] = id,
				["Name"] = GetDisplayName({ Text = "Asphodel", IgnoreSpecialFormatting = true }) .. " Exit (Sand Vortex)",
			}
			if not ObjectAlreadyPresent(exitPoint, copy) then
				table.insert(copy, exitPoint)
			end
		end
	end
	return copy
end

function AddPoisonCure(objects)
	local ids = GetIdsByType({ Name = "PoisonCure" })
	if not ids or #ids == 0 then
		return objects
	end

	local NV = CurrentRun.CurrentRoom.PoisonCure
	local copy = ShallowCopyTable(objects)
	for _, id in ipairs(ids) do
		if IsUseable({ Id = id }) then
			local entry = {
				ObjectId = id,
				Name = "Curing Pool"
			}
			if not ObjectAlreadyPresent(entry, copy) then
				table.insert(copy, entry)
			end
		end
	end
	return copy
end

function AddGiftRack(objects)
	local ids = GetIdsByType({ Name = "GiftRack" })
	if not ids or #ids == 0 then
		return objects
	end

	local copy = ShallowCopyTable(objects)
	for _, id in ipairs(ids) do
		if IsUseable({ Id = id }) then
			local entry = {
				ObjectId = id,
				Name = "Keepsakes"
			}
			if not ObjectAlreadyPresent(entry, copy) then
				table.insert(copy, entry)
			end
		end
	end
	return copy
end

function AddSurfaceShop(objects)
	if not CurrentRun.CurrentRoom.SurfaceShop then
		return objects
	end

	local NV = CurrentRun.CurrentRoom.SurfaceShop
	local copy = ShallowCopyTable(objects)
	local switch = {
		["ObjectId"] = CurrentRun.CurrentRoom.SurfaceShop.ObjectId,
		["Name"] = "SurfaceShop_Title"
	}
	if not ObjectAlreadyPresent(switch, copy) then
		table.insert(copy, switch)
	end
	return copy
end

function AddWell(objects)
	if not (CurrentRun.CurrentRoom.WellShop and IsUseable({ Id = CurrentRun.CurrentRoom.WellShop.ObjectId })) then
		return objects
	end
	local NV = CurrentRun.CurrentRoom.WellShop.ObjectId
	local copy = ShallowCopyTable(objects)
	local well = {
		["ObjectId"] = CurrentRun.CurrentRoom.WellShop.ObjectId,
		["Name"] = "WellShop_Title",
	}
	if not ObjectAlreadyPresent(well, copy) then
		table.insert(copy, well)
	end
	return copy
end

function AddPool(objects)
	if not (CurrentRun.CurrentRoom.SellTraitShop and IsUseable({ Id = CurrentRun.CurrentRoom.SellTraitShop.ObjectId })) then
		return objects
	end
	local NV = CurrentRun.CurrentRoom.SellTraitShop.ObjectId
	local copy = ShallowCopyTable(objects)
	local pool = {
		["ObjectId"] = CurrentRun.CurrentRoom.SellTraitShop.ObjectId,
		["Name"] = "SellTraitShop",
	}
	if not ObjectAlreadyPresent(pool, copy) then
		table.insert(copy, pool)
	end
	return copy
end

function AddStand(objects)
	if not CurrentRun.CurrentRoom.MetaRewardStand then
		return objects
	end

	local copy = ShallowCopyTable(objects)
	local switch = {
		["ObjectId"] = CurrentRun.CurrentRoom.MetaRewardStand.ObjectId,
		["Name"] = "ShrinePointReward"
	}
	if not ObjectAlreadyPresent(switch, copy) then
		table.insert(copy, switch)
	end
	return copy
end

function AddInspectPoints(objects)
	-- Add lore interactables (InspectPoints) to the menu
	if not MapState.InspectPoints then
		return objects
	end
	local copy = ShallowCopyTable(objects)
	for objectId, inspectPoint in pairs(MapState.InspectPoints) do
		if IsUseable({ Id = objectId }) then
			local loreObject = {
				["ObjectId"] = objectId,
				["Name"] = "Lore: " .. (GetDisplayName({ Text = inspectPoint.Name or "Unknown", IgnoreSpecialFormatting = true }) or "Inspect Point"),
			}
			if not ObjectAlreadyPresent(loreObject, copy) then
				table.insert(copy, loreObject)
			end
		end
	end
	return copy
end

function AddAetherFont(objects)
	-- Add Aether Font (ManaFountain) - magic restoration fountain
	local copy = ShallowCopyTable(objects)
	local manaFountainIds = GetIdsByType({ Name = "ManaFountain" })
	if manaFountainIds then
		for _, fountainId in ipairs(manaFountainIds) do
			if IsUseable({ Id = fountainId }) then
				local fountainName = GetDisplayName({ Text = "UseManaFountain", IgnoreSpecialFormatting = true })
				local fountain = {
					["ObjectId"] = fountainId,
					["Name"] = fountainName,
				}
				if not ObjectAlreadyPresent(fountain, copy) then
					table.insert(copy, fountain)
				end
			end
		end
	end
	return copy
end

function AddOlympianStatues(objects)
	-- Add Olympian god statues (interactive traps that help in combat)
	local copy = ShallowCopyTable(objects)
	local statueTypes = {
		{ Name = "StatueTrap_Zeus", DisplayName = "Zeus" },
		{ Name = "StatueTrap_Hestia", DisplayName = "Hestia" },
		{ Name = "StatueTrap_Demeter", DisplayName = "Demeter" },
		{ Name = "StatueTrap_Poseidon", DisplayName = "Poseidon" }
	}
	
	for _, statueInfo in ipairs(statueTypes) do
		local statueIds = GetIdsByType({ Name = statueInfo.Name })
		if statueIds then
			for _, statueId in ipairs(statueIds) do
				if IsUseable({ Id = statueId }) then
					local statueName = GetDisplayName({ Text = statueInfo.DisplayName, IgnoreSpecialFormatting = true }) .. " " .. GetDisplayName({ Text = "UseStatue", IgnoreSpecialFormatting = true })
					local statue = {
						["ObjectId"] = statueId,
						["Name"] = statueName,
					}
					if not ObjectAlreadyPresent(statue, copy) then
						table.insert(copy, statue)
					end
				end
			end
		end
	end
	
	return copy
end

function AddNPCs(objects)
	-- Don't add NPCs during active combat, but allow after combat even if exits aren't unlocked yet
	if CurrentRun and IsCombatEncounterActive(CurrentRun) then
		return objects
	end
	local npcs = CollapseTableOrderedByKeys(ActiveEnemies)
	if TableLength(npcs) == 0 then
		return objects
	end
	local copy = ShallowCopyTable(objects)
	for i = 1, #npcs do
		local skip = false
		if IsUseable({ Id = npcs[i].ObjectId }) then
			local npc = {
				["ObjectId"] = npcs[i].ObjectId,
				["Name"] = GetDisplayName({ Text = npcs[i].Name, IgnoreSpecialFormatting = true }),
			}
			if npcs[i].Name == "NPC_Hades_01" and GetMapName() == "Hub_Main" then   --Hades in house
				if ActiveEnemies[555686] then                                       --Hades is in garden
					npc["ObjectId"] = 555686
				elseif GetDistance({ Id = npc["ObjectId"], DestinationId = 422028 }) < 100 then --Hades on his throne
					npc["DestinationOffsetY"] = 150
				end
			elseif npcs[i].Name == "NPC_Cerberus_01" and GetMapName() == "Hub_Main" and GetDistance({ Id = npc["ObjectId"], DestinationId = 422028 }) > 500 then                                                                                                     --Cerberus not present in house
				skip = true
			end
			if not ObjectAlreadyPresent(npc, copy) and not skip then
				table.insert(copy, npc)
			end
		end
	end
	return copy
end

function ObjectAlreadyPresent(object, objects)
	found = false
	for k, v in ipairs(objects) do
		if object.ObjectId == v.ObjectId then
			found = true
		end
	end
	if CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Store and NumUseableObjects(CurrentRun.CurrentRoom.Store.SpawnedStoreItems or MapState.SurfaceShopItems) > 0 then
		for k, v in pairs(CurrentRun.CurrentRoom.Store.SpawnedStoreItems or MapState.SurfaceShopItems) do
			if object.ObjectId == v.ObjectId and v.Name ~= "ForbiddenShopItem" then
				found = true
			end
		end
	end
	return found
end

function TableInsertAtBeginning(baseTable, insertValue)
	if baseTable == nil or insertValue == nil then
		return
	end
	local returnTable = {}
	table.insert(returnTable, insertValue)
	for k, v in ipairs(baseTable) do
		table.insert(returnTable, v)
	end
	return returnTable
end

function OpenRewardMenu(rewards)
	local screen = DeepCopyTable(ScreenData.BlindAccessibilityRewardMenu)

	if IsScreenOpen(screen.Name) then
		return
	end
	OnScreenOpened(screen)
	HideCombatUI(screen.Name)

	PlaySound({ Name = "/SFX/Menu Sounds/BrokerMenuOpen" })
	local components = screen.Components

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Menu_UI" })
	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Menu_UI_Backing", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackgroundDim.Id, OffsetX = 0, OffsetY = 440 })
	components.CloseButton.OnPressedFunctionName = "BlindAccessCloseRewardMenu"
	components.CloseButton.ControlHotkeys        = { "Cancel", }
	components.CloseButton.MouseControlHotkeys   = { "Cancel", }

	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = { 0, 0, 0, 1 } })

	CreateRewardButtons(screen, rewards)
	screen.KeepOpen = true
	HandleScreenInput(screen)
	-- SetConfigOption({ Name = "ExclusiveInteractGroup", Value = "Menu_UI" })
end

function CreateRewardButtons(screen, rewards)
	local index = 0
	local startX = 250
	local startY = 235
	local yIncrement = 55
	local curY = startY
	local components = screen.Components
	local isFirstButton = true
	if not string.find(GetMapName(), "Hub_PreRun") and GetMapName():find("Hub_Main", 1, true) ~= 1 and GetMapName():find("E_", 1, true) ~= 1 then
		local healthKey = "AssesResourceMenuInformationHealth"
		components[healthKey] =
			CreateScreenComponent({
				Name = "ButtonDefault",
				Group = "Menu_UI_Rewards",
				Scale = 0.8,
				X = 960,
				Y = curY
			})
		AttachLua({ Id = components[healthKey].Id, Table = components[healthKey] })

		CreateTextBox({
			Id = components[healthKey].Id,
			Text = GetDisplayName({ Text = "Health", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0),
			FontSize = 24,
			OffsetX = -100,
			OffsetY = 0,
			Color = Color.White,
			Font = "P22UndergroundSCMedium",
			Group = "Menu_UI_Rewards",
			ShadowBlur = 0,
			ShadowColor = { 0, 0, 0, 1 },
			ShadowOffset = { 0, 2 },
			Justification = "Left",
		})
		curY = curY + yIncrement

		local armorKey = "AssesResourceMenuInformationArmor"
		components[armorKey] =
			CreateScreenComponent({
				Name = "ButtonDefault",
				Group = "Menu_UI_Rewards",
				Scale = 0.8,
				X = 960,
				Y = curY
			})
		AttachLua({ Id = components[armorKey].Id, Table = components[armorKey] })
		CreateTextBox({
			Id = components[armorKey].Id,
			Text = GetDisplayName({ Text = "Armor", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.HealthBuffer or 0),
			FontSize = 24,
			OffsetX = -100,
			OffsetY = 0,
			Color = Color.White,
			Font = "P22UndergroundSCMedium",
			Group = "Menu_UI_Rewards",
			ShadowBlur = 0,
			ShadowColor = { 0, 0, 0, 1 },
			ShadowOffset = { 0, 2 },
			Justification = "Left",
		})
		curY = curY + yIncrement

		local goldKey = "AssesResourceMenuInformationGold"
		components[goldKey] =
			CreateScreenComponent({
				Name = "ButtonDefault",
				Group = "Menu_UI_Rewards",
				Scale = 0.8,
				X = 960,
				Y = curY
			})
		AttachLua({ Id = components[goldKey].Id, Table = components[goldKey] })
		CreateTextBox({
			Id = components[goldKey].Id,
			Text = GetDisplayName({ Text = "Money", IgnoreSpecialFormatting = true }) .. ": " .. (GameState.Resources["Money"] or 0),
			FontSize = 24,
			OffsetX = -100,
			-- OffsetY = yIncrement * 2,
			Color = Color.White,
			Font = "P22UndergroundSCMedium",
			Group = "Menu_UI_Rewards",
			ShadowBlur = 0,
			ShadowColor = { 0, 0, 0, 1 },
			ShadowOffset = { 0, 2 },
			Justification = "Left",
		})
		curY = curY + yIncrement

		local manaKey = "AssesResourceMenuInformationMana"
		components[manaKey] =
			CreateScreenComponent({
				Name = "ButtonDefault",
				Group = "Menu_UI_Rewards",
				Scale = 0.8,
				X = 960,
				Y = curY
			})
		AttachLua({ Id = components[manaKey].Id, Table = components[manaKey] })
		CreateTextBox({
			Id = components[manaKey].Id,
			Text = GetDisplayName({ Text = "Mana", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.Mana or 0) .. "/" .. (CurrentRun.Hero.MaxMana or 0),
			FontSize = 24,
			OffsetX = -100,
			OffsetY = 0,
			Color = Color.White,
			Font = "P22UndergroundSCMedium",
			Group = "Menu_UI_Rewards",
			ShadowBlur = 0,
			ShadowColor = { 0, 0, 0, 1 },
			ShadowOffset = { 0, 2 },
			Justification = "Left",
		})
		curY = curY + yIncrement

		local deathDefianceKey = "AssesResourceMenuInformationDeathDefiance"
		components[deathDefianceKey] =
			CreateScreenComponent({
				Name = "ButtonDefault",
				Group = "Menu_UI_Rewards",
				Scale = 0.8,
				X = 960,
				Y = curY
			})
		AttachLua({ Id = components[deathDefianceKey].Id, Table = components[deathDefianceKey] })
		local deathDefianceCount = 0
		if CurrentRun.Hero.LastStands then
			for i, v in pairs(CurrentRun.Hero.LastStands) do
				deathDefianceCount = deathDefianceCount + 1
			end
		end
		CreateTextBox({
			Id = components[deathDefianceKey].Id,
			Text = GetDisplayName({ Text = "ExtraChance", IgnoreSpecialFormatting = true }) .. ": " .. deathDefianceCount,
			FontSize = 24,
			OffsetX = -100,
			OffsetY = 0,
			Color = Color.White,
			Font = "P22UndergroundSCMedium",
			Group = "Menu_UI_Rewards",
			ShadowBlur = 0,
			ShadowColor = { 0, 0, 0, 1 },
			ShadowOffset = { 0, 2 },
			Justification = "Left",
		})
		curY = curY + yIncrement
	else
		startY = 110
		curY = startY
	end
	for k, reward in pairs(rewards) do

		local rowOffset = 55
		local columnOffset = 450
		local boonsPerRow = 4
		local rowsPerPage = 99
		local rowIndex = math.floor(index / boonsPerRow)
		local pageIndex = math.floor(rowIndex / rowsPerPage)
		local offsetX = startX + columnOffset * (index % boonsPerRow)
		local offsetY = startY + rowOffset * (rowIndex % rowsPerPage)
		index = index + 1

		local displayText = reward.Name
		local buttonKey = "RewardMenuButton" .. k .. displayText
		components[buttonKey] =
			CreateScreenComponent({
				Name = "ButtonDefault",
				Group = "Menu_UI_Rewards",
				Scale = 0.8,
				X = offsetX,
				Y = offsetY
			})

		-- SetScaleX({ Id = components[buttonKey].Id, Fraction = 4 })
		AttachLua({ Id = components[buttonKey].Id, Table = components[buttonKey] })
		-- components[buttonKey].OnMouseOverFunctionName = "MouseOver"
		components[buttonKey].index = k
		components[buttonKey].reward = reward
		components[buttonKey].OnPressedFunctionName = "BlindAccessGoToReward"
		if reward.Args ~= nil and reward.Args.ForceLootName then
			displayText = reward.Args.ForceLootName --:gsub("Upgrade", ""):gsub("Drop", "")
		end
		if displayText:find("Drop") == #displayText - 3 then
			displayText = displayText:sub(1, -5)
		end
		displayText = GetDisplayName({ Text = displayText, IgnoreSpecialFormatting = true }) ..
		" "                                                                             --we need this space for Echo, NPC_Echo_01 -> "Echo" -> "Blitz" since "Echo" is an id
		if reward.IsOptionalReward then
			displayText = displayText ..
			"(" .. GetDisplayName({ Text = "MetaRewardAlt", IgnoreSpecialFormatting = true }) .. ")"
		end
		if displayText == "RandomLoot " then
			if LootObjects[reward.ObjectId] ~= nil then
				displayText = LootObjects[reward.ObjectId].Name
			end
		end
		CreateTextBox({
			Id = components[buttonKey].Id,
			Text = displayText,
			FontSize = 16,
			OffsetX = 0,
			OffsetY = 0,
			Color = Color.White,
			Font = "P22UndergroundSCMedium",
			Group = "Menu_UI_Rewards",
			ShadowBlur = 0,
			ShadowColor = { 0, 0, 0, 1 },
			ShadowOffset = { 0, 2 },
			Justification = "Center",
		})


		if reward.IsShopItem then
			CreateTextBox({
				Id = components[buttonKey].Id,
				Text = reward.ResourceCosts.Money .. " " .. GetDisplayName({ Text = "Money", IgnoreSpecialFormatting = true }),
				FontSize = 16,
				OffsetX = -520,
				OffsetY = 30,
				Color = Color.White,
				Font = "P22UndergroundSCMedium",
				Group = "Asses_UI_Store",
				ShadowBlur = 0,
				ShadowColor = { 0, 0, 0, 1 },
				ShadowOffset = { 0, 2 },
				Justification = "Center",
			})
		end

		if isFirstButton then
			TeleportCursor({ OffsetX = offsetX, OffsetY = offsetY })
			wait(0.2)
			TeleportCursor({ OffsetX = offsetX, OffsetY = offsetY })
			isFirstButton = false
		end
		curY = curY + yIncrement
	end
end

function rom.game.BlindAccessGoToReward(screen, button)
	PlaySound({ Name = "/SFX/Menu Sounds/ContractorItemPurchase" })
	rom.game.BlindAccessCloseRewardMenu(screen, button)
	local RewardID = nil
	RewardID = button.reward.ObjectId
	local destinationOffsetX = button.reward.DestinationOffsetX or 0
	local destinationOffsetY = button.reward.DestinationOffsetY or 0

	-- If no specific offset is set, calculate better positioning
	if destinationOffsetX == 0 and destinationOffsetY == 0 then
		-- Default positioning - stand slightly in front of object
		destinationOffsetY = -80 -- Stand in front (closer to player's view)
		destinationOffsetX = 0   -- Centered horizontally

		-- Adjust for specific object types
		if button.reward.Name then
			local name = button.reward.Name
			if name:find("Door") or name:find("Exit") or button.reward.IsDoor then
				destinationOffsetY = -120 -- Further back for doors
			elseif name:find("Loot") or name:find("Reward") then
				destinationOffsetY = -60  -- Closer for loot
			elseif name:find("Store") or name:find("Shop") then
				destinationOffsetY = -100 -- Good distance for shops
			end
		end

		-- Special positioning for NPCs - position directly in front ready to interact
		if button.reward.IsNPC or (button.reward.Name and ActiveEnemies) then
			-- Check if this object is an NPC by checking ActiveEnemies
			local isNPC = false
			if ActiveEnemies then
				for enemyId, enemy in pairs(ActiveEnemies) do
					if enemy.ObjectId == button.reward.ObjectId then
						isNPC = true
						break
					end
				end
			end
			if isNPC then
				destinationOffsetY = 150  -- Stand directly in front of NPCs for interaction
				destinationOffsetX = 0
			end
		end
	end

	if RewardID ~= nil then
		Teleport({
			Id = CurrentRun.Hero.ObjectId,
			DestinationId = RewardID,
			OffsetX = destinationOffsetX,
			OffsetY = destinationOffsetY
		})
	end
end

function rom.game.BlindAccessCloseRewardMenu(screen, button)
	SetConfigOption({ Name = "ExclusiveInteractGroup", Value = nil })
	OnScreenCloseStarted(screen)
	CloseScreen(GetAllIds(screen.Components), 0.15)
	OnScreenCloseFinished(screen)
	notifyExistingWaiters(screen.Name)
	ShowCombatUI(screen.Name)
end

function NumUseableObjects(objects)
	local count = 0
	if objects ~= nil then
		for k, object in pairs(objects) do
			if object.ObjectId ~= nil and IsUseable({ Id = object.ObjectId }) and object.Name ~= "ForbiddenShopItem" then
				count = count + 1
			end
		end
	end
	return count
end

function OpenStoreMenu(items)
	local screen = DeepCopyTable(ScreenData.BlindAccesibilityStoreMenu)

	if IsScreenOpen(screen.Name) then
		return
	end
	OnScreenOpened(screen)
	HideCombatUI(screen.Name)

	PlaySound({ Name = "/SFX/Menu Sounds/BrokerMenuOpen" })
	local components = screen.Components

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Asses_UI_Store" })

	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Asses_UI_Store_Backing", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackgroundDim.Id, OffsetX = 0, OffsetY = 440 })
	components.CloseButton.OnPressedFunctionName = "BlindAccessCloseItemScreen"
	components.CloseButton.ControlHotkeys        = { "Cancel", }
	components.CloseButton.MouseControlHotkeys   = { "Cancel", }

	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = { 0, 0, 0, 1 } })

	CreateItemButtons(screen, items)
	screen.KeepOpen = true
	HandleScreenInput(screen)
	-- SetConfigOption({ Name = "ExclusiveInteractGroup", Value = "Asses_UI_Store" })
end

function CreateItemButtons(screen, items)
	local xPos = 960
	local startY = 235
	local yIncrement = 75
	local curY = startY
	local components = screen.Components
	local isFirstButton = true
	local healthKey = "AssesResourceMenuInformationHealth"
	components[healthKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI_Store",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[healthKey].Id, Table = components[healthKey] })

	CreateTextBox({
		Id = components[healthKey].Id,
		Text = GetDisplayName({ Text = "Health", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0),
		FontSize = 24,
		OffsetX = -100,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI_Store",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement

	local armorKey = "AssesResourceMenuInformationArmor"
	components[armorKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI_Store",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[armorKey].Id, Table = components[armorKey] })
	CreateTextBox({
		Id = components[armorKey].Id,
		Text = GetDisplayName({ Text = "Armor", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.HealthBuffer or 0),
		FontSize = 24,
		OffsetX = -100,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI_Store",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement

	local goldKey = "AssesResourceMenuInformationGold"
	components[goldKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI_Store",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[goldKey].Id, Table = components[goldKey] })
	CreateTextBox({
		Id = components[goldKey].Id,
		Text = GetDisplayName({ Text = "Money", IgnoreSpecialFormatting = true }) .. ": " .. (GameState.Resources["Money"] or 0),
		FontSize = 24,
		OffsetX = -100,
		-- OffsetY = yIncrement * 2,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI_Store",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement

	local manaKey = "AssesResourceMenuInformationMana"
	components[manaKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI_Store",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[manaKey].Id, Table = components[manaKey] })
	CreateTextBox({
		Id = components[manaKey].Id,
		Text = GetDisplayName({ Text = "Mana", IgnoreSpecialFormatting = true }) .. ": " .. (CurrentRun.Hero.Mana or 0) .. "/" .. (CurrentRun.Hero.MaxMana or 0),
		FontSize = 24,
		OffsetX = -100,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI_Store",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement

	local deathDefianceKey = "AssesResourceMenuInformationDeathDefiance"
	components[deathDefianceKey] =
		CreateScreenComponent({
			Name = "ButtonDefault",
			Group = "Asses_UI_Store",
			Scale = 0.8,
			X = 960,
			Y = curY
		})
	AttachLua({ Id = components[deathDefianceKey].Id, Table = components[deathDefianceKey] })
	local deathDefianceCount = 0
	if CurrentRun.Hero.LastStands then
		for i, v in pairs(CurrentRun.Hero.LastStands) do
			deathDefianceCount = deathDefianceCount + 1
		end
	end
	CreateTextBox({
		Id = components[deathDefianceKey].Id,
		Text = GetDisplayName({ Text = "ExtraChance", IgnoreSpecialFormatting = true }) .. ": " .. deathDefianceCount,
		FontSize = 24,
		OffsetX = -100,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Asses_UI_Store",
		ShadowBlur = 0,
		ShadowColor = { 0, 0, 0, 1 },
		ShadowOffset = { 0, 2 },
		Justification = "Left",
	})
	curY = curY + yIncrement
	for k, item in pairs(items) do
		if IsUseable({ Id = item.ObjectId }) and item.Name ~= "ForbiddenShopItem" then
			local displayText = item.Name
			local buttonKey = "AssesShopMenuButton" .. k .. displayText
			components[buttonKey] =
				CreateScreenComponent({
					Name = "ButtonDefault",
					Group = "Asses_UI_Store",
					Scale = 0.8,
					X = xPos,
					Y = curY
				})
			components[buttonKey].index = k
			components[buttonKey].item = item
			components[buttonKey].OnPressedFunctionName = "BlindAccessMoveToItem"
			AttachLua({ Id = components[buttonKey].Id, Table = components[buttonKey] })
			-- components[buttonKey].OnMouseOverFunctionName = "MouseOver"

			if displayText == "RandomLoot" then
				if LootObjects[item.ObjectId] ~= nil then
					displayText = LootObjects[item.ObjectId].Name
				end
			end
			displayText = displayText:gsub("RoomReward", ""):gsub("StoreReward", "") or displayText
			CreateTextBox({
				Id = components[buttonKey].Id,
				Text = GetDisplayName({ Text = displayText, IgnoreSpecialFormatting = true }),
				UseDescription = false,
				FontSize = 24,
				OffsetX = -520,
				OffsetY = 0,
				Color = Color.White,
				Font = "P22UndergroundSCMedium",
				Group = "Asses_UI_Store",
				ShadowBlur = 0,
				ShadowColor = { 0, 0, 0, 1 },
				ShadowOffset = { 0, 2 },
				Justification = "Left",
			})
			CreateTextBox({
				Id = components[buttonKey].Id,
				Text = item.ResourceCosts.Money .. " " .. GetDisplayName({ Text = "Money", IgnoreSpecialFormatting = true }),
				FontSize = 24,
				OffsetX = -520,
				OffsetY = 30,
				Color = Color.White,
				Font = "P22UndergroundSCMedium",
				Group = "Asses_UI_Store",
				ShadowBlur = 0,
				ShadowColor = { 0, 0, 0, 1 },
				ShadowOffset = { 0, 2 },
				Justification = "Left",
			})
			if isFirstButton then
				TeleportCursor({ OffsetX = xPos + 300, OffsetY = curY })
				wait(0.2)
				TeleportCursor({ OffsetX = xPos, OffsetY = curY })
				isFirstButton = false
			end
			curY = curY + yIncrement
		end
	end
end

function rom.game.BlindAccessMoveToItem(screen, button)
	PlaySound({ Name = "/SFX/Menu Sounds/ContractorItemPurchase" })
	rom.game.BlindAccessCloseItemScreen(screen, button)
	local ItemID = button.item.ObjectId
	if ItemID ~= nil then
		-- Default positioning for store items - stand in front
		local offsetX = button.item.DestinationOffsetX or 0
		local offsetY = button.item.DestinationOffsetY or -80 -- Stand in front by default
		Teleport({
			Id = CurrentRun.Hero.ObjectId,
			DestinationId = ItemID,
			OffsetX = offsetX,
			OffsetY = offsetY
		})
	end
end

function rom.game.BlindAccessCloseItemScreen(screen, button)
	SetConfigOption({ Name = "ExclusiveInteractGroup", Value = nil })
	OnScreenCloseStarted(screen)
	CloseScreen(GetAllIds(screen.Components), 0.15)
	OnScreenCloseFinished(screen)
	notifyExistingWaiters(screen.Name)
	ShowCombatUI(screen.Name)
end

function CreateArcanaSpeechText(button, args, buttonArgs)
	local c = DeepCopyTable(args)
	c.SkipWrap = true
	if button.OnMouseOverFunctionName == "MouseOverMetaUpgrade" then
		DestroyTextBox({ Id = button.Id })
		local cardName = button.CardName
		local metaUpgradeData = MetaUpgradeCardData[cardName]

		c.UseDescription = false

		local state = "HIDDEN"
		if buttonArgs.CardState then
			state = buttonArgs.CardState
		else
			if GameState.MetaUpgradeState[cardName].Unlocked then
				state = "UNLOCKED"
			elseif HasNeighboringUnlockedCards(buttonArgs.Row, buttonArgs.Column) or (buttonArgs.Row == 1 and buttonArgs.Column == 1) then
				state = "LOCKED"
			end
		end

		local stateText = GetDisplayName({ Text = "AwardMenuLocked", IgnoreSpecialFormatting = true })
		if state == "UNLOCKED" then
			stateText = GetDisplayName({ Text = "Off", IgnoreSpecialFormatting = true })
			if GameState.MetaUpgradeState[cardName].Equipped then
				stateText = GetDisplayName({ Text = "On", IgnoreSpecialFormatting = true })
			end
		end


		c.Text = GetDisplayName({ Text = c.Text, IgnoreSpecialFormatting = true }) .. ", State: " .. stateText .. ", "
		c.Text = c.Text ..
		GetDisplayName({ Text = "CannotUseChaosWeaponUpgrade", IgnoreSpecialFormatting = true }) ..
		metaUpgradeData.Cost .. GetDisplayName({ Text = "IncreaseMetaUpgradeCard", IgnoreSpecialFormatting = true }) .. ", "
		if state == "LOCKED" then
			local costText = GetDisplayName({ Text = "CannotUseChaosWeaponUpgrade", IgnoreSpecialFormatting = true }) --cheating here, this is just "Requires: {Hammer Icon}" and we just remove the Hammer Icon

			local totalResourceCosts = MetaUpgradeCardData[button.CardName].ResourceCost
			for resource, cost in pairs(totalResourceCosts) do
				costText = costText ..
				" " .. cost .. " " .. GetDisplayName({ Text = resource, IgnoreSpecialFormatting = true })
			end
			c.Text = c.Text .. costText
		end

		CreateTextBox(c)
		CreateTextBox({
			Id = c.Id,
			Text = args.Text,
			UseDescription = true,
			LuaKey = c.LuaKey,
			LuaValue = c.LuaValue,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})
		CreateTextBox({
			Id = c.Id,
			Text = metaUpgradeData.AutoEquipText,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})

		return nil
	else
		local cardTitle = button.CardName
		local cardMultiplier = 1
		if GameState.MetaUpgradeState[cardTitle].AdjacencyBonuses and GameState.MetaUpgradeState[cardTitle].AdjacencyBonuses.CustomMultiplier then
			cardMultiplier = cardMultiplier + GameState.MetaUpgradeState[cardTitle].AdjacencyBonuses.CustomMultiplier
		end
		local cardData = {}
		if MetaUpgradeCardData[cardTitle].TraitName then
			cardData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = MetaUpgradeCardData[cardTitle]
			.TraitName, Rarity = TraitRarityData.RarityUpgradeOrder[GetMetaUpgradeLevel(cardTitle)], CustomMultiplier =
			cardMultiplier })
			local nextLevelCardData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = MetaUpgradeCardData
			[cardTitle].TraitName, Rarity = TraitRarityData.RarityUpgradeOrder[GetMetaUpgradeLevel(cardTitle) + 1], CustomMultiplier =
			cardMultiplier })
			SetTraitTextData(cardData, { ReplacementTraitData = nextLevelCardData })
		end
		if TraitData[MetaUpgradeCardData[cardTitle].TraitName].CustomUpgradeText then
			cardTitle = TraitData[MetaUpgradeCardData[cardTitle].TraitName].CustomUpgradeText
		end

		local costText = ""
		if CanUpgradeMetaUpgrade(button.CardName) then
			local state = "HIDDEN"
			if buttonArgs.CardState then
				state = buttonArgs.CardState
			else
				if GameState.MetaUpgradeState[button.CardName].Unlocked then
					state = "UNLOCKED"
				elseif HasNeighboringUnlockedCards(buttonArgs.Row, buttonArgs.Column) or (buttonArgs.Row == 1 and buttonArgs.Column == 1) then
					state = "LOCKED"
				end
			end

			if state == "UNLOCKED" then
				costText = GetDisplayName({ Text = "CannotUseChaosWeaponUpgrade", IgnoreSpecialFormatting = true }) --cheating here, this is just "Requires: {Hammer Icon}" and we just remove the Hammer Icon

				local totalResourceCosts = MetaUpgradeCardData[button.CardName].UpgradeResourceCost
				[GetMetaUpgradeLevel(button.CardName)]
				for resource, cost in pairs(totalResourceCosts) do
					costText = costText ..
					" " .. cost .. " " .. GetDisplayName({ Text = resource, IgnoreSpecialFormatting = true })
				end
			end
		end

		c.Id = button.Id
		c.Text = cardTitle
		c.UseDescription = true
		c.LuaKey = "TooltipData"
		c.LuaValue = cardData
		CreateTextBox({
			Id = c.Id,
			Text = GetDisplayName({ Text = args.Text, IgnoreSpecialFormatting = true }) .. ", " .. costText,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})
		CreateTextBox(c)
	end
end

function OnExitDoorUnlocked()
	if TableLength(MapState.OfferedExitDoors) == 1 then
		if GetDistance({ Id = 547487, DestinationId = 551569 }) == 0 then
			return
		elseif GetDistance({ Id = 547487, DestinationId = 551569 }) ~= 0 and GetDistance({ Id = CurrentRun.Hero.ObjectId, DestinationId = 547487 }) < 1000 then
			return
		end
	end
	local rewardsTable = ProcessTable(LootObjects)
	if TableLength(rewardsTable) > 0 then
		PlaySound({ Name = "/Leftovers/SFX/AnnouncementPing" })
		return
	end
	local curMap = GetMapName()
	if curMap == nil or string.find(curMap, "PostBoss") or string.find(curMap, "Hub_Main") or string.find(curMap, "Shop") or string.find(curMap, "D_Hub") or (string.find(curMap, "PreBoss") and CurrentRun.CurrentRoom.Store ~= nil and CurrentRun.CurrentRoom.Store.SpawnedStoreItems ~= nil) then
		return
	end
	OpenAssesDoorShowerMenu(CollapseTable(MapState.OfferedExitDoors))
end

function OnCodexPress()
	if IsScreenOpen("TraitTrayScreen") then
		for k, _ in pairs(ActiveScreens) do
			if k ~= "TraitTrayScreen" then
				return
			end
		end
		local rewardsTable = {}
		local curMap = GetMapName()

		if string.find(curMap, "Hub_PreRun") then
			rewardsTable = ProcessTable(MapState.WeaponKits)
		else
			local blockedIds = {}
			-- Check both map name and room name patterns for shops
			local isShopRoom = (curMap and (string.find(curMap, "Shop") or string.find(curMap, "PreBoss") or string.find(curMap, "D_Hub")))
			local hasStore = CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Store

			if (isShopRoom or hasStore) then
				if hasStore then
					-- Check if store items exist (don't use NumUseableObjects since shop items aren't useable until purchased)
					if CurrentRun.CurrentRoom.Store.SpawnedStoreItems and TableLength(CurrentRun.CurrentRoom.Store.SpawnedStoreItems) > 0 then
						for k, v in pairs(CurrentRun.CurrentRoom.Store.SpawnedStoreItems) do
							local name = v.Name
							if name == "StoreRewardRandomStack" then
								name = "RandomPom"
							end
							if v.Name ~= "ForbiddenShopItem" then
								table.insert(rewardsTable,
									{ IsShopItem = true, Name = name, ObjectId = v.ObjectId, ResourceCosts = v
									.ResourceCosts })
								blockedIds[v.ObjectId] = true
							end
						end
					end
					if MapState.SurfaceShopItems and TableLength(MapState.SurfaceShopItems) > 0 then
						for k, v in pairs(MapState.SurfaceShopItems) do
							if v and v.ObjectId and v.Name and v.ResourceCosts then
								table.insert(rewardsTable,
									{ IsShopItem = true, Name = v.Name, ObjectId = v.ObjectId, ResourceCosts = v
									.ResourceCosts })
								blockedIds[v.ObjectId] = true
							end
						end
					end
				end
			end
			local t = ProcessTable(ModUtil.Table.Merge(LootObjects, MapState.RoomRequiredObjects), blockedIds)
			for k, v in pairs(t) do
				table.insert(rewardsTable, v)
			end
			local currentRoom = CurrentRun.CurrentRoom
			if currentRoom.ShovelPointChoices and #currentRoom.ShovelPointChoices > 0 then
				for i, id in pairs(currentRoom.ShovelPointChoices) do
					if IsUseable({Id = id}) then
						table.insert(rewardsTable, { IsResourceHarvest = true, Name = "Shovel", ObjectId = id })
					end
				end
			end
			if currentRoom.PickaxePointChoices and #currentRoom.PickaxePointChoices > 0 then
				for i, id in pairs(currentRoom.PickaxePointChoices) do
					if IsUseable({Id = id}) then
						table.insert(rewardsTable, { IsResourceHarvest = true, Name = "Pickaxe", ObjectId = id })
					end
				end
			end
			if currentRoom.ExorcismPointChoices and #currentRoom.ExorcismPointChoices > 0 then
				for i, id in pairs(currentRoom.ExorcismPointChoices) do
					if IsUseable({Id = id}) then
						table.insert(rewardsTable, { IsResourceHarvest = true, Name = "Tablet", ObjectId = id })
					end
				end
			end
			if currentRoom.FishingPointChoices and #currentRoom.FishingPointChoices > 0 then
				for i, id in pairs(currentRoom.FishingPointChoices) do
					if IsUseable({Id = id}) then
						table.insert(rewardsTable, { IsResourceHarvest = true, Name = "Fish", ObjectId = id })
					end
				end
			end
			if currentRoom.HarvestPointChoicesIds and #currentRoom.HarvestPointChoicesIds > 0 then
				for i, id in pairs(currentRoom.HarvestPointChoicesIds) do
					if IsUseable({Id = id}) then
						table.insert(rewardsTable, { IsResourceHarvest = true, Name = "Herb", ObjectId = id })
					end
				end
			end
			-- Add Darkness (Mixer6CommonDrop) - spawned in Chaos rooms as a consumable, not a HarvestPoint
			local darknessIds = GetIdsByType({ Name = "Mixer6CommonDrop" })
			if darknessIds then
				for i, id in ipairs(darknessIds) do
					if IsUseable({Id = id}) then
						table.insert(rewardsTable, { IsResourceHarvest = true, Name = "Mixer6Common", ObjectId = id })
					end
				end
			end
			-- Add Zeus Mana Restoration (ManaDropZeus)
			local zeusDropIds = GetIdsByType({ Name = "ManaDropZeus" })
			if zeusDropIds then
				for i, id in ipairs(zeusDropIds) do
					if IsUseable({Id = id}) then
						table.insert(rewardsTable, { Name = "Zeus Magic Restoration", ObjectId = id })
					end
				end
			end
			-- Add InspectPoints from MapState
			if MapState.InspectPoints then
				for id, inspectPoint in pairs(MapState.InspectPoints) do
					if IsUseable({Id = id}) then
						table.insert(rewardsTable, { IsResourceHarvest = true, Name = "InspectPoint", ObjectId = id })
					end
				end
			end
			if GetIdsByType({ Name = "FieldsRewardCage" }) then
				for k, v in ipairs(GetIdsByType({ Name = "FieldsRewardCage" })) do
					local name = ""

					local ids = GetClosestIds({ Id = v, DestinationName = "Standing", Distance = 1 })
					for _, id in pairs(ids) do
						if id ~= 40000 and id ~= v then
							if LootObjects[id] then
								name = LootObjects[id].Name
							end
						end
					end
					table.insert(rewardsTable, { Name = name, ObjectId = v })
				end
			end
			if MapState.OptionalRewards then
				for k, v in pairs(MapState.OptionalRewards) do
					table.insert(rewardsTable, { IsOptionalReward = true, Name = v.Name, ObjectId = k })
				end
			end
		end

		local tempTable = {}
		for k, v in pairs(rewardsTable) do
			-- Shop items don't need IsUseable check since they're blocked until purchased
			if v.IsShopItem or v.ObjectId == nil or IsUseable({ Id = v.ObjectId }) then
				tempTable[k] = v
			end
		end

		rewardsTable = tempTable
		if TableLength(rewardsTable) > 0 then
			thread(TraitTrayScreenClose, ActiveScreens.TraitTrayScreen)
			OpenRewardMenu(rewardsTable)
		else
			return
		end
	end
end

function OnAdvancedTooltipPress()

	if string.find(GetMapName(), "Flashback_") ~= nil and IsInputAllowed({}) then
		rewardsTable = ProcessTable()--ModUtil.Table.Merge(LootObjects, MapState.RoomRequiredObjects))
		OpenRewardMenu(rewardsTable)
		return
	end

	-- Handle post-Typhon rooms (Q_PostBoss01, Q_Story01) like Crossroads/Flashback
	-- Handle post-Chronos rooms (I_PostBoss01, I_ChronosFlashback01, I_DeathAreaRestored) the same way
	local curMapName = GetMapName()
	if (curMapName == "Q_PostBoss01" or curMapName == "Q_Story01" or
	    curMapName == "I_PostBoss01" or curMapName == "I_ChronosFlashback01" or curMapName == "I_DeathAreaRestored") and IsInputAllowed({}) then
		rewardsTable = ProcessTable()

		-- Add exit doors to the menu (they're normally blocked in ProcessTable)
		if MapState.OfferedExitDoors then
			for doorId, door in pairs(MapState.OfferedExitDoors) do
				if door and door.ObjectId then
					local doorName = "Exit"
					if door.Name then
						doorName = door.Name
					end
					-- Get a readable name for the door
					local displayName = GetDisplayName({ Text = doorName, IgnoreSpecialFormatting = true })
					if displayName == doorName and door.Room and door.Room.Name then
						-- Try using the room name if door name wasn't translated
						displayName = GetDisplayName({ Text = door.Room.Name, IgnoreSpecialFormatting = true })
						if displayName == door.Room.Name then
							displayName = "Exit to " .. door.Room.Name
						end
					end
					table.insert(rewardsTable, { Name = displayName, ObjectId = door.ObjectId, IsDoor = true })
				end
			end
		end

		OpenRewardMenu(rewardsTable)
		return
	end

	if IsEmpty(ActiveScreens) then
		if not IsEmpty(MapState.CombatUIHide) or not IsInputAllowed({}) then
			-- If no screen is open, controlled entirely by input status
			return
		end
	end
	local rewardsTable = {}
	if CurrentRun ~= nil and CurrentRun.Hero ~= nil and CurrentRun.Hero.IsDead and not IsScreenOpen("InventoryScreen") and not IsScreenOpen("BlindAccesibilityInventoryMenu") then
		rewardsTable = ProcessTable(ModUtil.Table.Merge(LootObjects, MapState.RoomRequiredObjects))
		local curMap = GetMapName()
		if string.find(curMap, "Hub_Main") then
			if GameState.GardenPlots then
				local index = 1
				for k, v in pairs(GameState.GardenPlots) do
					local name = v.Name .. index
					index = index + 1
					table.insert(rewardsTable, { Name = name, ObjectId = k })
				end
			end
			if GameState.WorldUpgradesAdded.WorldUpgradeMusicPlayer then
				table.insert(rewardsTable, { Name = "MusicPlayer", ObjectId = 738510 })
			end
			if GameState.WorldUpgradesAdded.WorldUpgradeBadgeSeller then
				table.insert(rewardsTable, { Name = "Bartender", ObjectId = 590506 })
			end
			if GameState.WorldUpgradesAdded.WorldUpgradeRunHistory then
				table.insert(rewardsTable, { Name = "Historian", ObjectId = 589466 })
			end
		end
		if TableLength(rewardsTable) > 0 then
			if not IsEmpty(ActiveScreens.TraitTrayScreen) then
				thread(TraitTrayScreenClose, ActiveScreens.TraitTrayScreen)
			end
			OpenRewardMenu(rewardsTable)
		end
	end
end

-- Convert icon paths to readable text
function ConvertIconsToText(text)
	if not text then return text end

	-- Common icon mappings
	local iconMappings = {
		["@GUI\\Icons\\Life"] = "Health",
		["@GUI\\Icons\\Currency"] = "Gold",
		["@gui/icons/life"] = "Health",
		["@gui/icons/currency"] = "Gold",
		["@gui/icons/mana"] = "Magick",
		["@gui/icons/armor"] = "Armor",
		["@gui/icons/attack"] = "Attack",
		["@gui/icons/speed"] = "Speed",
	}

	-- First try exact matches (case-insensitive)
	for pattern, replacement in pairs(iconMappings) do
		text = text:gsub(pattern:gsub("\\", "\\\\"), replacement)
		text = text:gsub(pattern:lower():gsub("\\", "\\\\"), replacement)
		text = text:gsub(pattern:upper():gsub("\\", "\\\\"), replacement)
	end

	-- Handle any remaining icon patterns by extracting the icon name
	-- Pattern: @gui/icons/name or @GUI\Icons\name (with optional .number at the end)
	text = text:gsub("@[Gg][Uu][Ii][/\\][Ii]cons[/\\]([%w_]+)%.?%d*", function(iconName)
		-- Convert icon name from camelCase/snake_case to readable format
		-- First, handle known specific names
		local knownNames = {
			life = "Health",
			currency = "Gold",
			mana = "Magick",
			armor = "Armor",
			attack = "Attack",
			speed = "Speed",
		}

		local lowerName = iconName:lower()
		if knownNames[lowerName] then
			return knownNames[lowerName]
		end

		-- Otherwise, capitalize first letter and return
		return iconName:sub(1,1):upper() .. iconName:sub(2)
	end)

	return text
end

function wrap_GetDisplayName(baseFunc, args)
	v = baseFunc(args)
	if args.IgnoreSpecialFormatting then
		v = v:gsub("{[^}]+}", "")
		v = ConvertIconsToText(v)
		return v
	end
	return v
end

function wrap_TraitTrayScreenShowCategory(baseFunc, screen, categoryIndex, args)
	if not screen.Closing then
		return baseFunc(screen, categoryIndex, args)
	end
end

function override_SpawnStoreItemInWorld(itemData, kitId)
	local spawnedItem = nil
	if itemData.Name == "WeaponUpgradeDrop" then
		spawnedItem = CreateWeaponLoot({
			SpawnPoint = kitId,
			ResourceCosts = itemData.ResourceCosts or
				GetProcessedValue(ConsumableData.WeaponUpgradeDrop.ResourceCosts),
			DoesNotBlockExit = true,
			SuppressSpawnSounds = true,
		})
	elseif itemData.Name == "ShopHermesUpgrade" then
		spawnedItem = CreateHermesLoot({
			SpawnPoint = kitId,
			ResourceCosts = itemData.ResourceCosts or
				GetProcessedValue(ConsumableData.ShopHermesUpgrade.ResourceCosts),
			DoesNotBlockExit = true,
			SuppressSpawnSounds = true,
			BoughtFromShop = true,
			AddBoostedAnimation =
				itemData.AddBoostedAnimation,
			BoonRaritiesOverride = itemData.BoonRaritiesOverride
		})
		spawnedItem.CanReceiveGift = false
		SetThingProperty({ Property = "SortBoundsScale", Value = 1.0, DestinationId = spawnedItem.ObjectId })
	elseif itemData.Name == "ShopManaUpgrade" then
		spawnedItem = CreateManaLoot({
			SpawnPoint = kitId,
			ResourceCosts = itemData.ResourceCosts or
				GetProcessedValue(ConsumableData.ShopManaUpgrade.ResourceCosts),
			DoesNotBlockExit = true,
			SuppressSpawnSounds = true,
			BoughtFromShop = true,
			AddBoostedAnimation =
				itemData.AddBoostedAnimation,
			BoonRaritiesOverride = itemData.BoonRaritiesOverride
		})
		spawnedItem.CanReceiveGift = false
		SetThingProperty({ Property = "SortBoundsScale", Value = 1.0, DestinationId = spawnedItem.ObjectId })
	elseif itemData.Type == "Consumable" then
		local consumablePoint = SpawnObstacle({ Name = itemData.Name, DestinationId = kitId, Group = "Standing" })
		local upgradeData = GetRampedConsumableData(ConsumableData[itemData.Name] or LootData[itemData.Name])
		spawnedItem = CreateConsumableItemFromData(consumablePoint, upgradeData, itemData.CostOverride)
		spawnedItem.CanDuplicate = false
		spawnedItem.CanReceiveGift = false
		ApplyConsumableItemResourceMultiplier(CurrentRun.CurrentRoom, spawnedItem)
		ExtractValues(CurrentRun.Hero, spawnedItem, spawnedItem)
	elseif itemData.Type == "Boon" then
		itemData.Args.SpawnPoint = kitId
		itemData.Args.DoesNotBlockExit = true
		itemData.Args.SuppressSpawnSounds = true
		itemData.Args.SuppressFlares = true
		spawnedItem = GiveLoot(itemData.Args)
		spawnedItem.CanReceiveGift = false
		SetThingProperty({ Property = "SortBoundsScale", Value = 1.0, DestinationId = spawnedItem.ObjectId })
	end
	if spawnedItem ~= nil then
		spawnedItem.SpawnPointId = kitId
		if not itemData.PendingShopItem then
			SetObstacleProperty({ Property = "MagnetismWhileBlocked", Value = 0, DestinationId = spawnedItem.ObjectId })
			spawnedItem.UseText = spawnedItem.PurchaseText or "Shop_UseText"
			spawnedItem.IconPath = spawnedItem.TextIconPath or spawnedItem.IconPath
			-- FIX: Add nil check for Store before accessing SpawnedStoreItems
			if CurrentRun.CurrentRoom.Store and CurrentRun.CurrentRoom.Store.SpawnedStoreItems then
				table.insert(CurrentRun.CurrentRoom.Store.SpawnedStoreItems,
					--MOD START
					{ KitId = kitId, ObjectId = spawnedItem.ObjectId, OriginalResourceCosts = spawnedItem.BaseResourceCosts, ResourceCosts = spawnedItem.ResourceCosts, Name =
					itemData.Name })
				--MOD END
			end
		else
			MapState.SurfaceShopItems = MapState.SurfaceShopItems or {}
			table.insert(MapState.SurfaceShopItems, spawnedItem.Name)
		end
		return spawnedItem
	else
		DebugPrint({ Text = " Not spawned?!" .. itemData.Name })
	end
end

function wrap_MetaUpgradeCardAction(screen, button)
	-- Add nil check to prevent crash when button is nil (e.g., when clicking "forget")
	if not button then
		return
	end

	local selectedButton = button
	local cardName = selectedButton.CardName
	local metaUpgradeData = MetaUpgradeCardData[cardName]

	CreateArcanaSpeechText(selectedButton, {
		Id = selectedButton.Id,
		Text = metaUpgradeData.Name,
		SkipDraw = true,
		Color = Color.Transparent,
		UseDescription = true,
		LuaKey = "TooltipData",
		LuaValue = selectedButton.TraitData or {},
	}, { CardState = selectedButton.CardState })
end

function wrap_UpdateMetaUpgradeCardCreateTextBox(baseFunc, screen, row, column, args)
	if args.SkipDraw and not args.SkipWrap then
		if args.LuaKey == nil then
			return
		end
		local button = screen.Components[GetMetaUpgradeKey(row, column)]

		CreateArcanaSpeechText(button, args, { Row = row, Column = column })
		return nil
	else
		return baseFunc(args, screen, row, column, args)
	end
end

function wrap_UpdateMetaUpgradeCard(screen, row, column)
	local components = screen.Components
	local button = components.MemCostModuleBacking
	-- Add nil check to prevent crash when button doesn't exist (e.g., when clicking "forget")
	if not button or not button.Id then
		return
	end

	-- Set up accessibility speech for the MemCostModuleBacking button
	button.Screen = screen
	AttachLua({ Id = button.Id, Table = button })

	-- Keep the original expand text creation (this was working before)
	if MetaUpgradeCostData.MetaUpgradeLevelData[GetCurrentMetaUpgradeLimitLevel() + 1] then
		local nextCostData = MetaUpgradeCostData.MetaUpgradeLevelData[GetCurrentMetaUpgradeLimitLevel() + 1]
		.ResourceCost
		local nextMetaUpgradeLevel = MetaUpgradeCostData.MetaUpgradeLevelData[GetCurrentMetaUpgradeLimitLevel() + 1]

		local costText = GetDisplayName({ Text = "CannotUseChaosWeaponUpgrade", IgnoreSpecialFormatting = true })

		for resource, cost in pairs(nextCostData) do
			costText = costText .. " " .. cost .. " " .. GetDisplayName({ Text = resource, IgnoreSpecialFormatting = true })
		end

		DestroyTextBox({ Id = button.Id })
		CreateTextBox({
			Id = button.Id,
			Text = GetDisplayName({ Text = "IncreaseMetaUpgradeCard", IgnoreSpecialFormatting = true }) ..
			", " .. costText,
			SkipDraw = true,
			Color = Color.Transparent
		})
		CreateTextBox({
			Id = button.Id,
			Text = "IncreaseMetaUpgradeCard",
			SkipDraw = true,
			Color = Color.Transparent,
			UseDescription = true,
			LuaKey = "TempTextData",
			LuaValue = { Amount = nextMetaUpgradeLevel.CostIncrease }
		})
	else
		DestroyTextBox({ Id = button.Id })
		CreateTextBox({
			Id = button.Id,
			Text = GetDisplayName({ Text = "IncreaseMetaUpgradeCard", IgnoreSpecialFormatting = true }) ..
			", " .. GetDisplayName({ Text = "Max_MetaUpgrade", IgnoreSpecialFormatting = true }),
			SkipDraw = true,
			Color = Color.Transparent
		})
	end

	-- Add Insights and Forget-me-not text boxes here (so they're ready on first hover)
	local additionalActions = {}

	-- Check for Insights action
	if CanUpgradeCards() then
		local insightsPoints = GetResourceAmount("CardUpgradePoints")
		local insightsName = GetDisplayName({ Text = "MetaUpgradeMem_UpgradeMode", IgnoreSpecialFormatting = true })
		local cardUpgradePointsName = GetDisplayName({ Text = "CardUpgradePoints", IgnoreSpecialFormatting = true })
		table.insert(additionalActions, insightsName .. ", " .. insightsPoints .. " " .. cardUpgradePointsName)
	end

	-- Check for Forget-me-not action (always available)
	local forgetMeNotName = GetDisplayName({ Text = "MetaUpgrade_Pin", IgnoreSpecialFormatting = true })
	table.insert(additionalActions, forgetMeNotName)

	-- Add these additional actions to the button
	if #additionalActions > 0 then
		local additionalText = table.concat(additionalActions, ", ")
		CreateTextBox({
			Id = button.Id,
			Text = additionalText,
			SkipDraw = true,
			Color = Color.Transparent
		})
	end
end

-- Weapon and boss name mappings for testaments
local WeaponNames = {
	["WeaponStaffSwing"] = "Staff",
	["WeaponDagger"] = "Sister Blades",
	["WeaponCast"] = "Sister Blades",  -- Alternative ID for daggers
	["WeaponBlink"] = "Black Coat",  -- Alternative ID (dash weapon)
	["WeaponTorch"] = "Umbral Flames",
	["WeaponTorchSpecial"] = "Umbral Flames",  -- Torch variant/aspect
	["WeaponAxe"] = "Moonstone Axe",
	["WeaponSprint"] = "Moonstone Axe",  -- Axe variant/aspect
	["WeaponLob"] = "Argent Skull",
	["WeaponSuit"] = "Black Coat",
}

local BossNames = {
	["BossHecate01"] = "Hecate",
	["BossHecate02"] = "Hecate",
	["BossScylla01"] = "Scylla",
	["BossScylla02"] = "Scylla",
	["BossPolyphemus01"] = "Polyphemus",
	["BossPolyphemus02"] = "Polyphemus",
	["BossEris01"] = "Eris",
	["BossEris02"] = "Eris",
	["BossInfestedCerberus01"] = "Infested Cerberus",
	["BossInfestedCerberus02"] = "Infested Cerberus",
	["BossPrometheus01"] = "Prometheus",
	["BossPrometheus02"] = "Prometheus",
	["BossChronos01"] = "Chronos",
	["BossChronos02"] = "Chronos",
	["BossTyphonHead01"] = "Typhon",
	["BossTyphonHead02"] = "Typhon",
}

-- Remove fake fear requirements - we don't know the real ones yet
local BossFearRequirements = {}

-- Map bounty name patterns to weapons and bosses
local BountyWeaponMap = {
	["Staff"] = "Staff",
	["Dagger"] = "Sister Blades",
	["Torch"] = "Umbral Flames",
	["Axe"] = "Moonstone Axe",
	["Lob"] = "Argent Skull",
	["Suit"] = "Black Coat",
}

local BountyBossMap = {
	["FBoss"] = "Hecate",  -- F area boss
	["GBoss"] = "Scylla",  -- G area boss
	["HBoss"] = "Infested Cerberus",  -- H area boss
	["NBoss"] = "Polyphemus",  -- N area boss
	["OBoss"] = "Eris",  -- O area boss
	["PBoss"] = "Prometheus",  -- P area boss
	["QBoss"] = "Chronos",  -- Q area boss (Surface/Olympus)
	["IBoss"] = "Typhon",  -- I area boss (Tartarus)
}

-- Extract testament info from bounty name pattern
local function GetTestamentInfo(bountyData, bountyName)
	if not bountyData then
		return nil, nil
	end

	local weaponName = nil
	local bossName = nil

	-- Try to extract from bounty name pattern (e.g., "BountyShrineDaggerGBoss")
	if bountyName then
		-- Check for weapon in name
		for pattern, weapon in pairs(BountyWeaponMap) do
			if string.find(bountyName, pattern) then
				weaponName = weapon
				break
			end
		end

		-- Check for boss in name
		for pattern, boss in pairs(BountyBossMap) do
			if string.find(bountyName, pattern) then
				bossName = boss
				break
			end
		end
	end

	-- Fallback to old extraction method if name pattern doesn't work
	if not weaponName and bountyData.CompleteGameStateRequirements then
		for _, req in ipairs(bountyData.CompleteGameStateRequirements) do
			if req.Path and req.Path[#req.Path] == "Weapons" and req.HasAny then
				local weaponId = req.HasAny[1]
				if weaponId then
					weaponName = WeaponNames[weaponId]
				end
				break
			end
		end
	end

	if not bossName and bountyData.Encounters and bountyData.Encounters[1] then
		local encounterId = bountyData.Encounters[1]
		-- Try to get display name first
		if GetDisplayName then
			bossName = GetDisplayName({ Text = encounterId })
		end
		-- Fallback to hardcoded names
		if not bossName or bossName == "" or bossName == encounterId then
			bossName = BossNames[encounterId]
		end
	end

	return weaponName, bossName
end

-- Announce boss testaments for current weapon at current fear
function AnnounceBossTestaments()
	if not rom or not rom.tolk then
		return
	end

	if not BountyData then
		rom.tolk.output("Testament data not available", false)
		return
	end

	-- Get current weapon - extensive debug logging
	local currentWeaponId = nil

	-- Debug everything we can find
	if rom and rom.log then
		rom.log.info("=== Weapon Detection Debug ===")

		-- Check CurrentRun
		if CurrentRun then
			rom.log.info("CurrentRun exists")
			if CurrentRun.Hero and CurrentRun.Hero.Weapons then
				rom.log.info("CurrentRun.Hero.Weapons:")
				for weaponId, _ in pairs(CurrentRun.Hero.Weapons) do
					rom.log.info("  - " .. weaponId)
				end
			end
		else
			rom.log.info("CurrentRun is nil (in hub)")
		end

		-- Check GameState
		if GameState then
			rom.log.info("GameState exists")
			if GameState.LastWeaponUpgradeData then
				rom.log.info("LastWeaponUpgradeData.WeaponName: " .. tostring(GameState.LastWeaponUpgradeData.WeaponName))
			end
			if GameState.LastInteractedWeaponUpgrade then
				rom.log.info("LastInteractedWeaponUpgrade: " .. tostring(GameState.LastInteractedWeaponUpgrade))
			end
			-- Check for any weapon-related fields
			for key, value in pairs(GameState) do
				if string.find(key:lower(), "weapon") then
					rom.log.info("GameState." .. key .. " = " .. tostring(value))
				end
			end
		end
		rom.log.info("=== End Debug ===")
	end

	-- Try GameState.PrimaryWeaponName first (most reliable when it exists)
	if GameState and GameState.PrimaryWeaponName then
		currentWeaponId = GameState.PrimaryWeaponName
	-- Then check CurrentRun for main weapons only
	elseif CurrentRun and CurrentRun.Hero and CurrentRun.Hero.Weapons then
		-- Priority list of main weapons
		local mainWeapons = {"WeaponStaffSwing", "WeaponDagger", "WeaponTorch", "WeaponAxe", "WeaponLob", "WeaponSuit"}
		for _, weapon in ipairs(mainWeapons) do
			if CurrentRun.Hero.Weapons[weapon] then
				currentWeaponId = weapon
				break
			end
		end
	end

	if not currentWeaponId then
		if rom and rom.tolk then
			rom.tolk.output("Cannot determine current weapon", false)
		end
		return
	end

	-- Keep the weapon ID for matching, get display name later for output
	local currentWeaponMatchName = WeaponNames[currentWeaponId] or currentWeaponId

	-- Get current fear level
	local currentFear = GetTotalSpentShrinePoints and GetTotalSpentShrinePoints() or 0

	-- Find relevant testaments
	local availableTestaments = {}
	local completedTestaments = {}

	-- Check bounties in the shrine order if available
	local bountyOrder = ScreenData and ScreenData.Shrine and ScreenData.Shrine.BountyOrder or {}

	-- If no order defined, check all bounties
	if #bountyOrder == 0 then
		for bountyName, _ in pairs(BountyData) do
			table.insert(bountyOrder, bountyName)
		end
	end

	for _, bountyName in ipairs(bountyOrder) do
		local bountyData = BountyData[bountyName]
		if bountyData then
			-- Check if testament is unlocked
			local isUnlocked = true
			if bountyData.UnlockGameStateRequirements then
				isUnlocked = IsGameStateEligible and IsGameStateEligible(CurrentRun, bountyData.UnlockGameStateRequirements) or false
			end

			-- Check if testament is completed
			local isCompleted = GameState and GameState.ShrineBountiesCompleted and GameState.ShrineBountiesCompleted[bountyName] or false

			if isUnlocked then
				local weaponName, bossName = GetTestamentInfo(bountyData, bountyName)

				-- Debug logging
				if weaponName or bossName then
					-- Uncomment for debugging:
					-- rom.log.info("Testament " .. bountyName .. ": weapon=" .. tostring(weaponName) .. ", boss=" .. tostring(bossName))
				end

				-- Check if this testament matches current weapon and has required fear
				if weaponName == currentWeaponMatchName and bossName then
					-- Try to extract fear requirement from actual data
					local requiredFear = 0

					-- Debug: log the bounty structure to understand it better
					if bossName == "Scylla" then
						-- Log what we find for Scylla since we know it should be Fear 2
						if rom and rom.log then
							rom.log.info("=== Scylla bounty: " .. bountyName .. " ===")
							if bountyData.UnlockGameStateRequirements then
								rom.log.info("UnlockGameStateRequirements:")
								for i, req in ipairs(bountyData.UnlockGameStateRequirements) do
									rom.log.info("  Req " .. i .. ":")
									for key, value in pairs(req) do
										if type(value) == "table" then
											rom.log.info("    " .. key .. " = " .. table.concat(value, "."))
										else
											rom.log.info("    " .. key .. " = " .. tostring(value))
										end
									end
								end
							end
							if bountyData.CompleteGameStateRequirements then
								rom.log.info("CompleteGameStateRequirements:")
								for i, req in ipairs(bountyData.CompleteGameStateRequirements) do
									rom.log.info("  Req " .. i .. ":")
									for key, value in pairs(req) do
										if type(value) == "table" and key == "Path" then
											rom.log.info("    " .. key .. " = " .. table.concat(value, "."))
										elseif type(value) == "table" then
											rom.log.info("    " .. key .. " = table with " .. #value .. " items")
										else
											rom.log.info("    " .. key .. " = " .. tostring(value))
										end
									end
								end
							end
							rom.log.info("=== End Scylla debug ===")
						end
					end

					-- Extract fear requirement from CompleteGameStateRequirements
					if bountyData.CompleteGameStateRequirements then
						for _, req in ipairs(bountyData.CompleteGameStateRequirements) do
							if req.Path and table.concat(req.Path, ".") == "GameState.SpentShrinePointsCache"
							   and req.Comparison == ">=" and req.Value then
								requiredFear = req.Value
								break
							end
						end
					end

					if currentFear >= requiredFear then
						if not isCompleted then
							table.insert(availableTestaments, {
								boss = bossName,
								fear = requiredFear,
								bountyName = bountyName
							})
							-- Debug: log what we're adding
							-- rom.log.info("Adding testament: " .. bossName .. " at fear " .. requiredFear .. " for " .. currentWeaponName)
						else
							table.insert(completedTestaments, bossName)
						end
					end
				end
			end
		end
	end

	-- Get proper display name for output
	local currentWeaponDisplayName = nil
	if GetDisplayName then
		currentWeaponDisplayName = GetDisplayName({ Text = currentWeaponId })
	end
	if not currentWeaponDisplayName or currentWeaponDisplayName == "" then
		currentWeaponDisplayName = currentWeaponMatchName
	end

	-- Build announcement - only show NEXT testament
	local announcement = ""

	if #availableTestaments > 0 then
		-- Sort by fear requirement to get the next/most relevant one
		table.sort(availableTestaments, function(a, b)
			return (a.fear or 0) < (b.fear or 0)
		end)

		-- Get the first (lowest fear requirement) testament
		local nextTestament = availableTestaments[1]

		announcement = "Next testament with " .. currentWeaponDisplayName .. ": " .. nextTestament.boss

		-- Show if current fear exceeds the requirement
		if nextTestament.fear and nextTestament.fear > 0 then
			if currentFear > nextTestament.fear then
				announcement = announcement .. " (Fear " .. currentFear .. " exceeds requirement of " .. nextTestament.fear .. ")"
			elseif currentFear == nextTestament.fear then
				announcement = announcement .. " (Fear " .. nextTestament.fear .. " requirement met)"
			end
		else
			-- Don't claim "no fear requirement" when we just don't know
			announcement = announcement .. " at Fear " .. currentFear
		end

		-- If there are more testaments available, mention count
		if #availableTestaments > 1 then
			announcement = announcement .. ". " .. (#availableTestaments - 1) .. " more available"
		end
	else
		announcement = "No testaments available for " .. currentWeaponDisplayName .. " at Fear " .. currentFear
		-- Debug: show what weapon ID we're using if not recognized
		if currentWeaponId and WeaponNames[currentWeaponId] == nil then
			announcement = announcement .. " (Unknown weapon ID: " .. currentWeaponId .. ")"
		end
	end

	rom.tolk.output(announcement, false)
end

-- Shrine screen (Oath of the Unseen) accessibility functions for real-time updates
function wrap_ShrineScreenRankUp(screen, button)
	if not screen or not screen.SelectedItem then
		return
	end
	-- Announce the updated shrine upgrade information
	AnnounceShrineUpgradeState(screen.SelectedItem)
	-- Also announce boss testaments when fear changes
	AnnounceBossTestaments()
end

function wrap_ShrineScreenRankDown(screen, button)
	if not screen or not screen.SelectedItem then
		return
	end
	-- Announce the updated shrine upgrade information
	AnnounceShrineUpgradeState(screen.SelectedItem)
	-- Also announce boss testaments when fear changes
	AnnounceBossTestaments()
end

function AnnounceShrineUpgradeState(button)
	if not button or not button.Data then
		return
	end

	-- First time announcing any shrine upgrade, also announce testaments
	if not _G.ShrineTestamentsAnnouncedThisSession then
		_G.ShrineTestamentsAnnouncedThisSession = true
		if rom and rom.tolk then
			rom.tolk.output("Checking testaments...", false)
		end
		AnnounceBossTestaments()
	end

	local upgradeData = button.Data
	local upgradeName = upgradeData.Name
	local currentRank = GetNumShrineUpgrades(upgradeName)
	local maxRank = GetShrineUpgradeMaxRank(upgradeData)

	-- Build the rank status text
	local displayName = GetDisplayName({ Text = upgradeName, IgnoreSpecialFormatting = true })
	local rankText = ""

	if currentRank == 0 then
		rankText = "Inactive"
	elseif currentRank == maxRank then
		rankText = "Maximum, Rank " .. currentRank .. " of " .. maxRank
	else
		rankText = "Rank " .. currentRank .. " of " .. maxRank
	end

	-- Destroy existing textboxes
	DestroyTextBox({ Id = button.Id })

	-- Create the name and rank text
	CreateTextBox({
		Id = button.Id,
		Text = displayName .. ", " .. rankText,
		SkipDraw = true,
		SkipWrap = true,
		Color = Color.Transparent
	})

	-- Create the description textbox with proper formatting
	-- Handle pluralized forms like the game does
	local descriptionTextKey = upgradeName
	if upgradeData.UsePluralizedForm then
		descriptionTextKey = GetPluralizedForm(upgradeName, upgradeData.ChangeValue)
	end

	-- This allows the game to substitute variables like {#PropertyName} with actual values
	CreateTextBox({
		Id = button.Id,
		Text = descriptionTextKey,
		UseDescription = true,
		LuaKey = "TooltipData",
		LuaValue = upgradeData,
		SkipDraw = true,
		SkipWrap = true,
		Color = Color.Transparent
	})

	-- Announce total Fear level
	if fear and fear.AnnounceTotalFear then
		fear.AnnounceTotalFear()
	end
end

-- Update button text on mouse over to add Insights and Forget-me-not actions
function wrap_MouseOverMemCostModule(button)
	if not button or not button.Id or not button.Screen then
		return
	end

	-- Check if we already added the extra text to prevent duplicates
	if button.AccessibilityTextAdded then
		return
	end

	local additionalActions = {}

	-- Check for Insights action
	if CanUpgradeCards() then
		local insightsPoints = GetResourceAmount("CardUpgradePoints")
		local insightsName = GetDisplayName({ Text = "MetaUpgradeMem_UpgradeMode", IgnoreSpecialFormatting = true })
		local cardUpgradePointsName = GetDisplayName({ Text = "CardUpgradePoints", IgnoreSpecialFormatting = true })
		table.insert(additionalActions, insightsName .. ", " .. insightsPoints .. " " .. cardUpgradePointsName)
	end

	-- Check for Forget-me-not action (always available)
	local forgetMeNotName = GetDisplayName({ Text = "MetaUpgrade_Pin", IgnoreSpecialFormatting = true })
	table.insert(additionalActions, forgetMeNotName)

	-- Add these additional actions to the button (without destroying existing text)
	if #additionalActions > 0 then
		local additionalText = table.concat(additionalActions, ", ")
		CreateTextBox({
			Id = button.Id,
			Text = additionalText,
			SkipDraw = true,
			Color = Color.Transparent
		})
		-- Mark that we've added the accessibility text
		button.AccessibilityTextAdded = true
	end
end

function wrap_OpenGraspLimitAcreen()
	local components = ActiveScreens.GraspLimitLayout.Components

	local buttonKey = "GraspReadUIButton"
	components[buttonKey] = CreateScreenComponent({
		Name = "ButtonDefault",
		Group = "Combat_Menu_TraitTray",
		X = 600,
		Y = 100
	})
	-- components[buttonKey].OnMouseOverFunctionName = "MouseOver"
	AttachLua({ Id = components[buttonKey].Id, Table = components[buttonKey] })

	CreateTextBox({
		Id = components[buttonKey].Id,
		Text = "MetaUpgradeTable_UnableToEquip",
		UseDescription = true,
	})

	thread(function()
		wait(0.02)
		TeleportCursor({ DestinationId = components[buttonKey].Id })
	end)
end

function wrap_GhostAdminDisplayCategory(screen, button)
	local category = screen.ItemCategories[button.CategoryIndex]
	local slotName = category.Name

	-- Process available items (not purchased)
	for k, itemData in pairs(screen.AvailableItems) do
		local name = itemData.Name
		local buttonKey = name .. "Button"
		local itemButton = screen.Components[buttonKey]

		-- Skip if button doesn't exist
		if not itemButton then
			goto continue
		end

		local displayName = GetDisplayName({ Text = name, IgnoreSpecialFormatting = true })

		local itemNameFormat = ShallowCopyTable(screen.ItemAvailableAffordableNameFormat)
		itemNameFormat.Id = itemButton.Id
		itemNameFormat.Text = displayName

		DestroyTextBox({ Id = itemButton.Id })
		CreateTextBox(itemNameFormat)

		-- Hidden description for tooltip
		CreateTextBox({
			Id = itemButton.Id,
			Text = name,
			UseDescription = true,
			Color = Color.Transparent,
			LuaKey = "TooltipData",
			LuaValue = itemData,
		})

		-- Add invisible flavor text for screen reader
		local flavorKey = name .. "_Flavor"
		CreateTextBox({
			Id = itemButton.Id,
			Text = flavorKey,
			UseDescription = true,
			Color = Color.Transparent,
		})
		::continue::
	end

	-- Process purchased items
	for k, itemData in pairs(screen.PurchasedItems) do
		local name = itemData.Name
		local buttonKey = name .. "Button"
		local itemButton = screen.Components[buttonKey]

		-- Skip if button doesn't exist
		if not itemButton then
			goto continue2
		end

		local displayName = GetDisplayName({ Text = name, IgnoreSpecialFormatting = true })

		local itemNameFormat = ShallowCopyTable(screen.ItemPurchasedNameFormat)
		itemNameFormat.Id = itemButton.Id
		itemNameFormat.Text = displayName ..
		", ," .. GetDisplayName({ Text = "On", IgnoreSpecialFormatting = true }) .. ", ,"

		DestroyTextBox({ Id = itemButton.Id })
		CreateTextBox(itemNameFormat)

		-- Hidden description for tooltip
		CreateTextBox({
			Id = itemButton.Id,
			Text = name,
			UseDescription = true,
			Color = Color.Transparent,
			LuaKey = "TooltipData",
			LuaValue = itemData,
		})

		-- Add invisible flavor text for screen reader
		local flavorKey = name .. "_Flavor"
		CreateTextBox({
			Id = itemButton.Id,
			Text = flavorKey,
			UseDescription = true,
			Color = Color.Transparent,
		})
		::continue2::
	end
end

function override_GhostAdminScreenRevealNewItemsPresentation(screen, button)
	-- Immediate parameter validation before any operations
	if not screen then
		return
	end

	local components = screen.Components
	AddInputBlock({ Name = "GhostAdminScreenRevealNewItemsPresentation" })

	-- Add comprehensive safety checks for screen object
	if not components then
		RemoveInputBlock({ Name = "GhostAdminScreenRevealNewItemsPresentation" })
		return
	end

	if not screen.AvailableItems then
		RemoveInputBlock({ Name = "GhostAdminScreenRevealNewItemsPresentation" })
		return
	end

	local incantationsRevealed = false
	-- Iterate through all available items and check if they need to be revealed
	for i, itemData in ipairs(screen.AvailableItems) do
		if screen.ItemsToReveal and screen.ItemsToReveal[itemData.Name] then
			-- Auto-scroll for items on other pages
			local needScroll = false
			while (i > screen.ScrollOffset + screen.ItemsPerPage) do
				needScroll = true
				screen.ScrollOffset = screen.ScrollOffset + screen.ItemsPerPage
			end
			if needScroll then
				wait(0.1)
				if GenericScrollPresentation then
					GenericScrollPresentation(screen)
				end
				if GhostAdminUpdateVisibility then
					GhostAdminUpdateVisibility(screen, { AnimateSlider = true })
				end
				wait(0.2)
			end

			incantationsRevealed = true
			if HeroVoiceLines and HeroVoiceLines.CauldronTyphonHintVoiceLines then
				thread(PlayVoiceLines, HeroVoiceLines.CauldronTyphonHintVoiceLines)
			end
			thread(PlayVoiceLines, itemData.OfferedVoiceLines or (HeroVoiceLines and HeroVoiceLines.CauldronSpellsRevealingVoiceLines))

			local itemButton = components[itemData.Name .. "Button"]
			if itemButton then
				ModifyTextBox({ Id = itemButton.Id, FadeOpacity = 0.0, FadeTarget = 1.0, FadeDuration = 1.3 })
				SetAlpha({ Id = itemButton.Id, Fraction = 1.0, Duration = 0.0 })
				if itemButton.AssociatedIds then
					SetAlpha({ Ids = itemButton.AssociatedIds, Fraction = 1.0, Duration = 0.6 })
				end
				SetAnimation({ DestinationId = itemButton.Id, Name = "CriticalItemShopButtonReveal" })
			end

			if CurrentRun and CurrentRun.WorldUpgradesRevealed then
				CurrentRun.WorldUpgradesRevealed[itemData.Name] = true
			end
			if GameState and GameState.WorldUpgradesRevealed then
				GameState.WorldUpgradesRevealed[itemData.Name] = true
			end
			wait(1.0)
		end
	end

	if screen.ItemsToReveal then
		screen.ItemsToReveal = {}
	end

	if incantationsRevealed then
		if HeroVoiceLines and HeroVoiceLines.CauldronSpellDiscoveredVoiceLines then
			thread(PlayVoiceLines, HeroVoiceLines.CauldronSpellDiscoveredVoiceLines, true)
		end
		wait(0.5)
	end

	RemoveInputBlock({ Name = "GhostAdminScreenRevealNewItemsPresentation" })
end

function wrap_MarketScreenDisplayCategory(screen, categoryIndex)
	local components = screen.Components
	local category = screen.ItemCategories[categoryIndex]

	local currentItemIndex = 0

	local items = CurrentRun.MarketItems[screen.ActiveCategoryIndex]
	for itemIndex, item in ipairs(items) do
		if not item.SoldOut and ResourceData[item.BuyName] ~= nil then
			local buyResourceData = ResourceData[item.BuyName]
			item.LeftDisplayName = item.BuyName
			item.LeftDisplayAmount = item.BuyAmount
			local costDisplay = item.Cost
			local costText = "ResourceCost"
			if category.FlipSides then
				for resourceName, resourceAmount in pairs(item.Cost) do
					buyResourceData = ResourceData[resourceName]
					item.LeftDisplayName = resourceName
					item.LeftDisplayAmount = resourceAmount
					costDisplay = {}
					costDisplay[item.BuyName] = item.BuyAmount
					costText = "ResourceCostSelling"
					break
				end
				if buyResourceData == nil then
					-- Back compat for removed resources
					break
				end
			end

			item.Showing = true
			if not HasResources(item.Cost) then
				if category.HideUnaffordable then
					item.Showing = false
				end
			end

			if item.Showing then
				currentItemIndex = currentItemIndex + 1
				local purchaseButtonKey = "PurchaseButton" .. currentItemIndex
				local itemNameFormat = screen.ItemNameFormat
				itemNameFormat.Id = components[purchaseButtonKey].Id

				local displayName = GetDisplayName({ Text = item.LeftDisplayName, IgnoreSpecialFormatting = true }) ..
				" * " .. item.LeftDisplayAmount

				local currentAmount = GameState.Resources[buyResourceData.Name] or 0
				local bannerText = ""
				if not item.Priority then
					bannerText = GetDisplayName({ Text = "Market_LimitedTimeOffer" }) .. ". "
				elseif item.HasUnmetRequirements then
					bannerText = GetDisplayName({ Text = "MarketEarlySellWarning" }) .. ". "
				end

				local price = ""
				if category.FlipSides then
					price = GetDisplayName({ Text = "MarketScreen_SellingHeader" }) .. ": +"
				else
					price = GetDisplayName({ Text = "MarketScreen_BuyingHeader", IgnoreSpecialFormatting = true }) .. ": "
				end

				local priceParts = {}
				for resource, amount in pairs(costDisplay) do
					local currencyName = GetDisplayName({ Text = resource, IgnoreSpecialFormatting = true })
					table.insert(priceParts, amount .. " " .. currencyName)
				end
				price = price .. table.concat(priceParts, ", ") -- Combine all parts of the price

				itemNameFormat.Text = bannerText ..
				displayName ..
				" " ..
				GetDisplayName({ Text = "Inventory", IgnoreSpecialFormatting = true }) ..
				": " .. currentAmount .. ", " .. price
				DestroyTextBox({ Id = components[purchaseButtonKey].Id })
				CreateTextBox(itemNameFormat)
			end
		end
	end
end

function override_CreateSurfaceShopButtons(screen)
	local itemLocationStartY = screen.ShopItemStartY
	local itemLocationYSpacer = screen.ShopItemSpacerY
	local itemLocationMaxY = itemLocationStartY + 4 * itemLocationYSpacer
	local itemLocationStartX = screen.ShopItemStartX
	local itemLocationXSpacer = screen.ShopItemSpacerX
	local itemLocationMaxX = itemLocationStartX + 1 * itemLocationXSpacer
	local itemLocationTextBoxOffset = 380
	local itemLocationX = itemLocationStartX
	local itemLocationY = itemLocationStartY
	local components = screen.Components
	local numButtons = StoreData.WorldShop.MaxOffers
	if numButtons == nil then
		numButtons = 0
		for i, groupData in pairs(StoreData.WorldShop.GroupsOf) do
			numButtons = numButtons + groupData.Offers
		end
	end
	RandomSynchronize(GetRunDepth(CurrentRun))
	local firstUseable = false
	for itemIndex = 1, numButtons do
		local upgradeData = CurrentRun.CurrentRoom.Store.StoreOptions[itemIndex]
		if upgradeData ~= nil then
			if not upgradeData.Processed then
				if upgradeData.Type == "Consumable" then
					if ConsumableData[upgradeData.Name] then
						local purchaseRequirements = nil
						if upgradeData.ReplacePurchaseRequirements ~= nil then
							purchaseRequirements = ShallowCopyTable(upgradeData.ReplacePurchaseRequirements)
						end
						upgradeData = GetRampedConsumableData(ConsumableData[upgradeData.Name])
						if purchaseRequirements then
							upgradeData.PurchaseRequirements = purchaseRequirements
						end
					elseif LootData[upgradeData.Name] then
						upgradeData = GetRampedConsumableData(LootData[upgradeData.Name])
					end
					upgradeData.Type = "Consumable"
				elseif upgradeData.Type == "Boon" and upgradeData.Args.ForceLootName then
					upgradeData.ResourceCosts = GetRampedConsumableData(ConsumableData.RandomLoot).ResourceCosts
					upgradeData.Type = "Boon"
					upgradeData.Name = upgradeData.Args.ForceLootName
				end
				upgradeData.RoomDelay = RandomInt(SurfaceShopData.DelayMin, SurfaceShopData.DelayMax)
				local delayCostMultiplier = SurfaceShopData.DelayPriceDiscount[upgradeData.RoomDelay]
				if not delayCostMultiplier then
					delayCostMultiplier = SurfaceShopData.DelayPriceDiscount[#SurfaceShopData.DelayPriceDiscount]
				end
				upgradeData.SpeedUpResourceCosts = {}
				upgradeData.BaseResourceCosts = {}
				local costMultiplier = GetShopCostMultiplier()
				for resourceName, resourceAmount in pairs(upgradeData.ResourceCosts) do
					local baseCost = round(resourceAmount * costMultiplier)
					local penaltyCost = round(resourceAmount * costMultiplier * SurfaceShopData.ImpatienceMultiplier)
					upgradeData.BaseResourceCosts[resourceName] = resourceAmount
					upgradeData.ResourceCosts[resourceName] = round(baseCost * delayCostMultiplier)
					upgradeData.SpeedUpResourceCosts[resourceName] = (penaltyCost - round(baseCost * delayCostMultiplier))
				end
				upgradeData.Processed = true
			end
			CurrentRun.CurrentRoom.Store.StoreOptions[itemIndex] = upgradeData
			local tooltipData = upgradeData
			local surfaceShopIcon = GetSurfaceShopIcon(upgradeData)
			local icon = nil
			if surfaceShopIcon ~= nil then
				icon = DeepCopyTable(ScreenData.UpgradeChoice.Icon)
				icon.X = itemLocationX + ScreenData.UpgradeChoice.IconOffsetX
				icon.Y = itemLocationY + ScreenData.UpgradeChoice.IconOffsetY
				icon.Animation = surfaceShopIcon
				icon.Alpha = 0.0
				icon.AlphaTarget = 1.0
				icon.AlphaTargetDuration = 0.2
				local iconBackingKey = "IconBacking" .. itemIndex
				components[iconBackingKey] = CreateScreenComponent({ Name = "BlankObstacle", Alpha = 0.0, AlphaTarget = 1.0, AlphaTargetDuration = 0.2, X = icon.X + screen.IconBackingOffsetX, Y = icon.Y + screen.IconBackingOffsetY, Group = "Combat_Menu", Animation = "SurfaceShopIconBacking" })
			end
			local purchaseButtonKey = "PurchaseButton" .. itemIndex
			local purchaseButton = DeepCopyTable(ScreenData.UpgradeChoice.PurchaseButton)
			purchaseButton.X = itemLocationX
			purchaseButton.Y = itemLocationY
			components[purchaseButtonKey] = CreateScreenComponent(purchaseButton)
			local highlight = ShallowCopyTable(ScreenData.UpgradeChoice.Highlight)
			highlight.X = purchaseButton.X
			highlight.Y = purchaseButton.Y
			components[purchaseButtonKey .. "Highlight"] = CreateScreenComponent(highlight)
			components[purchaseButtonKey].Highlight = components[purchaseButtonKey .. "Highlight"]
			if surfaceShopIcon ~= nil then
				components["Icon" .. itemIndex] = CreateScreenComponent(icon)
			end
			local iconKey = "HermesSpeedUp" .. itemIndex
			components[iconKey] = CreateScreenComponent({ Name = "BlankObstacle", X = itemLocationX + 457, Y = itemLocationY - 50, Group = "Combat_Menu" })
			if upgradeData.Purchased then
				SetAnimation({ DestinationId = components[iconKey].Id, Name = "SurfaceShopBuyNowSticker" })
			end
			local itemBackingKey = "Backing" .. itemIndex
			components[itemBackingKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX + itemLocationTextBoxOffset, Y = itemLocationY })
			local costString = "@GUI\\Icons\\Currency"
			local targetResourceCosts = upgradeData.ResourceCosts
			if upgradeData.Purchased then
				targetResourceCosts = upgradeData.SpeedUpResourceCosts
			end
			if upgradeData.ResourceCosts then
				local costAmount = GetResourceCost(targetResourceCosts, "Money")
				costString = costAmount .. " " .. costString
			end
			local costColor = Color.CostAffordableShop
			if not HasResources(targetResourceCosts) then
				costColor = Color.CostUnaffordable
			end
			local titleColor = costColor
			if not CurrentRun.CurrentRoom.FirstPurchase and HasHeroTraitValue("FirstPurchaseDiscount") and (costColor == Color.CostAffordableShop) then
				costColor = Color.CostAffordableDiscount
			end
			local button = components[purchaseButtonKey]
			button.Screen = screen
			AttachLua({ Id = button.Id, Table = button })
			button.OnMouseOverFunctionName = "MouseOverSurfaceShopButton"
			button.OnMouseOffFunctionName = "MouseOffSurfaceShopButton"
			button.OnPressedFunctionName = "HandleSurfaceShopAction"
			if not firstUseable then
				TeleportCursor({ OffsetX = itemLocationX, OffsetY = itemLocationY, ForceUseCheck = true })
				firstUseable = true
			end

			local deliveryDuration = "PendingDeliveryDuration"
			if upgradeData.Purchased then
				deliveryDuration = "SpeedUpDelivery"
			end
			local title = GetDisplayName({Text = GetSurfaceShopText(upgradeData)})
			local cost = costString
			local time = GetDisplayName({Text = deliveryDuration}):gsub("TempTextData.Delay", upgradeData.RoomDelay)
			local summaryText = title .. ", " .. cost .. ". " .. time

			local summaryTextBox = DeepCopyTable(ScreenData.UpgradeChoice.DescriptionText)
			summaryTextBox.Id = components[purchaseButtonKey].Id
			summaryTextBox.Text = summaryText
			summaryTextBox.UseDescription = false
			summaryTextBox.AppendToId = components[purchaseButtonKey].Id
			summaryTextBox.SkipDraw = true
			CreateTextBoxWithFormat(summaryTextBox)

			components[purchaseButtonKey].BlindAccessTitleText = title
			components[purchaseButtonKey].BlindAccessCostText = cost
			components[purchaseButtonKey].BlindAccessTimeText = time

			local purchaseButtonCostKey = "PurchaseButtonCost" .. itemIndex
			components[purchaseButtonCostKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			local costText = DeepCopyTable(ScreenData.UpgradeChoice.CostText)
			costText.Text = costString
			costText.Color = costColor
			costText.Id = components[purchaseButtonCostKey].Id
			CreateTextBox(costText)

			local purchaseButtonTitleKey = "PurchaseButtonTitle" .. itemIndex
			components[purchaseButtonTitleKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX, Y = itemLocationY })
			local titleText = DeepCopyTable(ScreenData.UpgradeChoice.TitleText)
			titleText.Id = components[purchaseButtonTitleKey].Id
			titleText.Text = GetSurfaceShopText(upgradeData)
			titleText.LuaKey = "TempTextData"
			titleText.LuaValue = upgradeData
			titleText.Color = titleColor
			CreateTextBox(titleText)

			local descriptionText = DeepCopyTable(ScreenData.UpgradeChoice.DescriptionText)
			descriptionText.Id = components[purchaseButtonKey].Id
			descriptionText.Text = GetSurfaceShopText(upgradeData)
			descriptionText.LuaKey = "TooltipData"
			descriptionText.LuaValue = upgradeData
			CreateTextBoxWithFormat(descriptionText)

			local statLines = upgradeData.StatLines
			local statLineData = upgradeData
			if upgradeData.CustomStatLinesWithShrineUpgrade ~= nil and GetNumShrineUpgrades(upgradeData.CustomStatLinesWithShrineUpgrade.ShrineUpgradeName) > 0 then
				statLines = upgradeData.CustomStatLinesWithShrineUpgrade.StatLines
			end
			if statLines then
				for lineNum, statLine in ipairs(statLines) do
					if statLine ~= "" then
						local offsetY = (lineNum - 1) * ScreenData.UpgradeChoice.LineHeight
						local statLineLeft = DeepCopyTable(ScreenData.UpgradeChoice.StatLineLeft)
						statLineLeft.Id = components[purchaseButtonKey].Id
						statLineLeft.Text = statLine
						statLineLeft.OffsetY = offsetY
						statLineLeft.LuaValue = statLineData
						statLineLeft.AppendToId = descriptionText.Id
						CreateTextBoxWithFormat(statLineLeft)
						local statLineRight = DeepCopyTable(ScreenData.UpgradeChoice.StatLineRight)
						statLineRight.Id = components[purchaseButtonKey].Id
						statLineRight.Text = statLine
						statLineRight.OffsetY = offsetY
						statLineRight.AppendToId = descriptionText.Id
						statLineRight.LuaValue = statLineData
						CreateTextBoxWithFormat(statLineRight)
					end
				end
			end

			SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value = ScreenData.UpgradeChoice.TooltipOffsetX })
			local purchaseButtonDeliveryKey = "PurchaseButtonDelivery" .. itemIndex
			components[purchaseButtonDeliveryKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			CreateTextBox({ Id = components[purchaseButtonDeliveryKey].Id, Text = deliveryDuration, FontSize = 18, OffsetX = -245, OffsetY = 80, Width = 720, Color = Color.White, Font = "LatoMedium", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Left", VerticalJustification = "BOTTOM", LuaKey = "TempTextData", LuaValue = { Delay = upgradeData.RoomDelay } })

			components[purchaseButtonKey].Data = upgradeData
			components[purchaseButtonKey].WeaponName = currentWeapon
			components[purchaseButtonKey].Index = itemIndex
			components[purchaseButtonKey].TitleId = components[purchaseButtonTitleKey].Id
			components[purchaseButtonKey].CostId = components[purchaseButtonCostKey].Id

			if CurrentRun.CurrentRoom.Store.Buttons == nil then
				CurrentRun.CurrentRoom.Store.Buttons = {}
			end
			table.insert(CurrentRun.CurrentRoom.Store.Buttons, components[purchaseButtonKey])
		end
		itemLocationX = itemLocationX + itemLocationXSpacer
		if itemLocationX >= itemLocationMaxX then
			itemLocationX = itemLocationStartX
			itemLocationY = itemLocationY + itemLocationYSpacer
		end
	end
end

function wrap_HandleSurfaceShopAction(screen, button)

	if button.Purchased then
		local upgradeData = button.Data

		DestroyTextBox({ Id = button.Id })

		local title = button.BlindAccessTitleText
		local rushCostAmount = GetResourceCost(upgradeData.SpeedUpResourceCosts, "Money")
		local rushCostString = rushCostAmount .. " @GUI\\Icons\\Currency"
		local correctTime = GetDisplayName({
			Text = "SpeedUpDelivery",
			LuaKey = "TempTextData",
			LuaValue = { Delay = upgradeData.RoomDelay }
		})
		local newSummaryText = title .. ", " .. rushCostString .. ", " .. correctTime
		
		local summaryTextBox = DeepCopyTable(ScreenData.UpgradeChoice.DescriptionText)
		summaryTextBox.Id = button.Id
		summaryTextBox.Text = newSummaryText
		summaryTextBox.UseDescription = false
		summaryTextBox.AppendToId = button.Id
		summaryTextBox.SkipDraw = true
		CreateTextBoxWithFormat(summaryTextBox)
	end
end

function wrap_CreateKeepsakeIconText(textboxArgs, keepsakeArgs)
	local upgradeData = keepsakeArgs.UpgradeData
	local traitName = upgradeData.Gift
	local traitData = nil
	if HeroHasTrait(traitName) then
		traitData = GetHeroTrait( traitName )
	else
		traitData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = traitName, Rarity = GetRarityKey(GetKeepsakeLevel( traitName )) })
	end
	local rarityLevel = GetRarityValue( traitData.Rarity )
	local titleArgs = DeepCopyTable(textboxArgs)
	titleArgs.UseDescription = false
	titleArgs.ignoreWrap = true
	titleArgs.Text =  GetDisplayName({ Text = titleArgs.Text, IgnoreSpecialFormatting = true }) .. ", " .. ("{!Icons.AwardRank" .. rarityLevel .. "}")

	CreateTextBox(titleArgs)
end

function wrap_CreateStoreButtons(baseFunc, args)
	if args.LuaKey == "TooltipData" then --only the textbox being read and the Fated List notification has this
		if args.Text == "TraitQuestItem" then --dont double up on title and cost for fated list notification
			return baseFunc(args)
		end
		local upgradeData = args.LuaValue
		local costString = "@GUI\\Icons\\Currency"
		local costAmount = 0 -- Start by assuming the cost is 0.

		-- Now, only try to access ResourceCosts if it actually exists.
		if upgradeData.ResourceCosts then
			costAmount = upgradeData.ResourceCosts["Money"] or 0
		end

		costString = costAmount .. "/" .. GetResourceAmount( "Money" ) .. " " .. costString

		if upgradeData.HealthCost then
			costString = upgradeData.HealthCost .. " / " .. CurrentRun.Hero.Health .. " @GUI\\Icons\\Life"
		end

		local titleText = DeepCopyTable( ScreenData.UpgradeChoice.TitleText )
		titleText.Id = args.Id
		titleText.Text = GetDisplayName({Text = GetTraitTooltip( args.LuaValue ), IgnoreSpecialFormatting = true}) .. " " .. costString
		titleText.LuaKey = "TempTextData"
		titleText.LuaValue = args.LuaValue
		CreateTextBox( titleText )

		return baseFunc(args)
	end
end

function wrap_CreateSpellButtons(baseFunc, args)
	if args.LuaKey == "TooltipData" and args.UseDescription then --only the textbox being read and the Fated List notification has this
		local traitData = args.LuaValue
		if traitData == nil or args.Text ~= GetTraitTooltip(traitData) then
			return baseFunc(args)
		end

		local titleText = DeepCopyTable( ScreenData.UpgradeChoice.TitleText )
		titleText.Id = args.Id
		titleText.Text = args.Text
		titleText.LuaKey = "TooltipData"
		titleText.LuaValue = traitData
		CreateTextBox( titleText )
			
		return baseFunc(args)
	end

	return baseFunc(args)
end

function override_OpenTalentScreen(args, spellItem)
	args = args or {}
	local screenName = "BlindTalentScreen"
	if not args.ReadOnly and spellItem and spellItem.AddTalentPoints then
		local talentPoints = ( spellItem.AddTalentPoints - 1 ) or 0
		CurrentRun.NumTalentPoints = CurrentRun.NumTalentPoints + talentPoints
	end
	CurrentRun.Hero.UntargetableFlags[screenName] = true
	SetPlayerInvulnerable( screenName )
	AddPlayerImmuneToForce( screenName )

	-- Not allowed to quit after seeing otherwise hidden choices
	InvalidateCheckpoint()
	HideCombatUI( screenName )
	
	if spellItem ~= nil then
		AddTimerBlock( CurrentRun, "OpenTalentScreen" )
		LootPickupPresentation( spellItem )
		RecordConsumableItem( spellItem )
		MapState.RoomRequiredObjects[spellItem.ObjectId] = nil
		SetAlpha({ Id = spellItem.ObjectId, Fraction = 0, Duration = 0 })
		RemoveScreenEdgeIndicator( spellItem )
		RemoveTimerBlock( CurrentRun, "OpenTalentScreen" )
	end
	
	local screen = DeepCopyTable( ScreenData[screenName] )
	screen.ReadOnly = args.ReadOnly
	screen.StartingTalentPoints = CurrentRun.NumTalentPoints
	if screen.ReadOnly then
		screen.BlockPause = true
	end
	local components = screen.Components

	AltAspectRatioFramesShow()
	
	OnScreenOpened( screen )
	LoadVoiceBanks( { Name = "Selene" }, nil, true )

	local traitData = nil
	if spellItem ~= nil and spellItem.RotateAfterUse and CurrentRun.Hero.SlottedSpell then
		MapState.GeneratedSpells = MapState.GeneratedSpells or {}
		RemoveTrait( CurrentRun.Hero, CurrentRun.Hero.SlottedSpell.Name )
		local eligibleSpells = {}
		for spellName, spellData in pairs( SpellData ) do
			if not spellData.Skip and not Contains( MapState.GeneratedSpells, spellName ) then
				table.insert( eligibleSpells, spellData )
			end
		end
		if IsEmpty( eligibleSpells ) then
			MapState.GeneratedSpells = {}
			eligibleSpells = { ChooseSpell( CurrentRun.CurrentRoom, args ) }
		end
		CurrentRun.Hero.SlottedSpell = DeepCopyTable( eligibleSpells[1] )
		CurrentRun.Hero.SlottedSpell.Talents = CreateTalentTree( SpellData[CurrentRun.Hero.SlottedSpell.Name] )	
		traitData = AddTraitToHero({ TraitName = CurrentRun.Hero.SlottedSpell.TraitName })
		table.insert( MapState.GeneratedSpells, CurrentRun.Hero.SlottedSpell.Name )
	end

	if not CurrentRun.Hero.SlottedSpell then	
		CurrentRun.Hero.SlottedSpell = ChooseSpell( CurrentRun.CurrentRoom, args )
		CurrentRun.Hero.SlottedSpell.Talents = CreateTalentTree( SpellData[CurrentRun.Hero.SlottedSpell.Name] )	
		traitData = AddTraitToHero({ TraitName = CurrentRun.Hero.SlottedSpell.TraitName })

	end
	screen.QueuedTalents = {}
	screen.SelectedTalent = nil
	screen.Source = spellItem
	CreateScreenFromData( screen, screen.ComponentData )

	if not traitData then
		traitData = GetHeroTrait( CurrentRun.Hero.SlottedSpell.TraitName )
	end

	-- Hex
	CreateTextBox({
		Id = components.SpellBacking.Id,
		Text = traitData.Name,
		FontSize = 16,
		OffsetX = 0,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Combat_Menu",
		Justification = "Center",
	})
	CreateTextBox({
		Id = components.SpellBacking.Id,
		Text = traitData.Name,
		UseDescription = true,
		FontSize = 16,
		OffsetX = 0,
		OffsetY = 10,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Combat_Menu",
		Justification = "Center",
		LuaKey = "TooltipData",
		LuaValue = traitData
	})

	--Path of stars points
	CreateTextBox({
		Id = components.SpellBacking.Id,
		Text = ": Available points : " .. (CurrentRun.NumTalentPoints + 1),
		FontSize = 16,
		OffsetX = 0,
		OffsetY = 0,
		Color = Color.White,
		Font = "P22UndergroundSCMedium",
		Group = "Combat_Menu",
		Justification = "Center",
	})

	mod.CreateTalentTreeIcons( screen, { ObstacleName = "ButtonTalent", OnPressedFunctionName = "OnTalentPressed"} )
	wrap_UpdateTalentButtons( screen )
	if screen.ReadOnly or screen.AllInvested then
		UseableOn({ Id = components.CloseButton.Id })
		SetAlpha({ Id = components.CloseButton.Id, Fraction = 1.0, Duration = 0.2 })
		screen.BlockPause = true
	else
		UseableOff({ Id = components.CloseButton.Id })
	end

	if spellItem ~= nil and spellItem.RespawnAfterUse then
		local newSpellItemId = SpawnObstacle({ Name = "TalentDrop", DestinationId = spellItem.ObjectId })
		local newSpellItem = CreateConsumableItem( newSpellItemId, "TalentDrop", 0 )
		newSpellItem.RespawnAfterUse = spellItem.RespawnAfterUse
		newSpellItem.RotateAfterUse = spellItem.RotateAfterUse
		spellItem.RespawnAfterUse = false
	end

	if HeroHasTrait( "SpellTalentKeepsake" ) then
		local trait = GetHeroTrait("SpellTalentKeepsake")
		ReduceTraitUses( trait, {Force = true })
		trait.CustomTrayText = trait.ZeroBonusTrayText
	end

	if CurrentRun.Hero.SlottedSpell.HasDuoTalent and CurrentRun.ScreenViewRecord[screenName] == 1 then
		thread(FirstTimeDuoTalentPresentation, components.SpellBacking.Id )
	end
	-- Short delay to let animations finish and prevent accidental input
	wait(0.5)
	SetAlpha({ Id = components.TalentPointText.Id, Fraction = 1.0, Duration = 0.2 })
	screen.KeepOpen = true
	HandleScreenInput( screen )
	TeleportCursor({ OffsetX = components.SpellBacking.X + 300, OffsetY = components.SpellBacking.Y })
	wait(0.2)
	TeleportCursor({ OffsetX = components.SpellBacking.X, OffsetY = components.SpellBacking.Y })
end

function mod.CreateTalentTreeIcons(screen, args)
	args = args or {}
	local offsetX = args.OffsetX or screen.DefaultStartX + ScreenCenterNativeOffsetX
	local offsetY = args.OffsetY or screen.DefaultStartY + ScreenCenterNativeOffsetY
	local xSpacer = args.XSpacer or screen.DefaultTalentXSpacer
	local ySpacer = args.YSpacer or screen.DefaultTalentYSpacer
	local scale = args.Scale or screen.DefaultTalentScale
	local screenObstacle = args.ObstacleName or "BlankObstacle"
	local components = screen.Components
	local spellTalents = nil
	if CurrentRun.Hero.SlottedSpell then
		spellTalents = CurrentRun.Hero.SlottedSpell.Talents
	end
	if not spellTalents then
		spellTalents = screen.TalentData
	end
	if spellTalents.OffsetY then
		offsetY = offsetY + spellTalents.OffsetY
	end
	components.TalentIds = {}
	components.TalentFrameIds = {}
	components.TalentIdsDictionary = {}
	components.TalentFramesIdsDictionary = {}
	components.LinkObjects = {}
	for i, column in ipairs( spellTalents ) do
		for s, talent in pairs(spellTalents[i]) do
			local talentOffsetX = (talent.GridOffsetX or 0) * xSpacer
			local talentOffsetY = (talent.GridOffsetY or 0) * ySpacer

			local interactProperties = nil
			if screenObstacle ~= "BlankObstacle" then
				interactProperties =
				{
					TooltipOffsetX = ScreenCenterNativeOffsetX + screen.TooltipOffsetXStart - (i * xSpacer + offsetX + talentOffsetX),
					TooltipOffsetY = ScreenCenterNativeOffsetY + screen.TooltipOffsetYStart - (s * ySpacer + offsetY + talentOffsetY),
				}
			end
			local talentObject = CreateScreenComponent({
					-- Name = screenObstacle, X = i * xSpacer + offsetX + talentOffsetX, Y = s * ySpacer + offsetY + talentOffsetY,
					Name = screenObstacle, X = i * xSpacer + offsetX + talentOffsetX, Y = s * ySpacer + offsetY + talentOffsetY,
					Group = "Combat_Menu_Overlay",
					Scale = scale,
					InteractProperties = interactProperties,
					Alpha = 0.01,
					AlphaTarget = 1.0,
					AlphaTargetDuration = 0.6,
			})

			talentObject.Screen = screen
			-- talentObject.OnMouseOverFunctionName = "MouseOverTalentButton"
			-- talentObject.OnMouseOffFunctionName = "MouseOffTalentButton"
			talentObject.LinkObjects = {}
			if screenObstacle ~= "BlankObstacle" then
				CreateTextBox({ Id = talentObject.Id,
					OffsetX = 0, OffsetY = 0,
					Font = "P22UndergroundSCHeavy",
					Justification = "LEFT",
					Color = Color.Transparent,
					UseDescription = true,
				})
			end
			if not screen.ReadOnly then
				talentObject.OnPressedFunctionName = args.OnPressedFunctionName
			end
			talentObject.Data = talent
			talentObject.TalentColumn = i
			talentObject.TalentRow = s
			talentObject.Valid = false  -- Initialize as false, will be set by wrap_UpdateTalentButtons
			local newTraitData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = talent.Name, Rarity = talent.Rarity, ForBoonInfo = true })
			SetTraitTextData( newTraitData )
			CreateTextBox({
				Id = talentObject.Id,
				Text = talent.Name,
				FontSize = 16,
				OffsetX = 0,
				OffsetY = 0,
				Color = Color.White,
				Font = "P22UndergroundSCMedium",
				Group = "Combat_Menu",
				Justification = "Center",
			})
			CreateTextBox({
				Id = talentObject.Id,
				Text = talent.Name,
				UseDescription = true,
				FontSize = 16,
				OffsetX = 0,
				OffsetY = 10,
				Color = Color.White,
				Font = "P22UndergroundSCMedium",
				Group = "Combat_Menu",
				Justification = "Center",
				LuaKey = "TooltipData",
				LuaValue = newTraitData
			})
			table.insert( components.TalentIds, talentObject.Id )
			components.TalentIdsDictionary[i .. "_" .. s] = talentObject.Id
			components["TalentObject"..i .. "_" .. s] = talentObject
		end
	end
	for i, column in ipairs( spellTalents ) do
		for s, talent in pairs( spellTalents[i] ) do
			local talentObject = components["TalentObject"..i.."_"..s]
			talentObject.LinkObjects = {}
			if talent.LinkTo then
				CreateTextBox({
					Id = talentObject.Id,
					Text = ": Links to :",
					FontSize = 16,
					OffsetX = 0,
					OffsetY = 0,
					Color = Color.White,
					Font = "P22UndergroundSCMedium",
					Group = "Combat_Menu",
					Justification = "Center",
				})
				for q, linkToIndex in pairs( talent.LinkTo ) do
					CreateTextBox({
						Id = talentObject.Id,
						Text = (components["TalentObject"..(i+1).."_"..linkToIndex] and components["TalentObject"..(i+1).."_"..linkToIndex].Data and components["TalentObject"..(i+1).."_"..linkToIndex].Data.Name) or "Unknown",
						FontSize = 16,
						OffsetX = 0,
						OffsetY = 0,
						Color = Color.White,
						Font = "P22UndergroundSCMedium",
						Group = "Combat_Menu",
						Justification = "Center",
					})
				end
			end
			if talent.LinkFrom then
				CreateTextBox({
					Id = talentObject.Id,
					Text = ": Links from :",
					FontSize = 16,
					OffsetX = 0,
					OffsetY = 0,
					Color = Color.White,
					Font = "P22UndergroundSCMedium",
					Group = "Combat_Menu",
					Justification = "Center",
				})
				for q, linkToIndex in pairs( talent.LinkFrom ) do
					CreateTextBox({
						Id = talentObject.Id,
						Text = (components["TalentObject"..(i-1).."_"..linkToIndex] and components["TalentObject"..(i-1).."_"..linkToIndex].Data and components["TalentObject"..(i-1).."_"..linkToIndex].Data.Name) or "Unknown",
						FontSize = 16,
						OffsetX = 0,
						OffsetY = 0,
						Color = Color.White,
						Font = "P22UndergroundSCMedium",
						Group = "Combat_Menu",
						Justification = "Center",
					})
				end
			end
		end
	end
end

-- OnTalentPressed function for BlindTalentScreen button handling
function OnTalentPressed(screen, button)
	local components = screen.Components
	local selectedTalent = CurrentRun.Hero.SlottedSpell.Talents[button.TalentColumn][button.TalentRow]
	if selectedTalent.Invested or selectedTalent.QueuedInvested then
		PlaySound({ Name = "/Leftovers/SFX/OutOfAmmo" })
	elseif button.Valid then
		screen.SelectedTalent = selectedTalent
		PlaySound({ Name = "/SFX/Menu Sounds/VictoryScreenBoonPin" })
		TryCloseTalentTree(screen, button)
	else
		PlaySound({ Name = "/Leftovers/SFX/OutOfAmmo" })
	end
end

-- LeaveTalentTree function for BlindTalentScreen exit handling
function LeaveTalentTree(screen, button)
	local components = screen.Components
	if not screen.ReadOnly and not screen.AllInvested then
		return
	end
	TryCloseTalentTree(screen, button)
end

-- TryCloseTalentTree function for BlindTalentScreen close handling
function TryCloseTalentTree(screen, button)
	local components = screen.Components

	if not screen.AllInvested and not screen.ReadOnly then
		IncrementTableValue(CurrentRun, "InvestedTalentPoints")
		if not screen.SelectedTalent then
			return
		else
			table.insert(screen.QueuedTalents, screen.SelectedTalent)
			screen.SelectedTalent.QueuedInvested = true
		end

		if CurrentRun.NumTalentPoints and CurrentRun.NumTalentPoints > 0 then
			CurrentRun.NumTalentPoints = CurrentRun.NumTalentPoints - 1
			RecreateTalentTree(screen, button)
			UpdateAdditionalTalentPointButton(screen)
			if not screen.AllInvested then
				return
			end
		end
	end

	screen.AddedTraitNames = {}
	for _, talentInfo in pairs(screen.QueuedTalents) do
		talentInfo.Invested = true

		local baseTraitData = TraitData[talentInfo.Name]
		if baseTraitData.IsDuoBoon then
			CurrentRun.Hero.SlottedSpell.ObtainedDuoTalent = true
		end
		screen.AddedTraitNames[talentInfo.Name] = true
		if HeroHasTrait(talentInfo.Name) then
			local traitData = GetHeroTrait(talentInfo.Name)
			IncreaseTraitLevel(traitData)
			if baseTraitData.AcquireFunctionName then
				thread(CallFunctionName, baseTraitData.AcquireFunctionName, baseTraitData.AcquireFunctionArgs, traitData)
			end
		else
			AddTraitToHero({ TraitName = talentInfo.Name, Rarity = talentInfo.Rarity, FromLoot = true })
		end
	end

	SetConfigOption({ Name = "FreeFormSelectWrapY", Value = false })
	SetConfigOption({ Name = "ExclusiveInteractGroup", Value = nil })
	UpdateTalentPointInvestedCache()
	wait(0.3)

	OnScreenCloseStarted(screen)

	if screen.Source and screen.Source.DestroySourceOnClose then
		Destroy({ Id = screen.Source.ObjectId })
	end

	local ids = GetAllIds(screen.Components)
	ConcatTableValues(ids, components.TalentIds)
	ConcatTableValues(ids, components.TalentFrameIds)
	ConcatTableValues(ids, components.LinkObjects)
	for i, column in ipairs(CurrentRun.Hero.SlottedSpell.Talents) do
		for s, talent in pairs(column) do
			local talentObject = components["TalentObject"..i.."_"..s]
			if talentObject ~= nil and talentObject.BadgeId ~= nil then
				table.insert(ids, talentObject.BadgeId)
			end
		end
	end
	CloseScreen(ids, nil, screen, { CloseDestroyWait = 0.5 })
	AltAspectRatioFramesHide()
	if not screen.ReadOnly then
		if HeroHasTrait("SpellTalentKeepsake") then
			local traitData = GetHeroTrait("SpellTalentKeepsake")
			traitData.CustomTrayText = traitData.ZeroBonusTrayText
			ReduceTraitUses(traitData, {Force = true})
		end
	end
	if screen.Source and CurrentRun.AllSpellInvestedCache then
		screen.Source.CanDuplicate = false
	end
	CurrentRun.Hero.UntargetableFlags[screen.Name] = nil
	SetPlayerVulnerable(screen.Name)
	RemovePlayerImmuneToForce(screen.Name)

	OnScreenCloseFinished(screen)
	ShowCombatUI(screen.Name)
	if screen.Source and screen.Source.DoSpellInteractEndOnClose then
		SpellDropInteractPresentationEnd()
	end
	if screen.ReadOnly then
		ShowTraitTrayScreen({ AutoPin = false })
	else
		notifyExistingWaiters(UIData.TalentMenuId)
		wait(0.2, RoomThreadName)
		if CheckRoomExitsReady(CurrentRun.CurrentRoom) then
			UnlockRoomExits(CurrentRun, CurrentRun.CurrentRoom)
		end
	end
end

-- RecreateTalentTree function for BlindTalentScreen
function RecreateTalentTree(screen, button)
	local components = screen.Components
	local componentKey = "TalentObject"..button.TalentColumn.."_"..button.TalentRow
	wrap_UpdateTalentButtons(screen, true)
	TeleportCursor({ DestinationId = components[componentKey].Id, ForceUseCheck = true })
end

-- UpdateAdditionalTalentPointButton function for BlindTalentScreen
function UpdateAdditionalTalentPointButton(screen, args)
	args = args or {}
	local components = screen.Components
	if screen.ReadOnly then
		return
	else
		ModifyTextBox({ Id = components.TalentPointText.Id, Text = (CurrentRun.NumTalentPoints + 1) })
	end
end

function wrap_CreateTalentTreeIcons(screen, args)
	args = args or {}
	local screenObstacle = args.ObstacleName or "BlankObstacle"
	local components = screen.Components
	local spellTalents = nil
	if CurrentRun.Hero.SlottedSpell then
		spellTalents = CurrentRun.Hero.SlottedSpell.Talents
	end
	if not spellTalents then
		spellTalents = screen.TalentData
	end
	for i, column in ipairs( spellTalents ) do
		for s, talent in pairs( spellTalents[i] ) do
			talentObject = components["TalentObject"..i.."_"..s]
			local hasPreRequisites = true
			if talent.LinkFrom then
				hasPreRequisites = false
				for _, preReqIndex in pairs( talent.LinkFrom ) do
					if components["TalentObject"..(i-1).."_"..preReqIndex].Data.Invested or components["TalentObject"..(i-1).."_"..preReqIndex].Data.QueuedInvested  then
						-- if any are invested, this becomes valid
						hasPreRequisites = true
					end
				end
			end
			-- Check bidirectional links (can be unlocked from talents below too)
			if not hasPreRequisites and talent.LinkTo and talent.Bidirectional then
				for _, preReqIndex in pairs( talent.LinkTo ) do
					if components["TalentObject"..(i+1).."_"..preReqIndex] and ( components["TalentObject"..(i+1).."_"..preReqIndex].Data.Invested or components["TalentObject"..(i+1).."_"..preReqIndex].Data.QueuedInvested ) then
						-- if any are invested, this becomes valid
						hasPreRequisites = true
					end
				end
			end
			-- Don't create text here - wrap_UpdateTalentButtons will create all text
			-- This ensures text is always current and not stale
		end
	end
end

function wrap_UpdateTalentButtons(screen, skipUsableCheck)
	local components = screen.Components
	local firstUsable = skipUsableCheck

	-- Safety check: Ensure SlottedSpell exists before accessing Talents
	if not CurrentRun.Hero.SlottedSpell or not CurrentRun.Hero.SlottedSpell.Talents then
		return
	end

	screen.AllInvested = true  -- Assume all invested, set to false if any are not

	for i, column in ipairs( CurrentRun.Hero.SlottedSpell.Talents ) do
		for s, talent in pairs( column ) do
			local talentObject = components["TalentObject"..i.."_"..s]
			DestroyTextBox({Id = talentObject.Id})
			-- Update talentObject.Data to current state from game
			talentObject.Data = talent
			local hasPreRequisites = true
			if talent.LinkFrom then
				hasPreRequisites = false
				for _, preReqIndex in pairs( talent.LinkFrom ) do
					if components["TalentObject"..(i-1).."_"..preReqIndex].Data.Invested or components["TalentObject"..(i-1).."_"..preReqIndex].Data.QueuedInvested  then
						-- if any are invested, this becomes valid
						hasPreRequisites = true
					end
				end
			end
			-- Check bidirectional links (can be unlocked from talents below too)
			if not hasPreRequisites and talent.LinkTo and talent.Bidirectional then
				for _, preReqIndex in pairs( talent.LinkTo ) do
					if components["TalentObject"..(i+1).."_"..preReqIndex] and ( components["TalentObject"..(i+1).."_"..preReqIndex].Data.Invested or components["TalentObject"..(i+1).."_"..preReqIndex].Data.QueuedInvested ) then
						-- if any are invested, this becomes valid
						hasPreRequisites = true
					end
				end
			end
			if not hasPreRequisites and talent.QueuedInvested then
				talent.QueuedInvested = nil
			end

			-- Set Valid property for clickable buttons
			if not talent.Invested and not talent.QueuedInvested and hasPreRequisites then
				talentObject.Valid = true
				screen.AllInvested = false  -- At least one talent can still be invested
			else
				talentObject.Valid = false
			end

			-- Also set AllInvested to false if there are any non-invested talents
			if not talent.Invested then
				screen.AllInvested = false
			end

			local stateText = ""
			if talent.Invested or talent.QueuedInvested then
				stateText = GetDisplayName({ Text = "On" })
			elseif not talent.Invested then
				if hasPreRequisites then
					stateText = GetDisplayName({ Text = "Off" }) .. ", " ..(CurrentRun.NumTalentPoints + 1) .. " " .. GetDisplayName({Text = "AdditionalTalentPointDisplay"})
				else
					stateText = GetDisplayName({Text = "AwardMenuLocked"}) .. ", " .. (CurrentRun.NumTalentPoints + 1) .. " " .. GetDisplayName({Text = "AdditionalTalentPointDisplay"})
				end
			end

			local talentNameText = GetDisplayName({Text = talent.Name}) or talent.Name
		local titleText = talentNameText .. ", " .. stateText
			CreateTextBox({ 
				Id = talentObject.Id,
				Text = titleText,
				OffsetX = 0, OffsetY = 0,
				Font = "P22UndergroundSCHeavy",
				Justification = "LEFT",
				Color = Color.Transparent,
			})
			local newTraitData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = talent.Name, Rarity = talent.Rarity, ForBoonInfo = true })
			newTraitData.ForBoonInfo = true
			SetTraitTextData( newTraitData )
			CreateTextBox({ 
				Id = talentObject.Id,
				Text = talent.Name,
				OffsetX = 0, OffsetY = 0,
				Font = "P22UndergroundSCHeavy",
				Justification = "LEFT",
				Color = Color.Transparent,
				UseDescription = true,
				LuaKey = "TooltipData", LuaValue = newTraitData
			})

			if talent.LinkTo then
				local linkText = "→"
				for k,v in pairs(talent.LinkTo) do
					-- print((button.TalentColumn + 1) .."_"..v)
					-- print(components.TalentIdsDictionary[(button.TalentColumn + 1) .."_"..v])
					local linkedButton = components["TalentObject" .. (i + 1) .."_"..v]

					-- Safety check: Ensure linkedButton exists before accessing it
					if linkedButton and linkedButton.Data and linkedButton.Data.Name then
						linkText = linkText .. GetDisplayName({Text = linkedButton.Data.Name}) .. ", "
					end
				end
				linkText = linkText:sub(1, -3)
				CreateTextBox({ 
					Id = talentObject.Id,
					Text = linkText,
					OffsetX = 0, OffsetY = 0,
					Font = "P22UndergroundSCHeavy",
					Justification = "LEFT",
					Color = Color.Transparent,
				})
			end
		end
	end
end

function wrap_MouseOverTalentButton(button)
	-- Safety check for button and data
	if not button or not button.Data or not button.Data.Name then
		return
	end

	local talent = button.Data
	local screen = button.Screen

	-- Build the spoken text similar to how boons are described
	local spokenText = ""

	-- Safety: Get talent trait data for full information
	local newTraitData = nil
	if CurrentRun and CurrentRun.Hero then
		pcall(function()
			newTraitData = GetProcessedTraitData({
				Unit = CurrentRun.Hero,
				TraitName = talent.Name,
				Rarity = talent.Rarity,
				ForBoonInfo = true
			})
		end)
	end

	-- Add talent name
	local talentName = GetDisplayName({Text = talent.Name}) or talent.Name
	spokenText = talentName

	-- Add state (invested, queued, or available)
	if talent.Invested then
		spokenText = spokenText .. ", " .. (GetDisplayName({ Text = "On" }) or "On")
	elseif talent.QueuedInvested then
		spokenText = spokenText .. ", " .. (GetDisplayName({ Text = "On" }) or "On") .. " " .. (GetDisplayName({ Text = "Queued" }) or "Queued")
	else
		-- Check if it has prerequisites met
		local hasPreRequisites = true
		if talent.LinkFrom and screen and screen.Components and button.TalentColumn then
			hasPreRequisites = false
			for _, preReqIndex in pairs(talent.LinkFrom) do
				local preReqButton = screen.Components["TalentObject"..(button.TalentColumn-1).."_"..preReqIndex]
				if preReqButton and preReqButton.Data and (preReqButton.Data.Invested or preReqButton.Data.QueuedInvested) then
					hasPreRequisites = true
					break
				end
			end
		end

		if hasPreRequisites then
			spokenText = spokenText .. ", " .. (GetDisplayName({ Text = "Off" }) or "Off")
			-- Add cost info
			if CurrentRun and CurrentRun.NumTalentPoints ~= nil then
				local costText = GetDisplayName({ Text = "Cost" }) or "Cost"
				local pointsText = GetDisplayName({Text = "AdditionalTalentPointDisplay"}) or "points"
				spokenText = spokenText .. ", " .. costText .. " " .. (CurrentRun.NumTalentPoints + 1) .. " " .. pointsText
			end
		else
			spokenText = spokenText .. ", " .. (GetDisplayName({Text = "AwardMenuLocked"}) or "Locked")
		end
	end

	-- Add description as transparent text
	pcall(function()
		CreateTextBox({
			Id = button.Id,
			Text = spokenText,
			Color = Color.Transparent,
		})
	end)

	-- Add the actual talent description
	if talent.Name then
		pcall(function()
			local descriptionText = GetDisplayName({Text = talent.Name, UseDescription = false})
			if descriptionText and descriptionText ~= "" and descriptionText ~= talentName then
				CreateTextBox({
					Id = button.Id,
					Text = descriptionText,
					Color = Color.Transparent,
				})
			end
		end)
	end

	-- Add linked talents information
	if talent.LinkTo and button.TalentColumn and screen and screen.Components then
		pcall(function()
			local linkText = GetDisplayName({ Text = "LeadsTo" }) or "Leads to"
			local linkedNames = {}
			for k,v in pairs(talent.LinkTo) do
				local linkedButton = screen.Components["TalentObject" .. (button.TalentColumn + 1) .."_"..v]
				if linkedButton and linkedButton.Data and linkedButton.Data.Name then
					table.insert(linkedNames, GetDisplayName({Text = linkedButton.Data.Name}) or linkedButton.Data.Name)
				end
			end
			if #linkedNames > 0 then
				linkText = linkText .. " " .. table.concat(linkedNames, ", ")
				CreateTextBox({
					Id = button.Id,
					Text = linkText,
					Color = Color.Transparent,
				})
			end
		end)
	end
end

function override_HecateHideAndSeekExit(source, args)
	args = args or {}

	SetAnimation({ Name = "HecateHubGreet", DestinationId = source.ObjectId })
	PlaySound({ Name = "/SFX/Player Sounds/IrisDeathMagic" })
	PlaySound({ Name = "/Leftovers/Menu Sounds/TextReveal2" })

	Teleport({ Id = source.ObjectId, DestinationId = args.TeleportId })
	SetAnimation({ Name = "Hecate_Hub_Hide_Start", DestinationId = source.ObjectId })
	SetAlpha({ Id = source.ObjectId, Fraction = 1.0, Duration = 0 })
	RefreshUseButton( source.ObjectId, source )
	StopStatusAnimation( source )
	UseableOn({Id = source.ObjectId})
	-- thread( HecateHideAndSeekHint )
end

function wrap_UseableOff(baseFunc, args) 
	if GetMapName({}) == "Flashback_Hub_Main" and args.Id == 0 then
		return baseFunc()
	end
	return baseFunc(args)
end

function override_ExorcismSequence( source, exorcismData, args, user )
	local totalCheckFails = 0
	local consecutiveCheckFails = 0
	local prevAnim = "Melinoe_Tablet_Idle"

	if exorcismData.MoveSequence == nil then
		return false
	end

	for i, move in ipairs( exorcismData.MoveSequence ) do
		rom.tolk.silence()

		local consecutiveMistakes = 0
		local reactionTime
		if config.Exorcism.Time == 0 then
			-- If Time is 0, go with the game's default.
			local gameFailCount = exorcismData.ConsecutiveCheckFails or 14
			reactionTime = gameFailCount * (exorcismData.InputCheckInterval or 0.1)
		else
			reactionTime = config.Exorcism.Time or 2.0
		end
		move.EndTime = _worldTime + reactionTime

		ExorcismNextMovePresentation( source, args, user, move )
		if config.Exorcism.Speak then
			local outputText = ""
			if move.Left and move.Right then
				outputText = config.Exorcism.CueBoth
			elseif move.Left then
				outputText = config.Exorcism.CueLeft
			elseif move.Right then
				outputText = config.Exorcism.CueRight
			end

			if outputText == nil or outputText == "" then
				-- Use shortened button prompts for faster reading
				if move.Left and move.Right then
					outputText = "both"
				elseif move.Left then
					outputText = "left"
				elseif move.Right then
					outputText = "right"
				end
			end

			rom.tolk.output(outputText)
		end

		local succeedCheck = false
		while _worldTime < move.EndTime do
			wait( exorcismData.InputCheckInterval or 0.1 )

			if user.ExorcismDamageTaken then
				return false
			end

			local isLeftDown = IsControlDown({ Name = "ExorcismLeft" })
			local isRightDown = IsControlDown({ Name = "ExorcismRight" })
			local targetAnim = nil
			if isLeftDown and isRightDown then
				targetAnim = "Melinoe_Tablet_Both_Start"
			elseif isLeftDown then
				targetAnim = "Melinoe_Tablet_Left_Start"
			elseif isRightDown then
				targetAnim = "Melinoe_Tablet_Right_Start"
			else
				if prevAnim == "Melinoe_Tablet_Both_Start" then
					targetAnim = "Melinoe_Tablet_Both_End"
				elseif prevAnim == "Melinoe_Tablet_Left_Start" then
					targetAnim = "Melinoe_Tablet_Left_End"
				elseif prevAnim == "Melinoe_Tablet_Right_Start" then
					targetAnim = "Melinoe_Tablet_Right_End"
				end
			end
			local nextAnim = nil
			if targetAnim ~= nil and targetAnim ~= prevAnim then
				nextAnim = targetAnim
			end
			if nextAnim ~= nil then
				SetAnimation({ Name = nextAnim, DestinationId = user.ObjectId })
				prevAnim = nextAnim
			end

			local isLeftCorrect = move.Left == isLeftDown
			local isRightCorrect = move.Right == isRightDown

			ExorcismInputCheckPresentation( source, args, user, move, isLeftCorrect, isRightCorrect, isLeftDown, isRightDown, consecutiveCheckFails, exorcismData )

			if isLeftCorrect and isRightCorrect then
				consecutiveCheckFails = 0
				consecutiveMistakes = 0
				if not succeedCheck then
					succeedCheck = true
					move.EndTime = _worldTime + (move.Duration or 0.4)
				end
			else
				succeedCheck = false
				consecutiveCheckFails = consecutiveCheckFails + 1

				if config.Exorcism.Failure == true then
					local isPressingAnyButton = IsControlDown({ Name = "ExorcismLeft" }) or IsControlDown({ Name = "ExorcismRight" })

					if isPressingAnyButton then
						consecutiveMistakes = consecutiveMistakes + 1
						totalCheckFails = totalCheckFails + 1
						if totalCheckFails >= (exorcismData.TotalCheckFails or 99) or consecutiveMistakes >= (exorcismData.ConsecutiveCheckFails or 14) then
							thread( DoRumble, { { LeftTriggerStrengthFraction = 0.0, RightTriggerStrengthFraction = 0.0, }, } )
							return false
						end
					end
				end
			end
		end

		if not succeedCheck then
			thread( DoRumble, { { LeftTriggerStrengthFraction = 0.0, RightTriggerStrengthFraction = 0.0, }, } )
			return false
		end
		local key = "MovePipId"..move.Index
		SetAnimation({ Name = "ExorcismPip_Full", DestinationId = source[key] })
		if move.Left and move.Right then
			CreateAnimation({ Name = "ExorcismSuccessHandLeft", DestinationId = CurrentRun.Hero.ObjectId })
			CreateAnimation({ Name = "ExorcismSuccessHandRight", DestinationId = CurrentRun.Hero.ObjectId })
		elseif move.Left then
			CreateAnimation({ Name = "ExorcismSuccessHandLeft", DestinationId = CurrentRun.Hero.ObjectId })
		elseif move.Right then
			CreateAnimation({ Name = "ExorcismSuccessHandRight", DestinationId = CurrentRun.Hero.ObjectId })
		end
	end

	return true
end
function sjson_Chronos(data)
	for k, v in ipairs(data.Projectiles) do
		if v.Name == "ChronosCircle" or v.Name == "ChronosCircleInverted" then
			v.Damage = 50
		end
	end
end

function wrap_Damage(baseFunc, victim, triggerArgs)
	-- Check if no trap damage is enabled and victim is the hero
	if config.NoTrapDamage and victim.ObjectId == game.CurrentRun.Hero.ObjectId then
		-- Check if the attacker is a trap (inherits from BaseTrap)
		local attacker = triggerArgs.AttackerTable
		if attacker and attacker.Name then
			-- Check if this is a trap by looking at the UnitSetData.Traps table
			if game.UnitSetData and game.UnitSetData.Traps and game.UnitSetData.Traps[attacker.Name] then
				-- This is a trap, prevent damage entirely by returning early
				return
			end
		end

		-- Check for lava-based trap damage (projectiles only, not enemy attacks)
		local lavaProjectiles = {
			"LavaSplash",
			"LavaTileWeapon",
			"LavaTileTriangle01Weapon",
			"LavaTileTriangle02Weapon",
			"LavaPuddleLarge"
		}

		-- Check if damage source is a lava projectile
		if triggerArgs.SourceProjectile then
			for _, lavaName in ipairs(lavaProjectiles) do
				if triggerArgs.SourceProjectile == lavaName then
					return
				end
			end
		end

		-- Check if damage source weapon is lava-based
		if triggerArgs.SourceWeapon then
			for _, lavaName in ipairs(lavaProjectiles) do
				if triggerArgs.SourceWeapon == lavaName then
					return
				end
			end
		end
	end

	-- Call the original function for non-trap damage
	local result = baseFunc(victim, triggerArgs)

	-- Check and announce HP for player (HP announcements enabled)
	if victim and game.CurrentRun and game.CurrentRun.Hero and victim.ObjectId == game.CurrentRun.Hero.ObjectId then
		print("Player took damage, calling CheckAndPlayHPSound")
		CheckAndPlayHPSound()
	end

	-- Check and announce HP for bosses and mini-bosses (HP announcements enabled)
	if victim and (victim.IsBoss or victim.IsElite) then
		print("Boss/Elite took damage, calling CheckBossHealth")
		CheckBossHealth(victim)
	end

	return result
end

-- Bounty Board (Pitch-Black Stone) accessibility function
function wrap_MouseOverBounty(button)
	if not button or not button.Data or not button.Screen or not button.Screen.Components then
		return
	end

	local bountyData = button.Data
	local screen = button.Screen
	local bountyComplete = (GameState.PackagedBountyClears[bountyData.Name] ~= nil)

	-- The base game function has already run, all components exist
	-- Clear all screen component text boxes to prevent TOLK from reading them
	-- We'll put all text on button.Id instead

	-- Clear ItemTitleText (shows name)
	if screen.Components.ItemTitleText and screen.Components.ItemTitleText.Id then
		ModifyTextBox({ Id = screen.Components.ItemTitleText.Id, Text = " " })
	end

	-- Clear DescriptionText (shows description)
	if screen.Components.DescriptionText and screen.Components.DescriptionText.Id then
		ModifyTextBox({ Id = screen.Components.DescriptionText.Id, Text = " " })
	end

	-- Clear WeaponIconBacking text
	if screen.Components.WeaponIconBacking and screen.Components.WeaponIconBacking.Id then
		ModifyTextBox({ Id = screen.Components.WeaponIconBacking.Id, Text = " " })
	end

	-- Clear LocationIcon text
	if screen.Components.LocationIcon and screen.Components.LocationIcon.Id then
		ModifyTextBox({ Id = screen.Components.LocationIcon.Id, Text = " " })
	end

	-- Clear KeepsakeIcon text
	if screen.Components.KeepsakeIcon and screen.Components.KeepsakeIcon.Id then
		ModifyTextBox({ Id = screen.Components.KeepsakeIcon.Id, Text = " " })
	end

	-- Don't destroy button.Id - just add text to it
	-- The base game modified an existing text box on button.Id
	-- We'll append additional info by calling CreateTextBox multiple times

	-- Add the name first
	local bountyName = bountyData.Name
	CreateTextBox({
		Id = button.Id,
		Text = bountyName,
		SkipDraw = true,
		SkipWrap = true,
		Color = Color.Transparent
	})

	-- Add description with full text (remove _Short suffix)
	local textKey = bountyData.Text or bountyData.Name
	if textKey then
		local descriptionKey = textKey:gsub("_Short$", "")
		CreateTextBox({
			Id = button.Id,
			Text = descriptionKey,
			UseDescription = true,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})
	end

	-- Add weapon information
	if bountyData.WeaponKitName then
		local weaponName = bountyData.WeaponKitName
		if GameState.WorldUpgrades and GameState.WorldUpgrades.WorldUpgradeWeaponUpgradeSystem and bountyData.WeaponUpgradeName then
			weaponName = bountyData.WeaponUpgradeName
		end
		local weaponDisplayName = GetDisplayName({ Text = weaponName, IgnoreSpecialFormatting = true })
		CreateTextBox({
			Id = button.Id,
			Text = "Weapon: " .. weaponDisplayName,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})
	elseif bountyData.RandomWeaponKitNames then
		local randomWeapon = GetDisplayName({ Text = "BountyBoard_RandomWeapon", IgnoreSpecialFormatting = true })
		CreateTextBox({
			Id = button.Id,
			Text = "Weapon: " .. randomWeapon,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})
	end

	-- Add biome information
	if bountyData.StartingBiome then
		local biomeTextKey = bountyData.BiomeText or ("Biome" .. bountyData.StartingBiome)
		local biomeName = GetDisplayName({ Text = biomeTextKey, IgnoreSpecialFormatting = true })
		CreateTextBox({
			Id = button.Id,
			Text = "Biome: " .. biomeName,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})

		-- Add biome description
		local biomeDescription = GetDisplayName({ Text = biomeTextKey, IgnoreSpecialFormatting = true, UseDescription = true })
		if biomeDescription and biomeDescription ~= "" and biomeDescription ~= biomeName then
			CreateTextBox({
				Id = button.Id,
				Text = biomeDescription,
				SkipDraw = true,
				SkipWrap = true,
				Color = Color.Transparent
			})
		end
	end

	-- Add keepsake information
	if bountyData.KeepsakeName then
		local keepsakeDisplayName = GetDisplayName({ Text = bountyData.KeepsakeName, IgnoreSpecialFormatting = true })
		CreateTextBox({
			Id = button.Id,
			Text = "Keepsake: " .. keepsakeDisplayName,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})
	elseif bountyData.RandomKeepsakeNames then
		local randomKeepsake = GetDisplayName({ Text = "BountyBoard_RandomKeepsake", IgnoreSpecialFormatting = true })
		CreateTextBox({
			Id = button.Id,
			Text = "Keepsake: " .. randomKeepsake,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})
	end

	-- Add reward information
	local dropData = nil
	if bountyData.LootOptions then
		local loot = bountyData.LootOptions[1]
		if loot.Overrides and loot.Overrides.AddResources then
			dropData = loot.Overrides
		else
			dropData = ConsumableData[loot.Name]
		end
	elseif bountyComplete and GameState.WorldUpgrades and GameState.WorldUpgrades.WorldUpgradeBountyBoardRepeat then
		dropData = ConsumableData[bountyData.ForcedRewardRepeat]
	else
		dropData = ConsumableData[bountyData.ForcedReward]
	end

	if dropData and dropData.AddResources then
		local resourceName = GetFirstKey(dropData.AddResources)
		local resourceAmount = dropData.AddResources[resourceName]
		local resourceDisplayName = GetDisplayName({ Text = resourceName, IgnoreSpecialFormatting = true })

		local rewardLabel = GetDisplayName({ Text = "RunReward", IgnoreSpecialFormatting = true }) or "Reward"
		CreateTextBox({
			Id = button.Id,
			Text = rewardLabel .. ": " .. resourceAmount .. " " .. resourceDisplayName,
			SkipDraw = true,
			SkipWrap = true,
			Color = Color.Transparent
		})
	end
end




