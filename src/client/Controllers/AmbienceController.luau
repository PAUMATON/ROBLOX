--!strict

-- AmbienceController — el so d'ambient segons on ets: ocells a la ciutat
-- (plaça, carrers, obra) i onades a la platja. Canvia amb una fosa suau.
-- A sota hi sona la música de fons (MUSIC), una pista rere l'altra.
-- La font de la plaça té el seu propi so d'aigua al mapa (se sent de prop).
-- Tots els sons són de ProSoundEffects / DistroKid via el Creator Store:
-- es poden fer servir en jocs públics.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))

local AmbienceController = {}

local LOOPS: { [string]: { id: string, volume: number } } = {
	city = { id = "rbxassetid://9112750044", volume = 0.3 }, -- Birds Quiet And Tranquil (ProSoundEffects)
	beach = { id = "rbxassetid://73399320704222", volume = 0.4 }, -- Relaxing waves on the beach
}
local BEACH_X = 160 -- a l'est d'aquí comença el passeig marítim

-- Música de fons: pistes de DistroKid (biblioteca amb llicència de Roblox,
-- com les onades: es poden fer servir en qualsevol experiència). Sonen
-- seguides i en roda, amb el volum de "Music" de la configuració; si una no
-- carrega, se salta. Una llista per a la ciutat (alegre, de simulador) i una
-- per a Egipte: en viatjar a l'illa canvia amb una fosa.
local MUSIC: { [string]: { string } } = {
	city = {
		"rbxassetid://139242395374944", -- Playground Adventure
		"rbxassetid://137582812940604", -- Fun in Roblox City
		"rbxassetid://140317576492006", -- Crafty Bounce Pop – Fun Background Music
		"rbxassetid://137997389892171", -- Happy Park
		"rbxassetid://135549334341493", -- Obby Rush BGM
	},
	egypt = {
		"rbxassetid://109579195200347", -- Ancient Egypt
		"rbxassetid://114553110631859", -- Desert Delight
		"rbxassetid://139402900044442", -- Oasis Song
	},
}
local EGYPT_X = 1500 -- a l'est d'aquí ja ets al desert d'Egipte (x = 6000)
local MUSIC_VOLUME = 0.22
local MUSIC_FADE = 2
local FADE = 2.5

local sounds: { [string]: Sound } = {}
local current: string? = nil

-- l'ambient: ocells a la ciutat, onades a la platja; al desert d'Egipte
-- cap bucle ("egypt" no és a LOOPS: s'apaguen tots i sona la música)
local function zoneAt(pos: Vector3): string
	if pos.X > EGYPT_X then
		return "egypt"
	end
	return if pos.X > BEACH_X then "beach" else "city"
end

local function musicZoneAt(pos: Vector3): string
	return if pos.X > EGYPT_X then "egypt" else "city"
end

local function switch(zone: string, force: boolean?)
	if zone == current and not force then
		return
	end
	current = zone
	for name, sound in sounds do
		local target = if name == zone then LOOPS[name].volume * Theme.MusicVolume else 0
		if target > 0 and not sound.IsPlaying then
			sound:Play()
		end
		TweenService:Create(sound, TweenInfo.new(FADE), { Volume = target }):Play()
	end
end

-- ─────────────────────────── MÚSICA ───────────────────────────

local music: Sound? = nil
local musicZone = "city"
local track: { [string]: number } = {}
local loadToken = 0 -- una càrrega nova anul·la la que s'esperava

local function musicTarget(): number
	return MUSIC_VOLUME * Theme.MusicVolume
end

local function playNext()
	local s = music
	local list = MUSIC[musicZone]
	if not s or not list or #list == 0 then
		return
	end
	loadToken += 1
	local mine = loadToken
	for _ = 1, #list do
		local i = (track[musicZone] or math.random(0, #list - 1)) % #list + 1
		track[musicZone] = i
		s:Stop()
		s.SoundId = list[i]
		-- espera que carregui (o que falli: llavors, la següent)
		local t0 = os.clock()
		while not s.IsLoaded and os.clock() - t0 < 8 do
			task.wait(0.25)
			if mine ~= loadToken then
				return -- mentrestant s'ha canviat de zona
			end
		end
		if s.IsLoaded then
			s.Volume = 0
			s.TimePosition = 0
			s:Play()
			TweenService:Create(s, TweenInfo.new(MUSIC_FADE), { Volume = musicTarget() }):Play()
			return
		end
	end
end

-- Canvia de llista (ciutat <-> Egipte): fosa de sortida i la primera de l'altra
local function setMusicZone(zone: string)
	if zone == musicZone then
		return
	end
	musicZone = zone
	local s = music
	if not s then
		return
	end
	TweenService:Create(s, TweenInfo.new(1.2), { Volume = 0 }):Play()
	task.delay(1.25, playNext)
end

local function startMusic()
	local s = Instance.new("Sound")
	s.Name = "Music"
	s.Looped = false
	s.Volume = 0
	s.Parent = SoundService
	music = s
	s.Ended:Connect(function()
		task.wait(1.5)
		playNext()
	end)
	task.spawn(playNext)
end

function AmbienceController.Start()
	for name, def in LOOPS do
		local s = Instance.new("Sound")
		s.Name = "Ambience_" .. name
		s.SoundId = def.id
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		sounds[name] = s
	end
	-- el volum de "Music" de la configuració
	Theme.OnMusicVolume(function()
		if current then
			switch(current, true)
		end
		if music and music.IsPlaying then
			TweenService:Create(music, TweenInfo.new(0.3), { Volume = musicTarget() }):Play()
		end
	end)
	startMusic()
	local player = Players.LocalPlayer
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			switch(zoneAt(root.Position))
			setMusicZone(musicZoneAt(root.Position))
		end
	end)
end

return AmbienceController
