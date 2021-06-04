if not _G.ElvUI then 
	return 
end

local _G, getmetatable 					= _G, getmetatable
local hooksecurefunc					= _G.hooksecurefunc	  
local CreateFrame						= _G.CreateFrame	  
local EnumerateFrames					= _G.EnumerateFrames

local handled = { ["Frame"] = true }
local object = CreateFrame("Frame")
object.t = object:CreateTexture(nil,"BACKGROUND")
local OldTexelSnappingBias = object.t:GetTexelSnappingBias()

local function Fix(frame)
	if (frame and not frame:IsForbidden()) and frame.PixelSnapDisabled and not frame.PixelSnapTurnedOff then
		if frame.SetSnapToPixelGrid then
			frame:SetTexelSnappingBias(OldTexelSnappingBias)
		elseif frame.GetStatusBarTexture then
			local texture = frame:GetStatusBarTexture()
			if texture and texture.SetSnapToPixelGrid then                
				texture:SetTexelSnappingBias(OldTexelSnappingBias)
			end
		end
		frame.PixelSnapTurnedOff = true 
	end
end

local function addapi(object)
	local mt = getmetatable(object).__index
	if mt.DisabledPixelSnap then 
		if mt.SetSnapToPixelGrid then hooksecurefunc(mt, 'SetSnapToPixelGrid', Fix) end
		if mt.SetStatusBarTexture then hooksecurefunc(mt, 'SetStatusBarTexture', Fix) end
		if mt.SetColorTexture then hooksecurefunc(mt, 'SetColorTexture', Fix) end
		if mt.SetVertexColor then hooksecurefunc(mt, 'SetVertexColor', Fix) end
		if mt.CreateTexture then hooksecurefunc(mt, 'CreateTexture', Fix) end
		if mt.SetTexCoord then hooksecurefunc(mt, 'SetTexCoord', Fix) end
		if mt.SetTexture then hooksecurefunc(mt, 'SetTexture', Fix) end
	end
end

addapi(object)
addapi(object:CreateTexture())
addapi(object:CreateFontString())
addapi(object:CreateMaskTexture())
object = EnumerateFrames()
while object do
	if not object:IsForbidden() and not handled[object:GetObjectType()] then
		addapi(object)
		handled[object:GetObjectType()] = true
	end
	
	object = EnumerateFrames(object)
end