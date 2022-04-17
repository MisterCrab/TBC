-- DESCRIPTION:
--    This is incredible flexibility module:
--	  --[[ Security ]]--
--	  - Contains protection against session reset on copying, renaming, overwritting, sharing profile
--	  - Contains protection against changing local time on computer
--	  - Contains protection against modifying session through public API
--
--	  --[[ Privacy ]]--
--	  - Features copyright against other devs as base of profile, or just as a name proof
--	  - Features with cryptographic session authentication for users (optional)
--	  - Authentication is attached to user's b.tag obtained through blake3 hash encrypted with dev's key which is retrived from each dev as unique 256-bit derived key
--
--	  --[[ Supports ]]--
--	  - Supports unique exact expiration date and time for each user
--	  - Supports unique trial one-time use session for each user, each profile has own startup time
-- 	  - Supports multiple ProfileSession:Setup() call even from different snippets, therefore it's unnecessary to hold it in globals
--	  - Supports error handlers for devs on attempt to incorrectly use public API
--
--	  --[[ UI ]]--
--	  - Displays visual information: 
--		- Remaning profile's session time in "DD:HH:MM:SS" format in the main UI 
--		- User status (e.g. trial, full or not authorized) in the main UI
--	   	- Counter from 300 until 0 seconds before expiration in the chat 
--	  - Drawn native UI with panels:
--		- Dev panel shows options to set name and secure word to generate dev_key 
--		- User panel shows user_key and message when session expired or when user is not authorized to use profile 
--	  - Allowed for modification by devs


local _G, setmetatable, getmetatable, select, error, rawset, rawget, type, pairs, assert = 
	  _G, setmetatable, getmetatable, select, error, rawset, rawget, type, pairs, assert

local message				= _G.message	  
local BNGetInfo				= _G.BNGetInfo
local NewTimer				= _G.C_Timer.NewTimer
local NewTicker				= _G.C_Timer.NewTicker

local time 					= _G.time 
local date 					= _G.date

local math 		 			= _G.math 
local math_max				= math.max
local math_abs				= math.abs

local string 				= _G.string
local strsplittable			= _G.strsplittable
local format 				= string.format

local TMW 					= _G.TMW
local Env					= TMW.CNDT.Env

local A 					= _G.Action
local StdUi					= A.StdUi
local GetLocalization 		= A.GetLocalization
local GetCL			 		= A.GetCL
local Hide 					= A.Hide
local Print 				= A.Print
local toStr 				= A.toStr
local toNum 				= A.toNum
local Utils					= A.Utils
local blake3_derive_key		= Utils.blake3_derive_key
local hex_to_bin			= Utils.hex_to_bin
local blake3				= Utils.blake3


local metatable; metatable = {
	__index = function(t, k)
		if rawget(t, k) == nil then 
			rawset(t, k, setmetatable({}, metatable))
			return t[k]
		end
	end,
}
local private = {
	cache 		= setmetatable({}, metatable),
	data 		= setmetatable({}, metatable),
	tObjectTime = {},
	indexToName = {
		[1] = "year",
		[2] = "month",
		[3] = "day",
		[4] = "hour",
		[5] = "min",
		[6] = "sec",
		[7] = "undefined",
	},
	affected_profiles = {},	-- user_key:@string 'dev_key'
	disabled_profiles = {}, -- profile_name:@boolean true/false
}

function private:GetDate(date_text, current_seconds)
	-- @return: number - UTC format
	local t = strsplittable("-", date_text)
	
	-- trial
	if t[1] == "trial" then 
		return current_seconds + (toNum(t[2]) * 86400) --> UTC seconds + (days to seconds)
	end 
	
	-- member
	local tObjectTime = self.tObjectTime
	local indexToName = self.indexToName	
	for i = 1, 6 do 
		tObjectTime[indexToName[i]] = toNum(t[i])
	end  
	
	return time(date("!*t", time(tObjectTime))) --> GMT table to GMT seconds => GMT seconds to UTC table => UTC table to UTC seconds 
end 

function private:RunSession()
	local timerObj = self.timerObj
	if (not timerObj or timerObj:IsCancelled()) and self.session / 86400 < 49.7 then --> game has bug called "49.7 days bug" causes C-stack overflow. Anyway game resets every week, so session will be properly restarted anyway.
		self.timerObj = NewTimer(self.session + 1, function(this)
			private:CancelSession()
			private:ShutDownSession()
		end)

		private.timerObj.func = function(this, counter)
			local counter = counter or this._remainingIterations 
			local REMAINING = (self.locale and (self.locale.REMAINING[GetCL()] or self.locale.REMAINING["enUS"])) or GetLocalization().PROFILESESSION.REMAINING
			Print(format(REMAINING, private.profile or A.CurrentProfile, counter))
		end
		
		if self.session > 300 then 
			self.timerObj.notifyStartUp = NewTimer(self.session - 300, function(this)
				private.timerObj.func(nil, 300)
				private.timerObj.notifyObj = NewTicker(1, private.timerObj.func, 299)
			end)
		else 
			private.timerObj.func(nil, self.session)
			private.timerObj.notifyObj = NewTicker(1, private.timerObj.func, self.session - 1)
		end 
	end 
end 

function private:CancelSession(isCallback)
	local timerObj = self.timerObj
	if timerObj and not timerObj:IsCancelled() then
		if not isCallback then 
			local DISABLED = (self.locale and (self.locale.DISABLED[GetCL()] or self.locale.DISABLED["enUS"])) or GetLocalization().PROFILESESSION.DISABLED
			Print(format(DISABLED, self.profile))
		end 
		
		self.session = 0
		self.expiration = 0
		
		if timerObj.notifyStartUp and not timerObj.notifyStartUp:IsCancelled() then 
			timerObj.notifyStartUp:Cancel()
		end 
		
		if timerObj.notifyObj and not timerObj.notifyObj:IsCancelled() then 
			timerObj.notifyObj:Cancel()
		end
		
		timerObj:Cancel()
	end 
end 

function private:ShutDownSession()
	local current_profile = A.CurrentProfile
	if not self.disabled_profiles[current_profile] then 
		if not self.isReplaced then 
			local originalFunc_Rotation = A.Rotation 
			local disabled_profiles = self.disabled_profiles
			A.Rotation = function(...)
				if disabled_profiles[A.CurrentProfile] then
					return Hide(...)
				else 
					return originalFunc_Rotation(...)
				end 
			end; Env.Rotation = A.Rotation
			
			self.isReplaced = true 
		end 
		
		self.disabled_profiles[current_profile] = true 
	end 

	private.UI:Switch("LeftButton")
end 

do -- create UI 
	local UI = {}; private.UI = UI
	local default_width, default_height = 300, 25
	
	function UI:Switch(mouse_button)
		if mouse_button then 
			self.mouse_button = mouse_button
			
			local L = GetLocalization()
			local CL = GetCL()
			local CUSTOM = private.locale 
			
			local panel = mouse_button == "LeftButton" and self.panelUser or self.panelDev
			if mouse_button == "RightButton" then 
				panel.titlePanel.label:SetText((CUSTOM and (CUSTOM.DEVELOPMENTPANEL[CL] or CUSTOM.DEVELOPMENTPANEL["enUS"])) or L.PROFILESESSION.DEVELOPMENTPANEL)
				
				panel.input_name.subtitle:SetText((CUSTOM and (CUSTOM.PROJECTNAME[CL] or CUSTOM.PROJECTNAME["enUS"])) or L.PROFILESESSION.PROJECTNAME)
				panel.input_name.stdUiTooltip.text:SetText((CUSTOM and (CUSTOM.PROJECTNAMETT[CL] or CUSTOM.PROJECTNAMETT["enUS"])) or L.PROFILESESSION.PROJECTNAMETT)
				panel.input_secureword.subtitle:SetText((CUSTOM and (CUSTOM.SECUREWORD[CL] or CUSTOM.SECUREWORD["enUS"])) or L.PROFILESESSION.SECUREWORD)
				panel.input_secureword.stdUiTooltip.text:SetText((CUSTOM and (CUSTOM.SECUREWORDTT[CL] or CUSTOM.SECUREWORDTT["enUS"])) or L.PROFILESESSION.SECUREWORDTT)
				panel.output.stdUiTooltip.text:SetText((CUSTOM and (CUSTOM.KEYTT[CL] or CUSTOM.KEYTT["enUS"])) or L.PROFILESESSION.KEYTT)
				panel.OnInput(panel.output, true) --> emulating human's input to dev_key in output
			else 
				panel.titlePanel.label:SetText((CUSTOM and (CUSTOM.USERPANEL[CL] or CUSTOM.USERPANEL["enUS"])) or L.PROFILESESSION.USERPANEL)
				
				if private.status then --> authorized
					if private.session == 0 then --> expired
						panel.message:SetText(format((CUSTOM and (CUSTOM.EXPIREDMESSAGE[CL] or CUSTOM.EXPIREDMESSAGE["enUS"])) or L.PROFILESESSION.EXPIREDMESSAGE, private.profile or A.CurrentProfile))
					else --> everything is ok e.g. key is authorized 
						panel.message:SetText((CUSTOM and (CUSTOM.AUTHORIZED[CL] or CUSTOM.AUTHORIZED["enUS"])) or L.PROFILESESSION.AUTHORIZED)
					end 
				else --> not authorized
					panel.message:SetText((CUSTOM and (CUSTOM.AUTHMESSAGE[CL] or CUSTOM.AUTHMESSAGE["enUS"])) or L.PROFILESESSION.AUTHMESSAGE)
				end 	
				
				panel.output:SetText(private:GetUserKey(private.affected_profiles[private.profile]) or "Use ProfileSession:Setup(key,config) to get key here")
				panel.output.stdUiTooltip.text:SetText((CUSTOM and (CUSTOM.KEYTTUSER[CL] or CUSTOM.KEYTTUSER["enUS"])) or L.PROFILESESSION.KEYTTUSER)
			end 
			
			panel.output.subtitle:SetText(CUSTOM and CUSTOM.KEY and (CUSTOM.KEY[CL] or CUSTOM.KEY["enUS"]) or L.TAB.KEY)
			panel.button_close:SetText(CUSTOM and CUSTOM.CLOSE and (CUSTOM.CLOSE[CL] or CUSTOM.CLOSE["enUS"]) or L.CLOSE)
			panel:DoLayout()
			panel:SetHeight(math_abs(select(5, panel.button_close:GetPoint())) + panel.button_close:GetHeight() + 10)
			
			self.panelDev:SetShown(mouse_button == "RightButton")
			if private.affected_profiles[A.CurrentProfile] then --> shows only on valid profiles 
				self.panelUser:SetShown(mouse_button == "LeftButton")
			end 			
			
			-- This is so terrible StdUi bug with editboxes on layout, so terrible..
			local needHide = not panel.isFixed 
			if not panel.isFixed then 
				panel.isFixed = true 
				NewTimer(0.03, function() UI:Switch(self.mouse_button) end)
			end 
			if needHide then 
				self.panelDev:SetShown(mouse_button ~= "RightButton")
				if private.affected_profiles[A.CurrentProfile] then 
					self.panelUser:SetShown(mouse_button ~= "LeftButton")
				end 			
			end 
		else 
			self:SetShown(false)
		end 
	end 
	
	function UI:Close()
		UI:SetShown(false)
	end 
	
	function UI:SetShown(state)
		self.panelDev:SetShown(state)
		self.panelUser:SetShown(state)
	end 
	
	function UI:IsShown()
		return self.panelDev:IsShown() or self.panelUser:IsShown()
	end 
	
	local config_elements = { column = "even", editbox_height = 25, button_height = 25 }
	local function OnUserInput(this, isUserInput)
		if isUserInput then 
			this:SetText(this.last_text)
		end 
	end
	---[[ DEV PANEL ]]---
	local panelDev = StdUi:PanelWithTitle(_G.UIParent, default_width, default_height, ""); UI.panelDev = panelDev
	panelDev:SetFrameStrata("DIALOG")
	panelDev:SetPoint("CENTER")
	panelDev:SetShown(false) 
	panelDev:EnableMouse(true)	
	panelDev.OnInput = function(this, isHumanInput)
		if isHumanInput then 
			local parent = this:GetParent()
			local name = parent.input_name:GetText()
			local secure_word = parent.input_secureword:GetText()
			secure_word = secure_word ~= "" and secure_word or nil
			parent.output:SetText(private:GetDevKey(name, secure_word))
		end 	
	end

	panelDev.input_name = StdUi:SimpleEditBox(panelDev, default_width, config_elements.editbox_height, "My Brand Routines")
	panelDev.input_name:SetCursorPosition(0)
	panelDev.input_name:SetScript("OnTextChanged", panelDev.OnInput)
	panelDev.input_name.subtitle = StdUi:Subtitle(panelDev.input_name, "") 
	StdUi:GlueAbove(panelDev.input_name.subtitle, panelDev.input_name)
	StdUi:FrameTooltip(panelDev.input_name, "", nil, "TOP", true)
	
	panelDev.input_secureword = StdUi:SimpleEditBox(panelDev, default_width, config_elements.editbox_height, (select(2, BNGetInfo())))
	panelDev.input_secureword:SetCursorPosition(0)
	panelDev.input_secureword:SetScript("OnTextChanged", panelDev.OnInput)
	panelDev.input_secureword.subtitle = StdUi:Subtitle(panelDev.input_secureword, "") 
	StdUi:GlueAbove(panelDev.input_secureword.subtitle, panelDev.input_secureword)
	StdUi:FrameTooltip(panelDev.input_secureword, "", nil, "TOP", true)
	
	panelDev.output = StdUi:SimpleEditBox(panelDev, default_width, config_elements.editbox_height, "")
	panelDev.output:SetPropagateKeyboardInput(false)
	panelDev.output:EnableGamePadButton(false)
	panelDev.output:SetMultiLine(true)
	panelDev.output:SetCursorPosition(0)
	panelDev.output:SetScript("OnChar", OnUserInput)
	panelDev.output:SetScript("OnTextChanged", OnUserInput)
	panelDev.output:SetScript("OnKeyDown", function(this)
		this.last_text = this:GetText()
	end)
	panelDev.output.subtitle = StdUi:Subtitle(panelDev.output, "") 
	StdUi:GlueAbove(panelDev.output.subtitle, panelDev.output)
	StdUi:FrameTooltip(panelDev.output, "", nil, "TOP", true)
	
	panelDev.button_close = StdUi:Button(panelDev, default_width, config_elements.button_height, "")
	panelDev.button_close:RegisterForClicks("LeftButtonUp")	
	panelDev.button_close:SetScript("OnClick", UI.Close)	
	
	StdUi:EasyLayout(panelDev, { padding = { top = panelDev.titlePanel:GetHeight() + 20, left = 0, right = 0 } })
	panelDev:AddRow():AddElements(panelDev.input_name, panelDev.input_secureword, config_elements)
	panelDev:AddRow():AddElement(panelDev.output)
	panelDev:AddRow({ margin = { top = -5 } }):AddElement(panelDev.button_close)
	
	---[[ USER PANEL ]]---
	local panelUser = StdUi:PanelWithTitle(_G.UIParent, default_width, default_height, ""); UI.panelUser = panelUser
	panelUser:SetFrameStrata("DIALOG")
	panelUser:SetPoint("CENTER")
	panelUser:SetShown(false) 
	panelUser:EnableMouse(true)	

	panelUser.message = StdUi:FontString(panelUser, "")
	panelUser.message:SetJustifyH("MIDDLE")
	
	panelUser.output = StdUi:SimpleEditBox(panelUser, default_width, config_elements.editbox_height, "")
	panelUser.output:SetPropagateKeyboardInput(false)
	panelUser.output:EnableGamePadButton(false)
	panelUser.output:SetMultiLine(true)
	panelUser.output:SetCursorPosition(0)
	panelUser.output:SetScript("OnChar", OnUserInput)
	panelUser.output:SetScript("OnTextChanged", OnUserInput)
	panelUser.output:SetScript("OnKeyDown", function(this)
		this.last_text = this:GetText()
	end)	
	panelUser.output.subtitle = StdUi:Subtitle(panelUser.output, "") 
	StdUi:GlueAbove(panelUser.output.subtitle, panelUser.output)
	StdUi:FrameTooltip(panelUser.output, "", nil, "TOP", true)
	
	panelUser.button_close = StdUi:Button(panelUser, default_width, config_elements.button_height, "")
	panelUser.button_close:RegisterForClicks("LeftButtonUp")	
	panelUser.button_close:SetScript("OnClick", UI.Close)	
	
	StdUi:EasyLayout(panelUser, { padding = { top = panelUser.titlePanel:GetHeight() + 15, left = 0, right = 0 } })
	panelUser:AddRow():AddElement(panelUser.message)
	panelUser:AddRow():AddElement(panelUser.output)
	panelUser:AddRow({ margin = { top = -5 } }):AddElement(panelUser.button_close)
end
 

TMW:RegisterSelfDestructingCallback("TMW_ACTION_IS_INITIALIZED_PRE", function(callbackEvent, pActionDB, gActionDB)
	local Server = TMW.Classes.Server; private.Server = Server
	local function CheckSession()
		private:CancelSession(true)
		private.UI:SetShown(false)
		private.session = 0; private.expiration = 0; private.profile = nil; private.locales = nil; private.status = nil --> nil means not authorized
		local current_profile = TMW.db.profile.signature or ""
		if private.affected_profiles[current_profile] then
			private.profile = current_profile
			
			-- Enable 
			local current_seconds = Server:GetTimeInSeconds() --> current UTC time in seconds 
			for dev_key, dev_config in pairs(private.data) do 
				local my_key = private:GetUserKey(dev_key)
				local my_config = rawget(dev_config.users, my_key) or rawget(dev_config.users, "*")
				if my_config and rawget(my_config, "profiles") and rawget(my_config.profiles, current_profile) then 
					local expiration = my_config.expiration
					local expiration_seconds = private:GetDate(expiration, current_seconds)
					local isTrial = expiration:find("%l%l%l%l%l%-")
					if isTrial then 
						if not TMW.db.profile.trial then 
							TMW.db.profile.trial = expiration_seconds
						end 
						
						private.status = "TRIAL"
						private.session = math_max(TMW.db.profile.trial - current_seconds, 0)							
					else 
						private.status = "FULL"
						private.session = math_max(expiration_seconds - current_seconds, 0)
					end 
					
					private.locales = rawget(dev_config, locales)
					if private.session > 0 and current_profile == A.CurrentProfile and not private.disabled_profiles[A.CurrentProfile] then
						private.expiration = current_seconds + private.session
						private:RunSession()
						return
					else 
						private.session = 0
					end 
				end 
			end
			
			-- Disable 
			if private.session <= 0 then 
				private:ShutDownSession()
			end 
		end 
	end
		
	TMW:RegisterCallback("TMW_ACTION_IS_INITIALIZED_PRE", CheckSession)
	CheckSession()
	
	return true
end)

-----------------------------------------------------------------
-- API
-----------------------------------------------------------------
local ProfileSession = {}
function ProfileSession:GetDevKey(name, custom_secure_word)
	-- @usage: local dev_key = ProfileSession:GetDevKey("My Brand Routines"[, "Any string here if you don't trust cryptography your btag"])
	-- @return: blake3 hash encrypted by unique 256-bit derived key
	local key = custom_secure_word or (select(2, BNGetInfo()))
	private.cache.dev_keys[name][key] = rawget(private.cache.dev_keys[name], key) or blake3(key, hex_to_bin(blake3_derive_key(key, name)))
	return private.cache.dev_keys[name][key]
end; private.GetDevKey = ProfileSession.GetDevKey

function ProfileSession:GetUserKey(dev_key)
	-- @usage: local user_key = ProfileSession:GetUserKey("hash_string")
	-- @return: blake3 hash encrypted by 'dev_key'
	if dev_key then 
		private.cache.user_keys[dev_key] = rawget(private.cache.user_keys, dev_key) or blake3((select(2, BNGetInfo())), hex_to_bin(dev_key))
		return private.cache.user_keys[dev_key]
	end 
end; private.GetUserKey = ProfileSession.GetUserKey

function ProfileSession:GenerateUID()
	-- Can be used as custom_secure_word for ProfileSession:GetDevKey(name, custom_secure_word)
	-- @return: string unique 32 bit ints token
	return TMW.generateGUID(TMW.CONST.GUID_SIZE):upper()
end; private.GenerateUID = ProfileSession.GenerateUID

function ProfileSession:Setup(dev_key, dev_config, useTrialReset)	
	--[[ @usage:
	Arguments:
		dev_key
			@string - hexadecimal representation of blake3 hash
		dev_config
			@table:
			{
				-- required
				users = {
					-- 1th way with 'user_key' authorization:
					["user_key1"] = {
						expiration = "2022-12-31-23-59-59", 	-- @string expiration date in format 'YYYY-MM-DD-HH-MM-SS' (UTC) 
						profiles = {
							["profileName1"] = true, 			-- @boolean true - signing "profileName1" for session 
							["profileName2"] = true,
						},
					},
					["*"] = {
						expiration = "trial-07", 				-- @string expiration date in format 'trial-DD'	
						profiles = {
							["profileName1"] = true,
							["profileName2"] = true,
						},
					},
					-- 2th way without 'user_key' authorization e.g. for any user:
					["*"] = {
						expiration = "2022-12-31-23-59-59",
						profiles = {
							["profileName1"] = true,
							["profileName2"] = true,
						},
					},
				},
	 			-- optional, if omitted it will use default locales, see Action.lua > Localization table.
				locales = { 
					EXPIREDMESSAGE = {
						-- required 
						["enUS"] = "Your subscription for %s profile is expired!\nPlease contact profile developer!", -- %s will be formatted by profile name; %s is required in the string
						-- optional 
						["ruRU"] = "Ваша подписка на %s профиль истекла!\nПожалуйста, обратитесь к разработчику профиля!",
					},
					AUTHMESSAGE = {
						-- required 
						["enUS"] = "Thank you for using premium profile\nTo authorize your key please contact profile developer!",
						-- optional 
						["ruRU"] = "Спасибо за использование премиум профиля\nДля авторизации вашего ключа, пожалуйста, обратитесь к разработчику профиля!",
					},
					REMAINING = {
						-- required 
						["enUS"] = "[%s] remains %d secs", -- %s will be formatted by profile name, %d will be formatted by remaining session time 
														   -- e.g. output example "[profileName] remains 200 secs", %s and %d are required in the string
						-- optional 
						["ruRU"] = "[%s] осталось %d сек.",
					},
					DISABLED = {
						-- required 
						["enUS"] = "[%s] |cffff0000expired session!|r", -- %s will be formatted by profile name; %s is required in the string; |cffff0000 "is read color here" |r
						-- optional 
						["ruRU"] = "[%s] |cffff0000истекла сессия!|r",
					},
					-- ... and so on, you can replace all localization keys, for more details see Action.lua -> Localization.enUS.PROFILESESSION
				},
			}
			
			notes:
			sessions["*"] 				- ["*"] is special key, means for any not presented 'user_key'
			sessions[key] = 'trial-DD' 	- will make one-time session, adds 'DD' (days) to current date and time to create expiration date (UTC)
										- after finished trial time the user can't use profile for this 'dev_key', so next your lua file must contain his key or use ["*"] for any user	
		
		useTrialReset
			@boolean - true, resets all activated trials on all specified profiles. 
			USE THIS ONLY ON YOUR LOCAL REPOSITORY!!! DO NOT SHARE PROFILE WITH THIS OPTION!!!
	]]

	assert(type(dev_key) == "string" and not dev_key:find("%X"), format("dev_key '%s' must be hash string!", toStr(dev_key)))
	--assert(rawget(private.data, dev_key) == nil, format("dev_key '%s' has been already signed!", toStr(dev_key)))) -- commented because devs can use multiple times setup for same key in the local snippets
	assert(type(dev_config) == "table", format("dev_key: '%s'\ndev_config must be table! This type is '%s'.", toStr(dev_key), type(dev_config)))
	assert(type(dev_config.users) == "table", format("dev_key: '%s'\ndev_config.users must be table! This type is '%s'.", toStr(dev_key), type(dev_config.users)))
	assert(type(dev_config.locales) == "table" or type(dev_config.locales) == "nil", format("dev_key: '%s'\ndev_config.locales must be table or empty! This type is '%s'.", toStr(dev_key), type(dev_config.locales)))
	assert(not useTrialReset or rawget(private.data, dev_key) == nil, format("dev_key: '%s'\nuseTrialReset can not be used on already signed session!", toStr(dev_key)))
	
	local config = private.data[dev_key]
	local config_users = config.users 
	local config_locales = config.locales
	
	-- required
	local TMW_db_profiles = TMW.db.profiles
	for user_key, user_config in pairs(dev_config.users) do 
		assert(type(user_key) == "string", format("dev_key: '%s'\ndev_config.users['%s'] must be string! This type is '%s'.", toStr(dev_key), toStr(user_key), type(user_key)))
		assert(type(user_config) == "table", format("dev_key: '%s'\ndev_config.users['%s'] must be table! This type is '%s'.", toStr(dev_key), toStr(user_key), type(user_config)))
		assert(type(user_config.expiration) == "string" and (user_config.expiration:find("trial%-%d%d") or user_config.expiration:find("%d%d%d%d%-%d%d%-%d%d%-%d%d%-%d%d%-%d%d")), format("dev_key: '%s'\ndev_config.users['%s'].expiration = '%s' is incorrect format or type!", toStr(dev_key), toStr(user_key), toStr(user_config.expiration or "nil")))
		assert(type(user_config.profiles) == "table", format("dev_key: '%s'\ndev_config.users['%s'].profiles must be table! This type is '%s'!", toStr(dev_key), toStr(user_key), type(user_config.profiles)))
		
		local raw_expiration = rawget(config_users, user_key)
		assert(raw_expiration == nil or raw_expiration ~= user_config.expiration, format("dev_key: '%s'\ndev_config.users['%s'].expiration = '%s' already written expiration doesn't match new expiration '%s'.", toStr(dev_key), toStr(user_key), toStr(raw_expiration), toStr(user_config.expiration)))
		if rawget(config_users[user_key], expiration) == nil then
			config_users[user_key].expiration = user_config.expiration
		end 
		
		for profileName, profileStatus in pairs(user_config.profiles) do 
			local profile = TMW_db_profiles[profileName]
			if profile then 
				assert(type(profileName) == "string" and profile, format("dev_key: '%s'\ndev_config.users['%s'].profiles['%s'] must be valid profile name!", toStr(dev_key), toStr(user_key), toStr(profileName)))
				assert(type(profileStatus) == "boolean", format("dev_key: '%s'\ndev_config.users['%s'].profiles['%s'] = '%s' is incorrect format or type!", toStr(dev_key), toStr(user_key), toStr(profileName), toStr(profileStatus or "nil")))
				
				local raw_profileStatus = rawget(config_users[user_key].profiles, profileName)
				if raw_profileStatus == nil then 
					config_users[user_key].profiles[profileName] = profileStatus
					
					assert(private.affected_profiles[profileName] == nil or private.affected_profiles[profileName] == dev_key, format("dev_key: '%s'\ndev_config.users['%s'].profiles['%s'] this profile has been signed by another '%s' dev_key!", toStr(dev_key), toStr(user_key), toStr(profileName), toStr(private.affected_profiles[profileName]))) 
					private.affected_profiles[profileName] = dev_key
					profile.signature = profileName
				end 
				
				if useTrialReset and profile.trial and private.affected_profiles[profileName] == dev_key then 
					profile.trial = nil
					Print(format("Trial was successfully reseted on %s (%s)!", profileName, toStr(dev_key)))
				end 
			end 
		end 
	end 
	
	-- optional
	if dev_config.locales then
		for label, localization in pairs(dev_config.locales) do 
			assert(type(localization) == "table" and localization.enUS, format("dev_key: '%s'\ndev_config.locales['%s'] has incorrect format or type!", toStr(dev_key), toStr(label)))
			
			for lang, message in pairs(localization) do 
				assert(type(message) == "string", format("dev_key: '%s'\ndev_config.locales['%s']['%s'] = '%s' has incorrect message format or type!", toStr(dev_key), toStr(label), toStr(lang), toStr(message)))
				if label == "REMAINING" then 
					assert(message:find("%%s") and message:find("%%d"), format("dev_key: '%s'\ndev_config.locales['%s']['%s'] = '%s' has missed %s or %d in the string!", toStr(dev_key), toStr(label), toStr(lang), toStr(message)))
				end 
				if label == "EXPIREDMESSAGE" or label == "DISABLED" then 
					assert(message:find("%%s"), format("dev_key: '%s'\ndev_config.locales['%s']['%s'] = '%s' has missed %s in the string!", toStr(dev_key), toStr(label), toStr(lang), toStr(message)))
				end 
				
				config_locales[label][lang] = message 
			end 
		end 
	end 
	
	if useTrialReset then 
		message("Please remove 3th true argument in ProfileSession:Setup(dev_key, dev_config, true)")
	end 
end; private.Setup = ProfileSession.Setup

function ProfileSession:Disable()
	private:CancelSession()
	private:ShutDownSession()
end; private.Disable = ProfileSession.Disable

function ProfileSession:GetSession()
	-- @return: 
	-- [1] @string remaining time in "DD:HH:MM:SS" string format 
	-- [2] @number remaining time in seconds
	-- [3] @string or @nil status: "TRIAL", "FULL", nil. nil - means not authorized
	-- [4] @string or @nil native profile name. nil - means this profile is not using session
	-- [5] @table or @nil. table that have locales which must overwrite defaults
	local remain = math_max((private.expiration or 0) - private.Server:GetTimeInSeconds(), 0)
	return private.Server:FormatSeconds(remain), remain, private.status, private.profile, private.locales
end; private.GetSession = ProfileSession.GetSession

A.ProfileSession = setmetatable({ UI = private.UI }, { --> Allows modify UI
	__index = ProfileSession,
	__newindex = function(t, key, value)
		error("Attempt to modify read-only table", 2)
	end,
	__metatable = true,
})


-----------------------------------------------------------------
-- API: USAGE EXAMPLES
-----------------------------------------------------------------
--[[
--- [ Manual ] ---
-- 1th step: Get 'dev_key' as the string representation.
local dev_key = "cdb0db7b6f82440a270838ce2951853facbc017a9eb1c8b6b7c4f8ebc42d8e23"  --> retrived from UI (right click on small "document" texture near profile dropdown) 
																					--> or retrive it from game chat via /dump Action.ProfileSession:GetDevKey("My Brand Routines") --> this is through using your b.tag as master password.
																					--> 							  	 /dump Action.ProfileSession:GetDevKey("My Brand Routines", "Secure Password Word") --> this is through using your custom master password. 

-- 2th step: Write somewhere code to setup session, can be written in global snippets if you have them or just store it inside profile snippets.
-- Make sure that you performed initial setup with your dev_key as user_key, it needs to retrive your user_key, after that you will replace dev_key by user_key. It must to be done one time per each dev_key.
local ProfileSession = _G.Action.ProfileSession
ProfileSession:Setup(dev_key or "cdb0db7b6f82440a270838ce2951853facbc017a9eb1c8b6b7c4f8ebc42d8e23", {
	["cdb0db7b6f82440a270838ce2951853facbc017a9eb1c8b6b7c4f8ebc42d8e23"] = { 		--> put your dev_key here, just to get your user_key otherwise it will not allow you to enter in native UI 
		expiration = "2100-01-01-23-59-59",
		profiles = {
			["profileName1-Warrior"] = true,
		},
	},
	-- You will replace this key as soon as you will get own user_key.
	-- See description @usage in the function ProfileSession:Setup(dev_key, dev_config) in this file 
})

-- 3th step (optional): Obfuscate your written code (2th step) by using: MoonSec, Luraph, AzureBrew, Prometheus, SimplyXOR, or any such tool.
-- 4th step: Export and share your profile through Profile Install to your users.
-- 5th step (optional): Ask your users to send you a key, they will get a message with their key in the next time using your profile.

-- Important to note:
-- User key is attached to his b.tag through blake3 hash, so if user changes b.tag (payment change tag, merging b.accounts and etc) then his old key will no longer work and you have to replace it.
-- If you will not encode or obfuscate your 2th step, that part will be unprotected and everyone will able to modify it. So it's highly recommended to hide it somehow on your side before you will share profile.
-- Every hash is one-way cryptographically protected by a 256-bit key information mathematically tied to a user's b.tag, reversing hash will not give any viable results to attacker.
-- Trial runs one-time per each profile, once it's launched it can not be reversed, unless creating clearly new profile from scratch or passing 3th argument as boolean true to reset it (see Example #reset).

-- Tips:
-- I recommend to make google sheets table that will hold associated Discord/email user with hash key instead of writting commentary near the key. 
-- You can hold user key under Discord's profile notes for each user.



--- [ Example #1 ] ---
-- Runs same session for all users and all specified profiles, without trial option. 
-- If you have lifetime users you can personally add their user_key, specified users have higher priority.

local lifetime 	 	= "2100-01-01-23-59-59" 	--> expires on 1 Jan 2100 23:59:59 (UTC)
local full_profiles = {
	["profileName1-Warrior"] = true,
	["profileName2-Paladin"] = true,
	["profileName3-Rogue"] 	 = true,
}
ProfileSession:Setup("cdb0db7b6f82440a270838ce2951853facbc017a9eb1c8b6b7c4f8ebc42d8e23", {
	-- required
	users = {
		["user_key1"] = { 						--> specified lifetime user
			expiration = lifetime,
			profiles = full_profiles,
		},
		["*"] = { 								--> all other users
			expiration = "2022-12-31-23-59-59", --> expires on 31 Dec 2022 23:59:59 (UTC)
			profiles = full_profiles,
		},
	},
	-- optional, if omitted it will use default locales, see Action.lua > Localization table.
	locales = { 
		EXPIREDMESSAGE = {
			-- required 
			["enUS"] = "Your subscription for %s profile is expired!\nPlease contact profile developer!", -- %s will be formatted by profile name; %s is required in the string
			-- optional 
			["ruRU"] = "Ваша подписка на %s профиль истекла!\nПожалуйста, обратитесь к разработчику профиля!",
		},
		AUTHMESSAGE = {
			-- required 
			["enUS"] = "Thank you for using premium profile\nTo authorize your key please contact profile developer!",
			-- optional 
			["ruRU"] = "Спасибо за использование премиум профиля\nДля авторизации вашего ключа, пожалуйста, обратитесь к разработчику профиля!",
		},
		REMAINING = {
			-- required 
			["enUS"] = "[%s] remains %d secs", -- %s will be formatted by profile name, %d will be formatted by remaining session time 
											   -- e.g. output example "[profileName] remains 200 secs", %s and %d are required in the string
			-- optional 
			["ruRU"] = "[%s] осталось %d сек.",
		},
		DISABLED = {
			-- required 
			["enUS"] = "[%s] |cffff0000expired session!|r", -- %s will be formatted by profile name; %s is required in the string; |cffff0000 "is read color here" |r
			-- optional 
			["ruRU"] = "[%s] |cffff0000истекла сессия!|r",
		},
	},
})




--- [ Example #2 ] ---
-- Runs same session for specified users with full_profiles, and trial for not authorized users with trial_profiles

local normaltime = "2022-12-31-23-59-59" --> expires on 31 Dec 2022 23:59:59 (UTC)
local lifetime 	 = "2100-01-01-23-59-59" --> expires on  1 Jan 2100 23:59:59 (UTC)
local trialtime  = "trial-07"			 --> 7-days trial time (UTC), start up will be launched as soon as user will load profile 
local full_profiles = {
	["profileName1-Warrior"] = true,
	["profileName2-Paladin"] = true,
	["profileName3-Rogue"] 	 = true,
}
local trial_profiles = {
	["profileName1-Warrior"] = true,
	["profileName2-Priest"]  = true,
}
ProfileSession:Setup("cdb0db7b6f82440a270838ce2951853facbc017a9eb1c8b6b7c4f8ebc42d8e23", {
	-- required
	users = {
		["user_key1"] = { 						--> specified lifetime user
			expiration = lifetime, 				--> expires on 1 Jan 2100 23:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["user_key2"] = {						--> specified normaltime user
			expiration = normaltime,			--> expires on 31 Dec 2022 23:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["*"] = {								--> all other users e.g. trials in this example
			expiration = trialtime,				--> 7-days trial time (UTC), start up will be launched as soon as user will load profile
			profiles = trial_profiles,			--> trial profiles 
		},
	},
})




--- [ Example #3 ] ---
-- Runs individual session for each user with full_profiles, and lifetime session for not authorized users with free_profiles

local lifetime 	 = "2100-01-01-23-59-59" --> expires on  1 Jan 2100 23:59:59 (UTC)
local trialtime  = "trial-07"			 --> 7-days trial time (UTC), start up will be launched as soon as user will load profile 
local full_profiles = {
	["profileName1-Warrior"] = true,
	["profileName2-Paladin"] = true,
	["profileName3-Rogue"] 	 = true,
}
local free_profiles = {
	["profileName1-Warrior-Free"] = true,
	["profileName2-Paladin-Free"] = true,
	["profileName3-Rogue-Free"]   = true,
}
ProfileSession:Setup("cdb0db7b6f82440a270838ce2951853facbc017a9eb1c8b6b7c4f8ebc42d8e23", {
	-- required
	users = {
		["user_key1"] = { 						--> specified lifetime user
			expiration = lifetime, 				--> expires on 1 Jan 2100 23:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["user_key2"] = {						--> specified individual time user
			expiration = "2022-12-31-23-59-59", --> expires on 31 Dec 2022 23:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["user_key3"] = {						--> specified individual time user
			expiration = "2022-05-01-10-59-59", --> expires on 1 May 2022 10:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["*"] = {								--> all other users e.g. free lifetime profiles in this example
			expiration = lifetime,				--> expires on  1 Jan 2100 23:59:59 (UTC)
			profiles = free_profiles,			--> free profiles 
		},
	},
})




--- [ Example #4 ] ---
-- Runs individual session for each user with full_profiles and unique, and trial session for not authorized users with full_profiles

local normaltime = "2022-12-31-23-59-59" --> expires on 31 Dec 2022 23:59:59 (UTC)
local lifetime 	 = "2100-01-01-23-59-59" --> expires on  1 Jan 2100 23:59:59 (UTC)
local trialtime  = "trial-07"			 --> 7-days trial time (UTC), start up will be launched as soon as user will load profile 
local full_profiles = {
	["profileName1-Warrior"] = true,
	["profileName2-Paladin"] = true,
	["profileName3-Rogue"] 	 = true,
}
ProfileSession:Setup("cdb0db7b6f82440a270838ce2951853facbc017a9eb1c8b6b7c4f8ebc42d8e23", {
	-- required
	users = {
		["user_key1"] = { 						--> specified lifetime user
			expiration = lifetime, 				--> expires on 1 Jan 2100 23:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["user_key2"] = {						--> specified individual time user
			expiration = normaltime, 			--> expires on 31 Dec 2022 23:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["user_key3"] = {						--> specified individual time user
			expiration = normaltime, 			--> expires on 31 Dec 2022 23:59:59 (UTC)
			profiles = {						--> unique profiles
				["profileName1-Warrior"] = true,
			},			 
		},
		["*"] = {								--> all other users e.g. free lifetime profiles in this example
			expiration = trialtime,				--> 7-days trial time (UTC), start up will be launched as soon as user will load profile 
			profiles = full_profiles,			--> free profiles 
		},
	},
})




--- [ Example #reset ] ---
-- Runs reseting process on specified profiles, let's take example #4, difference in what you passing 3th argument as true in to function. See last line.

local normaltime = "2022-12-31-23-59-59" --> expires on 31 Dec 2022 23:59:59 (UTC)
local lifetime 	 = "2100-01-01-23-59-59" --> expires on  1 Jan 2100 23:59:59 (UTC)
local trialtime  = "trial-07"			 --> 7-days trial time (UTC), start up will be launched as soon as user will load profile 
local full_profiles = {
	["profileName1-Warrior"] = true,
	["profileName2-Paladin"] = true,
	["profileName3-Rogue"] 	 = true,
}
ProfileSession:Setup("cdb0db7b6f82440a270838ce2951853facbc017a9eb1c8b6b7c4f8ebc42d8e23", {
	-- required
	users = {
		["user_key1"] = { 						--> specified lifetime user
			expiration = lifetime, 				--> expires on 1 Jan 2100 23:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["user_key2"] = {						--> specified individual time user
			expiration = normaltime, 			--> expires on 31 Dec 2022 23:59:59 (UTC)
			profiles = full_profiles,			--> full profiles 
		},
		["user_key3"] = {						--> specified individual time user
			expiration = normaltime, 			--> expires on 31 Dec 2022 23:59:59 (UTC)
			profiles = {						--> unique profiles
				["profileName1-Warrior"] = true,
			},			 
		},
		["*"] = {								--> all other users e.g. free lifetime profiles in this example
			expiration = trialtime,				--> 7-days trial time (UTC), start up will be launched as soon as user will load profile 
			profiles = full_profiles,			--> free profiles 
		},
	},
}, true) 										--> passing true here causes trial reset!
]]