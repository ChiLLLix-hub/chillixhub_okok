# Security Recommendations for okokChat

This document contains recommended security improvements for the okokChat module. These are **optional enhancements** that would further strengthen the security posture.

## 1. Add Message Length Validation

**Priority:** Medium  
**Difficulty:** Easy  

### Problem
Currently, there is no maximum length check on messages, which could lead to:
- Chat spam with extremely long messages
- Potential UI overflow issues
- Client-side performance problems

### Solution
Add this to `config.lua`:

```lua
--------------------------------
-- [Security Settings]

Config.MaxMessageLength = 256  -- Maximum characters allowed in a message
Config.EnableRateLimiting = true
Config.MessagesPerMinute = 10  -- Maximum messages per player per minute
```

Then update `server.lua` event handler:

```lua
AddEventHandler('_chat:messageEntered', function(author, color, message)
	if not message or not author then
		return
	end

	-- Add length validation
	if Config.MaxMessageLength and string.len(message) > Config.MaxMessageLength then
		TriggerClientEvent('okokNotify:Alert', source, "CHAT", "Message too long (max "..Config.MaxMessageLength.." characters)", 5000, 'error')
		return
	end

	TriggerEvent('chatMessage', source, author, message)

	if not WasEventCanceled() then
		TriggerClientEvent('chatMessage', -1, author, {255, 255, 255}, message)
	end
end)
```

## 2. Fix Advertisement Cooldown (Per-Player Instead of Global)

**Priority:** High  
**Difficulty:** Easy  

### Problem
The current `canAdvertise` boolean is global, meaning when ONE player uses `/ad`, ALL players must wait for the cooldown period.

### Solution
Replace in `commands.lua`:

**Current Code (Lines 5, 73-92):**
```lua
local canAdvertise = true
-- ... later in the file ...
if canAdvertise then
    -- advertisement logic
    canAdvertise = false
    -- cooldown logic
    canAdvertise = true
```

**Improved Code:**
```lua
local advertisementCooldowns = {}

if Config.EnableAdvertisementCommand then
	RegisterCommand(Config.AdvertisementCommand, function(source, args, rawCommand)
		local xPlayer = ESX.GetPlayerFromId(source)
		local length = string.len(Config.AdvertisementCommand)
		local message = rawCommand:sub(length + 1)
		local time = os.date(Config.DateFormat)
		playerName = xPlayer.getName()
		local bankMoney = xPlayer.getAccount('bank').money
		local identifier = xPlayer.identifier

		-- Check per-player cooldown
		if advertisementCooldowns[identifier] and os.time() < advertisementCooldowns[identifier] then
			local timeLeft = advertisementCooldowns[identifier] - os.time()
			TriggerClientEvent('okokNotify:Alert', source, "ADVERTISEMENT", "Please wait "..math.ceil(timeLeft/60).." more minute(s)", 10000, 'error')
			return
		end

		if bankMoney >= Config.AdvertisementPrice then
			xPlayer.removeAccountMoney('bank', Config.AdvertisementPrice)
			TriggerClientEvent('chat:addMessage', -1, {
				template = '<div class="chat-message advertisement"><i class="fas fa-ad"></i> <b><span style="color: #81db44">{0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
				args = { playerName, message, time }
			})

			TriggerClientEvent('okokNotify:Alert', source, "ADVERTISEMENT", "Advertisement successfully made for "..Config.AdvertisementPrice..'€', 10000, 'success')

			-- Set per-player cooldown
			advertisementCooldowns[identifier] = os.time() + (Config.AdvertisementCooldown * 60)
		else
			TriggerClientEvent('okokNotify:Alert', source, "ADVERTISEMENT", "You don't have enough money to make an advertisement", 10000, 'error')
		end
	end)
end

-- Cleanup old cooldowns periodically
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(300000) -- Every 5 minutes
		local currentTime = os.time()
		for identifier, expiry in pairs(advertisementCooldowns) do
			if currentTime > expiry then
				advertisementCooldowns[identifier] = nil
			end
		end
	end
end)
```

## 3. Add Access Control to Twitter Command

**Priority:** Medium  
**Difficulty:** Easy  

### Problem
Unlike Twitch and YouTube commands which have whitelists, the Twitter command allows ANYONE to use it.

### Solution
Add to `config.lua`:

```lua
--------------------------------
-- [Twitter]

Config.EnableTwitterCommand = true

Config.TwitterCommand = 'twitter'

-- Option 1: Whitelist (recommended)
Config.TwitterWhitelistEnabled = true
-- Types of identifiers: steam: | license: | xbl: | live: | discord: | fivem: | ip:
Config.TwitterList = {
	'steam:110000118a12j8a' -- Example, change this
}

-- Option 2: Job-based (alternative)
Config.TwitterJobBased = false
Config.TwitterJobName = 'reporter' -- Example job
```

Then update in `commands.lua`:

```lua
if Config.EnableTwitterCommand then
	RegisterCommand(Config.TwitterCommand, function(source, args, rawCommand)
		local xPlayer = ESX.GetPlayerFromId(source)
		local length = string.len(Config.TwitterCommand)
		local message = rawCommand:sub(length + 1)
		local time = os.date(Config.DateFormat)
		playerName = xPlayer.getName()

		-- Add permission check
		local hasPermission = false
		
		if Config.TwitterWhitelistEnabled then
			hasPermission = twitterPermission(source)
		elseif Config.TwitterJobBased then
			hasPermission = (xPlayer.job.name == Config.TwitterJobName)
		else
			hasPermission = true -- Open to all if neither option is enabled
		end

		if hasPermission then
			TriggerClientEvent('chat:addMessage', -1, {
				template = '<div class="chat-message twitter"><i class="fab fa-twitter"></i> <b><span style="color: #2aa9e0">{0}</span>&nbsp;<span style="font-size: 14px; color: #e1e1e1;">{2}</span></b><div style="margin-top: 5px; font-weight: 300;">{1}</div></div>',
				args = { playerName, message, time }
			})
		else
			TriggerClientEvent('okokNotify:Alert', source, "TWITTER", "You don't have permission to use this command", 5000, 'error')
		end
	end)
end

function twitterPermission(id)
	for i, a in ipairs(Config.TwitterList) do
		for x, b in ipairs(GetPlayerIdentifiers(id)) do
			if string.lower(b) == string.lower(a) then
				return true
			end
		end
	end
	return false
end
```

## 4. Add Rate Limiting for Chat Messages

**Priority:** Medium  
**Difficulty:** Medium  

### Problem
No rate limiting on regular chat messages could allow spam attacks.

### Solution
Add to `server.lua`:

```lua
local messageCounts = {}
local RATE_LIMIT_WINDOW = 60 -- seconds
local MAX_MESSAGES = 10 -- messages per window

AddEventHandler('_chat:messageEntered', function(author, color, message)
	if not message or not author then
		return
	end

	-- Rate limiting
	local currentTime = os.time()
	if not messageCounts[source] then
		messageCounts[source] = {}
	end

	-- Remove old messages outside the time window
	local recentMessages = {}
	for _, timestamp in ipairs(messageCounts[source]) do
		if currentTime - timestamp < RATE_LIMIT_WINDOW then
			table.insert(recentMessages, timestamp)
		end
	end
	messageCounts[source] = recentMessages

	-- Check if rate limit exceeded
	if #messageCounts[source] >= MAX_MESSAGES then
		TriggerClientEvent('okokNotify:Alert', source, "CHAT", "You're sending messages too quickly!", 3000, 'warning')
		return
	end

	-- Add current message timestamp
	table.insert(messageCounts[source], currentTime)

	TriggerEvent('chatMessage', source, author, message)

	if not WasEventCanceled() then
		TriggerClientEvent('chatMessage', -1, author, {255, 255, 255}, message)
	end
end)

-- Cleanup on player disconnect
AddEventHandler('playerDropped', function()
	messageCounts[source] = nil
end)
```

## 5. Host Vue.js Locally Instead of CDN

**Priority:** Low  
**Difficulty:** Easy  

### Problem
Loading Vue.js from `cdn.jsdelivr.net` creates a dependency on external infrastructure and potential CDN compromise risks.

### Solution

1. Download Vue.js to the web folder:
```bash
cd web/
curl -o vue.min.js https://cdn.jsdelivr.net/npm/vue@2/dist/vue.min.js
```

2. Update `web/ui.html` line 7:

**Current:**
```html
<script src="https://cdn.jsdelivr.net/npm/vue@2"></script>
```

**Improved:**
```html
<script src="vue.min.js"></script>
```

3. Update `fxmanifest.lua` if needed:
```lua
files {
	'web/*.*',  -- This already includes vue.min.js
}
```

## 6. Add Input Sanitization for Command Arguments

**Priority:** Medium  
**Difficulty:** Easy  

### Problem
While XSS is prevented in the web layer, additional server-side sanitization would add defense in depth.

### Solution
Add to `commands.lua` at the top:

```lua
-- Sanitization function
local function sanitizeMessage(message)
	if not message then return "" end
	
	-- Remove null bytes
	message = message:gsub("%z", "")
	
	-- Trim whitespace
	message = message:match("^%s*(.-)%s*$")
	
	-- Optional: Remove or escape special characters if needed
	-- message = message:gsub("[<>\"'&]", "")
	
	return message
end
```

Then use it in all command handlers:
```lua
local message = sanitizeMessage(rawCommand:sub(length + 1))
```

## Implementation Priority

1. **High Priority (Implement First):**
   - Fix advertisement cooldown (per-player)
   - Add message length validation

2. **Medium Priority (Recommended):**
   - Add Twitter command access control
   - Add rate limiting for chat messages
   - Add input sanitization

3. **Low Priority (Optional):**
   - Host Vue.js locally

## Testing Recommendations

After implementing any changes:

1. Test all chat commands individually
2. Test permission systems (staff, jobs, whitelists)
3. Test rate limiting and cooldowns
4. Test with very long messages
5. Test with special characters and edge cases
6. Test with multiple players simultaneously

## Conclusion

While the okokChat module is already secure with no critical vulnerabilities, implementing these recommendations would provide:

- Better user experience (no global cooldowns)
- Protection against spam and abuse
- Stronger access controls
- Reduced external dependencies
- Defense in depth security

All recommendations are backward-compatible and won't break existing functionality.
