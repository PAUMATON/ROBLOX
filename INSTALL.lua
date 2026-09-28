--[[ ═══════════════════════════════════════════════════════════════════════
     MUSEU DE FOSSILS  ·  instal.lador de la Zona 1 "Obra"

     COM S'USA (dues opcions):

     A) COM A PLUGIN (recomanat, un sol clic)
        Aquest fitxer ja esta copiat a la carpeta de plugins de Roblox.
        Obre Roblox Studio -> pestanya PLUGINS -> boto "Construir Zona 1".

     B) MANUALMENT
        Roblox Studio -> View -> Command Bar -> enganxa TOT -> Enter.

     Es pot tornar a executar tantes vegades com vulguis: neteja i refa.

     ESCALES (fixades a CLAUDE.md, no s'en surt res):
       jugador 5 · zona 80x80 · tanca 4 alt · excavadora 12-14 alt
       caravana 8x4x3 · grua 22 alt · edifici 40x30 d'ocupacio
     ═══════════════════════════════════════════════════════════════════════ ]]

local function Install()
	local Workspace = game:GetService("Workspace")
	local Lighting = game:GetService("Lighting")
	local CollectionService = game:GetService("CollectionService")

	-- ─────────────────────── ESCALES ───────────────────────
	local ZONE = 80 -- 80x80
	local HALF = ZONE / 2 -- ±40
	local SURFACE_Y = 2 -- cota superior de la plataforma
	local FENCE_H = 4

	-- ─────────────────────── COLORS ────────────────────────
	local SAND = Color3.fromRGB(217, 199, 160) -- #D9C7A0
	local EARTH = Color3.fromRGB(139, 111, 71) -- #8B6F47
	local ROCK = Color3.fromRGB(110, 106, 99) -- #6E6A63
	local YELLOW = Color3.fromRGB(230, 190, 40)
	local DARK_YELLOW = Color3.fromRGB(180, 150, 30)
	local ORANGE = Color3.fromRGB(255, 107, 0) -- #FF6B00, fluorescent
	local BLACK = Color3.fromRGB(30, 30, 30)
	local DARK_GRAY = Color3.fromRGB(50, 50, 50)
	local GRAY = Color3.fromRGB(100, 100, 100)
	local RUST = Color3.fromRGB(139, 69, 19) -- #8B4513
	local WHITE = Color3.fromRGB(230, 230, 230)
	local WINDOW = Color3.fromRGB(35, 50, 60)
	local BRICK = Color3.fromRGB(170, 90, 50)
	local PVC = Color3.fromRGB(220, 220, 215)
	local CONCRETE = Color3.fromRGB(184, 180, 168) -- #B8B4A8

	-- ─────────────────────── HELPERS ───────────────────────
	local function P(props, parent)
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in pairs(props) do
			p[k] = v
		end
		p.Parent = parent
		return p
	end

	local function New(cls, props, parent)
		local o = Instance.new(cls)
		for k, v in pairs(props) do
			o[k] = v
		end
		if parent then o.Parent = parent end
		return o
	end

	-- Cilindre vertical: l'eix d'un Cylinder va per X, cal tombar-lo 90 graus.
	local function VCyl(props, parent)
		props.Shape = Enum.PartType.Cylinder
		props.CFrame = props.CFrame * CFrame.Angles(0, 0, math.rad(90))
		return P(props, parent)
	end

	-- Cilindre horitzontal amb l'eix per Z (tubs).
	local function ZCyl(props, parent)
		props.Shape = Enum.PartType.Cylinder
		props.CFrame = props.CFrame * CFrame.Angles(0, math.rad(90), 0)
		return P(props, parent)
	end

	-- Cilindre inclinat: dona un CFrame construit com per a un Part normal
	-- (pivot * CFrame.new(0,0,dist) * Angles(tilt,0,0), com el Boom/Stick de
	-- l'altra excavadora) i el reorienta perque l'eix del cilindre (X local)
	-- segueixi aquesta mateixa direccio. Aixi es poden encadenar seccions.
	local function AxisCyl(props, parent)
		props.Shape = Enum.PartType.Cylinder
		props.CFrame = props.CFrame * CFrame.Angles(0, math.rad(-90), 0)
		return P(props, parent)
	end

	-- Escriure .Source nomes funciona si Studio ha donat permis d'injeccio
	-- de scripts al plugin. Si no, aqui es veu de seguida.
	local scriptsOk = true
	local function makeScript(cls, name, src, parent)
		local ok, err = pcall(function()
			New(cls, { Name = name, Source = src }, parent)
		end)
		if not ok then
			scriptsOk = false
			warn("[Museu] no s'ha pogut escriure " .. name .. ": " .. tostring(err))
		end
		return ok
	end

	-- ─────────────────────── NETEJA ────────────────────────
	for _, name in ipairs({ "Zones", "Museums", "World", "Baseplate" }) do
		local x = Workspace:FindFirstChild(name)
		if x then x:Destroy() end
	end
	for _, x in ipairs(Workspace:GetChildren()) do
		if x:IsA("SpawnLocation") then x:Destroy() end
	end
	local oldAtmo = Lighting:FindFirstChild("FossilAtmosphere")
	if oldAtmo then oldAtmo:Destroy() end

	-- ─────────────────────── CARPETES ──────────────────────
	local zones = New("Folder", { Name = "Zones" }, Workspace)
	New("Folder", { Name = "Museums" }, Workspace)
	New("Folder", { Name = "World" }, Workspace)

	local zone = Instance.new("Model")
	zone.Name = "Construction"

	local decor = New("Folder", { Name = "Decor" }, zone)

	-- ═══════════════════════════════════════════════════════════════════════
	-- CONSTRUCCIO COMENCA AQUI
	-- ═══════════════════════════════════════════════════════════════════════

	-- ═══════════════ PLATAFORMA 80x80 ═══════════════
	P({
		Name = "BaseConstructionSite",
		Size = Vector3.new(ZONE, 4, ZONE),
		Position = Vector3.new(0, 0, 0),
		Color = EARTH,
		Material = Enum.Material.Slate,
	}, zone)

	-- ═══════════════ EDIFICI EN CONSTRUCCIO (costat NE, torre estreta) ═══════════════
	-- Mes alt i mes estret que abans: petjada 16x12 (HX=8,HZ=6) en lloc de
	-- 30x30, 8 plantes de 3.2 (alt total 25.6). Parets de bloc de formigo
	-- a mitja alcada a totes les plantes (com si s'estiguessin aixecant ara
	-- mateix) + bastida i escala als 4 costats. Nomes l'edifici, sense
	-- maquinaria. Centre (27,-29): 5 studs dels bordes nord i est.
	do
		local bldg = Instance.new("Model")
		bldg.Name = "BuildingUnderConstruction"
		local bldgO = CFrame.new(27, SURFACE_Y, -29)
		local HX, HZ = 8, 6 -- petjada 16x12
		local FLOOR_H = 3.2
		local FLOORS = 8
		local TOP_Y = FLOORS * FLOOR_H
		local WALL_H = FLOOR_H * 0.62 -- paret nomes fins a mitja alcada, oberta a dalt

		-- Columnes: 4 cantonades + 4 al mig de cada cara, alcada sencera
		local colXZ = {}
		for _, dx in ipairs({ -HX, 0, HX }) do
			for _, dz in ipairs({ -HZ, 0, HZ }) do
				if dx ~= 0 or dz ~= 0 then
					table.insert(colXZ, { dx, dz })
				end
			end
		end
		for _, c in ipairs(colXZ) do
			local dx, dz = c[1], c[2]
			local isCorner = (dx == -HX or dx == HX) and (dz == -HZ or dz == HZ)
			P({
				Name = "Column",
				Size = Vector3.new(isCorner and 1.6 or 1.3, TOP_Y, isCorner and 1.6 or 1.3),
				CFrame = bldgO * CFrame.new(dx, TOP_Y / 2, dz),
				Color = ROCK,
				Material = Enum.Material.Slate,
			}, bldg)
			-- Ferro que sobresurt del capdamunt (planta 9 encara no colada)
			for _, rdx in ipairs({ -0.45, 0.45 }) do
				for _, rdz in ipairs({ -0.45, 0.45 }) do
					P({
						Name = "RebarStub",
						Size = Vector3.new(0.1, 1.8, 0.1),
						CFrame = bldgO * CFrame.new(dx + rdx, TOP_Y + 0.9, dz + rdz),
						Color = RUST,
						Material = Enum.Material.Metal,
						CanCollide = false,
						CastShadow = false,
					}, bldg)
				end
			end
		end

		-- Lloses de cada planta
		for level = 0, FLOORS do
			P({
				Name = "Slab" .. level,
				Size = Vector3.new(HX * 2 + 0.6, 0.35, HZ * 2 + 0.6),
				CFrame = bldgO * CFrame.new(0, level * FLOOR_H, 0),
				Color = CONCRETE,
				Material = Enum.Material.Concrete,
			}, bldg)
		end

		-- Parets de bloc de formigo a mitja alcada, totes les plantes, amb un
		-- buit central a cada cara (obertura de finestra/porta encara sense fer).
		local wallFaces = {
			{ dx = 1, len = HZ * 2 },
			{ dx = -1, len = HZ * 2 },
			{ dz = 1, len = HX * 2 },
			{ dz = -1, len = HX * 2 },
		}
		for level = 0, FLOORS - 1 do
			local baseY = level * FLOOR_H + 0.2 + WALL_H / 2
			for _, f in ipairs(wallFaces) do
				local segLen = f.len / 2 - 1.4 -- deixa un buit d'uns 2.8 al mig
				for _, side in ipairs({ -1, 1 }) do
					local offset = side * (f.len / 4 + 0.7)
					if f.dx then
						P({
							Name = "Wall",
							Size = Vector3.new(0.6, WALL_H, segLen),
							CFrame = bldgO * CFrame.new(f.dx * HX, baseY, offset),
							Color = CONCRETE,
							Material = Enum.Material.Concrete,
						}, bldg)
					else
						P({
							Name = "Wall",
							Size = Vector3.new(segLen, WALL_H, 0.6),
							CFrame = bldgO * CFrame.new(offset, baseY, f.dz * HZ),
							Color = CONCRETE,
							Material = Enum.Material.Concrete,
						}, bldg)
					end
				end
			end
		end

		-- Bastida completa als 4 costats: pals verticals sencers + baranes
		-- horitzontals a cada planta, separats 1 stud de la façana.
		for _, c in ipairs(colXZ) do
			local ox = c[1] ~= 0 and c[1] + (c[1] > 0 and 1 or -1) or c[1]
			local oz = c[2] ~= 0 and c[2] + (c[2] > 0 and 1 or -1) or c[2]
			P({
				Name = "ScaffoldPole",
				Size = Vector3.new(0.15, TOP_Y, 0.15),
				CFrame = bldgO * CFrame.new(ox, TOP_Y / 2, oz),
				Color = GRAY,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CastShadow = false,
			}, bldg)
		end
		for level = 1, FLOORS do
			local y = level * FLOOR_H
			for _, f in ipairs(wallFaces) do
				local off = (f.dx and HX or HZ) + 1
				if f.dx then
					P({
						Name = "ScaffoldRail",
						Size = Vector3.new(0.12, 0.12, f.len + 2),
						CFrame = bldgO * CFrame.new(f.dx * off, y, 0),
						Color = GRAY,
						Material = Enum.Material.Metal,
						CanCollide = false,
						CastShadow = false,
					}, bldg)
				else
					P({
						Name = "ScaffoldRail",
						Size = Vector3.new(f.len + 2, 0.12, 0.12),
						CFrame = bldgO * CFrame.new(0, y, f.dz * off),
						Color = GRAY,
						Material = Enum.Material.Metal,
						CanCollide = false,
						CastShadow = false,
					}, bldg)
				end
			end
		end

		-- Escala de ma recolzada a la cara sud, de terra a la planta 1
		do
			local ladderO = bldgO * CFrame.new(0, 0, HZ + 1.3) * CFrame.Angles(math.rad(-62), 0, 0)
			for _, railX in ipairs({ -0.5, 0.5 }) do
				P({
					Name = "LadderRail",
					Size = Vector3.new(0.15, FLOOR_H + 1.5, 0.12),
					CFrame = ladderO * CFrame.new(railX, (FLOOR_H + 1.5) / 2, 0),
					Color = EARTH,
					Material = Enum.Material.WoodPlanks,
					CanCollide = false,
					CastShadow = false,
				}, bldg)
			end
			for rung = 1, 6 do
				P({
					Name = "LadderRung",
					Size = Vector3.new(1.1, 0.12, 0.12),
					CFrame = ladderO * CFrame.new(0, rung * 0.7, 0),
					Color = EARTH,
					Material = Enum.Material.WoodPlanks,
					CanCollide = false,
					CastShadow = false,
				}, bldg)
			end
		end

		bldg.Parent = zone
	end

	-- ═══════════════ GRUA TORRE (gelosia detallada) ═══════════════
	-- A l'oest de l'edifici (que es centra a X=27, Z=-29). Girada 90 perque
	-- el braç (+Z local) apunti cap a +X i sobrevoli tota la torre.
	-- Pal de gelosia real (diagonals en ziga-zaga a les 4 cares), escala
	-- d'accés amb replans, collar d'enfilada, corona de gir, cabina, cap de
	-- torre amb tirants, ploma triangular amb carro i ganxo, contraploma
	-- amb maquinaria i contrapesos.
	do
		local m = Instance.new("Model")
		m.Name = "TowerCrane"
		local CRANE = Color3.fromRGB(232, 185, 35) -- #E8B923
		local CRANE_DK = Color3.fromRGB(196, 150, 22)
		local STEEL = Color3.fromRGB(120, 122, 125)

		local SEC = 1.1 -- mig ample del pal (seccio 2.2)
		local PANEL = 3 -- alcada d'un panell de gelosia
		local PANELS = 10
		local BASE_TOP = 1
		local TOWER_H = PANEL * PANELS -- 30
		local slewY = BASE_TOP + TOWER_H -- 31
		local ARM_LEN = 22
		local CJ_LEN = 9
		local TROLLEY_Z = 15 -- sobre el centre de l'edifici (X=27)
		local jibTop = slewY + 2.4
		local jibBot = slewY + 0.8
		local apexY = slewY + 7

		local O = CFrame.new(12, SURFACE_Y, -29) * CFrame.Angles(0, math.rad(90), 0)

		-- Punt local -> mon, per poder tracar barres entre dos punts qualsevol.
		local function LP(x, y, z)
			return O:PointToWorldSpace(Vector3.new(x, y, z))
		end
		local function Rod(name, p1, p2, thick, color)
			local mid = (p1 + p2) / 2
			return P({
				Name = name,
				Size = Vector3.new(thick, thick, (p2 - p1).Magnitude),
				CFrame = CFrame.new(mid, p2),
				Color = color or CRANE,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CastShadow = false,
			}, m)
		end
		local function Beam(name, size, cf, color, material)
			return P({
				Name = name,
				Size = size,
				CFrame = cf,
				Color = color or CRANE,
				Material = material or Enum.Material.Metal,
				CanCollide = false,
				CastShadow = false,
			}, m)
		end

		-- ── FONAMENT ──
		P({
			Name = "Foundation",
			Size = Vector3.new(7, 1, 7),
			CFrame = O * CFrame.new(0, 0.5, 0),
			Color = CONCRETE,
			Material = Enum.Material.Concrete,
		}, m)
		for _, bx in ipairs({ -2.4, 2.4 }) do
			for _, bz in ipairs({ -2.4, 2.4 }) do
				P({
					Name = "Ballast",
					Size = Vector3.new(2.2, 1.1, 2.2),
					CFrame = O * CFrame.new(bx, 1.55, bz),
					Color = CONCRETE,
					Material = Enum.Material.Concrete,
				}, m)
				Beam("AnchorBolt", Vector3.new(0.25, 0.5, 0.25), O * CFrame.new(bx, 2.3, bz), STEEL)
			end
		end

		-- ── PAL DE GELOSIA ──
		for _, dx in ipairs({ -SEC, SEC }) do
			for _, dz in ipairs({ -SEC, SEC }) do
				P({
					Name = "MastLeg",
					Size = Vector3.new(0.36, TOWER_H, 0.36),
					CFrame = O * CFrame.new(dx, BASE_TOP + TOWER_H / 2, dz),
					Color = CRANE,
					Material = Enum.Material.Metal,
					CastShadow = false,
				}, m)
			end
		end
		for p = 0, PANELS do
			local y = BASE_TOP + p * PANEL
			-- anella horitzontal (4 travessers)
			for _, dx in ipairs({ -SEC, SEC }) do
				Beam("MastRing", Vector3.new(0.18, 0.18, SEC * 2), O * CFrame.new(dx, y, 0), CRANE)
			end
			for _, dz in ipairs({ -SEC, SEC }) do
				Beam("MastRing", Vector3.new(SEC * 2, 0.18, 0.18), O * CFrame.new(0, y, dz), CRANE)
			end
			-- diagonals en ziga-zaga a les 4 cares
			if p < PANELS then
				local y2 = y + PANEL
				local flip = (p % 2 == 0)
				local a, b = -SEC, SEC
				if not flip then
					a, b = SEC, -SEC
				end
				for _, dx in ipairs({ -SEC, SEC }) do
					Rod("MastBrace", LP(dx, y, a), LP(dx, y2, b), 0.16, CRANE)
				end
				for _, dz in ipairs({ -SEC, SEC }) do
					Rod("MastBrace", LP(a, y, dz), LP(b, y2, dz), 0.16, CRANE)
				end
			end
		end

		-- Escala d'acces amb replans cada 9 studs
		for _, lx in ipairs({ -0.3, 0.3 }) do
			Beam("LadderRail", Vector3.new(0.12, TOWER_H, 0.12), O * CFrame.new(lx, BASE_TOP + TOWER_H / 2, -SEC + 0.3), STEEL)
		end
		for r = 1, math.floor(TOWER_H) do
			Beam("LadderRung", Vector3.new(0.72, 0.1, 0.1), O * CFrame.new(0, BASE_TOP + r, -SEC + 0.3), STEEL)
		end
		for _, py in ipairs({ 9, 18, 27 }) do
			Beam("RestPlatform", Vector3.new(1.9, 0.12, 1.1), O * CFrame.new(0, BASE_TOP + py, -SEC + 0.7), STEEL)
		end

		-- Collar d'enfilada (la gabia que fa pujar la grua per trams)
		do
			local cy = BASE_TOP + 21
			for _, dx in ipairs({ -1.7, 1.7 }) do
				Beam("ClimbCage", Vector3.new(0.22, 4.5, 0.22), O * CFrame.new(dx, cy, -1.7), CRANE_DK)
				Beam("ClimbCage", Vector3.new(0.22, 4.5, 0.22), O * CFrame.new(dx, cy, 1.7), CRANE_DK)
			end
			for _, dy in ipairs({ -2.2, 2.2 }) do
				for _, dz in ipairs({ -1.7, 1.7 }) do
					Beam("ClimbRing", Vector3.new(3.6, 0.2, 0.2), O * CFrame.new(0, cy + dy, dz), CRANE_DK)
				end
				for _, dx in ipairs({ -1.7, 1.7 }) do
					Beam("ClimbRing", Vector3.new(0.2, 0.2, 3.6), O * CFrame.new(dx, cy + dy, 0), CRANE_DK)
				end
			end
		end

		-- ── CORONA DE GIR ──
		VCyl({
			Name = "SlewRing",
			Size = Vector3.new(0.8, 3.2, 3.2),
			CFrame = O * CFrame.new(0, slewY - 0.2, 0),
			Color = STEEL,
			Material = Enum.Material.Metal,
			CastShadow = false,
		}, m)
		P({
			Name = "SlewDeck",
			Size = Vector3.new(3.6, 0.5, 4),
			CFrame = O * CFrame.new(0, slewY + 0.45, 0),
			Color = DARK_YELLOW,
			Material = Enum.Material.Metal,
		}, m)

		-- ── CABINA ──
		do
			local cab = P({
				Name = "Cab",
				Size = Vector3.new(2.1, 2.1, 2.4),
				CFrame = O * CFrame.new(2, slewY + 1.8, 0.9),
				Color = CRANE,
				Material = Enum.Material.Metal,
			}, m)
			Beam("CabRoof", Vector3.new(2.4, 0.15, 2.7), cab.CFrame * CFrame.new(0, 1.12, 0), CRANE_DK)
			-- vidre frontal inclinat, mirant cap a la ploma
			P({
				Name = "CabWindowFront",
				Size = Vector3.new(1.9, 1.5, 0.12),
				CFrame = cab.CFrame * CFrame.new(0, 0.1, 1.24) * CFrame.Angles(math.rad(12), 0, 0),
				Color = WINDOW,
				Transparency = 0.25,
				CanCollide = false,
				CastShadow = false,
			}, m)
			P({
				Name = "CabWindowSide",
				Size = Vector3.new(0.12, 1.2, 1.8),
				CFrame = cab.CFrame * CFrame.new(1.06, 0.15, 0),
				Color = WINDOW,
				Transparency = 0.25,
				CanCollide = false,
				CastShadow = false,
			}, m)
			Beam("CabPlatform", Vector3.new(1.2, 0.12, 2.4), O * CFrame.new(3.5, slewY + 0.75, 0.9), STEEL)
			Beam("CabRail", Vector3.new(0.1, 0.1, 2.4), O * CFrame.new(4, slewY + 1.55, 0.9), STEEL)
		end

		-- ── CAP DE TORRE + TIRANTS ──
		local apex = LP(0, apexY, 0)
		for _, dx in ipairs({ -1, 1 }) do
			for _, dz in ipairs({ -1, 1 }) do
				Rod("HeadLeg", LP(dx, slewY + 0.7, dz), apex, 0.22, CRANE)
			end
		end
		Beam("HeadCap", Vector3.new(0.5, 0.4, 0.5), O * CFrame.new(0, apexY + 0.2, 0), CRANE_DK)
		P({
			Name = "AviationLight",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.45, 0.45, 0.45),
			CFrame = O * CFrame.new(0, apexY + 0.6, 0),
			Color = Color3.fromRGB(255, 60, 50),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		}, m)
		-- pendulars: 2 punts a la ploma i 1 a la contraploma
		Rod("Pendant", apex, LP(0, jibTop, 10), 0.14, STEEL)
		Rod("Pendant", apex, LP(0, jibTop, ARM_LEN - 1), 0.14, STEEL)
		Rod("Pendant", apex, LP(0, jibTop, -(CJ_LEN - 1)), 0.14, STEEL)

		-- ── PLOMA (seccio triangular: 1 corda a dalt, 2 a baix) ──
		Beam("JibTopChord", Vector3.new(0.32, 0.32, ARM_LEN), O * CFrame.new(0, jibTop, ARM_LEN / 2), CRANE)
		for _, dx in ipairs({ -0.75, 0.75 }) do
			Beam("JibBotChord", Vector3.new(0.28, 0.28, ARM_LEN), O * CFrame.new(dx, jibBot, ARM_LEN / 2), CRANE)
		end
		Beam("JibCross", Vector3.new(1.5, 0.16, 0.16), O * CFrame.new(0, jibBot, ARM_LEN), CRANE)
		for z = 0, ARM_LEN - 3, 3 do
			Beam("JibCross", Vector3.new(1.5, 0.16, 0.16), O * CFrame.new(0, jibBot, z), CRANE)
			Rod("JibWeb", LP(0, jibTop, z), LP(-0.75, jibBot, z + 3), 0.14, CRANE)
			Rod("JibWeb", LP(0, jibTop, z), LP(0.75, jibBot, z + 3), 0.14, CRANE)
			-- ziga-zaga al pla inferior
			Rod("JibWebBot", LP(-0.75, jibBot, z), LP(0.75, jibBot, z + 3), 0.13, CRANE)
		end
		-- punta de ploma amb politja (eix lateral, com una roda)
		Beam("JibTipPlate", Vector3.new(1.6, 0.9, 0.3), O * CFrame.new(0, jibBot + 0.5, ARM_LEN), CRANE_DK)
		P({
			Name = "JibSheave",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 0.7, 0.7),
			CFrame = O * CFrame.new(0, jibBot + 0.5, ARM_LEN - 0.3),
			Color = STEEL,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CastShadow = false,
		}, m)
		-- barana del passadis de servei
		for _, dx in ipairs({ -0.95, 0.95 }) do
			Beam("JibRail", Vector3.new(0.09, 0.09, ARM_LEN), O * CFrame.new(dx, jibTop + 1, ARM_LEN / 2), STEEL)
		end
		for z = 2, ARM_LEN - 1, 4 do
			for _, dx in ipairs({ -0.95, 0.95 }) do
				Beam("JibRailPost", Vector3.new(0.09, 1, 0.09), O * CFrame.new(dx, jibTop + 0.5, z), STEEL)
			end
		end

		-- ── CARRO (trolley) + CABLE + GANXO ──
		do
			local trY = jibBot - 0.45
			Beam("TrolleyBody", Vector3.new(1.7, 0.7, 1.8), O * CFrame.new(0, trY, TROLLEY_Z), CRANE_DK)
			for _, wx in ipairs({ -0.75, 0.75 }) do
				for _, wz in ipairs({ -0.65, 0.65 }) do
					P({
						Name = "TrolleyWheel",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(0.16, 0.5, 0.5),
						CFrame = O * CFrame.new(wx, trY + 0.42, TROLLEY_Z + wz),
						Color = STEEL,
						Material = Enum.Material.Metal,
						CanCollide = false,
						CastShadow = false,
					}, m)
				end
			end

			-- El ganxo penja just per sobre del terrat de l'edifici (25.6)
			local hookY = 27
			local ropeLen = trY - 0.35 - hookY
			for _, rx in ipairs({ -0.3, 0.3 }) do
				Beam("HoistRope", Vector3.new(0.08, ropeLen, 0.08), O * CFrame.new(rx, hookY + ropeLen / 2, TROLLEY_Z), STEEL)
			end
			Beam("HookBlock", Vector3.new(1.1, 0.8, 0.8), O * CFrame.new(0, hookY, TROLLEY_Z), CRANE_DK)
			P({
				Name = "HookSheave",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.14, 0.6, 0.6),
				CFrame = O * CFrame.new(0, hookY, TROLLEY_Z + 0.45),
				Color = STEEL,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CastShadow = false,
			}, m)
			Beam("HookShank", Vector3.new(0.22, 0.7, 0.22), O * CFrame.new(0, hookY - 0.7, TROLLEY_Z), STEEL)
			Beam("HookCurve", Vector3.new(0.22, 0.22, 0.7), O * CFrame.new(0, hookY - 1.05, TROLLEY_Z + 0.25), STEEL)
			Beam("HookTip", Vector3.new(0.2, 0.5, 0.2), O * CFrame.new(0, hookY - 0.85, TROLLEY_Z + 0.5), STEEL)
		end

		-- ── CONTRAPLOMA ──
		for _, dx in ipairs({ -0.7, 0.7 }) do
			Beam("CJTopChord", Vector3.new(0.28, 0.28, CJ_LEN), O * CFrame.new(dx, jibTop - 0.4, -CJ_LEN / 2), CRANE)
			Beam("CJBotChord", Vector3.new(0.28, 0.28, CJ_LEN), O * CFrame.new(dx, jibBot, -CJ_LEN / 2), CRANE)
		end
		for z = -1, -(CJ_LEN - 2), -2 do
			Beam("CJPost", Vector3.new(1.6, 0.14, 0.14), O * CFrame.new(0, jibBot, z), CRANE)
			Rod("CJWeb", LP(-0.7, jibBot, z), LP(0.7, jibTop - 0.4, z - 2), 0.13, CRANE)
		end
		Beam("CJDeck", Vector3.new(1.9, 0.14, CJ_LEN), O * CFrame.new(0, jibBot + 0.3, -CJ_LEN / 2), STEEL)
		for _, dx in ipairs({ -1, 1 }) do
			Beam("CJRail", Vector3.new(0.09, 0.09, CJ_LEN), O * CFrame.new(dx, jibBot + 1.3, -CJ_LEN / 2), STEEL)
		end
		-- caseta de maquinaria (torn del cable)
		P({
			Name = "MachineryHouse",
			Size = Vector3.new(2.3, 1.8, 3.2),
			CFrame = O * CFrame.new(0, jibTop - 0.4, -3.4),
			Color = CRANE_DK,
			Material = Enum.Material.Metal,
		}, m)
		P({
			Name = "HoistDrum",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.8, 1.2, 1.2), -- eix lateral, com un torn de veritat
			CFrame = O * CFrame.new(0, jibTop - 0.4, -5.4),
			Color = STEEL,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CastShadow = false,
		}, m)
		-- contrapesos de formigo amb franja d'avis
		for i, cz in ipairs({ -7.6, -8.7 }) do
			P({
				Name = "Counterweight" .. i,
				Size = Vector3.new(3, 2.2, 1),
				CFrame = O * CFrame.new(0, jibBot + 0.9, cz),
				Color = CONCRETE,
				Material = Enum.Material.Concrete,
			}, m)
			Beam("CWStripe", Vector3.new(3.04, 0.35, 1.04), O * CFrame.new(0, jibBot + 1.7, cz), BLACK)
		end

		m.Parent = zone
	end

	zone.Parent = zones

	-- ═══════════════════════════════════════════════════════════════════════
	-- CIUTAT: placa quadrada al centre, 2 anelles d'edificis, 4 carrers
	-- ═══════════════════════════════════════════════════════════════════════
	-- Plantejament (vist des de dalt):
	--   placa 60x60 -> carrer -> anella 1 d'edificis -> carrer -> anella 2.
	--   Les dues anelles s'obren pel mig de cada costat (N/S/E/O): son els
	--   4 carrers que van de fora fins a la placa.
	local cityPivot, cityScale -- els fixa el bloc de la ciutat; els fa servir la galeria d'ossos
	do
		local city = Instance.new("Model")
		city.Name = "City"
		-- ─── ESCALA DE LA CIUTAT ───
		-- Tota l'arquitectura es multiplica per S. Canviar nomes aquest numero
		-- fa la ciutat mes gran o mes petita sense tocar res mes.
		--
		-- S=1.4 esta triat perque el jugador (5 studs) hi estigui comode:
		-- planta de 7 studs i porta de ~4.8, o sigui proporcions humanes.
		-- La sensacio de ciutat gran no ve d'inflar-ho tot, ve de tenir 4
		-- anelles i edificis de fins a 12 plantes (84 studs, 17 vegades el
		-- jugador — com un edifici real al costat d'una persona).
		local S = 1.4

		local C = CFrame.new(150, 0, 0) -- prop del spawn per arribar rapid
		cityPivot, cityScale = C, S

		local BONE = Color3.fromRGB(237, 227, 204) -- #EDE3CC
		local BRASS = Color3.fromRGB(192, 138, 62) -- #C08A3E
		local GREEN = Color3.fromRGB(47, 74, 60) -- #2F4A3C
		local ASPHALT = Color3.fromRGB(64, 66, 70) -- calçada
		local PAVE_A = Color3.fromRGB(203, 203, 200) -- llosa de placa
		local PAVE_B = Color3.fromRGB(188, 189, 187) -- vorera
		local LINE = Color3.fromRGB(238, 236, 228) -- marques vials
		local WATER = Color3.fromRGB(120, 165, 175)
		local WET_SAND = Color3.fromRGB(178, 160, 126)

		local G = SURFACE_Y -- cota del terra
		local FH = 5 * S -- alcada d'una planta

		-- ─── TRAÇAT: quadricula, no anelles ───
		-- Vist des de dalt, d'oest a est: 2x2 illes de cases, una illa
		-- estreta i llarga, la platja i el mar. Els carrers son els buits.
		local LAND_W, LAND_E = -260, 160 -- on comenca i acaba el terra de ciutat
		local LAND_N, LAND_S = -190, 190
		local PROM_E = 172 -- fi del passeig maritim
		local SAND_E = 252 -- fi de la sorra
		local SEA_E = 380 -- fi del mar

		-- Illes. La de dalt a l'esquerra es la zona d'obres.
		local BLOCKS = {
			{ id = "Obra", x0 = -242, x1 = -110, z0 = -172, z1 = -30, sides = { "N", "W" }, fMin = 3, fMax = 6 },
			{ id = "NE", x0 = -50, x1 = 82, z0 = -172, z1 = -30, sides = { "N", "S", "W", "E" }, fMin = 4, fMax = 9 },
			{ id = "SW", x0 = -242, x1 = -110, z0 = 30, z1 = 172, sides = { "N", "S", "W", "E" }, fMin = 3, fMax = 7 },
			{ id = "SE", x0 = -50, x1 = 82, z0 = 30, z1 = 172, sides = { "N", "S", "W", "E" }, fMin = 4, fMax = 8 },
			{ id = "Long", x0 = 102, x1 = 142, z0 = -172, z1 = 172, sides = { "W", "E" }, fMin = 2, fMax = 5 },
		}
		-- La placa surt de creuar l'avinguda nord-sud amb el carrer central.
		local PLAZA_X0, PLAZA_X1 = -110, -50
		local PLAZA_Z0, PLAZA_Z1 = -30, 30

		-- ── TERRA ──
		P({
			Name = "CityGround",
			Size = Vector3.new(LAND_E - LAND_W, 4, LAND_S - LAND_N),
			CFrame = C * CFrame.new((LAND_W + LAND_E) / 2, G - 2, (LAND_N + LAND_S) / 2),
			Color = ASPHALT,
			Material = Enum.Material.SmoothPlastic,
		}, city)

		-- Cada illa porta la seva vorera aixecada: es el que fa que des de
		-- dalt es vegi la quadricula, amb els carrers com a buits.
		for _, b in ipairs(BLOCKS) do
			P({
				Name = "Sidewalk_" .. b.id,
				Size = Vector3.new(b.x1 - b.x0 + 6, 0.5, b.z1 - b.z0 + 6),
				CFrame = C * CFrame.new((b.x0 + b.x1) / 2, G + 0.25, (b.z0 + b.z1) / 2),
				Color = PAVE_B,
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			}, city)
			-- vorada fosca: sense aixo la vorera no es llegeix des de terra
			P({
				Name = "Kerb_" .. b.id,
				Size = Vector3.new(b.x1 - b.x0 + 6.9, 0.42, b.z1 - b.z0 + 6.9),
				CFrame = C * CFrame.new((b.x0 + b.x1) / 2, G + 0.21, (b.z0 + b.z1) / 2),
				Color = Color3.fromRGB(150, 151, 149),
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			}, city)
		end

		-- Placa central: lloses grans i uniformes, no escacs. El dibuix a
		-- escacs era el que li donava aire de placa antiga; ara el que es
		-- veu es nomes la junta fosca entre lloses.
		local TILE = 10 * S
		local pw, pd = PLAZA_X1 - PLAZA_X0, PLAZA_Z1 - PLAZA_Z0
		local nx, nz = math.floor(pw / TILE), math.floor(pd / TILE)
		for ix = 0, nx - 1 do
			for iz = 0, nz - 1 do
				P({
					Name = "PlazaTile",
					Size = Vector3.new(pw / nx - 0.35, 0.4, pd / nz - 0.35),
					CFrame = C * CFrame.new(
						PLAZA_X0 + (pw / nx) * (ix + 0.5),
						G + 0.25,
						PLAZA_Z0 + (pd / nz) * (iz + 0.5)
					),
					Color = ((ix * 7 + iz * 3) % 5 == 0) and PAVE_B or PAVE_A,
					Material = Enum.Material.SmoothPlastic,
					CastShadow = false,
				}, city)
			end
		end

		-- ── EDIFICI DE CIUTAT ──
		-- baseCF: centre de la planta baixa, amb +Z local cap al carrer.
		--
		-- PELL (i per que surt tan barat): l'edifici es un NUCLI FOSC una
		-- mica mes estret, i a sobre hi van FRANGES CLARES que envolten els
		-- quatre costats. El fosc que queda entre franja i franja SON les
		-- finestres. Una torre de 14 plantes resol tota la seva envolupant,
		-- per les quatre cares, amb 15 peces. I com que el fosc esta
		-- retranquejat 0.3S, no hi ha manera que dues cares visibles caiguin
		-- al mateix pla: el z-fighting no pot tornar.
		--
		-- FORMAT: aqui hi ha 19 ARQUETIPS que componen els volums de maneres
		-- diferents. No son variacions d'una caixa; cada un dona una silueta
		-- propia. Es el que fa que la ciutat no sigui una filera de caixes.
		local SMOOTH = Enum.Material.SmoothPlastic

		-- Cada entrada es una PARELLA cos+finestra pensada junta, no dos
		-- colors a l'atzar: aixi cada edifici sembla dissenyat i, sobretot,
		-- es distingeix del del costat.
		local CITY_LOOK = {
			{ Color3.fromRGB(243, 242, 239), Color3.fromRGB(62, 68, 74) }, -- blanc · gris fosc
			{ Color3.fromRGB(236, 231, 220), Color3.fromRGB(56, 80, 100) }, -- os · blau
			{ Color3.fromRGB(206, 190, 158), Color3.fromRGB(72, 64, 52) }, -- caqui · bronze
			{ Color3.fromRGB(184, 166, 136), Color3.fromRGB(56, 52, 46) }, -- sorra fosca · marro
			{ Color3.fromRGB(150, 154, 158), Color3.fromRGB(46, 52, 60) }, -- gris mitja · carbo
			{ Color3.fromRGB(118, 126, 136), Color3.fromRGB(36, 44, 52) }, -- gris blau fosc
			{ Color3.fromRGB(214, 206, 190), Color3.fromRGB(76, 92, 106) }, -- crema · pissarra
			{ Color3.fromRGB(176, 142, 116), Color3.fromRGB(54, 48, 42) }, -- terracota apagada
			{ Color3.fromRGB(196, 200, 198), Color3.fromRGB(50, 72, 86) }, -- gris clar · teal
			{ Color3.fromRGB(164, 176, 178), Color3.fromRGB(42, 60, 72) }, -- gris verdos
			{ Color3.fromRGB(228, 216, 188), Color3.fromRGB(92, 100, 92) }, -- sorra clara · oliva
			{ Color3.fromRGB(138, 148, 154), Color3.fromRGB(38, 52, 64) }, -- gris blau
			{ Color3.fromRGB(222, 214, 206), Color3.fromRGB(88, 78, 68) }, -- perla · torrat
			{ Color3.fromRGB(160, 150, 132), Color3.fromRGB(48, 46, 42) }, -- oliva grisos
		}
		local CITY_GLASS = { -- nomes per a les torres de mur cortina
			Color3.fromRGB(96, 130, 152),
			Color3.fromRGB(62, 94, 118),
			Color3.fromRGB(44, 68, 86),
			Color3.fromRGB(100, 130, 132),
			Color3.fromRGB(70, 106, 104),
		}
		-- Arquetips. Els que surten repetits son mes frequents: una ciutat
		-- necessita fons de prismes i blocs, i que les torres rares es
		-- notin justament per ser poques.
		local ARCHETYPES = {
			"prism", "prism", "prism",
			"slab", "slab",
			"setback", "setback",
			"stepside", "ziggurat", "spire", "pyramid",
			"round", "diamond", "twistcrown",
			"ell", "tee", "twin", "corebox",
			"cantilever", "jenga", "parking", "archbase",
		}
		local lastLook, lastArch = 0, ""

		local cityParts, cityCount = 0, 0

		local function buildCityBuilding(baseCF, w, d, floors, hiDetail)
			local m = Instance.new("Model")
			m.Name = "CityBuilding"

			-- ═══ 1. PELL ═══
			-- Mai dos edificis seguits amb el mateix aspecte ni el mateix
			-- arquetip: fillEdge els posa l'un al costat de l'altre.
			local li = math.random(1, #CITY_LOOK)
			if li == lastLook then
				li = (li % #CITY_LOOK) + 1
			end
			lastLook = li
			local band, core = CITY_LOOK[li][1], CITY_LOOK[li][2]
			local whiteFrac, mSpan
			local q = math.random()
			if q < 0.16 then -- mur cortina: gairebe tot vidre
				core = CITY_GLASS[math.random(1, #CITY_GLASS)]
				whiteFrac, mSpan = 0.2 + math.random() * 0.1, (4 + math.random() * 1.6) * S
			elseif q < 0.5 then -- graella: muntants junts
				whiteFrac, mSpan = 0.42 + math.random() * 0.16, (2.9 + math.random() * 1.2) * S
			else -- franges horitzontals amples
				whiteFrac, mSpan = 0.56 + math.random() * 0.16, (7 + math.random() * 5) * S
			end
			local roofC = band:Lerp(Color3.fromRGB(56, 58, 60), 0.74)
			local plinthC = band:Lerp(Color3.fromRGB(70, 72, 74), 0.55)
			local INS = 0.3 * S

			local NC = { CanCollide = false, CastShadow = false }
			local function B(name, size, cf, color, material, extra)
				local t = { Name = name, Size = size, CFrame = cf, Color = color, Material = material }
				if extra then
					for k, v in pairs(extra) do
						t[k] = v
					end
				end
				return P(t, m)
			end

			-- ═══ 2. MIDA ═══
			-- Que no tots omplin el seu solar es la meitat de la feina: si
			-- l'ample sempre encaixa, el carrer es un mur continu.
			if math.random() < 0.34 then
				w *= 0.52 + math.random() * 0.32
				d *= 0.7 + math.random() * 0.24
			end
			if math.random() < 0.3 then
				floors = math.min(24, math.floor(floors * (1.5 + math.random())))
			end
			-- Com que l'ample i el fons s'encongien per separat, sortien
			-- edificis-fulla (8 d'ample per 25 de fons) i ganivetes (8
			-- d'ample per 140 d'alt). Les dues coses queden lletges de
			-- valent, aixi que aqui es topen les dues proporcions.
			if w > d * 2.1 then
				w = d * 2.1
			end
			if d > w * 2.1 then
				d = w * 2.1
			end
			floors = math.max(2, math.min(floors, math.floor(math.min(w, d) * 9 / FH)))
			local h = floors * FH

			-- ═══ 3. FORMAT ═══
			local arch = ARCHETYPES[math.random(1, #ARCHETYPES)]
			if arch == lastArch then
				arch = ARCHETYPES[(math.random(1, #ARCHETYPES) % #ARCHETYPES) + 1]
			end
			lastArch = arch

			-- Volum: y0..y1, ample, fons, i un CFrame propi que ja porta el
			-- desplaçament i el gir. Aixi hi caben plantes girades 45 graus,
			-- voladissos i ales sense tocar res mes.
			local vols = {}
			local function V(y0, y1, vw, vd, xo, zo, rot, rnd, cap)
				table.insert(vols, {
					y0 = y0,
					y1 = y1,
					w = vw,
					d = vd,
					round = rnd or false,
					cap = (cap ~= false),
					cf = baseCF * CFrame.new(xo or 0, 0, zo or 0) * CFrame.Angles(0, math.rad(rot or 0), 0),
				})
			end

			if arch == "slab" then
				floors = math.max(2, math.floor(floors * 0.45))
				h = floors * FH
				V(0, h, w, d)
			elseif arch == "round" then
				local r = math.min(w, d)
				V(0, h, r, r, 0, 0, 0, true)
			elseif arch == "diamond" then
				local s2 = math.min(w, d) * 0.68
				V(0, h, s2, s2, 0, 0, 45)
			elseif arch == "setback" then
				local kT = math.max(2, math.floor(floors * 0.36))
				local yc = math.max(FH * 2, (floors - kT) * FH)
				V(0, yc, w, d)
				V(yc, h, w * 0.66, d * 0.72)
			elseif arch == "stepside" then
				-- nomes es retranqueja per un costat: silueta asimetrica
				local kT = math.max(2, math.floor(floors * 0.42))
				local yc = math.max(FH * 2, (floors - kT) * FH)
				V(0, yc, w, d)
				V(yc, h, w * 0.55, d, -w * 0.2)
			elseif arch == "ziggurat" then
				floors = math.max(6, floors)
				h = floors * FH
				for i = 1, 4 do
					V(h * (i - 1) / 4, h * i / 4, w * (1 - (i - 1) * 0.17), d * (1 - (i - 1) * 0.17))
				end
			elseif arch == "spire" then
				floors = math.max(8, floors)
				h = floors * FH
				V(0, h, w, d)
				local ty, tw, td = h, w * 0.6, d * 0.6
				for _ = 1, 3 do
					V(ty, ty + FH * 0.9, tw, td, 0, 0, 0, false, false)
					ty += FH * 0.9
					tw, td = tw * 0.6, td * 0.6
				end
			elseif arch == "pyramid" then
				floors = math.max(7, floors)
				h = floors * FH
				for i = 1, 6 do
					local t = (i - 1) / 6
					V(h * (i - 1) / 6, h * i / 6, w * (1 - t * 0.7), d * (1 - t * 0.7), 0, 0, 0, false, i == 6)
				end
			elseif arch == "ell" then
				-- dues ales en angle recte
				local ad = d * 0.55
				V(0, h, w, ad, 0, d / 2 - ad / 2)
				local bw = w * 0.42
				V(0, h * (0.55 + math.random() * 0.35), bw, d, -w / 2 + bw / 2)
			elseif arch == "tee" then
				-- podi ample i torre estreta que el travessa
				local pf = math.max(2, math.floor(floors * 0.3))
				V(0, pf * FH, w, d)
				V(0, h, w * 0.44, d * 0.62)
			elseif arch == "twin" then
				local tw2 = w * 0.4
				local off = w * 0.28
				V(0, h, tw2, d * 0.8, -off)
				V(0, h * (0.8 + math.random() * 0.2), tw2, d * 0.8, off)
				V(h * 0.55, h * 0.68, off * 2, d * 0.45, 0, 0, 0, false, false) -- pont
			elseif arch == "corebox" then
				local bf = math.max(3, math.floor(floors * 0.5))
				V(0, bf * FH, w, d)
				V(0, h, w * 0.4, d * 0.5)
			elseif arch == "twistcrown" then
				local yc = h * 0.68
				V(0, yc, w, d)
				local s2 = math.min(w, d) * 0.62
				V(yc, h, s2, s2, 0, 0, 45)
			elseif arch == "cantilever" then
				local yc = h * 0.55
				V(0, yc, w * 0.68, d)
				V(yc, h, w, d * 0.82, 0, d * 0.14)
			elseif arch == "jenga" then
				floors = math.max(6, floors)
				h = floors * FH
				for i = 1, 5 do
					V(
						h * (i - 1) / 5,
						h * i / 5,
						w * 0.8,
						d * 0.8,
						((i % 2 == 0) and 1 or -1) * w * 0.09,
						((i % 3 == 0) and d * 0.08 or 0),
						0,
						false,
						i == 5
					)
				end
			elseif arch == "archbase" then
				-- cos aixecat sobre dues potes: passatge a la planta baixa
				floors = math.max(5, floors)
				h = floors * FH
				local lw = w * 0.22
				V(0, 2 * FH, lw, d, -w / 2 + lw / 2, 0, 0, false, false)
				V(0, 2 * FH, lw, d, w / 2 - lw / 2, 0, 0, false, false)
				V(2 * FH, h, w, d)
			elseif arch == "parking" then
				floors = math.max(3, math.min(6, floors))
				h = floors * FH
			else -- prism
				V(0, h, w, d)
			end

			-- ═══ 4. ENVOLUPANT ═══
			local function envelope(v)
				local function slabAt(name, a, b, sw, sd, color)
					if v.round then
						VCyl({
							Name = name,
							Size = Vector3.new(b - a, sw, sd),
							CFrame = v.cf * CFrame.new(0, (a + b) / 2, 0),
							Color = color,
							Material = SMOOTH,
						}, m)
					else
						B(name, Vector3.new(sw, b - a, sd), v.cf * CFrame.new(0, (a + b) / 2, 0), color, SMOOTH)
					end
				end
				-- als trams mes prims de les agulles el nucli es quedaria en
				-- res; el topem perque no surtin peces degenerades
				slabAt("Core", v.y0, v.y1, math.max(0.4, v.w - INS * 2), math.max(0.4, v.d - INS * 2), core)

				local bh = FH * whiteFrac
				local f0 = math.floor(v.y0 / FH + 0.5)
				local f1 = math.floor(v.y1 / FH + 0.5)
				for f = f0, f1 do
					local y = f * FH
					local a = math.max(y - bh / 2, v.y0)
					local b = math.min(y + bh / 2, v.y1)
					if f == f0 then
						a = v.y0
					end
					if f == f1 then
						b = v.y1
					end
					if b - a > 0.15 then
						slabAt("Band", a, b, v.w, v.d, band)
					end
				end
				if v.round then
					return
				end

				-- Muntants verticals: enrasats amb les franges pero 0.06
				-- studs per davant, perque cap cara comparteixi pla.
				local yc, hh = (v.y0 + v.y1) / 2, v.y1 - v.y0
				local function mulRow(n, half, onZ, sgn)
					for c = 0, n do
						local t = math.clamp(-half + (half * 2 / n) * c, -half + 0.2 * S, half - 0.2 * S)
						if onZ then
							B(
								"Mullion",
								Vector3.new(0.32 * S, hh, INS * 2),
								v.cf * CFrame.new(t, yc, sgn * (v.d / 2 - INS + 0.06)),
								band,
								SMOOTH,
								NC
							)
						else
							B(
								"Mullion",
								Vector3.new(INS * 2, hh, 0.32 * S),
								v.cf * CFrame.new(sgn * (v.w / 2 - INS + 0.06), yc, t),
								band,
								SMOOTH,
								NC
							)
						end
					end
				end
				local nx = math.max(2, math.floor(v.w / mSpan + 0.5))
				local nz = math.max(2, math.floor(v.d / mSpan + 0.5))
				mulRow(nx, v.w / 2, true, 1)
				mulRow(nx, v.w / 2, true, -1)
				mulRow(nz, v.d / 2, false, 1)
				mulRow(nz, v.d / 2, false, -1)
			end

			-- ═══ 5. CORONAMENT ═══
			local function crown(v)
				if v.round then
					VCyl({
						Name = "Parapet",
						Size = Vector3.new(1.1 * S, v.w, v.d),
						CFrame = v.cf * CFrame.new(0, v.y1 + 0.55 * S, 0),
						Color = band,
						Material = SMOOTH,
					}, m)
					VCyl({
						Name = "RoofDeck",
						Size = Vector3.new(0.3 * S, v.w - 1.2 * S, v.d - 1.2 * S),
						CFrame = v.cf * CFrame.new(0, v.y1 + 1.25 * S, 0),
						Color = roofC,
						Material = SMOOTH,
					}, m)
					return
				end
				B(
					"RoofDeck",
					Vector3.new(v.w - 0.3 * S, 0.5 * S, v.d - 0.3 * S),
					v.cf * CFrame.new(0, v.y1 + 0.25 * S, 0),
					roofC,
					SMOOTH
				)
				for _, sd in ipairs({
					{ 0, v.d / 2 - 0.22 * S, v.w, 0.44 * S },
					{ 0, -(v.d / 2 - 0.22 * S), v.w, 0.44 * S },
					{ v.w / 2 - 0.22 * S, 0, 0.44 * S, v.d },
					{ -(v.w / 2 - 0.22 * S), 0, 0.44 * S, v.d },
				}) do
					B(
						"Parapet",
						Vector3.new(sd[3], 1.15 * S, sd[4]),
						v.cf * CFrame.new(sd[1], v.y1 + 0.57 * S, sd[2]),
						band,
						SMOOTH
					)
				end
			end

			-- ═══ 6. MUNTATGE ═══
			if arch == "parking" then
				-- aparcament obert: nomes forjats, ampits i pilars. Es veu
				-- a traves, i aixo el fa inconfusible entre tants prismes.
				for f = 0, floors do
					B("Deck", Vector3.new(w, 0.7 * S, d), baseCF * CFrame.new(0, f * FH, 0), band, SMOOTH)
					if f < floors then
						B(
							"DeckRail",
							Vector3.new(w + 0.25 * S, 0.55 * S, 0.35 * S),
							baseCF * CFrame.new(0, f * FH + 1.3 * S, d / 2 - 0.1 * S),
							core,
							SMOOTH,
							NC
						)
					end
				end
				for _, sx in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						B(
							"DeckCol",
							Vector3.new(1.1 * S, h, 1.1 * S),
							baseCF * CFrame.new(sx * (w / 2 - 0.75 * S), h / 2, sz * (d / 2 - 0.75 * S)),
							band,
							SMOOTH
						)
					end
				end
				B(
					"StairCore",
					Vector3.new(w * 0.24, h + 2.4 * S, d * 0.34),
					baseCF * CFrame.new(-w * 0.32, (h + 2.4 * S) / 2, -d * 0.28),
					core,
					SMOOTH
				)
			else
				for _, v in ipairs(vols) do
					envelope(v)
					if v.cap then
						crown(v)
					end
				end
			end

			-- Socol. Ha de seguir la planta REAL de cada volum que toca
			-- terra, no un rectangle generic: amb un de generic, sota les
			-- torres rodones hi quedava una llosa quadrada, sota les girades
			-- una de tort, i sota les bessones una que sobresortia pels dos
			-- costats. Era el que feia mes lleig de tot.
			if arch == "parking" then
				B(
					"Plinth",
					Vector3.new(w + 0.3 * S, 0.6 * S, d + 0.3 * S),
					baseCF * CFrame.new(0, 0.2 * S, 0),
					plinthC,
					SMOOTH
				)
			else
				for _, v in ipairs(vols) do
					if v.y0 < 0.01 then
						if v.round then
							VCyl({
								Name = "Plinth",
								Size = Vector3.new(0.6 * S, v.w + 0.3 * S, v.d + 0.3 * S),
								CFrame = v.cf * CFrame.new(0, 0.2 * S, 0),
								Color = plinthC,
								Material = SMOOTH,
							}, m)
						else
							B(
								"Plinth",
								Vector3.new(v.w + 0.3 * S, 0.6 * S, v.d + 0.3 * S),
								v.cf * CFrame.new(0, 0.2 * S, 0),
								plinthC,
								SMOOTH
							)
						end
					end
				end
			end

			-- ═══ 7. COBERTA ═══
			local hTop, wTop, dTop = h, w, d
			if #vols > 0 then
				local t = vols[#vols]
				hTop, wTop, dTop = t.y1, t.w, t.d
			end
			if arch == "spire" or arch == "pyramid" then
				VCyl({
					Name = "Mast",
					Size = Vector3.new(7 * S, 0.24 * S, 0.24 * S),
					CFrame = baseCF * CFrame.new(0, hTop + 3.5 * S, 0),
					Color = band,
					Material = SMOOTH,
					CastShadow = false,
				}, m)
				B("MastLight", Vector3.new(0.45 * S, 0.45 * S, 0.45 * S), baseCF * CFrame.new(0, hTop + 7.2 * S, 0), Color3.fromRGB(255, 78, 68), Enum.Material.Neon, {
					Shape = Enum.PartType.Ball,
					CanCollide = false,
					CastShadow = false,
				})
			elseif arch ~= "parking" then
				if floors >= 6 and math.random() < 0.55 then
					local bw = math.min(wTop * 0.32, 7 * S)
					B(
						"RoofBox",
						Vector3.new(bw, 2.8 * S, bw * 0.85),
						baseCF * CFrame.new(wTop * 0.15, hTop + 1.4 * S, -dTop * 0.15),
						band,
						SMOOTH
					)
				end
				if math.random() < 0.45 then
					for k = 0, 1 do
						B(
							"RoofUnit",
							Vector3.new(2.1 * S, 1.2 * S, 1.7 * S),
							baseCF * CFrame.new(-wTop * 0.22 + k * 3.0 * S, hTop + 0.95 * S, dTop * 0.12),
							Color3.fromRGB(138, 140, 142),
							SMOOTH,
							{ CastShadow = false }
						)
					end
				end
				if floors >= 11 and math.random() < 0.55 then
					local ax, az = wTop * 0.12, -dTop * 0.12
					VCyl({
						Name = "Mast",
						Size = Vector3.new(6.5 * S, 0.22 * S, 0.22 * S),
						CFrame = baseCF * CFrame.new(ax, hTop + 3.5 * S, az),
						Color = Color3.fromRGB(150, 152, 154),
						Material = SMOOTH,
						CastShadow = false,
					}, m)
					B("MastLight", Vector3.new(0.45 * S, 0.45 * S, 0.45 * S), baseCF * CFrame.new(ax, hTop + 6.9 * S, az), Color3.fromRGB(255, 78, 68), Enum.Material.Neon, {
						Shape = Enum.PartType.Ball,
						CanCollide = false,
						CastShadow = false,
					})
				end
			end

			cityParts += #m:GetChildren()
			cityCount += 1
			m.Parent = city
			return m
		end

		-- Omple una vora d'illa amb edificis de mida variable, mirant al carrer.
		-- La façana de buildCityBuilding surt pel +Z local, per aixo cada
		-- costat porta el seu gir: N=180, S=0, W=270, E=90.
		local function fillEdge(side, b, depth, cfg, gapHalf)
			local from, to, fixed, rot
			if side == "N" then
				from, to, fixed, rot = b.x0, b.x1, b.z0 + depth / 2, 180
			elseif side == "S" then
				from, to, fixed, rot = b.x0, b.x1, b.z1 - depth / 2, 0
			elseif side == "W" then
				from, to, fixed, rot = b.z0 + depth, b.z1 - depth, b.x0 + depth / 2, 270
			else
				from, to, fixed, rot = b.z0 + depth, b.z1 - depth, b.x1 - depth / 2, 90
			end

			local minW = cfg.wMin * S
			local function run(a, z)
				local pos = a
				while z - pos > minW do
					local w = math.min((cfg.wMin + math.random() * (cfg.wMax - cfg.wMin)) * S, z - pos)
					if w < minW then
						break
					end
					local c = pos + w / 2
					local dd = depth - (1.5 + math.random() * 2) * S
					local floors = math.random(b.fMin, b.fMax)
					local cf
					if side == "N" or side == "S" then
						cf = C * CFrame.new(c, G, fixed) * CFrame.Angles(0, math.rad(rot), 0)
					else
						cf = C * CFrame.new(fixed, G, c) * CFrame.Angles(0, math.rad(rot), 0)
					end
					buildCityBuilding(cf, w, dd, floors, cfg.hi)
					pos = pos + w + (0.5 + math.random() * 1) * S
				end
			end

			-- Amb gapHalf s'obre un pas al mig del costat: es per on s'entra
			-- al pati interior, on hi ha els museus.
			if gapHalf and gapHalf > 0 then
				local mid = (from + to) / 2
				run(from, mid - gapHalf)
				run(mid + gapHalf, to)
			else
				run(from, to)
			end
		end

		for _, b in ipairs(BLOCKS) do
			local narrow = (b.x1 - b.x0) < 60
			local depth = narrow and 18 or 28
			local cfg = { wMin = 11, wMax = 22, hi = not narrow }
			for _, side in ipairs(b.sides) do
				fillEdge(side, b, depth, cfg, (side == "S" and not narrow) and 11 or 0)
			end
		end

		-- ── ANELL EXTERIOR: pisos que tanquen la ciutat ──
		-- Fora de la carretera de ronda no hi havia res i es veia el buit.
		-- Aixo hi posa una filera continua d'edificis mirant cap endins pel
		-- nord, l'oest i el sud (l'est ja el tanca el mar). Es el mateix
		-- conveni que fillEdge: N/S agafen les cantonades, l'oest queda
		-- encaixat entre les dues.
		do
			local RING_GAP = 12 -- de la vora del terra fins a la vorera de l'anell
			local RING_DEPTH = 24 -- fondaria dels blocs de l'anell
			local RING_BACK = 10 -- marge de terra darrere els edificis
			local SPAN = RING_GAP + RING_DEPTH + RING_BACK
			local WLK = 5 -- amplada de la vorera davant dels pisos

			-- terra d'asfalt de l'anell (mateixa cota que CityGround)
			local function apron(name, cx, cz, sx, sz)
				P({
					Name = "RingGround_" .. name,
					Size = Vector3.new(sx, 4, sz),
					CFrame = C * CFrame.new(cx, G - 2, cz),
					Color = ASPHALT,
					Material = Enum.Material.SmoothPlastic,
				}, city)
			end
			apron("W", LAND_W - SPAN / 2, 0, SPAN, (LAND_S - LAND_N) + SPAN * 2)
			apron("N", (LAND_W + LAND_E) / 2, LAND_N - SPAN / 2, (LAND_E - LAND_W) + SPAN, SPAN)
			apron("S", (LAND_W + LAND_E) / 2, LAND_S + SPAN / 2, (LAND_E - LAND_W) + SPAN, SPAN)

			-- vorera aixecada davant de la filera
			local function walk(name, cx, cz, sx, sz)
				P({
					Name = "RingSidewalk_" .. name,
					Size = Vector3.new(sx, 0.5, sz),
					CFrame = C * CFrame.new(cx, G + 0.25, cz),
					Color = PAVE_B,
					Material = Enum.Material.SmoothPlastic,
					CastShadow = false,
				}, city)
			end
			walk("W", LAND_W - RING_GAP - WLK / 2, 0, WLK, LAND_S - LAND_N)
			walk("N", (LAND_W + LAND_E) / 2, LAND_N - RING_GAP - WLK / 2, (LAND_E - LAND_W) + (RING_GAP + WLK) * 2, WLK)
			walk("S", (LAND_W + LAND_E) / 2, LAND_S + RING_GAP + WLK / 2, (LAND_E - LAND_W) + (RING_GAP + WLK) * 2, WLK)

			-- filera d'edificis. La façana de buildCityBuilding surt pel +Z
			-- local, per aixo cada costat porta el seu gir cap endins.
			local rMin, rMax = 14 * S, 24 * S
			local function ringRun(from, to, coord, rot, horizontal)
				local pos = from
				while to - pos > rMin do
					local w = math.min(rMin + math.random() * (rMax - rMin), to - pos)
					if w < rMin then
						break
					end
					local c = pos + w / 2
					local dd = RING_DEPTH - (1 + math.random() * 2) * S
					local floors = math.random(3, 6)
					local cf
					if horizontal then
						cf = C * CFrame.new(c, G, coord) * CFrame.Angles(0, math.rad(rot), 0)
					else
						cf = C * CFrame.new(coord, G, c) * CFrame.Angles(0, math.rad(rot), 0)
					end
					buildCityBuilding(cf, w, dd, floors, false)
					pos = pos + w + (0.5 + math.random() * 1.5) * S
				end
			end

			-- Nord: façana mira +Z (cap al sud, cap a la ciutat) => rot 0
			ringRun(LAND_W - SPAN, LAND_E + SPAN, LAND_N - RING_GAP - RING_DEPTH / 2, 0, true)
			-- Sud: façana mira -Z => rot 180
			ringRun(LAND_W - SPAN, LAND_E + SPAN, LAND_S + RING_GAP + RING_DEPTH / 2, 180, true)
			-- Oest: façana mira +X => rot 90, encaixat entre nord i sud
			ringRun(LAND_N, LAND_S, LAND_W - RING_GAP - RING_DEPTH / 2, 90, false)
		end

		-- ── MOBILIARI: fanals als carrers i arbres a la placa ──
		-- Fanal de carretera modern (pal + brac + llumenera plana), no el
		-- globus sobre pal que feia placa de poble. El tercer valor es cap
		-- on mira el brac: sempre cap a la calçada.
		-- Van sobre la VORERA (les voreres arriben a ±27 al carrer central,
		-- a -107/-53 a l'avinguda i a 85/99 al carrer de l'illa llarga);
		-- abans queien enmig de la calçada.
		local lampSpots = {}
		for x = LAND_W + 20, LAND_E - 20, 46 do
			table.insert(lampSpots, { x, -25, 0 })
			table.insert(lampSpots, { x, 25, 180 })
		end
		for z = LAND_N + 24, LAND_S - 24, 46 do
			table.insert(lampSpots, { -104, z, 90 })
			table.insert(lampSpots, { -56, z, 270 })
			table.insert(lampSpots, { 87, z, 90 })
		end
		local POLE_C = Color3.fromRGB(88, 92, 98)
		for _, sp in ipairs(lampSpots) do
			local ph = 9.5 * S
			local base = C * CFrame.new(sp[1], G, sp[2]) * CFrame.Angles(0, math.rad(sp[3]), 0)
			P({
				Name = "LampPost",
				Size = Vector3.new(0.42 * S, ph, 0.42 * S),
				CFrame = base * CFrame.new(0, ph / 2, 0),
				Color = POLE_C,
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			}, city)
			P({
				Name = "LampArm",
				Size = Vector3.new(0.3 * S, 0.3 * S, 2.8 * S),
				CFrame = base * CFrame.new(0, ph - 0.15 * S, 1.4 * S),
				Color = POLE_C,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CastShadow = false,
			}, city)
			P({
				Name = "LampShell",
				Size = Vector3.new(0.95 * S, 0.38 * S, 2.3 * S),
				CFrame = base * CFrame.new(0, ph - 0.48 * S, 2.4 * S),
				Color = Color3.fromRGB(114, 118, 124),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CastShadow = false,
			}, city)
			local head = P({
				Name = "LampHead",
				Size = Vector3.new(0.75 * S, 0.14 * S, 2.0 * S),
				CFrame = base * CFrame.new(0, ph - 0.72 * S, 2.4 * S),
				Color = Color3.fromRGB(255, 251, 238),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CastShadow = false,
			}, city)
			New("PointLight", { Brightness = 1.5, Range = 30, Color = Color3.fromRGB(242, 246, 255) }, head)
		end

		-- ── MARQUES VIALS ──
		-- Ratlla discontinua al mig de cada calçada i passos de zebra a la
		-- placa. Es barat i es el que acaba de dir "ciutat d'ara".
		do
			local function dashes(a, b, fixed, alongX)
				local L, gap = 5.0, 4.5
				local pos = a
				while pos < b do
					local len = math.min(L, b - pos)
					P({
						Name = "RoadDash",
						Size = alongX and Vector3.new(len, 0.12, 0.75) or Vector3.new(0.75, 0.12, len),
						CFrame = alongX and C * CFrame.new(pos + len / 2, G + 0.06, fixed)
							or C * CFrame.new(fixed, G + 0.06, pos + len / 2),
						Color = LINE,
						Material = Enum.Material.SmoothPlastic,
						CanCollide = false,
						CastShadow = false,
					}, city)
					pos = pos + L + gap
				end
			end
			local function crosswalk(cx, cz, span, roadAlongZ)
				for k = 0, 6 do
					local off = -span / 2 + span * (k + 0.5) / 7
					P({
						Name = "Crosswalk",
						Size = roadAlongZ and Vector3.new(1.7, 0.12, 7.5) or Vector3.new(7.5, 0.12, 1.7),
						CFrame = roadAlongZ and C * CFrame.new(cx + off, G + 0.06, cz)
							or C * CFrame.new(cx, G + 0.06, cz + off),
						Color = LINE,
						Material = Enum.Material.SmoothPlastic,
						CanCollide = false,
						CastShadow = false,
					}, city)
				end
			end
			dashes(LAND_W + 6, -118, 0, true) -- carrer central, tram oest
			dashes(-42, LAND_E - 6, 0, true) -- tram est (la placa queda al mig)
			dashes(LAND_N + 6, -36, -80, false) -- avinguda, tram nord
			dashes(36, LAND_S - 6, -80, false) -- avinguda, tram sud
			dashes(LAND_N + 6, LAND_S - 6, 92, false) -- carrer de l'illa llarga
			dashes(LAND_N - 40, LAND_S + 40, LAND_W + 2, false) -- ronda oest
			dashes(LAND_W - 40, LAND_E + 6, LAND_N - 1, true) -- ronda nord
			dashes(LAND_W - 40, LAND_E + 6, LAND_S + 1, true) -- ronda sud
			crosswalk(-80, -36, 52, true)
			crosswalk(-80, 36, 52, true)
			crosswalk(-118, 0, 52, false)
			crosswalk(-42, 0, 52, false)
		end

		-- ── ARBRAT DE CARRER ──
		-- Als referents els carrers van plens d'arbres; sense aixo la ciutat
		-- queda seca. Van a la mateixa linia que els fanals pero desplaçats
		-- mitja separacio, o sigui que s'alternen: fanal, arbre, fanal.
		local treeSpots = { { -100, 0 }, { -60, 0 } }
		for x = LAND_W + 43, LAND_E - 20, 46 do
			table.insert(treeSpots, { x, -25 })
			table.insert(treeSpots, { x, 25 })
		end
		for z = LAND_N + 47, LAND_S - 24, 46 do
			table.insert(treeSpots, { -104, z })
			table.insert(treeSpots, { -56, z })
			table.insert(treeSpots, { 87, z })
		end
		local LEAF = Color3.fromRGB(78, 120, 84)
		local TRUNK = Color3.fromRGB(124, 102, 78)
		for _, tp in ipairs(treeSpots) do
			P({
				Name = "TreePit",
				Size = Vector3.new(3.4, 0.3, 3.4),
				CFrame = C * CFrame.new(tp[1], G + 0.5, tp[2]),
				Color = Color3.fromRGB(96, 90, 78),
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			}, city)
			VCyl({
				Name = "TreeTrunk",
				Size = Vector3.new(6.5 * S, 0.85 * S, 0.85 * S),
				CFrame = C * CFrame.new(tp[1], G + 3.25 * S, tp[2]),
				Color = TRUNK,
				Material = Enum.Material.SmoothPlastic,
			}, city)
			P({
				Name = "TreeCrown",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(6.4 * S, 5.6 * S, 6.4 * S),
				CFrame = C * CFrame.new(tp[1], G + 7.6 * S, tp[2]),
				Color = LEAF,
				Material = Enum.Material.Grass,
				CanCollide = false,
				CastShadow = false,
			}, city)
			P({
				Name = "TreeCrownTop",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(4.5 * S, 3.9 * S, 4.5 * S),
				CFrame = C * CFrame.new(tp[1] + 0.9 * S, G + 9.7 * S, tp[2] - 0.7 * S),
				Color = LEAF:Lerp(Color3.new(1, 1, 1), 0.14),
				Material = Enum.Material.Grass,
				CanCollide = false,
				CastShadow = false,
			}, city)
		end

		-- ── PLATJA I MAR (tota la vora est) ──
		do
			P({
				Name = "Promenade",
				Size = Vector3.new(PROM_E - LAND_E, 0.6, LAND_S - LAND_N),
				CFrame = C * CFrame.new((LAND_E + PROM_E) / 2, G + 0.3, 0),
				Color = PAVE_A,
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			}, city)
			P({
				Name = "BeachSand",
				Size = Vector3.new(SAND_E - PROM_E, 4, LAND_S - LAND_N),
				CFrame = C * CFrame.new((PROM_E + SAND_E) / 2, G - 2, 0),
				Color = SAND,
				Material = Enum.Material.Sand,
			}, city)
			P({
				Name = "WetSand",
				Size = Vector3.new(16, 0.4, LAND_S - LAND_N),
				CFrame = C * CFrame.new(SAND_E - 8, G + 0.2, 0),
				Color = WET_SAND,
				Material = Enum.Material.Sand,
				CastShadow = false,
			}, city)
			P({
				Name = "SeaBed",
				Size = Vector3.new(SEA_E - SAND_E, 4, LAND_S - LAND_N + 60),
				CFrame = C * CFrame.new((SAND_E + SEA_E) / 2, G - 3, 0),
				Color = WET_SAND,
				Material = Enum.Material.Sand,
			}, city)
			P({
				Name = "Sea",
				Size = Vector3.new(SEA_E - SAND_E, 3, LAND_S - LAND_N + 60),
				CFrame = C * CFrame.new((SAND_E + SEA_E) / 2, G - 0.6, 0),
				Color = WATER,
				Material = Enum.Material.Glass,
				Transparency = 0.35,
				CanCollide = false,
			}, city)
			for z = LAND_N + 10, LAND_S - 10, 14 do
				VCyl({
					Name = "PromRailPost",
					Size = Vector3.new(3 * S, 0.35 * S, 0.35 * S),
					CFrame = C * CFrame.new(LAND_E + 1.5, G + 1.5 * S, z),
					Color = BONE,
					Material = Enum.Material.SmoothPlastic,
					CastShadow = false,
				}, city)
			end

			-- Punts d'excavacio de la platja, a escala de jugador: son
			-- gameplay, no decorat, i el jugador hi ha de poder cavar.
			local digIdx = 0
			for _, bx in ipairs({ 0.22, 0.45, 0.68, 0.88 }) do
				for k = -8, 8 do
					digIdx += 1
					local radius = 3.5 + math.random() * 1.5
					local px = PROM_E + (SAND_E - PROM_E) * bx + (math.random() - 0.5) * 12
					local pz = k * 21 + (math.random() - 0.5) * 12
					-- Els dos museus de la platja hi son primer: no s'hi posa sorra a sobre.
					local blocked = false
					for _, mz in ipairs({ -120, 120 }) do
						if math.abs(px - 200) < 26 and math.abs(pz - mz) < 28 then
							blocked = true
						end
					end
					if blocked then
						continue
					end
					local mound = P({
						Name = "BeachDig" .. digIdx,
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(radius * 2, radius, radius * 2),
						CFrame = C * CFrame.new(px, G + radius / 4, pz)
							* CFrame.Angles(0, math.rad(math.random(0, 359)), 0),
						Color = WET_SAND,
						Material = Enum.Material.Sand,
					}, city)
					CollectionService:AddTag(mound, "DigSpot")
				end
			end
		end

		-- ── L'OBRA VA DINS DE LA ILLA DE DALT A L'ESQUERRA ──
		-- Es construeix a l'origen amb les seves coordenades i aqui es mou
		-- sencera: es un Model ancorat, o sigui que PivotTo ho mou tot de cop.
		local OBRA_X, OBRA_Z = -170, -100
		zone:PivotTo(zone:GetPivot() + Vector3.new(C.X + OBRA_X, 0, C.Z + OBRA_Z))
		-- Tanca d'obra al voltant del solar, oberta cap al carrer del sud
		for _, sd in ipairs({ { 0, -42, 84, 1 }, { -42, 0, 1, 84 }, { 42, 0, 1, 84 } }) do
			P({
				Name = "SiteHoarding",
				Size = Vector3.new(sd[3] == 1 and 0.8 or sd[3], 4 * S, sd[4] == 1 and 0.8 or sd[4]),
				CFrame = C * CFrame.new(OBRA_X + sd[1], G + 2 * S, OBRA_Z + sd[2]),
				Color = Color3.fromRGB(198, 176, 148),
				Material = Enum.Material.WoodPlanks,
			}, city)
		end

		-- ── SPAWN ──
		-- A la placa central: sense aixo el jugador apareix a l'origen del
		-- mon, que ara ja no te terra a sota.
		-- Porta cap al museu del jugador, al costat de l'spawn
		do
			local pad = P({
				Name = "MuseumDoor",
				Size = Vector3.new(7, 0.6, 7),
				CFrame = C * CFrame.new(-95, G + 0.6, 12),
				Color = Color3.fromRGB(192, 138, 62),
				Material = Enum.Material.Marble,
			}, city)
			P({
				Name = "MuseumDoorArch",
				Size = Vector3.new(7, 9, 0.8),
				CFrame = C * CFrame.new(-95, G + 5, 15.5),
				Color = BONE,
				Material = Enum.Material.Marble,
			}, city)
			New("ProximityPrompt", {
				Name = "GoMuseum",
				ActionText = "Anar al teu museu",
				ObjectText = "Museu",
				HoldDuration = 0.3,
				MaxActivationDistance = 10,
			}, pad)
			CollectionService:AddTag(pad, "ToMuseum")
		end

		New("SpawnLocation", {
			Name = "CitySpawn",
			Anchored = true,
			Size = Vector3.new(8, 1, 8),
			CFrame = C * CFrame.new(-80, G + 0.9, 12),
			Color = BONE,
			Material = Enum.Material.Marble,
			Duration = 0,
			Neutral = true,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
		}, city)

		print(("[Museu] ciutat: %d edificis, %d peces d'edifici"):format(cityCount, cityParts))
		city.Parent = zones
	end

	-- ═══════════════════════════════════════════════════════════════════════
	-- OSSOS: peces d'esquelet (colom, gos, gat, rata)
	-- ═══════════════════════════════════════════════════════════════════════
	-- Cada esquelet es parteix en 5 peces de raresa desigual (3 comunes,
	-- 1 rara, 1 epica). Aixo es el que fa que el comerc tingui sentit:
	-- tothom acumula comunes i a tothom li falta el crani.
	-- Fets amb parts basiques, que es el pla B del CLAUDE.md: des d'aqui no
	-- puc generar malles amb Cube 3D.
	do
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local prev = ReplicatedStorage:FindFirstChild("Bones")
		if prev then
			prev:Destroy()
		end
		local bonesRoot = New("Folder", { Name = "Bones" }, ReplicatedStorage)

		local BONE_COL = Color3.fromRGB(237, 227, 204) -- #EDE3CC
		local SOCKET = Color3.fromRGB(52, 46, 40)

		-- ── CONFIG PRIMER ──
		local PIECES = {
			{ id = "Skull", rarity = "Epic" },
			{ id = "Spine", rarity = "Common" },
			{ id = "ForeLimbs", rarity = "Common" },
			{ id = "HindLimbs", rarity = "Common" },
			{ id = "Tail", rarity = "Rare" },
		}
		local MAMMAL_NAMES = {
			Skull = "Crani",
			Spine = "Columna i costelles",
			ForeLimbs = "Potes davanteres",
			HindLimbs = "Potes posteriors",
			Tail = "Cua",
		}
		local BIRD_NAMES = {
			Skull = "Crani i bec",
			Spine = "Columna i estern",
			ForeLimbs = "Ales",
			HindLimbs = "Potes",
			Tail = "Pigostil",
		}
		local SKELETONS = {
			{ id = "Pigeon", name = "Colom", kind = "bird", s = 0.7, display = 2.2 },
			{ id = "Rat", name = "Rata", kind = "mammal", s = 0.5, snout = 0.9, ribs = 5, display = 2.6 },
			{ id = "Cat", name = "Gat", kind = "mammal", s = 1, snout = 0.45, ribs = 6, display = 1.5 },
			{ id = "Dog", name = "Gos", kind = "mammal", s = 1.5, snout = 0.9, ribs = 7, display = 1.1 },
		}

		-- ── HELPERS D'OS ──
		-- Conveni: +Z es el davant (cap), -Z el darrere (cua), +Y amunt.
		local function B(props, parent)
			props.Color = props.Color or BONE_COL
			props.Material = props.Material or Enum.Material.Marble
			props.CanCollide = false
			props.CastShadow = false
			return P(props, parent)
		end
		-- Diafisi entre dos punts: el cilindre te l'eix a la X local, per aixo
		-- el CFrame de lookAt (que mira per -Z) es gira 90 graus.
		local function shaft(parent, p1, p2, thick)
			local d = (p2 - p1).Magnitude
			if d < 0.02 then
				return
			end
			return B({
				Name = "Shaft",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(d, thick, thick),
				CFrame = CFrame.new((p1 + p2) / 2, p2) * CFrame.Angles(0, math.rad(90), 0),
			}, parent)
		end
		local function knob(parent, p, r)
			return B({
				Name = "Knob",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(r, r, r),
				CFrame = CFrame.new(p),
			}, parent)
		end
		local function chain(parent, pts, thick, knobR)
			for i = 1, #pts - 1 do
				shaft(parent, pts[i], pts[i + 1], thick)
			end
			for _, p in ipairs(pts) do
				knob(parent, p, knobR)
			end
		end
		local function V(x, y, z)
			return Vector3.new(x, y, z)
		end

		-- ── MAMIFER ──
		local mammal = {}

		function mammal.Skull(sk)
			local s = sk.s
			local m = Instance.new("Model")
			local snout = (0.55 + sk.snout) * s
			B({
				Name = "Cranium",
				Shape = Enum.PartType.Ball,
				Size = V(0.82 * s, 0.74 * s, 0.95 * s),
				CFrame = CFrame.new(0, 0, 0),
			}, m)
			B({
				Name = "Snout",
				Size = V(0.4 * s, 0.32 * s, snout),
				CFrame = CFrame.new(0, -0.05 * s, 0.42 * s + snout / 2),
			}, m)
			B({
				Name = "Jaw",
				Size = V(0.34 * s, 0.15 * s, snout * 0.96),
				CFrame = CFrame.new(0, -0.27 * s, 0.42 * s + snout / 2),
			}, m)
			B({
				Name = "Occiput",
				Size = V(0.5 * s, 0.42 * s, 0.18 * s),
				CFrame = CFrame.new(0, -0.05 * s, -0.45 * s),
			}, m)
			for _, sgn in ipairs({ -1, 1 }) do
				B({
					Name = "EyeSocket",
					Shape = Enum.PartType.Ball,
					Color = SOCKET,
					Size = V(0.28 * s, 0.28 * s, 0.28 * s),
					CFrame = CFrame.new(sgn * 0.29 * s, 0.07 * s, 0.36 * s),
				}, m)
				B({
					Name = "Zygomatic",
					Size = V(0.07 * s, 0.09 * s, 0.5 * s),
					CFrame = CFrame.new(sgn * 0.36 * s, -0.08 * s, 0.22 * s),
				}, m)
				for i = 0, 3 do
					B({
						Name = "Tooth",
						Size = V(0.05 * s, (i == 0 and 0.16 or 0.1) * s, 0.05 * s),
						CFrame = CFrame.new(sgn * 0.12 * s, -0.2 * s, 0.5 * s + i * snout * 0.22),
					}, m)
				end
			end
			return m
		end

		function mammal.Spine(sk)
			local s, n = sk.s, sk.ribs
			local m = Instance.new("Model")
			local len = 2.6 * s
			local pts = {}
			for i = 0, 10 do
				local t = i / 10
				table.insert(pts, V(0, math.sin(t * math.pi) * 0.1 * s, -len / 2 + len * t))
			end
			chain(m, pts, 0.1 * s, 0.17 * s)
			for i = 2, 9 do
				B({
					Name = "SpinousProcess",
					Size = V(0.05 * s, 0.22 * s, 0.06 * s),
					CFrame = CFrame.new(pts[i] + V(0, 0.17 * s, 0)),
				}, m)
			end
			-- Costelles: quart d'el.lipse des de la columna cap avall i enfora.
			local r = 0.6 * s
			for i = 1, n do
				local z = -len * 0.3 + (len * 0.6) * ((i - 1) / math.max(1, n - 1))
				for _, sgn in ipairs({ -1, 1 }) do
					local rp = {}
					for k = 0, 4 do
						local a = math.rad(90 * k / 4)
						table.insert(rp, V(sgn * r * math.sin(a), -r * (1 - math.cos(a)), z))
					end
					for k = 1, #rp - 1 do
						shaft(m, rp[k], rp[k + 1], 0.055 * s)
					end
				end
			end
			return m
		end

		function mammal.ForeLimbs(sk)
			local s = sk.s
			local m = Instance.new("Model")
			for _, sgn in ipairs({ -1, 1 }) do
				local shoulder = V(sgn * 0.34 * s, 0, 0)
				local elbow = V(sgn * 0.44 * s, -0.72 * s, 0.14 * s)
				local wrist = V(sgn * 0.4 * s, -1.38 * s, -0.04 * s)
				local paw = V(sgn * 0.4 * s, -1.56 * s, 0.14 * s)
				B({
					Name = "Scapula",
					Size = V(0.08 * s, 0.6 * s, 0.36 * s),
					CFrame = CFrame.new(shoulder + V(0, 0.34 * s, -0.04 * s)) * CFrame.Angles(0, 0, math.rad(sgn * 12)),
				}, m)
				chain(m, { shoulder, elbow, wrist }, 0.11 * s, 0.16 * s)
				shaft(m, wrist, paw, 0.09 * s)
				for t = -1, 1 do
					shaft(m, paw, paw + V(t * 0.09 * s, -0.1 * s, 0.17 * s), 0.045 * s)
				end
			end
			return m
		end

		function mammal.HindLimbs(sk)
			local s = sk.s
			local m = Instance.new("Model")
			B({
				Name = "Pelvis",
				Size = V(0.75 * s, 0.3 * s, 0.5 * s),
				CFrame = CFrame.new(0, 0.05 * s, 0),
			}, m)
			for _, sgn in ipairs({ -1, 1 }) do
				local hip = V(sgn * 0.34 * s, -0.05 * s, -0.06 * s)
				local knee = V(sgn * 0.42 * s, -0.72 * s, 0.24 * s)
				local ankle = V(sgn * 0.4 * s, -1.36 * s, -0.12 * s)
				local foot = V(sgn * 0.4 * s, -1.6 * s, 0.12 * s)
				B({
					Name = "Ilium",
					Size = V(0.1 * s, 0.34 * s, 0.3 * s),
					CFrame = CFrame.new(hip + V(0, 0.2 * s, -0.14 * s)),
				}, m)
				chain(m, { hip, knee, ankle }, 0.12 * s, 0.17 * s)
				shaft(m, ankle, foot, 0.09 * s)
				for t = -1, 1 do
					shaft(m, foot, foot + V(t * 0.09 * s, -0.08 * s, 0.19 * s), 0.045 * s)
				end
			end
			return m
		end

		function mammal.Tail(sk)
			local s = sk.s
			local m = Instance.new("Model")
			local segs = (sk.id == "Rat") and 16 or 12
			local len = ((sk.id == "Rat") and 2.2 or 1.6) * s
			local pts = {}
			for i = 0, segs do
				local t = i / segs
				table.insert(pts, V(0, -math.sin(t * 1.5) * 0.5 * s, -len * t))
			end
			for i = 1, #pts - 1 do
				shaft(m, pts[i], pts[i + 1], (0.11 - 0.07 * (i / segs)) * s)
			end
			for i, p in ipairs(pts) do
				knob(m, p, (0.17 - 0.11 * ((i - 1) / segs)) * s)
			end
			return m
		end

		-- ── OCELL ──
		local bird = {}

		function bird.Skull(sk)
			local s = sk.s
			local m = Instance.new("Model")
			B({
				Name = "Cranium",
				Shape = Enum.PartType.Ball,
				Size = V(0.62 * s, 0.6 * s, 0.66 * s),
				CFrame = CFrame.new(0, 0, 0),
			}, m)
			B({
				Name = "BeakUpper",
				Size = V(0.24 * s, 0.16 * s, 0.34 * s),
				CFrame = CFrame.new(0, -0.02 * s, 0.44 * s),
			}, m)
			B({
				Name = "BeakTip",
				Size = V(0.13 * s, 0.1 * s, 0.24 * s),
				CFrame = CFrame.new(0, -0.04 * s, 0.7 * s),
			}, m)
			B({
				Name = "BeakLower",
				Size = V(0.16 * s, 0.07 * s, 0.42 * s),
				CFrame = CFrame.new(0, -0.14 * s, 0.5 * s),
			}, m)
			-- Els ocells tenen les conques enormes: es el que els fa reconeixibles.
			for _, sgn in ipairs({ -1, 1 }) do
				B({
					Name = "EyeSocket",
					Shape = Enum.PartType.Ball,
					Color = SOCKET,
					Size = V(0.34 * s, 0.34 * s, 0.34 * s),
					CFrame = CFrame.new(sgn * 0.22 * s, 0.05 * s, 0.2 * s),
				}, m)
			end
			B({
				Name = "Atlas",
				Shape = Enum.PartType.Ball,
				Size = V(0.16 * s, 0.16 * s, 0.16 * s),
				CFrame = CFrame.new(0, -0.12 * s, -0.36 * s),
			}, m)
			return m
		end

		function bird.Spine(sk)
			local s = sk.s
			local m = Instance.new("Model")
			-- Coll en S
			local neck = {}
			for i = 0, 6 do
				local t = i / 6
				table.insert(neck, V(0, 0.5 * s - math.sin(t * math.pi) * 0.28 * s, 0.75 * s - t * 0.75 * s))
			end
			chain(m, neck, 0.08 * s, 0.13 * s)
			local trunk = {}
			for i = 0, 5 do
				table.insert(trunk, V(0, 0.05 * s, -i * 0.16 * s))
			end
			chain(m, trunk, 0.1 * s, 0.15 * s)
			B({
				Name = "Sternum",
				Size = V(0.5 * s, 0.1 * s, 0.9 * s),
				CFrame = CFrame.new(0, -0.5 * s, -0.32 * s),
			}, m)
			B({
				Name = "Keel",
				Size = V(0.08 * s, 0.42 * s, 0.86 * s),
				CFrame = CFrame.new(0, -0.72 * s, -0.32 * s),
			}, m)
			for _, sgn in ipairs({ -1, 1 }) do
				-- Furcula (el forcat)
				shaft(m, V(sgn * 0.3 * s, 0.02 * s, 0.06 * s), V(0, -0.4 * s, -0.05 * s), 0.05 * s)
				for i = 1, 4 do
					local z = -0.05 * s - i * 0.17 * s
					local rp = {}
					for k = 0, 3 do
						local a = math.rad(90 * k / 3)
						table.insert(rp, V(sgn * 0.42 * s * math.sin(a), -0.55 * s * (1 - math.cos(a)), z))
					end
					for k = 1, #rp - 1 do
						shaft(m, rp[k], rp[k + 1], 0.045 * s)
					end
				end
			end
			return m
		end

		function bird.ForeLimbs(sk)
			local s = sk.s
			local m = Instance.new("Model")
			for _, sgn in ipairs({ -1, 1 }) do
				local shoulder = V(sgn * 0.22 * s, 0, 0)
				local elbow = V(sgn * 1 * s, 0.16 * s, -0.28 * s)
				local wrist = V(sgn * 1.75 * s, 0.1 * s, -0.62 * s)
				local tip = V(sgn * 2.35 * s, -0.02 * s, -0.9 * s)
				B({
					Name = "Coracoid",
					Size = V(0.3 * s, 0.08 * s, 0.1 * s),
					CFrame = CFrame.new(shoulder + V(sgn * -0.06 * s, -0.14 * s, 0)),
				}, m)
				chain(m, { shoulder, elbow, wrist, tip }, 0.09 * s, 0.13 * s)
				-- Plomes primaries (del canell enrere) i secundaries (del colze)
				for i = 0, 5 do
					local t = i / 5
					local from = wrist:Lerp(tip, t)
					shaft(m, from, from + V(sgn * 0.12 * s, -0.05 * s, -(0.5 + t * 0.5) * s), 0.035 * s)
				end
				for i = 0, 3 do
					local t = i / 3
					local from = elbow:Lerp(wrist, t)
					shaft(m, from, from + V(sgn * 0.08 * s, -0.04 * s, -(0.34 + t * 0.2) * s), 0.03 * s)
				end
			end
			return m
		end

		function bird.HindLimbs(sk)
			local s = sk.s
			local m = Instance.new("Model")
			B({
				Name = "Pelvis",
				Size = V(0.46 * s, 0.14 * s, 0.7 * s),
				CFrame = CFrame.new(0, 0.1 * s, 0),
			}, m)
			for _, sgn in ipairs({ -1, 1 }) do
				local hip = V(sgn * 0.18 * s, 0, -0.05 * s)
				local knee = V(sgn * 0.26 * s, -0.5 * s, 0.16 * s)
				local heel = V(sgn * 0.24 * s, -0.95 * s, -0.14 * s)
				-- El tars llarg es el que fa que una pota d'ocell es reconegui
				local foot = V(sgn * 0.24 * s, -1.62 * s, 0.02 * s)
				chain(m, { hip, knee, heel, foot }, 0.08 * s, 0.12 * s)
				for t = -1, 1 do
					shaft(m, foot, foot + V(t * 0.14 * s, -0.06 * s, 0.3 * s), 0.035 * s)
				end
				shaft(m, foot, foot + V(0, -0.05 * s, -0.2 * s), 0.035 * s)
			end
			return m
		end

		function bird.Tail(sk)
			local s = sk.s
			local m = Instance.new("Model")
			local pts = {}
			for i = 0, 4 do
				table.insert(pts, V(0, 0, -i * 0.14 * s))
			end
			chain(m, pts, 0.09 * s, 0.13 * s)
			B({
				Name = "Pygostyle",
				Size = V(0.14 * s, 0.26 * s, 0.3 * s),
				CFrame = CFrame.new(0, 0.02 * s, -0.72 * s),
			}, m)
			for i = -3, 3 do
				local a = math.rad(i * 13)
				shaft(m, V(0, 0, -0.82 * s), V(math.sin(a) * 1.1 * s, 0, -0.82 * s - math.cos(a) * 1.1 * s), 0.035 * s)
			end
			return m
		end

		-- ── CONSTRUEIX I DESA A ReplicatedStorage ──
		local built = {}
		for _, sk in ipairs(SKELETONS) do
			local folder = New("Folder", { Name = sk.id }, bonesRoot)
			local isBird = sk.kind == "bird"
			local builders = isBird and bird or mammal
			local names = isBird and BIRD_NAMES or MAMMAL_NAMES
			built[sk.id] = {}
			for _, pc in ipairs(PIECES) do
				local m = builders[pc.id](sk)
				m.Name = sk.id .. "_" .. pc.id
				m:SetAttribute("Skeleton", sk.id)
				m:SetAttribute("SkeletonName", sk.name)
				m:SetAttribute("Piece", pc.id)
				m:SetAttribute("PieceName", names[pc.id])
				m:SetAttribute("Rarity", pc.rarity)
				CollectionService:AddTag(m, "BonePiece")
				m.Parent = folder
				built[sk.id][pc.id] = m
			end
		end

		-- ── GALERIA A LA PLACA ──
		-- Sense aixo els ossos nomes viuen a ReplicatedStorage i no es veuen.
		-- 4 files (una per esquelet) x 5 pedestals, a la meitat nord de la
		-- placa, just al davant de qui apareix a l'spawn.
		local cityModel = zones:FindFirstChild("City")
		if cityPivot and cityModel then
			local gal = Instance.new("Model")
			gal.Name = "BoneGallery"
			local RAR_COL = {
				Common = Color3.fromRGB(150, 150, 145),
				Rare = Color3.fromRGB(70, 120, 190),
				Epic = Color3.fromRGB(150, 90, 190),
			}
			for r, sk in ipairs(SKELETONS) do
				local pz = -(48 + (r - 1) * 15)
				local names = (sk.kind == "bird") and BIRD_NAMES or MAMMAL_NAMES
				for c, pc in ipairs(PIECES) do
					local px = -104 + (c - 1) * 12
					P({
						Name = "Pedestal",
						Size = Vector3.new(2.2, 2.6, 2.2),
						CFrame = cityPivot * CFrame.new(px, SURFACE_Y + 1.3, pz),
						Color = BONE_COL,
						Material = Enum.Material.Marble,
					}, gal)
					local cap = P({
						Name = "Cap",
						Size = Vector3.new(2.6, 0.3, 2.6),
						CFrame = cityPivot * CFrame.new(px, SURFACE_Y + 2.75, pz),
						Color = RAR_COL[pc.rarity],
						Material = Enum.Material.Marble,
					}, gal)
					local gui = New("SurfaceGui", {
						Name = "Plaque",
						Face = Enum.NormalId.Front,
						LightInfluence = 0,
						PixelsPerStud = 50,
					}, cap)
					New("TextLabel", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = sk.name .. " · " .. names[pc.id],
						TextColor3 = Color3.fromRGB(30, 28, 24),
						TextScaled = true,
						Font = Enum.Font.GothamBold,
					}, gui)

					local disp = built[sk.id][pc.id]:Clone()
					disp.Name = "Display"
					disp.Parent = gal
					disp:ScaleTo(sk.display)
					disp:PivotTo(cityPivot * CFrame.new(px, SURFACE_Y + 4.2, pz))
				end
			end
			gal.Parent = cityModel
		end
	end

	-- ═══════════════════════════════════════════════════════════════════════
	-- MINIJOC D'EXCAVACIO: pala + barra de precisio
	-- ═══════════════════════════════════════════════════════════════════════
	-- Regla d'or del CLAUDE.md: el client envia intencio, mai resultat.
	-- La linia la dibuixa el client, pero qui decideix on era quan has
	-- clicat es el servidor, recalculant-ho amb el seu propi rellotge.
	do
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local ServerScriptService = game:GetService("ServerScriptService")
		local ServerStorage = game:GetService("ServerStorage")
		local StarterPlayer = game:GetService("StarterPlayer")
		local scripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")

		-- Neteja del que hi hagi de l'execucio anterior
		for _, path in ipairs({
			{ ReplicatedStorage, "Shared" },
			{ ReplicatedStorage, "Remotes" },
			{ ServerScriptService, "DigService" },
			{ ServerStorage, "Tools" },
			{ scripts, "DigController" },
		}) do
			local parent, name = path[1], path[2]
			if parent then
				local old = parent:FindFirstChild(name)
				if old then
					old:Destroy()
				end
			end
		end

		-- ── REMOTES ──
		local remotes = New("Folder", { Name = "Remotes" }, ReplicatedStorage)
		for _, n in ipairs({
			"DigStart",
			"DigClick",
			"DigUpdate",
			"DigResult",
			"InventoryUpdate",
			"Assemble",
			"Display",
			"MuseumUpdate",
			"TradeAction",
			"TradeUpdate",
			"TradeInvite",
		}) do
			New("RemoteEvent", { Name = n }, remotes)
		end

		-- ── CONFIG (primer la config, despres la logica) ──
		local shared = New("Folder", { Name = "Shared" }, ReplicatedStorage)
		local configFolder = New("Folder", { Name = "Config" }, shared)
		makeScript("ModuleScript", "DigConfig", [==[--!strict

-- Config del minijoc d'excavacio. Un sol lloc per a tots els numeros.

local DigConfig = {}

DigConfig.ATTEMPTS = 3
DigConfig.SPEED = 0.9 -- anada+tornada = 2/SPEED segons
DigConfig.PERFECT_HALF = 0.08 -- mig ample de la franja verd fort (-1..1)
DigConfig.GOOD_HALF = 0.26 -- mig ample de la franja verd fluix
DigConfig.PERFECT_BONUS = 50
DigConfig.GOOD_BONUS = 30
DigConfig.MAX_DIG_DISTANCE = 12
DigConfig.DIG_COOLDOWN = 1.2
DigConfig.MIN_CLICK_INTERVAL = 0.12
DigConfig.LUCK_CAP = 3 -- sostre de sort del CLAUDE.md: x3, mai mes

DigConfig.WEIGHTS = { Common = 70, Rare = 22, Epic = 8 }

-- Ona triangular determinista. El client la dibuixa i el servidor la torna
-- a calcular pel seu compte: cap dels dos es fia de l'altre.
function DigConfig.markerAt(elapsed: number): number
	local p = (elapsed * DigConfig.SPEED) % 2
	if p < 1 then
		return p * 2 - 1
	end
	return 3 - p * 2
end

function DigConfig.scoreFor(pos: number): number
	local d = math.abs(pos)
	if d <= DigConfig.PERFECT_HALF then
		return DigConfig.PERFECT_BONUS
	elseif d <= DigConfig.GOOD_HALF then
		return DigConfig.GOOD_BONUS
	end
	return 0
end

return DigConfig
]==], configFolder)

		makeScript(
			"ModuleScript",
			"Constants",
			[==[--!strict

-- Constants globals. Un sol lloc per a tot el que pot canviar sense redisseny.

local Constants = {
	AUTOSAVE_INTERVAL = 120,
	SCHEMA_VERSION = 1,
	LOCK_TIMEOUT = 90,
	SAVE_RETRIES = 4,
	MAX_LUCK = 3,
}

return Constants
]==],
			configFolder
		)

		makeScript("ModuleScript", "Skeletons", [==[--!strict

-- Que es pot muntar, quant renda i com s'ordenen les peces a l'espai.
-- Config primer: aqui es toca el balanceig, no dins dels serveis.

local Skeletons = {}

Skeletons.PIECES = { "Skull", "Spine", "ForeLimbs", "HindLimbs", "Tail" }

-- income = monedes per minut mentre estigui exposat.
Skeletons.LIST = {
	Rat = { name = "Rata", kind = "mammal", s = 0.5, income = 5, display = 2.6 },
	Pigeon = { name = "Colom", kind = "bird", s = 0.7, income = 8, display = 2.2 },
	Cat = { name = "Gat", kind = "mammal", s = 1, income = 12, display = 1.5 },
	Dog = { name = "Gos", kind = "mammal", s = 1.5, income = 18, display = 1.1 },
}

Skeletons.SLOTS = 6
Skeletons.INCOME_CAP = 120 -- sostre de renda per minut, passi el que passi
Skeletons.OFFLINE_CAP_HOURS = 8
Skeletons.TICK = 10 -- cada quants segons s'acumula la renda

-- On va cada peca respecte del centre, seguint el conveni amb que es van
-- construir els ossos: +Z es el davant, -Z el darrere, +Y amunt.
function Skeletons.layout(kind: string, s: number): { [string]: Vector3 }
	if kind == "bird" then
		return {
			Spine = Vector3.new(0, 0, 0),
			Skull = Vector3.new(0, 0.62 * s, 0.86 * s),
			ForeLimbs = Vector3.new(0, 0.1 * s, -0.15 * s),
			HindLimbs = Vector3.new(0, -0.5 * s, -0.5 * s),
			Tail = Vector3.new(0, -0.05 * s, -0.95 * s),
		}
	end
	local len = 2.6 * s
	return {
		Spine = Vector3.new(0, 0, 0),
		Skull = Vector3.new(0, 0.26 * s, len / 2 + 0.55 * s),
		ForeLimbs = Vector3.new(0, -0.04 * s, len / 2 - 0.4 * s),
		HindLimbs = Vector3.new(0, -0.04 * s, -len / 2 + 0.5 * s),
		Tail = Vector3.new(0, 0.12 * s, -len / 2),
	}
end

return Skeletons
]==], configFolder)

		-- ── LA PALA ──
		local tools = New("Folder", { Name = "Tools" }, ServerStorage)
		do
			local tool = New("Tool", {
				Name = "Pala",
				RequiresHandle = true,
				CanBeDropped = false,
				ToolTip = "Cava als munts de terra",
				GripPos = Vector3.new(0, -0.9, 0),
			}, tools)
			local handle = New("Part", {
				Name = "Handle",
				Size = Vector3.new(0.28, 3.2, 0.28),
				Color = EARTH,
				Material = Enum.Material.WoodPlanks,
				Anchored = false,
				CanCollide = false,
				Massless = true,
				CFrame = CFrame.new(0, 0, 0),
			}, tool)
			local blade = New("Part", {
				Name = "Blade",
				Size = Vector3.new(1.1, 1.2, 0.14),
				Color = GRAY,
				Material = Enum.Material.Metal,
				Anchored = false,
				CanCollide = false,
				Massless = true,
				CFrame = CFrame.new(0, -2.1, 0),
			}, tool)
			New("Part", {
				Name = "Collar",
				Size = Vector3.new(0.4, 0.35, 0.4),
				Color = DARK_GRAY,
				Material = Enum.Material.Metal,
				Anchored = false,
				CanCollide = false,
				Massless = true,
				CFrame = CFrame.new(0, -1.5, 0),
			}, tool)
			-- Les soldadures es fan despres de posar els CFrame: capturen la
			-- posicio relativa del moment.
			for _, part in ipairs(tool:GetChildren()) do
				if part:IsA("BasePart") and part ~= handle then
					New("WeldConstraint", { Part0 = handle, Part1 = part }, handle)
				end
			end
			blade.Name = "Blade"
		end

		-- ── SUPORT D'EINES A L'OBRA ──
		do
			local rack = Instance.new("Model")
			rack.Name = "ShovelRack"
			local O = CFrame.new(-14, SURFACE_Y, 6)
			P({
				Name = "Base",
				Size = Vector3.new(4.5, 0.3, 1.6),
				CFrame = O * CFrame.new(0, 0.15, 0),
				Color = EARTH,
				Material = Enum.Material.WoodPlanks,
			}, rack)
			for _, dx in ipairs({ -2, 2 }) do
				P({
					Name = "Post",
					Size = Vector3.new(0.25, 3.4, 0.25),
					CFrame = O * CFrame.new(dx, 1.7, 0),
					Color = EARTH,
					Material = Enum.Material.WoodPlanks,
				}, rack)
			end
			local bar = P({
				Name = "Bar",
				Size = Vector3.new(4.5, 0.2, 0.2),
				CFrame = O * CFrame.new(0, 3.2, 0),
				Color = EARTH,
				Material = Enum.Material.WoodPlanks,
			}, rack)
			-- Pales recolzades, decoratives
			for _, dx in ipairs({ -1.3, 0, 1.3 }) do
				P({
					Name = "RackShaft",
					Size = Vector3.new(0.22, 3, 0.22),
					CFrame = O * CFrame.new(dx, 1.6, -0.4) * CFrame.Angles(math.rad(9), 0, 0),
					Color = EARTH,
					Material = Enum.Material.WoodPlanks,
					CastShadow = false,
				}, rack)
				P({
					Name = "RackBlade",
					Size = Vector3.new(0.9, 1, 0.12),
					CFrame = O * CFrame.new(dx, 0.5, -0.62) * CFrame.Angles(math.rad(9), 0, 0),
					Color = GRAY,
					Material = Enum.Material.Metal,
					CastShadow = false,
				}, rack)
			end
			New("ProximityPrompt", {
				Name = "TakeShovel",
				ActionText = "Agafar una pala",
				ObjectText = "Suport d'eines",
				HoldDuration = 0.3,
				MaxActivationDistance = 10,
			}, bar)
			CollectionService:AddTag(rack, "ShovelGiver")
			rack.Parent = zone
		end

		-- ── DADES ──
		makeScript(
			"ModuleScript",
			"DataService",
			[==[--!strict

-- Perfils amb session-locking. Cap altre servei toca el DataStore.
-- Regla del CLAUDE.md: cap accio modifica el perfil abans que hagi carregat.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Constants = require(Config:WaitForChild("Constants"))

local DataService = {}

local store = DataStoreService:GetDataStore("MuseuProfiles_v1")
local profiles: { [Player]: any } = {}
local ready: { [Player]: boolean } = {}
local persisted: { [Player]: boolean } = {}

local function jobKey(): string
	return game.JobId ~= "" and game.JobId or "studio"
end

local function emptyProfile()
	return {
		schemaVersion = Constants.SCHEMA_VERSION,
		bones = {},
		skeletons = {},
		museum = {},
		coins = 0,
		lastSeen = os.time(),
	}
end

local function migrate(data)
	data.bones = data.bones or {}
	data.skeletons = data.skeletons or {}
	data.museum = data.museum or {}
	data.coins = data.coins or 0
	data.lastSeen = data.lastSeen or os.time()
	data.schemaVersion = Constants.SCHEMA_VERSION
	return data
end

local function retry(fn)
	local lastErr
	for i = 1, Constants.SAVE_RETRIES do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		task.wait(0.5 * 2 ^ i)
	end
	return false, lastErr
end

function DataService.load(player: Player): boolean
	local key = "p_" .. player.UserId
	local me = jobKey()
	local ok, data = retry(function()
		return store:UpdateAsync(key, function(old)
			local d = old and migrate(old) or emptyProfile()
			local now = os.time()
			local lock = d.lock
			-- Si un altre servidor el te viu, no el toquem.
			if lock and lock.jobId ~= me and now - (lock.at or 0) < Constants.LOCK_TIMEOUT then
				return nil
			end
			d.lock = { jobId = me, at = now }
			return d
		end)
	end)

	if ok and data then
		profiles[player] = data
		persisted[player] = true
	else
		-- A Studio sense "API Services" activat el DataStore no respon. Val
		-- mes deixar jugar amb un perfil de memoria que no pas deixar el joc
		-- mort, pero s'ha de dir clarament que no es desa.
		warn("[DataService] perfil de " .. player.Name .. " no carregat: es juga SENSE DESAR")
		profiles[player] = emptyProfile()
		persisted[player] = false
	end
	ready[player] = true
	return persisted[player]
end

function DataService.save(player: Player, release: boolean)
	if not ready[player] or not persisted[player] then
		return
	end
	local data = profiles[player]
	if not data then
		return
	end
	local key = "p_" .. player.UserId
	local me = jobKey()
	retry(function()
		return store:UpdateAsync(key, function()
			local d = table.clone(data)
			d.lock = release and nil or { jobId = me, at = os.time() }
			return d
		end)
	end)
end

function DataService.isReady(player: Player): boolean
	return ready[player] == true
end

function DataService.isPersisted(player: Player): boolean
	return persisted[player] == true
end

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.addBone(player: Player, pieceId: string): boolean
	if not ready[player] then
		return false
	end
	local d = profiles[player]
	d.bones[pieceId] = (d.bones[pieceId] or 0) + 1
	return true
end

function DataService.release(player: Player)
	DataService.save(player, true)
	profiles[player] = nil
	ready[player] = nil
	persisted[player] = nil
end

task.spawn(function()
	while true do
		task.wait(Constants.AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.save(player, false)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataService.release(player)
	end
end)

return DataService
]==],
			ServerScriptService
		)

		-- ── SERVIDOR ──
		makeScript("Script", "DigService", [==[--!strict

-- Autoritat total al servidor: el client nomes diu "he clicat", i aqui es
-- recalcula on era la linia en aquell instant amb el rellotge del servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DigConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataService = require(script.Parent:WaitForChild("DataService"))

local BUCKET_MAX = 12
local BUCKET_REFILL = 6 -- fitxes per segon

local buckets: { [Player]: { tokens: number, last: number } } = {}
local sessions: { [Player]: any } = {}
local lastDig: { [Player]: number } = {}

-- Rate limit a tots els remotes, com mana el CLAUDE.md.
local function allow(player: Player, cost: number): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = BUCKET_MAX, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(BUCKET_MAX, b.tokens + (now - b.last) * BUCKET_REFILL)
	b.last = now
	if b.tokens < cost then
		return false
	end
	b.tokens -= cost
	return true
end

local function rollRarity(bonus: number): string
	-- bonus 0..150 -> multiplicador 1..2.5, sempre per sota del sostre x3
	local mult = math.min(1 + bonus / 100, Config.LUCK_CAP)
	local w = {
		{ "Epic", Config.WEIGHTS.Epic * mult },
		{ "Rare", Config.WEIGHTS.Rare * mult },
		{ "Common", Config.WEIGHTS.Common },
	}
	local total = 0
	for _, e in ipairs(w) do
		total += e[2]
	end
	local roll = math.random() * total
	for _, e in ipairs(w) do
		roll -= e[2]
		if roll <= 0 then
			return e[1]
		end
	end
	return "Common"
end

local function pickPiece(bonus: number)
	local bones = ReplicatedStorage:FindFirstChild("Bones")
	if not bones then
		return nil
	end
	local skeletons = bones:GetChildren()
	if #skeletons == 0 then
		return nil
	end
	local sk = skeletons[math.random(1, #skeletons)]
	local rarity = rollRarity(bonus)
	local pool = {}
	for _, piece in ipairs(sk:GetChildren()) do
		if piece:GetAttribute("Rarity") == rarity then
			table.insert(pool, piece)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

local function pushInventory(player: Player)
	if not DataService.isReady(player) then
		return
	end
	local d = DataService.get(player)
	Remotes.InventoryUpdate:FireClient(player, {
		bones = d.bones,
		persisted = DataService.isPersisted(player),
	})
end

local function finish(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	local piece = pickPiece(s.total)
	-- L'os va al perfil del servidor, no a cap objecte del Player.
	local stored = false
	if piece and DataService.isReady(player) then
		stored = DataService.addBone(player, piece.Name)
		pushInventory(player)
	end
	Remotes.DigResult:FireClient(player, {
		bonus = s.total,
		skeleton = piece and piece:GetAttribute("SkeletonName") or nil,
		piece = piece and piece:GetAttribute("PieceName") or nil,
		rarity = piece and piece:GetAttribute("Rarity") or nil,
		stored = stored,
	})
end

-- La pala es dona sola en entrar i en reaparèixer: el suport de l'obra
-- queda com a alternativa, pero ningu es queda sense poder cavar.
local function giveShovel(player: Player)
	local pack = player:FindFirstChildOfClass("Backpack")
	if not pack then
		return
	end
	local char = player.Character
	if pack:FindFirstChild("Pala") or (char and char:FindFirstChild("Pala")) then
		return
	end
	local tools = ServerStorage:FindFirstChild("Tools")
	local template = tools and tools:FindFirstChild("Pala")
	if template then
		template:Clone().Parent = pack
	end
end

local function onPlayerAdded(player: Player)
	DataService.load(player)
	pushInventory(player)
	giveShovel(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		giveShovel(player)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Remotes.DigStart.OnServerEvent:Connect(function(player, spot)
	if not allow(player, 3) then
		return
	end
	-- Validacio de tipus abans de tocar res
	if typeof(spot) ~= "Instance" or not spot:IsA("BasePart") then
		return
	end
	if not CollectionService:HasTag(spot, "DigSpot") then
		return
	end
	if sessions[player] then
		return
	end
	local now = os.clock()
	if lastDig[player] and now - lastDig[player] < Config.DIG_COOLDOWN then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- Ha de dur la pala equipada i ser-hi a prop
	if not char:FindFirstChild("Pala") then
		return
	end
	if (root.Position - spot.Position).Magnitude > Config.MAX_DIG_DISTANCE then
		return
	end

	lastDig[player] = now
	local startTime = workspace:GetServerTimeNow()
	sessions[player] = { startTime = startTime, attempts = 0, total = 0, lastClick = 0 }
	Remotes.DigStart:FireClient(player, {
		startTime = startTime,
		attempts = Config.ATTEMPTS,
	})
end)

Remotes.DigClick.OnServerEvent:Connect(function(player)
	if not allow(player, 1) then
		return
	end
	local s = sessions[player]
	if not s then
		return
	end
	local now = os.clock()
	if now - s.lastClick < Config.MIN_CLICK_INTERVAL then
		return
	end
	s.lastClick = now

	-- Aqui es on el servidor mana: la posicio surt del seu rellotge, no
	-- de res que hagi enviat el client.
	local elapsed = workspace:GetServerTimeNow() - s.startTime
	local pos = Config.markerAt(elapsed)
	local gained = Config.scoreFor(pos)
	s.attempts += 1
	s.total += gained

	Remotes.DigUpdate:FireClient(player, {
		attempt = s.attempts,
		gained = gained,
		total = s.total,
		pos = pos,
	})

	if s.attempts >= Config.ATTEMPTS then
		finish(player)
	end
end)

-- Suport d'eines: dona la pala
for _, rack in ipairs(CollectionService:GetTagged("ShovelGiver")) do
	local prompt = rack:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			if not allow(player, 2) then
				return
			end
			local pack = player:FindFirstChildOfClass("Backpack")
			local char = player.Character
			if not pack then
				return
			end
			if pack:FindFirstChild("Pala") or (char and char:FindFirstChild("Pala")) then
				return
			end
			local template = ServerStorage:FindFirstChild("Tools")
			template = template and template:FindFirstChild("Pala")
			if template then
				template:Clone().Parent = pack
			end
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	sessions[player] = nil
	lastDig[player] = nil
	DataService.release(player)
end)
]==], ServerScriptService)

		makeScript("Script", "MuseumService", [==[--!strict

-- Muntar esquelets, exposar-los i cobrar-ne la renda.
-- Tot passa aqui: el client nomes demana, i cada peticio es revalida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Skeletons = require(Config:WaitForChild("Skeletons"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataService = require(script.Parent:WaitForChild("DataService"))
local Bones = ReplicatedStorage:WaitForChild("Bones")

local BUCKET_MAX = 10
local BUCKET_REFILL = 4

local buckets: { [Player]: { tokens: number, last: number } } = {}
local plotOf: { [Player]: Model } = {}
local freePlots: { Model } = {}

local function allow(player: Player, cost: number): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = BUCKET_MAX, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(BUCKET_MAX, b.tokens + (now - b.last) * BUCKET_REFILL)
	b.last = now
	if b.tokens < cost then
		return false
	end
	b.tokens -= cost
	return true
end

for _, plot in ipairs(CollectionService:GetTagged("MuseumPlot")) do
	table.insert(freePlots, plot)
end
table.sort(freePlots, function(a, b)
	return a.Name < b.Name
end)

-- ── RENDA ──
local function incomeRate(profile): number
	local rate = 0
	for _, id in pairs(profile.museum) do
		local def = Skeletons.LIST[id]
		if def then
			rate += def.income
		end
	end
	-- Sostre: exposar mes esquelets no dispara la renda sense limit.
	return math.min(rate, Skeletons.INCOME_CAP)
end

local function pushMuseum(player: Player)
	if not DataService.isReady(player) then
		return
	end
	local d = DataService.get(player)
	-- Que es pot muntar ara mateix: cal tenir-ne les 5 peces.
	local buildable = {}
	for id, def in pairs(Skeletons.LIST) do
		local ok = true
		for _, piece in ipairs(Skeletons.PIECES) do
			if (d.bones[id .. "_" .. piece] or 0) < 1 then
				ok = false
				break
			end
		end
		if ok then
			buildable[id] = def.name
		end
	end
	Remotes.MuseumUpdate:FireClient(player, {
		coins = math.floor(d.coins),
		rate = incomeRate(d),
		cap = Skeletons.INCOME_CAP,
		slots = Skeletons.SLOTS,
		museum = d.museum,
		skeletons = d.skeletons,
		buildable = buildable,
		names = (function()
			local t = {}
			for id, def in pairs(Skeletons.LIST) do
				t[id] = def.name
			end
			return t
		end)(),
	})
end

-- ── MUNTATGE FISIC DE L'ESQUELET ──
local function buildSkeleton(id: string): Model?
	local def = Skeletons.LIST[id]
	local folder = Bones:FindFirstChild(id)
	if not def or not folder then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = id .. "_Assembled"
	local layout = Skeletons.layout(def.kind, def.s)
	for _, piece in ipairs(Skeletons.PIECES) do
		local src = folder:FindFirstChild(id .. "_" .. piece)
		if src then
			local c = src:Clone()
			c.Parent = m
			c:PivotTo(CFrame.new(layout[piece] or Vector3.zero))
		end
	end
	return m
end

local function refreshDisplays(player: Player)
	local plot = plotOf[player]
	if not plot or not DataService.isReady(player) then
		return
	end
	local d = DataService.get(player)
	for i = 1, Skeletons.SLOTS do
		local slot = plot:FindFirstChild("Slot" .. i)
		if slot then
			local old = slot:FindFirstChild("Exhibit")
			if old then
				old:Destroy()
			end
			local id = d.museum[tostring(i)]
			if id then
				local m = buildSkeleton(id)
				if m then
					m.Name = "Exhibit"
					m.Parent = slot
					m:ScaleTo(Skeletons.LIST[id].display)
					m:PivotTo(slot.CFrame * CFrame.new(0, 3.4, 0))
				end
			end
		end
	end
end

-- ── REMOTES ──
Remotes.Assemble.OnServerEvent:Connect(function(player, id)
	if not allow(player, 2) then
		return
	end
	if typeof(id) ~= "string" or not Skeletons.LIST[id] then
		return
	end
	if not DataService.isReady(player) then
		return
	end
	local d = DataService.get(player)
	-- Comprovacio abans de tocar res: o hi son les 5, o no es gasta cap peca.
	for _, piece in ipairs(Skeletons.PIECES) do
		if (d.bones[id .. "_" .. piece] or 0) < 1 then
			return
		end
	end
	for _, piece in ipairs(Skeletons.PIECES) do
		local key = id .. "_" .. piece
		d.bones[key] -= 1
		if d.bones[key] <= 0 then
			d.bones[key] = nil
		end
	end
	d.skeletons[id] = (d.skeletons[id] or 0) + 1
	Remotes.InventoryUpdate:FireClient(player, { bones = d.bones, persisted = DataService.isPersisted(player) })
	pushMuseum(player)
end)

Remotes.Display.OnServerEvent:Connect(function(player, id)
	if not allow(player, 2) then
		return
	end
	if typeof(id) ~= "string" or not Skeletons.LIST[id] then
		return
	end
	if not DataService.isReady(player) then
		return
	end
	local d = DataService.get(player)
	if (d.skeletons[id] or 0) < 1 then
		return
	end
	local slot: string? = nil
	for i = 1, Skeletons.SLOTS do
		if d.museum[tostring(i)] == nil then
			slot = tostring(i)
			break
		end
	end
	if not slot then
		return
	end
	d.skeletons[id] -= 1
	if d.skeletons[id] <= 0 then
		d.skeletons[id] = nil
	end
	d.museum[slot] = id
	refreshDisplays(player)
	pushMuseum(player)
end)

-- ── ENTRADA I SORTIDA ──
local function assignPlot(player: Player)
	local plot = table.remove(freePlots, 1)
	if not plot then
		return
	end
	plotOf[player] = plot
	local sign = plot:FindFirstChild("OwnerSign", true)
	local label = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = "MUSEU DE " .. string.upper(player.Name)
	end
end

local function onPlayerAdded(player: Player)
	-- DigService ja crida DataService.load; aqui s'espera que estigui llest.
	local waited = 0
	while not DataService.isReady(player) and waited < 20 do
		task.wait(0.25)
		waited += 0.25
	end
	if not DataService.isReady(player) then
		return
	end
	local d = DataService.get(player)
	-- Renda acumulada mentre no hi era, amb el sostre de 8 hores.
	local away = math.clamp(os.time() - (d.lastSeen or os.time()), 0, Skeletons.OFFLINE_CAP_HOURS * 3600)
	d.coins += incomeRate(d) * (away / 60)
	d.lastSeen = os.time()
	assignPlot(player)
	refreshDisplays(player)
	pushMuseum(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	if DataService.isReady(player) then
		DataService.get(player).lastSeen = os.time()
	end
	local plot = plotOf[player]
	if plot then
		for i = 1, Skeletons.SLOTS do
			local slot = plot:FindFirstChild("Slot" .. i)
			local ex = slot and slot:FindFirstChild("Exhibit")
			if ex then
				ex:Destroy()
			end
		end
		local sign = plot:FindFirstChild("OwnerSign", true)
		local label = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			label.Text = "MUSEU LLIURE"
		end
		table.insert(freePlots, plot)
	end
	plotOf[player] = nil
	buckets[player] = nil
end)

-- ── ACUMULACIO DE RENDA ──
task.spawn(function()
	while true do
		task.wait(Skeletons.TICK)
		for _, player in ipairs(Players:GetPlayers()) do
			if DataService.isReady(player) then
				local d = DataService.get(player)
				d.coins += incomeRate(d) * (Skeletons.TICK / 60)
				d.lastSeen = os.time()
				pushMuseum(player)
			end
		end
	end
end)

-- ── PORTES ──
for _, pad in ipairs(CollectionService:GetTagged("ToMuseum")) do
	local prompt = pad:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			local plot = plotOf[player]
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local entry = plot and plot:FindFirstChild("Entry")
			if root and entry then
				root.CFrame = entry.CFrame + Vector3.new(0, 4, 0)
			end
		end)
	end
end

for _, pad in ipairs(CollectionService:GetTagged("ToCity")) do
	local prompt = pad:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local spawnPad = workspace:FindFirstChild("CitySpawn", true)
			if root and spawnPad then
				root.CFrame = spawnPad.CFrame + Vector3.new(0, 4, 0)
			end
		end)
	end
end
]==], ServerScriptService)

		makeScript("Script", "TradeService", [==[--!strict

-- COMERC. El codi mes perillos del joc, i per aixo el mes desconfiat.
--
-- Garanties:
--  · Cap objecte de valor viu al Player: tot surt del perfil del servidor.
--  · Qualsevol canvi d'oferta esborra les confirmacions de TOTS DOS. Es el
--    que impedeix l'estafa classica de canviar l'oferta a l'ultim moment.
--  · L'intercanvi es valida sencer i despres es fa sencer, sense cap yield
--    pel mig. En un entorn cooperatiu com Luau, no cedir el control es el
--    que fa que sigui atomic: o passa tot, o no passa res.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataService = require(script.Parent:WaitForChild("DataService"))

local MAX_TRADE_DISTANCE = 40
local REQUEST_COOLDOWN = 3
local BUCKET_MAX = 14
local BUCKET_REFILL = 5

local buckets: { [Player]: { tokens: number, last: number } } = {}
local tradeOf: { [Player]: any } = {}
local inviteFrom: { [Player]: Player } = {}
local lastRequest: { [Player]: number } = {}

local function allow(player: Player, cost: number): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = BUCKET_MAX, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(BUCKET_MAX, b.tokens + (now - b.last) * BUCKET_REFILL)
	b.last = now
	if b.tokens < cost then
		return false
	end
	b.tokens -= cost
	return true
end

local function near(a: Player, b: Player): boolean
	local ca, cb = a.Character, b.Character
	local ra = ca and ca:FindFirstChild("HumanoidRootPart")
	local rb = cb and cb:FindFirstChild("HumanoidRootPart")
	if not ra or not rb then
		return false
	end
	return (ra.Position - rb.Position).Magnitude <= MAX_TRADE_DISTANCE
end

local function other(t, player: Player): Player
	return t.a == player and t.b or t.a
end

local function pushState(t)
	for _, player in ipairs({ t.a, t.b }) do
		local o = other(t, player)
		Remotes.TradeUpdate:FireClient(player, {
			state = "active",
			other = o.Name,
			myOffer = t.offers[player],
			theirOffer = t.offers[o],
			myConfirmed = t.confirmed[player],
			theirConfirmed = t.confirmed[o],
			myAccepted = t.accepted[player],
			theirAccepted = t.accepted[o],
			locked = t.confirmed[t.a] and t.confirmed[t.b],
		})
	end
end

local function closeTrade(t, reason: string)
	for _, player in ipairs({ t.a, t.b }) do
		if tradeOf[player] == t then
			tradeOf[player] = nil
		end
		Remotes.TradeUpdate:FireClient(player, { state = "idle", reason = reason })
	end
end

-- Qualsevol moviment d'oferta invalida les confirmacions dels dos.
local function resetConfirmations(t)
	t.confirmed[t.a] = false
	t.confirmed[t.b] = false
	t.accepted[t.a] = false
	t.accepted[t.b] = false
end

-- ── L'INTERCANVI ──
local function executeTrade(t): boolean
	-- 1) VALIDACIO SENCERA. Encara no s'ha tocat cap perfil.
	if not DataService.isReady(t.a) or not DataService.isReady(t.b) then
		return false
	end
	local da, db = DataService.get(t.a), DataService.get(t.b)
	for _, pair in ipairs({ { t.a, da }, { t.b, db } }) do
		local player, d = pair[1], pair[2]
		for id, n in pairs(t.offers[player]) do
			if type(n) ~= "number" or n < 1 or (d.bones[id] or 0) < n then
				return false
			end
		end
	end

	-- 2) MUTACIO SENCERA. A partir d'aqui no hi ha cap crida que cedeixi el
	--    control, o sigui que ningu pot colar-se entremig ni deixar-ho a mig fer.
	local function move(from, to, offer)
		for id, n in pairs(offer) do
			from.bones[id] -= n
			if from.bones[id] <= 0 then
				from.bones[id] = nil
			end
			to.bones[id] = (to.bones[id] or 0) + n
		end
	end
	move(da, db, t.offers[t.a])
	move(db, da, t.offers[t.b])
	return true
end

-- ── ACCIONS ──
local actions = {}

function actions.request(player: Player, targetName)
	if typeof(targetName) ~= "string" then
		return
	end
	if tradeOf[player] then
		return
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return
	end
	local target = Players:FindFirstChild(targetName)
	if not target or not target:IsA("Player") or target == player then
		return
	end
	if tradeOf[target] then
		return
	end
	if not near(player, target) then
		return
	end
	lastRequest[player] = now
	inviteFrom[target] = player
	Remotes.TradeInvite:FireClient(target, { from = player.Name })
end

function actions.accept_invite(player: Player)
	local from = inviteFrom[player]
	inviteFrom[player] = nil
	if not from or not from.Parent then
		return
	end
	if tradeOf[player] or tradeOf[from] then
		return
	end
	if not near(player, from) then
		return
	end
	local t = {
		a = from,
		b = player,
		offers = { [from] = {}, [player] = {} },
		confirmed = { [from] = false, [player] = false },
		accepted = { [from] = false, [player] = false },
	}
	tradeOf[from] = t
	tradeOf[player] = t
	pushState(t)
end

function actions.decline_invite(player: Player)
	inviteFrom[player] = nil
end

function actions.offer(player: Player, payload)
	local t = tradeOf[player]
	if not t then
		return
	end
	-- Amb l'oferta bloquejada per les dues confirmacions ja no s'hi toca.
	if t.confirmed[t.a] and t.confirmed[t.b] then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	local id, delta = payload.id, payload.delta
	if typeof(id) ~= "string" or typeof(delta) ~= "number" then
		return
	end
	delta = (delta > 0) and 1 or -1
	if not DataService.isReady(player) then
		return
	end
	local d = DataService.get(player)
	local offer = t.offers[player]
	local current = offer[id] or 0
	local wanted = current + delta
	-- No es pot oferir mes del que es te ara mateix.
	if wanted < 0 or wanted > (d.bones[id] or 0) then
		return
	end
	offer[id] = (wanted > 0) and wanted or nil
	resetConfirmations(t)
	pushState(t)
end

function actions.confirm(player: Player, value)
	local t = tradeOf[player]
	if not t then
		return
	end
	t.confirmed[player] = value and true or false
	if not t.confirmed[player] then
		t.accepted[t.a] = false
		t.accepted[t.b] = false
	end
	pushState(t)
end

function actions.accept(player: Player)
	local t = tradeOf[player]
	if not t then
		return
	end
	if not (t.confirmed[t.a] and t.confirmed[t.b]) then
		return
	end
	if not near(t.a, t.b) then
		closeTrade(t, "us heu allunyat massa")
		return
	end
	t.accepted[player] = true
	if not (t.accepted[t.a] and t.accepted[t.b]) then
		pushState(t)
		return
	end

	local ok = executeTrade(t)
	local a, b = t.a, t.b
	closeTrade(t, ok and "canvi fet" or "el canvi ha fallat: alguna peca ja no hi era")
	if ok then
		for _, player2 in ipairs({ a, b }) do
			local d = DataService.get(player2)
			Remotes.InventoryUpdate:FireClient(
				player2,
				{ bones = d.bones, persisted = DataService.isPersisted(player2) }
			)
			-- Desa just despres de tancar: aixo si que pot cedir el control,
			-- pero l'intercanvi ja esta fet i es coherent.
			task.spawn(function()
				DataService.save(player2, false)
			end)
		end
	end
end

function actions.cancel(player: Player)
	local t = tradeOf[player]
	if t then
		closeTrade(t, player.Name .. " ha cancel.lat")
	end
	inviteFrom[player] = nil
end

Remotes.TradeAction.OnServerEvent:Connect(function(player, action, payload)
	if typeof(action) ~= "string" then
		return
	end
	local fn = actions[action]
	if not fn then
		return
	end
	if not allow(player, action == "request" and 3 or 1) then
		return
	end
	fn(player, payload)
end)

Players.PlayerRemoving:Connect(function(player)
	local t = tradeOf[player]
	if t then
		closeTrade(t, player.Name .. " ha marxat")
	end
	buckets[player] = nil
	inviteFrom[player] = nil
	lastRequest[player] = nil
	for p, from in pairs(inviteFrom) do
		if from == player then
			inviteFrom[p] = nil
		end
	end
end)
]==], ServerScriptService)

		-- ── CLIENT ──
		if scripts then
			makeScript("LocalScript", "TradeController", [==[--!strict

-- Panell de comerc. Nomes ensenya i demana: totes les decisions son del servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Bones = ReplicatedStorage:WaitForChild("Bones")

local myBones: { [string]: number } = {}
local state: any = { state = "idle" }
local invite: string? = nil

local function describe(id: string): string
	for _, sk in ipairs(Bones:GetChildren()) do
		local m = sk:FindFirstChild(id)
		if m then
			return (m:GetAttribute("SkeletonName") or sk.Name) .. " · " .. (m:GetAttribute("PieceName") or id)
		end
	end
	return id
end

local gui = Instance.new("ScreenGui")
gui.Name = "TradeGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 300)
panel.Position = UDim2.new(0, 16, 1, -316)
panel.BackgroundColor3 = Color3.fromRGB(47, 42, 36)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner").Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 22)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(192, 138, 62)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = "COMERÇ"
title.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -36)
list.Position = UDim2.fromOffset(8, 30)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local order = 0
local function row(text: string, color: Color3?)
	order += 1
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -6, 0, 17)
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color or Color3.fromRGB(200, 192, 176)
	l.TextScaled = true
	l.Font = Enum.Font.Gotham
	l.Text = text
	l.Parent = list
end

local function button(text: string, color: Color3, cb)
	order += 1
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -6, 0, 24)
	b.LayoutOrder = order
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.TextColor3 = Color3.fromRGB(237, 227, 204)
	b.TextScaled = true
	b.Font = Enum.Font.Gotham
	b.Text = text
	b.Parent = list
	Instance.new("UICorner").Parent = b
	b.MouseButton1Click:Connect(cb)
end

local GREY = Color3.fromRGB(70, 62, 52)
local GREEN = Color3.fromRGB(58, 104, 66)
local RED = Color3.fromRGB(118, 62, 52)

local function nearbyPlayers()
	local out = {}
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot then
		return out
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - myRoot.Position).Magnitude <= 40 then
				table.insert(out, p.Name)
			end
		end
	end
	return out
end

local function redraw()
	for _, c in ipairs(list:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	order = 0

	if invite then
		title.Text = "COMERÇ"
		row(invite .. " et proposa un canvi", Color3.fromRGB(237, 227, 204))
		button("Acceptar", GREEN, function()
			Remotes.TradeAction:FireServer("accept_invite")
			invite = nil
			redraw()
		end)
		button("Rebutjar", RED, function()
			Remotes.TradeAction:FireServer("decline_invite")
			invite = nil
			redraw()
		end)
		return
	end

	if state.state ~= "active" then
		title.Text = "COMERÇ"
		if state.reason then
			row(state.reason, Color3.fromRGB(192, 138, 62))
		end
		local names = nearbyPlayers()
		if #names == 0 then
			row("no hi ha ningu a prop")
		else
			for _, name in ipairs(names) do
				button("Proposar canvi a " .. name, GREY, function()
					Remotes.TradeAction:FireServer("request", name)
				end)
			end
		end
		return
	end

	title.Text = "CANVI AMB " .. string.upper(state.other)

	row("LA TEVA OFERTA", Color3.fromRGB(140, 133, 120))
	local anyMine = false
	for id, n in pairs(state.myOffer or {}) do
		anyMine = true
		row("  " .. describe(id) .. " x" .. n)
	end
	if not anyMine then
		row("  res")
	end

	row("LA SEVA OFERTA", Color3.fromRGB(140, 133, 120))
	local anyTheirs = false
	for id, n in pairs(state.theirOffer or {}) do
		anyTheirs = true
		row("  " .. describe(id) .. " x" .. n)
	end
	if not anyTheirs then
		row("  res")
	end

	if not state.locked then
		row("EL TEU INVENTARI", Color3.fromRGB(140, 133, 120))
		for id, n in pairs(myBones) do
			local offered = (state.myOffer or {})[id] or 0
			button(describe(id) .. "  (" .. offered .. "/" .. n .. ")", GREY, function()
				Remotes.TradeAction:FireServer("offer", { id = id, delta = 1 })
			end)
			if offered > 0 then
				button("  treure " .. describe(id), GREY, function()
					Remotes.TradeAction:FireServer("offer", { id = id, delta = -1 })
				end)
			end
		end
	else
		row("oferta bloquejada pels dos", Color3.fromRGB(192, 138, 62))
	end

	row(
		"tu: " .. (state.myConfirmed and "confirmat" or "sense confirmar") .. "  ·  ell: " .. (
			state.theirConfirmed and "confirmat" or "sense confirmar"
		),
		Color3.fromRGB(140, 133, 120)
	)

	if not state.locked then
		button(state.myConfirmed and "Treure la confirmacio" or "Confirmar oferta", GREEN, function()
			Remotes.TradeAction:FireServer("confirm", not state.myConfirmed)
		end)
	else
		button(state.myAccepted and "Esperant l altre..." or "ACCEPTAR EL CANVI", GREEN, function()
			Remotes.TradeAction:FireServer("accept")
		end)
	end
	button("Cancel.lar", RED, function()
		Remotes.TradeAction:FireServer("cancel")
	end)
end

Remotes.TradeInvite.OnClientEvent:Connect(function(d)
	invite = d.from
	redraw()
end)

Remotes.TradeUpdate.OnClientEvent:Connect(function(d)
	state = d
	invite = nil
	redraw()
end)

Remotes.InventoryUpdate.OnClientEvent:Connect(function(d)
	myBones = d.bones or {}
	if state.state == "active" then
		redraw()
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		if state.state ~= "active" and not invite then
			redraw()
		end
	end
end)

redraw()
]==], scripts)
			makeScript("LocalScript", "MuseumController", [==[--!strict

-- Panell de museu. Nomes demana coses: no calcula monedes ni valida res.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "MuseumGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(280, 360)
panel.Position = UDim2.new(1, -296, 0, 16)
panel.BackgroundColor3 = Color3.fromRGB(47, 42, 36)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner").Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(192, 138, 62)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = "MUSEU"
title.Parent = panel

local money = Instance.new("TextLabel")
money.Size = UDim2.new(1, -16, 0, 20)
money.Position = UDim2.fromOffset(8, 32)
money.BackgroundTransparency = 1
money.TextColor3 = Color3.fromRGB(237, 227, 204)
money.TextXAlignment = Enum.TextXAlignment.Left
money.TextScaled = true
money.Font = Enum.Font.Gotham
money.Text = "0 monedes"
money.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -62)
list.Position = UDim2.fromOffset(8, 56)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function header(text: string, order: number)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -6, 0, 18)
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.fromRGB(140, 133, 120)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Text = text
	l.Parent = list
end

local function button(text: string, order: number, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -6, 0, 26)
	b.LayoutOrder = order
	b.BackgroundColor3 = Color3.fromRGB(70, 62, 52)
	b.BorderSizePixel = 0
	b.TextColor3 = Color3.fromRGB(237, 227, 204)
	b.TextScaled = true
	b.Font = Enum.Font.Gotham
	b.Text = text
	b.Parent = list
	Instance.new("UICorner").Parent = b
	b.MouseButton1Click:Connect(cb)
end

Remotes.MuseumUpdate.OnClientEvent:Connect(function(d)
	for _, c in ipairs(list:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	money.Text = d.coins .. " monedes  ·  " .. d.rate .. "/min (max " .. d.cap .. ")"

	local order = 0
	local any = false
	order += 1
	header("PER MUNTAR", order)
	for id, name in pairs(d.buildable or {}) do
		any = true
		order += 1
		button("Muntar " .. name, order, function()
			Remotes.Assemble:FireServer(id)
		end)
	end
	if not any then
		order += 1
		header("  et falten peces", order)
	end

	any = false
	order += 1
	header("MUNTATS, PER EXPOSAR", order)
	for id, count in pairs(d.skeletons or {}) do
		any = true
		order += 1
		button("Exposar " .. (d.names[id] or id) .. " x" .. count, order, function()
			Remotes.Display:FireServer(id)
		end)
	end
	if not any then
		order += 1
		header("  cap encara", order)
	end

	local used = 0
	for _ in pairs(d.museum or {}) do
		used += 1
	end
	order += 1
	header("EXPOSATS: " .. used .. " / " .. d.slots, order)
	for slot, id in pairs(d.museum or {}) do
		order += 1
		header("  " .. slot .. ". " .. (d.names[id] or id), order)
	end
end)
]==], scripts)
			makeScript("LocalScript", "DigController", [==[--!strict

-- Dibuixa la barra i envia clics. No calcula cap resultat: nomes intencio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DigConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local mouse = player:GetMouse()

local BAR_W = 520
local BAR_H = 46

local gui = Instance.new("ScreenGui")
gui.Name = "DigGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(BAR_W, BAR_H)
panel.Position = UDim2.new(0.5, 0, 0.78, 0)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(47, 42, 36) -- #2F2A24
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner").Parent = panel

local function band(halfWidth: number, color: Color3, z: number)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(halfWidth * 2, 0, 1, -12)
	f.Position = UDim2.new(0.5, 0, 0.5, 0)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = panel
	Instance.new("UICorner").Parent = f
	return f
end
band(Config.GOOD_HALF, Color3.fromRGB(110, 158, 90), 2) -- semiverd
band(Config.PERFECT_HALF, Color3.fromRGB(53, 193, 90), 3) -- verd fort

local marker = Instance.new("Frame")
marker.Size = UDim2.fromOffset(4, BAR_H - 4)
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.BackgroundColor3 = Color3.fromRGB(237, 227, 204)
marker.BorderSizePixel = 0
marker.ZIndex = 5
marker.Parent = panel

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 28)
info.Position = UDim2.new(0, 0, 0, -32)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.fromRGB(237, 227, 204)
info.TextScaled = true
info.Font = Enum.Font.GothamBold
info.Text = ""
info.Parent = panel

-- Panell d'inventari. Nomes mostra: la veritat viu al servidor.
local invGui = Instance.new("ScreenGui")
invGui.Name = "InventoryGui"
invGui.ResetOnSpawn = false
invGui.Parent = player:WaitForChild("PlayerGui")

local invPanel = Instance.new("Frame")
invPanel.Size = UDim2.fromOffset(260, 320)
invPanel.Position = UDim2.fromOffset(16, 16)
invPanel.BackgroundColor3 = Color3.fromRGB(47, 42, 36)
invPanel.BackgroundTransparency = 0.15
invPanel.BorderSizePixel = 0
invPanel.Parent = invGui
Instance.new("UICorner").Parent = invPanel

local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.new(1, -16, 0, 26)
invTitle.Position = UDim2.fromOffset(8, 6)
invTitle.BackgroundTransparency = 1
invTitle.TextColor3 = Color3.fromRGB(192, 138, 62)
invTitle.TextXAlignment = Enum.TextXAlignment.Left
invTitle.TextScaled = true
invTitle.Font = Enum.Font.GothamBold
invTitle.Text = "INVENTARI"
invTitle.Parent = invPanel

local invList = Instance.new("Frame")
invList.Size = UDim2.new(1, -16, 1, -40)
invList.Position = UDim2.fromOffset(8, 34)
invList.BackgroundTransparency = 1
invList.Parent = invPanel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = invList

local bonesFolder = ReplicatedStorage:WaitForChild("Bones")
local RARITY_COL = {
	Common = Color3.fromRGB(180, 180, 172),
	Rare = Color3.fromRGB(120, 170, 235),
	Epic = Color3.fromRGB(198, 140, 235),
}

local function describe(id: string)
	for _, sk in ipairs(bonesFolder:GetChildren()) do
		local m = sk:FindFirstChild(id)
		if m then
			return (m:GetAttribute("SkeletonName") or sk.Name)
				.. " · "
				.. (m:GetAttribute("PieceName") or id),
				m:GetAttribute("Rarity") or "Common"
		end
	end
	return id, "Common"
end

Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
	for _, c in ipairs(invList:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local rows = {}
	for id, count in pairs(data.bones or {}) do
		local text, rarity = describe(id)
		table.insert(rows, { text = text, rarity = rarity, count = count })
	end
	table.sort(rows, function(a, b)
		return a.text < b.text
	end)
	invTitle.Text = data.persisted and "INVENTARI" or "INVENTARI (no es desa)"
	invTitle.TextColor3 = data.persisted and Color3.fromRGB(192, 138, 62) or Color3.fromRGB(220, 120, 90)
	for i, row in ipairs(rows) do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, 20)
		l.LayoutOrder = i
		l.BackgroundTransparency = 1
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = RARITY_COL[row.rarity] or RARITY_COL.Common
		l.TextScaled = true
		l.Font = Enum.Font.Gotham
		l.Text = row.text .. "  x" .. row.count
		l.Parent = invList
	end
	if #rows == 0 then
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, 20)
		l.BackgroundTransparency = 1
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.fromRGB(140, 133, 120)
		l.TextScaled = true
		l.Font = Enum.Font.Gotham
		l.Text = "Encara no has trobat res"
		l.Parent = invList
	end
end)

local active = false
local startTime = 0
local conn: RBXScriptConnection? = nil

local function stop()
	active = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

Remotes.DigStart.OnClientEvent:Connect(function(data)
	startTime = data.startTime
	active = true
	gui.Enabled = true
	info.Text = "0 / " .. Config.ATTEMPTS .. "  ·  bonus 0%"
	if conn then
		conn:Disconnect()
	end
	conn = RunService.RenderStepped:Connect(function()
		local pos = Config.markerAt(workspace:GetServerTimeNow() - startTime)
		marker.Position = UDim2.new((pos + 1) / 2, 0, 0.5, 0)
	end)
end)

Remotes.DigUpdate.OnClientEvent:Connect(function(data)
	local tag = data.gained == Config.PERFECT_BONUS and "PERFECTE +50%"
		or (data.gained == Config.GOOD_BONUS and "BE +30%" or "FALLAT")
	info.Text = data.attempt .. " / " .. Config.ATTEMPTS .. "  ·  " .. tag .. "  ·  bonus " .. data.total .. "%"
end)

Remotes.DigResult.OnClientEvent:Connect(function(data)
	stop()
	if data.piece then
		info.Text = "Has trobat: "
			.. data.skeleton
			.. " · "
			.. data.piece
			.. " ("
			.. data.rarity
			.. ")"
			.. (data.stored and "" or "  [NO DESAT]")
	else
		info.Text = "No has trobat res. Bonus " .. data.bonus .. "%"
	end
	task.delay(3, function()
		if not active then
			gui.Enabled = false
		end
	end)
end)

local function onActivate()
	if active then
		Remotes.DigClick:FireServer()
		return
	end
	local target = mouse.Target
	if target and CollectionService:HasTag(target, "DigSpot") then
		Remotes.DigStart:FireServer(target)
	end
end

local function hook(child: Instance)
	if child:IsA("Tool") and child.Name == "Pala" then
		child.Activated:Connect(onActivate)
	end
end

local function watch(container: Instance)
	container.ChildAdded:Connect(hook)
	for _, c in ipairs(container:GetChildren()) do
		hook(c)
	end
end

watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(watch)
if player.Character then
	watch(player.Character)
end
]==], scripts)
		end
	end


	-- ═══════════════════════════════════════════════════════════════════════
	-- MUSEUS: 8 parcel.les repartides pel mapa
	-- ═══════════════════════════════════════════════════════════════════════
	-- Res de districte a part: van als patis interiors de les tres illes
	-- lliures (s'hi entra pel pas del costat sud) i dos a la platja.
	-- Prototip: pavello sense sostre, per poder veure els esquelets de fora.
	do
		local museums = Workspace:FindFirstChild("Museums")
		local MARBLE = Color3.fromRGB(237, 227, 204) -- os #EDE3CC
		local DEEP_GREEN = Color3.fromRGB(47, 74, 60) -- #2F4A3C
		local BRASS = Color3.fromRGB(192, 138, 62) -- #C08A3E
		local STONE = Color3.fromRGB(110, 106, 99) -- #6E6A63

		local MW, MD = 32, 36 -- petjada del pavello
		local WALL_H = 13

		local function buildMuseum(O, index)
			local plot = Instance.new("Model")
			plot.Name = "Plot" .. index

			-- Basament i graons d'entrada
			P({
				Name = "Base",
				Size = Vector3.new(MW + 4, 1.6, MD + 4),
				CFrame = O * CFrame.new(0, 0.8, 0),
				Color = STONE,
				Material = Enum.Material.Slate,
			}, plot)
			P({
				Name = "Floor",
				Size = Vector3.new(MW, 0.6, MD),
				CFrame = O * CFrame.new(0, 1.9, 0),
				Color = MARBLE,
				Material = Enum.Material.Marble,
			}, plot)
			P({
				Name = "Runner",
				Size = Vector3.new(6, 0.1, MD - 6),
				CFrame = O * CFrame.new(0, 2.25, 0),
				Color = DEEP_GREEN,
				Material = Enum.Material.Slate,
				CastShadow = false,
			}, plot)
			for st = 1, 3 do
				P({
					Name = "Step" .. st,
					Size = Vector3.new(MW - 6, 0.5, 1.6),
					CFrame = O * CFrame.new(0, 0.35 + (3 - st) * 0.5, MD / 2 + 1 + st * 1.6),
					Color = STONE,
					Material = Enum.Material.Slate,
				}, plot)
			end

			-- Tres parets tancades; la cara del davant es el porxo
			for _, w in ipairs({
				{ Vector3.new(MW, WALL_H, 1), Vector3.new(0, WALL_H / 2 + 2.2, -MD / 2) },
				{ Vector3.new(1, WALL_H, MD), Vector3.new(-MW / 2, WALL_H / 2 + 2.2, 0) },
				{ Vector3.new(1, WALL_H, MD), Vector3.new(MW / 2, WALL_H / 2 + 2.2, 0) },
			}) do
				P({
					Name = "Wall",
					Size = w[1],
					CFrame = O * CFrame.new(w[2].X, w[2].Y, w[2].Z),
					Color = DEEP_GREEN,
					Material = Enum.Material.Slate,
				}, plot)
			end
			-- Pilastres de marbre trencant el verd de les parets llargues
			for _, px in ipairs({ -MW / 2, MW / 2 }) do
				for _, pz in ipairs({ -10, 0, 10 }) do
					P({
						Name = "Pilaster",
						Size = Vector3.new(1.4, WALL_H, 2.2),
						CFrame = O * CFrame.new(px, WALL_H / 2 + 2.2, pz),
						Color = MARBLE,
						Material = Enum.Material.Marble,
						CastShadow = false,
					}, plot)
				end
			end

			-- Porxo: 4 columnes, arquitrau i frontó esglaonat
			for _, cx in ipairs({ -12, -4, 4, 12 }) do
				VCyl({
					Name = "Column",
					Size = Vector3.new(WALL_H, 2.6, 2.6),
					CFrame = O * CFrame.new(cx, WALL_H / 2 + 2.2, MD / 2 - 1),
					Color = MARBLE,
					Material = Enum.Material.Marble,
				}, plot)
				P({
					Name = "Capital",
					Size = Vector3.new(3.4, 0.7, 3.4),
					CFrame = O * CFrame.new(cx, WALL_H + 2.2, MD / 2 - 1),
					Color = MARBLE,
					Material = Enum.Material.Marble,
					CastShadow = false,
				}, plot)
			end
			P({
				Name = "Architrave",
				Size = Vector3.new(MW + 2, 2, 4),
				CFrame = O * CFrame.new(0, WALL_H + 3.2, MD / 2 - 1),
				Color = MARBLE,
				Material = Enum.Material.Marble,
			}, plot)
			for i = 1, 3 do
				P({
					Name = "Pediment" .. i,
					Size = Vector3.new((MW + 2) - i * 7, 1.3, 3.4),
					CFrame = O * CFrame.new(0, WALL_H + 4.4 + (i - 1) * 1.3, MD / 2 - 1),
					Color = MARBLE,
					Material = Enum.Material.Marble,
					CastShadow = false,
				}, plot)
			end
			-- Cornisa. Abans aixo era UNA planxa de llauto de la mida de tot
			-- l'edifici: des de l'aire es veia un rectangle mostassa enmig
			-- d'una ciutat blanca, i a mes tapava el pavello, que segons el
			-- disseny ha de quedar obert per dalt. Ara el llauto es nomes la
			-- motllura del perimetre: el museu es continua reconeixent d'una
			-- hora lluny pero llegeix com a arquitectura, no com una taca.
			-- Sense llosa: el pavello ha de quedar obert per dalt (aixi es
			-- veuen els esquelets des de fora, que es el que diu el disseny).
			-- Nomes la motllura del perimetre.
			for _, cs in ipairs({
				{ 0, (MD + 3) / 2 - 0.4, MW + 3, 0.8 },
				{ 0, -((MD + 3) / 2 - 0.4), MW + 3, 0.8 },
				{ (MW + 3) / 2 - 0.4, 0, 0.8, MD + 3 },
				{ -((MW + 3) / 2 - 0.4), 0, 0.8, MD + 3 },
			}) do
				P({
					Name = "Cornice",
					Size = Vector3.new(cs[3], 1.2, cs[4]),
					CFrame = O * CFrame.new(cs[1], WALL_H + 2.5, cs[2]),
					Color = BRASS,
					Material = Enum.Material.Slate,
					CastShadow = false,
				}, plot)
			end

			-- 6 pedestals: dues files de tres
			for k = 1, 6 do
				local col = (k - 1) % 3
				local row = math.floor((k - 1) / 3)
				local slot = P({
					Name = "Slot" .. k,
					Size = Vector3.new(5, 3, 5),
					CFrame = O * CFrame.new(-9 + col * 9, 3.7, -9 + row * 11),
					Color = MARBLE,
					Material = Enum.Material.Marble,
				}, plot)
				P({
					Name = "SlotCap",
					Size = Vector3.new(5.8, 0.35, 5.8),
					CFrame = slot.CFrame * CFrame.new(0, 1.7, 0),
					Color = BRASS,
					Material = Enum.Material.Slate,
					CastShadow = false,
				}, plot)
			end

			-- Rètol amb el nom del propietari, sobre l'arquitrau
			local sign = P({
				Name = "OwnerSign",
				Size = Vector3.new(MW - 6, 2.6, 0.5),
				CFrame = O * CFrame.new(0, WALL_H + 3.2, MD / 2 + 1.2),
				Color = DEEP_GREEN,
				Material = Enum.Material.Slate,
			}, plot)
			local gui = New("SurfaceGui", {
				Name = "SignGui",
				Face = Enum.NormalId.Front,
				LightInfluence = 0,
				PixelsPerStud = 40,
			}, sign)
			New("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "MUSEU LLIURE",
				TextColor3 = BRASS,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
			}, gui)

			-- Llum calid, que el CLAUDE.md demana un museu acollidor
			for _, lz in ipairs({ -10, 6 }) do
				local bulb = P({
					Name = "Lamp",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.1, 1.1, 1.1),
					CFrame = O * CFrame.new(0, WALL_H, lz),
					Color = Color3.fromRGB(255, 240, 205),
					Material = Enum.Material.Neon,
					CanCollide = false,
					CastShadow = false,
				}, plot)
				New("PointLight", {
					Brightness = 2,
					Range = 34,
					Color = Color3.fromRGB(255, 232, 195),
				}, bulb)
			end

			-- Arribada i tornada
			P({
				Name = "Entry",
				Size = Vector3.new(6, 0.3, 6),
				CFrame = O * CFrame.new(0, 2.3, MD / 2 - 6),
				Color = BRASS,
				Material = Enum.Material.Marble,
				CastShadow = false,
			}, plot)
			local back = P({
				Name = "BackPad",
				Size = Vector3.new(5, 0.5, 5),
				CFrame = O * CFrame.new(0, 0.4, MD / 2 + 8),
				Color = DEEP_GREEN,
				Material = Enum.Material.Marble,
			}, plot)
			New("ProximityPrompt", {
				Name = "GoCity",
				ActionText = "Tornar a la ciutat",
				ObjectText = "Sortida",
				HoldDuration = 0.3,
				MaxActivationDistance = 10,
			}, back)
			CollectionService:AddTag(back, "ToCity")

			CollectionService:AddTag(plot, "MuseumPlot")
			plot.Parent = museums
			return plot
		end

		-- Sis als patis de les illes (mirant al pas del sud) i dos a la
		-- platja (mirant cap a la ciutat).
		-- Als patis van de costat, no un darrere l'altre: en fila l'escala
		-- d'un topava amb el basament del seguent.
		local spots = {
			{ -4, -105, 0 }, -- pati de la illa NE
			{ 36, -105, 0 },
			{ -196, 105, 0 }, -- pati de la illa SW
			{ -156, 105, 0 },
			{ -4, 105, 0 }, -- pati de la illa SE
			{ 36, 105, 0 },
			{ 200, -120, 270 }, -- platja, mirant cap a la ciutat
			{ 200, 120, 270 },
		}
		for i, sp in ipairs(spots) do
			local O = cityPivot * CFrame.new(sp[1], SURFACE_Y, sp[2]) * CFrame.Angles(0, math.rad(sp[3]), 0)
			buildMuseum(O, i)
		end
	end

	if not scriptsOk then
		warn("[Museu] ATENCIO: Studio no ha deixat escriure els scripts del joc.")
		warn("[Museu] Cal donar permis d'injeccio de scripts a aquest plugin i")
		warn("[Museu] tornar a clicar el boto. Sense aixo el mon es construeix")
		warn("[Museu] pero no hi ha ni pala ni minijoc ni inventari.")
	end

	-- ═══════════════ LIGHTING ═══════════════
	Lighting.Technology = Enum.Technology.Future
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	New("Atmosphere", {
		Name = "FossilAtmosphere",
		Density = 0.3,
		Haze = 1.5,
		Color = Color3.fromRGB(200, 210, 230),
		Decay = Color3.fromRGB(130, 140, 160),
	}, Lighting)

	-- ═══════════════ RESUM ═══════════════
	print("")
	print("═══════════════════════════════════════════════")
	print("  MUSEU DE FOSSILS  ·  ZONA 1 (OBRA)")
	print("═══════════════════════════════════════════════")
	print("  · Plataforma 80x80, terra de construccio")
	print("  · Edifici NE: torre de 8 plantes (25.6 alt), petjada 16x12")
	print("    - Parets de bloc a mitja alcada a totes les plantes")
	print("    - Bastida completa (pals+baranes) als 4 costats")
	print("    - Escala de ma a la cara sud, ferro al capdamunt")
	print("  · Grua de torre de gelosia a l'oest (pal 30 + cap de torre)")
	print("    - Diagonals en ziga-zaga a les 4 cares, escala amb replans")
	print("    - Collar d'enfilada, corona de gir, cabina amb vidres")
	print("    - Ploma triangular de 22 amb carro, politges i ganxo")
	print("    - Contraploma amb torn, caseta i 2 contrapesos")
	print("")
	print("  CIUTAT (a X=2000, escala S=1.4 — canvia la constant S):")
	print("  · Planta de 7 studs i porta de ~4.8: proporcions de jugador")
	print("  · Quadricula: 2x2 illes + 1 illa llarga, amb carrers al mig")
	print("  · Illa de dalt a l'esquerra = ZONA D'OBRES, amb tanca")
	print("  · Placa central empedrada amb SPAWN, fanals i arbres")
	print("  · Vora est: passeig, platja i mar amb 68 punts d'excavacio")
	print("")
	print("  OSSOS (a ReplicatedStorage/Bones):")
	print("  · 4 esquelets x 5 peces = 20 models, amb tag BonePiece")
	print("  · Crani EPIC · Cua RARA · Columna i extremitats COMUNES")
	print("  · Galeria de 20 pedestals a la placa per veure-los")
	print("")
	print("  MINIJOC D EXCAVACIO:")
	print("  · La pala es dona sola en entrar (i al suport de l obra)")
	print("  · Barra amb linia que rebota; 3 intents")
	print("  · Verd fort +50%, verd fluix +30%, fora 0 (max 150%)")
	print("  · El servidor recalcula la posicio: el client no puntua")
	print("  · L os trobat va al perfil del servidor + panell d inventari")
	print("  · DataStore amb session-lock, autosave 120s i BindToClose")
	print("")
	print("  MUSEU:")
	print("  · 8 pavellons: 6 als patis de les illes, 2 a la platja")
	print("  · Se n assigna un en entrar; el retol porta el teu nom")
	print("  · Muntar esquelet = gastar les 5 peces, exposar = pedestal")
	print("  · Renda per minut amb sostre de 120 i 8 h offline")
	print("  · Porta a la placa per anar-hi i tornar")
	print("")
	print("  COMERC:")
	print("  · Proposar canvi a un jugador a menys de 40 studs")
	print("  · Oferta lliure; qualsevol canvi esborra les confirmacions")
	print("  · Escrow atomic: validacio sencera, despres mutacio sencera")
	print("═══════════════════════════════════════════════")
	print("")
end

if plugin then
	local toolbar = plugin:CreateToolbar("Museu de Fossils")
	local button = toolbar:CreateButton("Construir Zona 1", "Construeix la zona de construcció", "rbxasset://textures/Cursors/DragLockedCursor.png")
	button.Click:Connect(Install)
else
	Install()
end
