local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local Settings = require(script.Parent.Settings)

return function(t: TestContext)
	t.test("Load returns valid settings with defaults", function()
		local settings = Settings.Load(t.plugin)
		t.expect(settings.ResizeMode).toBe("OuterTouch")
		t.expect(settings.SelectionThreshold).toBe("25")
		t.expect(settings.ClassicUI).toBe(false)
		t.expect(settings.WindowPosition ~= nil).toBe(true)
		t.expect(settings.WindowAnchor ~= nil).toBe(true)
	end)

	t.test("SplineJoin options default and round-trip independently", function()
		local settings = Settings.Load(t.plugin)
		local saved = table.clone(settings.SplineJoin)
		t.expect(settings.SplineJoin.AutomaticSegments).toBe(true)
		t.expect(settings.SplineJoin.Padding).toBe(0)
		settings.SplineJoin = {
			AutomaticSegments = false,
			Segments = 24,
			Padding = 0.5,
			AdvancedPadding = true,
			PaddingA = 1,
			PaddingB = 2,
		}
		Settings.Save(t.plugin, settings)
		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.SplineJoin).toEqual(settings.SplineJoin)
		reloaded.SplineJoin.Padding = 3
		t.expect(settings.SplineJoin.Padding).toBe(0.5)
		settings.SplineJoin = saved
		Settings.Save(t.plugin, settings)
	end)

	t.test("SplineJoin migrates saved ArcJoin settings", function()
		local previous = Settings.Load(t.plugin)
		t.plugin:SetSetting("resizeAlignState", {
			ResizeMode = "ArcJoin",
			ArcJoin = {
				AutomaticSegments = false,
				Segments = 24,
				Padding = 0.5,
				AdvancedPadding = true,
				PaddingA = 1,
				PaddingB = 2,
			},
		})
		local settings = Settings.Load(t.plugin)
		t.expect(settings.ResizeMode).toBe("SplineJoin")
		t.expect(settings.SplineJoin.AutomaticSegments).toBe(false)
		t.expect(settings.SplineJoin.Segments).toBe(24)
		t.expect(settings.SplineJoin.Padding).toBe(0.5)
		Settings.Save(t.plugin, previous)
	end)

	t.test("Save and Load round-trips", function()
		local settings = Settings.Load(t.plugin)
		settings.ResizeMode = "ButtJoint"
		settings.SelectionThreshold = "15"
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.ResizeMode).toBe("ButtJoint")
		t.expect(reloaded.SelectionThreshold).toBe("15")

		-- Restore defaults
		settings.ResizeMode = "OuterTouch"
		settings.SelectionThreshold = "25"
		Settings.Save(t.plugin, settings)
	end)

	t.test("ClassicUI round-trips", function()
		local settings = Settings.Load(t.plugin)
		settings.ClassicUI = true
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.ClassicUI).toBe(true)

		-- Restore
		settings.ClassicUI = false
		Settings.Save(t.plugin, settings)
	end)

	t.test("AcuteWedgeJoin round-trips", function()
		local settings = Settings.Load(t.plugin)
		settings.AcuteWedgeJoin = false
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.AcuteWedgeJoin).toBe(false)

		-- Restore
		settings.AcuteWedgeJoin = true
		Settings.Save(t.plugin, settings)
	end)

	t.test("RoundedJoin cylinder defaults off and round-trips", function()
		local settings = Settings.Load(t.plugin)
		t.expect(settings.UseCylinderForRoundedJoin).toBe(false)
		settings.UseCylinderForRoundedJoin = true
		Settings.Save(t.plugin, settings)
		t.expect(Settings.Load(t.plugin).UseCylinderForRoundedJoin).toBe(true)
		settings.UseCylinderForRoundedJoin = false
		Settings.Save(t.plugin, settings)
	end)

	t.test("All resize modes round-trip", function()
		local modes = {
			"OuterTouch",
			"InnerTouch",
			"WedgeJoin",
			"RoundedJoin",
			"SplineJoin",
			"ButtJoint",
			"ExtendUpTo",
			"ExtendInto",
		}
		for _, mode in modes do
			local settings = Settings.Load(t.plugin)
			settings.ResizeMode = mode
			Settings.Save(t.plugin, settings)

			local reloaded = Settings.Load(t.plugin)
			t.expect(reloaded.ResizeMode).toBe(mode)
		end

		-- Restore
		local settings = Settings.Load(t.plugin)
		settings.ResizeMode = "OuterTouch"
		Settings.Save(t.plugin, settings)
	end)

	t.test("All threshold values round-trip", function()
		local thresholds = { "25", "15", "Exact" }
		for _, threshold in thresholds do
			local settings = Settings.Load(t.plugin)
			settings.SelectionThreshold = threshold
			Settings.Save(t.plugin, settings)

			local reloaded = Settings.Load(t.plugin)
			t.expect(reloaded.SelectionThreshold).toBe(threshold)
		end

		-- Restore
		local settings = Settings.Load(t.plugin)
		settings.SelectionThreshold = "25"
		Settings.Save(t.plugin, settings)
	end)

	t.test("WindowPosition round-trips", function()
		local settings = Settings.Load(t.plugin)
		settings.WindowPosition = Vector2.new(100, 200)
		settings.WindowAnchor = Vector2.new(0.5, 0.5)
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.WindowPosition.X).toBe(100)
		t.expect(reloaded.WindowPosition.Y).toBe(200)
		t.expect(reloaded.WindowAnchor.X).toBe(0.5)
		t.expect(reloaded.WindowAnchor.Y).toBe(0.5)

		-- Restore
		settings.WindowPosition = Vector2.new(24, 24)
		settings.WindowAnchor = Vector2.new(0, 0)
		Settings.Save(t.plugin, settings)
	end)

	t.test("HaveHelp and DoneTutorial round-trip", function()
		local settings = Settings.Load(t.plugin)
		settings.HaveHelp = false
		settings.DoneTutorial = true
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.HaveHelp).toBe(false)
		t.expect(reloaded.DoneTutorial).toBe(true)

		-- Restore
		settings.HaveHelp = true
		settings.DoneTutorial = false
		Settings.Save(t.plugin, settings)
	end)
end
