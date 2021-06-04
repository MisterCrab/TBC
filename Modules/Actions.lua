local _G, type, next, pairs, ipairs, select, unpack, table, setmetatable, math, string, error = 	
	  _G, type, next, pairs, ipairs, select, unpack, table, setmetatable, math, string, error
	  
local maxn					= table.maxn
local tinsert 				= table.insert		
local tsort 				= table.sort
local strgsub				= string.gsub
local strgmatch				= string.gmatch
local strlen				= string.len
local huge 					= math.huge
local wipe 					= _G.wipe
local hooksecurefunc		= _G.hooksecurefunc	  
	  
local TMW 					= _G.TMW
local CNDT 					= TMW.CNDT
local Env 					= CNDT.Env

local A   					= _G.Action	
local CONST 				= A.Const
local Listener				= A.Listener
local toNum 				= A.toNum
local UnitCooldown			= A.UnitCooldown
local CombatTracker			= A.CombatTracker
local Unit					= A.Unit 
local Player				= A.Player 
local LoC 					= A.LossOfControl
local MultiUnits			= A.MultiUnits
local TriggerGCD			= A.Enum.TriggerGCD
local GetToggle				= A.GetToggle
local BurstIsON				= A.BurstIsON

local TRINKET1				= CONST.TRINKET1
local TRINKET2				= CONST.TRINKET2
local POTION				= CONST.POTION
local EQUIPMENT_MANAGER		= CONST.EQUIPMENT_MANAGER
local CACHE_DEFAULT_TIMER	= CONST.CACHE_DEFAULT_TIMER
local SPELLID_FREEZING_TRAP = CONST.SPELLID_FREEZING_TRAP

local LibStub				= _G.LibStub

-------------------------------------------------------------------------------
-- Remap
-------------------------------------------------------------------------------
local A_OnGCD, A_GetCurrentGCD, A_GetGCD, A_GetPing, A_GetSpellInfo, A_GetSpellDescription 

Listener:Add("ACTION_EVENT_ACTIONS", "ADDON_LOADED", function(addonName) 
	if addonName == CONST.ADDON_NAME then  
		A_OnGCD					= A.OnGCD
		A_GetCurrentGCD			= A.GetCurrentGCD
		A_GetGCD				= A.GetGCD
		A_GetPing				= A.GetPing
		A_GetSpellInfo			= A.GetSpellInfo
		A_GetSpellDescription	= A.GetSpellDescription
		Listener:Remove("ACTION_EVENT_ACTIONS", "ADDON_LOADED")	
	end 	
end)

-------------------------------------------------------------------------------
local Pet					= LibStub("PetLibrary")
local SpellRange			= LibStub("SpellRange-1.0")
local IsSpellInRange 		= SpellRange.IsSpellInRange	  
local SpellHasRange			= SpellRange.SpellHasRange
local isSpellRangeException = {
	-- Shadowmeld
	[58984]		= true,
	-- LightsJudgment
	[255647]	= true,
	-- EveryManforHimself
	[59752]		= true, 
	-- EscapeArtist
	[20589]		= true,
	-- Stoneform
	[20594] 	= true, 
	-- Fireblood
	[265221]	= true,
	-- Regeneratin
	[291944]	= true,
	-- WilloftheForsaken
	[7744]		= true,
	-- Berserking
	[26297]		= true,
	-- WarStomp
	[20549]		= true, 
	-- BloodFury
	[33697]		= true,
	[20572]		= true,
	[33702]		= true,	
}
local ItemHasRange 			= ItemHasRange
local isItemRangeException 	= {
	[19950] = true,
	[18820] = true,
}
local isItemUseException	= {}
local itemCategory 			= {
	[1404]	= "CC",		-- Tidal Charm (stun 3sec)
	[17744]	= "MISC",	-- Heart of Noxxion (1 posion self-dispel)
	[19950] = "BOTH",
	[18820] = "BOTH",
}
	  	  	  
local GetNetStats 			= _G.GetNetStats  	
local GameLocale 			= _G.GetLocale()
local GetCVar				= _G.GetCVar or _G.C_CVar.GetCVar

-- Spell 
local Spell					= _G.Spell

local 	 IsPlayerSpell,    IsUsableSpell, 	 IsHelpfulSpell, 	IsHarmfulSpell,    IsAttackSpell, 	 IsCurrentSpell =
	  _G.IsPlayerSpell, _G.IsUsableSpell, _G.IsHelpfulSpell, _G.IsHarmfulSpell, _G.IsAttackSpell, _G.IsCurrentSpell

local 	  GetSpellTexture, 	  GetSpellLink,    GetSpellInfo, 	GetSpellDescription, 	GetSpellCount,	   GetSpellPowerCost, 	  CooldownDuration,    GetSpellCharges,    GetHaste, 	GetShapeshiftFormCooldown, 	  GetSpellBaseCooldown,    GetSpellAutocast = 
	  TMW.GetSpellTexture, _G.GetSpellLink, _G.GetSpellInfo, _G.GetSpellDescription, _G.GetSpellCount, 	_G.GetSpellPowerCost, Env.CooldownDuration, _G.GetSpellCharges, _G.GetHaste, _G.GetShapeshiftFormCooldown, _G.GetSpellBaseCooldown, _G.GetSpellAutocast

-- Item 	  
local 	 IsUsableItem, 	  IsHelpfulItem, 	IsHarmfulItem, 	  IsCurrentItem  =
	  _G.IsUsableItem, _G.IsHelpfulItem, _G.IsHarmfulItem, _G.IsCurrentItem
  
local 	 GetItemInfo, 	 GetItemIcon, 	 GetItemInfoInstant, 	GetItemSpell = 
	  _G.GetItemInfo, _G.GetItemIcon, _G.GetItemInfoInstant, _G.GetItemSpell	  

-- Talent	  
local TalentMap 					= A.TalentMap 

-- Rank 
local GetSpellBookItemName			= _G.GetSpellBookItemName
local FindSpellBookSlotBySpellID 	= _G.FindSpellBookSlotBySpellID

-- Unit 	  
local UnitAura						= _G.UnitAura
local 	 UnitIsUnit, 	UnitGUID	= 
	  _G.UnitIsUnit, _G.UnitGUID 

-- Empty 
local nullDescription				= A.MakeTableReadOnly({ 0, 0, 0, 0, 0, 0, 0, 0 })

-- Auras
local IsBreakAbleDeBuff = {}
do 
	local tempTable = A.GetAuraList("BreakAble")
	local tempTableInSkipID = A.GetAuraList("Rooted")
	for j = 1, #tempTable do 
		local isRoots 
		for l = 1, #tempTableInSkipID do 
			if tempTable[j] == tempTableInSkipID[l] then 
				isRoots = true 
				break 
			end 			
		end 
		
		if not isRoots then 
			IsBreakAbleDeBuff[tempTable[j]] = true 
			local spellName = GetSpellInfo(tempTable[j])
			if not spellName then 
				error("Need to delete " .. tempTable[j])
			else 
				IsBreakAbleDeBuff[spellName] = true 
			end 
		end 
	end 
end 

-- Player 
local GCD_OneSecond 			= {
	ROGUE 						= true,
}

local function sortByHighest(x, y)
	return x > y
end

-------------------------------------------------------------------------------
-- Global Cooldown
-------------------------------------------------------------------------------
-- Returns 'true' if duration field of spell/item cooldown used on global cooldown animation
A.OnGCD = TMW.OnGCD

function A.GetCurrentGCD()
	-- @return number 
	-- Current left in second time of in use (spining) GCD, 0 if GCD is not active
	return CooldownDuration("gcd") -- TMW.GCDSpell
end 
A.GetCurrentGCD = A.MakeFunctionCachedStatic(A.GetCurrentGCD)

function A.GetGCD()
	-- @return number 
	-- Summary time of GCD 
	if TMW.GCD > 0 then
		-- Depended by last used spell 
		return TMW.GCD
	else 
		if GCD_OneSecond[A.PlayerClass] then 
			return 1
		else 
			-- Depended on current haste
			return 1.5 / (1 + Player:HastePct() / 100) 
		end 
	end    
end 

function A.IsActiveGCD()
	-- @return boolean 
	return TMW.GCD ~= 0
end 

function A:IsRequiredGCD()
	-- @return boolean, number 
	-- true / false if required, number in seconds how much GCD will be used by action
	if self.Type == "Spell" and TriggerGCD[self.ID] and TriggerGCD[self.ID] > 0 then 
		return true, TriggerGCD[self.ID]
	end 
	
	return false, 0
end 

-------------------------------------------------------------------------------
-- Global Stop Conditions
-------------------------------------------------------------------------------
function A.GetPing()
	-- @return number
	return select(4, GetNetStats()) / 1000
end 
A.GetPing = A.MakeFunctionCachedStatic(A.GetPing, 0)

function A.GetLatency()
	-- @return number 
	-- Returns summary delay caused by ping and interface respond time (usually not higher than 0.4 sec)
	return toNum[GetCVar("SpellQueueWindow") or 100] / 1000 + (A_GetPing() / 2)
end

function A:ShouldStopByGCD()
	-- @return boolean 
	-- By Global Cooldown
	return not Player:IsShooting() and self:IsRequiredGCD() and A_GetGCD() - A_GetPing() > 0.301 and A_GetCurrentGCD() >= A_GetPing() + 0.65
end 

function A.ShouldStop()
	-- @return boolean 
	-- By Casting
	return Unit("player"):IsCasting()
end 
A.ShouldStop = A.MakeFunctionCachedStatic(A.ShouldStop, 0)

-------------------------------------------------------------------------------
-- Spell
-------------------------------------------------------------------------------
local spellbasecache  = setmetatable({}, { __index = function(t, v)
	local cd = GetSpellBaseCooldown(v)
	if cd then
		t[v] = cd / 1000
		return t[v]
	end     
	return 0
end })

function A:GetSpellBaseCooldown()
	-- @return number (seconds)
	-- Gives the (unmodified) cooldown
	return spellbasecache[self.ID]
end 

local spellpowercache = setmetatable(
	{ 
		null = {0, 1},
	}, 
	{ 
		__index = function(t, v)
			local pwr = GetSpellPowerCost(A.GetSpellInfo(v))
			if pwr and pwr[1] then
				t[v] = { pwr[1].cost, pwr[1].type }
				return t[v]
			end     
			return t.null
		end,
	}
)

function A:GetSpellPowerCostCache()
	-- THIS IS STATIC CACHED, ONCE CALLED IT WILL NOT REFRESH REALTIME POWER COST
	-- @usage A:GetSpellPowerCostCache() or A.GetSpellPowerCostCache(spellID)
	-- @return cost (@number), type (@number)
	local ID = self
	if type(self) == "table" then 
		ID = self.ID 
	end
    return unpack(spellpowercache[ID]) 
end

function A.GetSpellPowerCost(self)
	-- RealTime with cycle cache
	-- @usage A:GetSpellPowerCost() or A.GetSpellPowerCost(123)
	-- @return cost (@number), type (@number)
	local name 
	if type(self) == "table" then 
		name = self:Info()
	else 
		name = A_GetSpellInfo(self)
	end 
	
	local pwr = GetSpellPowerCost(name)
	if pwr and pwr[1] then
		return pwr[1].cost, pwr[1].type
	end   	
	return 0, -1
end 
A.GetSpellPowerCost = A.MakeFunctionCachedDynamic(A.GetSpellPowerCost)

local str_null 			= ""
local str_comma			= ","
local str_point			= "%."
local pattern_gmatch 	= "%f[%d]%d[.,%d]*%f[%D]"
local pattern_gsubspace	= "%s"
local descriptioncache 	= setmetatable({}, { __index = function(t, v)
	-- Stores formated string of description
	t[v] = strgsub(strgsub(v, pattern_gsubspace, str_null), str_comma, str_point)
	return t[v]
end })
local descriptiontemp	= {
	-- Stores temprorary data 
}
function A.GetSpellDescription(self)
	-- @usage A:GetSpellDescription() or A.GetSpellDescription(18)
	-- @return table array like where first index is highest number of the description
	local spellID = type(self) == "table" and self.ID or self
	local text = GetSpellDescription(spellID)
	
	if text then 
		-- The way to re-use table anyway is found now 
		if not descriptiontemp[spellID] then 
			descriptiontemp[spellID] = {}
		else 
			wipe(descriptiontemp[spellID])
		end 
		
		for value in strgmatch(descriptioncache[text], pattern_gmatch) do 
			if GameLocale == "frFR" and strlen(value) > 3 then -- French users have wierd syntax of floating dots
				tinsert(descriptiontemp[spellID], toNum[strgsub(value, str_point, str_null)])
			else 
				tinsert(descriptiontemp[spellID], toNum[value])
			end 
		end
		
		if #descriptiontemp[spellID] > 1 then
			tsort(descriptiontemp[spellID], sortByHighest)
		end 

		return descriptiontemp[spellID]
	end
	
	return nullDescription -- can not be used for 'next', 'unpack', 'pairs', 'ipairs'
end
A.GetSpellDescription = A.MakeFunctionCachedDynamic(A.GetSpellDescription)

function A:GetSpellCastTime()
	-- @return number 
	local _,_,_, castTime = GetSpellInfo(self.ID)
	return (castTime or 0) / 1000 
end 

function A:GetSpellCastTimeCache()
	-- @usage A:GetSpellCastTimeCache() or A.GetSpellCastTimeCache(116)
	-- @return number 
	if type(self) == "table" then 
		return (select(4, self:Info()) or 0) / 1000 
	else
		return (select(4, A_GetSpellInfo(self)) or 0) / 1000
	end 
end 

function A:GetSpellCharges()
	-- @return number
	local charges = GetSpellCharges((self:Info()))
	if not charges then 
		charges = 0
	end 
	
	return charges
end

function A:GetSpellChargesMax()
	-- @return number
	local _, max_charges = GetSpellCharges((self:Info()))
	if not max_charges then 
		max_charges = 0
	end 
	
	return max_charges	
end

function A:GetSpellChargesFrac()
	-- @return number	
	local charges, maxCharges, start, duration = GetSpellCharges((self:Info()))
	if not maxCharges then 
		return 0
	end 
	
	if charges == maxCharges then 
		return maxCharges
	end
	
	return charges + ((TMW.time - start) / duration)  
end

function A:GetSpellChargesFullRechargeTime()
	-- @return number
	local _, _, _, duration = GetSpellCharges((self:Info()))
	if duration then 
		return (self:GetSpellChargesMax() - self:GetSpellChargesFrac()) * duration
	else 
		return 0
	end 
end 

function A:GetSpellTimeSinceLastCast()
	-- @return number (seconds after last time casted - during fight)
	return CombatTracker:GetSpellLastCast("player", (self:Info()))
end 

function A:GetSpellCounter()
	-- @return number (total count casted of the spell - during fight)
	return CombatTracker:GetSpellCounter("player", (self:Info()))
end 

function A:GetSpellAmount(unitID, X)
	-- @return number (taken summary amount of the spell - during fight)
	-- X during which lasts seconds 
	if X then 
		return CombatTracker:GetSpellAmountX(unitID or "player", (self:Info()), X)
	else 
		return CombatTracker:GetSpellAmount(unitID or "player", (self:Info()))
	end 
end 

function A:GetSpellAbsorb(unitID)
	-- @return number (taken current absort amount of the spell - during fight)
	return CombatTracker:GetAbsorb(unitID or "player", (self:Info()))
end 

function A:GetSpellAutocast()
	-- @return boolean, boolean 
	-- Returns autocastable, autostate 
	return GetSpellAutocast((self:Info()))
end 

function A:IsSpellLastGCD(byID)
	-- @return boolean
	return (byID and self.ID == A.LastPlayerCastID) or (not byID and self:Info() == A.LastPlayerCastName)
end 

function A:IsSpellLastCastOrGCD(byID)
	-- @return boolean
	return self:IsSpellLastGCD(byID) or self:IsSpellInCasting()
end 

function A:IsSpellInFlight()
	-- @return boolean
	return UnitCooldown:IsSpellInFly("player", (self:Info())) -- Classic Info 
end 

function A:IsSpellInRange(unitID)
	-- @usage A:IsSpellInRange() or A.IsSpellInRange(spellID, unitID)
	-- @return boolean
	local ID, Name
	if type(self) == "table" then 
		ID = self.ID 
		Name = self:Info()
	else 
		ID = self 
		Name = A_GetSpellInfo(ID)
	end		
	return Name and (IsSpellInRange(Name, unitID) == 1 or (Pet:IsActive() and Pet:IsInRange(Name, unitID))) -- Classic better make through Name for Pet:IsInRange
end 

function A:IsSpellInCasting()
	-- @return boolean 
	return Unit("player"):IsCasting() == self:Info()
end 

function A:IsSpellCurrent()
	-- @return boolean
	return IsCurrentSpell((self:Info()))
end 

function A:CanSafetyCastHeal(unitID, offset)
	-- @return boolean 
	local castTime = self:GetSpellCastTime()
	return castTime and (castTime == 0 or castTime > Unit(unitID):TimeToDie() + A_GetCurrentGCD() + (offset or A_GetGCD())) or false 
end 

-------------------------------------------------------------------------------
-- Spell Rank 
-------------------------------------------------------------------------------
local DataSpellRanks = {}
local DataIsSpellUnknown = {}
function A.UpdateSpellBook(isProfileLoad)
	A.WipeTableKeyIdentify()
	wipe(DataSpellRanks)
	wipe(DataIsSpellUnknown)
	
	local spellName, spellRank, spellID 
	-- Search by player book 
	for i = 1, huge do 
		spellName, spellRank, spellID = GetSpellBookItemName(i, BOOKTYPE_SPELL)
		if spellName then 
			if spellRank and spellRank ~= "" and spellID then 
				spellRank = spellRank:match("%d+")
				if spellRank then 
					spellRank = toNum[spellRank]
					
					if not DataSpellRanks[spellName] then 
						DataSpellRanks[spellName] = {}
					end 
					
					DataSpellRanks[spellName][spellRank] = spellID
				end 
			end 
		else 
			break 
		end 
	end 
	
	-- Search by pet book
	for i = 1, huge do 
		spellName, spellRank, spellID = GetSpellBookItemName(i, BOOKTYPE_PET)
		if spellName then 
			if spellRank and spellRank ~= "" and spellID then 
				spellRank = spellRank:match("%d+")
				if spellRank then 
					spellRank = toNum[spellRank]
					
					if not DataSpellRanks[spellName] then 
						DataSpellRanks[spellName] = {}
					end 
					
					DataSpellRanks[spellName][spellRank] = spellID
				end 
			end 
		else 
			break 
		end 
	end 	

	-- Overwrite ID of spells with update isRank and block unavailable ranks 
	if A[A.PlayerClass] then 				
		for k, v in pairs(A[A.PlayerClass]) do 
			if type(v) == "table" and v.Type == "Spell" then 
				local spellName = v:Info()
				-- Overwrite ID and isRank 
				if DataSpellRanks[spellName] then 
					-- By max 
					if type(v.useMaxRank) == "boolean" then 					
						local maxRank = maxn(DataSpellRanks[spellName])
						v.ID = DataSpellRanks[spellName][maxRank]
						v.isRank = maxRank 		
					elseif type(v.useMaxRank) == "table" then 
						for i = #v.useMaxRank, 1, -1 do 
							if DataSpellRanks[spellName][v.useMaxRank[i]] then 
								v.isRank = v.useMaxRank[i]
								v.ID = DataSpellRanks[spellName][v.isRank]		
								break 
							end 							 
						end 					
					end 
					
					-- By min 
					if type(v.useMinRank) == "boolean" then 					
						local minRank = DataSpellRanks[spellName][1] ~= nil and 1 or next(DataSpellRanks[spellName])
						v.ID = DataSpellRanks[spellName][minRank]
						v.isRank = minRank 		
					elseif type(v.useMinRank) == "table" then 
						for i = 1, #v.useMinRank do 
							if DataSpellRanks[spellName][v.useMinRank[i]] then 
								v.isRank = v.useMinRank[i]
								v.ID = DataSpellRanks[spellName][v.isRank]		
								break 
							end 								
						end 
					end 
				end 
				
				-- Block spell (unlearned)				
				-- Search by player book
				local slot = FindSpellBookSlotBySpellID(v.ID, false)  
				
				-- Search by pet book 
				if not slot then 
					slot = FindSpellBookSlotBySpellID(v.ID, true)
				end
				
				-- Add to block 
				if not slot then 
					DataIsSpellUnknown[v.ID] = true 
					-- Prevent nil errors with ranks if not found at all 
					if not v.isRank then 
						v.isRank = 0
					end 
				end 								 								
			end 
		end 
	end 

	if isProfileLoad ~= true then 
		TMW:Fire("TMW_ACTION_SPELL_BOOK_CHANGED")	  -- for [3] tab refresh 
		--TMW:Fire("TMW_ACTION_RANK_DISPLAY_CHANGED") -- no need here since :Show method will be triggered 
	end 
end 

Listener:Add("ACTION_EVENT_SPELL_RANKS", "LEARNED_SPELL_IN_TAB", 		A.UpdateSpellBook)
TMW:RegisterCallback("TMW_ACTION_TALENT_MAP_UPDATED", function()
	A.UpdateSpellBook()
end)
TMW:RegisterCallback("TMW_ACTION_PET_LIBRARY_MAIN_PET_UP", function()
	A.UpdateSpellBook()
end)

function A:IsBlockedBySpellBook()
	-- @return boolean 
	return DataIsSpellUnknown[self.ID]
end 

function A:GetSpellRank()
	-- @return number 
	return self.isRank or 1
end 

function A:GetSpellMaxRank()
	-- @return number 
	if self.isRank then 
		local spellName = self:Info()
		if DataSpellRanks[spellName] then 
			return maxn(DataSpellRanks[spellName])
		end 
	end 
	return 1
end 

-------------------------------------------------------------------------------
-- Talent 
-------------------------------------------------------------------------------
function A:GetTalentRank()
	-- @usage A:GetTalentRank() or A.GetTalentRank(spellID)
	-- @return number 
	local ID, Name
	if type(self) == "table" then 
		--ID = self.ID 
		Name = self:Info()
	else 
		ID = self 
		Name = A_GetSpellInfo(ID)
	end	
	return TalentMap[Name] or 0 
end 

function A:IsTalentLearned()
	-- @usage A:IsTalentLearned() or A.IsTalentLearned(spellID)
	-- @return boolean 
	local ID, Name
	if type(self) == "table" then 
		ID = self.ID 
		Name = self:Info()
	else 
		ID = self 
		Name = A_GetSpellInfo(ID)
	end	
	return TalentMap[Name] and TalentMap[Name] > 0 or false 
end

-- Remap to keep old code working for it 
-- TODO: Remove in the future
A.IsSpellLearned = A.IsTalentLearned

-------------------------------------------------------------------------------
-- Racial (template)
-------------------------------------------------------------------------------	 
local Racial = {
	GetRaceBySpellName 										= {
		-- Perception 
		[Spell:CreateFromSpellID(20600):GetSpellName()] 	= "Human",
		-- Shadowmeld
		[Spell:CreateFromSpellID(20580):GetSpellName()] 	= "NightElf",
		-- EscapeArtist
		[Spell:CreateFromSpellID(20589):GetSpellName()] 	= "Gnome",
		-- Stoneform
		[Spell:CreateFromSpellID(20594):GetSpellName()] 	= "Dwarf",
		-- WilloftheForsaken
		[Spell:CreateFromSpellID(7744):GetSpellName()] 		= "Scourge", 				-- (this is confirmed) Undead 
		-- Berserking
		[Spell:CreateFromSpellID(20554):GetSpellName()] 	= "Troll",
		-- WarStomp
		[Spell:CreateFromSpellID(20549):GetSpellName()] 	= "Tauren",
		-- BloodFury
		[Spell:CreateFromSpellID(20572):GetSpellName()] 	= "Orc",
	},
	Temp													= {
		TotalAndMagic 										= {"TotalImun", "DamageMagicImun"},
		TotalAndPhysAndCC									= {"TotalImun", "DamagePhysImun", "CCTotalImun"},
		TotalAndPhysAndCCAndStun							= {"TotalImun", "DamagePhysImun", "CCTotalImun", "StunImun"},
	},
	-- Functions	
	CanUse 													= function(this, self, unitID)
		-- @return boolean 
		A.PlayerRace = this.GetRaceBySpellName[self:Info()]
		
		-- Iterrupts 
		if A.PlayerRace == "Tauren" then 
			return 	Player:IsStaying() and 
					(
						(
							unitID and 	
							Unit(unitID):IsEnemy() and 
							Unit(unitID):GetRange() <= 8 and 					
							Unit(unitID):IsControlAble("stun") and 
							self:AbsentImun(unitID, this.Temp.TotalAndPhysAndCCAndStun)
						) or 
						(
							(
								not unitID or 
								not Unit(unitID):IsEnemy() 
							) and 
							MultiUnits:GetByRange(8, 1) >= 1
						)
					)	
		end 
		
		if A.PlayerRace == "Gnome" then 
			return Player:IsStaying() 
		end 

		-- [NO LOGIC - ALWAYS TRUE] 
		return true 		 			
	end,
	CanAuto													= function(this, self, unitID)
		-- Loss Of Control 
		-- "Gnome", "Scourge", "Dwarf"
		local LOC = LoC.GetExtra[A.PlayerRace]
		if LOC then 
			if LoC:IsValid(LOC.Applied, LOC.Missed) then 
				return true 
			else 
				return false 
			end 
		end 	
		
		-- Iterrupts 
		if A.PlayerRace == "Tauren" then 
			return  (
						unitID and 					
						Unit(unitID):IsCastingRemains() > A_GetCurrentGCD() + 0.7
					) or 
					(
						(
							not unitID or 
							not Unit(unitID):IsEnemy() 
						) and 
						MultiUnits:GetCasting(8, 1) >= 1
					)			  
		end 		

		-- Control Avoid 
		if A.PlayerRace == "NightElf" then 
			if A.Zone == "pvp" then 
				-- Check Freezing Trap 
				if 	UnitCooldown:GetCooldown("arena", SPELLID_FREEZING_TRAP) > UnitCooldown:GetMaxDuration("arena", SPELLID_FREEZING_TRAP) - 2 and 
					UnitCooldown:IsSpellInFly("arena", SPELLID_FREEZING_TRAP) and 
					Unit("player"):GetDR("incapacitate") > 0 
				then 
					local Caster = UnitCooldown:GetUnitID("arena", SPELLID_FREEZING_TRAP)
					if Caster and not Player:IsStealthed() and Unit(Caster):GetRange() <= 40 and (Unit("player"):GetDMG() == 0 or not Unit("player"):IsFocused()) then 
						return true 
					end 
				end 
			end 
			
			return false 
		end 			
		
		-- Bursting 
		if ( A.PlayerRace == "Troll" or A.PlayerRace == "Orc" ) then 
			return BurstIsON(unitID)
		end 	
		
		-- [NO LOGIC - ALWAYS TRUE] 
		return true 		
	end, 
}

function A:IsRacialReady(unitID, skipRange, skipLua, skipShouldStop)
	-- @return boolean 
	-- For [3-4, 6-8]
	return self:RacialIsON() and self:IsReady(unitID, isSpellRangeException[self.ID] or skipRange, skipLua, skipShouldStop) and Racial:CanUse(self, unitID) 
end 

function A:IsRacialReadyP(unitID, skipRange, skipLua, skipShouldStop)
	-- @return boolean 
	-- For [1-2, 5]
	return self:RacialIsON() and self:IsReadyP(unitID, isSpellRangeException[self.ID] or skipRange, skipLua, skipShouldStop) and Racial:CanUse(self, unitID) 
end 

function A:AutoRacial(unitID, skipRange, skipLua, skipShouldStop)
	-- @return boolean 
	return self:IsRacialReady(unitID, skipRange, skipLua, skipShouldStop) and Racial:CanAuto(self, unitID)
end 

-------------------------------------------------------------------------------
-- Item (provided by TMW)
-------------------------------------------------------------------------------	  
function A.GetItemDescription(self)
	-- @usage A:GetItemDescription() or A.GetItemDescription(18)
	-- @return table 
	-- Note: It returns correct value only if item holds spell 
	local _, spellID = GetItemSpell(type(self) == "table" and self.ID or self)
	if spellID then 
		return A_GetSpellDescription(spellID)
	end 
	
	return nullDescription -- can not be used for 'next', 'unpack', 'pairs', 'ipairs'
end
A.GetItemDescription = A.MakeFunctionCachedDynamic(A.GetItemDescription)

local itemspellcache = setmetatable({}, { __index = function(t, v)
    local a = { GetItemSpell(v) }
	if #a > 0 then 
		t[v] = a
	end 
    return a
end })
function A:GetItemSpell()
	-- @return string, number or nil 
	-- Returns: spellName, spellID or nil 
	return unpack(itemspellcache[self.ID])
end

function A:GetItemCooldown()
	-- @return number
	local start, duration, enable = self.Item:GetCooldown()
	return enable ~= 0 and ((duration == 0 or A_OnGCD(duration)) and 0 or duration - (TMW.time - start)) or huge
end 

function A:GetItemCategory()
	-- @return string 
	-- Note: Only for Type "TrinketBySlot"
	return itemCategory[self.ID]
end 

function A:IsItemTank()
	-- @return boolean 
	local cat = itemCategory[self.ID]
	return not cat or (cat ~= "DPS" and cat ~= "MISC" and cat ~= "CC")
end 

function A:IsItemDamager()
	-- @return boolean 
	local cat = itemCategory[self.ID]
	return not cat or (cat ~= "DEFF" and cat ~= "MISC" and cat ~= "CC")
end 

function A:IsItemCurrent()
	-- @return boolean
	return IsCurrentItem((self:Info()))
end 

-- Next works by TMW components
-- A:IsInRange(unitID) (in Shared)
-- A:GetCount() (in Shared)
-- A:GetEquipped() 
-- A:GetCooldown() (in Shared)
-- A:GetCooldownDuration() 
-- A:GetCooldownDurationNoGCD() 
-- A:GetID() 
-- A:GetName() 
-- A:HasUseEffect() 

-------------------------------------------------------------------------------
-- Shared
-------------------------------------------------------------------------------	  
function A:IsExists(replacementByPass)   
	-- @return boolean
	if self.Type == "Spell" then 
		-- DON'T USE HERE A.GetSpellInfo COZ IT'S CACHE WHICH WILL WORK WRONG DUE RACE CHANGES
		local spellName, _, _, _, _, _, spellID = GetSpellInfo((self:Info())) 
		-- spellID will be nil in case of if it's not a player's spell 
		-- spellName will not be equal to self:Info() if it's replacement spell like "Chi-Torpedo" and "Roll"
		return (not replacementByPass or spellName == self:Info()) and type(spellID) == "number" and (IsPlayerSpell(spellID) or (Pet:IsActive() and Pet:IsSpellKnown(spellID)) or FindSpellBookSlotBySpellID(spellID, false))
	end 
	
	if self.Type == "SwapEquip" then 
		return self.Equip1() or self.Equip2()
	end 
	
	return self:GetEquipped() or self:GetCount() > 0	
end

function A:IsUsable(extraCD, skipUsable)
	-- @return boolean 
	-- skipUsable can be number to check specified power 
	
	if self.Type == "Spell" then 
		-- Works for pet spells 01/04/2019
		return (skipUsable == true or (type(skipUsable) == "number" and Unit("player"):Power() >= skipUsable) or IsUsableSpell((self:Info()))) and self:GetCooldown() <= A_GetPing() + CACHE_DEFAULT_TIMER + (self:IsRequiredGCD() and A_GetCurrentGCD() or 0) + (extraCD or 0)
	end 
	
	return not isItemUseException[self.ID] and (skipUsable == true or (type(skipUsable) == "number" and Unit("player"):Power() >= skipUsable) or IsUsableItem((self:Info()))) and self:GetItemCooldown() <= A_GetPing() + CACHE_DEFAULT_TIMER + (self:IsRequiredGCD() and A_GetCurrentGCD() or 0) + (extraCD or 0)
end

function A:IsHarmful()
	-- @return boolean 
	if self.Type == "Spell" then 
		return IsHarmfulSpell((self:Info())) or IsAttackSpell((self:Info()))
	end 
	
	return IsHarmfulItem((self:Info()))
end 

function A:IsHelpful()
	-- @return boolean 
	if self.Type == "Spell" then 
		return IsHelpfulSpell((self:Info()))
	end 
	
	return IsHelpfulItem((self:Info()))
end 

function A:IsInRange(unitID)
	-- @return boolean
	if self.skipRange then 
		return true 
	end 
	
	local unitID = unitID or "target"
	
	if self.Type == "SwapEquip" or UnitIsUnit("player", unitID) then 
		return true 
	end 
	
	if self.Type == "Spell" then 
		return self:IsSpellInRange(unitID)
	end 
	
	return self.Item:IsInRange(unitID)
end 

function A:IsCurrent()
	-- @return boolean
	-- Note: Only Spell, Item, Trinket 
	return (self.Type == "Spell" and self:IsSpellCurrent()) or ((self.Type == "Item" or self.Type == "Trinket") and self:IsItemCurrent()) or false 
end 

function A:HasRange()
	-- @return boolean 
	if self.Type == "Spell" then 
		local Name = self:Info()
		return Name and not isSpellRangeException[self.ID] and SpellHasRange(Name)
	end 
	
	if self.Type == "SwapEquip" then
		return false 
	end 
	
	return not isItemRangeException[self:GetID()] and ItemHasRange((self:Info()))
end 

function A:GetCooldown()
	-- @return number
	if self.Type == "SwapEquip" then 
		return (Player:IsSwapLocked() and huge) or 0
	end 
	
	if self.Type == "Spell" then 
		if self.isStance then 
			local start, duration = GetShapeshiftFormCooldown(self.isStance)
			if start and start ~= 0 then
				return (duration == 0 and 0) or (duration - (TMW.time - start))
			end
			
			return 0
		else 
			return CooldownDuration((self:Info()))
		end 
	end 
	
	return self:GetItemCooldown()
end 

function A:GetCount()
	-- @return number
	if self.Type == "Spell" then 
		return GetSpellCount(self.ID) or 0
	end 
	
	return self.Item:GetCount() or 0
end 

function A:AbsentImun(unitID, imunBuffs)
	-- @return boolean 
	-- Note: Checks for friendly / enemy Imun auras and compares it with remain duration 
	if not unitID or UnitIsUnit(unitID, "player") then 
		return true 
	else 		
		local isTable = type(self) == "table"
		local isEnemy = Unit(unitID):IsEnemy()
		
		-- Super trick for Queue System, it will save in cache imunBuffs on first entire call by APL and Queue will be allowed to handle cache to compare Imun 
		if isTable and imunBuffs then 
			self.AbsentImunQueueCache = imunBuffs
		end 	
		
		local MinDur = ((not isTable or self.Type ~= "Spell") and 0) or self:GetSpellCastTime()
		if MinDur > 0 then 
			MinDur = MinDur + (self:IsRequiredGCD() and A_GetCurrentGCD() or 0)
		end
		
		if isEnemy and GetToggle(1, "StopAtBreakAble") and Unit(unitID):HasDeBuffs(IsBreakAbleDeBuff) > MinDur then 
			return false 
			--[[
			local debuffName, expirationTime, remainTime, _
			for i = 1, huge do			
				debuffName, _, _, _, _, expirationTime = UnitAura(unitID, i, "HARMFUL")
				if not debuffName then
					break 
				elseif IsBreakAbleDeBuff[debuffName] then 
					remainTime = expirationTime == 0 and huge or expirationTime - TMW.time
					if remainTime > MinDur then 
						return false 
					end 
				end 
			end ]]
		end 
		
		if isEnemy and imunBuffs and A.IsInPvP and Unit(unitID):IsPlayer() and Unit(unitID):HasBuffs(imunBuffs) > MinDur then 
			return false 
		end 

		return true
	end 
end 

function A:IsBlockedByAny()
	-- @return boolean
	return self:IsBlocked() or self:IsBlockedByQueue() or (self.Type == "Spell" and (self:IsBlockedBySpellBook() or (self.isTalent and not self:IsTalentLearned()))) or (self.Type ~= "Spell" and self.Type ~= "SwapEquip" and self:GetCount() == 0 and not self:GetEquipped())
end 

function A:IsSuspended(delay, reset)
	-- @return boolean
	-- Returns true if action should be delayed before use, reset argument is a internal refresh cycle of expiration future time
	if (self.expirationSuspend or 0) + reset <= TMW.time then
		self.expirationSuspend = TMW.time + delay
	end 

	return self.expirationSuspend > TMW.time
end

function A:IsCastable(unitID, skipRange, skipShouldStop, isMsg, skipUsable)
	-- @return boolean
	-- Checks toggle, cooldown and range 
	
	if isMsg or ((skipShouldStop or not self.ShouldStop()) and not self:ShouldStopByGCD()) then 
		if 	self.Type == "Spell" and 
			not self:IsBlockedBySpellBook() and 
			( not self.isTalent or self:IsTalentLearned() ) and 
			--( not self.isReplacement or self:IsExists(true) ) and 
			self:IsUsable(nil, skipUsable) and 
			( skipRange or not unitID or not self:HasRange() or self:IsInRange(unitID) )
		then 
			return true 				
		end 
		
		if 	self.Type == "Trinket" then 
			local ID = self.ID		
			if 	ID ~= nil and 
				-- This also checks equipment (in idea because slot return ID which we compare)
				( A.Trinket1.ID == ID and GetToggle(1, "Trinkets")[1] or A.Trinket2.ID == ID and GetToggle(1, "Trinkets")[2] ) and 
				self:IsUsable(nil, skipUsable) and 
				( skipRange or not unitID or not self:HasRange() or self:IsInRange(unitID) )
			then 
				return true 
			end 
		end 
		
		if 	self.Type == "Potion" and 
			GetToggle(1, "Potion") and 
			self:GetCount() > 0 and 
			self:GetItemCooldown() == 0 
		then
			return true 
		end 
		
		if  self.Type == "Item" and 
			( self:GetCount() > 0 or self:GetEquipped() ) and 
			self:GetItemCooldown() == 0 and 
			( skipRange or not unitID or not self:HasRange() or self:IsInRange(unitID) )
		then
			return true 
		end 
	end 
	
	return false 
end

function A:IsReady(unitID, skipRange, skipLua, skipShouldStop, skipUsable)
	-- @return boolean
	-- For [3-4, 6-8]
    return 	not self:IsBlocked() and 
			not self:IsBlockedByQueue() and 
			self:IsCastable(unitID, skipRange, skipShouldStop, nil, skipUsable) and 
			( skipLua or self:RunLua(unitID) )
end 

function A:IsReadyP(unitID, skipRange, skipLua, skipShouldStop, skipUsable)
	-- @return boolean
	-- For [1-2, 5]
    return 	self:IsCastable(unitID, skipRange, skipShouldStop, nil, skipUsable) and (skipLua or self:RunLua(unitID))
end 

function A:IsReadyM(unitID, skipRange, skipUsable)
	-- @return boolean
	-- For MSG System or bypass ShouldStop with GCD checks and blocked conditions 
	if unitID == "" then 
		unitID = nil 
	end 
    return 	self:IsCastable(unitID, skipRange, nil, true, skipUsable) and self:RunLua(unitID)
end 

function A:IsReadyByPassCastGCD(unitID, skipRange, skipLua, skipUsable)
	-- @return boolean
	-- For [3-4, 6-8]
    return 	not self:IsBlocked() and 
			not self:IsBlockedByQueue() and 
			self:IsCastable(unitID, skipRange, nil, true, skipUsable) and 
			( skipLua or self:RunLua(unitID) )
end 

function A:IsReadyByPassCastGCDP(unitID, skipRange, skipLua, skipUsable)
	-- @return boolean
	-- For [1-2, 5]
    return 	self:IsCastable(unitID, skipRange, nil, true, skipUsable) and (skipLua or self:RunLua(unitID))
end 

function A:IsReadyToUse(unitID, skipShouldStop, skipUsable)
	-- @return boolean 
	-- Note: unitID is nil here always 
	return 	not self:IsBlocked() and 
			not self:IsBlockedByQueue() and 
			self:IsCastable(nil, true, skipShouldStop, nil, skipUsable)
end 

-------------------------------------------------------------------------------
-- Determine
-------------------------------------------------------------------------------
function A.DetermineHealObject(unitID, skipRange, skipLua, skipShouldStop, skipUsable, ...)
	-- @return object or nil 
	-- Note: :PredictHeal(unitID) must be only ! Use 'self' inside to determine by that which spell is it 
	local unitGUID = UnitGUID(unitID)
	for i = 1, select("#", ...) do 
		local object = select(i, ...)
		if object:IsReady(unitID, skipRange, skipLua, skipShouldStop, skipUsable) and object:PredictHeal(unitID, object:GetSpellCastTimeCache() ~= 0 and A.GetSpellCastTimeCache(A.LastPlayerCastName) ~= 0 and CombatTracker:GetSpellLastCast("player", A.LastPlayerCastName) < 0.5 and 2 or nil, unitGUID) then -- Only Classic has a bit delay like 'flying' spells before heal up some amount after cast			
			return object
		end 
	end 
end 

function A.DetermineUsableObject(unitID, skipRange, skipLua, skipShouldStop, skipUsable, ...)
	-- @return object or nil 
	for i = 1, select("#", ...) do 
		local object = select(i, ...)
		if object:IsReady(unitID, skipRange, skipLua, skipShouldStop, skipUsable) then 
			return object
		end 
	end 
end 

function A.DetermineIsCurrentObject(...)
	-- @return object or nil 
	for i = 1, select("#", ...) do 
		local object = select(i, ...)
		if object:IsCurrent() then 
			return object
		end 
	end 
end 

function A.DetermineCountGCDs(...)
	-- @return number, count of required summary GCD times to use all in vararg
	local count = 0
	for i = 1, select("#", ...) do 
		local object = select(i, ...)		
		if (not object.isStance or A.PlayerClass ~= "WARRIOR") and object:IsRequiredGCD() and not object:IsBlocked() and not object:IsBlockedBySpellBook() and (not object.isTalent or object:IsTalentLearned()) and object:GetCooldown() <= A_GetPing() + CACHE_DEFAULT_TIMER + A_GetCurrentGCD() then 
			count = count + 1
		end 
	end 	
	return count
end 

function A.DeterminePowerCost(...)
	-- @return number (required power to use all varargs actions)
	local total = 0
	for i = 1, select("#", ...) do 
		local object = select(i, ...)
		if object and object:IsReadyToUse(nil, true, true) then 
			total = total + object:GetSpellPowerCostCache()
		end 
	end 
	return total
end 

function A.DetermineCooldown(...)
	-- @return number (required summary cooldown time to use all varargs actions)
	local total = 0
	for i = 1, select("#", ...) do 
		local object = select(i, ...)
		if object then 
			total = total + object:GetCooldown()
		end 
	end 
	return total
end 

function A.DetermineCooldownAVG(...)
	-- @return number (required AVG cooldown to use all varargs actions)
	local total, count = 0, 0
	for i = 1, select("#", ...) do 
		local object = select(i, ...)
		if object then 
			total = total + object:GetCooldown()
			count = count + 1
		end 
	end 
	if count > 0 then 
		return total / count
	else 
		return 0 
	end 
end 

-------------------------------------------------------------------------------
-- Misc
-------------------------------------------------------------------------------
-- KeyName
local function tableSearch(self, array)
	for k, v in pairs(array) do 
		if type(v) == "table" and self == v then 
			return k 
		end 
	end 
end 

function A:GetKeyName()
	-- Returns @nil or @string as key name in the table
	return tableSearch(self, A[A.PlayerClass]) or tableSearch(self, A)
end 

-- Spell  
local spellinfocache = setmetatable({}, { __index = function(t, v)
    local a = { GetSpellInfo(v) }
	t[v] = a
    return a
end })

function A:GetSpellInfo()
	local ID = self
	if type(self) == "table" then 
		ID = self.ID 
	end
	
	if ID then 
		return unpack(spellinfocache[ID])
	end 
end

function A:GetSpellLink()
	local ID = self
	if type(self) == "table" then 
		ID = self.ID 
	end
    return GetSpellLink(ID) or ""
end 

function A:GetSpellIcon()
	return select(3, self:GetSpellInfo())
end

function A:GetSpellTexture(custom)
    return "texture", GetSpellTexture(custom or self.ID)
end 

--- Spell Colored Texturre
function A:GetColoredSpellTexture(custom)
    return "state; texture", {Color = A.Data.C[self.Color] or self.Color, Alpha = 1, Texture = ""}, GetSpellTexture(custom or self.ID)
end 

-- SingleColor
function A:GetColorTexture()
    return "state", {Color = A.Data.C[self.Color] or self.Color, Alpha = 1, Texture = "ERROR"}
end 

-- Item
local iteminfocache = setmetatable({}, { __index = function(t, v)	
	local a = { GetItemInfo(v) }
	if #a > 0 then 
		t[v] = a
	end 
	return a	
end })

function A:GetItemInfo(custom)
	local ID	
	local isTable = not custom and type(self) == "table"
	if isTable then 
		ID = self.ID 
	else 
		ID = custom or self 
	end
	
	if ID then 
		if #iteminfocache[ID] > 1 then 
			return unpack(iteminfocache[ID]) 
		elseif isTable then 
			local spellName = self:GetItemSpell()			
			return spellName or self:GetKeyName()
		end
	end 
end

function A:GetItemLink()
    return select(2, self:GetItemInfo()) or ""
end 

function A:GetItemIcon(custom)
	return select(10, self:GetItemInfo(custom)) or select(5, GetItemInfoInstant(custom or self.ID))
end

function A:GetItemTexture(custom)
	local texture
	if self.Type == "Trinket" then 
		if A.Trinket1.ID == self.ID then 
			texture = TRINKET1
		else 
			texture = TRINKET2
		end
	elseif self.Type == "Potion" then 
		texture = POTION
	else 
		texture = self:GetItemIcon(custom)
	end
	
    return "texture", texture
end 

-- Item Colored Texture
function A:GetColoredItemTexture(custom)
    return "state; texture", {Color = A.Data.C[self.Color] or self.Color, Alpha = 1, Texture = ""}, (custom and GetItemIcon(custom)) or self:GetItemIcon()
end 

-- Swap Colored Texture
function A:GetColoredSwapTexture(custom)
    return "state; texture", {Color = A.Data.C[self.Color] or self.Color, Alpha = 1, Texture = ""}, custom or self.ID
end 

-------------------------------------------------------------------------------
-- UI: Create
-------------------------------------------------------------------------------
-- Receive information from server about items before start UI builder
local ItemIDs = {} 
hooksecurefunc(TMW, "SortOrderedTables", function()
	-- This function working only before RunSnippet
	if #ItemIDs > 0 then 
		for _, id in ipairs(ItemIDs) do 
			GetItemInfo(id)
		end 
		wipe(ItemIDs)
	end
end)

-- Debug created actions 
local TableKeys = {}
TMW:RegisterCallback("TMW_ACTION_IS_INITIALIZED", function()
	-- Debug for SetBlocker and SetQueue for shared internal table keys 	
	local err 
	if A[A.PlayerClass] then 
		for key, action in pairs(A[A.PlayerClass]) do 
			if type(action) == "table" and action:IsActionTable() and not action.Hidden then 				
				if TableKeys[action:GetTableKeyIdentify()] then 
					err = (err or "Script found duplicate .TableKeyIdentify:\n") .. key .. " = " .. TableKeys[action:GetTableKeyIdentify()] .. ". Output: " .. action.TableKeyIdentify .. "\n"
				else 
					TableKeys[action:GetTableKeyIdentify()] = key 
				end 				
			end 
		end 
		wipe(TableKeys)
	end 	
	
	if err then 
		error(err)
	end 
end)

-- Create action with args 
function A.Create(args)
	--[[@usage: args (table)
		Required: 
			Type (@string)	- Spell|SpellSingleColor|Item|ItemSingleColor|Potion|Trinket|TrinketBySlot|ItemBySlot|SwapEquip (TrinketBySlot, ItemBySlot is only in CORE!)
			ID (@number) 	- spellID | itemID | textureID (textureID only for Type "SwapEquip")
			Color (@string) - only if type is Spell|SpellSingleColor|Item|ItemSingleColor|SwapEquip, this will set color which stored in A.Data.C[Color] or here can be own hex 
	 	Optional: 
			Desc (@string) uses in UI near Icon tab (usually to describe relative action like Penance can be for heal and for dps and it's different actions but with same name)
			BlockForbidden (@boolean) uses to preset for action fixed block valid 
			QueueForbidden (@boolean) uses to preset for action fixed queue valid 
			Texture (@number) valid only if Type is Spell|Item|Potion|Trinket|SwapEquip
			FixedTexture (@number or @file) valid only if Type is Spell|Item|Potion|Trinket|SwapEquip
			MetaSlot (@number) allows set fixed meta slot use for action whenever it will be tried to set in queue 
			Hidden (@boolean) allows to hide from UI this action 
			isStance (@number) will check in :GetCooldown cooldown timer by GetShapeshiftFormCooldown function instead of default, only if Type is Spell|SpellSingleColor			
			isTalent (@boolean) will check in :IsCastable method condition through :IsTalentLearned(), only if Type is Spell|SpellSingleColor
			isReplacement (@boolean) will check in :IsCastable method condition through :IsExists(true), only if Type is Spell|SpellSingleColor	
			isRank (@number) will use specified rank for spell (additional frame for color below TargetColor), only if Type is Spell|SpellSingleColor			
			isCP (@boolean) is used only for combo points with type Spell|SpellSingleColor to use as condition in Queue core, it's required to be noted manually due specific way of how it work
			useMaxRank (@boolean or @table) will overwrite current ID by highest available rank and apply isRank number, example of table use {1, 2, 4, 6, 7}, only if Type is Spell|SpellSingleColor 
			useMinRank (@boolean or @table) will overwrite current ID by lowest available rank and apply isRank number, example of table use {1, 2, 4, 6, 7}, only if Type is Spell|SpellSingleColor
			skipRange (@boolean) will skip check in :IsInRange method which is also used by Queue system, only if Type is Spell|SpellSingleColor|Item|ItemSingleColor|Trinket|TrinketBySlot
			Equip1, Equip2 (@function) between which equipments do swap, used in :IsExists method, only if Type is SwapEquip
			... any custom key-value will be inserted also 
						
		So the conception of Classic is to use own texture for any ranks and additional frame which will determine rank whenever it need, we assume what by default no need to determine rank if we use useMaxRank
		Otherwise it will interract with additional frame  
	]]
	local arg 	= args or {}	
	arg.Desc 	= arg.Desc or ""
	arg.SubType = arg.Type
	
	-- Type "Spell" 
	if arg.Type == "Spell" then 	
		-- Methods Remap		
		arg.Info = A.GetSpellInfo
		arg.Link = A.GetSpellLink		
		arg.Icon = A.GetSpellIcon
		if arg.Color then 
			if arg.Texture then 
				arg.TextureID = arg.Texture
				arg.Texture = function()
					return A.GetColoredSpellTexture(arg, arg.TextureID)
				end 
			elseif arg.FixedTexture then 
				arg.Texture = function()
					return "texture", arg.FixedTexture
				end 				
			else 
				arg.Texture = A.GetColoredSpellTexture
			end 		
		else 
			if arg.Texture then 
				arg.TextureID = arg.Texture
				arg.Texture = function()
					return A.GetSpellTexture(arg, arg.TextureID)
				end 
			elseif arg.FixedTexture then 
				arg.Texture = function()
					return "texture", arg.FixedTexture
				end 
			else 
				arg.Texture = A.GetSpellTexture	
			end						
		end 
		
		-- Power 
		arg.PowerCost, arg.PowerType = A.GetSpellPowerCostCache(arg.ID)

		-- Ranks 
		if type(arg.useMaxRank) == "table" then 
			tsort(arg.useMaxRank)
		end 	 
		if type(arg.useMinRank) == "table" then 
			tsort(arg.useMinRank)
		end 

		return setmetatable(arg, { __index = A }) 
	end 
	
	-- Type "Spell" 
	if arg.Type == "SpellSingleColor" then 
		-- Forced Type 
		arg.Type = "Spell"
		-- Methods Remap
		arg.Info = A.GetSpellInfo
		arg.Link = A.GetSpellLink		
		arg.Icon = A.GetSpellIcon
		-- This using static and fixed only color so no need texture
		arg.Texture = A.GetColorTexture			
		-- Power 
		arg.PowerCost, arg.PowerType = A.GetSpellPowerCostCache(arg.ID)	
		-- Ranks
		if type(arg.useMaxRank) == "table" then 
			tsort(arg.useMaxRank)
		end 		 
		if type(arg.useMinRank) == "table" then 
			tsort(arg.useMinRank)
		end 	
		
		return setmetatable(arg, { __index = A })
	end 
	
	-- Type "Trinket", "Potion", "Item"
	if arg.Type == "Trinket" or arg.Type == "Potion" or arg.Type == "Item" then 
		-- Methods Remap
		arg.Info = A.GetItemInfo
		arg.Link = A.GetItemLink		
		arg.Icon = A.GetItemIcon
		if arg.Color then 
			if arg.Texture then 
				arg.TextureID = arg.Texture
				arg.Texture = function()
					return A.GetColoredItemTexture(arg, arg.TextureID)
				end 
			elseif arg.FixedTexture then 
				arg.Texture = function()
					return "texture", arg.FixedTexture
				end 				
			else 
				arg.Texture = A.GetColoredItemTexture
			end 		
		else 		
			if arg.Texture then 
				arg.TextureID = arg.Texture
				arg.Texture = function()
					return A.GetItemTexture(arg, arg.TextureID)
				end 
			elseif arg.FixedTexture then 
				arg.Texture = function()
					return "texture", arg.FixedTexture
				end 				
			else 
				arg.Texture = A.GetItemTexture
			end 
		end	
		-- Misc
		arg.Item = TMW.Classes.ItemByID:New(arg.ID)
		ItemIDs[#ItemIDs + 1] = arg.ID
		
		return setmetatable(arg, { __index = function(self, key)
			if A[key] then
				return A[key]
			else
				return self.Item[key]
			end
		end })
	end 	
	
	-- Type "Trinket", "Item"
	if arg.Type == "TrinketBySlot" or arg.Type == "ItemBySlot" then 
		-- Forced Type 
		if arg.Type == "TrinketBySlot" then 
			arg.Type = "Trinket"
		else 
			arg.Type = "Item"
		end 
		-- Methods Remap
		arg.Info = A.GetItemInfo
		arg.Link = A.GetItemLink		
		arg.Icon = A.GetItemIcon
		if arg.Color then 
			if arg.Texture then 
				arg.TextureID = arg.Texture
				arg.Texture = function()
					return A.GetColoredItemTexture(arg, arg.TextureID)
				end 				
			else 
				arg.Texture = A.GetColoredItemTexture
			end 		
		else 		
			if arg.Texture then 
				arg.TextureID = arg.Texture
				arg.Texture = function()
					return A.GetItemTexture(arg, arg.TextureID)
				end 				
			else 
				arg.Texture = A.GetItemTexture
			end 
		end	
		-- Misc
		arg.Item = TMW.Classes.ItemBySlot:New(arg.ID)
		if arg.Item:GetID() then 	
			ItemIDs[#ItemIDs + 1] = arg.Item:GetID()
		end 
		arg.ID = nil
		
		return setmetatable(arg, { __index = function(self, key)
			if key == "ID" then 
				return self.Item:GetID()
			end 
			
			if A[key] then
				return A[key]
			else
				return self.Item[key]
			end
		end })
	end 
	
	-- Type "Item"
	if arg.Type == "ItemSingleColor" then
		-- Forced Type 
		arg.Type = "Item" 
		-- Methods Remap
		arg.Info = A.GetItemInfo
		arg.Link = A.GetItemLink		
		arg.Icon = A.GetItemIcon
		-- This using static and fixed only color so no need texture
		arg.Texture = A.GetColorTexture		
		-- Misc 
		arg.Item = TMW.Classes.ItemByID:New(arg.ID)
		ItemIDs[#ItemIDs + 1] = arg.ID
		
		return setmetatable(arg, { __index = function(self, key)
			if A[key] then
				return A[key]
			else
				return self.Item[key]
			end
		end })
	end 	
	
	-- Type "SwapEquip"	
	if arg.Type == "SwapEquip" then 
		-- Methods Remap
		arg.Info = function()
			return EQUIPMENT_MANAGER
		end 
		arg.Link = arg.Info		
		arg.Icon = function()
			return arg.ID 
		end 
		if arg.Color then 
			if arg.Texture then 
				arg.TextureID = arg.Texture
				arg.Texture = function()
					return A.GetColoredSwapTexture(arg, arg.TextureID)
				end 
			elseif arg.FixedTexture then 
				arg.Texture = function()
					return "texture", arg.FixedTexture
				end 				
			else 
				arg.Texture = A.GetColoredSwapTexture
			end 		
		else 		
			if arg.Texture then 
				arg.TextureID = arg.Texture
				arg.Texture = function()
					return "texture", arg.TextureID
				end 
			elseif arg.FixedTexture then 
				arg.Texture = function()
					return "texture", arg.FixedTexture
				end 				
			else 
				arg.Texture = function()
					return "texture", arg.ID
				end 
			end 
		end	
		
		return setmetatable(arg, { __index = A })	
	end 
	
	-- nil
	arg.Hidden = true 		
	return setmetatable(arg, { __index = A })		 
end 