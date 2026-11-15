--[[
	SoundMeter — run in a PLAY session, on the CLIENT. A way to "hear" a sound without ears.

	Each sound is played SILENTLY (an AudioPlayer wired only to an AudioAnalyzer, never to a speaker) and its loudness is
	read every frame: the highest peak, the average loudness while it sounds, and its ONSETS (the moments it strikes: a
	typewriter key, a footfall, the crack of lightning), each with its own peak. That is how the developer's complaint was
	checked (2026-11-15: "some letters are loud and some can hardly be heard": the typing played the first 0.07 s of a
	clip of several keys, at a random pitch, so each letter caught a different piece of it), and how a single strike is
	cut out of a clip (configs/Audio `Start` and `Cut`).

	    local meter = loadstring(game.ServerStorage.TLK_Tools.SoundMeter.Source)()   -- (client: from the bundle)
	    return meter({ "rbxassetid://9120299710", ... }, 6)

	Returns one line per sound: duration, peak, mean loudness, and the onsets as time@peak.
	NOT game code (it rides in the sync bundle's TLK_Tools).
]]

local RunService = game:GetService("RunService")

return function(ids: { string }, seconds: number?): string
	local limit = seconds or 6
	local lines: { string } = {}
	local jobs = 0
	for _, id in ids do
		jobs += 1
		task.spawn(function()
			local ok, err = pcall(function()
				local player = Instance.new("AudioPlayer")
				player.Asset = id
				player.Volume = 1
				player.Parent = workspace
				local analyzer = Instance.new("AudioAnalyzer")
				analyzer.Parent = player
				local wire = Instance.new("Wire")
				wire.SourceInstance = player
				wire.TargetInstance = analyzer
				wire.Parent = player
				local waited = 0
				while not player.IsReady and waited < 8 do
					waited += task.wait(0.05)
				end
				local length = player.TimeLength
				player:Play()
				local samples: { { number } } = {}
				local started = os.clock()
				while os.clock() - started < math.min(limit, length + 0.3) do
					RunService.Heartbeat:Wait()
					table.insert(samples, { player.TimePosition, analyzer.PeakLevel, analyzer.RmsLevel })
				end
				player:Stop()
				player:Destroy()
				local maxPeak, sumRms, loud = 0, 0, 0
				for _, s in samples do
					maxPeak = math.max(maxPeak, s[2])
				end
				for _, s in samples do
					if s[2] > maxPeak * 0.1 then
						sumRms += s[3]
						loud += 1
					end
				end
				-- onsets: the level rises past half of the loudest after having fallen under a quarter of it
				local onsets: { string } = {}
				local armed = true
				for i, s in samples do
					if armed and s[2] > maxPeak * 0.5 then
						-- the strike's own peak: the highest of the next few frames
						local p = s[2]
						for j = i, math.min(i + 6, #samples) do
							p = math.max(p, samples[j][2])
						end
						table.insert(onsets, ("%.3f@%.2f"):format(s[1], p))
						armed = false
					elseif s[2] < maxPeak * 0.25 then
						armed = true
					end
				end
				table.insert(lines, ("%s  %.2fs  peak %.2f  mean %.3f  onsets %s"):format(id, length, maxPeak, if loud > 0 then sumRms / loud else 0, table.concat(onsets, " ", 1, math.min(#onsets, 10))))
			end)
			if not ok then
				table.insert(lines, id .. "  FAILED " .. tostring(err))
			end
			jobs -= 1
		end)
	end
	local deadline = os.clock() + limit + 12
	while jobs > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
