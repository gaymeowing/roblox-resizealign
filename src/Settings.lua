--!strict
local InitialPosition = Vector2.new(24, 24)
local kSettingsKey = "resizeAlignState"

local PluginGuiTypes = require("./PluginGui/Types")

export type ResizeMode = "OuterTouch" | "InnerTouch" | "WedgeJoin" | "RoundedJoin" | "SplineJoin" | "ButtJoint" | "ExtendUpTo" | "ExtendInto"
export type SplineJoinOptions = {
	-- Zero chooses the segment count automatically
	Segments: number,
}

local DEFAULT_SPLINE_JOIN_OPTIONS: SplineJoinOptions = {
	Segments = 0,
}

export type SelectionThreshold = "25" | "15" | "Exact"

export type ResizeAlignSettings = PluginGuiTypes.PluginGuiSettings & {
	ResizeMode: ResizeMode,
	AcuteWedgeJoin: boolean,
	UseCylinderForRoundedJoin: boolean,
	-- Zero uses the radius the joined faces need
	RoundedJoinRadius: number,
	SplineJoin: SplineJoinOptions,
	SelectionThreshold: SelectionThreshold,
	ClassicUI: boolean,
}

local function loadSettings(plugin: Plugin): ResizeAlignSettings
	local raw = plugin:GetSetting(kSettingsKey) or {}
	-- Only the current options are carried over, which drops ones that were
	-- saved by earlier versions such as padding
	local savedSplineJoin = raw.SplineJoin or raw.ArcJoin or {}
	local splineJoin = table.clone(DEFAULT_SPLINE_JOIN_OPTIONS)
	-- Migrate the old AutomaticSegments checkbox, which is now Segments = 0
	if savedSplineJoin.Segments ~= nil and not savedSplineJoin.AutomaticSegments then
		splineJoin.Segments = savedSplineJoin.Segments
	end
	return {
		WindowPosition = Vector2.new(
			raw.WindowPositionX or InitialPosition.X,
			raw.WindowPositionY or InitialPosition.Y
		),
		WindowAnchor = Vector2.new(
			raw.WindowAnchorX or 0,
			raw.WindowAnchorY or 0
		),
		WindowHeightDelta = if raw.WindowHeightDelta ~= nil then raw.WindowHeightDelta else 0,
		DoneTutorial = if raw.DoneTutorial ~= nil then raw.DoneTutorial else false,
		HaveHelp = if raw.HaveHelp ~= nil then raw.HaveHelp else true,

		----

		SplineJoin = splineJoin,
		ResizeMode = if raw.ResizeMode == "ArcJoin"
			then "SplineJoin"
			elseif raw.ResizeMode ~= nil then raw.ResizeMode
			else "OuterTouch",
		UseCylinderForRoundedJoin = if raw.UseCylinderForRoundedJoin ~= nil then raw.UseCylinderForRoundedJoin else true,
		RoundedJoinRadius = if raw.RoundedJoinRadius ~= nil then raw.RoundedJoinRadius else 0,
		AcuteWedgeJoin = if raw.AcuteWedgeJoin ~= nil then raw.AcuteWedgeJoin else true,
		SelectionThreshold = if raw.SelectionThreshold ~= nil then raw.SelectionThreshold else "25",
		ClassicUI = if raw.ClassicUI ~= nil then raw.ClassicUI else false,
	}
end
local function saveSettings(plugin: Plugin, settings: ResizeAlignSettings)
	plugin:SetSetting(kSettingsKey, {
		WindowPositionX = settings.WindowPosition.X,
		WindowPositionY = settings.WindowPosition.Y,
		WindowAnchorX = settings.WindowAnchor.X,
		WindowAnchorY = settings.WindowAnchor.Y,
		WindowHeightDelta = settings.WindowHeightDelta,
		DoneTutorial = settings.DoneTutorial,
		HaveHelp = settings.HaveHelp,

		----

		ResizeMode = settings.ResizeMode,
		SplineJoin = settings.SplineJoin,
		AcuteWedgeJoin = settings.AcuteWedgeJoin,
		UseCylinderForRoundedJoin = settings.UseCylinderForRoundedJoin,
		RoundedJoinRadius = settings.RoundedJoinRadius,
		SelectionThreshold = settings.SelectionThreshold,
		ClassicUI = settings.ClassicUI,
	})
end

return {
	DefaultSplineJoinOptions = DEFAULT_SPLINE_JOIN_OPTIONS,
	Load = loadSettings,
	Save = saveSettings,
}
