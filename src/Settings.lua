--!strict
local InitialPosition = Vector2.new(24, 24)
local kSettingsKey = "resizeAlignState"

local PluginGuiTypes = require("./PluginGui/Types")

export type ResizeMode = "OuterTouch" | "InnerTouch" | "WedgeJoin" | "RoundedJoin" | "ArcJoin" | "ButtJoint" | "ExtendUpTo" | "ExtendInto"
export type ArcJoinOptions = {
	AutomaticSegments: boolean,
	Segments: number,
	Padding: number,
	AdvancedPadding: boolean,
	PaddingA: number,
	PaddingB: number,
}

local DEFAULT_ARC_JOIN_OPTIONS: ArcJoinOptions = {
	AutomaticSegments = true,
	Segments = 12,
	Padding = 0,
	AdvancedPadding = false,
	PaddingA = 0,
	PaddingB = 0,
}

export type SelectionThreshold = "25" | "15" | "Exact"

export type ResizeAlignSettings = PluginGuiTypes.PluginGuiSettings & {
	ResizeMode: ResizeMode,
	AcuteWedgeJoin: boolean,
	ArcJoin: ArcJoinOptions,
	SelectionThreshold: SelectionThreshold,
	ClassicUI: boolean,
}

local function loadSettings(plugin: Plugin): ResizeAlignSettings
	local raw = plugin:GetSetting(kSettingsKey) or {}
	local arcJoin = raw.ArcJoin or {}
	for key, default in DEFAULT_ARC_JOIN_OPTIONS do
		if arcJoin[key] == nil then
			arcJoin[key] = default
		end
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

		ArcJoin = arcJoin,
		ResizeMode = if raw.ResizeMode ~= nil then raw.ResizeMode else "OuterTouch",
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
		ArcJoin = settings.ArcJoin,
		AcuteWedgeJoin = settings.AcuteWedgeJoin,
		SelectionThreshold = settings.SelectionThreshold,
		ClassicUI = settings.ClassicUI,
	})
end

return {
	DefaultArcJoinOptions = DEFAULT_ARC_JOIN_OPTIONS,
	Load = loadSettings,
	Save = saveSettings,
}
