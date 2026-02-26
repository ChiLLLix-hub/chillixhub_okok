-- Leaked By: 5M-Leaks | 5M-Leaks | https://5m-leaks.com
QBCore = nil

-- Prefer the modern exports API; fall back to the legacy event for older builds
local ok, coreObj = pcall(function() return exports['qb-core']:GetCoreObject() end)
if ok and coreObj then
	QBCore = coreObj
else
	TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
end

-- Returns the QBCore core object, lazily retrying if startup init failed
local function GetCoreObject()
	if not QBCore then
		local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
		if ok and obj then QBCore = obj end
	end
	return QBCore
end

-- Returns the QBCore player object, or nil if not loaded yet
local function GetSafePlayer(source)
	local core = GetCoreObject()
	if not core then return nil end
	return core.Functions.GetPlayer(source)
end

-- Returns "Firstname Lastname" from charinfo, falling back to the FiveM player name
local function GetPlayerDisplayName(xPlayer, source)
	if xPlayer and xPlayer.PlayerData and xPlayer.PlayerData.charinfo then
		local ci = xPlayer.PlayerData.charinfo
		local first = ci.firstname or ''
		local last  = ci.lastname  or ''
		if first ~= '' or last ~= '' then
			return (first .. ' ' .. last):match('^%s*(.-)%s*$')
		end
	end
	return GetPlayerName(source) or 'Unknown'
end

-- Returns the player's job name, or an empty string when data is missing
local function GetPlayerJobName(xPlayer)
	if xPlayer and xPlayer.PlayerData and xPlayer.PlayerData.job then
		return xPlayer.PlayerData.job.name or ''
	end
	return ''
end

-- Returns a numeric money amount for a given money type (bank/cash), with fallbacks
local function GetMoneyAmount(xPlayer, moneyType)
	if not xPlayer then return 0 end
	-- Try the Functions.GetMoney API present in some QBCore forks first
	if xPlayer.Functions and xPlayer.Functions.GetMoney then
		local v = tonumber(xPlayer.Functions.GetMoney(moneyType))
		if v ~= nil then return v end
	end
	-- Standard QBCore: money stored directly in PlayerData.money
	if xPlayer.PlayerData and xPlayer.PlayerData.money then
		return tonumber(xPlayer.PlayerData.money[moneyType]) or 0
	end
	return 0
end

-- Removes money safely, returning true only when the framework confirms success
local function RemoveMoneySafe(xPlayer, moneyType, amount)
	if not xPlayer or amount <= 0 then return false end
	if xPlayer.Functions and xPlayer.Functions.RemoveMoney then
		return xPlayer.Functions.RemoveMoney(moneyType, amount) ~= false
	end
	return false
end

local canAdvertise = true

if Config.AllowPlayersToClearTheirChat then
	RegisterCommand(Config.ClearChatCommand, function(source, args, rawCommand)
		TriggerClientEvent('chat:client:ClearChat', source)
	end)
end

if Config.AllowStaffsToClearEveryonesChat then
	RegisterCommand(Config.ClearEveryonesChatCommand, function(source, args, rawCommand)
		local xPlayer = GetSafePlayer(source)
		local time = os.date(Config.DateFormat)

		if isAdmin(xPlayer) then
			TriggerClientEvent('chat:client:ClearChat', -1)
			TriggerClientEvent('chat:addMessage', -1, {
				template = '<div class="chat-message system"><i class="fas fa-cog"></i> <b><span style="color: #df7b00">SYSTEM</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{0}</span></b><div style="margin-top: 5px; font-weight: 300;">The chat has been cleared!</div></div>',
				args = { time }
			})
		end
	end)
end

if Config.EnableStaffCommand then
	RegisterCommand(Config.StaffCommand, function(source, args, rawCommand)
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.StaffCommand)
		local message = rawCommand:sub(length + 1)
		local time = os.date(Config.DateFormat)
		playerName = GetPlayerDisplayName(xPlayer, source)

		if isAdmin(xPlayer) then
			TriggerClientEvent('chat:addMessage', -1, {
				template = '<div class="chat-message staff"><i class="fas fa-shield-alt"></i> <b><span style="color: #1ebc62">[STAFF] {0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
				args = { playerName, message, time }
			})
		end
	end)
end

if Config.EnableStaffOnlyCommand then
	RegisterCommand(Config.StaffOnlyCommand, function(source, args, rawCommand)
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.StaffOnlyCommand)
		local message = rawCommand:sub(length + 1)
		local time = os.date(Config.DateFormat)
		playerName = GetPlayerDisplayName(xPlayer, source)

		if isAdmin(xPlayer) then
			showOnlyForAdmins(function(admins)
				TriggerClientEvent('chat:addMessage', admins, {
					template = '<div class="chat-message staffonly"><i class="fas fa-eye-slash"></i> <b><span style="color: #1ebc62">[STAFF ONLY] {0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
					args = { playerName, message, time }
				})
			end)
		end
	end)
end

if Config.EnableAdvertisementCommand then
	RegisterCommand(Config.AdvertisementCommand, function(source, args, rawCommand)
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.AdvertisementCommand)
		local message = rawCommand:sub(length + 1)
		local time = os.date(Config.DateFormat)
		playerName = GetPlayerDisplayName(xPlayer, source)
		local bankMoney = GetMoneyAmount(xPlayer, 'bank')
		local cashMoney = GetMoneyAmount(xPlayer, 'cash')

		if canAdvertise then
			if xPlayer and (bankMoney >= Config.AdvertisementPrice or cashMoney >= Config.AdvertisementPrice) then
				local paymentDone = false

				if bankMoney >= Config.AdvertisementPrice then
					paymentDone = RemoveMoneySafe(xPlayer, 'bank', Config.AdvertisementPrice)
				end

				if not paymentDone and cashMoney >= Config.AdvertisementPrice then
					paymentDone = RemoveMoneySafe(xPlayer, 'cash', Config.AdvertisementPrice)
				end

				if paymentDone then
					TriggerClientEvent('chat:addMessage', -1, {
						template = '<div class="chat-message advertisement"><i class="fas fa-ad"></i> <b><span style="color: #81db44">{0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
						args = { playerName, message, time }
					})

					TriggerClientEvent('okokNotify:Alert', source, "ADVERTISEMENT", "Advertisement successfully made for "..Config.AdvertisementPrice..'€', 10000, 'success')

					local time = Config.AdvertisementCooldown * 60
					local pastTime = 0
					canAdvertise = false

					while (time > pastTime) do
						Citizen.Wait(1000)
						pastTime = pastTime + 1
						timeLeft = time - pastTime
					end
					canAdvertise = true
				else
					TriggerClientEvent('okokNotify:Alert', source, "ADVERTISEMENT", "Couldn't process payment, try again", 10000, 'error')
				end
			else
				TriggerClientEvent('okokNotify:Alert', source, "ADVERTISEMENT", "You don't have enough money to make an advertisement", 10000, 'error')
			end
		else
			TriggerClientEvent('okokNotify:Alert', source, "ADVERTISEMENT", "You can't advertise so quickly", 10000, 'error')
		end
	end)
end

if Config.EnableTwitchCommand then
	RegisterCommand(Config.TwitchCommand, function(source, args, rawCommand)
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.TwitchCommand)
		local message = rawCommand:sub(length + 1)
		local time = os.date(Config.DateFormat)
		playerName = GetPlayerDisplayName(xPlayer, source)
		local twitch = twitchPermission(source)

		if twitch then
			TriggerClientEvent('chat:addMessage', -1, {
				template = '<div class="chat-message twitch"><i class="fab fa-twitch"></i> <b><span style="color: #9c70de">{0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
				args = { playerName, message, time }
			})
		end
	end)
end

function twitchPermission(id)
	for i, a in ipairs(Config.TwitchList) do
		for x, b in ipairs(GetPlayerIdentifiers(id)) do
			if string.lower(b) == string.lower(a) then
				return true
			end
		end
	end
end

if Config.EnableYoutubeCommand then
	RegisterCommand(Config.YoutubeCommand, function(source, args, rawCommand)
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.YoutubeCommand)
		local message = rawCommand:sub(length + 1)
		local time = os.date(Config.DateFormat)
		playerName = GetPlayerDisplayName(xPlayer, source)
		local youtube = youtubePermission(source)

		if youtube then
			TriggerClientEvent('chat:addMessage', -1, {
				template = '<div class="chat-message youtube"><i class="fab fa-youtube"></i> <b><span style="color: #ff0000">{0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
				args = { playerName, message, time }
			})
		end
	end)
end

function youtubePermission(id)
	for i, a in ipairs(Config.YoutubeList) do
		for x, b in ipairs(GetPlayerIdentifiers(id)) do
			if string.lower(b) == string.lower(a) then
				return true
			end
		end
	end
end

if Config.EnableTwitterCommand then
	RegisterCommand(Config.TwitterCommand, function(source, args, rawCommand)
		if not rawCommand then return end
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.TwitterCommand)
		local message = rawCommand:sub(length + 1):match('^%s*(.-)%s*$')
		local time = os.date(Config.DateFormat)
		local playerName = GetPlayerDisplayName(xPlayer, source)

		if not message or message == '' then return end

		TriggerClientEvent('chat:addMessage', -1, {
			template = '<div class="chat-message twitter"><i class="fab fa-twitter"></i> <b><span style="color: #2aa9e0">{0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
			args = { playerName, message, time }
		})
	end)
end

if Config.EnablePoliceCommand then
	RegisterCommand(Config.PoliceCommand, function(source, args, rawCommand)
		if not rawCommand then return end
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.PoliceCommand)
		local message = rawCommand:sub(length + 1):match('^%s*(.-)%s*$')
		local time = os.date(Config.DateFormat)
		playerName = GetPlayerDisplayName(xPlayer, source)
		local job = GetPlayerJobName(xPlayer)

		if not message or message == '' then return end

		if job == Config.PoliceJobName then
			TriggerClientEvent('chat:addMessage', -1, {
				template = '<div class="chat-message police"><i class="fas fa-bullhorn"></i> <b><span style="color: #4a6cfd">{0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
				args = { playerName, message, time }
			})
		else
			TriggerClientEvent('okokNotify:Alert', source, "POLICE", "You don't have the required job to use this command", 5000, 'error')
		end
	end)
end

if Config.EnableAmbulanceCommand then
	RegisterCommand(Config.AmbulanceCommand, function(source, args, rawCommand)
		if not rawCommand then return end
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.AmbulanceCommand)
		local message = rawCommand:sub(length + 1):match('^%s*(.-)%s*$')
		local time = os.date(Config.DateFormat)
		playerName = GetPlayerDisplayName(xPlayer, source)
		local job = GetPlayerJobName(xPlayer)

		if not message or message == '' then return end

		if job == Config.AmbulanceJobName then
			TriggerClientEvent('chat:addMessage', -1, {
				template = '<div class="chat-message ambulance"><i class="fas fa-ambulance"></i> <b><span style="color: #e3a71b">{0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
				args = { playerName, message, time }
			})
		else
			TriggerClientEvent('okokNotify:Alert', source, "AMBULANCE", "You don't have the required job to use this command", 5000, 'error')
		end
	end)
end

if Config.EnableOOCCommand then
	RegisterCommand(Config.OOCCommand, function(source, args, rawCommand)
		local xPlayer = GetSafePlayer(source)
		local length = string.len(Config.OOCCommand)
		local message = rawCommand:sub(length + 1)
		local time = os.date(Config.DateFormat)
		playerName = GetPlayerDisplayName(xPlayer, source)
		TriggerClientEvent('chat:ooc', -1, source, playerName, message, time)
	end)
end

function isAdmin(xPlayer)
	-- Guard: if player object or its source is unavailable, deny access
	if not xPlayer or not xPlayer.PlayerData then return false end
	local core = GetCoreObject()
	-- Check using QBCore permission system (ACE permissions)
	-- Config.StaffGroups can contain permission names like 'admin', 'god', etc.
	for k,v in ipairs(Config.StaffGroups) do
		if core and core.Functions.HasPermission(xPlayer.PlayerData.source, v) then 
			return true 
		end
	end
	return false
end

function showOnlyForAdmins(admins)
	local core = GetCoreObject()
	if not core then return end
	local players = core.Functions.GetPlayers()
	for k,v in ipairs(players) do
		local xPlayer = core.Functions.GetPlayer(v)
		if xPlayer and isAdmin(xPlayer) then
			admins(v)
		end
	end
end