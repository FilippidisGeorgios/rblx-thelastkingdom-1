--!strict
--[[
	Crouch
	The rules of ducking, without the world: how fast a crouched player walks and gives the speed back, how often
	the key may be pressed, and how much room standing up needs. Pure, so it can be tested.

	THE SPEED CLAIM. Several things write a player's WalkSpeed (the Brass Stirrup walks faster when out of a fight, the
	King's frost holds it). Crouching does what the Stirrup does: it takes a CLAIM on the speed, remembers what it
	was, and gives that back only if nobody else has written a different speed in between. A speed somebody else
	wrote is theirs and is left alone.

	Location: ServerScriptService.Server.Domain.Crouch
]]

local Crouch = {}

export type Claim = {
	base: number?, -- the speed before crouching
	set: number?, -- the speed this claim wrote
}

-- The speed to write when going down. Takes the claim.
function Crouch.enter(claim: Claim, current: number, mult: number): number
	if claim.set ~= nil then
		-- already crouched: nothing new to write
		return current
	end
	claim.base = current
	claim.set = current * mult
	return claim.set :: number
end

--[[
	The speed to write when coming up, or nil when nothing should be written. Gives back the speed from before only if
	the speed is still the one the claim wrote (someone who wrote another speed meanwhile keeps theirs). Drops the claim
	either way.
]]
function Crouch.leave(claim: Claim, current: number): number?
	local base, set = claim.base, claim.set
	claim.base = nil
	claim.set = nil
	if base == nil or set == nil then
		return nil
	end
	if math.abs(current - set) > 0.01 then
		return nil
	end
	return base
end

-- May the key be taken now? (A tap every `gap` seconds at most.)
function Crouch.mayToggle(now: number, last: number?, gap: number): boolean
	return last == nil or now - last >= gap
end

--[[
	Is there room to stand? `above` is the clear height over the head (studs); a standing body needs `standHeight`
	measured from the feet, of which `currentHeight` is already taken by the body as it is.
]]
function Crouch.hasRoom(above: number, currentHeight: number, standHeight: number): boolean
	return above >= (standHeight - currentHeight) - 0.001
end

return Crouch
