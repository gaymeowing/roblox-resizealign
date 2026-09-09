--!strict
local React = require(script.Parent.Parent.Packages.React)
local Colors = require("./PluginGui/Colors")
local e = React.createElement

local function ModeOptionsPanel(props: {
	RootRef: ((GuiObject?) -> ())?,
	LayoutOrder: number?,
	InsetLeft: number?,
	HeaderHeight: number?,
	children: { [string]: React.ReactNode }?,
})
	local contentHeight, setContentHeight = React.useState(0)
	local contentRef = React.useRef(nil :: Frame?)
	React.useEffect(function()
		if contentRef.current then
			setContentHeight(contentRef.current.AbsoluteSize.Y)
		end
	end, {})
	local content = table.clone(props.children or {})
	content.Layout = e("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})
	content.PaddingInset = e("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	local inset = props.InsetLeft or 0
	local header = (props.HeaderHeight or 28) + 4
	return e("Frame", {
		ref = props.RootRef,
		ZIndex = 3,
		Size = UDim2.new(1, 0, 0, contentHeight),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		Aligned = e("Frame", {
			Position = UDim2.fromOffset(inset, 0),
			Size = UDim2.new(1, -inset, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Background = e("Frame", {
				Position = UDim2.fromOffset(2, -4),
				Size = UDim2.new(1, -4, 1, 2),
				BackgroundColor3 = Color3.fromRGB(18, 18, 18),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", {
					TopLeftRadius = UDim.new(),
					TopRightRadius = UDim.new(),
					BottomLeftRadius = UDim.new(0, 2),
					BottomRightRadius = UDim.new(0, 2),
				}),
			}),
			Outline = e("Frame", {
				ZIndex = 4,
				Position = UDim2.fromOffset(0, -header),
				Size = UDim2.new(1, 0, 1, header),
				BackgroundTransparency = 1,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Stroke = e("UIStroke", {
					Color = Colors.WHITE,
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Center,
				}),
			}),
			Content = e("Frame", {
				ref = contentRef,
				[React.Change.AbsoluteSize] = function(frame: Frame)
					setContentHeight(frame.AbsoluteSize.Y)
				end,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, content),
		}),
	})
end

return ModeOptionsPanel
