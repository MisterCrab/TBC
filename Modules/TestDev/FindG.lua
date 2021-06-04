local _G, pairs, type, tostring, print =
	  _G, pairs, type, tostring, print
	  
function FindG(s)
	for k, v in pairs(_G) do 
		if type(s) == "string" and type(v) == "string" and v:lower():match(s:lower()) then 
			print(k .. " contain: " .. v)
		end 
		
		if type(s) == "number" and type(v) == "number" and s == v then 
			print(k .. " contain: " .. v)
		end 
	end 
end 

function FindGObj(s)
	for k, v in pairs(_G) do 
		if type(s) == "string" then 
			local current = tostring(k) 
			if current and current:lower():match(s:lower()) then 
				print(current .. " contain: " .. s)
			end 
		end 
	end 
end 

