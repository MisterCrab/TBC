-------------------------------------------------------------------------------
-- TellMeWhen Utils
-------------------------------------------------------------------------------
local _G, assert, error, tostring, select, type, next, math =
	  _G, assert, error, tostring, select, type, next, math
	  
local TMW 					= _G.TMW
local CNDT 					= TMW.CNDT
local Env 					= CNDT.Env
local strlowerCache  		= TMW.strlowerCache

local A   					= _G.Action
local CONST 				= A.Const
local Listener				= A.Listener
local GetToggle				= A.GetToggle
local toStr 				= A.toStr
local toNum 				= A.toNum
local Print 				= A.Print
local ActionDataColor		= A.Data.C

-------------------------------------------------------------------------------
-- Remap
-------------------------------------------------------------------------------
local A_LossOfControl, A_GetSpellInfo

Listener:Add("ACTION_EVENT_UTILS", "ADDON_LOADED", function(addonName) 
	if addonName == CONST.ADDON_NAME then 
		A_LossOfControl		= A.LossOfControl
		A_GetSpellInfo		= A.GetSpellInfo
		Listener:Remove("ACTION_EVENT_UTILS", "ADDON_LOADED")	
	end 	
end)
-------------------------------------------------------------------------------  
	  
local huge 					= math.huge	 
local wipe					= _G.wipe
local message				= _G.message
local hooksecurefunc		= _G.hooksecurefunc
local strfind				= _G.strfind	  
local strmatch				= _G.strmatch	
local UIParent				= _G.UIParent	
local C_CVar				= _G.C_CVar
	  
local 	 CreateFrame, 	 GetCVar, 	 				   SetCVar =
	  _G.CreateFrame, _G.GetCVar or C_CVar.GetCVar, _G.SetCVar or C_CVar.SetCVar	  

local GetPhysicalScreenSize = _G.GetPhysicalScreenSize
	  
local GetSpellTexture, 	  GetSpellInfo,    CombatLogGetCurrentEventInfo =	
  TMW.GetSpellTexture, _G.GetSpellInfo, _G.CombatLogGetCurrentEventInfo	  

local 	 UnitGUID, 	  UnitIsUnit =
	  _G.UnitGUID, _G.UnitIsUnit
	  
local RANKCOLOR 			= A.Data.RANKCOLOR	

-------------------------------------------------------------------------------
-- Env.LastPlayerCast
-------------------------------------------------------------------------------
-- Note: This code is modified for Action Core 
do
    local module = CNDT:GetModule("LASTCAST", true)
    if not module then
        module = CNDT:NewModule("LASTCAST", "AceEvent-3.0")
        
        local pGUID = UnitGUID("player")
        assert(pGUID, "pGUID was null when func string was generated!")
		
		local blacklist = {
			[75] = true, 					-- Hunter's Auto Shot
        }
        
        module:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED",
            function()
                local _, e, _, sourceGuid, _, _, _, _, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
                if (e == "SPELL_CAST_SUCCESS" or e == "SPELL_MISS") and sourceGuid == pGUID and not blacklist[spellID] then
                    Env.LastPlayerCastName 	= strlowerCache[spellName]
                    --Env.LastPlayerCastID 	= spellID
					A.LastPlayerCastName	= spellName
					--A.LastPlayerCastID	= spellID
                    TMW:Fire("TMW_CNDT_LASTCAST_UPDATED")
                end
        end)    
        
        module:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED",
            function(_, unit, _, spellID)
                if unit == "player" and not blacklist[spellID] then
					local spellName			= A_GetSpellInfo(spellID)
                    Env.LastPlayerCastName 	= strlowerCache[spellName]
                    Env.LastPlayerCastID 	= spellID
					A.LastPlayerCastName	= spellName
					A.LastPlayerCastID		= spellID
                    TMW:Fire("TMW_CNDT_LASTCAST_UPDATED")
                end
        end)  
    end
end

-------------------------------------------------------------------------------
-- DogTags
-------------------------------------------------------------------------------
local DogTag = LibStub("LibDogTag-3.0", true)
TMW:RegisterCallback("TMW_ACTION_MODE_CHANGED", 		DogTag.FireEvent, DogTag)
TMW:RegisterCallback("TMW_ACTION_BURST_CHANGED",		DogTag.FireEvent, DogTag)
TMW:RegisterCallback("TMW_ACTION_AOE_CHANGED", 			DogTag.FireEvent, DogTag)
TMW:RegisterCallback("TMW_ACTION_RANK_DISPLAY_CHANGED", DogTag.FireEvent, DogTag)
-- Taste's 
--TMW:RegisterCallback("TMW_ACTION_CD_MODE_CHANGED", 	DogTag.FireEvent, DogTag)
--TMW:RegisterCallback("TMW_ACTION_AOE_MODE_CHANGED", 	DogTag.FireEvent, DogTag)

local function removeLastChar(text)
	return text:sub(1, -2)
end

if DogTag then
	-- Changes displayed mode on rotation frame
    DogTag:AddTag("TMW", "ActionMode", {
        code = function()
            return A.IsInPvP and "PvP" or "PvE"
        end,
        ret = "string",
        doc = "Displays Rotation Mode",
		example = '[ActionMode] => "PvE"',
        events = "TMW_ACTION_MODE_CHANGED",
        category = "Action",
    })
	-- Changes displayed burst on rotation frame 
	DogTag:AddTag("TMW", "ActionBurst", {
        code = function()
			if A.IsInitialized then 
				local Toggle = GetToggle(1, "Burst") or ""
				Toggle = Toggle and Toggle:upper()
				return Toggle == "EVERYTHING" and ("|c" .. ActionDataColor["GREEN"] .. "EVERY|r") or Toggle == "OFF" and ("|c" .. removeLastChar(ActionDataColor["RED"]) .. Toggle .. "|r") or ("|c" .. ActionDataColor["GREEN"] .. Toggle .. "|r")
			else 
				return ""
			end 
        end,
        ret = "string",
        doc = "Displays Rotation Burst",
		example = '[ActionBurst] => "Auto, Off, Everything"',
        events = "TMW_ACTION_BURST_CHANGED",
        category = "Action",
    })
	-- Changes displayed aoe on rotation frame 
	DogTag:AddTag("TMW", "ActionAoE", {
        code = function()
			if A.IsInitialized then 
				return GetToggle(2, "AoE") and ("|c" .. ActionDataColor["GREEN"] .. "AoE|r") or "|c" .. removeLastChar(ActionDataColor["RED"]) .. "AoE|r"
			else 
				return ""
			end 
        end,
        ret = "string",
        doc = "Displays Rotation AoE",
		example = '[ActionAoE] => "AoE (green or red)"',
        events = "TMW_ACTION_AOE_CHANGED",
        category = "Action",
    })
	-- Changes displayed rank of spell on rotation frame 
	DogTag:AddTag("TMW", "ActionRank", {
        code = function()
			return A.IsInitialized and RankSingle.isColored or "" 
        end,
        ret = "string",
        doc = "Displays Rotation SpellRank in use on the frame",
		example = '[ActionRank] => "1"',
        events = "TMW_ACTION_RANK_DISPLAY_CHANGED",
        category = "Action",
    })
	
	-- Taste's 
	--[[
    DogTag:AddTag("TMW", "ActionModeCD", {
        code = function()            
			if A.IsInitialized and GetToggle(1, "Burst") ~= "Off" then
			    return "|cff00ff00CD|r"
			else 
				return "|cFFFF0000CD|r"
			end
        end,
        ret = "string",
        doc = "Displays CDs Mode",
		example = '[ActionModeCD] => "CDs ON"',
        events = "TMW_ACTION_CD_MODE_CHANGED",
        category = "ActionCDs",
    })
	DogTag:AddTag("TMW", "ActionModeAoE", {
        code = function()            
			if A.IsInitialized and GetToggle(1, "AoE") then
			    return "|cff00ff00AoE|r"
			else 
				return "|cFFFF0000AoE|r"
			end
        end,
        ret = "string",
        doc = "Displays AoE Mode",
		example = '[ActionModeAoE] => "AoE ON"',
        events = "TMW_ACTION_AOE_MODE_CHANGED",
        category = "ActionAoE",
    })	
	]]
	-- The biggest problem of TellMeWhen what he using :setup on frames which use DogTag and it's bring an error
	TMW:RegisterCallback("TMW_ACTION_IS_INITIALIZED", function()
		TMW:Fire("TMW_ACTION_MODE_CHANGED")
		TMW:Fire("TMW_ACTION_BURST_CHANGED")
		TMW:Fire("TMW_ACTION_AOE_CHANGED")
		TMW:Fire("TMW_ACTION_RANK_DISPLAY_CHANGED")
		-- Taste's 
		--TMW:Fire("TMW_ACTION_CD_MODE_CHANGED")		
		--TMW:Fire("TMW_ACTION_AOE_MODE_CHANGED")
	end)
end

-------------------------------------------------------------------------------
-- Icons
-------------------------------------------------------------------------------
-- Note: icon can be "TMW:icon:1S2PCb9iygE4" (as GUID) or "TellMeWhen_Group1_Icon1" (as ID)
function Env.IsIconShown(icon)
	-- @return boolean, if icon physically shown	
    local FRAME = TMW:GetDataOwner(icon)
    return (FRAME and FRAME.attributes.realAlpha == 1) or false
end 

function Env.IsIconDisplay(icon)
	-- @return textureID or 0 
    local FRAME = TMW:GetDataOwner(icon)
    return (FRAME and FRAME.Enabled and FRAME:IsVisible() and FRAME.attributes.texture) or 0    
end

function Env.IsIconEnabled(icon)
	-- @return boolean
    local FRAME = TMW:GetDataOwner(icon)
    return (FRAME and FRAME.Enabled) or false
end

-------------------------------------------------------------------------------
-- IconType: TheAction - LossOfControl
-------------------------------------------------------------------------------
local L = TMW.L
local INCONTROL 	= 1 -- Inside control 
local CONTROLLOST 	= 2 -- Out of control  

local TypeLOC = TMW.Classes.IconType:New("TheAction - LossOfControl")
TypeLOC.name = "[The Action] " .. L["LOSECONTROL_ICONTYPE"]	
TypeLOC.desc = L["LOSECONTROL_ICONTYPE_DESC"]
TypeLOC.menuIcon = "Interface\\Icons\\Spell_Shadow_Possession"
TypeLOC.AllowNoName = true
TypeLOC.usePocketWatch = 1
TypeLOC.hasNoGCD = true
TypeLOC.canControlGroup = true

TypeLOC:UsesAttributes("state")
TypeLOC:UsesAttributes("start, duration")
TypeLOC:UsesAttributes("texture")

TypeLOC:RegisterConfigPanel_XMLTemplate(165, "TellMeWhen_IconStates", {
	[INCONTROL] 	= { text = "|cFF00FF00" .. L["LOSECONTROL_INCONTROL"],   },
	[CONTROLLOST] 	= { text = "|cFFFF0000" .. L["LOSECONTROL_CONTROLLOST"], },
})

local function LossOfControlOnUpdate(icon, time)
	local attributes = icon.attributes
	local start = attributes.start or 0
	local duration = attributes.duration or 0
	
	if duration == huge then 
		duration = select(2, A_LossOfControl:GetFrameData())
	end 

	if duration ~= 0 and time - start < duration then 
		icon:SetInfo(
			"state; start, duration",
			CONTROLLOST,
			start, duration
		)
	else 
		icon:SetInfo(
			"texture; state; start, duration",
			icon.FirstTexture,
			INCONTROL,
			0, 0
		)
	end 
	--[[
	if TMW.time - start > duration then	
		icon:SetInfo(
			"texture; state; start, duration",
			icon.FirstTexture,
			INCONTROL,
			0, 0
		)	
		--icon.NextUpdateTime = 0 -- FIX ME: Is it necessary to prevent persistent auras??
	else
		icon:SetInfo(
			"state; start, duration",
			CONTROLLOST,
			start, duration
		)			
	end]]
end

local function LossOfControlOnEvent(icon)	
	local textureID, duration = A_LossOfControl:GetFrameData()		
	if duration ~= 0 and textureID ~= 0 then 
		icon:SetInfo(
			"texture; state; start, duration",
			textureID,
			CONTROLLOST,
			TMW.time, duration
		)
	else 
		icon:SetInfo(
			"texture; state; start, duration",
			icon.FirstTexture,
			INCONTROL,
			0, 0
		)
	end 
	--icon.NextUpdateTime = 0
end 

function TypeLOC:Setup(icon)	
	icon.FirstTexture = GetSpellTexture(CONST.PICKPOCKET)
	icon:SetInfo("texture", icon.FirstTexture)
	
	TMW:RegisterCallback("TMW_ACTION_LOSS_OF_CONTROL_UPDATE", LossOfControlOnEvent, icon)
	
	icon:SetUpdateMethod("manual")	
	icon:SetUpdateFunction(LossOfControlOnUpdate)
	icon:Update()
end

TypeLOC:Register(103)

-------------------------------------------------------------------------------
-- Scales
-------------------------------------------------------------------------------
local BlackBackground 	= CreateFrame("Frame", nil, UIParent)
if _G.BackdropTemplateMixin == nil and BlackBackground.SetBackdrop then -- Only expac less than Shadowlands
	BlackBackground:SetBackdrop(nil)
end 
BlackBackground:SetFrameStrata("HIGH")
BlackBackground:SetSize(273, 30)
BlackBackground:SetPoint("TOPLEFT", 0, 12) 
BlackBackground:SetShown(false)
BlackBackground.IsEnable = true
BlackBackground.texture = BlackBackground:CreateTexture(nil, "TOOLTIP")
BlackBackground.texture:SetAllPoints(true)
BlackBackground.texture:SetColorTexture(0, 0, 0, 1)

local function CreateRankFrame(name, anchor, x, y)
	local frame 		= CreateFrame("Frame", name, UIParent)
	if frame.SetBackdrop then 
		frame:SetBackdrop(nil)
	end 
	frame:SetFrameStrata("TOOLTIP")
	frame:SetToplevel(true)
	frame:SetSize(1, 1)
	frame:SetScale(1)
	frame:SetPoint(anchor, x, y)
	frame.texture = frame:CreateTexture(nil, "TOOLTIP")
	frame.texture:SetAllPoints(true)
	frame.texture:SetColorTexture(0, 0, 0, 1.0)
	return frame
end 

local RankSingle 		 = CreateRankFrame("RankSingle", "TOPLEFT", 163, -1)
local RankAoE	 		 = CreateRankFrame("RankAoE", "TOPLEFT", 163, -2)

local function UpdateFrames()
    if not TellMeWhen_Group1 or not strfind(strlowerCache(TellMeWhen_Group1.Name), "shown main") then 
        if BlackBackground:IsShown() then
            BlackBackground:Hide()
        end     
		
        if TargetColor and TargetColor:IsShown() then
            TargetColor:Hide()
        end  
		
		if RankSingle:IsShown() then
            RankSingle:Hide()
        end				
		
		if RankAoE:IsShown() then
            RankAoE:Hide()
        end		
		
        return 
    end
	
	local myheight = select(2, GetPhysicalScreenSize())
    local myscale1 = 0.42666670680046 * (1080 / myheight)  
    local group1 = TellMeWhen_Group1:GetEffectiveScale()  
	
	-- "Shown Main"
    if group1 ~= nil and group1 ~= myscale1 then
        TellMeWhen_Group1:SetParent(nil)
        TellMeWhen_Group1:SetScale(myscale1) 
        TellMeWhen_Group1:SetFrameStrata("TOOLTIP")
        TellMeWhen_Group1:SetToplevel(true) 
        if BlackBackground.IsEnable then 
            if not BlackBackground:IsShown() then
                BlackBackground:Show()
            end
            BlackBackground:SetScale(myscale1 / (BlackBackground:GetParent() and BlackBackground:GetParent():GetEffectiveScale() or 1))      
        end 
    end
	
	-- HealingEngine
    if TargetColor then
        if not TargetColor:IsShown() then
            TargetColor:Show()
        end
        TargetColor:SetScale((0.71111112833023 * (1080 / myheight)) / (TargetColor:GetParent() and TargetColor:GetParent():GetEffectiveScale() or 1))
    end           

	-- Rank Spells 
	if RankSingle then 
		if not RankSingle:IsShown() then
            RankSingle:Show()
        end
        RankSingle:SetScale((0.71111112833023 * (1080 / myheight)) / (RankSingle:GetParent() and RankSingle:GetParent():GetEffectiveScale() or 1))	
	end 
	
	if RankAoE then 
		if not RankAoE:IsShown() then
            RankAoE:Show()
        end
        RankAoE:SetScale((0.71111112833023 * (1080 / myheight)) / (RankAoE:GetParent() and RankAoE:GetParent():GetEffectiveScale() or 1))	
	end 	
end

local function UpdateCVAR()
    if GetCVar("Contrast") ~= "50" then 
		SetCVar("Contrast", 50)
		Print("Contrast should be 50")		
	end
	
    if GetCVar("Brightness") ~= "50" then 
		SetCVar("Brightness", 50) 
		Print("Brightness should be 50")			
	end
	
    if GetCVar("Gamma") ~= "1.000000" then 
		SetCVar("Gamma", "1.000000") 
		Print("Gamma should be 1")	
	end
	
    local colorblindsimulator = GetCVar("colorblindsimulator") -- Renamed to colorblindSimulator on some versions (?)
    if colorblindsimulator ~= nil and colorblindsimulator ~= "0" then 
		SetCVar("colorblindsimulator", 0) 
	end 
	
	local colorblindSimulator = GetCVar("colorblindSimulator")
	if colorblindSimulator ~= nil and colorblindSimulator ~= "0" then 
		SetCVar("colorblindSimulator", 0) 
	end 
	
	local colorblindWeaknessFactor = GetCVar("colorblindWeaknessFactor")
	if colorblindWeaknessFactor ~= nil and colorblindWeaknessFactor ~= "0.5"  then 
		SetCVar("colorblindWeaknessFactor", 0.5) 
	end
	
	if toNum[GetCVar("SpellQueueWindow") or 400] == nil then 
		SetCVar("SpellQueueWindow", 400) 
	end 
	
	--[[
    if GetCVar("RenderScale") ~= "1" then 
		SetCVar("RenderScale", 1) 
	end
		
    if GetCVar("MSAAQuality") ~= "0" then 
		SetCVar("MSAAQuality", 0) 
	end
	
    -- Could effect bugs if > 0 but FXAA should work, some people saying MSAA working too 
	local AAM = toNum[GetCVar("ffxAntiAliasingMode")]
    if AAM > 2 and AAM ~= 6 then 		
		SetCVar("ffxAntiAliasingMode", 0) 
		Print("You can't set higher AntiAliasing mode than FXAA or not equal to MSAA 8x")
	end
	]]
	
    if GetCVar("doNotFlashLowHealthWarning") ~="1" then 
		SetCVar("doNotFlashLowHealthWarning", 1) 
	end
	
	local nameplateMaxDistance = GetCVar("nameplateMaxDistance")
    if nameplateMaxDistance and toNum[nameplateMaxDistance] ~= CONST.CACHE_DEFAULT_NAMEPLATE_MAX_DISTANCE then 
		SetCVar("nameplateMaxDistance", CONST.CACHE_DEFAULT_NAMEPLATE_MAX_DISTANCE) 
		Print("nameplateMaxDistance " .. nameplateMaxDistance .. " => " .. CONST.CACHE_DEFAULT_NAMEPLATE_MAX_DISTANCE)	
	end	
	
	if GetToggle(1, "cameraDistanceMaxZoomFactor") then 
		local cameraDistanceMaxZoomFactor = GetCVar("cameraDistanceMaxZoomFactor")
		if cameraDistanceMaxZoomFactor ~= "4" then 
			SetCVar("cameraDistanceMaxZoomFactor", 4) 
			Print("cameraDistanceMaxZoomFactor " .. cameraDistanceMaxZoomFactor .. " => " .. 4)	
		end		
	end 
	
    -- WM removal
    if GetCVar("screenshotQuality") ~= "10" then 
		SetCVar("screenshotQuality", 10)  
	end
	
    if GetCVar("nameplateShowEnemies") ~= "1" then
        SetCVar("nameplateShowEnemies", 1) 
		Print("Enemy nameplates should be enabled")
    end		
	
	if GetCVar("autoSelfCast") ~= "1" then 
		SetCVar("autoSelfCast", 1)
	end 
end

local function ConsoleUpdate()
	UpdateCVAR()
    UpdateFrames()      
end 

local function TrueScaleInit()
    TMW:RegisterCallback("TMW_GROUP_SETUP_POST", function(_, frame)
            local str_group = toStr[frame]
            if strfind(str_group, "TellMeWhen_Group1") then                
                UpdateFrames()  
            end
    end)
    
	Listener:Add("ACTION_EVENT_UTILS", "DISPLAY_SIZE_CHANGED", 		ConsoleUpdate	)
	Listener:Add("ACTION_EVENT_UTILS", "UI_SCALE_CHANGED", 			ConsoleUpdate	)
	--Listener:Add("ACTION_EVENT_UTILS", "PLAYER_ENTERING_WORLD", 	ConsoleUpdate	)
	--Listener:Add("ACTION_EVENT_UTILS", "CVAR_UPDATE",				UpdateCVAR		)		
	VideoOptionsFrame:HookScript("OnHide", 							ConsoleUpdate	)
	InterfaceOptionsFrame:HookScript("OnHide", 						UpdateCVAR		)
	TMW:RegisterCallback("TMW_ACTION_IS_INITIALIZED", 				UpdateCVAR		) -- For GetToggle things we have to make post call
	ConsoleUpdate()
	
    TMW:UnregisterCallback("TMW_SAFESETUP_COMPLETE", TrueScaleInit, "TMW_TEMP_SAFESETUP_COMPLETE")
end
TMW:RegisterCallback("TMW_SAFESETUP_COMPLETE", TrueScaleInit, "TMW_TEMP_SAFESETUP_COMPLETE")    

function A.BlackBackgroundIsShown()
	-- @return boolean 
	return BlackBackground:IsShown()
end 

function A.BlackBackgroundSet(bool)
    BlackBackground.IsEnable = bool 
    BlackBackground:SetShown(bool)
end

-------------------------------------------------------------------------------
-- Frames 
-------------------------------------------------------------------------------
-- TellMeWhen Documentation - Sets attributes of an icon.
-- 
-- The attributes passed to this function will be processed by a [[api/icon-data-processor/api-documentation/|IconDataProcessor]] (and possibly one or more [[api/icon-data-processor-hook/api-documentation/|IconDataProcessorHook]]) and interested [[api/icon-module/api-documentation/|IconModule]]s will be notified of any changes to the attributes.
-- @name Icon:SetInfo
-- @paramsig signature, ...
-- @param signature [string] A semicolon-delimited string of attribute strings as passed to the constructor of a [[api/icon-data-processor/api-documentation/|IconDataProcessor]].
-- @param ... [...] Any number of params that will match up one-for-one with the signature passed in.
-- @usage icon:SetInfo("texture", "Interface\\AddOns\\TellMeWhen\\Textures\\Disabled")
--  
--  -- From IconTypes/IconType_wpnenchant:
--  icon:SetInfo("state; start, duration; spell",
--    STATE_ABSENT,
--    0, 0,
--    nil
--  )
-- 
--  -- From IconTypes/IconType_reactive:
--  icon:SetInfo("state; texture; start, duration; charges, maxCharges, chargeStart, chargeDur; stack, stackText; spell",
--    STATE_USABLE,
--    GetSpellTexture(iName),
--    start, duration,
--    charges, maxCharges, chargeStart, chargeDur
--    stack, stack,
--    iName			
local function TMWAPI(icon, ...)
    local attributesString, param = ...
    
	-- Sets texture 
    if attributesString == "state" then 
        -- Color if not colored (Alpha will show it)
        if type(param) == "table" and param["Color"] then 
            if icon.attributes.calculatedState.Color ~= param["Color"] then 
                icon:SetInfo(attributesString, {Color = param["Color"], Alpha = param["Alpha"], Texture = param["Texture"]})
            end
            return 
        end 
        
        -- Hide if not hidden
        if type(param) == "number" and (param == 0 or param == CONST.TMW_DEFAULT_STATE_HIDE) then
            if icon.attributes.realAlpha ~= 0 then 
                icon:SetInfo(attributesString, param)
            end 
            return 
        end 
    end 
    
    if attributesString == "texture" and type(param) == "number" then         
        if (icon.attributes.calculatedState.Color ~= "ffffffff" or icon.attributes.realAlpha == 0) then 
            -- Show + Texture if hidden
            icon:SetInfo("state; " .. attributesString, CONST.TMW_DEFAULT_STATE_SHOW, param)
        elseif icon.attributes.texture ~= param then 
            -- Texture if not applied        
            icon:SetInfo(attributesString, param)
        end 
        return         
    end 
    
    icon:SetInfo(...)
end
  
function A.Hide(icon)
	-- @usage A.Hide(icon)
	if not icon then 
		error("A.Hide tried to hide nil 'icon'", 2)
	else 
		local meta = icon.ID		
		if meta == 3 and RankSingle.isColored then 
			RankSingle.texture:SetColorTexture(0, 0, 0, 1.0)
			RankSingle.isColored = nil 
			TMW:Fire("TMW_ACTION_RANK_DISPLAY_CHANGED")
		end 
		
		if meta == 4 and RankAoE.isColored then 
			RankAoE.texture:SetColorTexture(0, 0, 0, 1.0)
			RankAoE.isColored = nil 
		end 
		
		if icon.attributes.state ~= CONST.TMW_DEFAULT_STATE_HIDE then 
			icon:SetInfo("state; texture", CONST.TMW_DEFAULT_STATE_HIDE, "")
		end 
	end 
end 

function A:Show(icon, texture) 
	-- @usage self:Show(icon) for own texture with color filter or self:Show(icon, textureID)		
	if not icon then 
		error((not texture and self:GetKeyName() or tostring(texture)) .. " tried to use Show() method with nil 'icon'", 2)
	else 
		-- Sets ranks 
		local meta = icon.ID
		if meta == 3 then 
			if not self.useMaxRank and self.isRank then 
				if self.isRank ~= RankSingle.isColored then 
					RankSingle.texture:SetColorTexture(RANKCOLOR[self.isRank]())
					RankSingle.isColored = self.isRank 
					TMW:Fire("TMW_ACTION_RANK_DISPLAY_CHANGED")
				end 
			elseif RankSingle.isColored then 
				RankSingle.texture:SetColorTexture(0, 0, 0, 1.0)
				RankSingle.isColored = nil 
				TMW:Fire("TMW_ACTION_RANK_DISPLAY_CHANGED")
			end 
		end 
		
		if meta == 4 then 
			if not self.useMaxRank and self.isRank then 
				if self.isRank ~= RankAoE.isColored then 
					RankAoE.texture:SetColorTexture(RANKCOLOR[self.isRank]())
					RankAoE.isColored = self.isRank 
				end 
			elseif RankAoE.isColored then 
				RankAoE.texture:SetColorTexture(0, 0, 0, 1.0)
				RankAoE.isColored = nil 
			end 	
		end 
		
		if texture then 
			TMWAPI(icon, "texture", texture)
		else 
			TMWAPI(icon, self:Texture())
		end 		
		
		return true 
	end 
end 

function A.FrameHasSpell(frame, spellID)
	-- @return boolean 
	-- @usage A.FrameHasSpell(icon, {123, 168, 18}) or A.FrameHasSpell(icon, 1022)
	if frame and frame.Enabled and frame:IsVisible() and frame.attributes and type(frame.attributes.texture) == "number" then 
		local texture = frame.attributes.texture
		if type(spellID) == "table" then 
			for i = 1, #spellID do 
				if texture == GetSpellTexture(spellID[i]) then 
					return true 
				end 
			end 
		else 
			return texture == GetSpellTexture(spellID) 
		end 	
	end 
	return false 
end 

function A.FrameHasObject(frame, ...)
	-- @return boolean 
	-- @usage A.FrameHasObject(frame, A.Spell1, A.Item1)
	if frame and frame.Enabled and frame:IsVisible() and frame.attributes and frame.attributes.texture and frame.attributes.texture ~= "" then 
		local texture = frame.attributes.texture
		for i = 1, select("#", ...) do 
			local obj = select(i, ...)
			local _, objTexture = obj:Texture()
			if objTexture and objTexture == texture then 
				return true 
			end 
		end 
	end 
end 

-------------------------------------------------------------------------------
-- TMW Help Frame
-------------------------------------------------------------------------------
Listener:Add("ACTION_EVENT_UTILS_TMW_HELP", "ADDON_LOADED", function(addonName) 
	if addonName == CONST.ADDON_NAME_TMW_OPTIONS or addonName == CONST.ADDON_NAME_TMW then 
		_G.TellMeWhen_IconEditor.Pages.Help:HookScript("OnShow", function(self)
			self:Hide()
		end)
		Listener:Remove("ACTION_EVENT_UTILS_TMW_HELP", "ADDON_LOADED")
	end 
end)

-------------------------------------------------------------------------------
-- TMW PlayerNames fix
-------------------------------------------------------------------------------
if TELLMEWHEN_VERSIONNUMBER <= 87303 then -- Classic 87303
	local NAMES 											= TMW.NAMES
	local GetNumBattlefieldScores, 	  GetBattlefieldScore 	= 
	   _G.GetNumBattlefieldScores, _G.GetBattlefieldScore
	function NAMES:UPDATE_BATTLEFIELD_SCORE()
		for i = 1, GetNumBattlefieldScores() do
			local name, _, _, _, _, _, _, _, _, classToken = GetBattlefieldScore(i)
			if name and self.ClassColors[classToken] then 
				self.ClassColoredNameCache[name] = self.ClassColors[classToken] .. name .. "|r"
			end
		end
	end
end 

-------------------------------------------------------------------------------
-- TMW IconConfig.lua attempt to index field 'CurrentTabGroup' (nil value) fix
-------------------------------------------------------------------------------
Listener:Add("ACTION_EVENT_UTILS_TMW_OPTIONS", "ADDON_LOADED", function(addonName) 
	if addonName == CONST.ADDON_NAME_TMW_OPTIONS or addonName == CONST.ADDON_NAME_TMW then 
		local IE 			= TMW.IE
		local CI 			= TMW.CI
		local PlaySound 	= _G.PlaySound
		if not IE or not CI then 
			return 
		end 
		function IE:LoadIcon(isRefresh, icon)
			if icon ~= nil then

				local ic_old = CI.icon

				if type(icon) == "table" then			
					PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
					IE:SaveSettings()
					
					CI.icon = icon
					
					if ic_old ~= CI.icon then
						IE.Pages.IconMain.PanelsLeft.ScrollFrame:SetVerticalScroll(0)
						IE.Pages.IconMain.PanelsRight.ScrollFrame:SetVerticalScroll(0)
					end

					IE.TabGroups.ICON:SetChildrenEnabled(true)

				elseif icon == false then
					CI.icon = nil
					IE.TabGroups.ICON:SetChildrenEnabled(false)

					if IE.CurrentTabGroup and IE.CurrentTabGroup.identifier == "ICON" then
						IE.ResetButton:Disable()
					end
				end

				TMW:Fire("TMW_CONFIG_ICON_LOADED_CHANGED", CI.icon, ic_old)
			end

			IE:Load(isRefresh)
		end
		Listener:Remove("ACTION_EVENT_UTILS_TMW_OPTIONS", "ADDON_LOADED")	
	end 	
end)

-------------------------------------------------------------------------------
-- TMW LockToggle fix
-------------------------------------------------------------------------------
local InCombatLockdown = _G.InCombatLockdown
local function LockToggle()
	if not TMW.Locked and not TMW.ALLOW_LOCKDOWN_CONFIG and (InCombatLockdown() or A.Zone == "pvp") then 
		TMW.ALLOW_LOCKDOWN_CONFIG = true 
		TMW:LockToggle()
		TMW:Update()
		TMW.ALLOW_LOCKDOWN_CONFIG = false
	end 
end 
hooksecurefunc(TMW, "LockToggle", LockToggle)