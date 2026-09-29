--!strict

-- Punt unic de definicio dels remotes. El servidor els crea, el client els espera.
-- Ambdos costats fan servir el mateix require, aixi cap script inventa noms per
-- la seva banda: si el nom no es en aquest fitxer, no existeix.
--
-- Nota: aquest modul viu a ReplicatedStorage.Shared.Remotes; els objectes remots
-- reals viuen a ReplicatedStorage.Remotes (carpeta separada, creada en runtime).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local CLIENT_WAIT_TIMEOUT = 15

-- Tots son RemoteEvents a proposit. Cap RemoteFunction: una invocacio del client
-- deixa el servidor esperant una resposta que l'atacant controla (o no envia mai).
-- El client envia intencio i el servidor respon pel seu canal.
local REMOTE_NAMES: { string } = {
	-- Client -> servidor (intencions)
	"DigRequest", -- ("start", munt) o ("click", quan): mai on era la línia
	"MuseumAction", -- ("assemble", esquelet) · ("display", esquelet) · ("withdraw", vitrina)
	"TradeRequest", -- (accio, dades): request, accept_invite, offer, confirm, accept, cancel...
	"TravelRequest", -- (desti): "museum", "city", "shop", "construction", "beach"
	"ShopRequest", -- ("buy" | "equip", eina): comprar, al costat de l'eina a la botiga
	"SellRequest", -- ("one", peça) · ("dupes") · ("all"): vendre fòssils, a la parada
	"SettingsRequest", -- (taula): mida de la UI i volums
	"PurchaseRequest", -- ("pass" | "product", clau): comprar amb Robux
	"RewardRequest", -- ("daily") · ("gift", número) · ("state"): recompenses gratis
	"QuestRequest", -- ("claim") · ("state"): cobrar la missió en curs

	-- Servidor -> client (resultats i estat)
	"DigUpdate", -- fases de l'excavacio: start, hit, result, denied, cancel
	"ProfileUpdate", -- instantania del perfil: monedes, ossos, museu, zones
	"TradeUpdate", -- invitacions i estat de l'intercanvi obert
	"Notify", -- avisos puntuals del servidor (p.ex. renda offline en tornar)
	"RewardUpdate", -- estat de les recompenses (diària, regals, invitacions)
	"VisitorUpdate", -- visitants dels museus: spawn, tip, remove, snapshot
	"QuestUpdate", -- la missió en curs: text, progrés, premi, cap on anar
}

export type Remotes = {
	DigRequest: RemoteEvent,
	MuseumAction: RemoteEvent,
	TradeRequest: RemoteEvent,
	TravelRequest: RemoteEvent,
	ShopRequest: RemoteEvent,
	SellRequest: RemoteEvent,
	SettingsRequest: RemoteEvent,
	PurchaseRequest: RemoteEvent,
	RewardRequest: RemoteEvent,
	QuestRequest: RemoteEvent,
	QuestUpdate: RemoteEvent,
	RewardUpdate: RemoteEvent,
	VisitorUpdate: RemoteEvent,
	DigUpdate: RemoteEvent,
	ProfileUpdate: RemoteEvent,
	TradeUpdate: RemoteEvent,
	Notify: RemoteEvent,
}

local function createOnServer(): { [string]: RemoteEvent }
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end

	local remotes: { [string]: RemoteEvent } = {}
	for _, name in ipairs(REMOTE_NAMES) do
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			remotes[name] = existing
		else
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
			remotes[name] = remote
		end
	end

	return remotes
end

local function waitOnClient(): { [string]: RemoteEvent }
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_TIMEOUT)
	if not folder then
		error(`[Remotes] la carpeta {FOLDER_NAME} no ha aparegut en {CLIENT_WAIT_TIMEOUT}s`, 0)
	end

	local remotes: { [string]: RemoteEvent } = {}
	for _, name in ipairs(REMOTE_NAMES) do
		local remote = folder:WaitForChild(name, CLIENT_WAIT_TIMEOUT)
		if not remote or not remote:IsA("RemoteEvent") then
			error(`[Remotes] falta el remote {name}`, 0)
		end
		remotes[name] = remote
	end

	return remotes
end

local remotes = if RunService:IsServer() then createOnServer() else waitOnClient()

return (remotes :: any) :: Remotes
