--!strict
--[[
	Hearing
	What the big blind one can hear (docs/systems/Catacombs.md §4). Pure rules over the plan (Domain/CatacombMaze); no
	services, no clocks of its own (the caller passes the time).

	A NOISE is { cell, loudness, kind, source }. `loudness` is how far it carries ALONG THE PASSAGES, in studs: the plan's
	walls stop it, so a shout in the next corridor is as far away as the way round to it, and a shut gate stops it dead.
	Whatever is within `Noise.Touch` studs of him he notices whatever it does.

	WHAT A FOOT MAKES. A body that does not move makes nothing. A crouched one makes `StepCrouch` (a few studs: he must be
	all but on it), an upright one `StepWalk`, a running one `StepRun`.

	MEMORY. He keeps the LOUDEST thing he heard for `Remember` seconds, and a newer noise at least as loud replaces it:
	so a bell rung across the plan pulls him off a quiet body, and a body that keeps walking keeps being found.

	Place: both places (pure; Server/Domain).
]]

local Hearing = {}

export type Noise = {
	c: number,
	r: number,
	loudness: number,
	kind: string,
	source: string?, -- the player or thing that made it (so a chase can follow it)
	x: number?,
	z: number?,
}

export type Memory = {
	noise: Noise?,
	at: number,
	forget: number,
}

-- How loud is a body's foot? `speed` is the flat speed in studs a second.
function Hearing.footstep(noise: any, speed: number, crouching: boolean, airborne: boolean?): number
	if airborne == true or speed < 1.5 then
		return 0
	end
	if crouching then
		return noise.StepCrouch
	end
	if speed >= noise.RunSpeed then
		return noise.StepRun
	end
	return noise.StepWalk
end

-- Studs of passage between a noise and a listener, or nil when no open way joins them.
function Hearing.distance(maze: any, noise: Noise, listener: { c: number, r: number }): number?
	return maze:reach({ c = noise.c, r = noise.r }, listener, true)
end

-- Does the listener, standing in `listener`, hear `noise`?
function Hearing.hears(maze: any, noise: Noise, listener: { c: number, r: number }): boolean
	if noise.loudness <= 0 then
		return false
	end
	local d = Hearing.distance(maze, noise, listener)
	return d ~= nil and d <= noise.loudness
end

-- Is a body this close (in studs, straight) noticed whatever it does?
function Hearing.touches(noise: any, distance: number): boolean
	return distance <= noise.Touch
end

--==========================================================================
-- Memory: the loudest recent noise
--==========================================================================
function Hearing.newMemory(forgetSeconds: number): Memory
	return { noise = nil, at = 0, forget = forgetSeconds }
end

-- Takes a noise into memory when it is at least as loud as what is remembered (or that has been forgotten).
-- Returns true when the memory changed to this noise.
function Hearing.hear(memory: Memory, noise: Noise, now: number): boolean
	local held = memory.noise
	if held == nil or now - memory.at > memory.forget or noise.loudness >= held.loudness then
		memory.noise = noise
		memory.at = now
		return true
	end
	return false
end

-- What is remembered now (nil once forgotten).
function Hearing.recall(memory: Memory, now: number): Noise?
	local held = memory.noise
	if held and now - memory.at <= memory.forget then
		return held
	end
	memory.noise = nil
	return nil
end

function Hearing.forgetAll(memory: Memory)
	memory.noise = nil
end

return Hearing
