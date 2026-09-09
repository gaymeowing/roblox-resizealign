--!strict
local CoreGui = game:GetService("CoreGui")

local Src = script.Parent
local Packages = Src.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local Colors = require("./PluginGui/Colors")
local HelpGui = require("./PluginGui/HelpGui")
local SubPanel = require("./PluginGui/SubPanel")
local PluginGui = require("./PluginGui/PluginGui")
local OperationButton = require("./PluginGui/OperationButton")
local ChipForToggle = require("./PluginGui/ChipForToggle")
local Checkbox = require("./PluginGui/Checkbox")
local Settings = require("./Settings")
local ModeOptionsPanel = require("./ModeOptionsPanel")
local NumberInput = require("./PluginGui/NumberInput")
local ModeDemo = require("./ModeDemo")
local PluginGuiTypes = require("./PluginGui/Types")
local FaceHighlight = require("./FaceHighlight")
local doExtend = require("./doExtend")

type Face = doExtend.Face

local e = React.createElement

local function createNextOrder()
	local order = 0
	return function()
		order += 1
		return order
	end
end

local function ArcJoinOptions(props: {
	RootRef: ((GuiObject?) -> ())?,
	Options: Settings.ArcJoinOptions,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
	InsetLeft: number?,
	HeaderHeight: number?,
})
	local options = props.Options
	local function paddingInput(key: "Padding" | "PaddingA" | "PaddingB")
		return e(NumberInput, {
			Value = options[key],
			LayoutOrder = 1,
			EmptyAsZero = true,
			Unit = " studs",
			ValueEntered = function(value: number): number
				if value >= 0 and value <= 2048 then
					options[key] = value
					props.UpdatedSettings()
				end
				return options[key]
			end,
		})
	end

	local function paddingField(label: string, key: "Padding" | "PaddingA" | "PaddingB", order: number)
		return e("Frame", {
			Size = UDim2.new(
				if options.AdvancedPadding then 0.5 else 1,
				if options.AdvancedPadding then -3 else 0,
				1,
				0
			),
			BackgroundTransparency = 1,
			LayoutOrder = order,
		}, {
			Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			Label = e("TextLabel", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = Colors.WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.SourceSans,
				TextSize = 16,
				LayoutOrder = 0,
			}),
			Input = paddingInput(key),
		})
	end

	local content = {
		AutomaticSegments = e(Checkbox, {
			Label = "Automatic segments",
			Checked = options.AutomaticSegments,
			LayoutOrder = 1,
			Changed = function(value: boolean)
				options.AutomaticSegments = value
				props.UpdatedSettings()
			end,
		}),
		Segments = not options.AutomaticSegments and e(NumberInput, {
			Label = "Segments",
			Value = options.Segments,
			LayoutOrder = 2,
			ValueEntered = function(value: number): number
				if value % 1 == 0 and value >= 1 then
					options.Segments = value
					options.AutomaticSegments = false
					props.UpdatedSettings()
				end
				return options.Segments
			end,
		}),
		AdvancedPadding = e(Checkbox, {
			Label = "Advanced padding",
			Checked = options.AdvancedPadding,
			LayoutOrder = 3,
			Changed = function(value: boolean)
				options.AdvancedPadding = value
				props.UpdatedSettings()
			end,
		}),
		Padding = e("Frame", {
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Both = not options.AdvancedPadding and paddingField("Both ends", "Padding", 1),
			First = options.AdvancedPadding and paddingField("First part", "PaddingA", 1),
			Second = options.AdvancedPadding and paddingField("Second part", "PaddingB", 2),
		}),
	}
	local help = {
		AutomaticSegments = "Choose the number of clones automatically from the arc length and curvature. Turn this off to enter a segment count.",
		Segments = "Number of clones making up the arc. More segments produce a smoother curve.",
		AdvancedPadding = "Set padding separately for the first and second selected parts. Turn this off to use one value for both ends.",
		Padding = "Extend the selected parts by this amount before creating the arc. Padding reduces the space the arc spans; zero adds no padding.",
	}
	for name, element in content do
		if element then
			content[name] = e(HelpGui.WithHelpIcon, {
				LayoutOrder = element.props.LayoutOrder,
				Subject = element,
				Help = e(HelpGui.BasicTooltip, { HelpRichText = help[name] }),
			})
		end
	end

	return e(ModeOptionsPanel, {
		RootRef = props.RootRef,
		LayoutOrder = props.LayoutOrder,
		InsetLeft = props.InsetLeft,
		HeaderHeight = props.HeaderHeight,
	}, content)
end

local function OuterTouchOptions(props: {
	RootRef: ((GuiObject?) -> ())?,
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
	InsetLeft: number?,
	HeaderHeight: number?,
})
	return e(ModeOptionsPanel, {
		RootRef = props.RootRef,
		LayoutOrder = props.LayoutOrder,
		InsetLeft = props.InsetLeft,
		HeaderHeight = props.HeaderHeight,
	}, {
		AcuteWedgeJoin = e(HelpGui.WithHelpIcon, {
			Subject = e(Checkbox, {
				Label = "Wedge Join tight corners",
				Checked = props.Settings.AcuteWedgeJoin,
				Changed = function(value: boolean)
					props.Settings.AcuteWedgeJoin = value
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Automatically use Wedge Join instead of Outer Touch when the angle between faces is small to allow the formation of a sharp point for tight corners.",
			}),
		}),
	})
end

local function RoundedJoinOptions(props: {
	RootRef: ((GuiObject?) -> ())?,
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
	InsetLeft: number?,
	HeaderHeight: number?,
})
	return e(ModeOptionsPanel, {
		RootRef = props.RootRef,
		LayoutOrder = props.LayoutOrder,
		InsetLeft = props.InsetLeft,
		HeaderHeight = props.HeaderHeight,
	}, {
		UseCylinderForRoundedJoin = e(HelpGui.WithHelpIcon, {
			Subject = e(Checkbox, {
				Label = "Use Cylinder For Join",
				Checked = props.Settings.UseCylinderForRoundedJoin,
				Changed = function(value: boolean)
					props.Settings.UseCylinderForRoundedJoin = value
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Uses a Cylinder part for joining both parts, rather than using an Arc Join.",
			}),
		}),
	})
end

local function ResizeMethodPanel(props: {
	OnSelectedBoundsChanged: (GuiObject?, GuiObject?) -> (),
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.ResizeMode
	local target, setTarget = React.useState(nil :: GuiObject?)
	local endTarget, setEndTarget = React.useState(nil :: GuiObject?)
	React.useLayoutEffect(function()
		props.OnSelectedBoundsChanged(target, endTarget)
	end, { target, endTarget })

	local function makeButton(text: string, mode: Settings.ResizeMode, helpText: string, layoutOrder: number)
		local HEIGHT = 28
		local openBelow = (mode == "ArcJoin" or mode == "OuterTouch" or mode == "RoundedJoin") and current == mode
		return e(HelpGui.WithHelpIcon, {
			LayoutOrder = layoutOrder,
			Subject = e("Frame", {
				ref = if current == mode then setTarget else nil,
				ZIndex = 2,
				Size = UDim2.new(1, 0, 0, HEIGHT),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Border = current == mode and not openBelow and e("UIStroke", {
					Color = Colors.WHITE,
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Button = e(ChipForToggle, {
					Text = text,
					IsCurrent = current == mode,
					JoinedRight = true,
					OpenBelow = openBelow,
					HideOutline = true,
					Height = HEIGHT,
					TextSize = 24,
					LayoutOrder = 1,
					OnClick = function()
						props.Settings.ResizeMode = mode
						props.UpdatedSettings()
					end,
				}),
				Demo = e(ModeDemo, {
					PreviewMode = if mode == "RoundedJoin" and props.Settings.UseCylinderForRoundedJoin then "RoundedJoinCylinder" else mode,
					JoinedLeft = true,
					OpenBelow = openBelow,
					Animate = current == mode,
					Size = UDim2.fromOffset(60, HEIGHT),
					LayoutOrder = 2,
				}),
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = helpText,
			}),
		})
	end

	return e(SubPanel, {
		Title = "Resize Method",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		OuterTouch = makeButton(
			"Outer Touch",
			"OuterTouch",
			"Extend both parts until their faces align at the outermost points. Good for sealing up non-right-angle joints.",
			1
		),
		OuterTouchOptions = current == "OuterTouch" and e(OuterTouchOptions, {
			RootRef = setEndTarget,
			Settings = props.Settings,
			UpdatedSettings = props.UpdatedSettings,
			InsetLeft = if props.Settings.HaveHelp then 20 else 0,
			HeaderHeight = 28,
			LayoutOrder = 2,
		}),
		InnerTouch = makeButton(
			"Inner Touch",
			"InnerTouch",
			"Extend both parts until their faces align at the innermost points.",
			3
		),
		WedgeJoin = makeButton(
			"Wedge Join",
			"WedgeJoin",
			"Extend to inner touch and fill the remaining gap with wedge parts to form a sharp point. This mode always avoids Z-fighting.",
			4
		),
		RoundedJoin = makeButton(
			"Rounded Join",
			"RoundedJoin",
			"Connect the selected faces with an automatic arc using fixed padding, or use the original cylinder filler.",
			5
		),
		RoundedJoinOptions = current == "RoundedJoin" and e(RoundedJoinOptions, {
			RootRef = setEndTarget,
			Settings = props.Settings,
			UpdatedSettings = props.UpdatedSettings,
			InsetLeft = if props.Settings.HaveHelp then 20 else 0,
			HeaderHeight = 28,
			LayoutOrder = 6,
		}),
		ArcJoin = makeButton(
			"Arc Join",
			"ArcJoin",
			"Connect the selected faces with an arc of clones of the first part. Segments are automatic by default. Padding extends each selected end before the arc begins.",
			7
		),
		ArcJoinOptions = current == "ArcJoin" and e(ArcJoinOptions, {
			RootRef = setEndTarget,
			Options = props.Settings.ArcJoin,
			UpdatedSettings = props.UpdatedSettings,
			InsetLeft = if props.Settings.HaveHelp then 20 else 0,
			HeaderHeight = 28,
			LayoutOrder = 8,
		}),
		ButtJoint = makeButton(
			"Butt Joint",
			"ButtJoint",
			"The first face butts up against the side of the second, with no overlap. Only works for right-angle intersections.",
			9
		),
		ExtendUpTo = makeButton(
			"Extend Up To",
			"ExtendUpTo",
			"Only the first face is extended out until it just touches the second face.",
			10
		),
		ExtendInto = makeButton(
			"Extend Into",
			"ExtendInto",
			"Only the first face is extended out until it fully penetrates the second face.",
			11
		),
	})
end

local function SelectionBehaviorPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.SelectionThreshold
	return e(SubPanel, {
		Title = "Reach Around Edge Threshold",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Buttons = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 1,
			Subject = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				ListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Threshold25 = e(ChipForToggle, {
					Text = "25%",
					IsCurrent = current == "25",
					LayoutOrder = 1,
					OnClick = function()
						props.Settings.SelectionThreshold = "25"
						props.UpdatedSettings()
					end,
				}),
				Threshold15 = e(ChipForToggle, {
					Text = "15%",
					IsCurrent = current == "15",
					LayoutOrder = 2,
					OnClick = function()
						props.Settings.SelectionThreshold = "15"
						props.UpdatedSettings()
					end,
				}),
				ThresholdExact = e(ChipForToggle, {
					Text = "Exact",
					IsCurrent = current == "Exact",
					LayoutOrder = 3,
					OnClick = function()
						props.Settings.SelectionThreshold = "Exact"
						props.UpdatedSettings()
					end,
				}),
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = 'How much margin near an edge should "Reach Around" for the back face to allow selection without camera movement.\n'
					.. "<b>•25%</b> — A large threshold; easier to select backfaces.\n"
					.. "<b>•15%</b> — Same behavior but with a smaller threshold.\n"
					.. "<b>•Exact</b> — Only the directly hovered face is selected; More precision.",
			}),
		}),
	})
end

local function OptionsPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Advanced Options",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		ClassicUI = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 1,
			Subject = e(Checkbox, {
				Label = "Classic UI style",
				Checked = props.Settings.ClassicUI,
				Changed = function(newValue: boolean)
					props.Settings.ClassicUI = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Switch to something more similar to the classic ResizeAlign UI.",
			}),
		}),
	})
end

local function CloseButton(props: {
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		CancelButton = e(OperationButton, {
			Text = "Close <i>ResizeAlign</i>",
			Color = Colors.DARK_RED,
			Disabled = false,
			Height = 30,
			OnClick = function()
				props.HandleAction("cancel")
			end,
		}),
	})
end

-- Classic UI: OperationButton with icon
local function IconOperationButton(props: {
	RootRef: ((GuiObject?) -> ())?,
	Text: string,
	SubText: string,
	IsCurrent: boolean,
	Icon: string?,
	PreviewMode: ModeDemo.PreviewMode?,
	OpenBelow: boolean?,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	local fullText = string.format('%s\n<i><font size="12" color="#AAA">%s</font></i>', props.Text, props.SubText)
	return e("Frame", {
		ref = props.RootRef,
		ZIndex = 2,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		Button = e("Frame", {
			Size = UDim2.new(1, -64, 0, 32),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			Inner = e(OperationButton, {
				Text = fullText,
				Color = if props.IsCurrent then Colors.DARK_RED else Colors.GREY,
				Disabled = false,
				Height = 32,
				OnClick = props.OnClick,
				JoinedRight = true,
				OpenBelow = props.OpenBelow,
			}),
		}),
		Icon = if props.PreviewMode
			then e(ModeDemo, {
				PreviewMode = props.PreviewMode,
				JoinedLeft = true,
				OpenBelow = props.OpenBelow,
				Animate = props.IsCurrent,
				Size = UDim2.fromOffset(64, 32),
				LayoutOrder = 2,
			})
			else e("ImageLabel", {
				Size = UDim2.fromOffset(64, 32),
				BackgroundTransparency = 1,
				Image = props.Icon,
				LayoutOrder = 2,
			}, {
				Corner = e("UICorner", {
					TopLeftRadius = UDim.new(),
					BottomLeftRadius = UDim.new(),
					TopRightRadius = UDim.new(0, 4),
					BottomRightRadius = UDim.new(0, if props.OpenBelow then 0 else 4),
				}),
			}),
	})
end

local RESIZE_MODE_ICONS: { [Settings.ResizeMode]: string } = {
	OuterTouch = "rbxassetid://9756984675",
	InnerTouch = "rbxassetid://9756984928",
	WedgeJoin = "rbxassetid://9756984675",
	RoundedJoin = "rbxassetid://9834555074",
	ButtJoint = "rbxassetid://9756985700",
	ExtendUpTo = "rbxassetid://9756985017",
	ExtendInto = "rbxassetid://9756985126",
}

local function ClassicResizeMethodPanel(props: {
	OnSelectedBoundsChanged: (GuiObject?, GuiObject?) -> (),
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.ResizeMode
	local target, setTarget = React.useState(nil :: GuiObject?)
	local endTarget, setEndTarget = React.useState(nil :: GuiObject?)
	React.useLayoutEffect(function()
		props.OnSelectedBoundsChanged(target, endTarget)
	end, { target, endTarget })
	local function makeButton(mode: Settings.ResizeMode, label: string, subText: string, layoutOrder: number)
		return e(IconOperationButton, {
			RootRef = if current == mode then setTarget else nil,
			Text = label,
			SubText = subText,
			IsCurrent = current == mode,
			Icon = RESIZE_MODE_ICONS[mode],
			PreviewMode = if mode == "RoundedJoin" and props.Settings.UseCylinderForRoundedJoin then "RoundedJoinCylinder"
				else if mode == "ArcJoin" or mode == "RoundedJoin" then mode else nil,
			OpenBelow = (mode == "ArcJoin" or mode == "OuterTouch" or mode == "RoundedJoin") and current == mode,
			LayoutOrder = layoutOrder,
			OnClick = function()
				props.Settings.ResizeMode = mode
				props.UpdatedSettings()
			end,
		})
	end
	return e(SubPanel, {
		Title = "Resize Method",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		OuterTouch = makeButton("OuterTouch", "Outer Touch", "extend to outermost alignment", 1),
		OuterTouchOptions = current == "OuterTouch" and e(OuterTouchOptions, {
			RootRef = setEndTarget,
			HeaderHeight = 32,
			Settings = props.Settings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 2,
		}),
		InnerTouch = makeButton("InnerTouch", "Inner Touch", "extend to innermost alignment", 3),
		RoundedJoin = makeButton("RoundedJoin", "Rounded Join", "rounded arc or cylinder filler", 5),
		RoundedJoinOptions = current == "RoundedJoin" and e(RoundedJoinOptions, {
			RootRef = setEndTarget,
			Settings = props.Settings,
			UpdatedSettings = props.UpdatedSettings,
			HeaderHeight = 32,
			LayoutOrder = 6,
		}),
		ArcJoin = makeButton("ArcJoin", "Arc Join", "connect with an arc of clones", 7),
		ArcJoinOptions = current == "ArcJoin" and e(ArcJoinOptions, {
			RootRef = setEndTarget,
			HeaderHeight = 32,
			Options = props.Settings.ArcJoin,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 8,
		}),
		ButtJoint = makeButton("ButtJoint", "Butt Joint", "butt up against second face", 9),
		ExtendUpTo = makeButton("ExtendUpTo", "Extend Up To", "extend to first contact", 10),
		ExtendInto = makeButton("ExtendInto", "Extend Into", "extend to full penetration", 11),
	})
end

local THRESHOLD_ICONS: { [Settings.SelectionThreshold]: string } = {
	["25"] = "rbxassetid://9758180727",
	["15"] = "rbxassetid://9758180952",
	Exact = "rbxassetid://9758180541",
}

local function ClassicSelectionBehaviorPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.SelectionThreshold
	local function makeButton(
		threshold: Settings.SelectionThreshold,
		label: string,
		subText: string,
		layoutOrder: number
	)
		return e(IconOperationButton, {
			Text = label,
			SubText = subText,
			IsCurrent = current == threshold,
			Icon = THRESHOLD_ICONS[threshold],
			LayoutOrder = layoutOrder,
			OnClick = function()
				props.Settings.SelectionThreshold = threshold
				props.UpdatedSettings()
			end,
		})
	end
	return e(SubPanel, {
		Title = "Selection Behavior",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Threshold25 = makeButton("25", "25% Threshold", "large edge threshold", 1),
		Threshold15 = makeButton("15", "15% Threshold", "small edge threshold", 2),
		ThresholdExact = makeButton("Exact", "Exact Target", "no threshold", 3),
	})
end

local function AdornmentOverlay(props: {
	HoverFace: Face?,
	SelectedFace: Face?,
	FaceState: "FaceA" | "FaceB",
})
	local children: { [string]: any } = {}

	if props.SelectedFace then
		children.SelectedFace = e(FaceHighlight, {
			Face = props.SelectedFace,
			Color = Color3.new(1, 0, 0),
			Transparency = 0,
			ZIndexOffset = 0,
		})
	end

	if props.HoverFace then
		local hoverColor = if props.FaceState == "FaceA" then Color3.new(1, 0, 0) else Color3.new(0, 0, 1)
		children.HoverFace = e(FaceHighlight, {
			Face = props.HoverFace,
			Color = hoverColor,
			Transparency = 0.5,
			ZIndexOffset = 2,
		})
	end

	return ReactRoblox.createPortal(
		e("Folder", {
			Name = "$ResizeAlignAdornments",
			Archivable = false,
		}, children),
		CoreGui
	)
end

local function ClassicContent(props: {
	OnSelectedBoundsChanged: (GuiObject?, GuiObject?) -> (),
	CurrentSettings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
})
	local currentSettings = props.CurrentSettings
	local nextOrder = createNextOrder()
	return React.createElement(React.Fragment, nil, {
		ClassicResizeMethod = e(ClassicResizeMethodPanel, {
			OnSelectedBoundsChanged = props.OnSelectedBoundsChanged,
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		ClassicSelectionBehavior = e(ClassicSelectionBehaviorPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		OptionsPanel = e(SubPanel, {
			Title = "Advanced Options",
			LayoutOrder = nextOrder(),
			Padding = UDim.new(0, 4),
		}, {
			ReturnToNewUI = e(Checkbox, {
				LayoutOrder = 1,
				Label = "Classic UI style",
				Checked = currentSettings.ClassicUI,
				Changed = function(newValue: boolean)
					currentSettings.ClassicUI = newValue
					props.UpdatedSettings()
				end,
			}),
		}),
	})
end

local function ModernContent(props: {
	OnSelectedBoundsChanged: (GuiObject?, GuiObject?) -> (),
	CurrentSettings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
})
	local currentSettings = props.CurrentSettings
	local nextOrder = createNextOrder()
	return React.createElement(React.Fragment, nil, {
		ResizeMethodPanel = e(ResizeMethodPanel, {
			OnSelectedBoundsChanged = props.OnSelectedBoundsChanged,
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		SelectionBehaviorPanel = e(SelectionBehaviorPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		OptionsPanel = e(OptionsPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		CloseButton = e(CloseButton, {
			HandleAction = props.HandleAction,
			LayoutOrder = nextOrder(),
		}),
	})
end

local RESIZEALIGN_CONFIG: PluginGuiTypes.PluginGuiConfig = {
	PluginName = "ResizeAlign",
	PendingText = "...",
	TutorialElement = nil,
}

local function ResizeAlignGui(props: {
	GuiState: PluginGuiTypes.PluginGuiMode,
	CurrentSettings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	FaceState: "FaceA" | "FaceB",
	HoverFace: Face?,
	SelectedFace: Face?,
})
	local currentSettings = props.CurrentSettings
	local target, setTarget = React.useState(nil :: GuiObject?)
	local endTarget, setEndTarget = React.useState(nil :: GuiObject?)
	local minimumHeight, setMinimumHeight = React.useState(0)
	local onSelectedBoundsChanged = React.useCallback(function(first: GuiObject?, last: GuiObject?)
		setTarget(first)
		setEndTarget(last)
	end, {})
	React.useLayoutEffect(function()
		if not target then
			return
		end
		local bottom = endTarget or target
		local function updateMinimumHeight()
			local firstPosition, bottomPosition = target.AbsolutePosition, bottom.AbsolutePosition
			local firstY, bottomY = firstPosition.Y, bottomPosition.Y
			setMinimumHeight(bottomY + bottom.AbsoluteSize.Y - firstY + 28 + 8 + 8)
		end
		local firstConnection = target:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateMinimumHeight)
		local lastConnection = if endTarget
			then endTarget:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateMinimumHeight)
			else nil
		updateMinimumHeight()
		return function()
			firstConnection:Disconnect()
			if lastConnection then
				lastConnection:Disconnect()
			end
		end
	end, { target, endTarget })
	return e(PluginGui, {
		Config = RESIZEALIGN_CONFIG,
		MinWindowHeight = minimumHeight,
		State = {
			Mode = props.GuiState,
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			Panelized = props.Panelized,
		},
	}, {
		AdornmentOverlay = e(AdornmentOverlay, {
			HoverFace = props.HoverFace,
			SelectedFace = props.SelectedFace,
			FaceState = props.FaceState,
		}),
		Content = if currentSettings.ClassicUI
			then e(ClassicContent, {
				OnSelectedBoundsChanged = onSelectedBoundsChanged,
				CurrentSettings = currentSettings,
				UpdatedSettings = props.UpdatedSettings,
			})
			else e(ModernContent, {
				OnSelectedBoundsChanged = onSelectedBoundsChanged,
				CurrentSettings = currentSettings,
				UpdatedSettings = props.UpdatedSettings,
				HandleAction = props.HandleAction,
			}),
	})
end

return ResizeAlignGui
