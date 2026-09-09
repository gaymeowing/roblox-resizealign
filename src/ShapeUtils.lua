--!strict

local function otherNormals(dir: Vector3): (Vector3, Vector3)
	if math.abs(dir.X) > 0 then
		return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
	elseif math.abs(dir.Y) > 0 then
		return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	else
		return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	end
end

local function isWedgeShape(part: BasePart): boolean
	return part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Wedge)
end

local function isCornerWedgeShape(part: BasePart): boolean
	return part:IsA("CornerWedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.CornerWedge)
end

local function isCylinder(part: BasePart): boolean
	return part:IsA("Part") and part.Shape == Enum.PartType.Cylinder
end

export type ArcSegment = { CFrame: CFrame, Size: Vector3 }

local MAX_SEGMENTS = 512

local function rotateAlong(rotation: CFrame, from: Vector3, to: Vector3, localNormal: Vector3): CFrame
	local axis = from:Cross(to)
	local dot = math.clamp(from:Dot(to), -1, 1)
	if axis.Magnitude > 1e-6 then
		return CFrame.fromAxisAngle(axis.Unit, math.atan2(axis.Magnitude, dot)) * rotation
	elseif dot < 0 then
		local perpendicular = if math.abs(localNormal.Y) < 0.5 then Vector3.yAxis else Vector3.xAxis
		return CFrame.fromAxisAngle(rotation:VectorToWorldSpace(perpendicular), math.pi) * rotation
	end
	return rotation
end

local function crossSectionRadius(rotation: CFrame, halfSize: Vector3, direction: Vector3): number
	local localDirection = rotation:VectorToObjectSpace(direction)
	return math.abs(localDirection.X) * halfSize.X
		+ math.abs(localDirection.Y) * halfSize.Y
		+ math.abs(localDirection.Z) * halfSize.Z
end

-- Align the top/bottom edges chosen by the shorter part. The offset remains
-- signed when the template is taller, so its outside surface stays flush.
local function getArcTargetPoint(
	startFrame: CFrame,
	targetFrame: CFrame,
	size: Vector3,
	targetSize: Vector3,
	localNormal: Vector3,
	targetLocalNormal: Vector3
): Vector3
	local up = if math.abs(targetLocalNormal.Y) < 0.5 then Vector3.yAxis else Vector3.zAxis
	local targetUp = targetFrame:VectorToWorldSpace(up)
	local endNormal = targetFrame:VectorToWorldSpace(targetLocalNormal)
	local rotation =
		rotateAlong(startFrame.Rotation, startFrame:VectorToWorldSpace(localNormal), -endNormal, localNormal)
	local dimension = Vector3.new(math.abs(localNormal.X), math.abs(localNormal.Y), math.abs(localNormal.Z))
	local radius = crossSectionRadius(rotation, size * (Vector3.one - dimension) / 2, targetUp)
	local targetRadius = targetSize:Dot(up) / 2
	local offset = targetRadius - radius
	local startUp = if math.abs(localNormal.Y) < 0.5 then Vector3.yAxis else Vector3.zAxis
	local commonUp = startFrame:VectorToWorldSpace(startUp) + targetUp
	if commonUp.Magnitude < 0.001 then
		commonUp = targetUp
	end
	local separation = targetFrame.Position - startFrame.Position
	local relativeHeight = separation:Dot(commonUp) * (if radius > targetRadius then 1 else -1)
	local side = if relativeHeight >= 0 then 1 else -1
	return targetFrame.Position + targetUp * (side * offset)
end

local function pointAt(startPoint: Vector3, controlA: Vector3, controlB: Vector3, endPoint: Vector3, t: number): Vector3
	local s = 1 - t
	return startPoint * (s * s * s) + controlA * (3 * s * s * t) + controlB * (3 * s * t * t) + endPoint * (t * t * t)
end

local function tangentAt(
	startPoint: Vector3,
	controlA: Vector3,
	controlB: Vector3,
	endPoint: Vector3,
	t: number
): Vector3
	local s = 1 - t
	return ((controlA - startPoint) * (s * s) + (controlB - controlA) * (2 * s * t) + (endPoint - controlB) * (t * t)).Unit
end

local function tangentPoint(origin: Vector3, normal: Vector3, a: Vector3, b: Vector3): Vector3
	local direction = (b - a).Unit
	local cross = normal:Cross(direction)
	local denominator = cross:Dot(cross)
	local aReach, bReach = (a - origin):Dot(normal), (b - origin):Dot(normal)
	local reach = if denominator > 1e-10
		then (a - origin):Cross(direction):Dot(cross) / denominator
		else if math.abs(aReach) < math.abs(bReach) then aReach else bReach
	return origin + normal * reach
end

local function miterExtension(rotation: CFrame, halfSection: Vector3, direction: Vector3, plane: Vector3): number
	local denominator = math.abs(direction:Dot(plane))
	if denominator < 1e-6 then
		return math.huge
	end
	return crossSectionRadius(rotation, halfSection, plane) / denominator
end

-- startFrame retains the first part's local axes at its selected face.
-- Both normals point OUT of the selected parts.
-- A cubic circular-arc approximation also accommodates unequal radii and
-- non-coplanar endpoints, where a single tangent circle cannot connect them.
local function planArcJoin(
	startFrame: CFrame,
	endPoint: Vector3,
	endNormal: Vector3,
	size: Vector3,
	localNormal: Vector3,
	requestedSegments: number?
): { ArcSegment }?
	local startPoint = startFrame.Position
	local startNormal = startFrame:VectorToWorldSpace(localNormal)
	local distance = (endPoint - startPoint).Magnitude

	if distance < 0.001 then
		return nil
	end

	if
		requestedSegments ~= nil
		and (requestedSegments % 1 ~= 0 or requestedSegments < 1 or requestedSegments > MAX_SEGMENTS)
	then
		return nil
	end

	local angle = math.acos(math.clamp(-startNormal:Dot(endNormal), -1, 1))
	local handleLength = 2 * distance / (3 * (1 + math.cos(angle / 2)))
	local handleA, handleB = handleLength, handleLength
	local tangentCorner: Vector3? = nil
	local cross = startNormal:Cross(endNormal)
	local crossSquared = cross:Dot(cross)

	if crossSquared > 1e-10 then
		local separation = endPoint - startPoint
		local reachA = separation:Cross(endNormal):Dot(cross) / crossSquared
		local reachB = separation:Cross(startNormal):Dot(cross) / crossSquared
		if reachA > 0 and reachB > 0 then
			-- Unequal tangent reaches need unequal handles. Equal handles can
			-- push the middle control points past one another and create an S.
			local fraction = 4 / 3 * math.tan(angle / 4) / math.tan(angle / 2)
			handleA, handleB = reachA * fraction, reachB * fraction
			tangentCorner = (startPoint + startNormal * reachA + endPoint + endNormal * reachB) / 2
		end
	end

	local controlA = startPoint + startNormal * handleA
	local controlB = endPoint + endNormal * handleB

	-- Balance chord error against turning angle: broad shallow bends need
	-- subdivision too, while tight bends still need a limit on each turn.
	local planar = crossSquared > 1e-10 and math.abs((endPoint - startPoint):Dot(cross.Unit)) < 0.0001
	local dimension = Vector3.new(math.abs(localNormal.X), math.abs(localNormal.Y), math.abs(localNormal.Z))
	local templateLength = size:Dot(dimension)
	local samples = math.max(128, (requestedSegments or 0) * 4)
	local measures = { 0 }
	local previousPoint = startPoint
	local previousDirection = startNormal
	local totalMeasure = 0
	local totalLength, totalTurn = 0, 0

	for i = 1, samples do
		local point = pointAt(startPoint, controlA, controlB, endPoint, i / samples)
		local chord = point - previousPoint
		local length = chord.Magnitude
		local turn = 0
		if length > 0 then
			local direction = if planar
				then tangentAt(startPoint, controlA, controlB, endPoint, i / samples)
				else chord.Unit
			turn = math.acos(math.clamp(previousDirection:Dot(direction), -1, 1))
			previousDirection = direction
		end
		totalLength += length
		totalTurn += turn
		totalMeasure += math.sqrt(length * turn) + turn * 2 + length / templateLength * 0.05
		measures[i + 1] = totalMeasure
		previousPoint = point
	end

	local endTurn = math.acos(math.clamp(previousDirection:Dot(-endNormal), -1, 1))
	totalTurn += endTurn
	totalMeasure += endTurn * 2
	measures[samples + 1] = totalMeasure
	local turnSegments = math.ceil(totalTurn / math.rad(5))

	if tangentCorner == nil then
		-- Tight reverse bends can accumulate a large turn over a tiny distance.
		-- Bound their detail by chord error relative to the clone cross-section,
		-- rather than allocating a part for every five degrees of that turn.
		local axisA, axisB = otherNormals(localNormal)
		local errorLimit = math.min(size:Dot(axisA), size:Dot(axisB)) * 0.0015
		local errorSegments = math.ceil(math.sqrt(totalLength * totalTurn / (8 * errorLimit)))
		turnSegments = math.min(turnSegments, errorSegments)
	end

	-- Reserve the two tangent segments without making every sample a clone.
	local count = requestedSegments
		or math.clamp(
			math.max(
				math.ceil(totalLength / templateLength),
				if turnSegments > 1 then turnSegments + 1 else turnSegments
			),
			1,
			MAX_SEGMENTS
		)
	local points = { startPoint }
	local sample = 1
	local tangentSegments = planar and count >= 3
	local previousTangentPoint, previousTangent = startPoint, startNormal

	for i = 1, if tangentSegments then count - 1 else count do
		local targetMeasure = totalMeasure * i / (if tangentSegments then count - 1 else count)

		while sample < samples and measures[sample + 1] < targetMeasure do
			sample += 1
		end

		local span = measures[sample + 1] - measures[sample]
		local fraction = if span > 0 then (targetMeasure - measures[sample]) / span else 0
		local t = math.clamp((sample - 1 + fraction) / samples, 0, 1)
		local point = pointAt(startPoint, controlA, controlB, endPoint, t)

		if tangentSegments then
			-- Intersect successive tangents to the same curve, including its
			-- endpoint tangents. This avoids spending two samples on end caps
			-- and then forcing their neighbors into a larger, sharper turn.
			local tangent = tangentAt(startPoint, controlA, controlB, endPoint, t)
			local normal = previousTangent:Cross(tangent)
			local denominator = normal:Dot(normal)
			points[i + 1] = if denominator > 1e-10
				then previousTangentPoint
					+ previousTangent * ((point - previousTangentPoint):Cross(tangent):Dot(normal) / denominator)
				else (previousTangentPoint + point) / 2
			previousTangentPoint, previousTangent = point, tangent
		else
			points[i + 1] = if i == count then endPoint else point
		end
	end
	points[count + 1] = endPoint

	if count == 2 and tangentCorner then
		points[2] = tangentCorner
	elseif count >= 3 and not tangentSegments then
		-- Intersect each endpoint tangent with the next chord. This keeps the
		-- first/last surfaces flush without reversing the neighboring bend.

		local first = tangentPoint(startPoint, startNormal, points[2], points[3])
		local last = tangentPoint(endPoint, endNormal, points[count - 1], points[count])
		points[2], points[count] = first, last
	end

	local segments: { ArcSegment } = {}
	previousPoint = startPoint
	previousDirection = startNormal
	local rotation = startFrame.Rotation

	for i = 1, count do
		local point = points[i + 1]
		local chord = point - previousPoint
		local length = chord.Magnitude
		-- Roblox would clamp these sizes, breaking the join. Reject the whole
		-- plan before resizing either source part or creating any clones.
		if not math.isfinite(length) or length < 0.001 or length > 2048 then
			return nil
		end
		local direction = chord.Unit
		rotation = rotateAlong(rotation, previousDirection, direction, localNormal)
		segments[i] = {
			CFrame = CFrame.new((previousPoint + point) / 2) * rotation,
			Size = size + dimension * (length - templateLength),
		}
		previousPoint = point
		previousDirection = direction
	end

	-- Chords only touch at their centerlines. Extend to the outermost point
	-- of each miter plane to close the triangular openings at every bend.
	-- This is thickness * tan(half the bend angle) for a planar strip, rather
	-- than a fixed overlap that would fail for thicker parts or fewer segments.
	local halfSection = size * (Vector3.one - dimension) / 2
	previousDirection = startNormal

	for i, segment in segments do
		local direction = segment.CFrame:VectorToWorldSpace(localNormal)
		local nextDirection = if i < count then segments[i + 1].CFrame:VectorToWorldSpace(localNormal) else -endNormal
		local startPlane = if i == 1 then startNormal else previousDirection + direction
		local endPlane = if i == count then -endNormal else direction + nextDirection

		local startReach = miterExtension(segment.CFrame, halfSection, direction, startPlane)
		local endReach = miterExtension(segment.CFrame, halfSection, direction, endPlane)
		local chordLength = segment.Size:Dot(dimension)
		-- On a tight bend the inner miter corner can pass the OTHER end of
		-- a short chord. Cover both complete miter sections, including that case.
		local before = if i == 1 and count > 1 then 0 else math.max(startReach, endReach - chordLength)
		local after = if i == count and count > 1 then 0 else math.max(endReach, startReach - chordLength)
		local length = chordLength + before + after
		if not math.isfinite(length) or length > 2048 then
			return nil
		end
		segment.Size += dimension * (before + after)
		segment.CFrame += direction * ((after - before) / 2)
		previousDirection = direction
	end
	return segments
end

return {
	maxArcSegments = MAX_SEGMENTS,
	planArcJoin = planArcJoin,
	getArcTargetPoint = getArcTargetPoint,
	otherNormals = otherNormals,
	isWedgeShape = isWedgeShape,
	isCornerWedgeShape = isCornerWedgeShape,
	isCylinder = isCylinder,
}
