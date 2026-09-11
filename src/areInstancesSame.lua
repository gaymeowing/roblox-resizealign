--!strict

local ReflectionService = game:GetService("ReflectionService")

local MEMBER_FILTER = table.freeze({ ExcludeDisplay = true })

local function areInstancesSame(a: Instance, b: Instance, ignoreProperties: { string }?): boolean
	-- this will most likely never be triggered, but incase this function ever gets used
	-- in a case where this does; it'll be fine performance wise
	if a == b then
		return true
	end
	local className = a.ClassName

	if className ~= b.ClassName then
		return false
	end

	for index, property in ReflectionService:GetPropertiesOfClass(className, MEMBER_FILTER :: any) do
		local permits = property.Permits
		local name = property.Name

		--stylua: ignore
		if
			(permits.Read and permits.Write)
			and (not (ignoreProperties and table.find(ignoreProperties, name)))
			and (a :: any)[name] ~= (b :: any)[name]
		then
			return false
		end
	end

	do
		local attributesA = a:GetAttributes()
		local attributesB = b:GetAttributes()

		for attribute, value in attributesA do
			if attributesB[attribute] ~= value then
				return false
			end
		end
		for attribute, value in attributesB do
			if attributesA[attribute] ~= value then
				return false
			end
		end
	end

	do
		local tagsA = a:GetTags()
		local tagsB = b:GetTags()

		if #tagsA ~= #tagsB then
			return false
		end

		for _, tag in tagsA do
			if not table.find(tagsB, tag) then
				return false
			end
		end
	end

	return true
end

return areInstancesSame
