--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)

local function createScrollTarget()
	local scroll: ScrollingFrame? = nil
	local first: GuiObject? = nil
	local last: GuiObject? = nil
	local paddingTop, paddingBottom = 0, 0
	local previousHeight: number?
	local previousCanvasHeight: number?
	local previousTop: number?
	local previousBottom: number?

	local function updateScroll()
		if not first then
			return
		end

		if not scroll then
			return
		end
		local height = scroll.AbsoluteWindowSize.Y

		if height <= 0 then
			return
		end

		local scrollY, firstY = scroll.AbsolutePosition.Y, first.AbsolutePosition.Y
		local canvasPosition = scroll.CanvasPosition
		local canvasY = canvasPosition.Y
		local top = firstY - scrollY + canvasY
		local bottom = top + first.AbsoluteSize.Y

		if last then
			local lastPosition = last.AbsolutePosition
			local lastY = lastPosition.Y
			local lastBottom = lastY - scrollY + canvasY + last.AbsoluteSize.Y
			if lastBottom - top <= height - paddingTop - paddingBottom then
				bottom = math.max(bottom, lastBottom)
			end
		end

		local canvasHeight = scroll.AbsoluteCanvasSize.Y

		if
			height == previousHeight
			and canvasHeight == previousCanvasHeight
			and top == previousTop
			and bottom == previousBottom
		then
			return
		end

		previousHeight, previousCanvasHeight, previousTop, previousBottom = height, canvasHeight, top, bottom

		local y = canvasY

		if bottom > y + height - paddingBottom then
			y = bottom - height + paddingBottom
		end

		if top < y + paddingTop then
			y = top - paddingTop
		end

		scroll.CanvasPosition = Vector2.new(canvasPosition.X, math.clamp(y, 0, math.max(0, canvasHeight - height)))
	end

	local function setScroll(instance: ScrollingFrame?)
		if scroll == instance then
			return
		end
		scroll = instance
		previousHeight = nil
	end

	local function setTarget(firstTarget: GuiObject?, lastTarget: GuiObject?, topInset: number?, bottomInset: number?)
		local top = topInset or 0
		local bottom = bottomInset or top

		if first == firstTarget and last == lastTarget and paddingTop == top and paddingBottom == bottom then
			return
		end

		first, last, paddingTop, paddingBottom = firstTarget, lastTarget, top, bottom
		previousHeight = nil
		updateScroll()
	end
	return { SetScroll = setScroll, Update = updateScroll, SetTarget = setTarget }
end

-- One controller retains the supplied instances across renders. Layout changes
-- adjust the target into view; ordinary wheel scrolling leaves it alone.
local function useScrollTarget()
	local controller = React.useMemo(createScrollTarget, {})
	return controller.SetScroll, controller.Update, controller.SetTarget
end

return useScrollTarget
