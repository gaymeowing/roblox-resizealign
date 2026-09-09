local Settings = require(script.Parent.Settings)
local ShapeUtils = require(script.Parent.ShapeUtils)
local doExtend = require(script.Parent.doExtend)
local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local function near(a: Vector3, b: Vector3)
	assert((a - b).Magnitude < 0.0001, `Expected {a} to meet {b}`)
end

local function inside(segment, point)
	local localPoint = segment.CFrame:PointToObjectSpace(point)
	assert(math.abs(localPoint.X) <= segment.Size.X / 2 + 0.0001, "Gap along local X")
	assert(math.abs(localPoint.Y) <= segment.Size.Y / 2 + 0.0001, "Gap along local Y")
	assert(math.abs(localPoint.Z) <= segment.Size.Z / 2 + 0.0001, "Gap along local Z")
end

type Segment = ShapeUtils.ArcSegment

local function jointBetween(a: Segment, b: Segment, normal: Vector3): (Vector3, Vector3, Vector3)
	local direction = a.CFrame:VectorToWorldSpace(normal)
	local nextDirection = b.CFrame:VectorToWorldSpace(normal)
	local cross = direction:Cross(nextDirection)
	local center, nextCenter = a.CFrame.Position, b.CFrame.Position
	local joint = (center + nextCenter) / 2
	if cross.Magnitude >= 0.00001 then
		joint = center + direction * ((nextCenter - center):Cross(nextDirection):Dot(cross) / cross:Dot(cross))
	end
	return joint, direction, nextDirection
end

local function overlapOnAxis(a: Segment, b: Segment, axis: Vector3)
	if axis.Magnitude < 0.000001 then
		return
	end
	axis = axis.Unit
	local radiusA = a.CFrame:VectorToObjectSpace(axis):Abs():Dot(a.Size) / 2
	local radiusB = b.CFrame:VectorToObjectSpace(axis):Abs():Dot(b.Size) / 2
	assert(
		math.abs((b.CFrame.Position - a.CFrame.Position):Dot(axis)) <= radiusA + radiusB + 0.0001,
		"Adjacent segments have a separating gap"
	)
end

local function checkOverlap(a: Segment, b: Segment)
	local axesA = { a.CFrame.XVector, a.CFrame.YVector, a.CFrame.ZVector }
	local axesB = { b.CFrame.XVector, b.CFrame.YVector, b.CFrame.ZVector }
	for _, axis in axesA do
		overlapOnAxis(a, b, axis)
	end
	for _, axis in axesB do
		overlapOnAxis(a, b, axis)
	end
	for _, axisA in axesA do
		for _, axisB in axesB do
			overlapOnAxis(a, b, axisA:Cross(axisB))
		end
	end
end

local function checkPlan(segments: { Segment }, first: Vector3, last: Vector3, normal: Vector3, size: Vector3)
	local crossSection = Vector3.one - Vector3.new(math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z))
	inside(segments[1], first)
	inside(segments[#segments], last)
	for i, segment in segments do
		near(segment.Size * crossSection, size * crossSection)
		if i < #segments then
			checkOverlap(segment, segments[i + 1])
		end
	end
end

-- Check the entire miter on well-conditioned quarter-circle fixtures. Inferring
-- an infinite miter from nearly parallel, rounded CFrames amplifies float error.
local function checkMiters(segments: { Segment }, size: Vector3)
	for i = 1, #segments - 1 do
		local a, b = segments[i], segments[i + 1]
		local joint, direction, nextDirection = jointBetween(a, b, Vector3.xAxis)
		local plane = direction + nextDirection
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local offset = a.CFrame:VectorToWorldSpace(Vector3.new(0, y * size.Y, z * size.Z) / 2)
				local corner = joint + offset - direction * (offset:Dot(plane) / direction:Dot(plane))
				inside(a, corner)
				inside(b, corner)
			end
		end
	end
end

local function withParts(callback)
	local folder = Instance.new("WorldModel")
	local a = Instance.new("Part")
	a.Anchored = true
	a.Size = Vector3.new(4, 2, 3)
	a.CFrame = CFrame.new(-2, 0, 0)
	a.Color = Color3.fromRGB(51, 123, 201)
	a:SetAttribute("ArcTemplate", true)
	a.Parent = folder
	local attachment = Instance.new("Attachment")
	attachment.Name = "TemplateAttachment"
	attachment.Parent = a
	local b = Instance.new("Part")
	b.Anchored = true
	b.Size = Vector3.new(2, 4, 3)
	b.CFrame = CFrame.new(10, 12, 0)
	b.Parent = folder
	local ok, err = pcall(
		callback,
		folder,
		a,
		b,
		{ Object = a, Normal = Enum.NormalId.Right },
		{ Object = b, Normal = Enum.NormalId.Bottom }
	)
	folder:Destroy()
	assert(ok, tostring(err))
end

-- The unequal-height E/C regression, mirrored and selected in either order.
local function tiltedJoin(reverse: boolean, mirror: number)
	local shortFrame = CFrame.new(-1.85, 0, 0)
	local tallFrame = CFrame.new(9.4763, -6.11964 * mirror, 0) * CFrame.Angles(0, 0, -math.atan2(2, 3) * mirror)
	local shortSize, tallSize = Vector3.new(3.7, 0.7, 1), Vector3.new(19.35, 2, 1)
	local first, second = if reverse then tallFrame else shortFrame, if reverse then shortFrame else tallFrame
	local firstSize, secondSize = if reverse then tallSize else shortSize, if reverse then shortSize else tallSize
	local n1, n2 = if reverse then -Vector3.xAxis else Vector3.xAxis, if reverse then Vector3.xAxis else -Vector3.xAxis
	local start, target = first * CFrame.new(n1 * firstSize / 2), second * CFrame.new(n2 * secondSize / 2)
	return start, target, firstSize, secondSize, n1, n2
end

return function(t: TestContext)
	t.test("RoundedJoin: derives tangent endpoints from the original filler radius", function()
		for _, thickness in { 2, 4 } do
			withParts(function(folder, a, b, faceA, faceB)
				a.Size = Vector3.new(4, thickness, 3)
				b.Size = Vector3.new(thickness, 4, 3)
				local ignoredOptions = table.clone(Settings.DefaultArcJoinOptions)
				ignoredOptions.AutomaticSegments = false
				ignoredOptions.Segments = 1
				ignoredOptions.Padding = 100
				doExtend(faceA, faceB, "RoundedJoin", false, ignoredOptions)
				local radius = thickness / 2
				near(a.Size, Vector3.new(14 - radius, thickness, 3))
				near(b.Size, Vector3.new(thickness, 14 - radius, 3))
				local segments = {}
				for _, part in folder:GetChildren() do
					if part ~= a and part ~= b then
						t.expect(part.Color).toBe(a.Color)
						t.expect(part:GetAttribute("ArcTemplate")).toBe(true)
						table.insert(segments, { CFrame = part.CFrame, Size = part.Size })
					end
				end
				t.expect(#segments >= 9).toBe(true)
				checkPlan(
					segments,
					Vector3.new(10 - radius, 0, 0),
					Vector3.new(10, radius, 0),
					Vector3.xAxis,
					Vector3.new(4, thickness, 3)
				)
			end)
		end
	end)

	t.test("ArcJoin: manual count forms a curved connected chain", function()
		local size = Vector3.new(4, 2, 3)
		local segments = assert(
			ShapeUtils.planArcJoin(CFrame.identity, Vector3.new(10, 10, 0), -Vector3.yAxis, size, Vector3.xAxis, 12)
		)
		t.expect(#segments).toBe(12)
		checkPlan(segments, Vector3.zero, Vector3.new(10, 10, 0), Vector3.xAxis, size)
		-- The middle of a quarter-circle is below the straight diagonal.
		t.expect(segments[6].CFrame.X - segments[6].CFrame.Y > 3).toBe(true)
	end)

	t.test("ArcJoin: thick coarse and fine arcs cover every miter corner", function()
		for _, count in { 3, 12, 48 } do
			for _, width in { 2, 8 } do
				local size = Vector3.new(4, width, 3)
				local finish = Vector3.new(10, 10, 0)
				local segments =
					assert(ShapeUtils.planArcJoin(CFrame.identity, finish, -Vector3.yAxis, size, Vector3.xAxis, count))
				checkPlan(segments, Vector3.zero, finish, Vector3.xAxis, size)
				checkMiters(segments, size)
			end
		end
	end)

	t.test("ArcJoin: target snaps to nearer top or bottom with clone thickness inset", function()
		local target = CFrame.new(10, 0, 0) * CFrame.Angles(0, 0, 0.4)
		for _, side in { -1, 1 } do
			local start = target * CFrame.new(-10, side * 20, 0)
			local point = ShapeUtils.getArcTargetPoint(
				start,
				target,
				Vector3.new(4, 2, 3),
				Vector3.new(4, 12, 3),
				Vector3.xAxis,
				-Vector3.xAxis
			)
			near(point, target:PointToWorldSpace(Vector3.new(0, side * 5, 0)))
		end
	end)

	t.test("ArcJoin: taller templates align their edge to the shorter target", function()
		local target = CFrame.new(10, 0, 0) * CFrame.Angles(0, 0, 0.4)
		for _, side in { -1, 1 } do
			local start = target * CFrame.new(-10, -side * 20, 0)
			local size = Vector3.new(4, 12, 3)
			local point =
				ShapeUtils.getArcTargetPoint(start, target, size, Vector3.new(4, 2, 3), Vector3.xAxis, -Vector3.xAxis)
			-- Whichever side the shorter target occupies, the matching surface
			-- is flush even though the clone's center lies beyond the target face.
			near(point, target:PointToWorldSpace(Vector3.new(0, -side * 5, 0)))
			local surface = point + target.UpVector * (side * size.Y / 2)
			near(surface, target.Position + target.UpVector * side)
			local segments = assert(ShapeUtils.planArcJoin(start, point, -target.RightVector, size, Vector3.xAxis, 12))
			checkPlan(segments, start.Position, point, Vector3.xAxis, size)
		end
	end)

	t.test("ArcJoin: unequal-height tilted joins stay on the matching edge without an S bend", function()
		for _, mirror in { -1, 1 } do
			for _, reverse in { false, true } do
				local start, target, firstSize, secondSize, n1, n2 = tiltedJoin(reverse, mirror)
				local finish = ShapeUtils.getArcTargetPoint(start, target, firstSize, secondSize, n1, n2)
				near(finish, target.Position + target.UpVector * (mirror * (secondSize.Y - firstSize.Y) / 2))
				local segments =
					assert(ShapeUtils.planArcJoin(start, finish, target:VectorToWorldSpace(n2), firstSize, n1, 24))
				near(segments[1].CFrame:VectorToWorldSpace(n1), start:VectorToWorldSpace(n1))
				near(segments[#segments].CFrame:VectorToWorldSpace(n1), -target:VectorToWorldSpace(n2))
				local last = segments[#segments]
				local endDirection = last.CFrame:VectorToWorldSpace(n1)
				near(last.CFrame.Position + endDirection * last.Size.X / 2, finish)
				local previous = start:VectorToWorldSpace(n1)
				local turnSign = mirror * (if reverse then 1 else -1)
				for _, segment in segments do
					local direction = segment.CFrame:VectorToWorldSpace(n1)
					t.expect(previous:Cross(direction).Z * turnSign >= -0.0001).toBe(true)
					previous = direction
				end
				checkPlan(segments, start.Position, finish, n1, firstSize)
			end
		end
	end)

	t.test("ArcJoin: automatic tilted joins distribute the turn through both endpoints", function()
		for _, reverse in { false, true } do
			local start, target, size, targetSize, normal, targetNormal = tiltedJoin(reverse, 1)
			local finish = ShapeUtils.getArcTargetPoint(start, target, size, targetSize, normal, targetNormal)
			local segments =
				assert(ShapeUtils.planArcJoin(start, finish, target:VectorToWorldSpace(targetNormal), size, normal))
			t.expect(#segments <= 8).toBe(true)
			local previous = start:VectorToWorldSpace(normal)
			for _, segment in segments do
				local direction = segment.CFrame:VectorToWorldSpace(normal)
				local turn = math.acos(math.clamp(previous:Dot(direction), -1, 1))
				assert(turn <= math.rad(6.5), "A coarse endpoint must not consume multiple turns")
				previous = direction
			end
			near(previous, -target:VectorToWorldSpace(targetNormal))
			if reverse then
				local penultimate = segments[#segments - 1].CFrame:VectorToWorldSpace(normal)
				assert(
					math.acos(math.clamp(previous:Dot(penultimate), -1, 1)) < math.rad(3),
					"The broad flat end needs a smaller turn than the tight curved end"
				)
			end
			checkPlan(segments, start.Position, finish, normal, size)
		end
	end)

	t.test("ArcJoin: padding does not oversample tiny reverse bends", function()
		for _, reverse in { false, true } do
			for _, padding in { 0.2, 0.3, 0.4, 0.5, 0.6 } do
				local start, target, size, targetSize, normal, targetNormal = tiltedJoin(reverse, 1)
				start += start:VectorToWorldSpace(normal) * padding
				target += target:VectorToWorldSpace(targetNormal) * padding
				local finish, surfaceOffset =
					ShapeUtils.getArcTargetPoint(start, target, size, targetSize, normal, targetNormal)
				local endNormal = target:VectorToWorldSpace(targetNormal)
				local segments =
					assert(ShapeUtils.planArcJoin(start, finish, endNormal, size, normal, nil, surfaceOffset))
				assert(#segments <= 13, `Padding {padding} generated {#segments} segments`)
				checkPlan(segments, start.Position, finish, normal, size)
				near(segments[1].CFrame:VectorToWorldSpace(normal), start:VectorToWorldSpace(normal))
				near(segments[#segments].CFrame:VectorToWorldSpace(normal), -endNormal)
			end
		end
	end)

	t.test("ArcJoin: C-first padding keeps inflection segments inside the join", function()
		for _, offset in { Vector3.zero, Vector3.new(-10, 20.85, 2.5) } do
			for _, padding in { 0.5999, 0.6, 0.6001 } do
				local start, target, size, targetSize, normal, targetNormal = tiltedJoin(false, 1)
				start += offset + start:VectorToWorldSpace(normal) * padding
				target += offset + target:VectorToWorldSpace(targetNormal) * padding
				local finish, surfaceOffset =
					ShapeUtils.getArcTargetPoint(start, target, size, targetSize, normal, targetNormal)
				local segments = assert(
					ShapeUtils.planArcJoin(
						start,
						finish,
						target:VectorToWorldSpace(targetNormal),
						size,
						normal,
						nil,
						surfaceOffset
					)
				)
				local gap = (finish - start.Position).Magnitude
				for _, segment in segments do
					-- These connected segments were over 40 studs long in a gap
					-- under one stud: endpoint and overlap checks alone passed.
					assert(segment.Size.X <= gap, `Inflection produced a {segment.Size.X}-stud spike`)
					assert(
						(segment.CFrame.Position - start.Position).Magnitude <= gap + size.Y / 2,
						"Inflection moved a segment outside the join"
					)
				end
				checkPlan(segments, start.Position, finish, normal, size)
				assert(#segments <= 11, "The small padded join should not regain excessive detail")
			end
		end
	end)

	t.test("ArcJoin: padded E/C detail stays similar in either selection order", function()
		local counts = {}
		for _, reverse in { false, true } do
			local start, target, size, targetSize, normal, targetNormal = tiltedJoin(reverse, 1)
			start += start:VectorToWorldSpace(normal) * 0.6
			target += target:VectorToWorldSpace(targetNormal) * 0.6
			local finish, surfaceOffset =
				ShapeUtils.getArcTargetPoint(start, target, size, targetSize, normal, targetNormal)
			local segments = assert(
				ShapeUtils.planArcJoin(
					start,
					finish,
					target:VectorToWorldSpace(targetNormal),
					size,
					normal,
					nil,
					surfaceOffset
				)
			)
			if reverse then
				local endDirection = segments[#segments].CFrame:VectorToWorldSpace(normal)
				local previousDirection = segments[#segments - 1].CFrame:VectorToWorldSpace(normal)
				assert(
					math.acos(math.clamp(endDirection:Dot(previousDirection), -1, 1)) <= math.rad(7),
					"The E-first curve must meet C gently"
				)
			end
			local previous = start:VectorToWorldSpace(normal)
			for _, segment in segments do
				local direction = segment.CFrame:VectorToWorldSpace(normal)
				assert(
					math.acos(math.clamp(previous:Dot(direction), -1, 1)) <= math.rad(15),
					"Surface fitting must not concentrate the bend into a sharp block corner"
				)
				assert(
					segment.CFrame.RightVector.Y <= math.sin(math.rad(16)),
					"The tall template must not amplify the small reverse bend into a large bulge"
				)
				previous = direction
			end
			table.insert(counts, #segments)
		end
		assert(math.abs(counts[1] - counts[2]) <= 1, "Selecting C first should not add unnecessary detail")
		t.expect(counts[1]).toBe(8)
		t.expect(counts[2]).toBe(8)
	end)

	t.test("ArcJoin: all six template faces keep their cross sections", function()
		for _, normalId in Enum.NormalId:GetEnumItems() do
			local normal = Vector3.fromNormalId(normalId)
			local start = CFrame.new(5, 8, -2) * CFrame.Angles(0.4, 0.7, 0.2)
			local turn = if math.abs(normal.Y) < 0.5 then Vector3.yAxis else Vector3.xAxis
			local finish = start:PointToWorldSpace((normal + turn) * 10)
			local size = Vector3.new(4, 2, 3)
			local segments =
				assert(ShapeUtils.planArcJoin(start, finish, -start:VectorToWorldSpace(turn), size, normal, 9))
			checkPlan(segments, start.Position, finish, normal, size)
		end
	end)

	t.test("ArcJoin: automatic count responds to length and curvature", function()
		local size = Vector3.new(4, 2, 3)
		local straight =
			assert(ShapeUtils.planArcJoin(CFrame.identity, Vector3.new(8, 0, 0), -Vector3.xAxis, size, Vector3.xAxis))
		local long =
			assert(ShapeUtils.planArcJoin(CFrame.identity, Vector3.new(80, 0, 0), -Vector3.xAxis, size, Vector3.xAxis))
		local curved =
			assert(ShapeUtils.planArcJoin(CFrame.identity, Vector3.new(5, 5, 0), -Vector3.yAxis, size, Vector3.xAxis))
		t.expect(#long > #straight).toBe(true)
		t.expect(#curved >= 9).toBe(true)
		checkPlan(straight, Vector3.zero, Vector3.new(8, 0, 0), Vector3.xAxis, size)
	end)

	t.test("ArcJoin: large gaps and manual counts can exceed 512 segments", function()
		local size = Vector3.new(4, 2, 3)
		local finish = Vector3.new(4096, 0, 0)
		local automatic = assert(ShapeUtils.planArcJoin(CFrame.identity, finish, -Vector3.xAxis, size, Vector3.xAxis))
		t.expect(#automatic).toBe(1024)
		local manual = assert(ShapeUtils.planArcJoin(CFrame.identity, finish, -Vector3.xAxis, size, Vector3.xAxis, 768))
		t.expect(#manual).toBe(768)
		for _, segments in { automatic, manual } do
			local length = 0
			for _, segment in segments do
				assert(segment.Size.X <= 2048, "The gap must be divided into valid part sizes")
				length += segment.Size.X
			end
			t.expect(length).toBe(finish.X)
			inside(segments[1], Vector3.zero)
			inside(segments[#segments], finish)
		end
	end)

	t.test("ArcJoin: skew and same-facing endpoints remain connected", function()
		for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis } do
			local size = Vector3.new(4, 2, 3)
			local finish = Vector3.new(10, 10, 7)
			local segments = assert(ShapeUtils.planArcJoin(CFrame.identity, finish, direction, size, Vector3.xAxis, 20))
			checkPlan(segments, Vector3.zero, finish, Vector3.xAxis, size)
		end
	end)

	t.test("ArcJoin: shared padding extends both ends and preserves clones", function()
		withParts(function(folder, a, b, faceA, faceB)
			local options = table.clone(Settings.DefaultArcJoinOptions)
			options.AutomaticSegments = false
			options.Segments = 7
			options.Padding = 2
			doExtend(faceA, faceB, "ArcJoin", false, options)
			t.expect(#folder:GetChildren()).toBe(9)
			near(a.Size, Vector3.new(6, 2, 3))
			near(b.Size, Vector3.new(2, 6, 3))
			near(a.Position - a.CFrame.XVector * a.Size.X / 2, Vector3.new(-4, 0, 0))
			near(b.Position + b.CFrame.YVector * b.Size.Y / 2, Vector3.new(10, 14, 0))
			local segments = {}
			for _, part in folder:GetChildren() do
				if part ~= a and part ~= b then
					t.expect(part.Color).toBe(a.Color)
					t.expect(part:GetAttribute("ArcTemplate")).toBe(true)
					t.expect(part:FindFirstChild("TemplateAttachment") ~= nil).toBe(true)
					table.insert(segments, { CFrame = part.CFrame, Size = part.Size })
				end
			end
			checkPlan(segments, Vector3.new(2, 0, 0), Vector3.new(10, 8, 0), Vector3.xAxis, Vector3.new(4, 2, 3))
		end)
	end)

	t.test("ArcJoin: advanced padding extends each end independently", function()
		withParts(function(folder, a, b, faceA, faceB)
			local options = table.clone(Settings.DefaultArcJoinOptions)
			options.AdvancedPadding = true
			options.Padding = 100
			options.PaddingA = 1
			options.PaddingB = 3
			doExtend(faceA, faceB, "ArcJoin", false, options)
			near(a.Size, Vector3.new(5, 2, 3))
			near(b.Size, Vector3.new(2, 7, 3))
			t.expect(#folder:GetChildren() > 2).toBe(true)
		end)
	end)

	t.test("ArcJoin: straight ends extend matching plain parts", function()
		for _, sameProperties in { true, false } do
			withParts(function(folder, a, b, faceA, faceB)
				a:ClearAllChildren()
				a:SetAttribute("ArcTemplate", nil)
				b.Color = if sameProperties then a.Color else Color3.new(1, 0, 0)
				local options = table.clone(Settings.DefaultArcJoinOptions)
				options.AutomaticSegments = false
				options.Segments = 12
				doExtend(faceA, faceB, "ArcJoin", false, options)
				t.expect(a.Size.X > 4).toBe(true)
				t.expect(b.Size.Y > 4).toBe(sameProperties)
				t.expect(#folder:GetChildren()).toBe(if sameProperties then 12 else 13)
				near(a.Position - a.CFrame.XVector * a.Size.X / 2, Vector3.new(-4, 0, 0))
				near(b.Position + b.CFrame.YVector * b.Size.Y / 2, Vector3.new(10, 14, 0))
			end)
		end
	end)

	t.test("ArcJoin: invalid counts and excessive padding leave sources untouched", function()
		for _, count in { 0, -1, 1.5, math.huge, 0 / 0 } do
			withParts(function(folder, a, b, faceA, faceB)
				local options = table.clone(Settings.DefaultArcJoinOptions)
				options.AutomaticSegments = false
				options.Segments = count
				options.Padding = 2
				t.expect(pcall(doExtend, faceA, faceB, "ArcJoin", false, options)).toBe(false)
				t.expect(#folder:GetChildren()).toBe(2)
				near(a.Size, Vector3.new(4, 2, 3))
				near(b.Size, Vector3.new(2, 4, 3))
			end)
		end
		withParts(function(folder, a, b, faceA, faceB)
			local options = table.clone(Settings.DefaultArcJoinOptions)
			options.Padding = 20
			t.expect(pcall(doExtend, faceA, faceB, "ArcJoin", false, options)).toBe(false)
			t.expect(#folder:GetChildren()).toBe(2)
			near(a.Size, Vector3.new(4, 2, 3))
			near(b.Size, Vector3.new(2, 4, 3))
		end)
	end)
end
