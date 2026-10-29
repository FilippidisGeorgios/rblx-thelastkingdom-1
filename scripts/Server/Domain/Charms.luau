--!strict
--[[
	Charms (domain)
	The rules of what a worn charm does while a run is on (configs/Chapel.luau → Charms), as pure
	functions: numbers in, numbers out. Server/World/CharmService does the touching.

	  lastBreath   the Mourner's Veil. A blow that would kill, once a run, leaves one breath.
	  calmSpeed    the Brass Stirrup. A bonus on the walking speed that is taken and given back
	               without ever disturbing a speed somebody else has set in between.
	  isCalm       "out of a fight": no blow dealt or taken for a few seconds.

	The Hollow Lantern has no rule of its own: it is a number (RunModService.notice) that
	EnemyBrain multiplies the detection radius by.

	Location: ServerScriptService.Server.Domain.Charms
]]

local Charms = {}

--[[
	A blow of `amount` falls on someone with `health`. If it would kill, and the veil is worn and
	not yet spent, it is cut to leave one breath. Returns (amount to deal, veil used).
]]
function Charms.lastBreath(health: number, amount: number, worn: boolean, spent: boolean): (number, boolean)
	if not worn or spent or health <= 0 or amount < health then
		return amount, false
	end
	return math.max(0, health - 1), true
end

-- Has `seconds` passed since the last blow, given or taken? (`lastFight` nil: there has been none.)
function Charms.isCalm(now: number, lastFight: number?, seconds: number): boolean
	return lastFight == nil or now - lastFight >= seconds
end

--[[
	A claim on one body's walking speed. `base` is the speed before the charm; `set` is exactly what
	the charm wrote. Both nil: no claim.
]]
export type Claim = { base: number?, set: number? }

local SAME = 0.02

--[[
	One step of the stirrup. `current` is the humanoid's speed now, `calm` whether the wearer is out
	of a fight, `multiplier` the charm's (1.08). Returns the speed to write, or nil to leave it alone.

	  - No claim, calm: take the claim, write current x multiplier.
	  - Claim, still calm: nothing.
	  - Claim, no longer calm: give back `base`.
	  - Claim, but the speed is not what we wrote (the King's frost, a slow, a new body): it is
	    somebody else's now. Drop the claim and write nothing, so a later reset by them is not
	    undone by us and ours is never given back over theirs.
]]
function Charms.calmSpeed(claim: Claim, current: number, calm: boolean, multiplier: number): number?
	local set = claim.set
	if set ~= nil then
		if math.abs(current - set) > SAME then
			claim.base, claim.set = nil, nil
			return nil
		end
		if calm and multiplier ~= 1 then
			return nil
		end
		local base = claim.base
		claim.base, claim.set = nil, nil
		return base
	end
	if calm and multiplier ~= 1 and current > 0 then
		claim.base = current
		claim.set = current * multiplier
		return claim.set
	end
	return nil
end

return Charms
