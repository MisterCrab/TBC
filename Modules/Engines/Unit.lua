local _G, setmetatable, unpack, select, next, type, pairs, ipairs, math, error =
	  _G, setmetatable, unpack, select, next, type, pairs, ipairs, math, error 
	  
local huge 									= math.huge	  
local math_max								= math.max 
local math_floor							= math.floor	
local math_random							= math.random
local wipe 									= _G.wipe 
local strsplit								= _G.strsplit
local debugstack							= _G.debugstack	  
	  
local TMW 									= _G.TMW
local CNDT 									= TMW.CNDT
local Env 									= CNDT.Env
local AuraTooltipNumber						= Env.AuraTooltipNumber
local AuraVariableNumber 					= Env.AuraVariableNumber
local strlowerCache  						= TMW.strlowerCache

local LibStub								= _G.LibStub
local HealComm 								= LibStub("LibHealComm-4.0", true) -- Note: Leave it with true in case if will need to disable lib, seems lib causing unexpected lua errors in PvP 
local LibRangeCheck  						= LibStub("LibRangeCheck-2.0")
local LibBossIDs							= LibStub("LibBossIDs-1.0").BossIDs

local A   									= _G.Action	
local CONST 								= A.Const
local Listener								= A.Listener
local insertMulti							= A.TableInsertMulti
local toNum 								= A.toNum
local strElemBuilder						= A.strElemBuilder
local Player 								= A.Player
local UnitCooldown							= A.UnitCooldown
local CombatTracker							= A.CombatTracker
local MultiUnits							= A.MultiUnits
local GetToggle								= A.GetToggle
local MouseHasFrame							= A.MouseHasFrame
local UnitInLOS								= A.UnitInLOS

local TeamCache								= A.TeamCache
local TeamCachethreatData					= TeamCache.threatData
local TeamCacheFriendly 					= TeamCache.Friendly
local TeamCacheFriendlyUNITs				= TeamCacheFriendly.UNITs
local TeamCacheFriendlyGUIDs				= TeamCacheFriendly.GUIDs
local TeamCacheFriendlyIndexToPLAYERs		= TeamCacheFriendly.IndexToPLAYERs
local TeamCacheFriendlyIndexToPETs			= TeamCacheFriendly.IndexToPETs
local TeamCacheEnemy 						= TeamCache.Enemy
local TeamCacheEnemyUNITs					= TeamCacheEnemy.UNITs
local TeamCacheEnemyGUIDs					= TeamCacheEnemy.GUIDs
local TeamCacheEnemyIndexToPLAYERs			= TeamCacheEnemy.IndexToPLAYERs
local TeamCacheEnemyIndexToPETs				= TeamCacheEnemy.IndexToPETs
local ActiveUnitPlates						= MultiUnits:GetActiveUnitPlates()
local ActiveUnitPlatesAny					= MultiUnits:GetActiveUnitPlatesAny()
	  
local ALL_HEALS								= HealComm and HealComm.ALL_HEALS	  
local CACHE_DEFAULT_TIMER_UNIT				= CONST.CACHE_DEFAULT_TIMER_UNIT

local GameLocale 							= A.FormatGameLocale(_G.GetLocale())	  
local CombatLogGetCurrentEventInfo			= _G.CombatLogGetCurrentEventInfo	  
local GetUnitSpeed							= _G.GetUnitSpeed
local GetSpellInfo							= _G.GetSpellInfo
local GetPartyAssignment 					= _G.GetPartyAssignment	  
local UnitIsUnit, UnitPlayerOrPetInRaid, UnitInAnyGroup, UnitPlayerOrPetInParty, UnitInRange, UnitLevel, UnitRace, UnitClass, UnitClassification, UnitExists, UnitIsConnected, UnitIsCharmed, UnitIsGhost, UnitIsDeadOrGhost, UnitIsFeignDeath, UnitIsPlayer, UnitPlayerControlled, UnitCanAttack, UnitIsEnemy, UnitAttackSpeed,
	  UnitPowerType, UnitPowerMax, UnitPower, UnitName, UnitCanCooperate, UnitCreatureType, UnitCreatureFamily, UnitHealth, UnitHealthMax, UnitGUID, UnitHasIncomingResurrection, UnitIsVisible, UnitDebuff, UnitCastingInfo, UnitChannelInfo =
	  UnitIsUnit, UnitPlayerOrPetInRaid, UnitInAnyGroup, UnitPlayerOrPetInParty, UnitInRange, UnitLevel, UnitRace, UnitClass, UnitClassification, UnitExists, UnitIsConnected, UnitIsCharmed, UnitIsGhost, UnitIsDeadOrGhost, UnitIsFeignDeath, UnitIsPlayer, UnitPlayerControlled, UnitCanAttack, UnitIsEnemy, UnitAttackSpeed,
	  UnitPowerType, UnitPowerMax, UnitPower, UnitName, UnitCanCooperate, UnitCreatureType, UnitCreatureFamily, UnitHealth, UnitHealthMax, UnitGUID, UnitHasIncomingResurrection, UnitIsVisible, UnitDebuff, UnitCastingInfo, UnitChannelInfo
local UnitAura 								= _G.UnitAura	  
	  
local UnitThreatSituation					= _G.UnitThreatSituation
local UnitDetailedThreatSituation			= _G.UnitDetailedThreatSituation
-------------------------------------------------------------------------------
-- Remap
-------------------------------------------------------------------------------
local A_Unit, A_GetSpellInfo, A_GetGCD, A_GetCurrentGCD, A_EnemyTeam, A_GetUnitItem

Listener:Add("ACTION_EVENT_UNIT", "ADDON_LOADED", function(addonName)
	if addonName == CONST.ADDON_NAME then 
		A_Unit						= A.Unit		
		A_GetSpellInfo				= A.GetSpellInfo	
		A_GetGCD					= A.GetGCD
		A_GetCurrentGCD				= A.GetCurrentGCD
		A_EnemyTeam					= A.EnemyTeam	
		A_GetUnitItem				= A.GetUnitItem
		
		Listener:Remove("ACTION_EVENT_UNIT", "ADDON_LOADED")	
	end 
end)
-------------------------------------------------------------------------------	

local function GetGUID(unitID)
	return TeamCacheFriendlyUNITs[unitID] or TeamCacheEnemyUNITs[unitID] or UnitGUID(unitID)
end 

-------------------------------------------------------------------------------
-- Cache
-------------------------------------------------------------------------------
local str_none = "none"
local str_empty = ""

local function PseudoClass(methods)
    local Class = setmetatable(methods, {
		__call = function(self, ...)
			self:New(...)
			return self				 
		end,
    })
    return Class
end

local Cache = {
	bufer = {},	
	newEl = function(this, inv, keyArg, func, ...)
		if not this.bufer[func][keyArg] then 
			this.bufer[func][keyArg] = { v = {} }
		else 
			wipe(this.bufer[func][keyArg].v)
		end 
		this.bufer[func][keyArg].t = TMW.time + (inv or CACHE_DEFAULT_TIMER_UNIT) + 0.001  -- Add small delay to make sure what it's not previous corroute  
		insertMulti(this.bufer[func][keyArg].v, func(...))
		return unpack(this.bufer[func][keyArg].v)
	end,
	Wrap = function(this, func, name)
		if CONST.CACHE_DISABLE then 
			return func 
		end 
		
		if not this.bufer[func] then 
			this.bufer[func] = {} 
		end
		
   		return function(...)   
			-- The reason of all this view look is memory hungry eating, this way use around 0 memory now
			local self = ...		
			local keyArg = strElemBuilder(name == "UnitGUID" and self.UnitID and UnitGUID(self.UnitID) or self.UnitID or self.ROLE or name, ...)		

	        if TMW.time > (this.bufer[func][keyArg] and this.bufer[func][keyArg].t or 0) then
	            return this:newEl(self.Refresh, keyArg, func, ...)
	        else
	            return unpack(this.bufer[func][keyArg].v)
	        end
        end        
    end,
	Pass = function(this, func, name) 
		if CONST.CACHE_MEM_DRIVE and not CONST.CACHE_DISABLE then 
			return this:Wrap(func, name)
		end 

		return func
	end,
}

local AuraList = {
    -- CC SCHOOL TYPE 
    Magic = {         
		853, 				-- Hammer of Justice 		(Paladin)
		20066, 				-- Repentance				(Paladin)
		17390,				-- Faerie Fire (Feral)		(Druid)		
		2637, 				-- Hibernate 				(Druid)
		1499, 				-- Freezing Trap			(Hunter)
		118, 				-- Polymorph				(Mage)
		851,				-- Polymorph: Sheep 		(Mage)
		605, 				-- Mind Control 			(Priest)                 
        8122, 				-- Psychic Scream			(Priest)
		9484, 				-- Shackle Undead 			(Priest)  				
		15487, 				-- Silence 					(Priest)
        5782, 				-- Fear						(Warlock)        
        6358, 				-- Seduction 				(Warlock)
        5484, 				-- Howl of Terror        	(Warlock)        
		710, 				-- Banish 					(Warlock)
		-- Roots 
        22519, 				-- Ice Nova 				(Mage)
        122, 				-- Frost Nova 				(Mage)		
        339, 				-- Entangling Roots 		(Druid)		
    },
    MagicRooted = {
        22519, 				-- Ice Nova 				(Mage)
        122, 				-- Frost Nova 				(Mage)		
        339, 				-- Entangling Roots 		(Druid)
    }, 
    Curse = {
		8277, 				-- Voodoo Hex   			(Shaman) 				-- I AM NOT SURE
	},
    --Disease = {},
    Poison = {
        24133, 				-- Wyvern Sting 			(Hunter)
        3034, 				-- Viper Sting 				(Hunter)
        3043,		 		-- Scorpid Sting 			(Hunter)
		7992, 				-- Slowing Poison 			(Rogue)
		3408, 				-- Crippling Poison 		(Rogue)
    },
    Physical = {
		7922, 				-- Charge Stun				(Warrior)
		676, 				-- Disarm 					(Warrior)
		5246, 				-- Intimidating Shout		(Warrior)
		12809,				-- Concussion Blow			(Warrior)
		20253,				-- Intercept Stun 			(Warrior)
		5211,				-- Bash						(Druid)
		9005,				-- Pounce					(Druid)
		12355,				-- Impact					(Mage, physical effect)
		19503, 				-- Scatter Shot 			(Hunter)
		19577,				-- Intimidation 			(Hunter)  				-- Berserker Rage can remove it!
		19410,				-- Improved Concussive Shot	(Hunter)
		408, 				-- Kidney Shot 				(Rogue)	
		1833, 				-- Cheap Shot 				(Rogue)        
		1776, 				-- Gouge					(Rogue)		
		6770, 				-- Sap 						(Rogue)
		2094, 				-- Blind					(Rogue)		        
		20549, 				-- War Stomp 				(Tauren)	
		20685,				-- Storm Bolt 				(Unknown)				-- FIX ME: Is it useable?
		5530,				-- Mace Stun				(Unknown)
		16922,				-- Starfire Stun			(Unknown)
   },
    -- CC CONTROL TYPE
    Incapacitated = { 
        1499, 				-- Freezing Trap			(Hunter) 
        20066, 				-- Repentance				(Paladin)
		6770, 				-- Sap 						(Rogue)
        1776, 				-- Gouge					(Rogue)
		710, 				-- Banish        			(Warlock)
		22570,				-- Mangle					(Druid)
    },
	Fleeing	= {
		5782, 				-- Fear						(Warlock)
		5484, 				-- Howl of Terror   		(Warlock)
		5246, 				-- Intimidating Shout		(Warrior)
		8122, 				-- Psychic Scream			(Priest)
	},
	Shackled = {
		9484, 				-- Shackle Undead 			(Priest)	
	},
	Polymorphed	= {
		118, 				-- Polymorph				(Mage)
		851,				-- Polymorph: Sheep 		(Mage)
		28272,				-- Polymorph: Pig			(Mage)
		28271,				-- Polymorph: Turtle		(Mage)
	},
    Disoriented = {			
		19503, 				-- Scatter Shot 			(Hunter)		 
        2094, 				-- Blind					(Rogue)
    },    
    Fear = {
		5782, 				-- Fear						(Warlock)
		5484, 				-- Howl of Terror   		(Warlock)
		5246, 				-- Intimidating Shout		(Warrior)
		6789,				-- Death Coil				(Warlock)
		8122, 				-- Psychic Scream			(Priest)
    },
    Charmed = {
        605, 				-- Mind Control 			(Priest)                 
        --9484, 				-- Shackle Undead 			(Priest)
    },
    Sleep = {
		2637, 				-- Hibernate 				(Druid)	
		19386, 				-- Wyvern Sting 			(Hunter)
	},
    Stuned = {
		7922, 				-- Charge Stun				(Warrior)
		12809,				-- Concussion Blow			(Warrior)
		20253,				-- Intercept Stun 			(Warrior)
		5530,				-- Mace Stun Effect			(Warrior)
		12798,				-- Revenge Stun				(Warrior)
		5211,				-- Bash						(Druid)
		9005,				-- Pounce					(Druid)
		12355,				-- Impact					(Mage, physical effect)
		22703,				-- Inferno Effect			(Warlock)
		18093,				-- Pyroclasm				(Warlock)
		19577,				-- Intimidation 			(Hunter)  				-- Berserker Rage can remove it!
		19410,				-- Improved Concussive Shot	(Hunter)
		853, 				-- Hammer of Justice 		(Paladin)
		1833, 				-- Cheap Shot 				(Rogue)
        408, 				-- Kidney Shot 				(Rogue)	
		20549, 				-- War Stomp 				(Tauren)
		20685,				-- Storm Bolt 				(Unknown)				-- FIX ME: Is it useable?			
		16922,				-- Starfire Stun			(Unknown)
		56,					-- Stun 					(Weapon proc)
		4067,				-- Big Bronze Bomb
		4066,				-- Small Bronze Bomb
		4065,				-- Large Copper Bomb
		4064,				-- Rough Copper Bomb
		13808,				-- M73 Frag Grenade
		19769,				-- Thorium Grenade
	},
    PhysStuned = {
		7922, 				-- Charge Stun				(Warrior)
		12809,				-- Concussion Blow			(Warrior)
		20253,				-- Intercept Stun 			(Warrior)
		5530,				-- Mace Stun Effect			(Warrior)
		12798,				-- Revenge Stun				(Warrior)
		5211,				-- Bash						(Druid)
		9005,				-- Pounce					(Druid)		
		12355,				-- Impact					(Mage, physical effect)
		22703,				-- Inferno Effect			(Warlock)
		18093,				-- Pyroclasm				(Warlock)
		19577,				-- Intimidation 			(Hunter)  				-- Berserker Rage can remove it!
		19410,				-- Improved Concussive Shot	(Hunter)
		1833, 				-- Cheap Shot 				(Rogue)
        408, 				-- Kidney Shot 				(Rogue)		
		20549, 				-- War Stomp 				(Tauren)	
		20685,				-- Storm Bolt	 			(Unknown)				-- FIX ME: Is it useable?		
		16922,				-- Starfire Stun			(Unknown)		
		56,					-- Stun 					(Weapon proc)	
		4067,				-- Big Bronze Bomb
		4066,				-- Small Bronze Bomb
		4065,				-- Large Copper Bomb
		4064,				-- Rough Copper Bomb
	},
    Silenced = {
		15487, 				-- Silence 					(Priest) 
		18469,				-- Counterspell - Silenced	(Mage)
		18425,				-- Kick - Silenced			(Rogue)
		24259,				-- Spell Lock (Felhunter) 	(Warlock)
		19821,				-- Arcane Bomb
		18278,				-- Silence (Silent Fang sword)
	},
    Disarmed = {
		676, 				-- Disarm 					(Warrior)
		14251,				-- Riposte					(Rogue)
		23365,				-- Dropped Weapon			(Unknown)
	},
    Rooted = {
		23694,				-- Improved Hamstring		(Warrior)
        22519, 				-- Ice Nova 				(Mage)
        122, 				-- Frost Nova 				(Mage)	
		12494,				-- Frostbite				(Mage)	
        339, 				-- Entangling Roots 		(Druid)
		19675,				-- Feral Charge Effect		(Druid)
		19229,				-- Improved Wing Clip 		(Hunter)
		19185,				-- Entrapment				(Hunter)
		25999,				-- Boar Charge				(Hunter's pet)		
    },  
    Slowed = {		
        1715, 				-- Hamstring				(Warrior)
		12323, 				-- Piercing Howl			(Warrior)
        3408, 				-- Crippling Poison			(Rogue)        
        7992, 				-- Slowing Poison			(Rogue)
		2974, 				-- Wing Clip				(Hunter)
		5116, 				-- Concussive Shot			(Hunter)
        13496, 				-- Dazed (aka "confuse")	(Druid, Hunter)        
        17311, 				-- Mind Flay				(Priest)                               
        2484, 				-- Earthbind				(Shaman)
        8056, 				-- Frost Shock				(Shaman)
		8034, 				-- Frostbrand Attack		(Shaman)
		116, 				-- Frostbolt     			(Mage)
		120, 				-- Cone of Cold				(Mage)
        6136, 				-- Chilled 					(Mage)		
		16094, 				-- Frost Breath 			(Mage)        
		11113, 				-- Blast Wave				(Mage)
		3604, 				-- Tendon Rip				(Unknown)
    },
    MagicSlowed = {        
        2484, 				-- Earthbind				(Shaman)
        8056, 				-- Frost Shock				(Shaman)
		8034, 				-- Frostbrand Attack		(Shaman)				-- FIX ME: I AM NOT SURE 		
        6136, 				-- Chilled 					(Mage)	 				-- FIX ME: I AM NOT SURE 
		16094, 				-- Frost Breath 			(Mage)					-- FIX ME: I AM NOT SURE 
        120, 				-- Cone of Cold 			(Mage)
		116, 				-- Frostbolt     			(Mage)
    },
    BreakAble = {
		5246, 				-- Intimidating Shout		(Warrior)
        20066, 				-- Repentance				(Paladin)		
		2637, 				-- Hibernate				(Druid)
		118, 				-- Polymorph				(Mage)
		851,				-- Polymorph: Sheep 		(Mage)
		28272,				-- Polymorph: Pig			(Mage)
		28271,				-- Polymorph: Turtle		(Mage)
		1499, 				-- Freezing Trap			(Hunter)
		19386, 				-- Wyvern Sting   			(Hunter)	
		19503, 				-- Scatter Shot        		(Hunter)
        6770, 				-- Sap 						(Rogue)
		2094, 				-- Blind					(Rogue) 
		1776, 				-- Gouge					(Rogue)
        5782, 				-- Fear						(Warlock)        
        6358, 				-- Seduction (pet)			(Warlock)                
        5484, 				-- Howl of Terror			(Warlock)
        8122, 				-- Psychic Scream			(Priest)      
		9484, 				-- Shackle Undead 			(Priest)			
        -- Rooted CC
        339, 				-- Entangling Roots			(Druid)
        122, 				-- Frost Nova				(Mage)
    },
    -- Imun Specific Buffs 
    FearImun = {
		18499, 				-- Berserker Rage 			(Warrior)
		12328,				-- Death Wish				(Warrior)
		1719,				-- Recklessness				(Warrior)
        8143, 				-- Tremor Totem 			(Shaman)
		6346,				-- Fear Ward				(Priest)		
    },
	FearImunDeBuffs = {
		704,				-- Curse of Recklessness 	(Warlock)
	},
    StunImun = {
        6615, 				-- Free Action 				(Free Action Potion)
		24364,				-- Living Free Action		(Potion)
        1953, 				-- Blink (micro buff)		(Mage)
    },        
    Freedom = {
		6615, 				-- Free Action 				(Free Action Potion)
		1044, 				-- Blessing of Freedom		(Paladin)
		24364,				-- Living Free Action		(Potion)
	},
    TotalImun = {
		710, 				-- Banish 					(Warlock)
		498, 				-- Divine Protection		(Paladin)
        642, 				-- Divine Shield			(Paladin)		
        11958, 				-- Ice Block				(Mage)
        19263, 				-- Deterrence    			(Hunter)
        20711, 				-- Spirit of Redemption		(Priest)
		17624,				-- Petrification			(Flask of Petrification)
    },
    DamagePhysImun = {		
		1022, 				-- Blessing of Protection	(Paladin)
		3169,				-- Invulnerability			(Limited Invulnerability Potion)
		--16621,			-- Self Invulnerability (Invulnerable Mail weapon) -- FIX ME: seems only for swing attacks
	},
    DamageMagicImun = {}, 
    CCTotalImun = {},     
    CCMagicImun = {
		8178,				-- Grounding Totem Effect	(Shaman)
	},
    Reflect = { 
        8178, 				-- Grounding Totem Effect	(Shaman)
        23131, 				-- Frost Reflector			(Item)
        23132, 				-- Shadow Reflector			(Item)
        23097, 				-- Fire Reflector			(Item)
    }, 
    KickImun = {},
    -- Purje 
    ImportantPurje = {
        1022, 				-- Blessing of Protection	(Paladin)
        20216, 				-- Divine Favor 			(Paladin)		
        11129, 				-- Combustion 				(Mage)
        12042, 				-- Arcane Power 			(Mage)
        10060, 				-- Power Infusion			(Priest)
		29166,				-- Innervate				(Druid)
		2645, 				-- Ghost Wolf 				(Shaman)
		16166, 				-- Elemental Mastery		(Shaman)
		17730,				-- Major Spellstone			(Warlock)
		17729,				-- Greater Spellstone		(Warlock)
		128,				-- Spellstone				(Warlock)
		18708,				-- Fel Domination			(Warlock)
		18288,				-- Amplify Curse			(Warlock)		
    },
    SecondPurje = {
        1044, 				-- Blessing of Freedom      (Paladin)  
        -- We need purje druid only in bear form 
		467,				-- Thorns					(Druid)
        774, 				-- Rejuvenation				(Druid)
        8936, 				-- Regrowth 				(Druid)
        1126, 				-- Mark of the Wild			(Druid)
    },
    -- Speed 
    Speed = {
        2983, 				-- Sprint 					(Rogue)
        2379, 				-- Speed 					(Swiftness Potion)
        2645, 				-- Ghost Wolf 				(Shaman)
		1850, 				-- Dash 					(Druid)
		5118, 				-- Aspect of the Cheetah	(Hunter)       
    },
    -- Deff 
    DeffBuffsMagic = {
		8178, 				-- Grounding Totem Effect	(Shaman)
		--498, 					-- Divine Protection		(Paladin)
        --642, 					-- Divine Shield			(Paladin)
        --11958, 				-- Ice Block				(Mage)
        --19263, 				-- Deterrence    			(Hunter)
        --20711, 				-- Spirit of Redemption		(Priest)		
    }, 
    DeffBuffs = {        
		871,				-- ShieldWall				(Warrior)
		20230,				-- Retaliation				(Warrior)
		5277, 				-- Evasion					(Rogue)
		1022, 				-- Blessing of Protection	(Paladin)
		22812,				-- Barkskin					(Druid)
		3169,				-- Invulnerability			(Limited Invulnerability Potion)
		--498, 					-- Divine Protection		(Paladin)
        --642, 					-- Divine Shield			(Paladin)
        --11958, 				-- Ice Block				(Mage)
        --19263, 				-- Deterrence    			(Hunter)
        --20711, 				-- Spirit of Redemption		(Priest)		
    },  
	SmallDeffBuffs = {
		20594,				-- Stoneform				(Dwarf)
		6940, 				-- Blessing of Sacrifice	(Paladin)
	},
    -- Damage buffs / debuffs
    Rage = {
        18499, 				-- Berserker Rage (Warrior)
        12880, 				-- Enrage (Warrior)
    }, 
    DamageBuffs = {        
		12328,				-- Death Wish 				(Warrior)		
		1719,				-- Recklessness				(Warrior)
		13877,				-- Blade Flurry				(Rogue)
		13750,				-- Adrenaline Rush			(Rogue)
		19574,				-- Bestial Wrath			(Hunter)
		11129, 				-- Combustion 				(Mage)
		12042, 				-- Arcane Power 			(Mage)
		26297,				-- Berserking				(Troll)
		20572,				-- Blood Fury				(Orc)
    },
    DamageBuffs_Melee = {        
		12328,				-- Death Wish 				(Warrior)	
		1719,				-- Recklessness				(Warrior)
        13750,				-- Adrenaline Rush			(Rogue)
		13877,				-- Blade Flurry				(Rogue)		
    },
    BurstHaste = {
        19372, 				-- Ancient Hysteria 		(Unknown)
        24185, 				-- Bloodlust 				(Unknown)
    },
    -- SOME SPECIAL
    --DamageDeBuffs = {}, 
    Flags = {
        301091, 			-- Alliance flag
        301089,  			-- Horde flag 
		23333,				-- Warsong Flag
        23335,  			-- Silverwing Flag
    }, 
    -- Cast Bars
    Reshift = {
        {118, 30}, 			-- Polymorph 				(Mage)
        {19386, 35, 8},		-- Wyvern Sting (8 - 35)	(Hunter)
    },
    Premonition = {
        {118, 30}, 			-- Polymorph 				(Mage)
		{851, 20},			-- Polymorph: Sheep 		(Mage)
		{28272, 30},		-- Polymorph: Pig	 		(Mage)
		{28271, 30},		-- Polymorph: Turtle 		(Mage)
        {24133, 35, 8},		-- Wyvern Sting (8 - 35)	(Hunter)
		{5782, 20}, 		-- Fear 					(Warlock)        
    },
    CastBarsCC = {
        118, 				-- Polymorph 				(Mage)
		851,				-- Polymorph: Sheep 		(Mage)
        20066, 				-- Repentance 				(Paladin)
        24133, 				-- Wyvern Sting 			(Hunter)
        5782, 				-- Fear 					(Warlock) 
		5484, 				-- Howl of Terror   		(Warlock)
        605, 				-- Mind Control 			(Priest)                 
        9484, 				-- Shackle Undead 			(Priest) 
    },
    AllPvPKickCasts = {    
        118, 				-- Polymorph 				(Mage)
		851,				-- Polymorph: Sheep 		(Mage)
		635,				-- Holy Light				(Paladin)
		19750,				-- Flash of Light			(Paladin)
        20066, 				-- Repentance 				(Paladin)		
		5782, 				-- Fear 					(Warlock) 
        19386, 				-- Wyvern Sting 			(Hunter)       
        982, 				-- Revive Pet 				(Hunter)
		605, 				-- Mind Control 			(Priest)  
		9484, 				-- Shackle Undead 			(Priest) 
        4526, 				-- Mass Dispel 				(Priest)	
		596, 				-- Prayer of Healing		(Priest)
		2060,				-- Greater Heal				(Priest)
		2061,				-- Flash Heal				(Priest)
		740, 				-- Tranquility				(Druid)
        20484, 				-- Rebirth					(Druid)
		25297,				-- Healing Touch			(Druid)
		8936, 				-- Regrowth 				(Druid)
		331,				-- Healing Wave				(Shaman)
		1064,				-- Chain Heal				(Shaman)
    },    
}

local AssociativeTables = setmetatable({ NullTable = {} }, { -- Only for Auras!
	--__mode = "kv",
	__index = function(t, v)
	-- @return table 
	-- Returns converted array like table to associative like with key-val as spellName and spellID with true val
	-- For situations when Action is not initialized and when 'v' is table always return self 'v' to keep working old profiles which use array like table
	-- Note: GetSpellInfo instead of A_GetSpellInfo because we will use it one time either if GC collected dead links, pointless for performance A_GetSpellInfo anyway
	if not v then
		if A.IsInitialized then 
			local error_snippet = debugstack():match("%p%l+%s\"?%u%u%u%s%u%l.*")
			if error_snippet then 
				error("Unit.lua script tried to put in AssociativeTables 'nil' as index and it caused null table return. The script successfully found the first occurrence of the error stack in the TMW snippet: " .. error_snippet, 0)
			else 
				error("Unit.lua script tried to put in AssociativeTables 'nil' as index and it caused null table return. Failed to find TMW snippet stack error. Below must be shown level of stack 1.", 1)
			end 
		end 
		return t.NullTable
	end 
	
	local v_type = type(v)
	if v_type == "table" then  
		if #v > 0 then 
			t[v] = {}
		
			local index, val = next(v)
			while index ~= nil do 
				if type(val) == "string" then 
					if AuraList[val] then
						-- Put associatived spellName (@string) and spellID (@number)
						for spellNameOrID, spellBoolean in pairs(t[val]) do 
							t[v][spellNameOrID] = spellBoolean 
						end 
					else -- Here is expected name of the spell always  
						-- Put associatived spellName (@string)
						t[v][val] = true 
					end 
				else -- Here is expected id of the spell always 
					-- Put associatived spellName (@string)
					local spellName = GetSpellInfo(val) 
					if spellName then
						t[v][spellName] = true 
					end 
					
					-- Put associatived spellID (@number)
					t[v][val] = true 
				end 
				
				index, val = next(v, index)
			end 
		else 
			t[v] = v
		end 			
	elseif AuraList[v] then
		t[v] = {}
		
		local spellName
		for _, spellID in ipairs(AuraList[v]) do 
			spellName = GetSpellInfo(spellID) 
			if spellName then 
				t[v][spellName] = true 
			end 
			t[v][spellID] = true
		end 		
	else
		-- Otherwise create new table and put spellName with spellID (if possible) for single entrance to keep return @table 
		t[v] = {}
				
		--local spellName = GetSpellInfo(v_type == "string" and not v:find("%D") and toNum[v] or v) -- TMW lua code passing through 'thisobj.Name' @string type 
		-- Since Classic hasn't 'thisobj.Name' ways in profiles at all we will avoid use string functions 
		local spellName = GetSpellInfo(v)
		if spellName then 
			t[v][spellName] = true 
		end 		 
		
		t[v][v] = true   
	end 
	
	--print("Created associatived table:")
	--print(tostring(v), "  Output:", tostring(t[v]), " Key:", next(t[v]))
	
	return t[v] 
end })

-- Classic has always associative spellinput
--local IsMustBeByID = {}
--local function IsAuraEqual(spellName, spellID, spellInput, byID)
--	-- @return boolean 
--	if byID then 
--		if #spellInput > 0 then 				-- ArrayTables
--			for i = 1, #spellInput do 
--				if AuraList[spellInput[i]] then 
--					for _, auraListID in ipairs(AuraList[spellInput[i]]) do 
--						if spellID == auraListID then 
--							return true 
--						end 
--					end 
--				elseif spellID == spellInput[i] then 
--					return true 
--				end 
--			end
--		else 									-- AssociativeTables
--			return spellInput[spellID]
--		end 
--	else 
--		if #spellInput > 0 then 				-- ArrayTables
--			for i = 1, #spellInput do 
--				if AuraList[spellInput[i]] then 
--					for _, auraListID in ipairs(AuraList[spellInput[i]]) do 
--						if spellName == A_GetSpellInfo(auraListID) then 
--							return true 
--						end 
--					end 
--				elseif IsMustBeByID[spellInput[i]] then -- Retail only 
--					if spellID == spellInput[i] then 
--						return true 
--					end 
--				elseif spellName == A_GetSpellInfo(spellInput[i]) then 
--					return true 
--				end 
--			end 
--		else 									-- AssociativeTables
--			return spellInput[spellName]
--		end 
--	end 
--end

-------------------------------------------------------------------------------
-- API: Core (Action Rotation Conditions)
-------------------------------------------------------------------------------
function A.GetAuraList(key)
	-- @return table 
    return AuraList[key]
end 

function A.IsUnitFriendly(unitID)
	-- @return boolean
	if unitID == "mouseover" then 
		return 	GetToggle(2, unitID) and MouseHasFrame() and not A_Unit(unitID):IsEnemy() 
	elseif unitID == "targettarget" then
		return 	GetToggle(2, unitID) and 
				( not GetToggle(2, "mouseover") or not A_Unit("mouseover"):IsExists() or A_Unit("mouseover"):IsEnemy() ) and 
				A_Unit("target"):IsEnemy() and
				not A_Unit(unitID):IsEnemy() and
				A_Unit(unitID):IsExists() and 
				-- LOS checking 
				not UnitInLOS(unitID)	
	else
		return 	(
					not GetToggle(2, "mouseover") or 
					not A_Unit("mouseover"):IsExists() or 
					A_Unit("mouseover"):IsEnemy()
				) and 
				not A_Unit(unitID):IsEnemy() and
				A_Unit(unitID):IsExists()
	end 
end 
A.IsUnitFriendly = A.MakeFunctionCachedDynamic(A.IsUnitFriendly)

function A.IsUnitEnemy(unitID)
	-- @return boolean
	if unitID == "mouseover" then 
		return  GetToggle(2, unitID) and A_Unit(unitID):IsEnemy() 
	elseif unitID == "targettarget" then
		return 	GetToggle(2, unitID) and 
				( not GetToggle(2, "mouseover") or (not MouseHasFrame() and not A_Unit("mouseover"):IsEnemy()) ) and 
				-- Exception to don't pull by mistake mob
				A_Unit(unitID):CombatTime() > 0 and
				not A_Unit("target"):IsEnemy() and
				A_Unit(unitID):IsEnemy() and 
				-- LOS checking 
				not UnitInLOS(unitID)						
	else
		return 	( not GetToggle(2, "mouseover") or not MouseHasFrame() ) and A_Unit(unitID):IsEnemy() 
	end
end 
A.IsUnitEnemy = A.MakeFunctionCachedDynamic(A.IsUnitEnemy)

-------------------------------------------------------------------------------
-- API: Unit 
-------------------------------------------------------------------------------
local Info = {
	CacheMoveIn					= setmetatable({}, { __mode = "kv" }),
	CacheMoveOut				= setmetatable({}, { __mode = "kv" }),
	CacheMoving 				= setmetatable({}, { __mode = "kv" }),
	CacheStaying				= setmetatable({}, { __mode = "kv" }),
	CacheInterrupt 				= setmetatable({}, { __mode = "kv" }),
	SpecIs 						= {
        ["MELEE"] 				= {103, 255, 70, 259, 260, 261, 263, 71, 72, 66, 73},
        ["RANGE"] 				= {102, 253, 254, 62, 63, 64, 258, 262, 265, 266, 267},
        ["HEALER"] 				= {105, 65, 256, 257, 264},
        ["TANK"] 				= {103, 66, 73},
        ["DAMAGER"] 			= {255, 70, 259, 260, 261, 263, 71, 72, 102, 253, 254, 62, 63, 64, 258, 262, 265, 266, 267},
    },
	ClassCanBeHealer			= {
		["PALADIN"] 			= true,
		["PRIEST"]				= true,
		["SHAMAN"] 				= true,
		["DRUID"] 				= true,	
	},
	ClassCanBeTank				= {
        ["WARRIOR"] 			= true,
        ["PALADIN"] 			= true,
        ["DRUID"] 				= true,	
		["SHAMAN"]				= true, -- T3 tank in Classic possible 
	},
	ClassCanBeMelee				= {
        ["WARRIOR"] 			= true,
        ["PALADIN"] 			= true,
        ["ROGUE"] 				= true,
        ["SHAMAN"] 				= true,
        ["DRUID"] 				= true,		
	},
	AllCC 						= {"Silenced", "Stuned", "Sleep", "Fear", "Disoriented", "Incapacitated"},
	CreatureType				= setmetatable(
		-- Formats localization to English locale
		-- Revision Classic 1.13.4.33920 April 2020
		{
			enUS				= {
				["Beast"]				= "Beast",				-- [1]
				["Dragonkin"]			= "Dragonkin",			-- [2]
				["Demon"]				= "Demon",				-- [3]
				["Elemental"]			= "Elemental",			-- [4]
				["Giant"]				= "Giant",				-- [5]
				["Undead"]				= "Undead",				-- [6]				
				["Humanoid"]			= "Humanoid",			-- [7]
				["Critter"]				= "Critter",			-- [8]
				["Mechanical"]			= "Mechanical",			-- [9]
				["Not specified"]		= "Not specified",		-- [10]				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["Totem"]				= "Totem",				-- [11]				
				--["Non-combat Pet"]	= "Non-combat Pet",		-- [12]	
				--["Gas Cloud"]			= "Gas Cloud",			-- [13]
				--["Wild Pet"]			= "Wild Pet",			-- [14]
				--["Aberration"]		= "Aberration",			-- [15]
			},
			ruRU				= {
				["Животное"]			= "Beast",				-- [1]
				["Дракон"]				= "Dragonkin",			-- [2]
				["Демон"]				= "Demon",				-- [3]
				["Элементаль"]			= "Elemental",			-- [4]
				["Великан"]				= "Giant",				-- [5]
				["Нежить"]				= "Undead",				-- [6]				
				["Гуманоид"]			= "Humanoid",			-- [7]
				["Существо"]			= "Critter",			-- [8]
				["Механизм"]			= "Mechanical",			-- [9]
				["Не указано"]			= "Not specified",		-- [10]				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["Тотем"]				= "Totem",				-- [11]				
				--["Спутник"]			= "Non-combat Pet",		-- [12]	
				--["Облако газа"]		= "Gas Cloud",			-- [13]
				--["Дикий питомец"]		= "Wild Pet",			-- [14]
				--["Аберрация"]			= "Aberration",			-- [15]
			},
			frFR				= {
				["Bête"]				= "Beast",				-- [1]
				["Draconien"]			= "Dragonkin",			-- [2]
				["Démon"]				= "Demon",				-- [3]
				["Élémentaire"]			= "Elemental",			-- [4]
				["Géant"]				= "Giant",				-- [5]
				["Mort-vivant"]			= "Undead",				-- [6]				
				["Humanoïde"]			= "Humanoid",			-- [7]
				["Bestiole"]			= "Critter",			-- [8]
				["Mécanique"]			= "Mechanical",			-- [9] -- Classic
				["Machine"]				= "Mechanical",			-- [9] -- Retail
				["Non spécifié"]		= "Not specified",		-- [10]				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["Totem"]				= "Totem",				-- [11]				
				--["Mascotte pacifique"]	= "Non-combat Pet",	-- [12]	
				--["Nuage de gaz"]		= "Gas Cloud",			-- [13]
				--["Mascotte sauvage"]	= "Wild Pet",			-- [14]
				--["Aberration"]		= "Aberration",			-- [15]
			},
			deDE				= {
				["Wildtier"]			= "Beast",				-- [1]
				["Drachkin"]			= "Dragonkin",			-- [2]
				["Dämon"]				= "Demon",				-- [3]
				["Elementar"]			= "Elemental",			-- [4]
				["Riese"]				= "Giant",				-- [5]
				["Untoter"]				= "Undead",				-- [6]				
				["Humanoid"]			= "Humanoid",			-- [7]
				["Tier"]				= "Critter",			-- [8] -- Classic 
				["Kleintier"]			= "Critter",			-- [8] -- Retail
				["Mechanisch"]			= "Mechanical",			-- [9]
				["Nicht spezifiziert"]	= "Not specified",		-- [10]				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["Totem"]				= "Totem",				-- [11]				
				--["Haustier"]			= "Non-combat Pet",		-- [12]	
				--["Gaswolke"]			= "Gas Cloud",			-- [13]
				--["Ungezähmtes Tier"]	= "Wild Pet",			-- [14]
				--["Entartung"]			= "Aberration",			-- [15]
			},
			esES				= {
				["Bestia"]				= "Beast",				-- [1]
				["Dragonante"]			= "Dragonkin",			-- [2]
				["Demonio"]				= "Demon",				-- [3]
				["Elemental"]			= "Elemental",			-- [4]
				["Gigante"]				= "Giant",				-- [5]
				["No-muerto"]			= "Undead",				-- [6]				
				["Humanoide"]			= "Humanoid",			-- [7]
				["Alimaña"]				= "Critter",			-- [8]
				["Mecánico"]			= "Mechanical",			-- [9]
				["Sin especificar"]		= "Not specified",		-- [10]				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["Tótem"]				= "Totem",				-- [11]				
				--["Mascota mansa"]		= "Non-combat Pet",		-- [12]	
				--["Nube de gas"]		= "Gas Cloud",			-- [13]
				--["Mascota salvaje"]	= "Wild Pet",			-- [14]
				--["Aberración"]		= "Aberration",			-- [15]
			},
			ptPT				= {
				["Fera"]				= "Beast",				-- [1]
				["Draconiano"]			= "Dragonkin",			-- [2]
				["Demônio"]				= "Demon",				-- [3]
				["Elemental"]			= "Elemental",			-- [4]
				["Gigante"]				= "Giant",				-- [5]
				["Morto-vivo"]			= "Undead",				-- [6]				
				["Humanoide"]			= "Humanoid",			-- [7]
				["Bicho"]				= "Critter",			-- [8]
				["Mecânico"]			= "Mechanical",			-- [9]
				["Não Especificado"]	= "Not specified",		-- [10]				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["Totem"]				= "Totem",				-- [11]				
				--["Mascote"]			= "Non-combat Pet",		-- [12]	
				--["Nuvem de Gás"]		= "Gas Cloud",			-- [13]
				--["Mascote Selvagem"]	= "Wild Pet",			-- [14]
				--["Aberração"]			= "Aberration",			-- [15]
			},			
			itIT				= {
				-- Classic hasn't Italy language but dataBase refferenced their locales to koKR
				["Bestia"]				= "Beast",				-- [1]
				["야수"]					= "Beast",				-- [1] Refference
				["Dragoide"]			= "Dragonkin",			-- [2]
				["용족"]					= "Dragonkin",			-- [2] Refference
				["Demone"]				= "Demon",				-- [3]
				["악마"]					= "Demon",				-- [3] Refference
				["Elementale"]			= "Elemental",			-- [4]
				["정령"]					= "Elemental",			-- [4] Refference
				["Gigante"]				= "Giant",				-- [5]
				["거인"]					= "Giant",				-- [5] Refference
				["Non Morto"]			= "Undead",				-- [6]				
				["언데드"]					= "Undead",				-- [6] Refference			
				["Umanoide"]			= "Humanoid",			-- [7]
				["인간형"]					= "Humanoid",			-- [7] Refference
				["Animale"]				= "Critter",			-- [8]
				["동물"]					= "Critter",			-- [8] Refference
				["Unità Meccanica"]		= "Mechanical",			-- [9]
				["기계"]					= "Mechanical",			-- [9] Refference
				["Non Specificato"]		= "Not specified",		-- [10]				
				["기타"]					= "Not specified",		-- [10] Refference				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["Totem"]				= "Totem",				-- [11]				
				["토템"]					= "Totem",				-- [11]	Refference			
				--["Mascotte"]			= "Non-combat Pet",		-- [12]	
				--["Nuvola di Gas"]		= "Gas Cloud",			-- [13]
				--["Mascotte Selvatica"]	= "Wild Pet",		-- [14]
				--["Aberrazione"]			= "Aberration",		-- [15]
			},
			koKR				= {
				["야수"]					= "Beast",				-- [1] 
				["용족"]					= "Dragonkin",			-- [2]
				["악마"]					= "Demon",				-- [3]
				["정령"]					= "Elemental",			-- [4]
				["거인"]					= "Giant",				-- [5]
				["언데드"]					= "Undead",				-- [6]				
				["인간형"]					= "Humanoid",			-- [7]
				["동물"]					= "Critter",			-- [8]
				["기계"]					= "Mechanical",			-- [9]
				["기타"]					= "Not specified",		-- [10]				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["토템"]					= "Totem",				-- [11]				
				--["애완동물"]				= "Non-combat Pet",		-- [12]	
				--["가스 구름"]				= "Gas Cloud",			-- [13]
				--["야생 애완동물"]			= "Wild Pet",			-- [14]
				--["돌연변이"]				= "Aberration",			-- [15]
			},
			zhCN				= {
				["野兽"]				= "Beast",				-- [1]
				["龙类"]					= "Dragonkin",			-- [2]
				["恶魔"]				= "Demon",				-- [3]
				["元素生物"]				= "Elemental",			-- [4]
				["巨人"]				= "Giant",				-- [5]
				["亡灵"]				= "Undead",				-- [6]				
				["人型生物"]				= "Humanoid",			-- [7]
				["小动物"]				= "Critter",			-- [8]
				["机械"]				= "Mechanical",			-- [9]
				["未指定"]				= "Not specified",		-- [10]				
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["图腾"]				= "Totem",				-- [11]				
				--["非战斗宠物"]			= "Non-combat Pet",		-- [12]	
				--["气体云雾"]			= "Gas Cloud",			-- [13]
				--["野生宠物"]			= "Wild Pet",			-- [14]
				--["畸变怪"]				= "Aberration",			-- [15]
			},
			zhTW				= {
				["野獸"]				= "Beast",				-- [1]
				["龍類"]				= "Dragonkin",			-- [2]
				["惡魔"]				= "Demon",				-- [3]
				["元素生物"]				= "Elemental",			-- [4]
				["巨人"]				= "Giant",				-- [5]
				["不死族"]				= "Undead",				-- [6]		
				["人型生物"]				= "Humanoid",			-- [7] Classic 
				["人形生物"]				= "Humanoid",			-- [7] Retail 
				["小動物"]				= "Critter",			-- [8]
				["機械"]				= "Mechanical",			-- [9]
				["未指定"]				= "Not specified",		-- [10] Classic
				["不明"]				= "Not specified",		-- [10] Retail
				[""]					= "Not specified",		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
				["圖騰"]				= "Totem",				-- [11]			
				--["非戰鬥寵物"]			= "Non-combat Pet",		-- [12]	
				--["氣體雲"]				= "Gas Cloud",			-- [13]
				--["野生寵物"]			= "Wild Pet",			-- [14]
				--["變異怪"]				= "Aberration",			-- [15]
			},
		}, 
		{
			__index = function(t, v)
				return t[GameLocale][v]
			end,
		}
	),
	CreatureFamily				= setmetatable(
		-- Formats localization to English locale
		-- Revision BFA 8.3.0.33941 April 2020
		{
			enUS				= {
				["Wolf"]					= "Wolf",					-- [1]
				["Cat"]						= "Cat",					-- [2]
				["Spider"]					= "Spider",					-- [3]
				["Bear"]					= "Bear",					-- [4]
				["Boar"]					= "Boar",					-- [5]
				["Crocolisk"]				= "Crocolisk",				-- [6]
				["Carrion Bird"]			= "Carrion Bird",			-- [7]
				["Crab"]					= "Crab",					-- [8]
				["Gorilla"]					= "Gorilla",				-- [9]
				["Raptor"]					= "Raptor",					-- [11]
				["Tallstrider"]				= "Tallstrider",			-- [12]
				["Felhunter"]				= "Felhunter",				-- [15]
				["Voidwalker"]				= "Voidwalker",				-- [16]
				["Succubus"]				= "Succubus",				-- [17]
				["Doomguard"]				= "Doomguard",				-- [19]
				["Scorpid"]					= "Scorpid",				-- [20]
				["Turtle"]					= "Turtle",					-- [21]
				["Imp"]						= "Imp",					-- [23]
				["Bat"]						= "Bat",					-- [24]
				["Hyena"]					= "Hyena",					-- [25]
				["Owl"]						= "Owl",					-- [26] Classic 
				["Bird of Prey"]			= "Bird of Prey",			-- [26] Retail 
				["Wind Serpent"]			= "Wind Serpent",			-- [27]
				["Remote Control"]			= "Remote Control",			-- [28]
				--["Felguard"]				= "Felguard",				-- [29]
				--["Dragonhawk"]				= "Dragonhawk",				-- [30]
				--["Ravager"]					= "Ravager",				-- [31]
				--["Warp Stalker"]			= "Warp Stalker",			-- [32]
				--["Sporebat"]				= "Sporebat",				-- [33]
				--["Ray"]						= "Ray",					-- [34]
				--["Serpent"]					= "Serpent",				-- [35]
				--["Moth"]					= "Moth",					-- [37]
				--["Chimaera"]				= "Chimaera",				-- [38]
				--["Devilsaur"]				= "Devilsaur",				-- [39]
				--["Ghoul"]					= "Ghoul",					-- [40]
				--["Silithid"]				= "Silithid",				-- [41]
				--["Worm"]					= "Worm",					-- [42]
				--["Clefthoof"]				= "Clefthoof",				-- [43]
				--["Wasp"]					= "Wasp",					-- [44]
				--["Core Hound"]				= "Core Hound",				-- [45]
				--["Spirit Beast"]			= "Spirit Beast",			-- [46]
				--["Water Elemental"]			= "Water Elemental",		-- [49]
				--["Fox"]						= "Fox",					-- [50]
				--["Monkey"]					= "Monkey",					-- [51]
				--["Dog"]						= "Dog",					-- [52]
				--["Beetle"]					= "Beetle",					-- [53]
				--["Shale Spider"]			= "Shale Spider",			-- [55]
				--["Zombie"]					= "Zombie",					-- [56]
				--["<< QA TEST FAMILY >>"]	= "<< QA TEST FAMILY >>",	-- [57]
				--["Hydra"]					= "Hydra",					-- [68]
				--["Fel Imp"]					= "Fel Imp",				-- [100]
				--["Voidlord"]				= "Voidlord",				-- [101]
				--["Shivarra"]				= "Shivarra",				-- [102]
				--["Observer"]				= "Observer",				-- [103]
				--["Wrathguard"]				= "Wrathguard",				-- [104]
				--["Infernal"]				= "Infernal",				-- [108]
				--["Fire Elemental"]			= "Fire Elemental",			-- [116]
				--["Earth Elemental"]			= "Earth Elemental",		-- [117]
				--["Crane"]					= "Crane",					-- [125]
				--["Water Strider"]			= "Water Strider",			-- [126]
				--["Rodent"]					= "Rodent",					-- [127]
				--["Quilen"]					= "Quilen",					-- [128]
				--["Goat"]					= "Goat",					-- [129]
				--["Basilisk"]				= "Basilisk",				-- [130]
				--["Direhorn"]				= "Direhorn",				-- [138]
				--["Storm Elemental"]			= "Storm Elemental",		-- [145]
				--["Terrorguard"]				= "Terrorguard",			-- [147]
				--["Abyssal"]					= "Abyssal",				-- [148]
				--["Riverbeast"]				= "Riverbeast",				-- [150]
				--["Stag"]					= "Stag",					-- [151]
				--["Mechanical"]				= "Mechanical",				-- [154]
				--["Abomination"]				= "Abomination",			-- [155]
				--["Scalehide"]				= "Scalehide",				-- [156]
				--["Oxen"]					= "Oxen",					-- [157]
				--["Feathermane"]				= "Feathermane",			-- [160]
				--["Lizard"]					= "Lizard",					-- [288]
				--["Pterrordax"]				= "Pterrordax",				-- [290]
				--["Toad"]					= "Toad",					-- [291]
				--["Krolusk"]					= "Krolusk",				-- [292]
				--["Blood Beast"]				= "Blood Beast",			-- [296]
			},
			ruRU				= {
				["Волк"]					= "Wolf",					-- [1]
				["Кошка"]					= "Cat",					-- [2]
				["Паук"]					= "Spider",					-- [3]
				["Медведь"]					= "Bear",					-- [4]
				["Вепрь"]					= "Boar",					-- [5]
				["Кроколиск"]				= "Crocolisk",				-- [6]
				["Падальщик"]				= "Carrion Bird",			-- [7]
				["Краб"]					= "Crab",					-- [8]
				["Горилла"]					= "Gorilla",				-- [9]
				["Ящер"]					= "Raptor",					-- [11]
				["Долгоног"]				= "Tallstrider",			-- [12]
				["Охотник Скверны"]			= "Felhunter",				-- [15]
				["Демон Бездны"]			= "Voidwalker",				-- [16]
				["Суккуб"]					= "Succubus",				-- [17]
				["Страж ужаса"]				= "Doomguard",				-- [19]
				["Скорпид"]					= "Scorpid",				-- [20]
				["Черепаха"]				= "Turtle",					-- [21]
				["Бес"]						= "Imp",					-- [23]
				["Летучая мышь"]			= "Bat",					-- [24]
				["Гиена"]					= "Hyena",					-- [25]
				["Сова"]					= "Owl",					-- [26] Classic 
				["Хищная птица"]			= "Bird of Prey",			-- [26] Retail
				["Крылатый змей"]			= "Wind Serpent",			-- [27]
				["Управление"]				= "Remote Control",			-- [28]
				--["Страж Скверны"]			= "Felguard",				-- [29]
				--["Дракондор"]				= "Dragonhawk",				-- [30]
				--["Опустошитель"]			= "Ravager",				-- [31]
				--["Прыгуана"]				= "Warp Stalker",			-- [32]
				--["Спороскат"]				= "Sporebat",				-- [33]
				--["Скат"]					= "Ray",					-- [34]
				--["Змей"]					= "Serpent",				-- [35]
				--["Мотылек"]					= "Moth",					-- [37]
				--["Химера"]					= "Chimaera",				-- [38]
				--["Дьявозавр"]				= "Devilsaur",				-- [39]
				--["Вурдалак"]				= "Ghoul",					-- [40]
				--["Силитид"]					= "Silithid",				-- [41]
				--["Червь"]					= "Worm",					-- [42]
				--["Копытень"]				= "Clefthoof",				-- [43]
				--["Оса"]						= "Wasp",					-- [44]
				--["Гончая недр"]				= "Core Hound",				-- [45]
				--["Дух зверя"]				= "Spirit Beast",			-- [46]
				--["Элементаль воды"]			= "Water Elemental",		-- [49]
				--["Лисица"]					= "Fox",					-- [50]
				--["Обезьяна"]				= "Monkey",					-- [51]
				--["Собака"]					= "Dog",					-- [52]
				--["Жук"]						= "Beetle",					-- [53]
				--["Сланцевый паук"]			= "Shale Spider",			-- [55]
				--["Зомби"]					= "Zombie",					-- [56]
				--["<< QA TEST FAMILY >>"]	= "<< QA TEST FAMILY >>",	-- [57]
				--["Гидра"]					= "Hydra",					-- [68]
				--["Бес Скверны"]				= "Fel Imp",				-- [100]
				--["Повелитель Бездны"]		= "Voidlord",				-- [101]
				--["Шиварра"]					= "Shivarra",				-- [102]
				--["Наблюдатель"]				= "Observer",				-- [103]
				--["Страж гнева"]				= "Wrathguard",				-- [104]
				--["Инфернал"]				= "Infernal",				-- [108]
				--["Элементаль огня"]			= "Fire Elemental",			-- [116]
				--["Элементаль земли"]		= "Earth Elemental",		-- [117]
				--["Журавль"]					= "Crane",					-- [125]
				--["Водный долгоног"]			= "Water Strider",			-- [126]
				--["Грызун"]					= "Rodent",					-- [127]
				--["Цийлинь"]					= "Quilen",					-- [128]
				--["Козел"]					= "Goat",					-- [129]
				--["Василиск"]				= "Basilisk",				-- [130]
				--["Дикорог"]					= "Direhorn",				-- [138]
				--["Элементаль бури"]			= "Storm Elemental",		-- [145]
				--["Стражник жути"]			= "Terrorguard",			-- [147]
				--["Абиссал"]					= "Abyssal",				-- [148]
				--["Речное чудище"]			= "Riverbeast",				-- [150]
				--["Олень"]					= "Stag",					-- [151]
				--["Механизм"]				= "Mechanical",				-- [154]
				--["Поганище"]				= "Abomination",			-- [155]
				--["Чешуешкурые"]				= "Scalehide",				-- [156]
				--["Быки"]					= "Oxen",					-- [157]
				--["Шерстоперые"]				= "Feathermane",			-- [160]
				--["Ящерица"]					= "Lizard",					-- [288]
				--["Терродактиль"]			= "Pterrordax",				-- [290]
				--["Жаба"]					= "Toad",					-- [291]
				--["Кролуск"]					= "Krolusk",				-- [292]
				--["Кровавое чудовище"]		= "Blood Beast",			-- [296]
			},
			frFR				= {
				["Loup"]					= "Wolf",					-- [1]
				["Félin"]					= "Cat",					-- [2]
				["Araignée"]				= "Spider",					-- [3]
				["Ours"]					= "Bear",					-- [4]
				["Sanglier"]				= "Boar",					-- [5]
				["Crocilisque"]				= "Crocolisk",				-- [6]
				["Charognard"]				= "Carrion Bird",			-- [7]
				["Crabe"]					= "Crab",					-- [8]
				["Gorille"]					= "Gorilla",				-- [9]
				["Raptor"]					= "Raptor",					-- [11]
				["Haut-trotteur"]			= "Tallstrider",			-- [12]
				["Chasseur corrompu"]		= "Felhunter",				-- [15]
				["Marcheur du Vide"]		= "Voidwalker",				-- [16]
				["Succube"]					= "Succubus",				-- [17]
				["Garde funeste"]			= "Doomguard",				-- [19]
				["Scorpide"]				= "Scorpid",				-- [20]
				["Tortue"]					= "Turtle",					-- [21]
				["Diablotin"]				= "Imp",					-- [23]
				["Chauve-souris"]			= "Bat",					-- [24]
				["Hyène"]					= "Hyena",					-- [25]
				["Chouette"]				= "Owl",					-- [26] Classic 
				["Oiseau de proie"]			= "Bird of Prey",			-- [26] Retail 
				["Serpent des vents"]		= "Wind Serpent",			-- [27]
				["Télécommande"]			= "Remote Control",			-- [28]
				--["Gangregarde"]				= "Felguard",				-- [29]
				--["Faucon-dragon"]			= "Dragonhawk",				-- [30]
				--["Ravageur"]				= "Ravager",				-- [31]
				--["Traqueur dim."]			= "Warp Stalker",			-- [32]
				--["Sporoptère"]				= "Sporebat",				-- [33]
				--["Raie"]					= "Ray",					-- [34]
				--["Serpent"]					= "Serpent",				-- [35]
				--["Phalène"]					= "Moth",					-- [37]
				--["Chimère"]					= "Chimaera",				-- [38]
				--["Diablosaure"]				= "Devilsaur",				-- [39]
				--["Goule"]					= "Ghoul",					-- [40]
				--["Silithide"]				= "Silithid",				-- [41]
				--["Ver"]						= "Worm",					-- [42]
				--["Sabot-fourchu"]			= "Clefthoof",				-- [43]
				--["Guêpe"]					= "Wasp",					-- [44]
				--["Chien du magma"]			= "Core Hound",				-- [45]
				--["Esprit de bête"]			= "Spirit Beast",			-- [46]
				--["Élémentaire d'eau"]		= "Water Elemental",		-- [49]
				--["Renard"]					= "Fox",					-- [50]
				--["Singe"]					= "Monkey",					-- [51]
				--["Chien"]					= "Dog",					-- [52]
				--["Hanneton"]				= "Beetle",					-- [53]
				--["Araignée de schiste"]		= "Shale Spider",			-- [55]
				--["Zombie"]					= "Zombie",					-- [56]
				--["<< QA TEST FAMILY >>"]	= "<< QA TEST FAMILY >>",	-- [57]
				--["Hydre"]					= "Hydra",					-- [68]
				--["Diablotin gangrené"]		= "Fel Imp",				-- [100]
				--["Seigneur du Vide"]		= "Voidlord",				-- [101]
				--["Shivarra"]				= "Shivarra",				-- [102]
				--["Observateur"]				= "Observer",				-- [103]
				--["Garde-courroux"]			= "Wrathguard",				-- [104]
				--["Infernal"]				= "Infernal",				-- [108]
				--["Élémentaire de feu"]		= "Fire Elemental",			-- [116]
				--["Élémentaire de terre"]	= "Earth Elemental",		-- [117]
				--["Grue"]					= "Crane",					-- [125]
				--["Trotteur aquatique"]		= "Water Strider",			-- [126]
				--["Rongeur"]					= "Rodent",					-- [127]
				--["Quilen"]					= "Quilen",					-- [128]
				--["Chèvre"]					= "Goat",					-- [129]
				--["Basilic"]					= "Basilisk",				-- [130]
				--["Navrecorne"]				= "Direhorn",				-- [138]
				--["Élém. de tempête"]		= "Storm Elemental",		-- [145]
				--["Garde de terreur"]		= "Terrorguard",			-- [147]
				--["Abyssal"]					= "Abyssal",				-- [148]
				--["Potamodonte"]				= "Riverbeast",				-- [150]
				--["Cerf"]					= "Stag",					-- [151]
				--["Mécanique"]				= "Mechanical",				-- [154]
				--["Abomination"]				= "Abomination",			-- [155]
				--["Peau écailleuse"]			= "Scalehide",				-- [156]
				--["Bovin"]					= "Oxen",					-- [157]
				--["Crin-de-plume"]			= "Feathermane",			-- [160]
				--["Lézard"]					= "Lizard",					-- [288]
				--["Pterreurdactyle"]			= "Pterrordax",				-- [290]
				--["Crapaud"]					= "Toad",					-- [291]
				--["Krolusk"]					= "Krolusk",				-- [292]
				--["Bête de sang"]			= "Blood Beast",			-- [296]
			},
			deDE				= {
				["Wolf"]					= "Wolf",					-- [1]
				["Katze"]					= "Cat",					-- [2]
				["Spinne"]					= "Spider",					-- [3]
				["Bär"]						= "Bear",					-- [4]
				["Eber"]					= "Boar",					-- [5]
				["Krokilisk"]				= "Crocolisk",				-- [6]
				["Aasvogel"]				= "Carrion Bird",			-- [7]
				["Krebs"]					= "Crab",					-- [8]
				["Gorilla"]					= "Gorilla",				-- [9]
				["Raptor"]					= "Raptor",					-- [11]
				["Weitschreiter"]			= "Tallstrider",			-- [12]
				["Teufelsjäger"]			= "Felhunter",				-- [15]
				["Leerwandler"]				= "Voidwalker",				-- [16]
				["Sukkubus"]				= "Succubus",				-- [17]
				["Verdammniswache"]			= "Doomguard",				-- [19]
				["Skorpid"]					= "Scorpid",				-- [20]
				["Schildkröte"]				= "Turtle",					-- [21]
				["Wichtel"]					= "Imp",					-- [23]
				["Fledermaus"]				= "Bat",					-- [24]
				["Hyäne"]					= "Hyena",					-- [25]
				["Eule"]					= "Owl",					-- [26] Classic 
				["Raubvogel"]				= "Bird of Prey",			-- [26] Retail
				["Windnatter"]				= "Wind Serpent",			-- [27]
				["Ferngesteuert"]			= "Remote Control",			-- [28]
				--["Teufelswache"]			= "Felguard",				-- [29]
				--["Drachenfalke"]			= "Dragonhawk",				-- [30]
				--["Felshetzer"]				= "Ravager",				-- [31]
				--["Sphärenjäger"]			= "Warp Stalker",			-- [32]
				--["Sporensegler"]			= "Sporebat",				-- [33]
				--["Rochen"]					= "Ray",					-- [34]
				--["Schlange"]				= "Serpent",				-- [35]
				--["Motte"]					= "Moth",					-- [37]
				--["Schimäre"]				= "Chimaera",				-- [38]
				--["Teufelssaurier"]			= "Devilsaur",				-- [39]
				--["Ghul"]					= "Ghoul",					-- [40]
				--["Silithid"]				= "Silithid",				-- [41]
				--["Wurm"]					= "Worm",					-- [42]
				--["Grollhuf"]				= "Clefthoof",				-- [43]
				--["Wespe"]					= "Wasp",					-- [44]
				--["Kernhund"]				= "Core Hound",				-- [45]
				--["Geisterbestie"]			= "Spirit Beast",			-- [46]
				--["Wasserelementar"]			= "Water Elemental",		-- [49]
				--["Fuchs"]					= "Fox",					-- [50]
				--["Affe"]					= "Monkey",					-- [51]
				--["Hund"]					= "Dog",					-- [52]
				--["Käfer"]					= "Beetle",					-- [53]
				--["Schieferspinne"]			= "Shale Spider",			-- [55]
				--["Zombie"]					= "Zombie",					-- [56]
				--["<< QA TEST FAMILY >>"]	= "<< QA TEST FAMILY >>",	-- [57]
				--["Hydra"]					= "Hydra",					-- [68]
				--["Teufelswichtel"]			= "Fel Imp",				-- [100]
				--["Leerenfürst"]				= "Voidlord",				-- [101]
				--["Shivarra"]				= "Shivarra",				-- [102]
				--["Beobachter"]				= "Observer",				-- [103]
				--["Zornwächter"]				= "Wrathguard",				-- [104]
				--["Höllenbestie"]			= "Infernal",				-- [108]
				--["Feuerelementar"]			= "Fire Elemental",			-- [116]
				--["Erdelementar"]			= "Earth Elemental",		-- [117]
				--["Kranich"]					= "Crane",					-- [125]
				--["Wasserschreiter"]			= "Water Strider",			-- [126]
				--["Nager"]					= "Rodent",					-- [127]
				--["Qilen"]					= "Quilen",					-- [128]
				--["Ziege"]					= "Goat",					-- [129]
				--["Basilisk"]				= "Basilisk",				-- [130]
				--["Terrorhorn"]				= "Direhorn",				-- [138]
				--["Sturmelementar"]			= "Storm Elemental",		-- [145]
				--["Terrorwache"]				= "Terrorguard",			-- [147]
				--["Abyssal"]					= "Abyssal",				-- [148]
				--["Flussbestie"]				= "Riverbeast",				-- [150]
				--["Hirsch"]					= "Stag",					-- [151]
				--["Mechanisch"]				= "Mechanical",				-- [154]
				--["Monstrosität"]			= "Abomination",			-- [155]
				--["Schuppenbalg"]			= "Scalehide",				-- [156]
				--["Ochse"]					= "Oxen",					-- [157]
				--["Federmähnen"]				= "Feathermane",			-- [160]
				--["Echse"]					= "Lizard",					-- [288]
				--["Pterrordax"]				= "Pterrordax",				-- [290]
				--["Kröte"]					= "Toad",					-- [291]
				--["Krolusk"]					= "Krolusk",				-- [292]
				--["Blutbestie"]				= "Blood Beast",			-- [296]
			},
			esES				= {
				["Lobo"]					= "Wolf",					-- [1]
				["Felino"]					= "Cat",					-- [2]
				["Araña"]					= "Spider",					-- [3]
				["Oso"]						= "Bear",					-- [4]
				["Jabalí"]					= "Boar",					-- [5]
				["Crocolisco"]				= "Crocolisk",				-- [6]
				["Carroñero"]				= "Carrion Bird",			-- [7]
				["Cangrejo"]				= "Crab",					-- [8]
				["Gorila"]					= "Gorilla",				-- [9]
				["Raptor"]					= "Raptor",					-- [11]
				["Zancudo"]					= "Tallstrider",			-- [12] Spain Classic 
				["Zancaalta"]				= "Tallstrider",			-- [12] Spain Retail / Mexico Classic
				["Manáfago"]				= "Felhunter",				-- [15]
				["Abisario"]				= "Voidwalker",				-- [16]
				["Súcubo"]					= "Succubus",				-- [17]
				["Guardia maldito"]			= "Doomguard",				-- [19] Spain Classic
				["Guardia apocalíptico"]	= "Doomguard",				-- [19] Spain Retail / Mexico Classic
				["Escórpido"]				= "Scorpid",				-- [20]
				["Tortuga"]					= "Turtle",					-- [21]
				["Diablillo"]				= "Imp",					-- [23]
				["Murciélago"]				= "Bat",					-- [24]
				["Hiena"]					= "Hyena",					-- [25]
				["Búho"]					= "Owl",					-- [26] Classic 
				["Ave rapaz"]				= "Bird of Prey",			-- [26] Retail
				["Dragón alado"]			= "Wind Serpent",			-- [27] Spain 
				["Serpiente alada"]			= "Wind Serpent",			-- [27] Mexico 
				["Control remoto"]			= "Remote Control",			-- [28]
				--["Guardia vil"]				= "Felguard",				-- [29]
				--["Dracohalcón"]				= "Dragonhawk",				-- [30]
				--["Devastador"]				= "Ravager",				-- [31]
				--["Acechador deformado"]		= "Warp Stalker",			-- [32]
				--["Esporiélago"]				= "Sporebat",				-- [33]
				--["Raya"]					= "Ray",					-- [34] Spain
				--["Mantarraya"]				= "Ray",					-- [34] Mexico
				--["Serpiente"]				= "Serpent",				-- [35]
				--["Palomilla"]				= "Moth",					-- [37]
				--["Quimera"]					= "Chimaera",				-- [38]
				--["Demosaurio"]				= "Devilsaur",				-- [39]
				--["Necrófago"]				= "Ghoul",					-- [40]
				--["Silítido"]				= "Silithid",				-- [41]
				--["Gusano"]					= "Worm",					-- [42]
				--["Uñagrieta"]				= "Clefthoof",				-- [43]
				--["Avispa"]					= "Wasp",					-- [44]
				--["Can del Núcleo"]			= "Core Hound",				-- [45]
				--["Bestia espíritu"]			= "Spirit Beast",			-- [46]
				--["Elemental de agua"]		= "Water Elemental",		-- [49]
				--["Zorro"]					= "Fox",					-- [50]
				--["Mono"]					= "Monkey",					-- [51]
				--["Perro"]					= "Dog",					-- [52]
				--["Alfazaque"]				= "Beetle",					-- [53]
				--["Araña de esquisto"]		= "Shale Spider",			-- [55]
				--["Zombi"]					= "Zombie",					-- [56]
				--["<< QA TEST FAMILY >>"]	= "<< QA TEST FAMILY >>",	-- [57]
				--["Hidra"]					= "Hydra",					-- [68]
				--["Diablillo vil"]			= "Fel Imp",				-- [100]
				--["Señor del Vacío"]			= "Voidlord",				-- [101]
				--["Shivarra"]				= "Shivarra",				-- [102]
				--["Observador"]				= "Observer",				-- [103]
				--["Guardia de cólera"]		= "Wrathguard",				-- [104]
				--["Infernal"]				= "Infernal",				-- [108]
				--["Elemental de fuego"]		= "Fire Elemental",			-- [116]
				--["Elemental de tierra"]		= "Earth Elemental",		-- [117]
				--["Grulla"]					= "Crane",					-- [125]
				--["Zancudo acuático"]		= "Water Strider",			-- [126]
				--["Roedor"]					= "Rodent",					-- [127]
				--["Quilen"]					= "Quilen",					-- [128]
				--["Cabra"]					= "Goat",					-- [129]
				--["Basilisco"]				= "Basilisk",				-- [130]
				--["Cuernoatroz"]				= "Direhorn",				-- [138]
				--["Elem. de tormenta"]		= "Storm Elemental",		-- [145] Spain
				--["Elemental tormenta"]		= "Storm Elemental",		-- [145] Mexico 
				--["Guarda terrorífico"]		= "Terrorguard",			-- [147]
				--["Abisal"]					= "Abyssal",				-- [148]
				--["Bestia fluvial"]			= "Riverbeast",				-- [150] Spain 
				--["Bestia del río"]			= "Riverbeast",				-- [150] Mexico
				--["Venado"]					= "Stag",					-- [151]
				--["Máquina"]					= "Mechanical",				-- [154] Spain 
				--["Mecánico"]				= "Mechanical",				-- [154] Mexico
				--["Abominación"]				= "Abomination",			-- [155]
				--["Pielescama"]				= "Scalehide",				-- [156]
				--["Buey"]					= "Oxen",					-- [157]
				--["Cuellipluma"]				= "Feathermane",			-- [160] Spain 
				--["Crinpluma"]				= "Feathermane",			-- [160] Mexico
				--["Lagarto"]					= "Lizard",					-- [288]
				--["Pterrordáctilo"]			= "Pterrordax",				-- [290]
				--["Sapo"]					= "Toad",					-- [291]
				--["Crolusco"]				= "Krolusk",				-- [292] Spain 
				--["Krolusko"]				= "Krolusk",				-- [292] Maxico
				--["Bestia de sangre"]		= "Blood Beast",			-- [296]
			},
			ptPT				= {
				["Lobo"]					= "Wolf",					-- [1]
				["Gato"]					= "Cat",					-- [2]
				["Aranha"]					= "Spider",					-- [3]
				["Urso"]					= "Bear",					-- [4]
				["Javali"]					= "Boar",					-- [5]
				["Crocolisco"]				= "Crocolisk",				-- [6]
				["Ave Carniceira"]			= "Carrion Bird",			-- [7]
				["Caranguejo"]				= "Crab",					-- [8]
				["Gorila"]					= "Gorilla",				-- [9]
				["Raptor"]					= "Raptor",					-- [11]
				["Moa"]						= "Tallstrider",			-- [12]
				["Caçador Vil"]				= "Felhunter",				-- [15]
				["Emissário do Caos"]		= "Voidwalker",				-- [16]
				["Súcubo"]					= "Succubus",				-- [17]
				["Demonarca"]				= "Doomguard",				-- [19]
				["Escorpídeo"]				= "Scorpid",				-- [20]
				["Tartaruga"]				= "Turtle",					-- [21]
				["Diabrete"]				= "Imp",					-- [23]
				["Morcego"]					= "Bat",					-- [24]
				["Hiena"]					= "Hyena",					-- [25]
				["Coruja"]					= "Owl",					-- [26] Classic 
				["Ave de Rapina"]			= "Bird of Prey",			-- [26] Retail
				["Serpente Alada"]			= "Wind Serpent",			-- [27]
				["Controle Remoto"]			= "Remote Control",			-- [28]
				--["Guarda Vil"]				= "Felguard",				-- [29]
				--["Falcodrago"]				= "Dragonhawk",				-- [30]
				--["Assolador"]				= "Ravager",				-- [31]
				--["Espreitador Dimens."]		= "Warp Stalker",			-- [32]
				--["Quirósporo"]				= "Sporebat",				-- [33]
				--["Arraia"]					= "Ray",					-- [34]
				--["Serpente"]				= "Serpent",				-- [35]
				--["Mariposa"]				= "Moth",					-- [37]
				--["Quimera"]					= "Chimaera",				-- [38]
				--["Demossauro"]				= "Devilsaur",				-- [39]
				--["Carniçal"]				= "Ghoul",					-- [40]
				--["Silitídeo"]				= "Silithid",				-- [41]
				--["Verme"]					= "Worm",					-- [42]
				--["Fenoceronte"]				= "Clefthoof",				-- [43]
				--["Vespa"]					= "Wasp",					-- [44]
				--["Cão-magma"]				= "Core Hound",				-- [45]
				--["Fera Espiritual"]			= "Spirit Beast",			-- [46]
				--["Elemental da Água"]		= "Water Elemental",		-- [49]
				--["Raposa"]					= "Fox",					-- [50]
				--["Macaco"]					= "Monkey",					-- [51]
				--["Cachorro"]				= "Dog",					-- [52]
				--["Besouro"]					= "Beetle",					-- [53]
				--["Aranha Xistosa"]			= "Shale Spider",			-- [55]
				--["Zumbi"]					= "Zombie",					-- [56]
				--["Beetle <zzOLD>"]			= "<< QA TEST FAMILY >>",	-- [57]
				--["Hidra"]					= "Hydra",					-- [68]
				--["Diabrete Vil"]			= "Fel Imp",				-- [100]
				--["Senhor do Caos"]			= "Voidlord",				-- [101]
				--["Shivarra"]				= "Shivarra",				-- [102]
				--["Observador"]				= "Observer",				-- [103]
				--["Guardião Colérico"]		= "Wrathguard",				-- [104]
				--["Infernal"]				= "Infernal",				-- [108]
				--["Elemental do Fogo"]		= "Fire Elemental",			-- [116]
				--["Elemental da Terra"]		= "Earth Elemental",		-- [117]
				--["Garça"]					= "Crane",					-- [125]
				--["Caminhante das Águas"]	= "Water Strider",			-- [126]
				--["Roedor"]					= "Rodent",					-- [127]
				--["Quílen"]					= "Quilen",					-- [128]
				--["Bode"]					= "Goat",					-- [129]
				--["Basilisco"]				= "Basilisk",				-- [130]
				--["Escornante"]				= "Direhorn",				-- [138]
				--["Elemental Tempestade"]	= "Storm Elemental",		-- [145]
				--["Deimoguarda"]				= "Terrorguard",			-- [147]
				--["Abissal"]					= "Abyssal",				-- [148]
				--["Fera-do-rio"]				= "Riverbeast",				-- [150]
				--["Cervo"]					= "Stag",					-- [151]
				--["Mecânico"]				= "Mechanical",				-- [154]
				--["Abominação"]				= "Abomination",			-- [155]
				--["Courescama"]				= "Scalehide",				-- [156]
				--["Boi"]						= "Oxen",					-- [157]
				--["Aquifélix"]				= "Feathermane",			-- [160]
				--["Lagarto"]					= "Lizard",					-- [288]
				--["Pterrordax"]				= "Pterrordax",				-- [290]
				--["Sapo"]					= "Toad",					-- [291]
				--["Crolusco"]				= "Krolusk",				-- [292]
				--["Fera Sangrenta"]			= "Blood Beast",			-- [296]
			},			
			itIT				= {
				["Lupo"]					= "Wolf",					-- [1]
				["Felino"]					= "Cat",					-- [2]
				["Ragno"]					= "Spider",					-- [3]
				["Orso"]					= "Bear",					-- [4]
				["Cinghiale"]				= "Boar",					-- [5]
				["Crocolisco"]				= "Crocolisk",				-- [6]
				["Mangiacarogne"]			= "Carrion Bird",			-- [7]
				["Granchio"]				= "Crab",					-- [8]
				["Gorilla"]					= "Gorilla",				-- [9]
				["Raptor"]					= "Raptor",					-- [11]
				["Zampalunga"]				= "Tallstrider",			-- [12]
				["Vilsegugio"]				= "Felhunter",				-- [15]
				["Ombra del Vuoto"]			= "Voidwalker",				-- [16]
				["Succube"]					= "Succubus",				-- [17]
				["Demone Guardiano"]		= "Doomguard",				-- [19]
				["Scorpide"]				= "Scorpid",				-- [20]
				["Tartaruga"]				= "Turtle",					-- [21]
				["Imp"]						= "Imp",					-- [23]
				["Pipistrello"]				= "Bat",					-- [24]
				["Iena"]					= "Hyena",					-- [25]
				["Rapace"]					= "Bird of Prey",			-- [26]
				["Serpente Volante"]		= "Wind Serpent",			-- [27]
				["Controllo a Distanza"]	= "Remote Control",			-- [28]
				--["Vilguardia"]				= "Felguard",				-- [29]
				--["Dragofalco"]				= "Dragonhawk",				-- [30]
				--["Devastatore"]				= "Ravager",				-- [31]
				--["Segugio Distorcente"]		= "Warp Stalker",			-- [32]
				--["Sporofago"]				= "Sporebat",				-- [33]
				--["Pastinaca"]				= "Ray",					-- [34]
				--["Serpente"]				= "Serpent",				-- [35]
				--["Falena"]					= "Moth",					-- [37]
				--["Chimera"]					= "Chimaera",				-- [38]
				--["Gigantosauro"]			= "Devilsaur",				-- [39]
				--["Ghoul"]					= "Ghoul",					-- [40]
				--["Silitide"]				= "Silithid",				-- [41]
				--["Verme"]					= "Worm",					-- [42]
				--["Mammuceronte"]			= "Clefthoof",				-- [43]
				--["Vespa"]					= "Wasp",					-- [44]
				--["Segugio del Nucleo"]		= "Core Hound",				-- [45]
				--["Bestia Eterea"]			= "Spirit Beast",			-- [46]
				--["Elementale d'Acqua"]		= "Water Elemental",		-- [49]
				--["Volpe"]					= "Fox",					-- [50]
				--["Scimmia"]					= "Monkey",					-- [51]
				--["Cane"]					= "Dog",					-- [52]
				--["Scarabeo"]				= "Beetle",					-- [53]
				--["Ragno Roccioso"]			= "Shale Spider",			-- [55]
				--["Zombi"]					= "Zombie",					-- [56]
				--["<< QA TEST FAMILY >>"]	= "<< QA TEST FAMILY >>",	-- [57]
				--["Idra"]					= "Hydra",					-- [68]
				--["Vilimp"]					= "Fel Imp",				-- [100]
				--["Signore del Vuoto"]		= "Voidlord",				-- [101]
				--["Shivarra"]				= "Shivarra",				-- [102]
				--["Osservatore"]				= "Observer",				-- [103]
				--["Guardia dell'Ira"]		= "Wrathguard",				-- [104]
				--["Infernale"]				= "Infernal",				-- [108]
				--["Elementale del Fuoco"]	= "Fire Elemental",			-- [116]
				--["Elementale di Terra"]		= "Earth Elemental",		-- [117]
				--["Gru"]						= "Crane",					-- [125]
				--["Gerride"]					= "Water Strider",			-- [126]
				--["Roditore"]				= "Rodent",					-- [127]
				--["Quilen"]					= "Quilen",					-- [128]
				--["Caprone"]					= "Goat",					-- [129]
				--["Basilisco"]				= "Basilisk",				-- [130]
				--["Cornofurente"]			= "Direhorn",				-- [138]
				--["Elementale Tempesta"]		= "Storm Elemental",		-- [145]
				--["Guardia Maligna"]			= "Terrorguard",			-- [147]
				--["Abission"]				= "Abyssal",				-- [148]
				--["Bestia dei Fiumi"]		= "Riverbeast",				-- [150]
				--["Cervo"]					= "Stag",					-- [151]
				--["Unità Meccanica"]			= "Mechanical",				-- [154]
				--["Abominio"]				= "Abomination",			-- [155]
				--["Scagliamanto"]			= "Scalehide",				-- [156]
				--["Yak"]						= "Oxen",					-- [157]
				--["Piumanto"]				= "Feathermane",			-- [160]
				--["Lucertola"]				= "Lizard",					-- [288]
				--["Pterrordattilo"]			= "Pterrordax",				-- [290]
				--["Rospo"]					= "Toad",					-- [291]
				--["Krolusk"]					= "Krolusk",				-- [292]
				--["Bestia di Sangue"]		= "Blood Beast",			-- [296]
			},
			koKR				= {
				["늑대"]						= "Wolf",					-- [1] 
				["살쾡이"]						= "Cat",					-- [2] 
				["거미"]						= "Spider",					-- [3] 
				["곰"]						= "Bear",					-- [4] 
				["멧돼지"]						= "Boar",					-- [5] 
				["악어"]						= "Crocolisk",				-- [6] 
				["독수리"]						= "Carrion Bird",			-- [7] 
				["게"]						= "Crab",					-- [8] 
				["고릴라"]						= "Gorilla",				-- [9] 
				["랩터"]						= "Raptor",					-- [11] 
				["타조"]						= "Tallstrider",			-- [12] 
				["지옥사냥개"]					= "Felhunter",				-- [15] 
				["보이드워커"]					= "Voidwalker",				-- [16] Classic
				["공허방랑자"]					= "Voidwalker",				-- [16] Retail
				["서큐버스"]					= "Succubus",				-- [17] 
				["파멸의수호병"]					= "Doomguard",				-- [19] Classic 
				["파멸수호병"]					= "Doomguard",				-- [19] Retail 
				["전갈"]						= "Scorpid",				-- [20] 
				["거북"]						= "Turtle",					-- [21] 
				["임프"]						= "Imp",					-- [23] 
				["박쥐"]						= "Bat",					-- [24] 
				["하이에나"]					= "Hyena",					-- [25] 
				["올빼미"]						= "Owl",					-- [26] Classic 
				["맹금"]						= "Bird of Prey",			-- [26] Retail
				["천둥매"]						= "Wind Serpent",			-- [27] 
				["무선조종 장난감"]				= "Remote Control",			-- [28]
				--["지옥수호병"]					= "Felguard",				-- [29]
				--["용매"]						= "Dragonhawk",				-- [30]
				--["칼날발톱"]					= "Ravager",				-- [31]
				--["차원의 추적자"]				= "Warp Stalker",			-- [32]
				--["포자박쥐"]					= "Sporebat",				-- [33]
				--["가오리"]						= "Ray",					-- [34]
				--["뱀"]						= "Serpent",				-- [35]
				--["나방"]						= "Moth",					-- [37]
				--["키메라"]						= "Chimaera",				-- [38]
				--["데빌사우루스"]					= "Devilsaur",				-- [39]
				--["구울"]						= "Ghoul",					-- [40]
				--["실리시드"]					= "Silithid",				-- [41]
				--["벌레"]						= "Worm",					-- [42]
				--["갈래발굽"]					= "Clefthoof",				-- [43]
				--["말벌"]						= "Wasp",					-- [44]
				--["심장부 사냥개"]				= "Core Hound",				-- [45]
				--["야수 정령"]					= "Spirit Beast",			-- [46]
				--["물의 정령"]					= "Water Elemental",		-- [49]
				--["여우"]						= "Fox",					-- [50]
				--["원숭이"]						= "Monkey",					-- [51]
				--["개"]						= "Dog",					-- [52]
				--["딱정벌레"]					= "Beetle",					-- [53]
				--["혈암거미"]					= "Shale Spider",			-- [55]
				--["좀비"]						= "Zombie",					-- [56]
				--["<< QA 테스트용 >>"]			= "<< QA TEST FAMILY >>",	-- [57]
				--["히드라"]						= "Hydra",					-- [68]
				--["지옥 임프"]					= "Fel Imp",				-- [100]
				--["공허군주"]					= "Voidlord",				-- [101]
				--["쉬바라"]						= "Shivarra",				-- [102]
				--["감시자"]						= "Observer",				-- [103]
				--["격노수호병"]					= "Wrathguard",				-- [104]
				--["지옥불정령"]					= "Infernal",				-- [108]
				--["불의 정령"]					= "Fire Elemental",			-- [116]
				--["대지의 정령"]					= "Earth Elemental",		-- [117]
				--["학"]						= "Crane",					-- [125]
				--["소금쟁이"]					= "Water Strider",			-- [126]
				--["설치류"]						= "Rodent",					-- [127]
				--["기렌"]						= "Quilen",					-- [128]
				--["염소"]						= "Goat",					-- [129]
				--["바실리스크"]					= "Basilisk",				-- [130]
				--["공포뿔"]						= "Direhorn",				-- [138]
				--["폭풍의 정령"]					= "Storm Elemental",		-- [145]
				--["공포수호병"]					= "Terrorguard",			-- [147]
				--["심연불정령"]					= "Abyssal",				-- [148]
				--["강물하마"]					= "Riverbeast",				-- [150]
				--["순록"]						= "Stag",					-- [151]
				--["기계"]						= "Mechanical",				-- [154]
				--["누더기골렘"]					= "Abomination",			-- [155]
				--["비늘가죽"]					= "Scalehide",				-- [156]
				--["소"]						= "Oxen",					-- [157]
				--["뾰족갈기"]					= "Feathermane",			-- [160]
				--["도마뱀"]						= "Lizard",					-- [288]
				--["테러닥스"]					= "Pterrordax",				-- [290]
				--["두꺼비"]						= "Toad",					-- [291]
				--["크롤러스크"]					= "Krolusk",				-- [292]
				--["피의 괴물"]					= "Blood Beast",			-- [296]
			},
			zhCN				= {
				["狼"]						= "Wolf",					-- [1] 
				["豹"]						= "Cat",					-- [2] 
				["蜘蛛"]					= "Spider",					-- [3] 
				["熊"]						= "Bear",					-- [4] 
				["野猪"]					= "Boar",					-- [5] 
				["鳄鱼"]					= "Crocolisk",				-- [6] 
				["食腐鸟"]					= "Carrion Bird",			-- [7] 
				["螃蟹"]					= "Crab",					-- [8] 
				["猩猩"]					= "Gorilla",				-- [9] 
				["迅猛龙"]					= "Raptor",					-- [11] 
				["陆行鸟"]					= "Tallstrider",			-- [12] 
				["地狱猎犬"]					= "Felhunter",				-- [15] 
				["虚空行者"]					= "Voidwalker",				-- [16] 
				["魅魔"]					= "Succubus",				-- [17]  
				["末日守卫"]					= "Doomguard",				-- [19] 
				["蝎子"]					= "Scorpid",				-- [20] 
				["海龟"]					= "Turtle",					-- [21] 
				["小鬼"]					= "Imp",					-- [23] 
				["蝙蝠"]					= "Bat",					-- [24] 
				["土狼"]					= "Hyena",					-- [25] 
				["猫头鹰"]					= "Owl",					-- [26] Classic 
				["猛禽"]					= "Bird of Prey",			-- [26] Retail
				["风蛇"]					= "Wind Serpent",			-- [27] 
				["远程控制"]					= "Remote Control",			-- [28] 
				--["恶魔卫士"]					= "Felguard",				-- [29]
				--["龙鹰"]					= "Dragonhawk",				-- [30]
				--["掠食者"]					= "Ravager",				-- [31]
				--["迁跃捕猎者"]				= "Warp Stalker",			-- [32]
				--["孢子蝠"]					= "Sporebat",				-- [33]
				--["鳐鱼"]					= "Ray",					-- [34]
				--["蛇"]						= "Serpent",				-- [35]
				--["蛾子"]					= "Moth",					-- [37]
				--["奇美拉"]					= "Chimaera",				-- [38]
				--["魔暴龙"]					= "Devilsaur",				-- [39]
				--["食尸鬼"]					= "Ghoul",					-- [40]
				--["异种虫"]					= "Silithid",				-- [41]
				--["蠕虫"]					= "Worm",					-- [42]
				--["裂蹄牛"]					= "Clefthoof",				-- [43]
				--["巨蜂"]					= "Wasp",					-- [44]
				--["熔岩犬"]					= "Core Hound",				-- [45]
				--["灵魂兽"]					= "Spirit Beast",			-- [46]
				--["水元素"]					= "Water Elemental",		-- [49]
				--["狐狸"]					= "Fox",					-- [50]
				--["猴子"]					= "Monkey",					-- [51]
				--["狗"]						= "Dog",					-- [52]
				--["甲虫"]					= "Beetle",					-- [53]
				--["页岩蛛"]					= "Shale Spider",			-- [55]
				--["僵尸"]					= "Zombie",					-- [56]
				--["<< QA TEST FAMILY >>"]	= "<< QA TEST FAMILY >>",	-- [57]
				--["九头蛇"]					= "Hydra",					-- [68]
				--["邪能小鬼"]					= "Fel Imp",				-- [100]
				--["空灵领主"]					= "Voidlord",				-- [101]
				--["破坏魔"]					= "Shivarra",				-- [102]
				--["眼魔"]					= "Observer",				-- [103]
				--["愤怒卫士"]					= "Wrathguard",				-- [104]
				--["地狱火"]					= "Infernal",				-- [108]
				--["火元素"]					= "Fire Elemental",			-- [116]
				--["土元素"]					= "Earth Elemental",		-- [117]
				--["鹤"]						= "Crane",					-- [125]
				--["水黾"]					= "Water Strider",			-- [126]
				--["啮齿动物"]					= "Rodent",					-- [127]
				--["魁麟"]					= "Quilen",					-- [128]
				--["山羊"]					= "Goat",					-- [129]
				--["石化蜥蜴"]					= "Basilisk",				-- [130]
				--["恐角龙"]					= "Direhorn",				-- [138]
				--["风暴元素"]					= "Storm Elemental",		-- [145]
				--["恐惧卫士"]					= "Terrorguard",			-- [147]
				--["深渊魔"]					= "Abyssal",				-- [148]
				--["淡水兽"]					= "Riverbeast",				-- [150]
				--["雄鹿"]					= "Stag",					-- [151]
				--["机械"]					= "Mechanical",				-- [154]
				--["憎恶"]					= "Abomination",			-- [155]
				--["鳞甲类"]					= "Scalehide",				-- [156]
				--["牛"]						= "Oxen",					-- [157]
				--["羽鬃兽"]					= "Feathermane",			-- [160]
				--["蜥蜴"]					= "Lizard",					-- [288]
				--["翼手龙"]					= "Pterrordax",				-- [290]
				--["蟾蜍"]					= "Toad",					-- [291]
				--["三叶虫"]					= "Krolusk",				-- [292]
				--["血兽"]					= "Blood Beast",			-- [296]
			},
			zhTW				= {
				["狼"]						= "Wolf",					-- [1] 
				["豹"]						= "Cat",					-- [2] Classic
				["大貓"]					= "Cat",					-- [2] Retail
				["蜘蛛"]					= "Spider",					-- [3] 
				["熊"]						= "Bear",					-- [4] 
				["野豬"]					= "Boar",					-- [5] 
				["鱷魚"]					= "Crocolisk",				-- [6] 
				["食腐鳥"]					= "Carrion Bird",			-- [7] 
				["螃蟹"]					= "Crab",					-- [8] 
				["猩猩"]					= "Gorilla",				-- [9] 
				["迅猛龍"]					= "Raptor",					-- [11] 
				["陸行鳥"]					= "Tallstrider",			-- [12] 
				["地獄獵犬"]					= "Felhunter",				-- [15] Classic 
				["惡魔獵犬"]					= "Felhunter",				-- [15] Retail 
				["虛空行者"]					= "Voidwalker",				-- [16] Classic 
				["虛無行者"]					= "Voidwalker",				-- [16] Retail 
				["魅魔"]					= "Succubus",				-- [17] 
				["末日守衛"]					= "Doomguard",				-- [19] 
				["蠍子"]					= "Scorpid",				-- [20] 
				["海龜"]					= "Turtle",					-- [21]
				["小鬼"]					= "Imp",					-- [23] 
				["蝙蝠"]					= "Bat",					-- [24] 
				["土狼"]					= "Hyena",					-- [25]
				["貓頭鷹"]					= "Owl",					-- [26] Classic  
				["猛禽"]					= "Bird of Prey",			-- [26] Retail
				["風蛇"]					= "Wind Serpent",			-- [27] 
				["遙控"]					= "Remote Control",			-- [28] 
				--["惡魔守衛"]					= "Felguard",				-- [29]
				--["龍鷹"]					= "Dragonhawk",				-- [30]
				--["劫毀者"]					= "Ravager",				-- [31]
				--["扭曲巡者"]					= "Warp Stalker",			-- [32]
				--["孢子蝙蝠"]					= "Sporebat",				-- [33]
				--["魟魚"]					= "Ray",					-- [34]
				--["毒蛇"]					= "Serpent",				-- [35]
				--["蛾"]						= "Moth",					-- [37]
				--["奇美拉"]					= "Chimaera",				-- [38]
				--["魔暴龍"]					= "Devilsaur",				-- [39]
				--["食屍鬼"]					= "Ghoul",					-- [40]
				--["異種蟲族"]					= "Silithid",				-- [41]
				--["蟲"]						= "Worm",					-- [42]
				--["裂蹄"]					= "Clefthoof",				-- [43]
				--["黃蜂"]					= "Wasp",					-- [44]
				--["熔核犬"]					= "Core Hound",				-- [45]
				--["靈獸"]					= "Spirit Beast",			-- [46]
				--["水元素"]					= "Water Elemental",		-- [49]
				--["狐狸"]					= "Fox",					-- [50]
				--["猴子"]					= "Monkey",					-- [51]
				--["狗"]						= "Dog",					-- [52]
				--["甲蟲"]					= "Beetle",					-- [53]
				--["岩蛛"]					= "Shale Spider",			-- [55]
				--["殭屍"]					= "Zombie",					-- [56]
				--["<< QA TEST FAMILY >>"]	= "<< QA TEST FAMILY >>",	-- [57]
				--["多頭蛇"]					= "Hydra",					-- [68]
				--["魔化小鬼"]					= "Fel Imp",				-- [100]
				--["虛無領主"]					= "Voidlord",				-- [101]
				--["希瓦拉"]					= "Shivarra",				-- [102]
				--["觀察者"]					= "Observer",				-- [103]
				--["憤怒守衛"]					= "Wrathguard",				-- [104]
				--["煉獄火"]					= "Infernal",				-- [108]
				--["火元素"]					= "Fire Elemental",			-- [116]
				--["土元素"]					= "Earth Elemental",		-- [117]
				--["鶴"]						= "Crane",					-- [125]
				--["水黽"]					= "Water Strider",			-- [126]
				--["齧齒類"]					= "Rodent",					-- [127]
				--["麒麟獸"]					= "Quilen",					-- [128]
				--["山羊"]					= "Goat",					-- [129]
				--["蜥蜴"]					= "Basilisk",				-- [130]
				--["恐角龍"]					= "Direhorn",				-- [138]
				--["風暴元素"]					= "Storm Elemental",		-- [145]
				--["恐懼護衛"]					= "Terrorguard",			-- [147]
				--["冥淵火"]					= "Abyssal",				-- [148]
				--["河獸"]					= "Riverbeast",				-- [150]
				--["雄鹿"]					= "Stag",					-- [151]
				--["機械"]					= "Mechanical",				-- [154]
				--["憎惡體"]					= "Abomination",			-- [155]
				--["鱗皮"]					= "Scalehide",				-- [156]
				--["玄牛"]					= "Oxen",					-- [157]
				--["羽鬃"]					= "Feathermane",			-- [160]
				--["蜥蜴"]					= "Lizard",					-- [288]
				--["翼手龍"]					= "Pterrordax",				-- [290]
				--["青蛙"]					= "Toad",					-- [291]
				--["葉殼蟲"]					= "Krolusk",				-- [292]
				--["血獸"]					= "Blood Beast",			-- [296]
			},
		}, 
		{
			__index = function(t, v)
				return t[GameLocale][v]
			end,
		}
	),
	IsDummy 					= {
		-- City (SW, Orgri, ...)
		[5652] 			= true, 
		[4952] 			= true,
		[4957] 			= true,
		[5723] 			= true,
		[1921] 			= true,
		[12426] 		= true, 
		[12385] 		= true,
		[11875] 		= true,
		[16211] 		= true, 
		[2674] 			= true, 
		[2673] 			= true,
		[5202]	 		= true, 
		[14831] 		= true, -- Unkillable Test Dummy 63 Warrior
	},
	IsBoss 						= {
		[14831] 		= true, -- Unkillable Test Dummy 63 Warrior
	},
	IsNotBoss 					= {
	},
	ControlAbleClassification 	= {
		["trivial"] 			= true,
		["minus"] 				= true,
		["normal"] 				= true,
		["rare"] 				= true,
		["rareelite"] 			= true,
		["elite"] 				= true,
		["worldboss"] 			= false,
		[""] 					= true,
	},
}

local InfoCacheMoveIn						= Info.CacheMoveIn
local InfoCacheMoveOut						= Info.CacheMoveOut
local InfoCacheMoving						= Info.CacheMoving
local InfoCacheStaying						= Info.CacheStaying
local InfoCacheInterrupt					= Info.CacheInterrupt

local InfoSpecIs 							= Info.SpecIs
local InfoClassCanBeHealer 					= Info.ClassCanBeHealer
local InfoClassCanBeTank 					= Info.ClassCanBeTank
local InfoClassCanBeMelee 					= Info.ClassCanBeMelee
local InfoAllCC 							= Info.AllCC

local InfoCreatureType 						= Info.CreatureType
local InfoCreatureFamily					= Info.CreatureFamily
local InfoIsDummy							= Info.IsDummy

local InfoIsBoss 							= Info.IsBoss
local InfoIsNotBoss 						= Info.IsNotBoss
local InfoControlAbleClassification			= Info.ControlAbleClassification

A.Unit = PseudoClass({
	-- If it's by "UnitGUID" then it will use cache for different unitID with same unitGUID (which is not really best way to waste performance)
	-- Use "UnitGUID" only on high required resource functions
	-- Pass - no cache at all 
	-- Wrap - is a cache 
	Name 									= Cache:Pass(function(self)  
		-- @return string 
		local unitID 						= self.UnitID		
		return UnitName(unitID) or str_none
	end, "UnitID"),
	Race 									= Cache:Pass(function(self)  
		-- @return string 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return A.PlayerRace
		end 
		
		return select(2, UnitRace(unitID)) or str_none
	end, "UnitID"),
	Class 									= Cache:Pass(function(self)  
		-- @return string 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return A.PlayerClass 
		end 
		
		return select(2, UnitClass(unitID)) or str_none
	end, "UnitID"),
	Role 									= Cache:Pass(function(self, hasRole)  
		-- @return boolean or string (depended on hasRole argument, TANK, HEALER, DAMAGER, NONE) 
		-- Nill-able: hasRole
		local unitID 						= self.UnitID

		if hasRole then 
			if hasRole == "HEALER" then 
				return self(unitID):IsHealer()
			elseif hasRole == "TANK" then 
				return self(unitID):IsTank()
			elseif hasRole == "DAMAGER" then 
				return self(unitID):IsDamager()
			else 
				return false
			end 
		else 
			if self(unitID):IsHealer() then 
				return "HEALER"
			elseif self(unitID):IsTank() then 
				return "TANK"
			elseif self(unitID):IsDamager() then 
				return "DAMAGER"
			else 
				return "NONE"
			end 
		end 				
	end, "UnitID"),
	Classification							= Cache:Pass(function(self)  
		-- @return string or empty string  
		local unitID 						= self.UnitID
		return UnitClassification(unitID) or str_empty
	end, "UnitID"),
	CreatureType							= Cache:Pass(function(self)  
		-- @return string or empty string     
		-- Returns formated string to English, possible string returns:
		-- "Beast"				-- [1]
		-- "Dragonkin"			-- [2]
		-- "Demon"				-- [3]
		-- "Elemental"			-- [4]
		-- "Giant"				-- [5]
		-- "Undead"				-- [6]				
		-- "Humanoid"			-- [7]
		-- "Critter"			-- [8]
		-- "Mechanical",		-- [9]
		-- "Not specified"		-- [10]				
		-- "Not specified"		-- [10]	(The default UI displays an empty string instead of "Not specified" for units with that creature type)
		-- "Totem"				-- [11]
		local unitID 						= self.UnitID
		local unitCreatureType 				= UnitCreatureType(unitID)
		return unitCreatureType and InfoCreatureType[unitCreatureType] or str_empty	
	end, "UnitID"),
	CreatureFamily							= Cache:Pass(function(self)  
		-- @return string or empty string     
		-- Returns formated string to English, possible string returns:
		-- "Wolf"					-- [1]
		-- "Cat"					-- [2]
		-- "Spider"					-- [3]
		-- "Bear"					-- [4]
		-- "Boar"					-- [5]
		-- "Crocolisk"				-- [6]
		-- "Carrion Bird"			-- [7]
		-- "Crab"					-- [8]
		-- "Gorilla"				-- [9]
		-- "Raptor"					-- [11]
		-- "Tallstrider"			-- [12]
		-- "Felhunter"				-- [15]
		-- "Voidwalker"				-- [16]
		-- "Succubus"				-- [17]
		-- "Doomguard"				-- [19]
		-- "Scorpid"				-- [20]
		-- "Turtle"					-- [21]
		-- "Imp"					-- [23]
		-- "Bat"					-- [24]
		-- "Hyena"					-- [25]
		-- "Bird of Prey"			-- [26]
		-- "Wind Serpent"			-- [27]
		-- "Remote Control"			-- [28]		
		local unitID 						= self.UnitID
		local unitCreatureFamily			= UnitCreatureFamily(unitID)
		return unitCreatureFamily and InfoCreatureFamily[unitCreatureFamily] or str_empty		
	end, "UnitID"),
	InfoGUID 								= Cache:Wrap(function(self, unitGUID)
		-- @return 
		-- For players: Player-[server ID]-[player UID] (Example: "Player-970-0002FD64")
		-- For creatures, pets, objects, and vehicles: [Unit type]-0-[server ID]-[instance ID]-[zone UID]-[ID]-[spawn UID] (Example: "Creature-0-970-0-11-31146-000136DF91")
		-- Unit Type Names: "Player", "Creature", "Pet", "GameObject", "Vehicle", and "Vignette" they are always in English		
		-- [1] utype
		-- [2] zero 		or server_id 
		-- [3] server_id 	or player_uid
		-- [4] instance_id	or nil 
		-- [5] zone_uid		or nil 
		-- [6] npc_id		or nil 
		-- [7] spawn_uid 	or nil 
		-- or nil
		-- Nill-able: unitGUID
		local unitID 						= self.UnitID
		local GUID 							= unitGUID or UnitGUID(unitID)
		if GUID then 
			local utype, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", GUID)
			if utype then 
				return utype, toNum[zero], toNum[server_id], instance_id and toNum[instance_id], zone_uid and toNum[zone_uid], npc_id and toNum[npc_id], spawn_uid and toNum[spawn_uid]
			end 
		end 
	end, "UnitID"),
	InLOS 									= Cache:Pass(function(self, unitGUID)   
		-- @return boolean 
		-- Nill-able: unitGUID
		local unitID 						= self.UnitID
		return UnitInLOS(unitID, unitGUID)
	end, "UnitID"),
	InGroup 								= Cache:Pass(function(self, includeAnyGroups, unitGUID)  
		-- @return boolean 
		local unitID 						= self.UnitID
		if includeAnyGroups then 
			return UnitInAnyGroup(unitID)
		else
			local GUID = unitGUID or GetGUID(unitID)
			return GUID and (TeamCacheFriendlyGUIDs[GUID] or TeamCacheEnemyGUIDs[GUID])
		end 
	end, "UnitID"),
	InParty									= Cache:Pass(function(self)  
		-- @return boolean 
		local unitID 						= self.UnitID
		return UnitPlayerOrPetInParty(unitID)
	end, "UnitID"),
	InRaid									= Cache:Pass(function(self)  
		-- @return boolean 
		local unitID 						= self.UnitID
		return UnitPlayerOrPetInRaid(unitID)
	end, "UnitID"),
	InRange 								= Cache:Pass(function(self)  
		-- @return boolean 
		local unitID 						= self.UnitID
		return UnitIsUnit(unitID, "player") or UnitInRange(unitID)
	end, "UnitID"),
	InCC 									= Cache:Wrap(function(self, index)
		-- @return number (time in seconds of remain crownd control)
		-- Nill-able: index
		local unitID 						= self.UnitID
		local value 
		for i = (index or 1), #InfoAllCC do 
			value = self(unitID):HasDeBuffs(InfoAllCC[i])
			if value ~= 0 then 
				return value
			end 
		end   
		return 0 
	end, "UnitGUID"),	
	IsEnemy									= Cache:Wrap(function(self, isPlayer)  
		-- @return boolean
		-- Nill-able: isPlayer
		local unitID 						= self.UnitID
		return unitID and (UnitCanAttack("player", unitID) or UnitIsEnemy("player", unitID)) and (not isPlayer or UnitIsPlayer(unitID))
	end, "UnitID"),	
	IsHealer 								= Cache:Wrap(function(self, skipUnitIsUnit, class)  
		-- @return boolean
		-- Nill-able: skipUnitIsUnit, class
		local unitID 						= self.UnitID
		if not skipUnitIsUnit and UnitIsUnit(unitID, "player") then 
			return self("player"):HasSpec(InfoSpecIs.HEALER) 
		end 
		
		if InfoClassCanBeHealer[class or self(unitID):Class()] then 		
											-- bypass it in PvP 
			local taken_dmg 				= (self(unitID):IsEnemy() and self(unitID):IsPlayer() and 0) or CombatTracker:GetDMG(unitID)
			local done_dmg					= CombatTracker:GetDPS(unitID)
			local done_hps					= CombatTracker:GetHPS(unitID)
			return done_hps > taken_dmg and done_hps > done_dmg  
		end 
	end, "UnitGUID"),
	IsHealerClass							= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return InfoClassCanBeHealer[self(unitID):Class()]
	end, "UnitID"),	
	IsTank 									= Cache:Wrap(function(self, skipUnitIsUnit, class)    
		-- @return boolean 
		-- Nill-able: skipUnitIsUnit, class
		local unitID 						= self.UnitID
		if not skipUnitIsUnit and UnitIsUnit(unitID, "player") then 
			return self("player"):HasSpec(InfoSpecIs.TANK) 
		end 
		
		local unitID_class 					= class or self(unitID):Class()
		if InfoClassCanBeTank[unitID_class] then 
			if unitID:match("raid%d+") and GetPartyAssignment("maintank", unitID) then 
				return true 
			end 
			
			if CombatTracker:CombatTime(unitID) == 0 then 
				if unitID_class == "PALADIN" then 
					local _, offhand = UnitAttackSpeed(unitID)
					-- Buff: Righteous Fury 
					return offhand == nil and self(unitID):HasBuffs(25781) > 0 and A_GetUnitItem(unitID, CONST.INVSLOT_OFFHAND, LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_SHIELD, nil, true) -- byPassDistance
				elseif unitID_class == "DRUID" then 
					return UnitPowerType(unitID) == 1
				elseif unitID_class == "WARRIOR" then 
					local _, offhand = UnitAttackSpeed(unitID)
					-- Buff: Defensive Stance
					return offhand == nil and self(unitID):HasBuffs(71) > 0 and A_GetUnitItem(unitID, CONST.INVSLOT_OFFHAND, LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_SHIELD) -- don't byPassDistance
				end
			elseif not A.IsInPvP then 
				local unitIDtarget = unitID .. "target"
				if UnitIsUnit(unitID, unitIDtarget .. "target") and self(unitIDtarget):IsBoss() then 
					return true 
				end 
			end 
			
			local taken_dmg 				= CombatTracker:GetDMG(unitID)
			local done_dmg					= CombatTracker:GetDPS(unitID)
			local done_hps					= CombatTracker:GetHPS(unitID)
			return taken_dmg > done_dmg and taken_dmg > done_hps
		end 
	end, "UnitGUID"),	
	IsTankClass								= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return InfoClassCanBeTank[self(unitID):Class()]
	end, "UnitID"),	
	IsDamager								= Cache:Wrap(function(self, skipUnitIsUnit)    
		-- @return boolean 
		-- Nill-able: skipUnitIsUnit
		local unitID 						= self.UnitID
		if not skipUnitIsUnit and UnitIsUnit(unitID, "player") then 
			return self("player"):HasSpec(InfoSpecIs.DAMAGER) 
		end 

		if unitID:match("raid%d+") and GetPartyAssignment("mainassist", unitID) then 
			return true 
		end 
											-- bypass it in PvP 
		local taken_dmg 					= (self(unitID):IsEnemy() and self(unitID):IsPlayer() and 0) or CombatTracker:GetDMG(unitID) 
		local done_dmg						= CombatTracker:GetDPS(unitID)
		local done_hps						= CombatTracker:GetHPS(unitID)
		return done_dmg > taken_dmg and done_dmg > done_hps 
	end, "UnitGUID"),	
	IsMelee 								= Cache:Wrap(function(self) 
		-- @return boolean 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return self("player"):HasSpec(InfoSpecIs.MELEE) 
		end 
		
		local class = self(unitID):Class()
		if InfoClassCanBeMelee[class] then 
			if self(unitID):IsTank(true, class) then 
				return true 
			end 
			
			if self(unitID):IsDamager(true) then 
				if unitClass == "SHAMAN" then 
					local _, offhand = UnitAttackSpeed(unitID)
					return offhand ~= nil                    
				elseif unitClass == "DRUID" then 
					local _, power = UnitPowerType(unitID)
					return power == "ENERGY" or power == "FURY"
				else 
					return true 
				end 
			else 
				if class == "DRUID" then 
					local _, power = UnitPowerType(unitID)
					return power == "ENERGY" or power == "FURY"					
				end 
			end 
		end 
	end, "UnitGUID"),
	IsMeleeClass							= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return InfoClassCanBeMelee[self(unitID):Class()]
	end, "UnitID"),
	IsDead 									= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitIsDeadOrGhost(unitID) and not UnitIsFeignDeath(unitID)
	end, "UnitID"),	
	IsGhost									= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitIsGhost(unitID)
	end, "UnitID"),		
	IsPlayer								= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitIsPlayer(unitID)
	end, "UnitID"),
	IsPet									= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return not UnitIsPlayer(unitID) and UnitPlayerControlled(unitID)
	end, "UnitID"),
	IsPlayerOrPet							= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitIsPlayer(unitID) or UnitPlayerControlled(unitID)
	end, "UnitID"),	
	IsNPC									= Cache:Pass(function(self) 
		-- @return boolean
		local unitID 						= self.UnitID
		return not UnitPlayerControlled(unitID)
	end, "UnitID"),
	IsVisible								= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitIsVisible(unitID)
	end, "UnitID"),
	IsExists 								= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitExists(unitID)
	end, "UnitID"),
	IsNameplate								= Cache:Pass(function(self)  
		-- @return boolean, nameplateUnitID or nil 
		-- Note: Only enemy plates
		local unitID 						= self.UnitID
		for nameplateUnit in pairs(ActiveUnitPlates) do 
			if UnitIsUnit(unitID, nameplateUnit) then 
				return true, nameplateUnit
			end 
		end 
	end, "UnitID"),
	IsNameplateAny							= Cache:Pass(function(self)  
		-- @return boolean, nameplateUnitID or nil 
		-- Note: Any plates
		local unitID 						= self.UnitID
		for nameplateUnit in pairs(ActiveUnitPlatesAny) do 
			if UnitIsUnit(unitID, nameplateUnit) then 
				return true, nameplateUnit
			end 
		end 
	end, "UnitID"),
	IsConnected								= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitIsConnected(unitID)
	end, "UnitID"),
	IsCharmed								= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitIsCharmed(unitID)
	end, "UnitID"),
	IsMounted								= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player")  then 
			return Player:IsMounted()
		end 
		return select(2, self(unitID):GetCurrentSpeed()) >= 200
	end, "UnitID"),
	IsMovingOut								= Cache:Pass(function(self, snap_timer)
		-- @return boolean 
		-- snap_timer must be in miliseconds e.g. 0.2 or leave it empty, it's how often unit must be updated between snapshots to understand in which side he's moving 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return true 
		end 
		
		local unitSpeed 					= self(unitID):GetCurrentSpeed()
		if unitSpeed > 0 then 
			if unitSpeed == self("player"):GetCurrentSpeed() then 
				return true 
			end 
			
			local GUID 						= UnitGUID(unitID) 
			local _, min_range				= self(unitID):GetRange()
			if not InfoCacheMoveOut[GUID] then 
				InfoCacheMoveOut[GUID] = {
					Snapshot 	= 1,
					TimeStamp 	= TMW.time,
					Range 		= min_range,
					Result 		= false,
				}
				return false 
			end 
			
			if TMW.time - InfoCacheMoveOut[GUID].TimeStamp <= (snap_timer or 0.2) then 
				return InfoCacheMoveOut[GUID].Result
			end 
			
			InfoCacheMoveOut[GUID].TimeStamp = TMW.time 
			
			if min_range == InfoCacheMoveOut[GUID].Range then 
				return InfoCacheMoveOut[GUID].Result
			end 
			
			if min_range > InfoCacheMoveOut[GUID].Range then 
				InfoCacheMoveOut[GUID].Snapshot = InfoCacheMoveOut[GUID].Snapshot + 1 
			else 
				InfoCacheMoveOut[GUID].Snapshot = InfoCacheMoveOut[GUID].Snapshot - 1
			end		

			InfoCacheMoveOut[GUID].Range = min_range
			
			if InfoCacheMoveOut[GUID].Snapshot >= 3 then 
				InfoCacheMoveOut[GUID].Snapshot = 2
				InfoCacheMoveOut[GUID].Result = true 
				return true 
			else
				if InfoCacheMoveOut[GUID].Snapshot < 0 then 
					InfoCacheMoveOut[GUID].Snapshot = 0 
				end 
				InfoCacheMoveOut[GUID].Result = false
				return false 
			end 
		end 		
	end, "UnitGUID"),
	IsMovingIn								= Cache:Pass(function(self, snap_timer)
		-- @return boolean 		
		-- snap_timer must be in miliseconds e.g. 0.2 or leave it empty, it's how often unit must be updated between snapshots to understand in which side he's moving 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return true 
		end 
		
		local unitSpeed 					= self(unitID):GetCurrentSpeed()
		if unitSpeed > 0 then 
			if unitSpeed == self("player"):GetCurrentSpeed() then 
				return true 
			end 
			
			local GUID 						= UnitGUID(unitID) 
			local _, min_range				= self(unitID):GetRange()
			if not InfoCacheMoveIn[GUID] then 
				InfoCacheMoveIn[GUID] = {
					Snapshot 	= 1,
					TimeStamp 	= TMW.time,
					Range 		= min_range,
					Result 		= false,
				}
				return false 
			end 
			
			if TMW.time - InfoCacheMoveIn[GUID].TimeStamp <= (snap_timer or 0.2) then 
				return InfoCacheMoveIn[GUID].Result
			end 
			
			InfoCacheMoveIn[GUID].TimeStamp = TMW.time 
			
			if min_range == InfoCacheMoveIn[GUID].Range then 
				return InfoCacheMoveIn[GUID].Result
			end 
			
			if min_range < InfoCacheMoveIn[GUID].Range then 
				InfoCacheMoveIn[GUID].Snapshot = InfoCacheMoveIn[GUID].Snapshot + 1 
			else 
				InfoCacheMoveIn[GUID].Snapshot = InfoCacheMoveIn[GUID].Snapshot - 1
			end		

			InfoCacheMoveIn[GUID].Range = min_range
			
			if InfoCacheMoveIn[GUID].Snapshot >= 3 then 
				InfoCacheMoveIn[GUID].Snapshot = 2
				InfoCacheMoveIn[GUID].Result = true 
				return true 
			else
				if InfoCacheMoveIn[GUID].Snapshot < 0 then 
					InfoCacheMoveIn[GUID].Snapshot = 0 
				end 			
				InfoCacheMoveIn[GUID].Result = false
				return false 
			end 
		end 		
	end, "UnitGUID"),
	IsMoving								= Cache:Pass(function(self)
		-- @return boolean 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return Player:IsMoving()
		else 
			return self(unitID):GetCurrentSpeed() ~= 0
		end 
	end, "UnitID"),
	IsMovingTime							= Cache:Pass(function(self)	
		-- @return number 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return Player:IsMovingTime()
		else 
			local GUID						= UnitGUID(unitID) 
			local isMoving  				= self(unitID):IsMoving()
			if isMoving then
				if not InfoCacheMoving[GUID] or InfoCacheMoving[GUID] == 0 then 
					InfoCacheMoving[GUID] = TMW.time 
				end                        
			else 
				InfoCacheMoving[GUID] = 0
			end 
			return (InfoCacheMoving[GUID] == 0 and -1) or TMW.time - InfoCacheMoving[GUID]
		end 
	end, "UnitGUID"),
	IsStaying								= Cache:Pass(function(self)
		-- @return boolean 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return Player:IsStaying()
		else 
			return self(unitID):GetCurrentSpeed() == 0
		end 		
	end, "UnitID"),
	IsStayingTime							= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
		if UnitIsUnit(unitID, "player") then 
			return Player:IsStayingTime()
		else 
			local GUID						= UnitGUID(unitID) 
			local isMoving  				= self(unitID):IsMoving()
			if not isMoving then
				if not InfoCacheStaying[GUID] or InfoCacheStaying[GUID] == 0 then 
					InfoCacheStaying[GUID] = TMW.time 
				end                        
			else 
				InfoCacheStaying[GUID] = 0
			end 
			return (InfoCacheStaying[GUID] == 0 and -1) or TMW.time - InfoCacheStaying[GUID]
		end
	end, "UnitGUID"),
	IsCasting 								= Cache:Wrap(function(self)
		-- @return:
		-- [1] castName (@string or @nil)
		-- [2] castStartedTime (@number or @nil)
		-- [3] castEndTime (@number or @nil)
		-- [4] notInterruptable (@boolean, false is able to be interrupted)
		-- [5] spellID (@number or @nil)
		-- [6] isChannel (@boolean)
		local unitID 						= self.UnitID
		local isChannel
		local castName, _, _, castStartTime, castEndTime, _, _, notInterruptable, spellID = UnitCastingInfo(unitID)
		if not castName then 
			castName, _, _, castStartTime, castEndTime, _, notInterruptable, spellID = UnitChannelInfo(unitID)			
			if castName then 
				isChannel = true
			end 
		end  
		
		-- Check interrupt able 
		if castName then 
			if next(AuraList.KickImun) then 
				notInterruptable = self(unitID):HasBuffs("KickImun") ~= 0 
			else
				notInterruptable = false 
			end 
		end 
		
		return castName, castStartTime, castEndTime, notInterruptable, spellID, isChannel
	end, "UnitGUID"),
	IsCastingRemains						= Cache:Pass(function(self, argSpellID)
		-- @return:
		-- [1] Currect Casting Left Time (seconds) (@number)
		-- [2] Current Casting Left Time (percent) (@number)
		-- [3] spellID (@number)
		-- [4] spellName (@string)
		-- [5] notInterruptable (@boolean, false is able to be interrupted)
		-- [6] isChannel (@boolean)
		-- Nill-able: argSpellID
		local unitID 						= self.UnitID
		return select(2, self(unitID):CastTime(argSpellID))
	end, "UnitGUID"),
	CastTime								= Cache:Pass(function(self, argSpellID)
		-- @return:
		-- [1] Total Casting Time (@number)
		-- [2] Currect Casting Left (X -> 0) Time (seconds) (@number)
		-- [3] Current Casting Done (0 -> 100) Time (percent) (@number)
		-- [4] spellID (@number)
		-- [5] spellName (@string)
		-- [6] notInterruptable (@boolean, false is able to be interrupted)
		-- [7] isChannel (@boolean)
		-- Nill-able: argSpellID
		local unitID 						= self.UnitID
		local castName, castStartTime, castEndTime, notInterruptable, spellID, isChannel = self(unitID):IsCasting()

		local TotalCastTime, CurrentCastTimeSeconds, CurrentCastTimeLeftPercent = 0, 0, 0
		if unitID == "player" then 
			TotalCastTime = (select(4, GetSpellInfo(argSpellID or spellID)) or 0) / 1000
			CurrentCastTimeSeconds = TotalCastTime
		end 
		
		if castName and (not argSpellID or A_GetSpellInfo(argSpellID) == castName) then 
			TotalCastTime = (castEndTime - castStartTime) / 1000
			CurrentCastTimeSeconds = (TMW.time * 1000 - castStartTime) / 1000
			CurrentCastTimeLeftPercent = CurrentCastTimeSeconds * 100 / TotalCastTime
		end 		
		
		return TotalCastTime, TotalCastTime - CurrentCastTimeSeconds, CurrentCastTimeLeftPercent, spellID, castName, notInterruptable, isChannel
	end, "UnitGUID"),
	MultiCast 								= Cache:Pass(function(self, spells, range)
		-- @return 
		-- [1] Total CastTime
		-- [2] Current CastingTime Left
		-- [3] Current CastingTime Percent (from 0% as start til 100% as finish)
		-- [4] SpellID 
		-- [5] SpellName
		-- [6] notInterruptable (@boolean, false is able to be interrupted)
		-- Note: spells accepts only table or nil to get list from "CastBarsCC"
		local unitID 						= self.UnitID				    
		local castTotal, castLeft, castLeftPercent, castID, castName, notInterruptable = self(unitID):CastTime()
		
		if castLeft > 0 and (not range or self(unitID):GetRange() <= range) then
			local query = (type(spells) == "table" and spells) or AuraList.CastBarsCC  
			for i = 1, #query do 				
				if castID == query[i] or castName == A_GetSpellInfo(query[i]) then 
					return castTotal, castLeft, castLeftPercent, castID, castName, notInterruptable
				end 
			end         
		end   
		
		return 0, 0, 0
	end, "UnitGUID"),
	IsControlAble 							= Cache:Pass(function(self, drCat, drDiminishing)
		-- @return boolean 
		-- drDiminishing is Tick (number: 100 -> 50 -> 25 -> 0) where 0 is fully imun, 100% no imun - can be fully duration CC'ed 
		-- "taunt" has unique Tick (number: 100 -> 65 -> 42 -> 27 -> 0)
		--[[ drCat accepts:
			"incapacitate"
			"silence"
			"stun"							-- PvE unlocked  
			"root"
			"disarm"						-- Added in original DRList	
			"random_stun"
			"random_root"					-- May be removed in the future!
			"fear"
			"mind_control"
			"frost_shock"
			"kidney_shot"	
		]]
		-- Nill-able: drDiminishing
		local unitID 						= self.UnitID 
		if not A.IsInPvP then 
			return not self(unitID):IsBoss() and InfoControlAbleClassification[self(unitID):Classification()] and (not drCat or self(unitID):GetDR(drCat) > (drDiminishing or 0)) and (drCat ~= "fear" or self(unitID):HasDeBuffs(AuraList.FearImunDeBuffs) == 0)
		else 
			return (not drCat or self(unitID):GetDR(drCat) > (drDiminishing or 0)) and (drCat ~= "fear" or self(unitID):HasDeBuffs(AuraList.FearImunDeBuffs) == 0)
		end 
	end, "UnitID"),
	-- CreatureType: Bool extenstion
	IsUndead								= Cache:Pass(function(self)
		-- @return boolean 
		local unitID 						= self.UnitID 
		return self(unitID):CreatureType() == "Undead"  	       	
	end, "UnitID"),
	IsDemon									= Cache:Pass(function(self)
		-- @return boolean 
		local unitID 						= self.UnitID 
		return self(unitID):CreatureType() == "Demon"       	
	end, "UnitID"),
	IsHumanoid								= Cache:Pass(function(self)
		-- @return boolean 
		local unitID 						= self.UnitID 
		return self(unitID):CreatureType() == "Humanoid"        	
	end, "UnitID"),
	IsElemental								= Cache:Pass(function(self)
		-- @return boolean 
		local unitID 						= self.UnitID 
		return self(unitID):CreatureType() == "Elemental" 	       	
	end, "UnitID"),
	IsTotem 								= Cache:Pass(function(self)
		-- @return boolean 
		local unitID 						= self.UnitID 
		return self(unitID):CreatureType() == "Totem" 	        	
	end, "UnitID"),
	-- CreatureType: End
	IsDummy									= Cache:Pass(function(self)	
		-- @return boolean 
		local unitID 						= self.UnitID
		local _, _, _, _, _, npc_id 		= self(unitID):InfoGUID()
		return npc_id and InfoIsDummy[npc_id]
	end, "UnitID"),
	IsBoss 									= Cache:Pass(function(self)       
	    -- @return boolean 
		local unitID 						= self.UnitID
		local _, _, _, _, _, npc_id 		= self(unitID):InfoGUID()
		if npc_id and not InfoIsNotBoss[npc_id] then 
			if InfoIsBoss[npc_id] or LibBossIDs[npc_id] or self(unitID):GetLevel() == -1 then 
				return true 
			else 
				for i = 1, CONST.MAX_BOSS_FRAMES do 
					if UnitIsUnit(unitID, "boss" .. i) then 
						return true 
					end 
				end 			
			end 
		end 
	end, "UnitID"),
	ThreatSituation							= Cache:Pass(function(self, otherunitID)  
		-- @return number, number, number 
		-- Returns: status (0 -> 3), percent of threat, value or threat 
		-- Nill-able: otherunit
		local unitID 						= self.UnitID
		if unitID then 
			local GUID 						= UnitGUID(unitID)					
			if GUID and TeamCachethreatData[GUID] then 
				if otherunitID and not UnitIsUnit(otherunitID, TeamCachethreatData[GUID].unit) then 
					-- By specified otherunitID
					-- Note: I prefer avoid use this as much as it possible since less performance 
					local _, status, scaledPercent, _, threatValue = UnitDetailedThreatSituation(unitID, otherunitID) 
					if threatValue and threatValue < 0 then
						threatValue = threatValue + 410065408
					end					
					return status or 0, scaledPercent or 0, threatValue or 0
				else 
					-- By own unit's target 
					return TeamCachethreatData[GUID].status, TeamCachethreatData[GUID].scaledPercent, TeamCachethreatData[GUID].threatValue       
				end 
			end 
		end 
		return 0, 0, 0
	end, "UnitID"),
	IsTanking 								= Cache:Pass(function(self, otherunitID, range)  
		-- @return boolean 
		-- Nill-able: otherunit, range
		local unitID 						= self.UnitID	
		local ThreatSituation 				= self(unitID):ThreatSituation(otherunitID) -- cacheed defaultly own target but if need to check something additional here is otherunitID
		return (A.IsInPvP and UnitIsUnit(unitID, (otherunitID or "target") .. "target")) or (not A.IsInPvP and ThreatSituation >= 3) or self(unitID):IsTankingAoE(range)	       
	end, "UnitID"),
	IsTankingAoE 							= Cache:Pass(function(self, range) 
		-- @return boolean 
		-- Nill-able: range
		local unitID 						= self.UnitID
		for unit in pairs(ActiveUnitPlates) do
			local ThreatSituation 		= self(unitID):ThreatSituation() -- cacheed defaultly own target 
			if ((A.IsInPvP and UnitIsUnit(unitID, unit .. "target")) or (not A.IsInPvP and ThreatSituation >= 3)) and (not range or self(unit .. "target"):CanInterract(range)) then 
				return true  
			end
		end       
	end, "UnitID"),
	IsPenalty								= Cache:Pass(function(self)  
		-- @return boolean 
		-- Note: Returns true if unit has penalty for healing or damage 
		local unitID 						= self.UnitID
		local unitLvL						= self(unitID):GetLevel()
		return unitLvL > 0 and unitLvL < A.PlayerLevel - 10
	end, "UnitID"),
	GetLevel 								= Cache:Pass(function(self) 
		-- @return number 
		local unitID 						= self.UnitID
		return UnitLevel(unitID) or 0  
	end, "UnitID"),
	GetCurrentSpeed 						= Cache:Wrap(function(self) 
		-- @return number (current), number (max)
		local unitID 						= self.UnitID
		local current_speed, max_speed 		= GetUnitSpeed(unitID)
		return math_floor(current_speed / 7 * 100), math_floor(max_speed / 7 * 100)
	end, "UnitGUID"),
	GetMaxSpeed								= Cache:Pass(function(self) 
		-- @return number 
		local unitID 						= self.UnitID
		return select(2, self(unitID):GetCurrentSpeed())
	end, "UnitGUID"),
	GetTotalHealAbsorbs						= Cache:Pass(function(self) 
		-- @return number 
		-- Note: 
		-- Returns the total amount of healing the unit can absorb without gaining health
		-- Abilities like Necrotic Strike cause affected units to absorb healing without gaining health
		local unitID 						= self.UnitID
		return 0 -- TODO: Classic, currently is blank
	end, "UnitID"),
	GetTotalHealAbsorbsPercent				= Cache:Pass(function(self) 
		-- @return number 
		local unitID 						= self.UnitID
		local maxHP							= self(unitID):HealthMax()
		if maxHP == 0 then 
			return 0
		else 
			return self(unitID):GetTotalHealAbsorbs() * 100 / maxHP
		end 
	end, "UnitID"),
	-- Combat: Diminishing
	GetDR 									= Cache:Pass(function(self, drCat) 
		-- @return: DR_Tick (@number), DR_Remain (@number), DR_Application (@number), DR_ApplicationMax (@number)
		-- drDiminishing is Tick (number: 100 -> 50 -> 25 -> 0) where 0 is fully imun, 100% no imun - can be fully duration CC'ed 
		-- "taunt" has unique Tick (number: 100 -> 65 -> 42 -> 27 -> 0)
		--[[ drCat accepts:
			"incapacitate"
			"silence"
			"stun"							-- PvE unlocked  
			"root"
			"disarm"						-- Added in original DRList	
			"random_stun"
			"random_root"					-- May be removed in the future!
			"fear"
			"mind_control"
			"frost_shock"
			"kidney_shot"	
		]]		
		local unitID 						= self.UnitID
		return CombatTracker:GetDR(unitID, drCat)
	end, "UnitID"),
	-- Combat: UnitCooldown
	GetCooldown								= Cache:Pass(function(self, spellName)
		-- @return number, number (remain cooldown time in seconds, start time stamp when spell was used and counter launched) 
		local unitID 						= self.UnitID
		return UnitCooldown:GetCooldown(unitID, spellName)
	end, "UnitID"),
	GetMaxDuration							= Cache:Pass(function(self, spellName)
		-- @return number (max cooldown of the spell on a unit) 
		local unitID 						= self.UnitID
		return UnitCooldown:GetMaxDuration(unitID, spellName)
	end, "UnitID"),
	GetUnitID								= Cache:Pass(function(self, spellName)
		-- @return unitID (who last casted spell) otherwise nil  
		local unitID 						= self.UnitID
		return UnitCooldown:GetUnitID(unitID, spellName)
	end, "UnitID"),
	GetBlinkOrShrimmer						= Cache:Pass(function(self)
		-- @return number, number, number 
		-- [1] Current Charges, [2] Current Cooldown, [3] Summary Cooldown 
		local unitID 						= self.UnitID
		return UnitCooldown:GetBlinkOrShrimmer(unitID)
	end, "UnitID"),
	IsSpellInFly							= Cache:Pass(function(self, spellName)
		-- @return boolean 
		local unitID 						= self.UnitID
		return UnitCooldown:IsSpellInFly(unitID, spellName)
	end, "UnitID"),
	-- Combat: CombatTracker 
	CombatTime 								= Cache:Pass(function(self)
		-- @return number, unitGUID
		local unitID 						= self.UnitID
		return CombatTracker:CombatTime(unitID)
	end, "UnitID"),
	GetLastTimeDMGX 						= Cache:Pass(function(self, x)
		-- @return number: taken amount 
		local unitID 						= self.UnitID
		return CombatTracker:GetLastTimeDMGX(unitID, x)
	end, "UnitID"),
	GetRealTimeDMG							= Cache:Pass(function(self, index)
		-- @return number: taken total, hits, phys, magic, swing 
		local unitID 						= self.UnitID
		if index then 
			return select(index, CombatTracker:GetRealTimeDMG(unitID))
		else
			return CombatTracker:GetRealTimeDMG(unitID)
		end 
	end, "UnitID"),
	GetRealTimeDPS 							= Cache:Pass(function(self, index)
		-- @return number: done total, hits, phys, magic, swing
		local unitID 						= self.UnitID
		if index then 
			return select(index, CombatTracker:GetRealTimeDPS(unitID))
		else
			return CombatTracker:GetRealTimeDPS(unitID)
		end 
	end, "UnitID"),
	GetDMG 									= Cache:Pass(function(self, index)
		-- @return number: taken total, hits, phys, magic 
		local unitID 						= self.UnitID
		if index then 
			return select(index, CombatTracker:GetDMG(unitID))
		else
			return CombatTracker:GetDMG(unitID)
		end 
	end, "UnitID"),
	GetDPS 									= Cache:Pass(function(self, index)
		-- @return number: done total, hits, phys, magic
		local unitID 						= self.UnitID
		if index then 
			return select(index, CombatTracker:GetDPS(unitID))
		else
			return CombatTracker:GetDPS(unitID)
		end 
	end, "UnitID"),
	GetHEAL 								= Cache:Pass(function(self, index)
		-- @return number: taken total, hits
		local unitID 						= self.UnitID
		if index then 
			return select(index, CombatTracker:GetHEAL(unitID))
		else
			return CombatTracker:GetHEAL(unitID)
		end 
	end, "UnitID"),
	GetHPS 									= Cache:Pass(function(self, index)
		-- @return number: done total, hits
		local unitID 						= self.UnitID
		if index then 
			return select(index, CombatTracker:GetHPS(unitID))
		else
			return CombatTracker:GetHPS(unitID)
		end 
	end, "UnitID"),
	GetSchoolDMG							= Cache:Pass(function(self, index)
		-- @return number
		-- [1] Holy 
		-- [2] Fire 
		-- [3] Nature 
		-- [4] Frost 
		-- [5] Shadow 
		-- [6] Arcane 
		-- Note: By @player only!
		local unitID 						= self.UnitID
		if index then 
			return select(index, CombatTracker:GetSchoolDMG(unitID))
		else
			return CombatTracker:GetSchoolDMG(unitID)
		end 
	end, "UnitID"),
	GetSpellAmountX 						= Cache:Pass(function(self, spell, x)
		-- @return number: taken total with 'x' lasts seconds by 'spell'
		local unitID 						= self.UnitID
		return CombatTracker:GetSpellAmountX(unitID, spell, x)
	end, "UnitID"),
	GetSpellAmount 							= Cache:Pass(function(self, spell)
		-- @return number: taken total during all time by 'spell'
		local unitID 						= self.UnitID
		return CombatTracker:GetSpellAmount(unitID, spell)
	end, "UnitID"),
	GetSpellLastCast 						= Cache:Pass(function(self, spell)
		-- @return number, number 
		-- time in seconds since last cast, timestamp of start 
		local unitID 						= self.UnitID
		return CombatTracker:GetSpellLastCast(unitID, spell)
	end, "UnitID"),
	GetSpellCounter 						= Cache:Pass(function(self, spell)
		-- @return number (counter of total used 'spell' during all fight)
		local unitID 						= self.UnitID
		return CombatTracker:GetSpellCounter(unitID, spell)
	end, "UnitID"),
	GetAbsorb 								= Cache:Pass(function(self, spell)
		-- @return number: taken absorb total (or by specified 'spell')
		local unitID 						= self.UnitID
		return CombatTracker:GetAbsorb(unitID, spell)
	end, "UnitID"),
	TimeToDieX 								= Cache:Pass(function(self, x)
		-- @return number 
		local unitID 						= self.UnitID
		return CombatTracker:TimeToDieX(unitID, x)
	end, "UnitID"),
	TimeToDie 								= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
		return CombatTracker:TimeToDie(unitID)
	end, "UnitID"),
	TimeToDieMagicX 						= Cache:Pass(function(self, x)
		-- @return number 
		local unitID 						= self.UnitID
		return CombatTracker:TimeToDieMagicX(unitID, x)
	end, "UnitID"),
	TimeToDieMagic							= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
		return CombatTracker:TimeToDieMagic(unitID)
	end, "UnitID"),
	-- Combat: End
	GetIncomingResurrection					= Cache:Pass(function(self)  
		-- @return boolean
		local unitID 						= self.UnitID
		return UnitHasIncomingResurrection(unitID)
	end, "UnitID"),
	GetIncomingHeals						= Cache:Wrap(function(self, castTime, unitGUID)
		-- @return number 
		-- Nill-able: unitGUID
		if not HealComm or not castTime or castTime <= 0 then 
			return 0
		end 
		
		local unitID 						= self.UnitID
		local GUID 							= unitGUID or UnitGUID(unitID)
		
		if not GUID then 
			return 0 
		end 
		
		return (HealComm:GetOthersHealAmount(GUID, ALL_HEALS, TMW.time + castTime) or 0) * HealComm:GetHealModifier(GUID) -- Better by others since if we will include our heals it will funky use accidentally downrank
	end, "UnitGUID"),
	GetIncomingHealsIncSelf					= Cache:Wrap(function(self, castTime, unitGUID)
		-- @return number 
		-- Nill-able: unitGUID
		if not HealComm or not castTime or castTime <= 0 then 
			return 0
		end 
		
		local unitID 						= self.UnitID
		local GUID 							= unitGUID or UnitGUID(unitID)
		
		if not GUID then 
			return 0 
		end 
		
		return (HealComm:GetHealAmount(GUID, ALL_HEALS, TMW.time + castTime) or 0) * HealComm:GetHealModifier(GUID) -- Includes self incoming on a unitID 
	end, "UnitGUID"),
	GetRange 								= Cache:Wrap(function(self)
		-- @return number (max), number (min)
		local unitID 						= self.UnitID
		local min_range, max_range 			= LibRangeCheck:GetRange(unitID)
		if not max_range then 
			return huge, min_range or huge 
		end 
		
		-- Limit range to 20 if unitID is nameplated and max range over normal behaivor 
		if max_range > CONST.CACHE_DEFAULT_NAMEPLATE_MAX_DISTANCE and self(unitID):IsNameplateAny() then 
			if min_range > CONST.CACHE_DEFAULT_NAMEPLATE_MAX_DISTANCE then 
				min_range = CONST.CACHE_DEFAULT_NAMEPLATE_MAX_DISTANCE
			end 
			return CONST.CACHE_DEFAULT_NAMEPLATE_MAX_DISTANCE, min_range
		end 			
		
	    return max_range, min_range 
	end, "UnitGUID"),
	CanInterract							= Cache:Pass(function(self, range, orBooleanInRange) 
		-- @return boolean  
		local unitID 						= self.UnitID
		local min_range 					= self(unitID):GetRange()
		
		return min_range > 0 and (min_range <= range or orBooleanInRange)	
	end, "UnitID"),
	CanInterrupt							= Cache:Pass(function(self, kickAble, auras, minX, maxX)
		-- @return boolean 
		-- Nill-able: kickAble, auras, minX, maxX
		local unitID 						= self.UnitID
		local castName, castStartTime, castEndTime, notInterruptable, spellID, isChannel = self(unitID):IsCasting()
		if castName and (not kickAble or not notInterruptable) then 
			if auras and self(unitID):HasBuffs(auras) > 0 then 
				return false 
			end 
			
			local GUID 						= UnitGUID(unitID)
			if not InfoCacheInterrupt[GUID] then 
				InfoCacheInterrupt[GUID] = {}
			end 
			
			if InfoCacheInterrupt[GUID].LastCast ~= castName then 
				InfoCacheInterrupt[GUID].LastCast 	= castName
				InfoCacheInterrupt[GUID].Timer 		= math_random(minX or 34, maxX or 68)				 
			end 
			
			local castPercent = ((TMW.time * 1000) - castStartTime) * 100 / (castEndTime - castStartTime)
			return castPercent >= InfoCacheInterrupt[GUID].Timer 
		end 	
	end, "UnitID"),
	CanCooperate							= Cache:Pass(function(self, otherunit)  
		-- @return boolean 
		local unitID 						= self.UnitID
		return UnitCanCooperate(unitID, otherunit)
	end, "UnitID"),		
	HasSpec									= Cache:Pass(function(self, specID)	
		-- @return boolean 
		-- Only PLAYER!
		local unitID 						= "player"
		if not UnitIsUnit(unitID, "player") then 
			error("Can't use Action.Unit(" .. (unitID or "unitID") .. "):HasSpec(" .. (specID or "") .. ") since field 'unitID' must be equal to 'player'")
			return 
		end 
		
		if type(specID) == "table" then        
			for i = 1, #specID do
				if specID[i] == A.PlayerSpec then 
					return true 
				end 
			end       
		else 
			return specID == A.PlayerSpec      
		end
	end, "UnitID"),
	HasFlags 								= Cache:Wrap(function(self) 
		-- @return boolean 
		local unitID 						= self.UnitID
	    return self(unitID):HasBuffs(AuraList.Flags) > 0 
	end, "UnitID"),
	Health									= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return CombatTracker:UnitHealth(unitID)
	end, "UnitID"),
	HealthMax								= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return CombatTracker:UnitHealthMax(unitID)
	end, "UnitID"),
	HealthDeficit							= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return self(unitID):HealthMax() - self(unitID):Health()
	end, "UnitID"),
	HealthDeficitPercent					= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return 100 - self(unitID):HealthPercent()
	end, "UnitID"),
	HealthPercent							= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
		if CombatTracker:UnitHasRealHealth(unitID) then 
			local maxHP						= UnitHealthMax(unitID)
			if maxHP == 0 then 
				return 0 					-- Fix beta / ptr "Division by zero"
			else 
				return UnitHealth(unitID) * 100 / maxHP
			end 
		end 
	    return UnitHealth(unitID)
	end, "UnitID"),
	HealthPercentLosePerSecond				= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
		local maxHP							= self(unitID):HealthMax()
		if maxHP == 0 then 
			return 0 						-- Fix beta / ptr "Division by zero"
		else 
			return math_max((self(unitID):GetDMG() * 100 / maxHP) - (self(unitID):GetHEAL() * 100 / maxHP), 0)
		end
	end, "UnitID"),
	HealthPercentGainPerSecond				= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
		local maxHP							= self(unitID):HealthMax()
		if maxHP == 0 then 
			return 0 						-- Fix beta / ptr "Division by zero"
		else 
			return math_max((self(unitID):GetHEAL() * 100 / maxHP) - (self(unitID):GetDMG() * 100 / maxHP), 0)
		end
	end, "UnitID"),
	Power									= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return UnitPower(unitID)
	end, "UnitID"),
	PowerType								= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return select(2, UnitPowerType(unitID))
	end, "UnitID"),
	PowerMax								= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return UnitPowerMax(unitID)
	end, "UnitID"),
	PowerDeficit							= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return self(unitID):PowerMax() - self(unitID):Power()
	end, "UnitID"),
	PowerDeficitPercent						= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return self(unitID):PowerDeficit() * 100 / self(unitID):PowerMax()
	end, "UnitID"),
	PowerPercent							= Cache:Pass(function(self)
		-- @return number 
		local unitID 						= self.UnitID
	    return self(unitID):Power() * 100 / self(unitID):PowerMax()
	end, "UnitID"),
	AuraTooltipNumber						= Cache:Wrap(function(self, spell, filter)
		-- @return number 
		-- Nill-able: filter
		local unitID 						= self.UnitID
		local spellName 
		if type(spell) == "number" then 
			spellName = A_GetSpellInfo(spell)
		else 
			spellName = spell
		end 
		
		if filter then 
			return AuraTooltipNumber(unitID, strlowerCache[spellName], filter) or 0
		else 
			local duration = AuraTooltipNumber(unitID, strlowerCache[spellName], "HELPFUL") or 0
			if duration == 0 then 
				duration = AuraTooltipNumber(unitID, strlowerCache[spellName], "HARMFUL") or 0
			end 
			return duration or 0
		end 
	end, "UnitGUID"),
	AuraVariableNumber						= Cache:Wrap(function(self, spell, filter)
		-- @return number 
		-- Nill-able: filter
		local unitID 						= self.UnitID
		local spellName 
		if type(spell) == "number" then 
			spellName = A_GetSpellInfo(spell)
		else 
			spellName = spell
		end 
		
		if filter then 
			return AuraVariableNumber(unitID, strlowerCache[spellName], filter) or 0
		else 
			local duration = AuraVariableNumber(unitID, strlowerCache[spellName], "HELPFUL") or 0
			if duration == 0 then 
				duration = AuraVariableNumber(unitID, strlowerCache[spellName], "HARMFUL") or 0
			end 
			return duration or 0
		end 
	end, "UnitGUID"),
	DeBuffCyclone 							= Cache:Pass(function(self)
		-- @return number 
		return 0 -- Right now no such effects, change Pass to Wrap if will be any in future!
	end, "UnitGUID"),	
	GetDeBuffInfo							= Cache:Pass(function(self, auraTable, caster)
		-- @return number, number, number, number 
		-- [1] rank
		-- [2] remain duration
		-- [3] total duration
		-- [4] stacks 
		-- auraTable is { [spellID or spellName] = rank, [18] = 1 }
		-- Nill-able: caster
		local unitID 						= self.UnitID		
		local filter
		if caster then 
			filter = "HARMFUL PLAYER"
		else 
			filter = "HARMFUL"
		end 
		
		local _, spellName, spellID, spellCount, spellDuration, spellExpirationTime	
		for i = 1, huge do			
			spellName, _, spellCount, _, spellDuration, spellExpirationTime, _,_,_, spellID = UnitAura(unitID, i, filter)
			
			if not spellName then 
				break
			elseif auraTable[spellID] then 
				return auraTable[spellID], spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time, spellDuration, spellCount
			elseif auraTable[spellName] then 
				return auraTable[spellName], spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time, spellDuration, spellCount
			end 
		end 
		
		return 0, 0, 0, 0
	end, "UnitID"),
	GetDeBuffInfoByName						= Cache:Pass(function(self, auraName, caster)
		-- @return number, number, number, number 
		-- [1] spellID
		-- [2] remain duration
		-- [3] total duration
		-- [4] stacks 
		-- auraName must be exactly @string 
		-- Nill-able: caster
		local unitID 						= self.UnitID		
		local filter
		if caster then 
			filter = "HARMFUL PLAYER"
		else 
			filter = "HARMFUL"
		end 
		
		local _, spellName, spellID, spellCount, spellDuration, spellExpirationTime	
		for i = 1, huge do			
			spellName, _, spellCount, _, spellDuration, spellExpirationTime, _,_,_, spellID = UnitAura(unitID, i, filter)
			
			if not spellName then 
				break
			elseif spellName == auraName then 
				return spellID, spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time, spellDuration, spellCount
			end 
		end 
		
		return 0, 0, 0, 0
	end, "UnitID"),
	IsDeBuffsLimited						= Cache:Pass(function(self)
		-- @return boolean, number 
		local unitID 						= self.UnitID	
		local auras 						= 0 
		
		local Name
		for i = 1, CONST.AURAS_MAX_LIMIT do			
			Name = UnitDebuff(unitID, i)
			
			if Name then					
				auras = auras + 1
			else
				break 
			end 
		end 
		
		return auras >= CONST.AURAS_MAX_LIMIT, auras
	end, "UnitID"), 
	--[[HasDeBuffs 								= Cache:Pass(function(self, spell, caster, byID)
		-- @return number, number 
		-- current remain, total applied duration
		-- Sorting method
		-- Nill-able: caster, byID
		local unitID 						= self.UnitID
        return self(unitID):SortDeBuffs(spell, caster, byID or IsMustBeByID[spell]) 
    end, "UnitID"),]]
	SortDeBuffs								= Cache:Wrap(function(self, spell, caster, byID)
		-- @return number, number 
		-- Returns sorted by highest and limited by 1-3 firstly found: current remain, total applied duration	
		-- Nill-able: caster, byID
		local unitID 						= self.UnitID		
		local filter
		if caster then 
			filter = "HARMFUL PLAYER"
		else 
			filter = "HARMFUL"
		end 
		local remain_dur, total_dur 		= 0, 0
		
		local c = 0
		local _, spellName, spellID, spellDuration, spellExpirationTime		
		for i = 1, huge do 
			spellName, _, _, _, spellDuration, spellExpirationTime, _, _, _, spellID = UnitAura(unitID, i, filter)
			
			if not spellName then 
				break 			
			elseif AssociativeTables[spell][byID and spellID or spellName] then 
				local current_dur = spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time
				if current_dur > remain_dur then 
					c = c + 1
					remain_dur = current_dur
					total_dur = spellDuration				
				
					if remain_dur == huge or c >= (type(spell) == "table" and 3 or 1) then 
						break 
					end 
				end			
			end 
		end 
		
		return remain_dur, total_dur    
    end, "UnitGUID"),
	HasDeBuffsStacks						= Cache:Wrap(function(self, spell, caster, byID)
		-- @return number
		-- Nill-able: caster, byID
		local unitID 						= self.UnitID
		local filter
		if caster then 
			filter = "HARMFUL PLAYER"
		else 
			filter = "HARMFUL"
		end 
		
		local _, spellName, spellID, spellCount		
		for i = 1, huge do 
			spellName, _, spellCount, _, _, _, _, _, _, spellID = UnitAura(unitID, i, filter)
			if not spellName then 
				break 			
			elseif AssociativeTables[spell][byID and spellID or spellName] then 
				return spellCount == 0 and 1 or spellCount			
			end 
		end 
		
		return 0
    end, "UnitGUID"),
	-- Pandemic Threshold
	PT										= Cache:Wrap(function(self, spell, debuff, byID)    
		-- @return boolean 
		-- Note: If duration remains <= 30% only for auras applied by @player
		-- Nill-able: debuff, byID
		local unitID 						= self.UnitID
		local filter
		if debuff then 
			filter = "HARMFUL PLAYER"
		else 
			filter = "HELPFUL PLAYER"
		end 
		
		local duration = 0
		local _, spellName, spellID, spellDuration, spellExpirationTime		
		for i = 1, huge do 
			spellName, _, _, _, spellDuration, spellExpirationTime, _, _, _, spellID = UnitAura(unitID, i, filter)
			if not spellName then 
				break 			
			elseif AssociativeTables[spell][byID and spellID or spellName] then 
				duration = spellExpirationTime == 0 and 1 or ((spellExpirationTime - TMW.time) / spellDuration)
				if duration <= 0.3 then 
					return true 
				end 
			end 
		end 
		
		return duration <= 0.3
    end, "UnitGUID"),
	GetBuffInfo								= Cache:Pass(function(self, auraTable, caster)
		-- @return number, number, number, number 
		-- [1] rank
		-- [2] remain duration
		-- [3] total duration
		-- [4] stacks 
		-- auraTable is { [spellID or spellName] = rank, [18] = 1 }
		-- Nill-able: caster
		local unitID 						= self.UnitID		
		local filter
		if caster then 
			filter = "HELPFUL PLAYER"
		else 
			filter = "HELPFUL"
		end 
		
		local _, spellName, spellID, spellCount, spellDuration, spellExpirationTime	
		for i = 1, huge do			
			spellName, _, spellCount, _, spellDuration, spellExpirationTime, _,_,_, spellID = UnitAura(unitID, i, filter)
			
			if not spellName then 
				break 
			elseif auraTable[spellID] then 
				return auraTable[spellID], spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time, spellDuration, spellCount
			elseif auraTable[spellName] then 
				return auraTable[spellName], spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time, spellDuration, spellCount
			end 
		end 
		
		return 0, 0, 0, 0
	end, "UnitID"),
	GetBuffInfoByName						= Cache:Pass(function(self, auraName, caster)
		-- @return number, number, number, number 
		-- spellID, remain duration, total duration, stacks 
		-- auraName must be exactly @string 
		-- Nill-able: caster
		local unitID 						= self.UnitID		
		local filter
		if caster then 
			filter = "HELPFUL PLAYER"
		else 
			filter = "HELPFUL"
		end 
		
		local _, spellName, spellID, spellCount, spellDuration, spellExpirationTime	
		for i = 1, huge do			
			spellName, _, spellCount, _, spellDuration, spellExpirationTime, _,_,_, spellID = UnitAura(unitID, i, filter)
			
			if not spellName then 
				break
			elseif spellName == auraName then 
				return spellID, spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time, spellDuration, spellCount
			end 
		end 
		
		return 0, 0, 0, 0
	end, "UnitID"),
	HasBuffs 								= Cache:Wrap(function(self, spell, caster, byID)
		-- @return number, number 
		-- current remain, total applied duration	
		-- Nill-able: caster, byID
		local unitID 						= self.UnitID	
		local filter -- default "HELPFUL"
		if caster then 
			filter = "HELPFUL PLAYER"
		end 

		local _, spellName, spellID, spellDuration, spellExpirationTime		
		for i = 1, huge do 
			spellName, _, _, _, spellDuration, spellExpirationTime, _, _, _, spellID = UnitAura(unitID, i, filter)
			if not spellName then 
				break  
			elseif AssociativeTables[spell][byID and spellID or spellName] then 
				return spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time, spellDuration
			end 
		end 
		
		return 0, 0
	end, "UnitGUID"),
	SortBuffs 								= Cache:Wrap(function(self, spell, caster, byID)
		-- @return number, number 
		-- Returns sorted by highest: current remain, total applied duration	
		-- Nill-able: caster, byID
		local unitID 						= self.UnitID	
		local filter -- default "HELPFUL"
		if caster then 
			filter = "HELPFUL PLAYER"
		end 
		local remain_dur, total_dur 		= 0, 0
		
		local _, spellName, spellID, spellDuration, spellExpirationTime		
		for i = 1, huge do 
			spellName, _, _, _, spellDuration, spellExpirationTime, _, _, _, spellID = UnitAura(unitID, i, filter)
			if not spellName then 
				break 			
			elseif AssociativeTables[spell][byID and spellID or spellName] then 
				local current_dur = spellExpirationTime == 0 and huge or spellExpirationTime - TMW.time
				if current_dur > remain_dur then 
					remain_dur, total_dur = current_dur, spellDuration
					if remain_dur == huge then 
						break 
					end 
				end				
			end 
		end 
		
		return remain_dur, total_dur		
	end, "UnitGUID"),
	HasBuffsStacks 							= Cache:Wrap(function(self, spell, caster, byID)
		-- @return number 
		-- Nill-able: caster, byID
		local unitID 						= self.UnitID	
		local filter -- default "HELPFUL"
		if caster then 
			filter = "HELPFUL PLAYER"
		end 
		
		local _, spellName, spellID, spellCount		
		for i = 1, huge do 
			spellName, _, spellCount, _, _, _, _, _, _, spellID = UnitAura(unitID, i, filter)
			if not spellName then 
				break 			
			elseif AssociativeTables[spell][byID and spellID or spellName] then 
				return spellCount == 0 and 1 or spellCount			
			end 
		end 
		
		return 0
	end, "UnitGUID"),
	IsFocused 								= Cache:Wrap(function(self, burst, deffensive, range, isMelee)
		-- @return boolean
		-- ATTENTION:
		-- 'burst' must be number 			or nil 
		-- 'deffensive' must be number 		or nil 	-- will check deffensive buffs on unitID (not focuser e.g. not member\arena)
		-- 'range' must be number 			or nil 
		-- 'isMelee' must be true 			or nil 
		-- Nill-able: burst, deffensive, range, isMelee
		local unitID 						= self.UnitID

		if self(unitID):IsEnemy() then
			if TeamCacheFriendly.Type then 
				local member
				for i = 1, TeamCacheFriendly.MaxSize do 
					member = TeamCacheFriendlyIndexToPLAYERs[i]
					if  member
					and not UnitIsUnit(member, "player")
					and UnitIsUnit(member .. "target", unitID) 					
					and ((not isMelee and self(member):IsDamager()) or (isMelee and self(member):IsMelee()))
					and (not burst 		or 	self(member):HasBuffs("DamageBuffs") >= burst) 
					and (not deffensive or 	self(unitID):HasBuffs("DeffBuffs") <= deffensive)
					and (not range 		or 	self(member):GetRange() <= range) 					
					then 
						return true 
					end 
				end 
			end 
		else
			local arena
			if TeamCacheEnemy.Type then 				
				for i = 1, TeamCacheEnemy.MaxSize do 
					arena = TeamCacheEnemyIndexToPLAYERs[i]
					if arena
					and UnitIsUnit(arena .. "target", unitID) 
					and ((not isMelee and self(arena):IsDamager()) or (isMelee and self(arena):IsMelee()))
					and (not burst 		or	self(arena):HasBuffs("DamageBuffs") >= burst) 
					and (not deffensive or 	self(unitID):HasBuffs("DeffBuffs") <= deffensive)
					and (not range 		or	self(arena):GetRange() <= range)
					then 
						return true 
					end 
				end 
			else 
				for arena in pairs(ActiveUnitPlates) do  
					if UnitIsUnit(arena .. "target", unitID) 
					and ((not isMelee and self(arena):IsDamager()) or (isMelee and self(arena):IsMelee()))
					and (not burst 		or	self(arena):HasBuffs("DamageBuffs") >= burst) 
					and (not deffensive or 	self(unitID):HasBuffs("DeffBuffs") <= deffensive)
					and (not range 		or	self(arena):GetRange() <= range)
					then 
						return true 
					end 
				end 
			end 
		end 
	end, "UnitGUID"),
	IsExecuted 								= Cache:Pass(function(self)
		-- @return boolean
		local unitID 						= self.UnitID

		return self(unitID):TimeToDieX(20) <= A_GetGCD() + A_GetCurrentGCD()
	end, "UnitID"),
	UseBurst 								= Cache:Wrap(function(self, pBurst)
		-- @return boolean
		-- Nill-able: pBurst
		local unitID 						= self.UnitID

		if self(unitID):IsEnemy() then
			return self(unitID):IsPlayer() and 
			(
				A.Zone == str_none or 
				self(unitID):TimeToDieX(25) <= A_GetGCD() * 4 or
				(
					self(unitID):IsHealer() and 
					(
						(
							self(unitID):CombatTime() > 5 and 
							self(unitID):TimeToDie() <= 10 and 
							self(unitID):HasBuffs("DeffBuffs") == 0                      
						) or
						self(unitID):HasDeBuffs("Silenced") >= A_GetGCD() * 2 or 
						self(unitID):HasDeBuffs("Stuned") >= A_GetGCD() * 2                         
					)
				) or 
				self(unitID):IsFocused(true) or 
				A_EnemyTeam("HEALER"):GetCC() >= A_GetGCD() * 3 or
				(
					pBurst and 
					self("player"):HasBuffs("DamageBuffs") >= A_GetGCD() * 3
				)
			)       
		elseif A.IamHealer then 
			-- For HealingEngine as Healer
			return self(unitID):IsPlayer() and 
			(
				self(unitID):IsExecuted() or
				(
					A.IsInPvP and 
					(
						(
							self(unitID):HasFlags() and                                         
							self(unitID):CombatTime() > 0 and 
							self(unitID):GetRealTimeDMG() > 0 and 
							self(unitID):TimeToDie() <= 14 and 
							(
								self(unitID):TimeToDie() <= 8 or 
								self(unitID):HasBuffs("DeffBuffs") < 1                         
							)
						) or 
						(
							self(unitID):IsFocused(true) and 
							(
								self(unitID):TimeToDie() <= 10 or 
								self(unitID):HealthPercent() <= 70
							)
						) 
					)
				)
			)                   
		end 
	end, "UnitGUID"),
	UseDeff 								= Cache:Wrap(function(self)
		-- @return boolean
		local unitID 						= self.UnitID
		return 
		(
			self(unitID):IsExecuted() or 
			self(unitID):IsFocused(4) or 
			(
				self(unitID):TimeToDie() < 8 and 
				self(unitID):IsFocused() 
			) 
		) 			
	end, "UnitGUID"),	
})	
A.Unit.HasDeBuffs = A.Unit.SortDeBuffs

function A.Unit:New(UnitID, Refresh)
	if not UnitID then 
		local error_snippet = debugstack():match("%p%l+%s\"?%u%u%u%s%u%l.*")
		if error_snippet then 
			error("Unit.lua Action.Unit():.. was used with 'nil' unitID. Found problem in TMW snippet here:" .. error_snippet, 0)
		else 
			error("Unit.lua Action.Unit():.. was used with 'nil' unitID. Failed to find TMW snippet stack error. Below must be shown level of stack 1.", 1)
		end 		
	end 
	self.UnitID 	= UnitID
	self.Refresh 	= Refresh
end

local function CheckUnitByRole(ROLE, unitID)
	return  not ROLE 													or 
			(ROLE == "HEALER" 			and A_Unit(unitID):IsHealer()) 	or 
			(ROLE == "TANK"   			and A_Unit(unitID):IsTank()) 	or 
			(ROLE == "DAMAGER" 			and A_Unit(unitID):IsDamager()) or 
			(ROLE == "DAMAGER_MELEE"	and A_Unit(unitID):IsMelee())	or 
			(ROLE == "DAMAGER_RANGE"	and A_Unit(unitID):IsDamager() and not A_Unit(unitID):IsMelee())
end 

-------------------------------------------------------------------------------
-- API: FriendlyTeam 
-------------------------------------------------------------------------------
A.FriendlyTeam = PseudoClass({
	-- Note: Return field 'unitID' will return "none" if is not found
	-- Note: Classic has included "player" in any way 
	GetUnitID 								= Cache:Wrap(function(self, range)
		-- @return string 
		-- Nill-able: range
		local ROLE 							= self.ROLE
		local member
		
		if TeamCacheFriendly.Type then 
			for i = 1, TeamCacheFriendly.MaxSize do 
				member = TeamCacheFriendlyIndexToPLAYERs[i]
				if member and CheckUnitByRole(ROLE, member) and not A_Unit(member):IsDead() and A_Unit(member):InRange() and (not range or A_Unit(member):GetRange() <= range) then 
					return member
				end 
			end 
		end  
		
		return str_none 
	end, "ROLE"),
	GetCC 									= Cache:Wrap(function(self, spells)
		-- @return number, unitID 
		-- Nill-able: spells
		local ROLE 							= self.ROLE
		local duration, member
		
		if TeamCacheFriendly.Size <= 1 then 
			member = "player"
			if CheckUnitByRole(ROLE, member) then 
				if spells then 
					duration = A_Unit(member):HasDeBuffs(spells) 
					if duration ~= 0 then 
						return duration, member					
					end 
				else 
					duration = A_Unit(member):InCC()
					if duration ~= 0 then 
						return duration, member					
					end 
				end 
			end 
			
			return 0, str_none
		end 		
		
		for i = 1, TeamCacheFriendly.MaxSize do
			member = TeamCacheFriendlyIndexToPLAYERs[i]
			if member and CheckUnitByRole(ROLE, member) then 
				if spells then 
					duration = A_Unit(member):HasDeBuffs(spells) 
				else
					duration = A_Unit(member):InCC()
				end 
				
				if duration ~= 0 then 
					return duration, member 
				end 
			end 
		end
		
		if TeamCacheFriendly.Type ~= "raid" and CheckUnitByRole(ROLE, "player") then
			duration = A_Unit("player"):HasDeBuffs(spells) 
			if duration ~= 0 then 
				return duration, "player" 
			end
		end 

		return 0, str_none
	end, "ROLE"),
	GetBuffs 								= Cache:Wrap(function(self, spells, range, source)
		-- @return number, unitID 
		-- Nill-able: range, source
		local ROLE 							= self.ROLE
		local duration, member
		
		if TeamCacheFriendly.Size <= 1 then 
			if CheckUnitByRole(ROLE, "player") then 
				duration = A_Unit("player"):HasBuffs(spells, source)
				if duration ~= 0 then 
					return duration, "player"
				end  
			end 
			return 0, str_none			 
		end 	

		for i = 1, TeamCacheFriendly.MaxSize do
			member = TeamCacheFriendlyIndexToPLAYERs[i]				
			if member and CheckUnitByRole(ROLE, member) and A_Unit(member):InRange() and (not range or A_Unit(member):GetRange() <= range) then
				duration = A_Unit(member):HasBuffs(spells, source)                     				 
				if duration ~= 0 then 
					return duration, member 
				end      
			end 
		end  
		
		if TeamCacheFriendly.Type ~= "raid" and CheckUnitByRole(ROLE, "player") then
			duration = A_Unit("player"):HasBuffs(spells) 
			if duration ~= 0 then 
				return duration, "player" 
			end
		end 		
		
		return 0, str_none
	end, "ROLE"),
	GetDeBuffs		 						= Cache:Wrap(function(self, spells, range)
		-- @return number, unitID 
		-- Nill-able: range
		local ROLE 							= self.ROLE
		local duration, member
		
		if TeamCacheFriendly.Size <= 1 then 
			if CheckUnitByRole(ROLE, "player") then 
				duration = A_Unit("player"):HasDeBuffs(spells)
				if duration ~= 0 then 
					return duration, "player"
				end 
			end 
			return 0, str_none			 
		end 		

		for i = 1, TeamCacheFriendly.MaxSize do
			member = TeamCacheFriendlyIndexToPLAYERs[i]
			if member and CheckUnitByRole(ROLE, member) and A_Unit(member):InRange() and (not range or A_Unit(member):GetRange() <= range) then
				duration = A_Unit(member):HasDeBuffs(spells)                     				 
				if duration ~= 0 then 
					return duration, member
				end      
			end 
		end  
		
		if TeamCacheFriendly.Type ~= "raid" and CheckUnitByRole(ROLE, "player") then
			duration = A_Unit("player"):HasDeBuffs(spells) 
			if duration ~= 0 then 
				return duration, "player" 
			end
		end 			
		
		return 0, str_none
	end, "ROLE"),
	GetTTD 									= Cache:Wrap(function(self, count, seconds, range)
		-- @return boolean, counter, unitID 
		-- Nill-able: range
		local ROLE 							= self.ROLE
		local member
		
		if TeamCacheFriendly.Size <= 1 then 
			if CheckUnitByRole(ROLE, "player") and A_Unit("player"):TimeToDie() <= seconds then
				return 1 >= count, 1, "player"
			end  
			
			return false, 0, str_none
		end 		
		
		local counter = 0
		local lastmember
		for i = 1, TeamCacheFriendly.MaxSize do
			member = TeamCacheFriendlyIndexToPLAYERs[i]
			if member and CheckUnitByRole(ROLE, member) and A_Unit(member):InRange() and (not range or A_Unit(member):GetRange() <= range) and A_Unit(member):TimeToDie() <= seconds then
				counter = counter + 1     
				if counter >= count then 
					return true, counter, member
				end
				lastmember = member
			end                        
		end  
		
		if TeamCacheFriendly.Type ~= "raid" and CheckUnitByRole(ROLE, "player") and A_Unit("player"):TimeToDie() <= seconds then
			counter = counter + 1 
			if counter >= count then 
				return true, counter, "player"
			end
			lastmember = "player"
		end 			
		
		return false, counter, lastmember or str_none
	end, "ROLE"),
	AverageTTD 								= Cache:Wrap(function(self, range)
		-- @return number, number 
		-- Returns average time to die of valid players in group, count of valid players in group
		-- Nill-able: range
		local ROLE 							= self.ROLE
		local member
		
		if TeamCacheFriendly.Size <= 1 then 
			if CheckUnitByRole(ROLE, "player") then 
				return A_Unit("player"):TimeToDie(), 1
			end 
			return 0, 0
		end 
		
		local value, members				= 0, 0
		for i = 1, TeamCacheFriendly.MaxSize do
			member = TeamCacheFriendlyIndexToPLAYERs[i]
			if member and CheckUnitByRole(ROLE, member) and A_Unit(member):InRange() and (not range or A_Unit(member):GetRange() <= range) then
				value = value + A_Unit(member):TimeToDie()
				members = members + 1
			end                        
		end  
		
		if TeamCacheFriendly.Type ~= "raid" and CheckUnitByRole(ROLE, "player") then
			value = value + A_Unit("player"):TimeToDie()
			members = members + 1
		end 	
		
		if members > 0 then 
			value = value / members
		end 
		
		return value, members
	end, "ROLE"),	
	MissedBuffs 							= Cache:Wrap(function(self, spells, source)
		-- @return boolean, unitID 
		-- Nill-able: source
		local ROLE 							= self.ROLE
		local member
		
		if TeamCacheFriendly.Size <= 1 then 
			if CheckUnitByRole(ROLE, "player") then 
				if A_Unit("player"):HasBuffs(spells, source) == 0 then 
					return true, "player"
				end 
			end 
			return false, str_none 			 
		end 
		
		for i = 1, TeamCacheFriendly.MaxSize do
			member = TeamCacheFriendlyIndexToPLAYERs[i]
			if member and CheckUnitByRole(ROLE, member) and A_Unit(member):InRange() and not A_Unit(member):IsDead() and A_Unit(member):HasBuffs(spells, source) == 0 then
				return true, member 
			end 
		end		
		
		if TeamCacheFriendly.Type ~= "raid" and CheckUnitByRole(ROLE, "player") and A_Unit("player"):HasBuffs(spells, source) == 0 then
			return true, "player"
		end 		
		
		return false, str_none 
	end, "ROLE"),
	PlayersInCombat 						= Cache:Wrap(function(self, range, combatTime)
		-- @return boolean, unitID 
		-- Nill-able: range, combatTime
		local ROLE 							= self.ROLE
		local member
		
		if TeamCacheFriendly.Size <= 1 then 
			if CheckUnitByRole(ROLE, "player") then 
				if A_Unit("player"):CombatTime() > 0 and (not combatTime or A_Unit("player"):CombatTime() <= combatTime) then 
					return true, "player"
				end 
			end 
			return false, str_none 			 
		end 
		
		for i = 1, TeamCacheFriendly.MaxSize do
			member = TeamCacheFriendlyIndexToPLAYERs[i]
			if member and CheckUnitByRole(ROLE, member) and A_Unit(member):InRange() and (not range or A_Unit(member):GetRange() <= range) and A_Unit(member):CombatTime() > 0 and (not combatTime or A_Unit(member):CombatTime() <= combatTime) then
				return true, member
			end 
		end 

		if TeamCacheFriendly.Type ~= "raid" and CheckUnitByRole(ROLE, "player") and A_Unit("player"):CombatTime() > 0 and (not combatTime or A_Unit("player"):CombatTime() <= combatTime) then
			return true, "player"
		end 			
		
		return false, str_none
	end, "ROLE"),
	HealerIsFocused 						= Cache:Wrap(function(self, burst, deffensive, range, isMelee)
		-- @return boolean, unitID 
		-- Nill-able: burst, deffensive, range, isMelee
		-- Note: No 'ROLE' here 
		local ROLE 							= self.ROLE
		local member
		
		if TeamCacheFriendly.Type then 
			for i = 1, TeamCacheFriendly.MaxSize do
				member = TeamCacheFriendlyIndexToPLAYERs[i]
				if member and CheckUnitByRole("HEALER", member) and A_Unit(member):InRange() and A_Unit(member):IsFocused(burst, deffensive, range, isMelee) then
					return true, member 
				end 
			end		
		end 				
		
		return false, str_none
	end, "ROLE"),
})

function A.FriendlyTeam:New(ROLE, Refresh)
    self.ROLE = ROLE
    self.Refresh = Refresh or 0.05
end

-------------------------------------------------------------------------------
-- API: EnemyTeam 
-------------------------------------------------------------------------------
A.EnemyTeam = PseudoClass({
	-- Note: Return field 'unitID' will return "none" if is not found
	GetUnitID 								= Cache:Wrap(function(self, range)
		-- @return string  
		-- Nill-able: range
		local ROLE 							= self.ROLE
		local arena

		if TeamCacheEnemy.Type then 
			for i = 1, TeamCacheEnemy.MaxSize do 
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and CheckUnitByRole(ROLE, arena) and not A_Unit(arena):IsDead() and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) then 
					return arena
				end 
			end 
		end  
		
		return str_none 
	end, "ROLE"),
	GetCC 									= Cache:Wrap(function(self, spells)
		-- @return number, unitID 
		-- Note: If 'ROLE' is "HEALER" then it will except healers if they are in @target
		-- Nill-able: spells
		local ROLE 							= self.ROLE
		local duration, arena
		
		if TeamCacheEnemy.Type then 
			for i = 1, TeamCacheEnemy.MaxSize do 
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and CheckUnitByRole(ROLE, arena) then 
					if ROLE ~= "HEALER" or not UnitIsUnit(arena, "target") then 
						if spells then 
							duration = A_Unit(arena):HasDeBuffs(spells) 
							if duration ~= 0 then 
								return duration, arena
							end 
						else
							duration = A_Unit(arena):InCC()
							if duration ~= 0 then 
								return duration, arena 
							end 
						end 
					end 
				end 
			end 
		end  		
		
		return 0, str_none
	end, "ROLE"),
	GetBuffs 								= Cache:Wrap(function(self, spells, range, source)
		-- @return number, unitID 
		-- Nill-able: range, source
		local ROLE 							= self.ROLE
		local duration, arena 
		
		if TeamCacheEnemy.Type then 
			for i = 1, TeamCacheEnemy.MaxSize do 
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and CheckUnitByRole(ROLE, arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) then 
					duration = A_Unit(arena):HasBuffs(spells, source)    
					if duration ~= 0 then 
						return duration, arena
					end 
				end 
			end 
		end  
		
		return 0, str_none
	end, "ROLE"),
	GetDeBuffs 								= Cache:Wrap(function(self, spells, range)
		-- @return number, unitID 
		-- Nill-able: range
		local ROLE 							= self.ROLE
		local duration, arena 
		
		if TeamCacheEnemy.Type then 
			for i = 1, TeamCacheEnemy.MaxSize do 
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and CheckUnitByRole(ROLE, arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) then 
					duration = A_Unit(arena):HasDeBuffs(spells)  
					if duration ~= 0 then 
						return duration, arena
					end 
				end 
			end 
		end  		
		
		return 0, str_none 
	end, "ROLE"),
	GetTTD 									= Cache:Pass(function(self, count, seconds, range)
		-- @return boolean, counter, unitID 
		-- Nill-able: range
		local ROLE 							= self.ROLE		
		local counter = 0
		local arena, lastarena
		
		if TeamCacheEnemy.Type then
			for i = 1, TeamCacheEnemy.MaxSize do
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and CheckUnitByRole(ROLE, arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) and A_Unit(arena):TimeToDie() <= seconds then
					counter = counter + 1     					
					if counter >= count then 
						return true, counter, arena
					end
					lastarena = arena        
				end 
			end  
		end   	
		
		return false, counter, lastarena or str_none
	end, "ROLE"),
	AverageTTD 								= Cache:Pass(function(self, range)
		-- @return number, number
		-- Returns average time to die of valid players, count of valid players
		-- Nill-able: range
		local ROLE 							= self.ROLE
		local value, members				= 0, 0
		
		if TeamCacheEnemy.Type then
			for i = 1, TeamCacheEnemy.MaxSize do
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and CheckUnitByRole(ROLE, arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) then
					value = value + A_Unit(arena):TimeToDie()
					arenas = arenas +  1     
				end 
			end  
		end   	
		
		if arenas > 0 then 
			value = value / arenas
		end 
		
		return value, arenas
	end, "ROLE"),
	IsBreakAble 							= Cache:Wrap(function(self, range)
		-- @return boolean, unitID 
		-- Nill-able: range
		local ROLE 							= self.ROLE
		local arena 
				
		if TeamCacheEnemy.Type then 
			for i = 1, TeamCacheEnemy.MaxSize do 
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and CheckUnitByRole(ROLE, arena) and not UnitIsUnit(arena, "target") and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) and A_Unit(arena):HasDeBuffs("BreakAble") ~= 0 then 
					return true, arena						 
				end 
			end 			  				
		else
			for arena in pairs(ActiveUnitPlates) do               
				if A_Unit(arena):IsPlayer() and CheckUnitByRole(ROLE, arena) and not UnitIsUnit("target", arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) and A_Unit(arena):HasDeBuffs("BreakAble") ~= 0 then
					return true, arena	
				end            
			end  			 
		end 
		
		return false, str_none
	end, "ROLE"),
	PlayersInRange 							= Cache:Wrap(function(self, stop, range)
		-- @return boolean, number, unitID 
		-- Nill-able: stop, range
		local ROLE 							= self.ROLE
		local count 						= 0 
		local arena
		
		if TeamCacheEnemy.Type then
			for i = 1, TeamCacheEnemy.Size do 
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and CheckUnitByRole(ROLE, arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) then 
					count = count + 1 	
					if not stop or count >= stop then 
						return true, count, arena 				 						
					end 
				end 
			end 					 
		else
			for arena in pairs(ActiveUnitPlates) do                 
				if A_Unit(arena):IsPlayer() and CheckUnitByRole(ROLE, arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) then
					count = count + 1 	
					if not stop or count >= stop then 
						return true, count, arena 				 						
					end 
				end         
			end   
		end 
		
		return false, count, arena or str_none 
	end, "ROLE"),
	FocusingUnitIDByClasses					= Cache:Wrap(function(self, unitID, stop, range, ...)
		-- @return boolean, number, who focusing (unitID)
		-- Nill-able: stop, range
		local ROLE 							= self.ROLE
		local count 						= 0 
		local arena, class
		
		if TeamCacheEnemy.Type then
			for i = 1, TeamCacheEnemy.Size do 
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena and UnitIsUnit(arena .. "target", unitID) and CheckUnitByRole(ROLE, arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) then 
					for i = 1, select("#", ...) do 
						class = select(i, ...)
						if A_Unit(arena):Class() == class then 
							count = count + 1 	
							if not stop or count >= stop then 
								return true, count, arena 				 						
							end 
							break 
						end 
					end
				end 
			end 					 
		else
			for arena in pairs(ActiveUnitPlates) do                 
				if A_Unit(arena):IsPlayer() and UnitIsUnit(arena .. "target", unitID) and CheckUnitByRole(ROLE, arena) and (not range or (A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= range)) then
					for i = 1, select("#", ...) do 
						class = select(i, ...)
						if A_Unit(arena):Class() == class then 
							count = count + 1 	
							if not stop or count >= stop then 
								return true, count, arena 				 						
							end 
							break 
						end 
					end
				end         
			end   
		end 
		
		return false, count, arena or str_none 
	end, "ROLE"),				
	-- [[ Without ROLE argument ]] 
	HasInvisibleUnits 						= Cache:Pass(function(self, checkVisible)
		-- @return boolean, unitID, unitClass
		-- Nill-able: checkVisible
		local arena, class
		
		for i = 1, TeamCacheEnemy.MaxSize do 
			arena = TeamCacheEnemyIndexToPLAYERs[i]
			if arena and not A_Unit(arena):IsDead() then
				class = A_Unit(arena):Class()
				if (class == "ROGUE" or class == "DRUID") and (not checkVisible or not A_Unit(arena):IsVisible()) then 
					return true, arena, class 
				end
			end 
		end 		 
		 
		return false, str_none, str_none
	end, "ROLE"), 
	IsTauntPetAble 							= Cache:Pass(function(self, object, range)
		-- @return boolean, unitID
		-- Nill-able: range
		if TeamCacheEnemy.Size > 0 then 
			local pet
			for i = 1, (TeamCacheEnemy.MaxSize >= 10 and 10 or TeamCacheEnemy.MaxSize) do -- Retail 3, Classic 10
				pet = TeamCacheEnemyIndexToPETs[i]
				if pet then 
					if not object or object:IsInRange(pet) then 
						return true, pet 
					end 
				end              
			end  
		end
		
		return false, str_none
	end, "ROLE"),
	IsCastingBreakAble 						= Cache:Pass(function(self, offset)
		-- @return boolean, unitID
		-- Nill-able: offset
		local arena 
		
		for i = 1, TeamCacheEnemy.MaxSize do 
			arena = TeamCacheEnemyIndexToPLAYERs[i]
			if arena then 
				local _, castRemain, _, _, castName = A_Unit(arena):CastTime()
				if castRemain > 0 and castRemain <= (offset or 0.5) then
					for _, spell in ipairs(AuraList.Premonition) do 
						if A_GetSpellInfo(spell[1]) == castName and A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= spell[2] then 
							return true, arena
						end 
					end 
				end
			end 
		end
 
		return false, str_none
	end, "ROLE"),
	IsReshiftAble 							= Cache:Pass(function(self, offset)
		-- @return boolean, unitID
		-- Nill-able: offset
		local arena 
		
		if not A_Unit("player"):IsFocused("MELEE") then 
			for i = 1, TeamCacheEnemy.MaxSize do 
				arena = TeamCacheEnemyIndexToPLAYERs[i]
				if arena then 
					local _, castRemain, _, _, castName = A_Unit(arena):CastTime()
					if castRemain > 0 and castRemain <= A_GetCurrentGCD() + A_GetGCD() + (offset or 0.05) then 
						for _, spell in ipairs(AuraList.Reshift) do 
							if A_GetSpellInfo(spell[1]) == castName and A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= spell[2] then 
								return true, arena
							end
						end 
					end
				end 
			end
		end
		
		return false, str_none
	end, "ROLE"), 
	IsPremonitionAble 						= Cache:Pass(function(self, offset)
		-- @return boolean, unitID
		-- Nill-able: offset
		local arena 
		
		for i = 1, TeamCacheEnemy.MaxSize do 
			arena = TeamCacheEnemyIndexToPLAYERs[i]
			if arena then 
				local _, castRemain, _, _, castName = A_Unit(arena):CastTime()
				if castRemain > 0 and castRemain <= A_GetGCD() + (offset or 0.05) then 
					for _, spell in ipairs(AuraList.Premonition) do 
						if A_GetSpellInfo(spell[1]) == castName and A_Unit(arena):GetRange() > 0 and A_Unit(arena):GetRange() <= spell[2] then 
							return true, arena
						end
					end 
				end
			end 
		end
			
		return false, str_none
	end, "ROLE"),
})

function A.EnemyTeam:New(ROLE, Refresh)
    self.ROLE = ROLE
    self.Refresh = Refresh or 0.05          
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local EventInfo 						= {
	["UNIT_DIED"] 						= "RESET",
	["UNIT_DESTROYED"]					= "RESET",
	["UNIT_DISSIPATES"]					= "RESET",
	["PARTY_KILL"] 						= "RESET",
	["SPELL_INSTAKILL"] 				= "RESET",
}
Listener:Add("ACTION_EVENT_UNIT", "COMBAT_LOG_EVENT_UNFILTERED", 		function(...)
	local _, EVENT, _, _, _, _, _, DestGUID = CombatLogGetCurrentEventInfo() 
	if EventInfo[EVENT] == "RESET" then 
		InfoCacheMoveIn[DestGUID] 		= nil 
		InfoCacheMoveOut[DestGUID] 		= nil 
		InfoCacheMoving[DestGUID]		= nil 
		InfoCacheStaying[DestGUID]		= nil 
		InfoCacheInterrupt[DestGUID]	= nil 
	end 
end)

Listener:Add("ACTION_EVENT_UNIT", "PLAYER_REGEN_ENABLED", 				function()
	if A.Zone ~= "pvp" and not A.IsInDuel then 
		for _, tfunc in pairs(Cache.bufer) do 
			for keyArg, tkeyArg in pairs(tfunc) do 
				if TMW.time - tkeyArg.t > 10 then 
					tfunc[keyArg] = nil 
				end 
			end			
		end 
		wipe(InfoCacheMoveIn)
		wipe(InfoCacheMoveOut)
		wipe(InfoCacheMoving)
		wipe(InfoCacheStaying)
		wipe(InfoCacheInterrupt)
	end 
end)

Listener:Add("ACTION_EVENT_UNIT", "PLAYER_REGEN_DISABLED", 				function()
	-- Need leave slow delay to prevent reset Data which was recorded before combat began for flyout spells, otherwise it will cause a bug
	if CombatTracker:GetSpellLastCast("player", A.LastPlayerCastName) > 1.5 and A.Zone ~= "pvp" and not A.IsInDuel and not Player:IsStealthed() and Player:CastTimeSinceStart() > 5 then 
		wipe(InfoCacheMoveIn)
		wipe(InfoCacheMoveOut)
		wipe(InfoCacheMoving)
		wipe(InfoCacheStaying)	
		wipe(InfoCacheInterrupt)
	end 
end)

TMW:RegisterCallback("TMW_ACTION_ENTERING",								function(event, subevent)
	if subevent ~= "UPDATE_INSTANCE_INFO" then 
		for _, tfunc in pairs(Cache.bufer) do 
			for keyArg, tkeyArg in pairs(tfunc) do 
				if TMW.time - tkeyArg.t > 10 then 
					tfunc[keyArg] = nil 
				end 
			end			
		end 
		wipe(InfoCacheMoveIn)
		wipe(InfoCacheMoveOut)
		wipe(InfoCacheMoving)
		wipe(InfoCacheStaying)	
		wipe(InfoCacheInterrupt)
	end 
end)