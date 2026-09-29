--!strict

-- SettingsService — desa la configuració del jugador (mida de la UI i
-- volums). No té cap valor econòmic, però igualment es valida: només
-- números dins de rang, i a poc a poc.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("Util"):WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)

local SettingsService = {}

local limiter = RateLimiter.new(2)
local RANGES: { [string]: { number } } = {
	musicVolume = { 0, 1 },
	sfxVolume = { 0, 1 },
	uiScale = { 0.7, 1.3 },
	menuScale = { 0.7, 1.3 },
}
local FLAGS = { "lowGraphics", "allowTrades", "quickRewards" }

function SettingsService.Start()
	Remotes.SettingsRequest.OnServerEvent:Connect(function(player: Player, payload: any)
		if type(payload) ~= "table" or not limiter:Check(player) then
			return
		end
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		for key, range in RANGES do
			local value = payload[key]
			if type(value) == "number" and value == value then
				(profile.settings :: any)[key] = math.clamp(value, range[1], range[2])
			end
		end
		for _, key in FLAGS do
			if type(payload[key]) == "boolean" then
				(profile.settings :: any)[key] = payload[key]
			end
		end
	end)
end

return SettingsService
