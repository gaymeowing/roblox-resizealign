local CoreGui = game:GetService("CoreGui")

local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local Packages = script.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local ResizeAlignGui = require(script.Parent.ResizeAlignGui)
local Settings = require(script.Parent.Settings)

local e = React.createElement

local function makeTestSettings()
	return {
		WindowPosition = Vector2.zero,
		WindowAnchor = Vector2.zero,
		WindowHeightDelta = 0,
		DoneTutorial = false,
		HaveHelp = false,
		ResizeMode = "OuterTouch",
		AcuteWedgeJoin = true,
		UseCylinderForRoundedJoin = true,
		ArcJoin = table.clone(require(script.Parent.Settings).DefaultArcJoinOptions),
		SelectionThreshold = "25",
		ClassicUI = false,
	}
end

local function renderGui(props: {
	ClassicUI: boolean?,
	ResizeMode: string?,
	HaveHelp: boolean?,
	Check: ((ScreenGui, Settings.ResizeAlignSettings, () -> ()) -> ())?,
	GuiState: string?,
	FaceState: string?,
	Panelized: boolean?,
	HoverFace: any?,
	SelectedFace: any?,
})
	local settings = makeTestSettings()
	settings.ClassicUI = props.ClassicUI or false
	settings.ResizeMode = props.ResizeMode or "OuterTouch"
	settings.HaveHelp = props.HaveHelp or false

	local screen = Instance.new("ScreenGui")
	screen.Name = "ResizeAlignGuiTest"
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = CoreGui

	local root = ReactRoblox.createRoot(screen)
	local function render()
		ReactRoblox.act(function()
			root:render(e(ResizeAlignGui, {
				GuiState = props.GuiState or "active",
				CurrentSettings = settings,
				UpdatedSettings = function() end,
				HandleAction = function() end,
				Panelized = props.Panelized or false,
				FaceState = props.FaceState or "FaceA",
				HoverFace = props.HoverFace,
				SelectedFace = props.SelectedFace,
			}))
		end)
	end
	render()

	local ok, err = pcall(function()
		if props.Check then
			props.Check(screen, settings, render)
		end
	end)
	ReactRoblox.act(function()
		root:unmount()
	end)
	screen:Destroy()
	assert(ok, tostring(err))
end

return function(t: TestContext)
	t.test("Attached menus follow selection in both UI styles", function()
		for _, classic in { false, true } do
			for _, mode in { "ArcJoin", "OuterTouch", "InnerTouch", "RoundedJoin" } do
				renderGui({
					ClassicUI = classic,
					ResizeMode = mode,
					HaveHelp = true,
					Check = function(screen)
						local arc = screen:FindFirstChild("ArcJoinOptions", true)
						local outer = screen:FindFirstChild("OuterTouchOptions", true)
						t.expect(arc ~= nil).toBe(mode == "ArcJoin")
						t.expect(outer ~= nil).toBe(mode == "OuterTouch")
						local panel = arc or outer
						if panel then
							t.expect(panel.LayoutOrder).toBe(if arc then 8 else 2)
							t.expect(panel.Aligned.Position.X.Offset).toBe(if classic then 0 else 20)
							t.expect(panel.Aligned.Outline.Stroke.Color).toBe(Color3.new(1, 1, 1))
						end
						if arc then
							local preview = screen:FindFirstChild("ArcJoin", true):FindFirstChild("Filler", true)
							t.expect(preview:IsA("Model")).toBe(true)
							t.expect(preview:FindFirstChildWhichIsA("BasePart") ~= nil).toBe(true)
							t.expect(arc.Aligned.Content:FindFirstChild("Segments") == nil).toBe(true)
							t.expect(panel.Aligned.Outline.BackgroundTransparency).toBe(1)
							t.expect(panel.Aligned.Background.BackgroundColor3).toBe(Color3.fromRGB(18, 18, 18))
							local textbox = arc.Aligned.Content.Padding:FindFirstChild("TextBox", true)
							t.expect(textbox.ClearTextOnFocus).toBe(false)
							t.expect(textbox.Text:find("studs", 1, true) ~= nil).toBe(true)
						end
					end,
				})
			end
		end
	end)

	t.test("Arc menu opens with the same outline and height as reselection", function()
		for _, classic in { false, true } do
			renderGui({
				ClassicUI = classic,
				ResizeMode = "ArcJoin",
				HaveHelp = true,
				Check = function(screen, settings, render)
					local panel = screen:FindFirstChild("ArcJoinOptions", true)
					local header = screen:FindFirstChild("ArcJoin", true)
					local height = panel.AbsoluteSize.Y
					t.expect(height > 0).toBe(true)
					t.expect(panel.ZIndex > header.ZIndex).toBe(true)
					t.expect(panel.Aligned.Outline.AbsolutePosition.Y).toBe(header.AbsolutePosition.Y)
					settings.ResizeMode = "InnerTouch"
					render()
					settings.ResizeMode = "ArcJoin"
					render()
					panel = screen:FindFirstChild("ArcJoinOptions", true)
					t.expect(panel.AbsoluteSize.Y).toBe(height)
					t.expect(panel.Aligned.Outline.AbsolutePosition.Y).toBe(header.AbsolutePosition.Y)
					settings.ArcJoin.AdvancedPadding = true
					render()
					t.expect(panel.AbsoluteSize.Y).toBe(height)
					settings.ArcJoin.AutomaticSegments = false
					render()
					t.expect(panel.AbsoluteSize.Y > height).toBe(true)
					local content = panel.Aligned.Content
					local a, b =
						content.AutomaticSegments:FindFirstChild("CheckBox", true),
						content.AdvancedPadding:FindFirstChild("CheckBox", true)
					t.expect(a.AbsolutePosition.X + a.AbsoluteSize.X).toBe(b.AbsolutePosition.X + b.AbsoluteSize.X)
					settings.WindowHeightDelta = -250
					render()
					local scroll = screen:FindFirstChild("Scroll", true)
					t.expect(header.AbsolutePosition.Y >= scroll.AbsolutePosition.Y).toBe(true)
					t.expect(
						header.AbsolutePosition.Y + header.AbsoluteSize.Y
							<= scroll.AbsolutePosition.Y + scroll.AbsoluteWindowSize.Y
					).toBe(true)
				end,
			})
		end
	end)

	t.test("Native scrolling leaves focus alone while minimum height follows the options", function()
		for _, classic in { false, true } do
			renderGui({
				ClassicUI = classic,
				ResizeMode = "ArcJoin",
				Check = function(screen, settings, render)
					settings.WindowHeightDelta = -10000
					render()
					local scroll = screen:FindFirstChild("Scroll", true)
					t.expect(scroll.ScrollingEnabled).toBe(true)
					t.expect(screen:FindFirstChild("SectionScroll", true) == nil).toBe(true)
					t.expect(scroll.CanvasPosition.Y).toBe(0)
					local autoHeight = scroll.Parent.Parent.AbsoluteSize.Y
					settings.ArcJoin.AutomaticSegments = false
					render()
					t.expect(scroll.Parent.Parent.AbsoluteSize.Y > autoHeight).toBe(true)
					t.expect(scroll.CanvasPosition.Y).toBe(0)
				end,
			})
		end
	end)

	t.test("Rounded Join menu switches between segmented and original cylinder previews", function()
		for _, classic in { false, true } do
			renderGui({
				ClassicUI = classic,
				ResizeMode = "RoundedJoin",
				Check = function(screen, settings, render)
					local menu = screen:FindFirstChild("RoundedJoinOptions", true)
					t.expect(menu.LayoutOrder).toBe(6)
					for _, cylinder in { false, true, false } do
						settings.UseCylinderForRoundedJoin = cylinder
						render()
						local filler = screen:FindFirstChild("RoundedJoin", true):FindFirstChild("Filler", true)
						t.expect(filler:IsA("Part")).toBe(cylinder)
						if cylinder then
							t.expect(filler.Shape).toBe(Enum.PartType.Cylinder)
							local sawFade = false
							for _ = 1, 24 do
								task.wait(0.05)
								if filler.Transparency > 0 and filler.Transparency < 1 then
									sawFade = true
								end
							end
							t.expect(sawFade).toBe(true)
						else
							t.expect(filler:IsA("Model")).toBe(true)
						end
					end
				end,
			})
		end
	end)

	t.test("Modern UI smoke", function()
		renderGui({ ClassicUI = false })
	end)

	t.test("Classic UI smoke", function()
		renderGui({ ClassicUI = true })
	end)

	t.test("Inactive state renders without error", function()
		renderGui({ GuiState = "inactive" })
	end)

	t.test("FaceB state renders without error", function()
		renderGui({ FaceState = "FaceB" })
	end)

	t.test("Panelized mode renders without error", function()
		renderGui({ Panelized = true })
	end)

	t.test("Classic UI inactive state renders without error", function()
		renderGui({ ClassicUI = true, GuiState = "inactive" })
	end)

	t.test("Renders with HoverFace in FaceA state", function()
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 4, 4)
		part.CFrame = CFrame.new(0, 0, 0)
		part.Parent = workspace

		renderGui({
			FaceState = "FaceA",
			HoverFace = {
				Object = part,
				Normal = Enum.NormalId.Top,
				IsWedge = false,
			},
		})

		part:Destroy()
	end)

	t.test("Renders with SelectedFace and HoverFace in FaceB state", function()
		local partA = Instance.new("Part")
		partA.Size = Vector3.new(4, 4, 4)
		partA.CFrame = CFrame.new(-5, 0, 0)
		partA.Parent = workspace

		local partB = Instance.new("Part")
		partB.Size = Vector3.new(4, 4, 4)
		partB.CFrame = CFrame.new(5, 0, 0)
		partB.Parent = workspace

		renderGui({
			FaceState = "FaceB",
			SelectedFace = {
				Object = partA,
				Normal = Enum.NormalId.Right,
				IsWedge = false,
			},
			HoverFace = {
				Object = partB,
				Normal = Enum.NormalId.Left,
				IsWedge = false,
			},
		})

		partA:Destroy()
		partB:Destroy()
	end)

	t.test("Renders with wedge face highlights", function()
		local wedge = Instance.new("WedgePart")
		wedge.Size = Vector3.new(4, 4, 4)
		wedge.CFrame = CFrame.new(0, 0, 0)
		wedge.Parent = workspace

		renderGui({
			FaceState = "FaceA",
			HoverFace = {
				Object = wedge,
				Normal = Enum.NormalId.Top,
				IsWedge = true,
			},
		})

		wedge:Destroy()
	end)

	t.test("Renders with CornerWedge slope face highlight", function()
		local cornerWedge = Instance.new("CornerWedgePart")
		cornerWedge.Size = Vector3.new(4, 4, 4)
		cornerWedge.CFrame = CFrame.new(0, 0, 0)
		cornerWedge.Parent = workspace

		renderGui({
			FaceState = "FaceA",
			HoverFace = {
				Object = cornerWedge,
				Normal = Enum.NormalId.Right,
				CornerWedgeSide = "Right",
			},
		})

		cornerWedge:Destroy()
	end)

	t.test("All resize modes render in modern UI", function()
		local modes = {
			"OuterTouch",
			"InnerTouch",
			"WedgeJoin",
			"RoundedJoin",
			"ArcJoin",
			"ButtJoint",
			"ExtendUpTo",
			"ExtendInto",
		}
		for _, mode in modes do
			local settings = makeTestSettings()
			settings.ResizeMode = mode

			local screen = Instance.new("ScreenGui")
			screen.Name = "ResizeAlignGuiTest"
			screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			screen.Parent = CoreGui

			local root = ReactRoblox.createRoot(screen)
			ReactRoblox.act(function()
				root:render(e(ResizeAlignGui, {
					GuiState = "active",
					CurrentSettings = settings,
					UpdatedSettings = function() end,
					HandleAction = function() end,
					Panelized = false,
					FaceState = "FaceA",
					HoverFace = nil,
					SelectedFace = nil,
				}))
			end)

			ReactRoblox.act(function()
				root:unmount()
			end)
			screen:Destroy()
		end
	end)
end
