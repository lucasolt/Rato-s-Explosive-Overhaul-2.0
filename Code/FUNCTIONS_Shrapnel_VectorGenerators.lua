---- Locais de modulo: evitam um lookup de global por chamada dentro dos lacos quentes
---- (um estilhaco de HE_Grenade roda isto 700 vezes por explosao).
local sin, cos, acos, sqrt, tan, pi = math.sin, math.cos, math.acos, math.sqrt, math.tan, math.pi
local random = math.random

---- PERF (C4): invariantes do cone hasteados para fora do laco.
function generateShrapnelPositionsInCone(numPositions, radius, center, args)
	local positions = {}
	local n = 0

	local angle_radians = args.angle_deg * pi / 180
	---- so a chamada de tan sai do laco; a ordem das multiplicacoes de h continua sendo a
	---- original (random * radius * tan), para nao mexer no arredondamento.
	local tan_half = tan(angle_radians / 2)
	local radius_sq = radius * radius
	local two_pi = 2 * pi
	local cx, cy, cz = center:x(), center:y(), center:z()
	local axis_x_p, axis_z_p = point(1, 0, 0), point(0, 0, 1)

	local spread_p = center:SetZ(cz + args.radius)
	spread_p = RotateAxis(spread_p, axis_x_p, 90 * 60, center)
	local spread_orient = CalcOrientation(center, spread_p)
	local angle_offset = (args.dir_angle - spread_orient)

	for i = 1, numPositions do
		local theta = random() * two_pi
		local h = random() * radius * tan_half

		local p = point(cx + cos(theta) * h, cy + sin(theta) * h, cz + sqrt(radius_sq - h * h))
		p = RotateAxis(p, axis_x_p, 90 * 60, center)
		p = RotateAxis(p, axis_z_p, angle_offset, center)
		---- NOTA: este 1.12 escala o Z ABSOLUTO do mapa, nao o deslocamento em relacao ao
		---- centro -- e o achado A3 do SHRAPNEL_REPORT.md. Mexer nele muda balanco, entao
		---- ficou de fora desta leva de performance.
		p = p:SetZ(p:z() * 1.12)

		if p:z() >= cz then
			n = n + 1
			positions[n] = p
		end
	end

	return positions
end

---- ============================================================================
---- Distribuicao dos estilhacos -- v2 (banda desenhada, sem descarte)
---- ============================================================================
----
---- O que a v1 fazia: distribuia uniforme na esfera inteira (espiral de Fibonacci,
---- que e a forma canonica e continua aqui), reescalava phi por dois multiplicadores
---- (phi >= 1.4 and phi*0.65 or phi*2.5) e depois jogava fora tudo que apontava para
---- baixo. O vies lateral que sobrava era BOM -- 94,5% dos raios entre 0 e 40 graus,
---- quase uniforme ate ~36 -- mas ele saia por descarte, nao por desenho:
----
----   * geravam-se 700 vetores para tracar 388 (44,5% de trabalho jogado fora);
----   * a forma final era a uniao de dois pedacos reescalados, com uma
----     descontinuidade de densidade em ~37,9 graus (onde um ramo acaba e so o
----     outro, esparso, continua);
----   * nao havia como tunar nada sem mexer nos dois multiplicadores no escuro.
----
---- A v2 amostra DIRETO na banda util: a elevacao de cada raio vem de uma curva
---- explicita, e todo vetor gerado e tracado. O azimute continua sendo o angulo
---- aureo (a parte que ja estava certa).
----
----   t     = (i - 0,5) / N                          posicao no sorteio, em [0,1)
----   lobo  = t < MainPct%   -> elev = ElevMain * u^Shape      (banda principal)
----   cauda = senao          -> elev = ElevMain .. ElevMax     (respingo alto)
----
---- Os defaults em __EOParams.lua reproduzem a distribuicao de hoje. Os botoes:
----
----   EO.ShrapElevMain   teto da banda principal, em graus. E O DIAL LATERAL:
----                      menor = mais rasante, mais chance de pegar quem esta em pe
----                      longe; maior = mais spray para cima, perdido.
----   EO.ShrapElevShape  expoente x100 dentro da banda. 100 = uniforme (hoje).
----                      >100 empurra os raios para perto do horizonte.
----   EO.ShrapMainPct    % dos raios na banda principal; o resto vira respingo alto.
----   EO.ShrapElevMax    teto do respingo.
----
---- NAO ha mais descarte: numPositions e o numero de raios TRACADOS. Quem chama
---- aplica EO.ShrapTracedPct sobre o r_shrap_num para manter a mesma contagem de
---- CheckLOF de antes -- o custo por explosao nao muda.
function generateShrapnelPositions(numPositions, radius, center, want_debug)
	local positions = {}
	local phis_list = want_debug and {} or nil
	local theta_list = want_debug and {} or nil

	if numPositions < 1 then
		return positions, phis_list, theta_list
	end

	---- inteiro: math.random(-x, x) exige argumento com representacao inteira, e a regra
	---- do projeto e MulDivRound em vez de float (ver CLAUDE.md).
	local maxRandomOffset = MulDivRound(const.SlabSizeX, 15, 100)

	local EO = const.EO or empty_table
	local elev_main = EO.ShrapElevMain or 38
	local elev_max = EO.ShrapElevMax or 82
	---- ATENCAO: '*0.01' e nao '/100'. Nesta engine o '/' entre inteiros e divisao
	---- inteira truncada, entao main_pct/100 daria 0 e o expoente 150/100 daria 1.
	local main_frac = (EO.ShrapMainPct or 95) * 0.01
	local shape_exp = (EO.ShrapElevShape or 100) * 0.01

	local goldenRatio = (1 + sqrt(5)) / 2
	local two_pi = 2 * pi
	local deg2rad = pi / 180
	local tail_span = elev_max - elev_main
	local cx, cy, cz = center:x(), center:y(), center:z()

	for i = 1, numPositions do
		local t = (i - 0.5) / numPositions

		local elev
		if t < main_frac then
			local u = t / main_frac
			elev = elev_main * (shape_exp == 1 and u or u ^ shape_exp)
		else
			elev = elev_main + tail_span * (t - main_frac) / (1 - main_frac)
		end

		local elev_rad = elev * deg2rad
		local horiz = cos(elev_rad) * radius
		local zr = sin(elev_rad) * radius

		local theta = two_pi * (i - 1) / goldenRatio

		positions[i] = point(horiz * cos(theta) + cx + random(-maxRandomOffset, maxRandomOffset),
		                     horiz * sin(theta) + cy + random(-maxRandomOffset, maxRandomOffset),
		                     cz + zr + random(-maxRandomOffset, maxRandomOffset))
		if want_debug then
			phis_list[i] = elev
			theta_list[i] = theta
		end
	end

	return positions, phis_list, theta_list
end

---- Fora do caminho quente desde o PERF (C1) -- generateShrapnelPositions nao chama mais.
---- Mantida porque e global e a bancada/outros mods podem consultar a distribuicao crua.
function generateShrapnelVectors(numVectors)
	local vectors = {}
	local phis = {}
	local thetas = {}

	local goldenRatio = (1 + sqrt(5)) / 2

	for i = 1, numVectors do
		local theta = 2 * pi * (i - 1) / goldenRatio

		local phi = acos(-1 + 2 * (i - 0.5) / numVectors) -- *0.7 ---- bias to north hemisphere.
		-- local phi = math.acos(math.random() * 2 - 1) *0.9
		-- phi = phi >= 1.4 and phi * 0.8 or phi * 3 ---- bias to the equator, a little to the north
		-- phi = phi >= 1.4 and phi * 0.8 or phi * 2.8
		phi = phi >= 1.4 and phi * 0.65 or phi * 2.5

		local x = sin(phi) * cos(theta)
		local y = sin(phi) * sin(theta)
		local z = cos(phi)

		vectors[i] = {x, y, z}
		phis[i] = phi
		thetas[i] = theta
	end

	return vectors, phis, thetas
end
