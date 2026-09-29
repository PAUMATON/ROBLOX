-- ═══════════════════════════ 03 · CASES ═══════════════════════════
-- Quatre tipus: "town" (casa de poble), "cottage" (caseta de camp),
-- "villa" (vila amb torre) i "beach" (casa de platja amb terrat).
-- Cada casa té el seu Random amb llavor fixa: surt igual cada vegada.
-- (Les cases es queden tradicionals a propòsit: és el que més agrada.
--  El que és modern és el mobiliari de carrer, la plaça, la platja i l'obra.)
local F = folder("Houses", WORLD)
local FH = 8 -- alçada d'una planta (jugador = 5)
local STONE = C(186, 178, 162)

-- ── cares d'un volum: centre (a terra), normal, tangent, llargada ──
local function face(cf, w, d, which)
	if which == "F" then
		return (cf * CF(0, 0, -d / 2)).Position, cf.LookVector, cf.RightVector, w
	elseif which == "B" then
		return (cf * CF(0, 0, d / 2)).Position, -cf.LookVector, -cf.RightVector, w
	elseif which == "L" then
		return (cf * CF(-w / 2, 0, 0)).Position, -cf.RightVector, cf.LookVector, d
	end
	return (cf * CF(w / 2, 0, 0)).Position, cf.RightVector, -cf.LookVector, d
end
local function slots(len, spacing)
	local k = math.max(1, math.floor((len - 3) / spacing))
	local t = {}
	for i = 1, k do
		t[i] = (i - (k + 1) / 2) * (len / k)
	end
	return t
end

-- ── finestra: marc, vidre, creu, ampit; persianes i jardinera opcionals ──
local function window(m, pos, n, tg, o)
	local w, h = o.w or 3.4, o.h or 4.6
	local frame = o.frame or COL.cream
	panel(V3(w + 0.8, h + 0.8, 0.3), pos + n * 0.15, n, frame, M.SmoothPlastic, m, true)
	local g = panel(V3(w, h, 0.2), pos + n * 0.28, n, COL.glass, M.SmoothPlastic, m, true)
	g.Reflectance = 0.25
	panel(V3(0.3, h, 0.15), pos + n * 0.4, n, frame, M.SmoothPlastic, m, true)
	panel(V3(w, 0.3, 0.15), pos + n * 0.4 + UP * (h * 0.12), n, frame, M.SmoothPlastic, m, true)
	panel(V3(w + 1.4, 0.45, 1.0), pos + n * 0.5 - UP * (h / 2 + 0.55), n, STONE, M.SmoothPlastic, m, true)
	if o.shut then
		for s = -1, 1, 2 do
			local sp = panel(V3(w * 0.55, h + 0.5, 0.25), pos + tg * (s * (w / 2 + 0.4 + w * 0.275)) + n * 0.2, n, o.shut, M.WoodPlanks, m, true)
			sp.CastShadow = true
		end
	end
	if o.flowers then
		local bp = pos + n * 0.9 - UP * (h / 2 + 0.2)
		panel(V3(w + 0.8, 0.9, 1.1), bp, n, o.box or COL.woodDark, M.WoodPlanks, m, true)
		for k = -1, 1 do
			Ball(1.25, bp + UP * 0.75 + tg * (k * w * 0.32), FLOWERS[o.rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, m, true)
		end
	end
end

-- finestra rodona (golfes)
local function roundWindow(m, pos, n, dia)
	local c = CFrame.lookAt(pos + n * 0.2, pos + n) * CFrame.Angles(0, rad(90), 0)
	Cyl(0.3, dia + 0.8, c, COL.cream, M.SmoothPlastic, m, true)
	local g = Cyl(0.35, dia, CFrame.lookAt(pos + n * 0.3, pos + n) * CFrame.Angles(0, rad(90), 0), COL.glass, M.SmoothPlastic, m, true)
	g.Reflectance = 0.25
end

-- ── porta amb marc de pedra, finestró, pom de llautó, esglaó i llumeta ──
local function door(m, pos, n, tg, color, rng)
	panel(V3(6, 8.8, 0.4), pos + UP * 4.4 + n * 0.2, n, STONE, M.SmoothPlastic, m, true)
	panel(V3(4.4, 7, 0.3), pos + UP * 3.5 + n * 0.4, n, color, M.WoodPlanks, m, true)
	local tr = panel(V3(4.4, 1.1, 0.2), pos + UP * 7.75 + n * 0.35, n, COL.glass, M.SmoothPlastic, m, true)
	tr.Reflectance = 0.25
	Ball(0.55, pos + UP * 3.4 + n * 0.65 + tg * 1.5, COL.brass, M.Metal, m, true)
	P(V3(6.6, 0.6, 2.4), CFrame.lookAt(pos + n * 1.2 + UP * 0.3, pos + n * 2 + UP * 0.3), STONE, M.SmoothPlastic, m)
	local lamp = panel(V3(0.9, 1.3, 0.9), pos + UP * 6.2 + n * 0.8 + tg * 3.8, n, C(255, 236, 196), M.Neon, m, true)
	panel(V3(1.2, 0.3, 1.2), pos + UP * 7.0 + n * 0.8 + tg * 3.8, n, COL.iron, M.Metal, m, true)
	if rng:NextNumber() < 0.5 then
		local pl = Instance.new("PointLight")
		pl.Range = 12
		pl.Brightness = 0.8
		pl.Color = C(255, 220, 170)
		pl.Parent = lamp
	end
end

-- balcó de ferro davant d'una finestra de pis
local function balcony(m, pos, n, tg, width)
	P(V3(width, 0.5, 2.8), CFrame.lookAt(pos + n * 1.4 - UP * 0.25, pos + n * 3 - UP * 0.25), STONE, M.SmoothPlastic, m)
	local top = pos + n * 2.7 + UP * 3.1
	panel(V3(width, 0.3, 0.3), top, n, COL.iron, M.Metal, m, true)
	panel(V3(width, 0.2, 0.2), pos + n * 2.7 + UP * 0.6, n, COL.iron, M.Metal, m, true)
	local nb = math.floor(width / 1.1)
	for k = 0, nb do
		local p = pos + n * 2.7 + tg * (-width / 2 + k * width / nb) + UP * 1.85
		P(V3(0.18, 2.6, 0.18), CF(p), COL.iron, M.Metal, m, true)
	end
	for s = -1, 1, 2 do
		local a = pos + tg * (s * width / 2) + UP * 3.1 + n * 0.2
		beam(a, a + n * 2.5, 0.25, COL.iron, M.Metal, m, true)
	end
end

local function chimney(m, cf, x, z, baseY, h)
	P(V3(2.6, h, 2.6), cf * CF(x, baseY + h / 2, z), COL.brick, M.Brick, m)
	P(V3(3.2, 0.6, 3.2), cf * CF(x, baseY + h + 0.3, z), STONE, M.SmoothPlastic, m)
	for s = -1, 1, 2 do
		VCyl(1.0, 0.7, (cf * CF(x + s * 0.6, baseY + h + 1.1, z)).Position, C(170, 100, 70), M.SmoothPlastic, m, true)
	end
end

-- ── rètol de botiga amb tendal de ratlles ──
local function shopFront(m, pos, n, tg, width, name, rng, noAwning)
	panel(V3(width, 6.4, 0.3), pos + UP * 3.6 + n * 0.3, n, COL.green, M.SmoothPlastic, m, true)
	local g = panel(V3(width - 1.4, 5.2, 0.2), pos + UP * 3.5 + n * 0.45, n, COL.glass, M.SmoothPlastic, m, true)
	g.Reflectance = 0.25
	local sign = panel(V3(width - 1, 1.8, 0.4), pos + UP * 7.6 + n * 0.5, n, COL.green, M.SmoothPlastic, m, true)
	Label(sign, name, COL.brass, Enum.Font.FredokaOne)
	panel(V3(width - 0.6, 0.25, 0.3), pos + UP * 8.6 + n * 0.55, n, COL.brass, M.Metal, m, true)
	if noAwning then
		return
	end
	-- tendal
	local stripes = 6
	local sw = (width - 1) / stripes
	for k = 1, stripes do
		local ap = pos + tg * ((k - (stripes + 1) / 2) * sw) + UP * 9.6 + n * 2.1
		local a = P(V3(sw + 0.02, 0.25, 4.2), CFrame.lookAt(ap, ap + n) * CFrame.Angles(rad(-22), 0, 0), k % 2 == 0 and COL.cream or COL.green, M.SmoothPlastic, m, true)
		a.CastShadow = true
	end
	panel(V3(width - 1, 0.8, 0.25), pos + UP * 8.45 + n * 4.05, n, COL.green, M.SmoothPlastic, m, true)
end

-- ═══════════════════════════ TIPUS DE CASA ═══════════════════════════
local function houseTown(cf, w, d, floors, rng, opt)
	local m = Instance.new("Model")
	m.Name = opt.shop and ("Shop_" .. opt.shop) or "TownHouse"
	local wall = PLASTERS[rng:NextInteger(1, #PLASTERS)]
	local shut = SHUTTERS[rng:NextInteger(1, #SHUTTERS)]
	local roofC = ROOFS[rng:NextInteger(1, #ROOFS)]
	local Hw = floors * FH + 1
	local A = opt.arcade or 0 -- fondària dels porxos (els pisos volen per sobre)
	-- sòcol: 0,25 per fora de la paret. Amb +0,4 les seves cares quedaven al
	-- mateix pla que les de fora de les pilastres de cantonada (w/2 - 0,4 + 0,6)
	-- i feien pampallugues a totes les cantonades
	P(V3(w + 0.5, 1.4, d + 0.5), cf * CF(0, 0.7, 0), STONE, M.SmoothPlastic, m)
	P(V3(w, Hw, d), cf * CF(0, Hw / 2, 0), wall, M.SmoothPlastic, m)
	if A > 0 then
		local hU = Hw - (FH + 1)
		P(V3(w, hU, A), cf * CF(0, FH + 1 + hU / 2, -d / 2 - A / 2), wall, M.SmoothPlastic, m)
		local nb = math.max(2, math.floor(w / 6.5 + 0.5))
		local bw = w / nb
		local zf = -d / 2 - A + 0.9
		for k = 0, nb do
			local x = math.clamp(-w / 2 + k * bw, -w / 2 + 0.9, w / 2 - 0.9)
			P(V3(1.7, FH + 1, 1.7), cf * CF(x, (FH + 1) / 2, zf), COL.cream, M.SmoothPlastic, m)
			P(V3(2.3, 0.6, 2.3), cf * CF(x, 0.3, zf), STONE, M.SmoothPlastic, m, true)
			P(V3(2.3, 0.6, 2.3), cf * CF(x, FH + 0.6, zf), STONE, M.SmoothPlastic, m, true)
		end
		for k = 0, nb - 1 do
			local xa = -w / 2 + k * bw
			local run = math.min(2.6, bw / 2 - 1)
			for sgn = -1, 1, 2 do
				local xx = sgn < 0 and (xa + 0.85 + run / 2) or (xa + bw - 0.85 - run / 2)
				local rot = CFrame.Angles(0, sgn < 0 and -math.pi / 2 or math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi)
				Wd(V3(1.2, 2.2, run), cf * CF(xx, FH + 1 - 1.1, zf) * rot * WEDGE_FIX, COL.cream, M.SmoothPlastic, m, true)
			end
		end
		P(V3(w, 0.1, A), cf * CF(0, 0.66, -d / 2 - A / 2), C(206, 190, 164), M.SmoothPlastic, m, true)
		for s2 = -1, 1, 2 do
			P(V3(1.3, Hw - FH - 1, 1.3), cf * CF(s2 * (w / 2 - 0.45), FH + 1 + (Hw - FH - 1) / 2, -d / 2 - A + 0.45), COL.cream, M.SmoothPlastic, m, true)
		end
		-- fanalets penjats dins els porxos
		for k = 0, nb - 1 do
			local lp = cf * CF(-w / 2 + (k + 0.5) * bw, FH - 0.8, -d / 2 - A / 2)
			P(V3(0.8, 1.2, 0.8), lp, C(255, 236, 196), M.Neon, m, true)
			P(V3(0.12, 1.4, 0.12), lp * CF(0, 1.2, 0), COL.iron, M.Metal, m, true)
		end
	end
	for f = 1, floors - 1 do
		P(V3(w + 0.3, 0.5, d + A + 0.3), cf * CF(0, 1 + f * FH, -A / 2), COL.cream, M.SmoothPlastic, m)
	end
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		P(V3(1.3, Hw, 1.3), cf * CF(q[1] * (w / 2 - 0.45), Hw / 2, q[2] * (d / 2 - 0.45)), COL.cream, M.SmoothPlastic, m, true)
	end
	P(V3(w + 1.3, 1.0, d + A + 1.3), cf * CF(0, Hw - 0.2, -A / 2), COL.cream, M.SmoothPlastic, m)
	hipRoof(cf * CF(0, Hw + 0.3, -A / 2), w, d + A, rad(rng:NextNumber(27, 33)), 1.4, roofC, roofC == COL.slate and M.Slate or M.SmoothPlastic, COL.cream, m)
	chimney(m, cf, w * 0.25 * (rng:NextNumber() < 0.5 and -1 or 1), d * 0.18, Hw, 5 + math.min(w, d) * 0.28)
	-- façanes
	for _, which in ipairs({ "F", "L", "R", "B" }) do
		if not (opt.blind and opt.blind[which]) then
			local c, n, tg, len = face(cf, w, d, which)
			local sl = slots(len, 7)
			local doorAt = which == "F" and (#sl >= 3 and math.ceil(#sl / 2) or 1) or -1
			for i, o in ipairs(sl) do
				local base = c + tg * o
				-- planta baixa
				if which == "F" and opt.shop then
					if i == 1 then
						shopFront(m, c, n, tg, math.min(len - 3, 16), opt.shop, rng, A > 0)
					end
				elseif i == doorAt then
					door(m, base + UP * 1.2, n, tg, shut, rng)
				else
					window(m, base + UP * (1 + FH * 0.5 + 0.3), n, tg, { shut = which ~= "B" and shut or nil })
				end
				-- pisos
				local fsh = (which == "F" and A > 0) and n * A or Vector3.zero
				for f = 1, floors - 1 do
					local wp = base + fsh + UP * (1 + f * FH + FH * 0.5 + 0.3)
					local balc = which == "F" and f == 1 and opt.balcony and i == doorAt
					window(m, wp, n, tg, {
						shut = which ~= "B" and shut or nil,
						flowers = which == "F" and not balc and f == 1,
						rng = rng,
						h = balc and 6.2 or 4.6,
					})
					if balc then
						balcony(m, base + fsh + UP * (1 + f * FH + 0.5), n, tg, 8)
					end
				end
			end
		end
	end
	m.Parent = F
	return m
end

local function houseCottage(cf, w, d, rng)
	local m = Instance.new("Model")
	m.Name = "Cottage"
	local brick = rng:NextNumber() < 0.55
	local wall = brick and COL.brick or PLASTERS[rng:NextInteger(1, #PLASTERS)]
	local shut = SHUTTERS[rng:NextInteger(1, #SHUTTERS)]
	local roofC = rng:NextNumber() < 0.5 and COL.slate or COL.terracotta
	local Hw = FH + 1.5
	-- sòcol: veure houseTown (no al pla de les pilastres)
	P(V3(w + 0.5, 1.4, d + 0.5), cf * CF(0, 0.7, 0), STONE, M.SmoothPlastic, m)
	P(V3(w, Hw, d), cf * CF(0, Hw / 2, 0), wall, brick and M.Brick or M.SmoothPlastic, m)
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		-- 0,1 més altes que la paret: el cap queda dins de la teulada i no al
		-- mateix pla que el de la paret (pampallugues)
		P(V3(1.2, Hw + 0.1, 1.2), cf * CF(q[1] * (w / 2 - 0.4), (Hw + 0.1) / 2, q[2] * (d / 2 - 0.4)), COL.cream, M.SmoothPlastic, m, true)
	end
	local pitch = rad(rng:NextNumber(38, 44))
	local gableC = brick and COL.cream or wall
	local h = gableRoof(cf * CF(0, Hw, 0), w, d, pitch, 1.8, 1.4, roofC, roofC == COL.slate and M.Slate or M.SmoothPlastic, gableC, M.SmoothPlastic, COL.cream, m)
	chimney(m, cf, -w * 0.3, d * 0.1, Hw, h + 3)
	-- lucana (dormer) a la vessant del davant
	do
		local zf = -d / 2 + 2.2
		local yb = Hw + (d / 2 - 2.2) * 0 + 2.2 * math.tan(pitch)
		local dcf = cf * CF(0, 0, zf + 2.5)
		P(V3(5.2, 5, 5), dcf * CF(0, yb + 1.5, 0), gableC, M.SmoothPlastic, m)
		gableRoof(dcf * CF(0, yb + 4, 0) * CFrame.Angles(0, math.pi / 2, 0), 5, 5.2, rad(45), 0.8, 0.6, roofC, roofC == COL.slate and M.Slate or M.SmoothPlastic, gableC, M.SmoothPlastic, COL.cream, m)
		local c, n, tg = face(dcf, 5.2, 5, "F")
		window(m, c + UP * (yb + 1.6), n, tg, { w = 2.6, h = 3.0 })
	end
	-- façana: porta al mig i finestres amb jardinera
	local c, n, tg, len = face(cf, w, d, "F")
	door(m, c + UP * 1.2, n, tg, shut, rng)
	for s = -1, 1, 2 do
		window(m, c + tg * (s * len * 0.3) + UP * 5.6, n, tg, { shut = shut, flowers = true, rng = rng })
	end
	-- porxo sobre la porta
	local pc = c + n * 2.6
	for s = -1, 1, 2 do
		P(V3(0.7, 8.2, 0.7), CF(pc + tg * (s * 3.2) + UP * 4.1), COL.cream, M.WoodPlanks, m)
	end
	P(V3(8.2, 0.5, 3.6), CFrame.lookAt(pc + UP * 8.5, pc + UP * 8.5 + n) * CFrame.Angles(rad(-14), 0, 0), roofC, M.SmoothPlastic, m)
	-- finestres rodones a les golfes i finestres laterals
	for _, which in ipairs({ "L", "R" }) do
		local c2, n2, tg2 = face(cf, w, d, which)
		roundWindow(m, c2 + UP * (Hw + h * 0.35), n2, 2.4)
		window(m, c2 + UP * 5.6, n2, tg2, { shut = shut })
	end
	local c3, n3, tg3 = face(cf, w, d, "B")
	window(m, c3 + UP * 5.6, n3, tg3, {})
	m.Parent = F
	return m
end

local function houseVilla(cf, w, d, rng)
	local m = Instance.new("Model")
	m.Name = "Villa"
	local wall = PLASTERS[rng:NextInteger(1, #PLASTERS)]
	local shut = SHUTTERS[rng:NextInteger(1, #SHUTTERS)]
	local roofC = ROOFS[rng:NextInteger(1, #ROOFS)]
	local rmat = roofC == COL.slate and M.Slate or M.SmoothPlastic
	local Hw = 2 * FH + 1
	-- sòcol: veure houseTown (no al pla de les pilastres)
	P(V3(w + 0.5, 1.4, d + 0.5), cf * CF(0, 0.7, 0), STONE, M.SmoothPlastic, m)
	P(V3(w, Hw, d), cf * CF(0, Hw / 2, 0), wall, M.SmoothPlastic, m)
	P(V3(w + 0.3, 0.5, d + 0.3), cf * CF(0, 1 + FH, 0), COL.cream, M.SmoothPlastic, m)
	P(V3(w + 1.3, 1.0, d + 1.3), cf * CF(0, Hw - 0.2, 0), COL.cream, M.SmoothPlastic, m)
	hipRoof(cf * CF(0, Hw + 0.3, 0), w, d, rad(28), 1.5, roofC, rmat, COL.cream, m)
	-- torre a la cantonada del davant
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local tw = 8
	local tcf = cf * CF(side * (w / 2 - tw / 2 + 1), 0, -d / 2 + tw / 2 - 1)
	local Ht = Hw + FH
	P(V3(tw, Ht, tw), tcf * CF(0, Ht / 2, 0), wall, M.SmoothPlastic, m)
	P(V3(tw + 1, 0.9, tw + 1), tcf * CF(0, Ht - 0.2, 0), COL.cream, M.SmoothPlastic, m)
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		P(V3(1.1, Ht, 1.1), tcf * CF(q[1] * (tw / 2 - 0.35), Ht / 2, q[2] * (tw / 2 - 0.35)), COL.cream, M.SmoothPlastic, m, true)
	end
	Pyramid(tcf * CF(0, Ht + 0.3, 0), tw + 2, 8, roofC, rmat, m)
	VCyl(2.2, 0.3, (tcf * CF(0, Ht + 9.3, 0)).Position, COL.brass, M.Metal, m, true)
	Ball(0.9, (tcf * CF(0, Ht + 10.6, 0)).Position, COL.brass, M.Metal, m, true)
	for _, which in ipairs({ "F", "L", "R" }) do
		local c, n, tg = face(tcf, tw, tw, which)
		window(m, c + UP * (Hw + FH * 0.5), n, tg, { shut = shut, w = 3.0, h = 4.4 })
	end
	-- Una finestra de la casa (amb l'ampit d'1 de fondària i els finestrons,
	-- fins a 4 de costat) no pot tocar la torre. La torre surt 1 per davant i
	-- 1 pel costat: l'ampit hi quedava enterrat amb la cara al mateix pla que
	-- la de la torre, i feia pampallugues.
	local function hitsTower(base, n, tg)
		for _, a in ipairs({ -4.1, 0, 4.1 }) do
			for _, b in ipairs({ 0.05, 1.1 }) do
				local l = tcf:PointToObjectSpace(base + tg * a + n * b)
				if math.abs(l.X) < tw / 2 + 0.05 and math.abs(l.Z) < tw / 2 + 0.05 then
					return true
				end
			end
		end
		return false
	end
	-- façanes principals
	for _, which in ipairs({ "F", "L", "R", "B" }) do
		local c, n, tg, len = face(cf, w, d, which)
		local sl = slots(len, 7.5)
		local doorAt = which == "F" and math.ceil(#sl / 2) or -1
		for i, o in ipairs(sl) do
			local base = c + tg * o
			local inTower = hitsTower(base, n, tg)
			if not inTower then
				if i == doorAt then
					door(m, base + UP * 1.2, n, tg, shut, rng)
					-- porxo amb dues columnes i balcó a sobre
					for s = -1, 1, 2 do
						VCyl(FH, 1.2, base + n * 3.2 + tg * (s * 3.6) + UP * (1 + FH / 2), COL.cream, M.SmoothPlastic, m)
					end
					P(V3(9, 0.8, 4.2), CFrame.lookAt(base + n * 2.1 + UP * (FH + 1.3), base + n * 3 + UP * (FH + 1.3)), COL.cream, M.SmoothPlastic, m)
					-- +1,75 i no +1,7: el terra del balcó queda 0,05 per sobre
					-- de la llosa del porxo (al mateix pla feia pampallugues)
					balcony(m, base + n * 1.3 + UP * (FH + 1.75), n, tg, 8.6)
				else
					window(m, base + UP * (1 + FH * 0.5), n, tg, { shut = which ~= "B" and shut or nil, h = 5.4 })
				end
				window(m, base + UP * (1 + FH * 1.5 + 0.3), n, tg, { shut = which ~= "B" and shut or nil, flowers = which == "F", rng = rng })
			end
		end
	end
	m.Parent = F
	return m
end

local function houseBeach(cf, w, d, rng)
	local m = Instance.new("Model")
	m.Name = "BeachHouse"
	local wall = rng:NextNumber() < 0.6 and COL.cream or PLASTERS[rng:NextInteger(1, 4)]
	local shut = rng:NextNumber() < 0.5 and C(84, 124, 136) or COL.green
	local Hw = 2 * FH + 1
	-- sòcol: veure houseTown (no al pla de les pilastres)
	P(V3(w + 0.5, 1.4, d + 0.5), cf * CF(0, 0.7, 0), STONE, M.SmoothPlastic, m)
	P(V3(w, Hw, d), cf * CF(0, Hw / 2, 0), wall, M.SmoothPlastic, m)
	P(V3(w + 0.3, 0.5, d + 0.3), cf * CF(0, 1 + FH, 0), COL.bone, M.SmoothPlastic, m)
	-- terrat amb ampit
	for _, e in ipairs({ { 0, -d / 2 + 0.4, w, 0.8 }, { 0, d / 2 - 0.4, w, 0.8 }, { -w / 2 + 0.4, 0, 0.8, d }, { w / 2 - 0.4, 0, 0.8, d } }) do
		P(V3(e[3] + 0.4, 2.6, e[4] + 0.4), cf * CF(e[1], Hw + 1.3, e[2]), wall, M.SmoothPlastic, m)
		P(V3(e[3] + 0.9, 0.4, e[4] + 0.9), cf * CF(e[1], Hw + 2.8, e[2]), COL.bone, M.SmoothPlastic, m, true)
	end
	P(V3(w - 1.6, 0.3, d - 1.6), cf * CF(0, Hw + 0.15, 0), C(196, 150, 110), M.WoodPlanks, m)
	-- pèrgola de fusta i para-sol
	local px = w * 0.22
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		P(V3(0.6, 6, 0.6), cf * CF(px + q[1] * 3.2, Hw + 3, q[2] * (d / 2 - 2.5)), COL.wood, M.WoodPlanks, m)
	end
	for k = -3, 3 do
		P(V3(7.2, 0.4, 0.5), cf * CF(px, Hw + 6.2, k * (d - 5) / 7), COL.wood, M.WoodPlanks, m, true)
	end
	local ux, uz = -w * 0.2, -d * 0.1
	VCyl(5.5, 0.3, (cf * CF(ux, Hw + 2.75, uz)).Position, COL.bone, M.SmoothPlastic, m, true)
	Pyramid(cf * CF(ux, Hw + 5, uz) * CFrame.Angles(0, rad(45), 0), 7, 1.8, COL.green, M.SmoothPlastic, m, { COL.green, COL.cream, COL.green, COL.cream })
	for s = -1, 1, 2 do
		P(V3(2, 0.5, 5), cf * CF(ux + s * 2.6, Hw + 0.8, uz + 3.8), COL.cream, M.SmoothPlastic, m)
	end
	-- façanes: finestrals grans a baix, finestres amb porticons a dalt
	for _, which in ipairs({ "F", "L", "R", "B" }) do
		local c, n, tg, len = face(cf, w, d, which)
		local sl = slots(len, 7.5)
		local doorAt = which == "F" and math.ceil(#sl / 2) or -1
		for i, o in ipairs(sl) do
			local base = c + tg * o
			if i == doorAt then
				door(m, base + UP * 1.2, n, tg, shut, rng)
			else
				window(m, base + UP * (1 + FH * 0.5), n, tg, { w = 4.2, h = 5.4, frame = COL.bone })
			end
			window(m, base + UP * (1 + FH * 1.5 + 0.3), n, tg, { shut = shut, frame = COL.bone, flowers = which == "F", rng = rng, box = COL.bone })
		end
	end
	-- porxo de fusta al davant
	local c, n, tg, len = face(cf, w, d, "F")
	P(V3(len, 0.6, 5), CFrame.lookAt(c + n * 2.5 + UP * 0.9, c + n * 4 + UP * 0.9), C(196, 150, 110), M.WoodPlanks, m)
	for k = -1, 1, 2 do
		P(V3(0.5, 3, 0.5), CF(c + n * 4.8 + tg * (k * (len / 2 - 0.4)) + UP * 2.4), COL.bone, M.SmoothPlastic, m, true)
	end
	panel(V3(len, 0.4, 0.4), c + n * 4.8 + UP * 3.8, n, COL.bone, M.SmoothPlastic, m, true)
	m.Parent = F
	return m
end

-- ── jardinet del davant: tanca de fusta, camí i flors ──
local function frontGarden(cf, lotW, depth, rng)
	local m = Instance.new("Model")
	m.Name = "Garden"
	local c, n, tg = face(cf, lotW, 0, "F")
	local gate = 3
	for s = -1, 1, 2 do
		local a0, a1 = gate, lotW / 2 - 0.4
		local mid = c + tg * (s * (a0 + a1) / 2)
		for _, y in ipairs({ 1.2, 2.6 }) do
			P(V3(a1 - a0, 0.3, 0.25), CFrame.lookAt(mid + UP * y, mid + UP * y + n), COL.cream, M.WoodPlanks, m, true)
		end
		local k = a0
		while k <= a1 do
			P(V3(0.5, 3.4, 0.3), CFrame.lookAt(c + tg * (s * k) + UP * 1.7, c + tg * (s * k) + UP * 1.7 + n), COL.cream, M.WoodPlanks, m, true)
			k += 1.3
		end
		-- parterre de flors
		for q = 1, 3 do
			local fp = c + tg * (s * rng:NextNumber(4.5, lotW / 2 - 2)) - n * rng:NextNumber(1.5, depth - 1.5)
			Ball(rng:NextNumber(1.8, 2.6), fp + UP * 0.7, COL.leafDark, M.SmoothPlastic, m, true)
			Ball(0.9, fp + UP * 1.7, FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, m, true)
		end
	end
	P(V3(2.8, 0.25, depth), CFrame.lookAt(c - n * (depth / 2) + UP * 0.12, c - n * depth + UP * 0.12), STONE, M.SmoothPlastic, m, true)
	m.Parent = F
end

-- ═══════════════════════════ REPARTIMENT PER ILLES ═══════════════════════════
local SHOP_NAMES = { "DINO DINER", "FOSSIL TRADE", "MAMMOTH CAFÉ", "ICE AGE GELATO", "JURASSIC BOOKS", "AMMONITE BAKERY", "SOUVENIRS", "TOOLS & BRUSHES" }
local shopIdx = 0
local count = 0
local SIDE = {
	N = function(b)
		return b[1], b[2], b[3], V3(0, 0, -1)
	end,
	S = function(b)
		return b[1], b[2], b[4], V3(0, 0, 1)
	end,
	W = function(b)
		return b[3], b[4], b[1], V3(-1, 0, 0)
	end,
	E = function(b)
		return b[3], b[4], b[2], V3(1, 0, 0)
	end,
}
local LOT_D = 24
local PZ = LAYOUT.PLAZA
local OB = LAYOUT.OBRA
local function facesPlaza(sideCh, fixed, a0, a1)
	if sideCh == "E" then
		return math.abs(fixed - PZ.x0) < 1 and a1 > PZ.z0 and a0 < PZ.z1
	elseif sideCh == "W" then
		return math.abs(fixed - PZ.x1) < 1 and a1 > PZ.z0 and a0 < PZ.z1
	elseif sideCh == "S" then
		return math.abs(fixed - PZ.z0) < 1 and a1 > PZ.x0 and a0 < PZ.x1
	elseif sideCh == "N" then
		return math.abs(fixed - PZ.z1) < 1 and a1 > PZ.x0 and a0 < PZ.x1
	end
	return false
end
for bi, b in ipairs(LAYOUT.BLOCKS) do
	local sides = b[5]
	local nearPlaza = b[2] > PZ.x0 - 30 and b[1] < PZ.x1 + 30 and b[4] > PZ.z0 - 30 and b[3] < PZ.z1 + 30
	local beachBlock = b[2] >= 160
	for sideCh in sides:gmatch(".") do
		local a0, a1, fixed, nrm = SIDE[sideCh](b)
		local horiz = sideCh == "N" or sideCh == "S"
		if not horiz and (sides:find("N") or sides:find("S")) then
			if sides:find("N") then
				a0 += LOT_D
			end
			if sides:find("S") then
				a1 -= LOT_D
			end
		end
		local len = a1 - a0
		local plazaSide = facesPlaza(sideCh, fixed, a0, a1)
		if len >= 18 then
			local nLots = math.max(1, math.floor(len / (plazaSide and 22 or 25)))
			local lotW = len / nLots
			for li = 1, nLots do
				local ac = a0 + (li - 0.5) * lotW
				local front = horiz and V3(ac, 0, fixed) or V3(fixed, 0, ac)
				local seed = math.floor(ac * 7 + fixed * 13 + bi * 101)
				local rng = Random.new(seed)
				local kind
				if plazaSide then
					kind = "shop"
				elseif beachBlock and sideCh == "E" then
					kind = "beach"
				elseif nearPlaza then
					kind = "town"
				else
					local r = rng:NextNumber()
					kind = r < 0.36 and "cottage" or (r < 0.6 and "villa" or "town")
				end
				local terraced = kind == "shop" or (kind == "town" and nearPlaza)
				local w = terraced and (lotW - 0.6) or math.min(lotW - rng:NextNumber(4, 7), 22)
				local d = kind == "cottage" and rng:NextNumber(14, 16) or rng:NextNumber(15, 18)
				local arcade = kind == "shop" and 5 or 0
				local setback = kind == "shop" and 0.5 or (terraced and 1.5 or (kind == "beach" and 7 or rng:NextNumber(5.5, 7)))
				local center = front - nrm * (setback + arcade + d / 2)
				-- cap casa sobre un museu ni dins l'obra
				local blocked = inRects(center.X, center.Z, LAYOUT.MUSEUM_RECTS, 9)
					or (center.X > OB.x0 - 12 and center.X < OB.x1 + 20 and center.Z > OB.z0 - 12 and center.Z < OB.z1 + 12)
				if not blocked then
					local cf = CFrame.lookAt(center, center + nrm)
					local blind = terraced and { L = li > 1, R = li < nLots } or nil
					if kind == "shop" then
						shopIdx += 1
						houseTown(cf, w, d, 3, rng, { shop = SHOP_NAMES[(shopIdx - 1) % #SHOP_NAMES + 1], balcony = true, blind = blind, arcade = arcade })
					elseif kind == "town" then
						houseTown(cf, w, d, rng:NextInteger(2, 3), rng, { balcony = rng:NextNumber() < 0.6, blind = blind })
					elseif kind == "cottage" then
						houseCottage(cf, w, d, rng)
					elseif kind == "villa" then
						houseVilla(cf, math.max(w, 18), d, rng)
					else
						houseBeach(cf, w, d, rng)
					end
					if not terraced then
						local gcf = CFrame.lookAt(front - nrm * 0.2, front - nrm * 0.2 + nrm)
						frontGarden(gcf, lotW - 1, setback - 0.6, rng)
					end
					count += 1
				end
			end
		end
	end
end
-- dues cases a l'est de l'obra, entre la tanca i el carrer (on hi havia el pati d'obra)
do
	local E = LAYOUT.EAST_LOTS
	local nrm = V3(1, 0, 0)
	local lotW = (E.z1 - E.z0) / 2
	for li = 1, 2 do
		local rng = Random.new(4242 + li)
		local front = V3(E.x1, 0, E.z0 + (li - 0.5) * lotW)
		local w = lotW - rng:NextNumber(2.5, 3.5)
		local d = rng:NextNumber(14, 15.5)
		local setback = rng:NextNumber(5.5, 6.5)
		local center = front - nrm * (setback + d / 2)
		local cf = CFrame.lookAt(center, center + nrm)
		if li == 1 then
			houseCottage(cf, w, d, rng)
		else
			houseTown(cf, w, d, 2, rng, { balcony = true })
		end
		frontGarden(CFrame.lookAt(front - nrm * 0.2, front - nrm * 0.2 + nrm), lotW - 1, setback - 0.6, rng)
		count += 1
	end
end
print(("Cases: %d (botigues %d)"):format(count, shopIdx))
