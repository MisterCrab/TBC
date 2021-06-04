-------------------------------------------------------------------------------------
-- Original lib has missed some spells
-- This file extend spell list and API methods
-------------------------------------------------------------------------------------

local Lib 												= LibStub("DRList-1.0")
local L													= Lib.L
local diminishedDurations								= Lib.diminishedDurations[Lib.gameExpansion]
local categoryNames										= Lib.categoryNames[Lib.gameExpansion]
local spellList											= Lib.spellList

local _G, error											= _G, error
local GetSpellInfo										= _G.GetSpellInfo

-------------------------------------------------------------------------------
-- API extend  
-------------------------------------------------------------------------------	  
--- Get next successive diminished duration
-- @tparam number diminished How many times the DR has been applied so far
-- @tparam[opt="default"] string category Unlocalized category name
-- @usage local reduction = DRList:GetNextDR(1) -- returns 0.50, half duration on debuff
-- @treturn number DR percentage in decimals. Returns 0 if max DR is reached or arguments are invalid.
function Lib:GetNextDR(diminished, category)
    local durations = diminishedDurations[category or "default"]
    if not durations and categoryNames[category] then
        -- Redirect to default when "stun", "root" etc is passed
        durations = diminishedDurations["default"]		
    end
	
	if not durations then 
		error("Wrong '" .. (category or "") .. "' category for function GetNextDR in the DRList library")
	end 
	
	return durations and durations[diminished] or 0
end

-- Get ApplicationMax
function Lib:GetApplicationMax(category)
	local durations = diminishedDurations[category or "default"] or (categoryNames[category] and diminishedDurations.default)
	return durations and #durations + 1 or 0
end 

-- keep same API as DRData-1.0 for easier transitions
Lib.NextDR = Lib.GetNextDR

-------------------------------------------------------------------------------
-- List extend  
-------------------------------------------------------------------------------	  
if Lib.gameExpansion == "classic" then 
	categoryNames.disarm 				= L.DISARMS
	
	-- Disarms
	spellList[GetSpellInfo(676)]     	= { category = "disarm", spellID = 676 }     		-- Disarm
	spellList[GetSpellInfo(14251)]   	= { category = "disarm", spellID = 14251 }     		-- Riposte
	spellList[GetSpellInfo(23365)]   	= { category = "disarm", spellID = 23365 }     		-- Dropped Weapon

	-- Incapacitates
	spellList[GetSpellInfo(2094)]		= { category = "incapacitate", spellID = 2094 } 	-- Blind 
	spellList[GetSpellInfo(9484)]		= { category = "incapacitate", spellID = 9484 } 	-- Shackle Undead 
	spellList[GetSpellInfo(710)]		= { category = "incapacitate", spellID = 710 } 		-- Banish

	-- Turn Undead 
	spellList[GetSpellInfo(2878)]    	= { category = "fear", spellID = 2878 }          	-- Turn Undead

	-- Stuns 
	spellList[GetSpellInfo(19482)]  	= { category = "stun", spellID = 19482 }   			-- War Stomp (Doomguard pet)
end 