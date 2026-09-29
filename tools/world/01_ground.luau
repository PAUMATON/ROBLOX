-- ═══════════════════════════ 01 · NETEJA, TERRENY I LLUM ═══════════════════════════
local Lighting = game:GetService("Lighting")
local Terrain = Workspace.Terrain

-- Neteja: el món anterior (i la prova de Chamonix) fora
for _, name in ipairs({ "Chamonix", "World", "Zones", "Museums", "Baseplate" }) do
	local x = Workspace:FindFirstChild(name)
	if x then
		x:Destroy()
	end
end
for _, x in ipairs(Workspace:GetChildren()) do
	if x:IsA("SpawnLocation") then
		x:Destroy()
	end
end
WORLD = folder("World", Workspace)
ZONES = folder("Zones", Workspace)
MUSEUMS = folder("Museums", Workspace)
Terrain:Clear()

-- ── Terra: gespa a tot el continent ──
-- (el terreny de Roblox queda 2 studs per sobre del bloc: per això els blocs acaben a -2)
local L = LAYOUT.LAND
for x = L.x0, LAYOUT.PROM.x1 - 1, 256 do
	for z = L.z0, L.z1 - 1, 256 do
		local sx = math.min(256, LAYOUT.PROM.x1 - x)
		local sz = math.min(256, L.z1 - z)
		Terrain:FillBlock(CF(x + sx / 2, -10, z + sz / 2), V3(sx, 16, sz), M.LeafyGrass)
	end
end
-- ── Mar: aigua fins a l'horitzó ──
local SEA_X1 = 1100
for x = LAYOUT.PROM.x1, SEA_X1 - 1, 256 do
	for z = L.z0 - 400, L.z1 + 399, 256 do
		local sx = math.min(256, SEA_X1 - x)
		Terrain:FillBlock(CF(x + sx / 2, -11, z + 128), V3(sx, 14, 256), M.Water)
		Terrain:FillBlock(CF(x + sx / 2, -24, z + 128), V3(sx, 12, 256), M.Sand)
	end
end
-- ── Platja: sorra plana i després una rampa suau que entra al mar ──
local zs, ze = L.z0 - 40, L.z1 + 40
local flat = LAYOUT.BEACH_FLAT_X1
Terrain:FillBlock(CF((LAYOUT.PROM.x1 + flat) / 2, -10.3, (zs + ze) / 2), V3(flat - LAYOUT.PROM.x1, 16, ze - zs), M.Sand)
local run, drop = 130, 11
local ang = math.atan(drop / run)
Terrain:FillBlock(
	CF(flat + run / 2, -drop / 2 - 10.3, (zs + ze) / 2) * CFrame.Angles(0, 0, -ang),
	V3(run / math.cos(ang) + 6, 16, ze - zs),
	M.Sand
)
-- extrems de la platja: roques
for _, zz in ipairs({ L.z0 - 30, L.z1 + 30 }) do
	for k = 0, 5 do
		Terrain:FillBall(V3(LAYOUT.PROM.x1 + 20 + k * 22, -2 + (5 - k) * 1.2, zz + (k % 2) * 12 - 6), 14 - k, M.Rock)
	end
end

-- ── Sota els paviments, res de gespa (l'herba del terreny travessa les peces) ──
-- (ReplaceMaterial canvia el material sense tocar l'alçada del terra)
local function paint(x0, x1, z0, z1, mat)
	if x1 > x0 and z1 > z0 then
		local region = Region3.new(V3(x0, -8, z0), V3(x1, 8, z1)):ExpandToGrid(4)
		Terrain:ReplaceMaterial(region, 4, M.LeafyGrass, mat)
	end
end
for _, r in ipairs(LAYOUT.ROADS) do
	local hw = r[5] / 2 + 1
	paint(math.min(r[1], r[3]) - hw, math.max(r[1], r[3]) + hw, math.min(r[2], r[4]) - hw, math.max(r[2], r[4]) + hw, M.Pavement)
end
for _, R in ipairs({ LAYOUT.PLAZA, LAYOUT.PASSEIG }) do
	paint(R.x0 - 2, R.x1 + 2, R.z0 - 2, R.z1 + 2, M.Pavement)
end
paint(LAYOUT.PROM.x0 - 2, LAYOUT.PROM.x1, L.z0, L.z1, M.Pavement)
for _, r in ipairs(LAYOUT.MUSEUM_RECTS) do
	paint(r[1], r[2], r[3], r[4], M.Pavement)
end
local O = LAYOUT.OBRA
paint(O.x0 - 4, O.x1 + 4, O.z0 - 4, O.z1 + 4, M.Ground)

-- herba del terreny: sense brins alts (es veien malament i travessaven les peces)
pcall(function()
	Terrain.Decoration = false
end)

-- ── Colors del terreny (paleta del CLAUDE.md) ──
Terrain:SetMaterialColor(M.Grass, C(118, 158, 84))
Terrain:SetMaterialColor(M.LeafyGrass, C(124, 164, 88))
Terrain:SetMaterialColor(M.Sand, COL.sand)
Terrain:SetMaterialColor(M.Rock, COL.rock)
Terrain:SetMaterialColor(M.Pavement, COL.paveDark)
Terrain:SetMaterialColor(M.Ground, COL.earth)
Terrain.WaterColor = C(64, 150, 170)
Terrain.WaterTransparency = 0.45
Terrain.WaterReflectance = 0.5
Terrain.WaterWaveSize = 0.18
Terrain.WaterWaveSpeed = 9

-- ── Llum (default.project.json: Future, ClockTime 14, Brightness 2) ──
for _, x in ipairs(Lighting:GetChildren()) do
	if x.Name == "ChamonixColor" or x:IsA("BloomEffect") or x:IsA("DepthOfFieldEffect") or x:IsA("SunRaysEffect") then
		x:Destroy()
	end
end
local cl = Terrain:FindFirstChildOfClass("Clouds")
if cl then
	cl:Destroy()
end
-- tarda assolellada i càlida: ombres llargues però suaus, colors vius
Lighting.ClockTime = 15.2
Lighting.Brightness = 2.3
Lighting.ExposureCompensation = -0.12
Lighting.GeographicLatitude = 32
Lighting.Ambient = C(110, 100, 96)
Lighting.OutdoorAmbient = C(150, 140, 132)
Lighting.ColorShift_Top = C(255, 236, 206)
Lighting.ColorShift_Bottom = C(170, 190, 220)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.7
Lighting.ShadowSoftness = 0.35
Lighting.FogEnd = 100000
Lighting.GlobalShadows = true
pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atm.Name = "FossilAtmosphere"
atm.Density = 0.28
atm.Offset = 0.2
atm.Haze = 1.2
atm.Glare = 0.35
atm.Color = C(214, 222, 236)
atm.Decay = C(120, 150, 196)
atm.Parent = Lighting
local cc = Lighting:FindFirstChild("FossilColor") or Instance.new("ColorCorrectionEffect")
cc.Name = "FossilColor"
cc.Saturation = 0.18
cc.Contrast = 0.08
cc.Brightness = 0.02
cc.TintColor = C(255, 248, 236)
cc.Parent = Lighting
local bloom = Lighting:FindFirstChild("FossilBloom") or Instance.new("BloomEffect")
bloom.Name = "FossilBloom"
bloom.Intensity = 0.35
bloom.Size = 28
bloom.Threshold = 2
bloom.Parent = Lighting
local rays = Lighting:FindFirstChild("FossilSunRays") or Instance.new("SunRaysEffect")
rays.Name = "FossilSunRays"
rays.Intensity = 0.06
rays.Spread = 0.6
rays.Parent = Lighting
-- núvols esponjosos
local clouds = Instance.new("Clouds")
clouds.Cover = 0.52
clouds.Density = 0.6
clouds.Color = C(255, 252, 246)
clouds.Parent = Terrain
print("Terreny, platja i llum fets")
