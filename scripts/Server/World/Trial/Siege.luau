--!strict
--[[
	Trial task: `siege`
	The Great Hall's whole point. After a PAUSE, a horn, and then the dead come
	to the doors in waves and break them.

	WHY A PAUSE
	The hall's design is that you walk in and are given time, and what you do with
	it (fetch planks, nail doors) decides the fight. The pause is the one place
	in the castle where the game says "get ready". It is `grace` seconds, with a
	warning thirty seconds and ten seconds before: a warning in the world's own
	terms (torches gathering, then moving), not a number.

	THE SIEGE
	An ordinary encounter (WaveService, configs/Encounters `area_6`): three
	waves of spearmen, archers and the heavy ones, scaled by the party and by
	depth like any wave. What makes it a siege is not here: it is that the doors
	are barricades the dead attack (Trial/Board, EnemyAIService.approachPoint).
	This task starts the encounter and is done when it is cleared.

	The chamber's own AreaWaveService wave is switched off for this chamber
	(`ownsWaves` in configs/Trials), so the first thing the dead do is not to
	meet you in the doorway.

	Params (configs/Trials):
	  encounter  the configs/Encounters id
	  grace      seconds before the horn

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local WaveService = require(script.Parent.Parent.WaveService)

local Siege = {}

function Siege.create(ctx: any, def: any)
	local stopper: (() -> ())? = nil
	local cancelled = false

	return {
		start = function()
			ctx.note("Torches are gathering beyond the doors.", 6)
			task.delay(math.max(0, def.grace - 30), function()
				if not cancelled then
					ctx.note("Thirty breaths. The torches are close.", 4)
				end
			end)
			task.delay(math.max(0, def.grace - 10), function()
				if not cancelled then
					ctx.note("They have begun to move.", 4)
				end
			end)
			task.delay(def.grace, function()
				if cancelled then
					return
				end
				ctx.note("A horn. They are at the doors.", 5)
				ctx.hint("Hold the hall")
				stopper = WaveService.startEncounter(def.encounter, {
					areaIndex = ctx.area,
					onWaveStart = function(wave: number, total: number)
						ctx.note(("The siege: wave %d of %d."):format(wave, total), 3)
					end,
					onComplete = function()
						stopper = nil
						ctx.hint(nil)
						ctx.note("The doors hold. The last of them falls back.", 5)
						ctx.done()
					end,
				})
			end)
		end,

		stop = function()
			cancelled = true
			if stopper then
				stopper()
				stopper = nil
			end
		end,

		progress = function(): (number, number)
			return 0, 1
		end,
	}
end

return Siege
