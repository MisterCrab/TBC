--[[ DOCUMENTATION:
-- Healing Engine has callback "TMW_ACTION_HEALINGENGINE_UNIT_UPDATE"
TMW:RegisterCallback("TMW_ACTION_HEALINGENGINE_UNIT_UPDATE", function(callbackEvent, thisUnit, db, QueueOrder)
	-- Example of implementation is function PerformByProfileHP (in that func 'self' is 'thisUnit')
	-- QueueOrder is used to save some FPS due iterations through all units, 
	-- So once required role is found for certain options (i.e. useDispel)
	-- we can save it for that role and don't use this check again for same role which will save FPS
	
	-- 'thisUnit' has all keys from :Setup method, like:
	-- Unit 			= unitID
	-- GUID 			= unitGUID			
	-- HP 				= 0-100									-- Modified Health Percent
	-- AHP 				= 0-huge 								-- Modified Health Actual
	-- MHP				= 0-huge								-- Maximum  Health Actual
	-- Role 			= "TANK", "HEALER", "DAMAGER", "NONE" 	-- Pet has "DAMAGER" role here
	-- LUA 				= @string 
	-- Enabled  		= @boolean								-- For function SetHealingTarget
	-- useDispel		= @boolean 
	-- useShields		= @boolean 
	-- useHoTs			= @boolean 
	-- useUtils			= @boolean 								-- Offensive and supportive spells such as BoP, Freedom and etc 
	-- isPlayer 		= @boolean 
	-- isPet 			= @boolean 
	-- isSelf	 		= @boolean 
	-- isSelectAble		= @boolean 								-- If possible to target that unit 
	-- incDMG 			= 0-huge 
	-- incOffsetDMG 	= 0-huge 
	-- realHP			= 0-100
	-- realAHP			= 0-huge 				
end)
-- Rest API located at the end of this file 
--]]

local _G, type, pairs, ipairs, setmetatable, table, unpack, math, error = 
	  _G, type, pairs, ipairs, setmetatable, table, unpack, math, error
	  
local TMW 								= _G.TMW

local A 								= _G.Action
local CONST 							= A.Const
local Listener							= A.Listener
local MakeFunctionCachedDynamic			= A.MakeFunctionCachedDynamic
local MakeFunctionCachedStatic			= A.MakeFunctionCachedStatic
local TeamCacheFriendly					= A.TeamCache.Friendly
local TeamCacheFriendlyUNITs			= TeamCacheFriendly.UNITs 			-- unitID to GUID 
local TeamCacheFriendlyGUIDs			= TeamCacheFriendly.GUIDs 			-- GUID to unitID 
local TeamCacheFriendlyIndexToPLAYERs	= TeamCacheFriendly.IndexToPLAYERs 	-- index to unitID 
local TeamCacheFriendlyIndexToPETs		= TeamCacheFriendly.IndexToPETs 	-- index to unitID
local GetToggle							= A.GetToggle
local AuraIsValid						= A.AuraIsValid
local BuildToC							= A.BuildToC
local StdUi								= A.StdUi
local RunLua							= StdUi.RunLua
local isClassic							= false -- StdUi.isClassic -- TBC has focus 

local GetLOS							= _G.GetLOS

--[[ Classic ]]
local playerClass						= A.PlayerClass

local LoadedLocals						= false
-- Paladin locals 
local BlessingofProtectionUnits, DispelUnits, BlessingofSacrificeUnits, BlessingofFreedomUnits
local IsAbleBoP, IsAbleDispel, IsAbleBoS, IsAbleBoF, IsAbleBlessingBuff
TMW:RegisterCallback("TMW_ACTION_PROFILE_DB_UPDATED", function()
	LoadedLocals						= false 
	
	if playerClass == "PALADIN" and A.PALADIN then 
		BlessingofProtectionUnits 		= GetToggle(2, "BlessingofProtectionUnits")
		DispelUnits 					= GetToggle(2, "DispelUnits")
		BlessingofSacrificeUnits 		= GetToggle(2, "BlessingofSacrificeUnits")
		BlessingofFreedomUnits 			= GetToggle(2, "BlessingofFreedomUnits")	
		IsAbleBoP						= A.IsAbleBoP 
		IsAbleDispel					= A.IsAbleDispel
		IsAbleBoS						= A.IsAbleBoS
		IsAbleBoF						= A.IsAbleBoF
		IsAbleBlessingBuff				= A.IsAbleBlessingBuff
		LoadedLocals					= true 
	end 
end)
--

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Remap
-------------------------------------------------------------------------------
local 	A_Unit, A_IsUnitFriendly, A_IsUnitEnemy, A_PauseChecks,
		-- [[ Classic ]]
		A_DetermineUsableObject
		-- 

Listener:Add("ACTION_EVENT_HEALINGENGINE", "ADDON_LOADED", function(addonName)
	if addonName == CONST.ADDON_NAME then 
		A_Unit 							= A.Unit 
		A_IsUnitFriendly 				= A.IsUnitFriendly
		A_IsUnitEnemy					= A.IsUnitEnemy
		A_PauseChecks					= A.PauseChecks
		
		-- [[ Classic ]]
		A_DetermineUsableObject			= A.DetermineUsableObject
		--

		Listener:Remove("ACTION_EVENT_HEALINGENGINE", "ADDON_LOADED")	
	end 
end)
-------------------------------------------------------------------------------
	  
local tremove							= table.remove 
local tsort								= table.sort 
local huge 								= math.huge
local math_max							= math.max
local math_min							= math.min
local wipe 								= _G.wipe

local 	 UnitGUID, 	  UnitIsUnit 		= 
	  _G.UnitGUID, _G.UnitIsUnit
	  	  
local PredictOptions, SelectStopOptions, dbUnitIDs, db, profileActionDB 
local inCombat, inGroup, maxGroupSize  
local player 							= "player"	 
local focus 							= "focus"
local target 							= "target"
local mouseover							= "mouseover"
local none 								= "none"
local healingTarget						= none 
local healingTargetGUID					= none 
local healingTargetDelay 				= 0	  
local healingTargetDelayByEvent			= false 
local isFocusHealing					= false

local frame 							= _G.CreateFrame("Frame", "TargetColor", _G.UIParent)
if _G.BackdropTemplateMixin == nil and frame.SetBackdrop then -- Only expac less than Shadowlands
	frame:SetBackdrop(nil)
end 
frame:SetFrameStrata("TOOLTIP")
frame:SetToplevel(true)
frame:SetSize(1, 1)
frame:SetScale(1)
frame:SetPoint("TOPLEFT", 163, 0)
frame.texture = frame:CreateTexture(nil, "TOOLTIP")
frame.texture:SetAllPoints(true)
frame.Colors 							= {
	none								= {0, 0, 0, 1},
	-- Party 
	party1								= {0.345098, 0.239216, 0.741176, 1},
	party2								= {0.407843, 0.501961, 0.086275, 1},
	party3								= {0.160784, 0.470588, 0.164706, 1},
	party4								= {0.725490, 0.572549, 0.647059, 1},
	-- Party pet
	partypet1							= {0.486275, 0.176471, 1.000000, 1},
	partypet2							= {0.031373, 0.572549, 0.152941, 1},
	partypet3							= {0.874510, 0.239216, 0.239216, 1},
	partypet4							= {0.117647, 0.870588, 0.635294, 1},	
	-- Raid 
	raid1								= {0.192157, 0.878431, 0.015686, 1},
	raid2								= {0.780392, 0.788235, 0.745098, 1},
	raid3								= {0.498039, 0.184314, 0.521569, 1},
	raid4								= {0.627451, 0.905882, 0.882353, 1},
	raid5								= {0.145098, 0.658824, 0.121569, 1},
	raid6								= {0.639216, 0.490196, 0.921569, 1},
	raid7								= {0.172549, 0.368627, 0.427451, 1},
	raid8								= {0.949020, 0.333333, 0.980392, 1},
	raid9								= {0.109804, 0.388235, 0.980392, 1},
	raid10								= {0.615686, 0.694118, 0.435294, 1},
	raid11								= {0.066667, 0.243137, 0.572549, 1},
	raid12								= {0.113725, 0.129412, 1.000000, 1},
	raid13								= {0.592157, 0.023529, 0.235294, 1},
	raid14								= {0.545098, 0.439216, 1.000000, 1},
	raid15								= {0.890196, 0.800000, 0.854902, 1},
	raid16								= {0.513725, 0.854902, 0.639216, 1},
	raid17								= {0.078431, 0.541176, 0.815686, 1},
	raid18								= {0.109804, 0.184314, 0.666667, 1},
	raid19								= {0.650980, 0.572549, 0.098039, 1},
	raid20								= {0.541176, 0.466667, 0.027451, 1},
	raid21								= {0.000000, 0.988235, 0.462745, 1},
	raid22								= {0.211765, 0.443137, 0.858824, 1},
	raid23								= {0.949020, 0.949020, 0.576471, 1},
	raid24								= {0.972549, 0.800000, 0.682353, 1},
	raid25								= {0.031373, 0.619608, 0.596078, 1},
	raid26								= {0.670588, 0.925490, 0.513725, 1},
	raid27								= {0.647059, 0.945098, 0.031373, 1},
	raid28								= {0.058824, 0.490196, 0.054902, 1},
	raid29								= {0.050980, 0.992157, 0.239216, 1},
	raid30								= {0.949020, 0.721569, 0.388235, 1},
	raid31								= {0.254902, 0.749020, 0.627451, 1},
	raid32								= {0.470588, 0.454902, 0.603922, 1},
	raid33								= {0.384314, 0.062745, 0.266667, 1},
	raid34								= {0.639216, 0.168627, 0.447059, 1},
	raid35								= {0.874510, 0.058824, 0.400000, 1},
	raid36								= {0.925490, 0.070588, 0.713725, 1},
	raid37								= {0.098039, 0.803922, 0.905882, 1},
	raid38								= {0.243137, 0.015686, 0.325490, 1},
	raid39								= {0.847059, 0.376471, 0.921569, 1},
	raid40								= {0.341176, 0.533333, 0.231373, 1},
	-- Raid pet
	raidpet1							= {0.458824, 0.945098, 0.784314, 1},
	raidpet2							= {0.239216, 0.654902, 0.278431, 1},
	raidpet3							= {0.537255, 0.066667, 0.905882, 1},
	raidpet4							= {0.333333, 0.415686, 0.627451, 1},
	raidpet5							= {0.576471, 0.811765, 0.011765, 1},
	raidpet6							= {0.517647, 0.164706, 0.627451, 1},
	raidpet7							= {0.439216, 0.074510, 0.941176, 1},
	raidpet8							= {0.984314, 0.854902, 0.376471, 1},
	raidpet9							= {0.082353, 0.286275, 0.890196, 1},
	raidpet10							= {0.058824, 0.003922, 0.964706, 1},
	raidpet11							= {0.956863, 0.509804, 0.949020, 1},
	raidpet12							= {0.474510, 0.858824, 0.031373, 1},
	raidpet13							= {0.509804, 0.882353, 0.423529, 1},
	raidpet14							= {0.337255, 0.647059, 0.427451, 1},
	raidpet15							= {0.611765, 0.525490, 0.352941, 1},
	raidpet16							= {0.921569, 0.129412, 0.913725, 1},
	raidpet17							= {0.117647, 0.933333, 0.862745, 1},
	raidpet18							= {0.733333, 0.015686, 0.937255, 1},
	raidpet19							= {0.819608, 0.392157, 0.686275, 1},
	raidpet20							= {0.823529, 0.976471, 0.541176, 1},
	raidpet21							= {0.043137, 0.305882, 0.800000, 1},
	raidpet22							= {0.737255, 0.270588, 0.760784, 1},
	raidpet23							= {0.807843, 0.368627, 0.058824, 1},
	raidpet24							= {0.364706, 0.078431, 0.078431, 1},
	raidpet25							= {0.094118, 0.901961, 1.000000, 1},
	raidpet26							= {0.772549, 0.690196, 0.047059, 1},
	raidpet27							= {0.415686, 0.784314, 0.854902, 1},
	raidpet28							= {0.470588, 0.733333, 0.047059, 1},
	raidpet29							= {0.619608, 0.086275, 0.572549, 1},
	raidpet30							= {0.517647, 0.352941, 0.678431, 1},
	raidpet31							= {0.003922, 0.149020, 0.694118, 1},
	raidpet32							= {0.454902, 0.619608, 0.831373, 1},
	raidpet33							= {0.674510, 0.741176, 0.050980, 1},
	raidpet34							= {0.560784, 0.713725, 0.784314, 1},
	raidpet35							= {0.400000, 0.721569, 0.737255, 1},
	raidpet36							= {0.094118, 0.274510, 0.392157, 1},
	raidpet37							= {0.298039, 0.498039, 0.462745, 1},
	raidpet38							= {0.125490, 0.196078, 0.027451, 1},
	raidpet39							= {0.937255, 0.564706, 0.368627, 1},
	raidpet40							= {0.929412, 0.592157, 0.501961, 1},
	-- Player 
	player 								= {0.788235, 0.470588, 0.858824, 1},
	-- Focus 
	focus 								= {0.615686, 0.227451, 0.988235, 1},
	-- Reserved
	--[[
	PLACEHOLDER							= {0.411765, 0.760784, 0.176471, 1},
	PLACEHOLDER							= {0.780392, 0.286275, 0.415686, 1},
	PLACEHOLDER							= {0.584314, 0.811765, 0.956863, 1},
	PLACEHOLDER							= {0.513725, 0.658824, 0.650980, 1},
	PLACEHOLDER							= {0.913725, 0.180392, 0.737255, 1},
	PLACEHOLDER							= {0.576471, 0.250980, 0.160784, 1},
	PLACEHOLDER							= {0.803922, 0.741176, 0.874510, 1},
	PLACEHOLDER							= {0.647059, 0.874510, 0.713725, 1},
	PLACEHOLDER							= {0.007843, 0.301961, 0.388235, 1},
	PLACEHOLDER							= {0.572549, 0.705882, 0.984314, 1},
	--]]
}
function frame:SetColor(unitID)
	local unit = unitID or none
	if (self.unit ~= unit or self.mode ~= isFocusHealing) and self.Colors[unit] then 	
		self.texture:SetColorTexture(unpack(self.Colors[unit]))
		self.unit = unit 
		self.unit = unit
		self.mode = isFocusHealing
		TMW:Fire("TMW_ACTION_METAENGINE_UPDATE", "HealingEngine", isFocusHealing and "focus" or "target", unit)
	end 		
end; frame:SetColor()

local function sort_high(x, y)			-- TODO: Remove (old profiles)
	return x > y
end

local function sort_incDMG(x, y)
	return x.incDMG > y.incDMG
end

local function sort_HP(x, y) 
	return x.HP < y.HP 
end

local function sort_AHP(x, y) 
	return x.AHP < y.AHP 
end

local Data; Data 						= {
	IsRunning							= false,	
	Aura 								= {
		Innervate						= 29166,			-- For ManaManagement (Classic has same ID)
	},
	UnitIDs  							= setmetatable(
		StdUi:tGenerateHealingEngineUnitIDs({
			-- Some keys can be placed here as initial but its pointless to do since meta method Wipe will remove it before we get with touch them 
		}), { __index = {
			Wipe 						= function()
				for _, v in pairs(Data.UnitIDs) do 
					wipe(v)
				end 
			end,
		},	}),		
	Frequency 							= setmetatable(
		{
			Actual 						= {},
			Temp 						= {},
		}, { __index = { 
			Wipe 						= function()
				for k, v in pairs(Data.Frequency) do 
					if type(v) == "table" then 
						wipe(v)
					else
						Data.Frequency[k] = nil 
					end 
				end 
			end,
		}, }),
	SortedUnitIDs						= setmetatable(
		{}, { __index = {
			Wipe 						= function()
				wipe(Data.SortedUnitIDs)
			end,
		},  }),
	SortedUnitIDs_MostlyIncDMG			= setmetatable(
		{}, { __index = {
			Wipe 						= function()
				wipe(Data.SortedUnitIDs_MostlyIncDMG)
			end,
		},  }),
	QueueOrder							= setmetatable(
		{
			useDispel					= {},
			useShields					= {},
			useHoTs						= {},
			useUtils					= {},
		}, { __index = {
			Wipe 						= function()
				for k, v in pairs(Data.QueueOrder) do 
					if type(v) == "table" then 
						wipe(v)
					else
						Data.QueueOrder[k] = nil 
					end 
				end 
			end,
		},  }),
	BossIDs								= setmetatable(
		{
			-- ["bossGUID"] = { ["holderUnitID"] = true, ["holderUnitID"] = true }
			-- Also jumper back ["holderUnitID"] = "bossGUID" 
		}, { __index = {
			Wipe 						= function()
				wipe(Data.BossIDs)
			end,
		},  }),	
}

-- Push in data some locals which can be used in custom profiles if necessary 
do 
	Data.frame 							= frame
	Data.isClassic						= isClassic
	Data.sort_incDMG					= sort_incDMG
	Data.sort_HP						= sort_HP
	Data.sort_AHP						= sort_AHP
end 

local Aura 								= Data.Aura
local UnitIDs							= Data.UnitIDs
local SortedUnitIDs						= Data.SortedUnitIDs
local SortedUnitIDs_MostlyIncDMG		= Data.SortedUnitIDs_MostlyIncDMG
local Frequency							= Data.Frequency
local FrequencyActual					= Frequency.Actual 
local FrequencyTemp						= Frequency.Temp
local QueueOrder						= Data.QueueOrder
local BossIDs							= Data.BossIDs

local function PerformByProfileHP(self)
	-- Enable specific instructions by profile 
	-- Note: Here is only players! This function doesn't perform pets anyhow!
	if not A.IsBasicProfile and A.IsGGLprofile then 
		local Role 			= self.Role
		local unitID 		= self.Unit
		
		if playerClass == "PRIEST" and A.PRIEST then 
			local PR = A.PRIEST			 
			
			-- Dispel
			if 	self.useDispel and not QueueOrder.useDispel[Role] and (not A.IsInPvP or not self.isSelf) and  
				(
					((AuraIsValid(unitID, "UseDispel", "Magic") or AuraIsValid(unitID, "UsePurge", "PurgeFriendly")) and PR.DispelMagic:IsReadyByPassCastGCD(unitID)) or 
					(A_Unit(unitID):HasBuffs(PR.AbolishDisease.ID) == 0 and AuraIsValid(unitID, "UseDispel", "Disease") and (PR.AbolishDisease:IsReadyByPassCastGCD(unitID) or PR.CureDisease:IsReadyByPassCastGCD(unitID)))
				)
			then 
				QueueOrder.useDispel[Role] = true 

				if self.isSelf then 
					self:SetupOffsets(db.OffsetSelfDispel, 25)
				elseif Role == "HEALER" then
					self:SetupOffsets(db.OffsetHealersDispel, 25)
				elseif Role == "TANK" then 
					self:SetupOffsets(db.OffsetTanksDispel, 30)
				else 
					self:SetupOffsets(db.OffsetDamagersDispel, 30)
				end 					
				return  							
			end

			-- Shields and HoTs 
			-- Sorts units by most lowest through .realHP 
			
			-- Shields
			if self.useShields and (not QueueOrder.useShields[Role] or QueueOrder.useShields[Role] > self.realHP) and GetToggle(2, "PreParePOWS") and PR.PowerWordShield:IsReadyByPassCastGCD(unitID) and A_Unit(unitID):HasDeBuffs(PR.WeakenedSoul.ID) == 0 and A_Unit(unitID):HasBuffs(PR.PowerWordShield.ID) == 0 and (inCombat or self.realHP < 100) then 				
				QueueOrder.useShields[Role] = self.realHP 
				
				if Role == "HEALER" then
					self:SetupOffsets(db.OffsetHealersShields, self.HP - 50)
				elseif Role == "TANK" then 
					self:SetupOffsets(db.OffsetTanksShields, self.HP - 50)
				else 
					self:SetupOffsets(db.OffsetDamagersShields, self.HP - 50)
				end 					
				return 			
			end 
			
			-- HoTs 
			if self.useHoTs and (not QueueOrder.useHoTs[Role] or QueueOrder.useHoTs[Role] > self.realHP) and GetToggle(2, "PrePareRenew") and A_Unit(unitID):HasBuffs(PR.Renew.ID, true) == 0 and self.realHP < 100 and (not GetToggle(2, "RenewOnlyTank") or A_Unit(unitID):IsTank()) then 
				local Renew = A_DetermineUsableObject(unitID, nil, nil, true, nil, PR.Renew, PR.Renew9, PR.Renew8, PR.Renew7, PR.Renew6, PR.Renew5, PR.Renew4, PR.Renew3, PR.Renew2, PR.Renew1)
				if Renew then 
					QueueOrder.useHoTs[Role] = self.realHP  

					if Role == "HEALER" then
						self:SetupOffsets(db.OffsetHealersHoTs, self.HP - 50)
					elseif Role == "TANK" then 
						self:SetupOffsets(db.OffsetTanksHoTs, self.HP - 50)
					else 
						self:SetupOffsets(db.OffsetDamagersHoTs, self.HP - 50)
					end 					
					return 					 
				end 							
			end 
		end

		if playerClass == "PALADIN" and A.PALADIN and LoadedLocals then 			
			-- [#1] Blessing of Protection
			-- Shields 
			if self.useShields and not QueueOrder.useShields[Role] and BlessingofProtectionUnits[5] and BlessingofProtectionUnits[4] and IsAbleBoP(unitID, true) then 
				QueueOrder.useShields[Role] = true
				
				if Role == "HEALER" then
					self:SetupOffsets(db.OffsetHealersShields, self.HP - 60)
				elseif Role == "TANK" then 
					self:SetupOffsets(db.OffsetTanksShields, self.HP - 60)
				else 
					self:SetupOffsets(db.OffsetDamagersShields, self.HP - 60)
				end 					
				return 	
			end 
				
			-- [#2] Cleanse / Purify
			-- Dispel 
			if self.useDispel and not QueueOrder.useDispel[Role] and (not A.IsInPvP or not self.isSelf) and DispelUnits[5] and DispelUnits[4] and IsAbleDispel(unitID, true) then
				QueueOrder.useDispel[Role] = true 

				if self.isSelf then 
					self:SetupOffsets(db.OffsetSelfDispel, 25)
				elseif Role == "HEALER" then
					self:SetupOffsets(db.OffsetHealersDispel, 25)
				elseif Role == "TANK" then 
					self:SetupOffsets(db.OffsetTanksDispel, 30)
				else 
					self:SetupOffsets(db.OffsetDamagersDispel, 30)
				end 					
				return 
			end 
			
			-- [#3] Blessing of Sacrifice
			-- HoTs 
			if self.useHoTs and not QueueOrder.useHoTs[Role] and BlessingofSacrificeUnits[5] and BlessingofSacrificeUnits[4] and IsAbleBoS(unitID, true) then 
				QueueOrder.useHoTs[Role] = true 

				if Role == "HEALER" then
					self:SetupOffsets(db.OffsetHealersHoTs, self.HP - 50)
				elseif Role == "TANK" then 
					self:SetupOffsets(db.OffsetTanksHoTs, self.HP - 50)
				else 
					self:SetupOffsets(db.OffsetDamagersHoTs, self.HP - 50)
				end 					
				return 
			end 	
			
			-- [#4] Blessing of Freedom
			-- Utils			
			if self.useUtils and not QueueOrder.useUtils[Role] and BlessingofFreedomUnits[5] and BlessingofFreedomUnits[4] and IsAbleBoF(unitID, true) then 
				QueueOrder.useUtils[Role] = true 
				
				if Role == "HEALER" then
					self:SetupOffsets(db.OffsetHealersUtils, self.HP - 45)
				elseif Role == "TANK" then 
					self:SetupOffsets(db.OffsetTanksUtils, self.HP - 35)
				else 
					self:SetupOffsets(db.OffsetDamagersUtils, self.HP - 35)
				end 					
				return 
			end 	

			-- [#5] Blessing Buff 
			-- Utils
			if self.useUtils and not QueueOrder.useUtils[Role] and ((A.IsInPvP and GetToggle(2, "BlessingBuffHealingEnginePvP")) or (not A.IsInPvP and GetToggle(2, "BlessingBuffHealingEnginePvE"))) and IsAbleBlessingBuff(unitID, true) then 
				QueueOrder.useUtils[Role] = true 
				
				if Role == "HEALER" then
					self:SetupOffsets(db.OffsetHealersUtils, 70)
				elseif Role == "TANK" then 
					self:SetupOffsets(db.OffsetTanksUtils, 75)
				else 
					self:SetupOffsets(db.OffsetDamagersUtils, 75)
				end 					
				return 
			end 			 
		end 						
	end 
end

-- Setup in UnitIDs table for each unitID his own methods 
do 
	local unitMethods					= { __index = {
		CanSelect						= function(self, unitID)
			-- @return boolean 
			local unitID 				= self.Unit or unitID
			local unitGUID 				= self.GUID
			
			return 
				A_Unit(unitID):InRange()
				and A_Unit(unitID):IsConnected()
				and not A_Unit(unitID):IsCharmed()			
				and not A_Unit(unitID):InLOS(unitGUID) 
				and (A.IsInPvP or not A_Unit(unitID):IsEnemy())
		end,
		CanRessurect					= function(self)
			local unitID 				= self.Unit 
			return not inCombat and not self.isSelf and self.isPlayer and db.SelectResurrects and not A_Unit(unitID):IsGhost() and not A_Unit(unitID):GetIncomingResurrection() and (not isClassic or playerClass ~= "DRUID")
		end,
		SetupOffsets 					= function(self, manualOffset, autoOffset)
			if manualOffset == 0 then 
				-- Auto 
				self.HP = math_min(autoOffset or self.HP, self.HP) -- Can not be higher than current modified HP
			else 
				-- Manual 
				if db.OffsetMode == "FIXED" then 
					self.HP = manualOffset
				else -- Mobile
					self.HP = self.HP + manualOffset
				end 
			end 			
		end,
		Setup							= function(self, unitID, unitGUID, isPlayer)
			-- @usage: :Setup(unitID, unitGUID[, isPlayer])
			-- Sets the keys in table: 			
			-- Unit 			= unitID
			-- GUID 			= unitGUID			
			-- HP 				= 0-100									-- Modified Health Percent
			-- AHP 				= 0-huge 								-- Modified Health Actual
			-- MHP				= 0-huge								-- Maximum  Health Actual
			-- Role 			= "TANK", "HEALER", "DAMAGER", "NONE" 	-- Pet has "DAMAGER" role here
			-- LUA 				= @string 
			-- Enabled  		= @boolean								-- For function SetHealingTarget
			-- useDispel		= @boolean 
			-- useShields		= @boolean 
			-- useHoTs			= @boolean 
			-- useUtils			= @boolean 								-- Offensive and supportive spells such as BoP, Freedom and etc 
			-- isPlayer 		= @boolean 
			-- isPet 			= @boolean 
			-- isSelf	 		= @boolean 
			-- isSelectAble		= @boolean 								-- If possible to target that unit 
			-- incDMG 			= 0-huge 
			-- incOffsetDMG 	= 0-huge 
			-- realHP			= 0-100
			-- realAHP			= 0-huge 			
			-- Merge all data from db (Enabled, Role, useDispel, useShields, useHoTs, useUtils, isPet, LUA)
			for k, v in pairs(dbUnitIDs[unitID]) do 
				self[k] = v 
			end 
			
			local isPlayer 				= isPlayer
			if isPlayer == nil then 
				isPlayer				= not self.isPet
			end 						
			
			self.Unit 					= unitID 
			self.GUID 					= unitGUID
			self.isPlayer 				= isPlayer	
			self.isSelf					= TeamCacheFriendlyUNITs.player == unitGUID						
			self.realAHP, self.MHP 		= A_Unit(unitID):Health(), A_Unit(unitID):HealthMax()
			if self.MHP == 0 then 
				self.realHP 			= 0 -- Fix beta / ptr "Division by zero"
			else				
				self.realHP 			= 100 * self.realAHP / self.MHP
			end 
			if self.Role == "AUTO" then 
				if not isPlayer then 
					self.Role = "DAMAGER"
				else
					self.Role = A_Unit(unitID):Role()
				end 
			end 
			
			if (not self.isPet or db.SelectPets) and (not A_Unit(unitID):IsDead() or self:CanRessurect()) and self:CanSelect() then 					
				local incomingHeals		= PredictOptions[1] and A_Unit(unitID):GetIncomingHeals() 	 or 0
				local incomingDMG		= PredictOptions[2] and A_Unit(unitID):GetRealTimeDMG() 	 or 0				
				local absorbPossitive 	= PredictOptions[5] and A_Unit(unitID):GetAbsorb()			 or 0
				local absorbNegative	= PredictOptions[6] and A_Unit(unitID):GetTotalHealAbsorbs() or 0							
				
				-- Prediction 
				self.incDMG				= incomingDMG
				if self.MHP == 0 then 
					self.HP 			= 0 -- Fix beta / ptr "Division by zero"
				else
					self.HP				= 100 * (self.realAHP + incomingHeals + absorbPossitive - absorbNegative) / self.MHP -- HoTs and Inc. Damage must be calculated by PerformByProfileHP or by callback "TMW_ACTION_HEALINGENGINE_UNIT_UPDATE"
				end 

				-- Multiplier - Incoming Damage 					
				self.incOffsetDMG		= self.MHP * db.MultiplierIncomingDamageLimit
				if incomingDMG > self.incOffsetDMG then 
					self.incOffsetDMG	= incomingDMG
				end										
				
				-- Multiplier - Threat 
				if not A.IsInPvP and A_Unit(unitID):ThreatSituation() >= 3 then 
					self.HP				= self.HP * db.MultiplierThreat
				end 
				
				-- Multiplier - Pets 
				if self.isPet then 
					if inCombat then 
						self.HP			= self.HP * db.MultiplierPetsInCombat
					else
						self.HP			= self.HP * db.MultiplierPetsOutCombat
					end 
				end 
				
				-- Offsets 
				if isPlayer then 
					if self.Enabled then 
						-- Performs GGL profiles 
						PerformByProfileHP(self)
					end 
					
					local role = self.Role
					if role == "TANK" then 
						self:SetupOffsets(db.OffsetTanks, self.HP - 2)
					elseif role == "HEALER" then
						if self.isSelf and A.IsInPvP then 
							if (not isClassic and A_Unit(player):IsFocused(nil, true)) or (isClassic and A_Unit(player):IsFocused(0)) then 
								self:SetupOffsets(db.OffsetSelfFocused, math_max(self.HP - 20, self.HP)) -- Can not be lower than current modified HP
							else 
								self:SetupOffsets(db.OffsetSelfUnfocused, self.HP - 2)
							end 
						else 
							self:SetupOffsets(db.OffsetHealers, self.HP + 2)
						end
					else
						self:SetupOffsets(db.OffsetDamagers, self.HP - 1)
					end 
				end

				self.isSelectAble		= true 
			else 				
				self.incDMG, self.incOffsetDMG 	= 0, 0
				self.HP							= self.realHP			
				self.isSelectAble				= false 
			end 											 
			
			TMW:Fire("TMW_ACTION_HEALINGENGINE_UNIT_UPDATE", self, db, QueueOrder)				
			-- Calculate Actual (back from modified HP)
			self.AHP					= self.HP * self.MHP / 100			
		end, 
		HasLua							= function(self)
			-- @return boolean 
			return self.LUA ~= ""
		end,
		RunLua 							= function(self, luaCode)
			-- Note: Shortcut to refference 'self' in LUA window is Action.HealingEngine.Data.UnitIDs[thisunit] which is through setfenv is HealingEngine.Data.UnitIDs[thisunit]
			-- Should return 'true' to make conditions viable, if LUA is OFF (i.e. LUA = "") it always returns 'true'
			-- This is the last condition which will be checked before set healing unit, if need to make something different then use callback system "TMW_ACTION_HEALINGENGINE_UNIT_UPDATE"
			return RunLua(luaCode or self.LUA, self.Unit)
		end,
	} }
	for _, unitTable in pairs(UnitIDs) do 
		setmetatable(unitTable, unitMethods)
	end 
end 

local member, memberGUID, memberData
local playerGUID, focusGUID 
local function OnUpdate()   
    -- Wipe previous 
	UnitIDs:Wipe() 
	SortedUnitIDs:Wipe()
	SortedUnitIDs_MostlyIncDMG:Wipe()
	QueueOrder:Wipe()
	playerGUID, focusGUID 				= nil, nil 
	
	-- Player (solo/party)
    if inGroup ~= "raid" then 
		member 							= player  
		memberGUID 						= TeamCacheFriendlyUNITs[member]	
		if memberGUID then 
			--playerGUID					= memberGUID -- Save for future referrence
			memberData 					= UnitIDs[member]
			memberData:Setup(member, memberGUID, true)				
			FrequencyTemp.MHP 			= (FrequencyTemp.MHP or 0) + memberData.MHP 
			FrequencyTemp.AHP 			= (FrequencyTemp.AHP or 0) + memberData.realAHP				
			if memberData.isSelectAble then 
				SortedUnitIDs[#SortedUnitIDs + 1] 							= memberData
				SortedUnitIDs_MostlyIncDMG[#SortedUnitIDs_MostlyIncDMG + 1] = memberData
			end 
		end 
    end 
	
	-- Focus 
	if not isClassic and not TeamCacheFriendlyGUIDs[focus] and not A_Unit(focus):IsEnemy() then 
		-- Replaces party/raid unit by self
		-- We have to replace member by focus only in case if focus is not member of the group
		-- This need for /focus macros otherwise toggles will not work through specific unit (e.g. raid1, party1) if its equal to focus unit like you can't /focus focus
		member 							= focus
		memberGUID						= UnitGUID(member)		
		if memberGUID and memberGUID ~= playerGUID then 
			focusGUID					= memberGUID -- Save for future referrence
			memberData 					= UnitIDs[member]
			memberData:Setup(member, memberGUID, A_Unit(member):IsPlayer() or false)	
			FrequencyTemp.MHP 			= (FrequencyTemp.MHP or 0) + memberData.MHP 
			FrequencyTemp.AHP 			= (FrequencyTemp.AHP or 0) + memberData.realAHP					
			if memberData.isSelectAble then 
				SortedUnitIDs[#SortedUnitIDs + 1] 							= memberData
				SortedUnitIDs_MostlyIncDMG[#SortedUnitIDs_MostlyIncDMG + 1] = memberData
			end 
		end 
	end
            
	-- Group 
	if inGroup then 
		for i = 1, maxGroupSize do
			-- Players 
			member 						= TeamCacheFriendlyIndexToPLAYERs[i]   
			memberGUID 					= member and TeamCacheFriendlyUNITs[member]					
			if memberGUID and memberGUID ~= focusGUID then				
				memberData 				= UnitIDs[member]
				memberData:Setup(member, memberGUID, true)					
				FrequencyTemp.MHP 		= (FrequencyTemp.MHP or 0) + memberData.MHP 
				FrequencyTemp.AHP 		= (FrequencyTemp.AHP or 0) + memberData.realAHP				
				if memberData.isSelectAble then 
					SortedUnitIDs[#SortedUnitIDs + 1] 							= memberData
					SortedUnitIDs_MostlyIncDMG[#SortedUnitIDs_MostlyIncDMG + 1] = memberData
				end 
			end 
			
			-- Pets
			member 						= TeamCacheFriendlyIndexToPETs[i]
			memberGUID 					= member and TeamCacheFriendlyUNITs[member]
			if memberGUID and memberGUID ~= focusGUID then 
				memberData 				= UnitIDs[member]
				memberData:Setup(member, memberGUID, false)					
				FrequencyTemp.MHP 		= (FrequencyTemp.MHP or 0) + memberData.MHP 
				FrequencyTemp.AHP 		= (FrequencyTemp.AHP or 0) + memberData.realAHP
				if memberData.isSelectAble then 
					SortedUnitIDs[#SortedUnitIDs + 1] 							= memberData
					SortedUnitIDs_MostlyIncDMG[#SortedUnitIDs_MostlyIncDMG + 1] = memberData
				end 					
			end 			 
		end 
	end 
    
    -- Frequency
    if inGroup then 
		if FrequencyTemp.MHP and FrequencyTemp.MHP > 0 then 
			FrequencyActual[#FrequencyActual + 1] = { 	                
				-- Max Group HP
				MHP		= FrequencyTemp.MHP, 
				-- Current Group Actual HP
				AHP 	= FrequencyTemp.AHP,
				-- Current Time on this record 
				TIME 	= TMW.time, 
			}
			
			-- Clear temp by current (old now) record
			wipe(FrequencyTemp)
			
			-- Clear actual from older records
			for i = #FrequencyActual, 1, -1 do             
				-- Remove data longer than 10 seconds 
				if TMW.time - FrequencyActual[i].TIME > 10 then 
					tremove(FrequencyActual, i)                
				end 
			end 
		end 
	else
		-- Wipe previous
		if #FrequencyActual > 0 then 
			Frequency:Wipe() 
		end 
    end 
    
	-- Sorting
    if #SortedUnitIDs > 1 then 
        -- Sort by most damage receive
        tsort(SortedUnitIDs_MostlyIncDMG, sort_incDMG)  
        
        -- Sort by Percent or Actual
		if db.SelectSortMethod == "HP" then 
			tsort(SortedUnitIDs, sort_HP)
		else 
			tsort(SortedUnitIDs, sort_AHP)
		end 
    end 
end

local function ClearHealingTarget()
	healingTarget 	  		= none
	healingTargetGUID 		= none		
	frame:SetColor(healingTarget) 
end 

local function SetHealingTarget()
	if #SortedUnitIDs > 0 then 
		for _, unitTable in ipairs(SortedUnitIDs) do 
			if unitTable.HP < 100 then 
				if unitTable.Enabled and unitTable:RunLua() then 
					healingTarget 		= unitTable.Unit
					healingTargetGUID 	= unitTable.GUID
					return 
				end 
			else 
				break 
			end 
		end 
	end 

    healingTarget 	  		= none
    healingTargetGUID 		= none
end

local function SetColorTarget()
	isFocusHealing = (BuildToC >= 20000 and not SelectStopOptions[1] and not SelectStopOptions[2] and not SelectStopOptions[3] and not SelectStopOptions[4] and not SelectStopOptions[5] and not SelectStopOptions[6])
	-- If we have no one to heal or we have already selected unit that need to heal	
	if 	healingTarget == none or healingTargetGUID == none or 
		-- /target mode
		(not isFocusHealing and healingTargetGUID == UnitGUID(target)) or 
		-- /focus mode
		(isFocusHealing and healingTargetGUID == UnitGUID(focus))
	then				
		return frame:SetColor(none)
	end	
	
	-- [1] @mouseover friendly 
	if SelectStopOptions[1] and A_IsUnitFriendly(mouseover) then
		return frame:SetColor(none)
	end
	
	-- [2] @mouseover enemy
	if SelectStopOptions[2] and A_IsUnitEnemy(mouseover) then 
		return frame:SetColor(none)
	end 
	
	-- [3] @target enemy
	if SelectStopOptions[3] and A_IsUnitEnemy(target) then 
		return frame:SetColor(none)
	end 
	
	-- [4] @target boss
	if SelectStopOptions[4] and A_Unit(target):IsBoss() then
		return frame:SetColor(none)
	end     
	
	-- [5] @player dead 
	if SelectStopOptions[5] and A_Unit(player):IsDead() then
		return frame:SetColor(none)
	end  
	
	-- [6] sync-up "Rotation doesn't work if"
	if SelectStopOptions[6] and A_PauseChecks() then 
		return frame:SetColor(none)
	end 
	
	return frame:SetColor(healingTarget)
end

local function UpdateTargetLOS()
	if A_Unit(target):IsExists() and not A_Unit(target):IsEnemy() and not A_IsUnitFriendly(mouseover) then 
		GetLOS(target)
	end 
end

local function PLAYER_TARGET_CHANGED()
	ClearHealingTarget()
	-- [3] @target enemy or [4] @target boss
	if db.AfterTargetEnemyOrBossDelay > 0 and (not SelectStopOptions[3] or not SelectStopOptions[4]) then 
		if ((not SelectStopOptions[3] and A_Unit(target):IsEnemy()) or (not SelectStopOptions[4] and A_Unit(target):IsBoss())) then 
			healingTargetDelay = TMW.time + db.AfterTargetEnemyOrBossDelay		
			healingTargetDelayByEvent = true 
		elseif healingTargetDelayByEvent then 
			healingTargetDelay = 0
			healingTargetDelayByEvent = false 
		end 
	end 
	
	-- Update Line of Sight
	UpdateTargetLOS()
end 

local function UPDATE_MOUSEOVER_UNIT()
	ClearHealingTarget()
	-- [2] @mouseover enemy 
	if db.AfterMouseoverEnemyDelay > 0 and not SelectStopOptions[2] then 
		if A_Unit(mouseover):IsEnemy() then 
			healingTargetDelay = TMW.time + db.AfterMouseoverEnemyDelay
			healingTargetDelayByEvent = true 
		elseif healingTargetDelayByEvent then 
			healingTargetDelay = 0 
			healingTargetDelayByEvent = false 
		end 
	end 
end 

local function UNIT_TARGET(holderUnitID)
	if db.ManaManagementManaBoss >= 0 and inCombat and A.IsInInstance and not A.IsInPvP and TeamCacheFriendly.MaxSize >= 5 then 
		if A_Unit(holderUnitID):IsBoss() and not A_Unit(holderUnitID):IsDead() then 
			local bossGUID = UnitGUID(holderUnitID)
			if not BossIDs[bossGUID] then 
				BossIDs[bossGUID] = {}
			end 
			BossIDs[bossGUID][holderUnitID] = true 
			BossIDs[holderUnitID] = bossGUID
		else 
			local bossGUID = BossIDs[holderUnitID]
			if bossGUID then 
				BossIDs[bossGUID][holderUnitID] = nil 
				BossIDs[holderUnitID] = nil 
			end 			
		end 
	end 
end 

local function Initialize()	
	if not isClassic and profileActionDB and profileActionDB[A.PlayerSpec] then 
		-- Note: The player may have 2 healer specs like Priest, so we have to keep correct db variable
		db 					= profileActionDB[A.PlayerSpec]
		
		PredictOptions		= db.PredictOptions
		SelectStopOptions 	= db.SelectStopOptions	
		dbUnitIDs			= db.UnitIDs				
	end 

	if A.IamHealer or (isClassic and GetToggle(1, "HE_AnyRole")) then 
		if not Data.IsRunning then 
			Listener:Add("ACTION_EVENT_HEALINGENGINE", "PLAYER_TARGET_CHANGED", 	PLAYER_TARGET_CHANGED)
			Listener:Add("ACTION_EVENT_HEALINGENGINE", "UPDATE_MOUSEOVER_UNIT", 	UPDATE_MOUSEOVER_UNIT)
			Listener:Add("ACTION_EVENT_HEALINGENGINE", "UNIT_TARGET", 				UNIT_TARGET)
			
			local UPD_INTV
			if not TMW.UPD_INTV then 
				TMW.UPD_INTV = 0.3
			end 
			
			frame.elapsed = 0
			frame:SetScript("OnUpdate", function(self, elapsed)
				UPD_INTV		= TMW.UPD_INTV				
				UPD_INTV 		= UPD_INTV > 0.3 and UPD_INTV or 0.3
				self.elapsed 	= self.elapsed + elapsed  
				
				if self.elapsed > UPD_INTV then 
					OnUpdate() 
					
					if TMW.time > healingTargetDelay then 
						SetHealingTarget() 
						SetColorTarget()   
					end 
					
					-- Update Line of Sight
					if self.unit == none then 
						UpdateTargetLOS()
					end 
					
					self.elapsed = 0
				end			
			end)
			
			Data.IsRunning = true 
		end 
	else
		if Data.IsRunning then
			Listener:Remove("ACTION_EVENT_HEALINGENGINE", "PLAYER_TARGET_CHANGED")
			Listener:Remove("ACTION_EVENT_HEALINGENGINE", "UPDATE_MOUSEOVER_UNIT")
			Listener:Remove("ACTION_EVENT_HEALINGENGINE", "UNIT_TARGET")
			
			frame:SetScript("OnUpdate", nil)
			ClearHealingTarget()
			
			UnitIDs:Wipe() 
			SortedUnitIDs:Wipe()
			SortedUnitIDs_MostlyIncDMG:Wipe()
			Frequency:Wipe()
			QueueOrder:Wipe()
			BossIDs:Wipe()
			
			Data.IsRunning = false 
		end
	end 
end 

if isClassic then 
	TMW:RegisterCallback("TMW_ACTION_HEALINGENGINE_ANY_ROLE", 					Initialize)
end 
TMW:RegisterCallback("TMW_ACTION_PLAYER_SPECIALIZATION_CHANGED", 				Initialize) 
TMW:RegisterCallback("TMW_ACTION_IS_INITIALIZED", 								Initialize) 
TMW:RegisterCallback("TMW_ACTION_DB_UPDATED",									function(callbackEvent, pActionDB)
	if pActionDB and pActionDB[8] then 
		if not isClassic then 
			db = pActionDB[8][A.PlayerSpec]
			profileActionDB = pActionDB[8] -- need for update specialization table when its change by "TMW_ACTION_PLAYER_SPECIALIZATION_CHANGED"
			
			if not db then 
				db = StdUi.Factory[8].PLAYERSPEC
				profileActionDB = nil 
			else 
				TMW:Fire("TMW_ACTION_PROFILE_DB_UPDATED")	
			end 
		else 
			db = pActionDB[8]
			if not db then 
				db = StdUi.Factory[8]
			else 
				TMW:Fire("TMW_ACTION_PROFILE_DB_UPDATED")
			end 
		end 
	else 
		if not isClassic then 
			db = StdUi.Factory[8].PLAYERSPEC
			profileActionDB = nil 
		else 
			db = StdUi.Factory[8]
		end 
	end 
	
	PredictOptions		= db.PredictOptions
	SelectStopOptions 	= db.SelectStopOptions	
	dbUnitIDs			= db.UnitIDs		
	
	if db.ManaManagementManaBoss < 0 then 
		BossIDs:Wipe()
	end 
end)
TMW:RegisterCallback("TMW_ACTION_GROUP_UPDATE",									function()
	inGroup 	 = TeamCacheFriendly.Type
	maxGroupSize = TeamCacheFriendly.MaxSize
	if Data.IsRunning then 
		BossIDs:Wipe()
	end 
end)
TMW:RegisterCallback("TMW_ACTION_METAENGINE_AUTH",								function()
	-- This callback resets frame allowing initial unit to be set correctly
	frame.unit, frame.mode = nil, nil
end)
Listener:Add("ACTION_EVENT_HEALINGENGINE", "PLAYER_REGEN_ENABLED", 				function()
	inCombat = false 
	if Data.IsRunning then 
		wipe(Frequency.Actual)
		BossIDs:Wipe()
	end 
end)
Listener:Add("ACTION_EVENT_HEALINGENGINE", "PLAYER_REGEN_DISABLED", 			function()
	inCombat = true 
	if Data.IsRunning then 
		wipe(Frequency.Actual)
		BossIDs:Wipe()
	end 
end)

-- ============================= API ==============================
-- API valid only for healer specializations  

-- Globals
A.HealingEngine = { Data = Data }

-- Locals
local HealingEngine = A.HealingEngine

-- Data Controller 
function HealingEngine.SortMembers()
	-- Manual re-sort table 
	if #SortedUnitIDs > 1 then
		-- Sort by most damage receive
        tsort(SortedUnitIDs_MostlyIncDMG, sort_incDMG)  
		
		-- Sort by Percent or Actual
		if db.SelectSortMethod == "HP" then 
			tsort(SortedUnitIDs, sort_HP)
		else 
			tsort(SortedUnitIDs, sort_AHP)
		end 
	end 
end 

-- SetTarget Controller 
function HealingEngine.SetTargetMostlyIncDMG(delay)
	-- Sets in HealingEngine specified unitID with delay which will prevent reset target during next few seconds 	
	if #SortedUnitIDs_MostlyIncDMG > 0 then 
		healingTargetDelay 	= TMW.time + (delay or 2)
		healingTargetGUID 	= SortedUnitIDs_MostlyIncDMG[1].GUID
		healingTarget		= SortedUnitIDs_MostlyIncDMG[1].Unit
		frame:SetColor(healingTarget) 
	end 
end 

function HealingEngine.SetTarget(unitID, delay)
	-- Sets in HealingEngine specified unitID with delay which will prevent reset target during next few seconds 	
	healingTargetGUID 		= TeamCacheFriendlyUNITs[unitID] or UnitGUID(unitID)
	healingTarget			= TeamCacheFriendlyGUIDs[healingTargetGUID]
	if healingTarget then 
		healingTargetDelay 	= TMW.time + (delay or 2)
		frame:SetColor(healingTarget)		 
	end 
end

-- Group Controller 
function HealingEngine.GetMembersAll()
	-- @return array table of all select able units 
	return SortedUnitIDs 
end 

function HealingEngine.GetBuffsCount(ID, duration, source, byID)
	-- @usage HealingEngine.GetBuffsCount(ID[, duration, source, byID])
	-- @return number 	
	-- Note: Only players 
    local total = 0
	for _, thisUnit in ipairs(SortedUnitIDs) do
		if thisUnit.isPlayer and A_Unit(thisUnit.Unit):HasBuffs(ID, source, byID) > (duration or 0) then
			total = total + 1
		end
	end
	
    return total 
end 

function HealingEngine.GetDeBuffsCount(ID, duration, source, byID)
	-- @usage HealingEngine.GetDeBuffsCount(ID[, duration, source, byID])
	-- @return number 	
	-- Note: Only players 
    local total = 0
	for _, thisUnit in ipairs(SortedUnitIDs) do
		if thisUnit.isPlayer and A_Unit(thisUnit.Unit):HasDeBuffs(ID, source, byID) > (duration or 0) then
			total = total + 1
		end
	end

    return total 
end 

function HealingEngine.GetHealth()
	-- @return number, number 
	-- Returns:
	-- [1] current (per group) health 
	-- [2] maximum (per group) health
	local m = #FrequencyActual
	if m > 0 then 
		return FrequencyActual[m].AHP, FrequencyActual[m].MHP
	end 
	return huge, huge
end 

function HealingEngine.GetHealthAVG() 
	-- @return number 
	-- Returns:
	-- [1] current (per group) health percent (%)
	local m = #FrequencyActual
	if m > 0 then 
		return FrequencyActual[m].AHP * 100 / FrequencyActual[m].MHP
	end 
	return 100  
end 

function HealingEngine.GetHealthFrequency(timer)
	-- @return number 
	-- Returns:
	-- [1] current (per group) health percent (%) changed during lasts 'timer'
	-- Note: Positive (+) is HP gain. Negative (-) is HP lose. Zero (0) is not changed
    local total, counter = 0, 0
	
	if timer > 10 then 
		error("HealingEngine.GetHealthFrequency function accepts maximum 10 as 'timer' argument")
	end 
	
	local m = #FrequencyActual
	if m > 1 and TMW.time - FrequencyActual[1].TIME >= timer then 
		for i = m - 1, 1, -1 do 
			-- Getting history during that time rate
			if TMW.time - FrequencyActual[i].TIME <= timer then 
				counter = counter + 1
				total 	= total + FrequencyActual[i].AHP
			else 
				break 
			end 
		end        
	end 
	
	if total > 0 then   
		total = (FrequencyActual[m].AHP * 100 / FrequencyActual[m].MHP) - (total / counter * 100 / FrequencyActual[m].MHP)
	end  	
	
    return total 
end 
HealingEngine.GetHealthFrequency = MakeFunctionCachedDynamic(HealingEngine.GetHealthFrequency)

function HealingEngine.GetIncomingDMG()
	-- @return number, number 
	-- Returns:
	-- [1] current (per group) health lose per second
	-- [2] average (per unit)  health lose per second 
	local total, avg = 0, 0
 
	for _, thisUnit in ipairs(SortedUnitIDs) do
		total = total + thisUnit.incDMG
	end
	
	if total > 0 then 
		avg = total / #SortedUnitIDs
    end 
	
    return total, avg 
end 
HealingEngine.GetIncomingDMG = MakeFunctionCachedStatic(HealingEngine.GetIncomingDMG)

function HealingEngine.GetIncomingHPS()
	-- @return number, number
	-- Returns: 
	-- [1] current (per group) health gain per second
	-- [2] average (per unit)  health gain per second 
	local total, avg = 0, 0

    for _, thisUnit in ipairs(SortedUnitIDs) do
		total = total + A_Unit(thisUnit.Unit):GetHEAL()
	end
		
	if total > 0 then 
		avg = total / #SortedUnitIDs
    end 
	
    return total, avg 
end 
HealingEngine.GetIncomingHPS = MakeFunctionCachedStatic(HealingEngine.GetIncomingHPS)

function HealingEngine.GetIncomingDMGAVG()
	-- @return number  
	-- Returns:	
	-- [1] current (per group) health percent (%) lose per second	
	local m = #FrequencyActual
    if m > 0 then 
		return HealingEngine.GetIncomingDMG() * 100 / FrequencyActual[m].MHP
    end 
    return 0 
end

function HealingEngine.GetIncomingHPSAVG()
	-- @return number  
	-- Returns:	
	-- [1] current (per group) health percent (%) gain per second	
	local m = #FrequencyActual
    if m > 0 then 
		return HealingEngine.GetIncomingHPS() * 100 / FrequencyActual[m].MHP
    end 
    return 0 
end 

function HealingEngine.GetTimeToFullDie()
	-- @return number 
	-- Returns:	
	-- [1] current time to die for all group members 
	local total = 0
	
	for _, thisUnit in ipairs(SortedUnitIDs) do
		total = total + A_Unit(thisUnit.Unit):TimeToDie()
	end
	
	if total > 0 then 
		return total / #SortedUnitIDs
	end 

	return huge  
end 

function HealingEngine.GetTimeToDieUnits(timer)
	-- @return number 
	-- Returns:	
	-- [1] count of units which are below or equal by TimeToDie to 'timer'
	local total = 0
	
	for _, thisUnit in ipairs(SortedUnitIDs) do
		if A_Unit(thisUnit.Unit):TimeToDie() <= timer then
			total = total + 1
		end
	end 
	
    return total 
end 

function HealingEngine.GetTimeToDieMagicUnits(timer)
	-- @return number 
	-- Returns:	
	-- [1] count of units which are below or equal by TimeToDieMagic to 'timer'	
	local total = 0

	for _, thisUnit in ipairs(SortedUnitIDs) do
		if A_Unit(thisUnit.Unit):TimeToDieMagic() <= timer then
			total = total + 1
		end
	end 
	
    return total 
end 

function HealingEngine.GetTimeToFullHealth()
	-- @return number
	-- Returns:	
	-- [1] current (per group) time to have maximum health 
	local m = #FrequencyActual
	if m > 0 then 
		local HPS = HealingEngine.GetIncomingHPS()
		if HPS > 0 then
			return (FrequencyActual[m].MHP - FrequencyActual[m].AHP) / HPS
		end 
	end 

	return 0 
end 

function HealingEngine.GetMinimumUnits(fullPartyMinus, raidLimit)
	-- @usage HealingEngine.GetMinimumUnits([, fullPartyMinus, raidLimit])
	-- @return number 
	-- This is easy template to known how many people minimum required to be healed by AoE with different group size or if some units out of range or in cyclone and etc..
	-- More easy to figure - which minimum units require if available group members <= 1 / <= 3 / <= 5 or > 5
	local members = #SortedUnitIDs
	return 	( members <= 1 and 1 ) or 
			( members <= 3 and members - math_min(fullPartyMinus or 0, 1)) or 
			( members <= 5 and members - (fullPartyMinus or 0) ) or 
			(
				members > 5 and 
				(
					(
						raidLimit ~= nil and
						(
							(
								members >= raidLimit and 
								raidLimit
							) or 
							(
								members < raidLimit and 
								members
							)
						)
					) or 
					(
						raidLimit == nil and 
						members
					)
				)
			)
end 

function HealingEngine.GetBelowHealthPercentUnits(hp, range)
	-- @usage HealingEngine.GetBelowHealthPercentUnits(hp[, range])
	-- @return number 
	-- Returns:	
	-- [1] count of units which are below or equal to health percent by 'hp' 
	local total = 0 

	for _, thisUnit in ipairs(SortedUnitIDs) do
		if (not range or A_Unit(thisUnit.Unit):CanInterract(range)) and thisUnit.realHP <= hp then
			total = total + 1
		end
	end 
	
	return total 
end; HealingEngine.GetBelowHealthPercentercentUnits = HealingEngine.GetBelowHealthPercentUnits -- Just for refference if old codes still uses it somewhere

function HealingEngine.HealingByRange(range, object, inParty, isMelee)
	-- @usage HealingEngine.HealingByRange(range, predictName, spell[, isMelee])
	-- @return number 
	-- Returns:	
	-- [1] count of units which can be healed by 'range'
	local total = 0

	for _, thisUnit in ipairs(SortedUnitIDs) do 
		if 	(not isMelee or A_Unit(thisUnit.Unit):IsMelee()) and 
			(not inParty or A_Unit(thisUnit.Unit):InParty()) and 
			A_Unit(thisUnit.Unit):CanInterract(range) and
			object:PredictHeal(thisUnit.Unit, nil, thisUnit.GUID)
		then
			total = total + 1
		end
	end 		

	return total 
end 

function HealingEngine.HealingBySpell(object, inParty, isMelee)
	-- @usage HealingEngine.HealingByRange(predictName, spell[, isMelee])
	-- @return number 
	-- Returns:	
	-- [1] count of units which can be healed by 'spell'
	-- Returns how much members can be healed by specified spell 
	local total = 0
	
	for _, thisUnit in ipairs(SortedUnitIDs) do 
		if 	(not isMelee or A_Unit(thisUnit.Unit):IsMelee()) and 
			(not inParty or A_Unit(thisUnit.Unit):InParty()) and 
			object:IsInRange(thisUnit.Unit) and 
			object:PredictHeal(thisUnit.Unit, nil, thisUnit.GUID)
		then
			total = total + 1
		end
	end 		

	return total 
end 

-- Unit Controller 
local emptyTable = {}
function HealingEngine.GetOptionsByUnitID(unitID, unitGUID)
	-- @usage local useDispel, useShields, useHoTs, useUtils, dbUnit = HealingEngine.GetOptionsByUnitID(unitID[, unitGUID])
	-- @return boolean, boolean, boolean, boolean, table
	-- Returns data from DB (not modified data by Healing Engine!):
	-- [1] useDispel
	-- [2] useShields
	-- [3] useHoTs
	-- [4] useUtils
	-- [5] @table itself table with keys: table.Enabled, table.Role, table.useDispel, table.useShields, table.useHoTs, table.useUtils, table.LUA
	-- Note: Don't change key-values in returned [5] table, only for referrence usage!
	local GUID = unitGUID or UnitGUID(unitID)
	if GUID then 
		if GUID == focusGUID then 
			local dbUnit = dbUnitIDs.focus
			if dbUnit then 
				return dbUnit.useDispel, dbUnit.useShields, dbUnit.useHoTs, dbUnit.useUtils, dbUnit
			end 
		else 
			local unit = TeamCacheFriendlyGUIDs[GUID]
			local dbUnit = unit and dbUnitIDs[unit]
			if dbUnit then 
				return dbUnit.useDispel, dbUnit.useShields, dbUnit.useHoTs, dbUnit.useUtils, dbUnit
			end 
		end 
	end 
	
	-- Default return for non in group units 
	local isPlayer = A_Unit(unitID):IsPlayer()
	return isPlayer, true, true, isPlayer, emptyTable, emptyTable
end 

function HealingEngine.IsMostlyIncDMG(unitID)
	-- @return boolean, number 
	-- Returns:
	-- [1] true, if unitID is the same unit which is most injured 
	-- [2] current incoming damage per second 
	if SortedUnitIDs_MostlyIncDMG[1] and UnitIsUnit(unitID, SortedUnitIDs_MostlyIncDMG[1].Unit) then 
		return true, SortedUnitIDs_MostlyIncDMG[1].incDMG
	end 
	return false, 0
end 

function HealingEngine.GetTarget()
	return healingTarget, healingTargetGUID
end 

-- Boss Controller 
function HealingEngine.GetBossHealth()
	-- @return number, number, number, number, number 
	-- Returns:
	-- [1] Average health current 
	-- [2] Average health maximum
	-- [3] Total health current
	-- [4] Total health maximum
	-- [5] Count of bosses 
	local healthCurrent, healthMax, c = 0, 0, 0
	local bossHealth = 0
	for bossGUID, bossHolders in pairs(BossIDs) do 
		if type(bossHolders) == "table" then 
			for bossUnitID in pairs(bossHolders) do 
				bossHealth = A_Unit(bossUnitID):Health()
				if bossHealth > 0 then 
					healthCurrent = healthCurrent + bossHealth
					healthMax = healthMax + A_Unit(bossUnitID):HealthMax()
					c = c + 1
					break 
				end 
			end 
		end 
	end 
	
	if c <= 0 then 
		return 0, 0, 0, 0, 0
	end 
	
	return healthCurrent / c, healthMax / c, healthCurrent, healthMax, c
end 

function HealingEngine.GetBossHealthPercent()
	-- @return number 
	-- Returns current average health percent (of all bosses)
	local curHealth, maxHealth = HealingEngine.GetBossHealth()
	if curHealth <= 0 then 
		return 0
	end 
	
	return curHealth * 100 / maxHealth
end 

function HealingEngine.GetBossTimeToDie()
	-- @return number, number, number, number, number 
	-- Returns:
	-- [1] Average ttd current 
	-- [2] Total ttd current
	-- [3] Count of bosses 
	local curTTD, c = 0, 0
	local ttd = 0
	for bossGUID, bossHolders in pairs(BossIDs) do 
		if type(bossHolders) == "table" then 
			for bossUnitID in pairs(bossHolders) do 
				ttd = A_Unit(bossUnitID):TimeToDie()
				if ttd > 0 then 
					curTTD = curTTD + ttd
					c = c + 1
					break 
				end 
			end 
		end 
	end 
	
	if c <= 0 then 
		return 0, 0, 0
	end 
	
	return curTTD / c, curTTD, c
end 

function HealingEngine.GetBossMain()
	-- @return unitID, unitGUID, unitFocused or nil 
	-- Returns:
	-- [1] unitID
	-- [2] unitGUID
	-- [3] unitFocused how much members focusing that boss 
	local unitID, unitGUID, unitFocused
	local lastUnit 
	local c = 0
	for bossGUID, bossHolders in pairs(BossIDs) do 
		if type(bossHolders) == "table" then 
			c = 0			
			for bossUnitID in pairs(bossHolders) do 
				c = c + 1
				lastUnit = bossUnitID
			end 
			
			if c > (unitFocused or 0) then 
				unitID = lastUnit
				unitGUID = bossGUID
				unitFocused = c 
			end 
		end 
	end 
	
	return unitID, unitGUID, unitFocused
end 

-- Mana Controller 
function HealingEngine.IsManaSave(unitID)
	-- @return boolean 
	-- Returns true if conditions are successful for mana save  
	if db.ManaManagementManaBoss >= 0 then 
		local bossHP = HealingEngine.GetBossHealthPercent() 
		local manaP  = A_Unit(player):PowerPercent()
		if bossHP > 0 and manaP <= bossHP and manaP <= db.ManaManagementManaBoss and A_Unit(player):HasBuffs(Aura.Innervate) == 0 then 
			-- Check stop conditions 
			return not unitID or (A_Unit(unitID):HealthPercent() >= db.ManaManagementStopAtHP and A_Unit(unitID):TimeToDie() >= db.ManaManagementStopAtTTD)
		end 
	end 
end 
HealingEngine.IsManaSave = MakeFunctionCachedDynamic(HealingEngine.IsManaSave)