local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local areInstancesSame = require(script.Parent.areInstancesSame)

local IGNORE_GEOMETRY = { "Size", "CFrame", "Position", "Orientation", "Rotation" }

return function(t: TestContext)
	t.test("Returns false for different classes", function()
		local a = Instance.new("Part")
		local b = Instance.new("WedgePart")

		t.expect(areInstancesSame(a, b)).toBe(false)

		a:Destroy()
		b:Destroy()
	end)

	t.test("Returns true for matching independent instances", function()
		local a = Instance.new("Part")
		local b = Instance.new("Part")

		t.expect(areInstancesSame(a, b)).toBe(true)

		a:Destroy()
		b:Destroy()
	end)


	t.test("Returns true for the same instance", function()
		local a = Instance.new("Part")
		a.Color = Color3.fromRGB(255, 0, 0)
		a.Size = Vector3.new(2, 3, 4)

		t.expect(areInstancesSame(a, a)).toBe(true)

		a:Destroy()
	end)

	t.test("Returns true for a matching clone", function()
		local a = Instance.new("Part")
		a.Anchored = true
		a.Color = Color3.fromRGB(12, 34, 56)
		a.Size = Vector3.new(2, 3, 4)
		a.Material = Enum.Material.Neon
		a:SetAttribute("Foo", 1)
		a:AddTag("Bar")

		local b = a:Clone()

		t.expect(areInstancesSame(a, b)).toBe(true)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Returns false when a property differs", function()
		local a = Instance.new("Part")
		local b = Instance.new("Part")
		b.Color = Color3.fromRGB(255, 0, 128)

		t.expect(areInstancesSame(a, b)).toBe(false)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Ignores properties listed in ignoreProperties", function()
		local a = Instance.new("Part")
		local b = Instance.new("Part")
		b.Size = Vector3.new(10, 10, 10)
		b.CFrame = CFrame.new(100, 200, 300)

		t.expect(areInstancesSame(a, b, IGNORE_GEOMETRY)).toBe(true)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Still detects differences when some properties are ignored", function()
		local a = Instance.new("Part")
		local b = Instance.new("Part")
		b.Size = Vector3.new(10, 10, 10)
		b.Color = Color3.fromRGB(255, 0, 0)

		t.expect(areInstancesSame(a, b, { "Size" })).toBe(false)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Returns true when attributes match", function()
		local a = Instance.new("Folder")
		a:SetAttribute("Foo", "bar")
		a:SetAttribute("Count", 3)
		a:SetAttribute("On", false)
		local b = a:Clone()

		t.expect(areInstancesSame(a, b)).toBe(true)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Returns false when an attributes differ", function()
		local a = Instance.new("Folder")
		local b = Instance.new("Folder")
		a:SetAttribute("Foo", "bar")
		b:SetAttribute("Foo", "baz")

		t.expect(areInstancesSame(a, b)).toBe(false)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Returns false when an attribute is missing on one instance", function()
		local a = Instance.new("Folder")
		local b = Instance.new("Folder")
		a:SetAttribute("Foo", "bar")

		t.expect(areInstancesSame(a, b)).toBe(false)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Returns false when the other instance has an extra attribute", function()
		local a = Instance.new("Folder")
		local b = Instance.new("Folder")
		b:SetAttribute("Foo", "bar")

		t.expect(areInstancesSame(a, b)).toBe(false)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Returns true when tags match", function()
		local a = Instance.new("Folder")
		a:AddTag("Alpha")
		a:AddTag("Beta")
		local b = Instance.new("Folder")
		b:AddTag("Beta")
		b:AddTag("Alpha")

		t.expect(areInstancesSame(a, b)).toBe(true)
		a:Destroy()
		b:Destroy()
	end)

	t.test("Returns false when a tag is missing", function()
		local a = Instance.new("Folder")
		a:AddTag("Alpha")
		a:AddTag("Beta")
		local b = Instance.new("Folder")
		b:AddTag("Alpha")

		t.expect(areInstancesSame(a, b)).toBe(false)
		a:Destroy()
		b:Destroy()
	end)
end
