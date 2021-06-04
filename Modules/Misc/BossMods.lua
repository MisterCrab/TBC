local _G, pairs, type, table, string, error = 
	  _G, pairs, type, table, string, error 
	  
local format						= string.format	 
local tremove						= table.remove 	  
local tinsert						= table.insert 	  
local hooksecurefunc				= _G.hooksecurefunc
	  
local TMW 							= _G.TMW 
local A	 							= _G.Action
local DBM 							= _G.DBM
local BigWigsLoader					= _G.BigWigsLoader

local strlowerCache  				= TMW.strlowerCache
local toNum 						= A.toNum
local GetToggle						= A.GetToggle	  

local DBM_TIMER_PULL				-- nil, will be remap 
local BIGWIGS_TIMER_PULL			-- nil, will be remap
local UnitName 						= _G.UnitName

A.BossMods 							= { EngagedBosses = {} }
local EngagedBosses					= A.BossMods.EngagedBosses

-------------------------------------------------------------------------------
-- Locals DBM 
-------------------------------------------------------------------------------
local DBM_GetTimeRemaining, DBM_GetTimeRemainingBySpellID
if DBM then 
	local Timers, TimersBySpellID 	= {}, {}
	
	A.BossMods.HasDBM 				= true 
	DBM_TIMER_PULL					= strlowerCache[_G.DBM_CORE_TIMER_PULL or _G.DBM_CORE_L.TIMER_PULL] -- Old DBM versions have DBM_CORE_TIMER_PULL	
	
	DBM:RegisterCallback("DBM_TimerStart", function(_, id, text, timerRaw, icon, timerType, spellid, colorId)
		-- Older versions of DBM return this value as a string:
		local duration
		if type(timerRaw) == "string" then
			duration = toNum[timerRaw:match("%d+")]
		else
			duration = timerRaw
		end
		
		if not Timers[id] then 
			Timers[id] 				= { 
				text 				= strlowerCache[text], 
				start 				= TMW.time, 
				duration 			= duration,
			}   
		else
			Timers[id].text 		= strlowerCache[text]
			Timers[id].start 		= TMW.time
			Timers[id].duration 	= duration
		end 
		
		if spellid then 
			Timers[id].spellid		 = spellid
			TimersBySpellID[spellid] = Timers[id]
		end 
	end)
	DBM:RegisterCallback("DBM_TimerStop", function(_, id) 
		if Timers[id] and Timers[id].spellid then 
			TimersBySpellID[Timers[id].spellid] = nil 
		end 
		Timers[id] = nil 
	end)

	DBM_GetTimeRemaining = function(text)       
		if text then 
			for id, t in pairs(Timers) do            
				if t.text:match(text) then
					local expirationTime 	= t.start + t.duration
					local remaining 		= expirationTime - TMW.time
					if remaining < 0 then 					
						remaining = 0 
					end
					
					return remaining, expirationTime
				end
			end
		else 
			error("Bad argument 'text' (nil value) for function DBM_GetTimeRemaining")
		end 
		
		return 0, 0
	end

	DBM_GetTimeRemainingBySpellID = function(spellID)
		if TimersBySpellID[spellID] then 
			local expirationTime 	= TimersBySpellID[spellID].start + TimersBySpellID[spellID].duration
			local remaining 		= expirationTime - TMW.time
			if remaining < 0 then 
				remaining = 0
			end
			
			return remaining, expirationTime
		end 
		
		return 0, 0
	end 

	hooksecurefunc(DBM, "StartCombat", function(DBM, mod, delay, event)
		if event ~= "TIMER_RECOVERY" then
			local bossName1 = strlowerCache[mod.localization.general.name]
			local bossName2 = strlowerCache[mod.id]
			if bossName1 then 
				EngagedBosses[bossName1] = mod
				EngagedBosses[bossName1].AddonBaseName = "DBM"
			end 
			
			if bossName2 then 
				EngagedBosses[bossName2] = mod
				EngagedBosses[bossName2].AddonBaseName = "DBM"
			end 
		end
	end)	
	hooksecurefunc(DBM, "EndCombat", function(DBM, mod)
		local bossName1 = strlowerCache[mod.localization.general.name]  or ""
		local bossName2 = strlowerCache[mod.id]							or ""
		EngagedBosses[bossName1] = nil
		EngagedBosses[bossName2] = nil
	end)
end

-------------------------------------------------------------------------------
-- Locals BigWigs 
-------------------------------------------------------------------------------
local BigWigs_GetTimeRemaining
if BigWigsLoader then 	
	A.BossMods.HasBigWigs = true 	
	
	local BigWigsPluginsName = "BigWigs_Plugins"
	if  _G.IsAddOnLoaded(BigWigsPluginsName) then 
		BIGWIGS_TIMER_PULL = strlowerCache[_G.BigWigsAPI:GetLocale("BigWigs: Plugins").pull]
	else 
		local L = setmetatable({
			enUS = "Pull",
			deDE = "Pull",
			esES = "Pull",
			itIT = "Ingaggio",
			frFR = "Pull",
			esMS = "Llamado de jefe",
			koKR = "전투 예정",
			ptBR = "Pull",
			zhCN = "拉怪",
			ruRU = "Атака",
			zhTW = "開怪倒數",
		}, { __index = function(self) return self.enUS end })
		BIGWIGS_TIMER_PULL = L[GetLocale()] 	
					
		A.Listener:Add("ACTION_BIGWIGS_PLUGINS", "ADDON_LOADED", function(addonName)
			if addonName == BigWigsPluginsName then 
				BIGWIGS_TIMER_PULL = strlowerCache[_G.BigWigsAPI:GetLocale("BigWigs: Plugins").pull]
				A.Listener:Remove("ACTION_BIGWIGS_PLUGINS", "ADDON_LOADED")
			end 		
		end); _G.LoadAddOn(BigWigsPluginsName)	
	end 
	
	local Timers, owner = {}, {}
	local function stop(module, text)
		local t
		for k = #Timers, 1, -1 do
			t = Timers[k]
			if t.module == module and (not text or t.text == text) then
				tremove(Timers, k)
			elseif t.start + t.duration < TMW.time then
				tremove(Timers, k)
			end
		end
	end
	
	BigWigsLoader.RegisterMessage(owner, "BigWigs_StartBar", function(_, module, key, text, time)
		stop(module, text)			
		tinsert(Timers, {module = module, key = key, text = text:lower(), start = TMW.time, duration = time})
	end)
	BigWigsLoader.RegisterMessage(owner, "BigWigs_StopBar", function(_, module, text)
		stop(module, text)  
	end)
	BigWigsLoader.RegisterMessage(owner, "BigWigs_StopBars", function(_, module)
		stop(module)  
	end)	
	BigWigsLoader.RegisterMessage(owner, "BigWigs_OnPluginDisable", function(_, module)
		stop(module)  
	end)
	BigWigsLoader.RegisterMessage(owner, "BigWigs_OnBossDisable", function(_, module)
		stop(module)  
		
		local bossName1 = strlowerCache[module.displayName] or ""
		local bossName2 = strlowerCache[module.moduleName] 	or ""
		EngagedBosses[bossName1] = nil
		EngagedBosses[bossName2] = nil
	end)
	BigWigsLoader.RegisterMessage(owner, "BigWigs_OnBossEngage", function(_, module, diff)
		local bossName1 = strlowerCache[module.displayName]
		local bossName2 = strlowerCache[module.moduleName]
		
		if bossName1 then 
			EngagedBosses[bossName1] = module
			EngagedBosses[bossName1].AddonBaseName = "BigWigs"
		end 
		
		if bossName2 then 
			EngagedBosses[bossName2] = module
			EngagedBosses[bossName2].AddonBaseName = "BigWigs"
		end 
	end)
	
	BigWigs_GetTimeRemaining = function(text)
		local t
		if text then 
			for k = 1, #Timers do
				t = Timers[k]			
				if t.text:match(text) then
					local expirationTime 	= t.start + t.duration
					local remaining 		= expirationTime - TMW.time
					if remaining < 0 then 
						remaining = 0 
					end
					
					return remaining, expirationTime
				end
			end
		else 
			error("Bad argument 'text' (nil value) for function BigWigs_GetTimeRemaining")
		end 
		
		return 0, 0
	end
end 

-------------------------------------------------------------------------------
-- API 
-------------------------------------------------------------------------------
-- DBM commands:
-- /dbm pull <5>
-- /dbm timer <10> <Name>
--
-- BigWigs commands:
-- /pull <5>

function A.BossMods:HasAnyAddon()
	-- @return boolean 
	return self.HasDBM or self.HasBigWigs
end 

function A.BossMods:GetPullTimer()
	-- @return @number, @number 
	local remaining, expirationTime = 0, 0
	if self:HasAnyAddon() and GetToggle(1, "BossMods") then 
		local remaining1, expirationTime1 = 0, 0
		local remaining2, expirationTime2 = 0, 0
		
		if self.HasDBM then 
			remaining1, expirationTime1 = DBM_GetTimeRemaining(DBM_TIMER_PULL)
		end 
		
		if self.HasBigWigs then 
			remaining2, expirationTime2 = BigWigs_GetTimeRemaining(BIGWIGS_TIMER_PULL)
		end 
		
		if remaining1 > remaining2 then 
			remaining 		= remaining1
			expirationTime 	= expirationTime1
		else 
			remaining 		= remaining2
			expirationTime	= expirationTime2
		end 
	end 
	
	return remaining, expirationTime
end 

function A.BossMods:GetTimer(name)
	-- @return @number, @number
	-- @arg name can be number (spellID, works only on DBM) or string (localizated name of the timer)
	local remaining, expirationTime = 0, 0
	if name and self:HasAnyAddon() and GetToggle(1, "BossMods") then 
		local remaining1, expirationTime1 = 0, 0
		local remaining2, expirationTime2 = 0, 0
		
		if self.HasDBM then 
			if type(name) == "string" then 
				remaining1, expirationTime1 = DBM_GetTimeRemaining(strlowerCache[name])
			else 
				remaining1, expirationTime1 = DBM_GetTimeRemainingBySpellID(name)
			end 
		end 
		
		if self.HasBigWigs then 
			remaining2, expirationTime2 = BigWigs_GetTimeRemaining(strlowerCache[name])
		end 
		
		if remaining1 > remaining2 then 
			remaining 		= remaining1
			expirationTime 	= expirationTime1
		else 
			remaining 		= remaining2
			expirationTime	= expirationTime2
		end 
	end 
	
	return remaining, expirationTime
end 

function A.BossMods:IsEngage(name)
	-- @return @boolean, @string or @nil 
	-- Returns true if engaged fight vs specified boss by 'name' argument or by any boss if 'name' is nil, last return is localized(!) bossName if its engaged 
	if self:HasAnyAddon() and GetToggle(1, "BossMods") then 
		local compareName = name and strlowerCache[name]
		for bossName, bossMod in pairs(EngagedBosses) do
			if (not compareName or bossName:match(compareName)) and ((bossMod.AddonBaseName == "DBM" and bossMod.inCombat) or (bossMod.AddonBaseName == "BigWigs" and bossMod.isEngaged)) then 
				return true, bossName
			end 
		end 
	end 
end 