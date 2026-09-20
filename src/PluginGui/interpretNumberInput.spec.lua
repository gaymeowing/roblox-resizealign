local TestTypes = require(script.Parent.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local interpretNumberInput = require(script.Parent.interpretNumberInput)

return function(t: TestContext)
	t.test("Interprets numbers and expressions", function()
		t.expect(interpretNumberInput("12")).toBe(12)
		t.expect(interpretNumberInput(" 2 * 3 ")).toBe(6)
		t.expect(interpretNumberInput("/8")).toBe(45)
		t.expect(interpretNumberInput("nonsense")).toBe(nil)
		t.expect(interpretNumberInput("")).toBe(nil)
		t.expect(interpretNumberInput("automatic")).toBe(nil)
	end)

	t.test("Empty text is zero only when requested", function()
		t.expect(interpretNumberInput("", true)).toBe(0)
		t.expect(interpretNumberInput("  ", true)).toBe(0)
		t.expect(interpretNumberInput("automatic", true)).toBe(nil)
	end)

	t.test("Zero label in any case or empty text is zero", function()
		for _, text in { "Automatic", "automatic", " AuToMaTiC ", "", "  ", "0" } do
			t.expect(interpretNumberInput(text, false, "Automatic")).toBe(0)
		end
		t.expect(interpretNumberInput("12", false, "Automatic")).toBe(12)
		t.expect(interpretNumberInput("automati", false, "Automatic")).toBe(nil)
	end)
end
