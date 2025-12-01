QBCore = nil

local Webhook = ''
local sessions = {}

TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)

RegisterServerEvent('okokCrafting:craftStartItem')
AddEventHandler('okokCrafting:craftStartItem',function()
	sessions[source] = {
		stoppedCraft = false,
		isCrafting = true,
		last = GetGameTimer(),
	}
end)

RegisterServerEvent('okokCrafting:craftStopItem')
AddEventHandler('okokCrafting:craftStopItem',function()
	sessions[source] = {
		stoppedCraft = true,
		isCrafting = false,
	}
end)

RegisterServerEvent('okokCrafting:failedCraft')
AddEventHandler('okokCrafting:failedCraft',function(item)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	if Webhook ~= '' then
		local identifierlist = ExtractIdentifiers(xPlayer.PlayerData.source)
		local data = {
			playerid = xPlayer.PlayerData.source,
			identifier = identifierlist.license:gsub("license2:", ""),
			discord = "<@"..identifierlist.discord:gsub("discord:", "")..">",
			type = "failed",
			item = item,
		}
		noSession(data)
	end
end)

RegisterServerEvent('okokCrafting:craftItemDeath')
AddEventHandler('okokCrafting:craftItemDeath',function(queueClient)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local queue = queueClient

	if sessions[source] then
		if sessions[source].stoppedCraft then
			for k,v in ipairs(queue) do
				for k2,v2 in ipairs(v.recipe) do
					xPlayer.Functions.AddItem(v2[1], v2[2])
				end
			end
			TriggerClientEvent('okokNotify:Alert', source, "CRAFTING", "You died, all crafting items were given back", 5000, 'info')
			sessions[xPlayer.PlayerData.source] = nil
		end
	else
		if Webhook ~= '' then
			local identifierlist = ExtractIdentifiers(xPlayer.PlayerData.source)
			local data = {
				playerid = xPlayer.PlayerData.source,
				identifier = identifierlist.license:gsub("license2:", ""),
				discord = "<@"..identifierlist.discord:gsub("discord:", "")..">",
				type = "Death",
			}
			noSession(data)
		end
		TriggerClientEvent('okokNotify:Alert', source, "CRAFTING", "No session!", 5000, 'error')
	end
			
end)

RegisterServerEvent('okokCrafting:craftItemFinished')
AddEventHandler('okokCrafting:craftItemFinished', function(item, crafts, itemName, isItem)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local timeToCraft = 600000
	local amount = 0

	if sessions[source] then
		for k,v in ipairs(crafts) do
			if v.item == item then
				amount = v.amount
				timeToCraft = v.time * 1000
			end
		end
		sessions[source].last = GetGameTimer() - sessions[source].last

		if sessions[source].last+500 >= timeToCraft then
			if isItem then
				xPlayer.Functions.AddItem(item, amount)
			else
				xPlayer.Functions.AddItem(item, 1)
			end
			if Webhook ~= '' then
				local identifierlist = ExtractIdentifiers(xPlayer.PlayerData.source)
				local data = {
					playerid = xPlayer.PlayerData.source,
					identifier = identifierlist.license:gsub("license2:", ""),
					discord = "<@"..identifierlist.discord:gsub("discord:", "")..">",
					type = "conclude-crafting",
					itemName = itemName,
					time = sessions[xPlayer.PlayerData.source].last,
				}
				noSession(data)
			end
			sessions[xPlayer.PlayerData.source] = nil
		else
			if Webhook ~= '' then
				local identifierlist = ExtractIdentifiers(xPlayer.PlayerData.source)
				local data = {
					playerid = xPlayer.PlayerData.source,
					identifier = identifierlist.license:gsub("license2:", ""),
					discord = "<@"..identifierlist.discord:gsub("discord:", "")..">",
					type = "crafted-soon",
					time_taken = sessions[source].last,
					time_needed = timeToCraft,
					itemName = itemName,
				}
				noSession(data)
			end
			TriggerClientEvent('okokNotify:Alert', source, "CRAFTING", "Anti-cheat protection!", 5000, 'error')
		end
	else
		if Webhook ~= '' then
			local identifierlist = ExtractIdentifiers(xPlayer.PlayerData.source)
			local data = {
				playerid = xPlayer.PlayerData.source,
				identifier = identifierlist.license:gsub("license2:", ""),
				discord = "<@"..identifierlist.discord:gsub("discord:", "")..">",
				type = "conclude",
			}
			noSession(data)
		end
		TriggerClientEvent('okokNotify:Alert', source, "CRAFTING", "No session!", 5000, 'error')
	end
			
end)

QBCore.Functions.CreateCallback("okokCrafting:inv2", function(source, cb, item)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local itemData = xPlayer.Functions.GetItemByName(item)
	local itemResult = {
		name = item,
		count = itemData and itemData.amount or 0
	}

	cb(itemResult)
end)

QBCore.Functions.CreateCallback("okokCrafting:itemNames", function(source, cb)
	local itemNames = {}
	local sharedItems = QBCore.Shared.Items

	for itemName, itemData in pairs(sharedItems) do
		itemNames[itemName] = itemData.label
	end

	cb(itemNames)
end)

QBCore.Functions.CreateCallback("okokCrafting:CanCraftItem", function(source, cb, itemID, recipe, itemName, amount)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local canCraft = true

	for k,v in pairs(recipe) do
		local itemData = xPlayer.Functions.GetItemByName(v[1])
		local itemCount = itemData and itemData.amount or 0

		if itemCount < v[2] then
			canCraft = false
		end
	end
	if canCraft then
		-- Check if player has inventory slots available for the crafted item
		local itemInfo = QBCore.Shared.Items[itemID]
		if itemInfo then
			local totalWeight = xPlayer.Functions.GetItemByName(itemID) and 0 or (itemInfo.weight or 0) * amount
			-- Calculate current inventory weight
			local currentWeight = 0
			for _, item in pairs(xPlayer.PlayerData.items) do
				if item then
					local iInfo = QBCore.Shared.Items[item.name]
					if iInfo then
						currentWeight = currentWeight + ((iInfo.weight or 0) * item.amount)
					end
				end
			end
			local maxWeight = Config and Config.MaxWeight or 120000 -- Default QBCore max weight
			if (currentWeight + totalWeight) > maxWeight then
				cb(false)
				TriggerClientEvent('okokNotify:Alert', source, "CRAFTING", "You can't carry "..itemName[itemID], 5000, 'error')
				return
			end
		end

		for k,v in pairs(recipe) do
			if v[3] == "true" then
				xPlayer.Functions.RemoveItem(v[1], v[2])
			end
		end
		cb(true)
		TriggerClientEvent('okokNotify:Alert', source, "CRAFTING", itemName[itemID].." added to the crafting queue", 5000, 'success')
		if Webhook ~= '' then
			local identifierlist = ExtractIdentifiers(xPlayer.PlayerData.source)
			local data = {
				playerid = xPlayer.PlayerData.source,
				identifier = identifierlist.license:gsub("license2:", ""),
				discord = "<@"..identifierlist.discord:gsub("discord:", "")..">",
				type = "crafting",
				itemName = itemName[itemID],
			}
			noSession(data)
		end
	else
		cb(false)
		TriggerClientEvent('okokNotify:Alert', source, "CRAFTING", "You can't craft "..itemName[itemID], 5000, 'error')
	end
end)

-------------------------- IDENTIFIERS

function ExtractIdentifiers(id)
    local identifiers = {
        steam = "",
        ip = "",
        discord = "",
        license = "",
        xbl = "",
        live = ""
    }

    for i = 0, GetNumPlayerIdentifiers(id) - 1 do
        local playerID = GetPlayerIdentifier(id, i)

        if string.find(playerID, "steam") then
            identifiers.steam = playerID
        elseif string.find(playerID, "ip") then
            identifiers.ip = playerID
        elseif string.find(playerID, "discord") then
            identifiers.discord = playerID
        elseif string.find(playerID, "license") then
            identifiers.license = playerID
        elseif string.find(playerID, "xbl") then
            identifiers.xbl = playerID
        elseif string.find(playerID, "live") then
            identifiers.live = playerID
        end
    end

    return identifiers
end

-------------------------- NO SESSION WEBHOOK

function noSession(data)
	local color = '65352'
	local category = 'test'

	if data.type == 'Death' then
		color = Config.AnticheatProtectionWebhookColor
		category = 'Tried to receive the crafting items without starting a crafting, he might be cheating'
	elseif data.type == 'conclude' then
		color = Config.AnticheatProtectionWebhookColor
		category = 'Tried to conclude a crafting without starting it first, he might be cheating'
	elseif data.type == 'crafted-soon' then
		color = Config.AnticheatProtectionWebhookColor
		category = 'Concluded the crafting of '..data.itemName..' after '..data.time_taken..'ms while it takes '..data.time_needed..'ms to craft, he might be cheating'
	elseif data.type == 'crafting' then
		color = Config.StartCraftWebhookColor
		category = 'Added '..data.itemName..' to queue'
	elseif data.type == 'conclude-crafting' then
		color = Config.ConcludeCraftWebhookColor
		category = 'Crafted a '..data.itemName..' after '..data.time..'ms'
	elseif data.type == 'failed' then
		color = Config.FailWebhookColor
		category = 'Failed to craft a '..data.item
	end
	
	local information = {
		{
			["color"] = color,
			["author"] = {
				["icon_url"] = Config.IconURL,
				["name"] = Config.ServerName..' - Logs',
			},
			["title"] = 'CRAFTING',
			["description"] = '**Action:** '..category..'\n\n**ID:** '..data.playerid..'\n**Identifier:** '..data.identifier..'\n**Discord:** '..data.discord,
			["footer"] = {
				["text"] = os.date(Config.DateFormat),
			}
		}
	}

	PerformHttpRequest(Webhook, function(err, text, headers) end, 'POST', json.encode({username = Config.BotName, embeds = information}), {['Content-Type'] = 'application/json'})
end