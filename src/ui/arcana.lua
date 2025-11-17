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
