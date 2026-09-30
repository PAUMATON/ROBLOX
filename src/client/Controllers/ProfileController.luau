--!strict

-- ProfileController — l'ultima instantania del perfil que ha enviat el
-- servidor. NOMES es per ensenyar: la veritat viu al servidor, i res del
-- que hi ha aqui s'envia mai de tornada com a resultat.
--
-- Un sol listener de ProfileUpdate a proposit: un RemoteEvent guarda els
-- missatges que arriben abans de tenir listener i els dona NOMES al primer
-- que es connecta. Si cada controlador escoltes pel seu compte, el primer
-- ProfileUpdate se l'emportaria un de sol.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

export type Snapshot = {
	coins: number,
	bones: { [string]: number },
	locked: { [string]: number }?, -- de les de `bones`, les de recompensa (no es comercien)
	tradeWait: number?, -- segons que falten per poder comerciar (quan es va enviar)
	skeletons: { [string]: number },
	museum: { [string]: string },
	rate: number,
	slots: number,
	zones: { string },
	discovered: { [string]: boolean },
	tools: { string },
	equippedTool: string,
	digs: number,
	persisted: boolean,
	potions: { [string]: number }?, -- poció -> quantes (Config/Potions)
	hasteLeft: number?, -- segons de poció haste que queden (quan es va enviar)
	settings: {
		musicVolume: number,
		sfxVolume: number,
		uiScale: number,
		menuScale: number?,
		lowGraphics: boolean?,
		allowTrades: boolean?,
		quickRewards: boolean?,
		questGuide: boolean?,
	}?,
}

local ProfileController = {}

ProfileController.Changed = Signal.new() -- (snapshot)
-- Només les monedes (renda del museu, cada segon): no redibuixa res més
ProfileController.CoinsChanged = Signal.new() -- (coins)

local current: Snapshot? = nil

function ProfileController.Get(): Snapshot?
	return current
end

function ProfileController.Init()
	-- A Init, abans de cap Start: aixi som el primer listener.
	Remotes.ProfileUpdate.OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then
			return
		end
		current = data :: Snapshot
		ProfileController.Changed:Fire(current)
	end)
	Remotes.CoinsUpdate.OnClientEvent:Connect(function(coins: any)
		local snapshot = current
		if not snapshot or type(coins) ~= "number" then
			return
		end
		snapshot.coins = coins
		ProfileController.CoinsChanged:Fire(coins)
	end)
end

return ProfileController
