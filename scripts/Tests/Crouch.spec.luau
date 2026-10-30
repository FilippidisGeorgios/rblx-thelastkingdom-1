--!strict
--[[
	Crouch.spec
	The speed claim (taken, given back, left alone when somebody else wrote), the key gap, and the room to stand.

	Location: TestService.Tests.Crouch.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crouch = require(ServerScriptService.Server.Domain.Crouch)
local Config: any = require(ReplicatedStorage.Config.Crouch)

return function(t: any)
	t.test("going down takes a share of the speed and coming up gives it back", function()
		local claim: Crouch.Claim = {}
		local down = Crouch.enter(claim, 16, 0.5)
		assert(down == 8, "half speed")
		assert(Crouch.leave(claim, 8) == 16, "the old speed comes back")
		assert(claim.base == nil and claim.set == nil, "the claim is dropped")
	end)

	t.test("a second 'down' does not take the claim twice", function()
		local claim: Crouch.Claim = {}
		Crouch.enter(claim, 16, 0.5)
		local again = Crouch.enter(claim, 8, 0.5)
		assert(again == 8, "still 8, not 4")
		assert(Crouch.leave(claim, 8) == 16, "and the true base is kept")
	end)

	t.test("a speed somebody else wrote while crouched is left alone", function()
		local claim: Crouch.Claim = {}
		Crouch.enter(claim, 16, 0.5)
		assert(Crouch.leave(claim, 5) == nil, "the King's frost (5) is not overwritten")
		assert(claim.set == nil, "the claim is gone all the same")
	end)

	t.test("standing without ever having crouched writes nothing", function()
		assert(Crouch.leave({}, 16) == nil)
	end)

	t.test("the key may be taken once per gap", function()
		assert(Crouch.mayToggle(10, nil, 0.3), "the first press")
		assert(not Crouch.mayToggle(10.1, 10, 0.3), "too soon")
		assert(Crouch.mayToggle(10.3, 10, 0.3), "after the gap")
	end)

	t.test("standing needs the whole height back", function()
		-- a crouched body 3.2 high, a standing one 5.4: it needs 2.2 above
		assert(Crouch.hasRoom(2.2, 3.2, 5.4), "exactly enough")
		assert(Crouch.hasRoom(10, 3.2, 5.4), "plenty")
		assert(not Crouch.hasRoom(0.4, 3.2, 5.4), "a low ceiling keeps you down")
	end)

	t.test("the real numbers: a crouched body fits a 3.4 passage and a standing one does not", function()
		-- measured in a playtest on the tallest avatar scale (1.05): height = about 1.0 + 3.95 x BodyHeightScale
		local crouched = 1.0 + 3.95 * Config.CrouchScale
		assert(crouched < 3.4, ("crouched %.2f must fit under 3.4"):format(crouched))
		assert(Config.StandHeight > 3.4, "standing must not")
		assert(Config.SpeedMult > 0 and Config.SpeedMult < 1, "slower, never stopped")
	end)
end
