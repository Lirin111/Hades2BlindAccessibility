---@meta _
---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- this file will be reloaded if it changes during gameplay,
-- 	so only assign to values or define things here.

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

function wrap_InventoryScreenDisplayCategory(screen, categoryIndex, args)
	args = args or {}
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
			return
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
				Id = button.Id,
				Text = GetDisplayName({ Text = resourceName, IgnoreSpecialFormatting = true }) ..
				": " .. (GameState.Resources[resourceName] or 0) .. ", " .. statusText,
				UseDescription = false
			})

			-- Create a second text box with the details description
			local detailsKey = resourceName .. "_Details"
			CreateTextBox({
				Id = button.Id,
				Text = detailsKey,
				UseDescription = true,
				OffsetY = 0,
				FontSize = 1,
				Color = {0, 0, 0, 0},  -- Invisible
				SkipDraw = true
			})

			-- Create a third text box with the flavor text
			local flavorKey = resourceName .. "_Flavor"
			CreateTextBox({
				Id = button.Id,
				Text = flavorKey,
				UseDescription = true,
				OffsetY = 0,
				FontSize = 1,
				Color = {0, 0, 0, 0},  -- Invisible
				SkipDraw = true
			})
		end
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

	if TableLength(MapState.OfferedExitDoors) == 0 and GetMapName() ~= "Hub_Main" and not hasAsphodelExit then
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


	CreateAssesDoorButtons(screen, doors)
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
	local inHouse = GetMapName():find("I_") == 1
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
		Text = "Health: " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0),
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
		Text = "Armor: " .. (CurrentRun.Hero.HealthBuffer or 0),
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
		Text = "Gold: " .. (GameState.Resources["Money"] or 0),
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
		Text = "Mana: " .. (CurrentRun.Hero.Mana or 0) .. "/" .. (CurrentRun.Hero.MaxMana or 0),
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
		if string.find(GetMapName(), "D_Hub") then
			if door.Room.Name:find("D_Boss", 1, true) == 1 and GetDistance({ Id = 547487, DestinationId = 551569 }) ~= 0 then
				showDoor = false
			end
		end
		if showDoor then
			local displayText = ""
			if inShip then
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
			if inCityHub and curY > 900 then
				curY = startY + yIncrement * 3 + 30
				curX = curX + 250
			end
		end
	end
end

function rom.game.BlindAccessCloseAssesDoorShowerScreen(screen, button)
	SetConfigOption({ Name = "ExclusiveInteractGroup", Value = nil })
	OnScreenCloseStarted(screen)
	CloseScreen(GetAllIds(screen.Components), 0.15)
	OnScreenCloseFinished(screen)
	notifyExistingWaiters(screen.Name)
	ShowCombatUI(screen.Name)
end

function rom.game.BlindAccessAssesDoorMenuSoundSet(screen, button)
	PlaySound({ Name = "/SFX/Menu Sounds/ContractorItemPurchase" })
	rom.game.BlindAccessCloseAssesDoorShowerScreen(screen, button)
	doDefaultSound(button.door)
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
	if GetMapName():find("O_") == 1 then
		return "MetaUpgrade_UpgradesAvailable_Close"
	elseif door.Room.Name == "FinalBossExitDoor" or door.Room.Name == "E_Intro" then
		return "Greece"
	elseif room.NextRoomSet and room.Name:find("D_Boss", 1, true) ~= 1 then
		return "Stairway"
	elseif room.Name:find("_Intro", 1, true) ~= nil then
		return "Next Biome"
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
			-- Add lore interactables (InspectPoints) for Crossroads
			copy = AddInspectPoints(copy)
			return copy
		end,
		Objects = {
			{ Name = "QuestLog_Unlocked_Subtitle", ObjectId = 560662, DestinationOffsetY = -120 },
			{ Name = "GhostAdminScreen_Title",     ObjectId = 567390, DestinationOffsetY = 137, RequireUseable = false },
			{ Name = "Broker",                     ObjectId = 558096, DestinationOffsetX = 140, DestinationOffsetY = 35 },
			{ Name = "Supply Drop",                ObjectId = 583652, DestinationOffsetX = 117, DestinationOffsetY = -64 }, --No direct translation in sjson
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
			{ Name = "RunHistoryScreen_RouteN",         ObjectId = 587935, DestinationOffsetX = -162, DestinationOffsetY = 194, RequireUseable = false },
			{ Name = "ShrineMenu",                      ObjectId = 589694, DestinationOffsetY = 90 },
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
		if map_name == currMap or map_name == "*" then
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

	if CurrentRun and CurrentRun.CurrentRoom and (CurrentRun.CurrentRoom.ExitsUnlocked or inAsphodel) then
		t = AddTrove(t)
		t = AddWell(t)
		t = AddSurfaceShop(t)
		t = AddPool(t)
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

function AddNPCs(objects)
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
	-- thread(HandleWASDInput, screen)
	HandleScreenInput(screen)
	-- SetConfigOption({ Name = "ExclusiveInteractGroup", Value = "Menu_UI" })
end

function CreateRewardButtons(screen, rewards)
	local xPos = 960
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
			Text = "Health: " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0),
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
			Text = "Armor: " .. (CurrentRun.Hero.HealthBuffer or 0),
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
			Text = "Gold: " .. (GameState.Resources["Money"] or 0),
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
			Text = "Mana: " .. (CurrentRun.Hero.Mana or 0) .. "/" .. (CurrentRun.Hero.MaxMana or 0),
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
		local displayText = reward.Name
		local buttonKey = "RewardMenuButton" .. k .. displayText
		components[buttonKey] =
			CreateScreenComponent({
				Name = "ButtonDefault",
				Group = "Menu_UI_Rewards",
				Scale = 0.8,
				X = xPos,
				Y = curY
			})

		SetScaleX({ Id = components[buttonKey].Id, Fraction = 4 })
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
			FontSize = 24,
			OffsetX = -200,
			OffsetY = 0,
			Color = Color.White,
			Font = "P22UndergroundSCMedium",
			Group = "Menu_UI_Rewards",
			ShadowBlur = 0,
			ShadowColor = { 0, 0, 0, 1 },
			ShadowOffset = { 0, 2 },
			Justification = "Left",
		})


		if reward.IsShopItem then
			CreateTextBox({
				Id = components[buttonKey].Id,
				Text = reward.ResourceCosts.Money .. " Gold",
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
		end

		if isFirstButton then
			TeleportCursor({ OffsetX = xPos + 300, OffsetY = curY })
			wait(0.2)
			TeleportCursor({ OffsetX = xPos, OffsetY = curY })
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
			if name:find("Door") or name:find("Exit") then
				destinationOffsetY = -120 -- Further back for doors
			elseif name:find("Loot") or name:find("Reward") then
				destinationOffsetY = -60  -- Closer for loot
			elseif name:find("Store") or name:find("Shop") then
				destinationOffsetY = -100 -- Good distance for shops
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
		Text = "Health: " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0),
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
		Text = "Armor: " .. (CurrentRun.Hero.HealthBuffer or 0),
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
		Text = "Gold: " .. (GameState.Resources["Money"] or 0),
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
		Text = "Mana: " .. (CurrentRun.Hero.Mana or 0) .. "/" .. (CurrentRun.Hero.MaxMana or 0),
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
				Text = item.ResourceCosts.Money .. " Gold",
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
							table.insert(rewardsTable,
								{ IsShopItem = true, Name = v.Name, ObjectId = v.ObjectId, ResourceCosts = v
								.ResourceCosts })
							blockedIds[v.ObjectId] = true
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
	if IsEmpty(ActiveScreens) then
		if not IsEmpty(MapState.CombatUIHide) or not IsInputAllowed({}) then
			-- If no screen is open, controlled entirely by input status
			return
		end
	end
	local rewardsTable = {}
	if CurrentRun ~= nil and CurrentRun.Hero ~= nil and CurrentRun.Hero.IsDead and not IsScreenOpen("InventoryScreen") and not IsScreenOpen("BlindAccesibilityInventoryMenu") then
		rewardsTable = ProcessTable(ModUtil.Table.Merge(LootObjects, MapState.RoomRequiredObjects))
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
			table.insert(CurrentRun.CurrentRoom.Store.SpawnedStoreItems,
				--MOD START
				{ KitId = kitId, ObjectId = spawnedItem.ObjectId, OriginalResourceCosts = spawnedItem.BaseResourceCosts, ResourceCosts = spawnedItem.ResourceCosts, Name =
				itemData.Name })
			--MOD END
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
	local button = components.MemCostModule
	if button.Id and MetaUpgradeCostData.MetaUpgradeLevelData[GetCurrentMetaUpgradeLimitLevel() + 1] then
		local nextCostData = MetaUpgradeCostData.MetaUpgradeLevelData[GetCurrentMetaUpgradeLimitLevel() + 1]
		.ResourceCost
		local nextMetaUpgradeLevel = MetaUpgradeCostData.MetaUpgradeLevelData[GetCurrentMetaUpgradeLimitLevel() + 1]

		local costText = GetDisplayName({ Text = "CannotUseChaosWeaponUpgrade", IgnoreSpecialFormatting = true }) --cheating here, this is just "Requires: {Hammer Icon}" and we just remove the Hammer Icon

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


	local availableItems = {}
	local boughtItems = {}

	CurrentRun.ViewableWorldUpgrades = CurrentRun.ViewableWorldUpgrades or {}
	for i, cosmeticName in ipairs(screen.ItemCategories[button.CategoryIndex]) do
		local cosmeticData = WorldUpgradeData[cosmeticName]
		if GhostAdminAllowViewItem(screen, category, cosmeticData) then
			if GameState.WorldUpgradesAdded[cosmeticName] and not cosmeticData.Repeatable then
				table.insert(boughtItems, cosmeticData)
			else
				table.insert(availableItems, cosmeticData)
			end
		end
	end

	local currentIndex = 0
	for k, v in pairs(availableItems) do
		currentIndex = currentIndex + 1

		local purchaseButtonKey = "PurchaseButton" .. currentIndex
		local button = screen.Components[purchaseButtonKey]

		-- Skip if button doesn't exist
		if not button then
			goto continue
		end

		local name = v.Name
		local displayName = GetDisplayName({ Text = name, IgnoreSpecialFormatting = true })

		local itemNameFormat = ShallowCopyTable(screen.ItemAvailableAffordableNameFormat)
		itemNameFormat.Id = button.Id

		local costText = GetDisplayName({ Text = "CannotUseChaosWeaponUpgrade", IgnoreSpecialFormatting = true }) --cheating here, this is just "Requires: {Hammer Icon}" and we just remove the Hammer Icon

		for k, v in pairs(v.Cost) do
			costText = costText .. " " .. v .. " " .. GetDisplayName({ Text = k, IgnoreSpecialFormatting = true }) .. ","
		end
		costText = costText:sub(1, -2) --remove final comma

		itemNameFormat.Text = displayName .. " " .. costText

		DestroyTextBox({ Id = button.Id })
		CreateTextBox(itemNameFormat)

		-- Hidden description for tooltip
		CreateTextBox({
			Id = button.Id,
			Text = name,
			UseDescription = true,
			Color = Color.Transparent,
			LuaKey = "TooltipData",
			LuaValue = v,
		})
		::continue::
	end

	for k, v in pairs(boughtItems) do
		currentIndex = currentIndex + 1

		local purchaseButtonKey = "PurchaseButton" .. currentIndex
		local button = screen.Components[purchaseButtonKey]

		-- Skip if button doesn't exist
		if not button then
			goto continue2
		end

		local name = v.Name
		local displayName = GetDisplayName({ Text = name, IgnoreSpecialFormatting = true })

		local itemNameFormat = ShallowCopyTable(screen.ItemAvailableAffordableNameFormat)
		itemNameFormat.Id = button.Id

		itemNameFormat.Text = displayName ..
		", ," .. GetDisplayName({ Text = "On", IgnoreSpecialFormatting = true }) .. ", ,"

		DestroyTextBox({ Id = button.Id })
		CreateTextBox(itemNameFormat)

		-- Hidden description for tooltip
		CreateTextBox({
			Id = button.Id,
			Text = name,
			UseDescription = true,
			Color = Color.Transparent,
			LuaKey = "TooltipData",
			LuaValue = v,
		})
		::continue2::
	end
end

function override_GhostAdminScreenRevealNewItemsPresentation(screen, button)
	-- Immediate parameter validation before any operations
	if not screen then
		return
	end

	AddInputBlock({ Name = "GhostAdminScreenRevealNewItemspResentation" })

	-- Add comprehensive safety checks for screen object and handle new data structures
	if not screen.Components then
		RemoveInputBlock({ Name = "GhostAdminScreenRevealNewItemspResentation" })
		return
	end

	if not screen.AvailableItems then
		RemoveInputBlock({ Name = "GhostAdminScreenRevealNewItemspResentation" })
		return
	end

	-- Handle cases where ScrollOffset or ItemsPerPage might be nil or zero
	local scrollOffset = screen.ScrollOffset or 1
	local itemsPerPage = screen.ItemsPerPage or 0

	if itemsPerPage <= 0 then
		RemoveInputBlock({ Name = "GhostAdminScreenRevealNewItemspResentation" })
		return
	end

	-- Ensure we don't access beyond available items
	local maxItems = #screen.AvailableItems or 0
	if maxItems <= 0 then
		RemoveInputBlock({ Name = "GhostAdminScreenRevealNewItemspResentation" })
		return
	end

	local components = screen.Components

	-- Reveal new items with bounds checking
	local endIndex = math.min(scrollOffset + itemsPerPage, maxItems)

	-- Reveal new items
	--for itemNum, item in ipairs( screen.AvailableItems ) do
	for itemNum = scrollOffset, endIndex do
		local item = screen.AvailableItems[itemNum]
		if item ~= nil and item.Name and GameState and GameState.WorldUpgradesRevealed and not GameState.WorldUpgradesRevealed[item.Name] then
			local purchaseButtonKey = "PurchaseButton" .. itemNum
			if components[purchaseButtonKey] ~= nil then
				SetAlpha({ Id = components[purchaseButtonKey].Id, Fraction = 0, Duration = 0 })
			end
			local iconKey = "Icon" .. itemNum
			if components[iconKey] ~= nil then
				SetAlpha({ Id = components[iconKey].Id, Fraction = 0, Duration = 0 })
			end
			local newIconKey = "NewIcon" .. itemNum
			if components[newIconKey] ~= nil then
				SetAlpha({ Id = components[newIconKey].Id, Fraction = 0, Duration = 0 })
			end
		end
	end
	local incantationsRevealed = false
	for itemNum = scrollOffset, endIndex do
		local item = screen.AvailableItems[itemNum]
		if item ~= nil and item.Name and GameState and GameState.WorldUpgradesRevealed and not GameState.WorldUpgradesRevealed[item.Name] then
			local purchaseButtonKey = "PurchaseButton" .. itemNum
			if components[purchaseButtonKey] ~= nil then
				ModifyTextBox({ Id = components[purchaseButtonKey].Id, FadeOpacity = 0.0, FadeTarget = 1.0, FadeDuration = 0.05 })
				SetAlpha({ Id = components[purchaseButtonKey].Id, Fraction = 1, Duration = 0 })
				SetAnimation({ Name = "CriticalItemShopButtonReveal", DestinationId = components[purchaseButtonKey].Id, OffsetX = 0, })
			end

			thread(PlayVoiceLines, item.OfferedVoiceLines, true)

			local iconKey = "Icon" .. itemNum
			if components[iconKey] ~= nil then
				SetAlpha({ Id = components[iconKey].Id, Fraction = 1, Duration = 0.05 })
			end
			local newIconKey = "NewIcon" .. itemNum
			if components[newIconKey] ~= nil then
				SetAlpha({ Id = components[newIconKey].Id, Fraction = 1, Duration = 0.05 })
			end
			if CurrentRun and CurrentRun.WorldUpgradesRevealed then
				CurrentRun.WorldUpgradesRevealed[item.Name] = true
			end
			if GameState and GameState.WorldUpgradesRevealed then
				GameState.WorldUpgradesRevealed[item.Name] = true
			end
			incantationsRevealed = true
			-- wait( 0.9 )
		end
	end
	if incantationsRevealed and HeroVoiceLines and HeroVoiceLines.CauldronSpellDiscoveredVoiceLines then
		thread(PlayVoiceLines, HeroVoiceLines.CauldronSpellDiscoveredVoiceLines, true)
	end
	wait(0.2) -- Need to wait for last reveal animation to fully finish
	RemoveInputBlock({ Name = "GhostAdminScreenRevealNewItemspResentation" })
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

	local firstUseable = false
	for itemIndex = 1, numButtons do
		local upgradeData = CurrentRun.CurrentRoom.Store.StoreOptions[itemIndex]

		if upgradeData ~= nil then
			if not upgradeData.Processed then
				if upgradeData.Type == "Consumable" then
					if ConsumableData[upgradeData.Name] then
						upgradeData = GetRampedConsumableData(ConsumableData[upgradeData.Name])
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
				local costMultiplier = 1 + (MetaUpgradeData.ShopPricesShrineUpgrade.ChangeValue - 1)
				costMultiplier = costMultiplier *
				GetTotalHeroTraitValue("StoreCostMultiplier", { IsMultiplier = true, Multiplicative = true })
				for resourceName, resourceAmount in pairs(upgradeData.ResourceCosts) do
					local baseCost = round(resourceAmount * costMultiplier)
					local penaltyCost = round(resourceAmount * costMultiplier * SurfaceShopData.ImpatienceMultiplier)
					upgradeData.ResourceCosts[resourceName] = round(baseCost * delayCostMultiplier)
					upgradeData.SpeedUpResourceCosts[resourceName] = (penaltyCost - round(baseCost * delayCostMultiplier))
				end


				upgradeData.Processed = true
			end

			CurrentRun.CurrentRoom.Store.StoreOptions[itemIndex] = upgradeData
			local tooltipData = upgradeData


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

			if GetSurfaceShopIcon(upgradeData) ~= nil then
				local icon = DeepCopyTable(ScreenData.UpgradeChoice.Icon)
				icon.X = itemLocationX + ScreenData.UpgradeChoice.IconOffsetX
				icon.Y = itemLocationY + ScreenData.UpgradeChoice.IconOffsetY
				icon.Animation = GetSurfaceShopIcon(upgradeData)
				components["Icon" .. itemIndex] = CreateScreenComponent(icon)
			end

			local iconKey = "HermesSpeedUp" .. itemIndex
			components[iconKey] = CreateScreenComponent({ Name = "BlankObstacle", X = itemLocationX - 313 + 560, Y =
			itemLocationY - 50, Group = "Combat_Menu" })

			if upgradeData.Purchased then
				SetAnimation({ DestinationId = components[iconKey].Id, Name = "SurfaceShopBuyNowSticker" })
			end

			local itemBackingKey = "Backing" .. itemIndex
			components[itemBackingKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X =
			itemLocationX + itemLocationTextBoxOffset, Y = itemLocationY })

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

			SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value =
			ScreenData.UpgradeChoice.TooltipOffsetX })

			local deliveryDuration = "PendingDeliveryDuration"
			if upgradeData.Purchased then
				deliveryDuration = "SpeedUpDelivery"
			end

			-- local title = GetDescriptionName({Text = })
			local title = GetDisplayName({Text=GetSurfaceShopText(upgradeData)})
			local cost = costString
			local time = GetDisplayName({Text=deliveryDuration}):gsub("TempTextData.Delay", upgradeData.RoomDelay)

			local titleText = DeepCopyTable(ScreenData.UpgradeChoice.DescriptionText)
			titleText.Id = components[purchaseButtonKey].Id
			titleText.Text = title .. ", " .. cost .. ", " .. time
			titleText.UseDescription = false
			CreateTextBoxWithFormat(titleText)

			local descriptionText = DeepCopyTable(ScreenData.UpgradeChoice.DescriptionText)
			descriptionText.Id = components[purchaseButtonKey].Id
			descriptionText.OffsetY = 10
			descriptionText.Text = GetSurfaceShopText( upgradeData )
			descriptionText.LuaKey = "TooltipData"
			descriptionText.LuaValue = upgradeData
			descriptionText.UseDescription = false
			CreateTextBoxWithFormat(descriptionText)

			components[purchaseButtonKey].BlindAccessTitleText = title
			components[purchaseButtonKey].BlindAccessCostText = cost
			components[purchaseButtonKey].BlindAccessTimeText = time

			components[purchaseButtonKey].Data = upgradeData
			components[purchaseButtonKey].WeaponName = currentWeapon
			components[purchaseButtonKey].Index = itemIndex

			--these arent necessary for tolk, but other functions need it
			local purchaseButtonDeliveryKey = "PurchaseButtonDelivery"..itemIndex
			components[purchaseButtonDeliveryKey ] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			CreateTextBox(MergeTables({ Id = components[purchaseButtonDeliveryKey].Id, Text = deliveryDuration,
				FontSize = 18,
				OffsetX = -245, OffsetY = 80,
				Width = 720,
				Color = Color.White,
				Font = "LatoMedium",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				VerticalJustification = "BOTTOM",
				LuaKey = "TempTextData",
				LuaValue = { Delay = upgradeData.RoomDelay }
			}))

			local purchaseButtonTitleKey = "PurchaseButtonTitle"..itemIndex
			components[purchaseButtonTitleKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX, Y = itemLocationY })
			local titleText = DeepCopyTable(ScreenData.UpgradeChoice.DescriptionText)
			titleText.Id = components[purchaseButtonTitleKey].Id
			titleText.Text = ""
			CreateTextBoxWithFormat(titleText)

			local purchaseButtonCostKey = "PurchaseButtonCost"..itemIndex
			components[purchaseButtonCostKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			
			CreateTextBox(MergeTables({ Id = components[purchaseButtonCostKey].Id, Text = costString, OffsetX = 410, OffsetY = -50, FontSize = 28, Color = costColor, Font = "P22UndergroundSCMedium", Justification = "Right" }))


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
	--[[
if HeroHasTrait( "PanelRerollMetaUpgrade" ) then
	local increment = 0
	if CurrentRun.CurrentRoom.SpentRerolls then
		increment = CurrentRun.CurrentRoom.SpentRerolls[CurrentRun.CurrentRoom.Store.Screen.Name] or 0
	end
	local cost = RerollCosts.Shop + increment

	local color = Color.White
	if CurrentRun.NumRerolls < cost or cost < 0 then
		color = Color.CostUnaffordable
	end
	if cost > 0 then
		components["RerollPanel"] = CreateScreenComponent({ Name = "ShopRerollButton", Scale = 1.0, Group = "Combat_Menu" })
		Attach({ Id = components["RerollPanel"].Id, DestinationId = components.ShopBackground.Id, OffsetX = -200, OffsetY = 440 })
		components["RerollPanel"].OnPressedFunctionName = "AttemptPanelReroll"
		components["RerollPanel"].RerollFunctionName = "RerollStore"
		components["RerollPanel"].Cost = cost
		components["RerollPanel"].RerollColor = {48, 25, 83, 255}
		components["RerollPanel"].RerollId = CurrentRun.CurrentRoom.Store.Screen.Name
		CreateTextBox({ Id = components["RerollPanel"].Id, Text = "RerollCount", OffsetX = 28, OffsetY = -5,
		ShadowColor = {0,0,0,1}, ShadowOffset={0,3}, OutlineThickness = 3, OutlineColor = {0,0,0,1},
		FontSize = 28, Color = color, Font = "P22UndergroundSCHeavy", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
		SetInteractProperty({ DestinationId = components["RerollPanel"].Id, Property = "TooltipOffsetX", Value = 850 })
		CreateTextBox({ Id = components["RerollPanel"].Id, Text = "MetaUpgradeRerollHint", Color = Color.Transparent, Font = "P22UndergroundSCHeavy", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
	end
end
]]
end

function wrap_HandleSurfaceShopAction(screen, button)
	local upgradeData = button.Data
	local costAmount = 0

	local title = button.BlindAccessTitleText
	local time = GetDisplayName({Text="SpeedUpDelivery"})

	DestroyTextBox({Id = button.Id})
	local costString = "@GUI\\Icons\\Currency"
	if upgradeData.ResourceCosts then 
		costAmount = GetResourceCost( upgradeData.SpeedUpResourceCosts, "Money")
		costString = costAmount .. " " .. costString
	end

	local titleText = DeepCopyTable(ScreenData.UpgradeChoice.DescriptionText)
	titleText.Id = button.Id
	titleText.Text = title .. ", " .. costString .. ", " .. time
	titleText.UseDescription = false
	CreateTextBoxWithFormat(titleText)

	local descriptionText = DeepCopyTable(ScreenData.UpgradeChoice.DescriptionText)
	descriptionText.Id = button.Id
	descriptionText.OffsetY = 10
	descriptionText.Text = GetSurfaceShopText( upgradeData )
	descriptionText.LuaKey = "TooltipData"
	descriptionText.LuaValue = upgradeData
	descriptionText.UseDescription = false
	CreateTextBoxWithFormat(descriptionText)

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
		local costAmount = upgradeData.ResourceCosts["Money"] or 0

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
			if not hasPreRequisites and talent.QueuedInvested then
				talent.QueuedInvested = nil		
			end
			local stateText = ""
			if talent.Invested or talent.QueuedInvested then
				stateText = GetDisplayName({ Text = "On" })
			elseif not talent.Invested then
				if hasPreRequisites then
					stateText = GetDisplayName({ Text = "Off" }) .. ", " .. (CurrentRun.NumTalentPoints + 1) .. " " .. GetDisplayName({Text = "AdditionalTalentPointDisplay"})
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

function wrap_UpdateTalentButtons(screen, skipUsableCheck)
	local components = screen.Components
	local firstUsable = skipUsableCheck

	-- Safety check: Ensure SlottedSpell exists before accessing Talents
	if not CurrentRun.Hero.SlottedSpell or not CurrentRun.Hero.SlottedSpell.Talents then
		return
	end

	for i, column in ipairs( CurrentRun.Hero.SlottedSpell.Talents ) do
		for s, talent in pairs( column ) do
			local talentObject = components["TalentObject"..i.."_"..s]
			DestroyTextBox({Id = talentObject.Id})
			local talent = talentObject.Data
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
			if not hasPreRequisites and talent.QueuedInvested then
				talent.QueuedInvested = nil		
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
			local descriptionText = GetDisplayName({Text = talent.Name, UseDescription = true})
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
				if move.Left then outputText = outputText .. GetDisplayName({Text = "ExorcismLeft"}) end
				if move.Right then outputText = outputText .. GetDisplayName({Text = "ExorcismRight"}) end
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
	end
	-- Call the original function for non-trap damage
	return baseFunc(victim, triggerArgs)
end
