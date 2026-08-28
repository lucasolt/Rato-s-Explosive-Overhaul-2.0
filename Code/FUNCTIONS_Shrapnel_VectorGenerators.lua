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

---- PERF (C1): gerador fundido, com o descarte ANTES do trabalho caro.
----
---- Antes eram duas passadas: generateShrapnelVectors montava N tabelas {x,y,z} mais dois
---- arrays de debug, e so entao generateShrapnelPositions jogava fora ~44,5% deles (todo
---- estilhaco que aponta para baixo, isto e, que ia para o chao). Ou seja: pagava-se
---- trigonometria completa, tres sorteios e varias alocacoes por vetor para descobrir
---- depois que quase metade nao seria nem tracada.
----
---- Agora o teste de descarte roda logo depois do acos/cos, antes de sin(phi), das duas
---- funcoes de theta, dos sorteios e do point(). Um estilhaco que vai para o chao custa
---- duas chamadas de trigonometria e nada mais.
----
---- O conjunto de sobreviventes e o MESMO: o corte usa a margem do offset aleatorio
---- (zr + maxOffset <= 0 => morto para qualquer sorteio possivel), entao nenhum vetor que
---- hoje sobrevive passa a ser descartado. So a ORDEM do fluxo de math.random muda, e ele
---- ja era nao-deterministico -- ver A2 no SHRAPNEL_REPORT.md, ainda pendente.
function generateShrapnelPositions(numPositions, radius, center, want_debug)
	local positions = {}
	local phis_list = want_debug and {} or nil
	local theta_list = want_debug and {} or nil
	local n = 0

	if numPositions < 1 then
		return positions, phis_list, theta_list
	end

	---- inteiro: math.random(-x, x) exige argumento com representacao inteira, e a regra
	---- do projeto e MulDivRound em vez de float (ver CLAUDE.md).
	local maxRandomOffset = MulDivRound(const.SlabSizeX, 15, 100)

	local goldenRatio = (1 + sqrt(5)) / 2
	local two_pi = 2 * pi
	local cx, cy, cz = center:x(), center:y(), center:z()

	for i = 1, numPositions do
		---- phi e theta sao calculados com a MESMA sequencia de operacoes de antes.
		---- Hastear as divisoes (2*pi/golden fora do laco) parece inofensivo e nao e:
		---- (2*pi*(i-1))/g e (2*pi/g)*(i-1) arredondam diferente, e o teste de
		---- equivalencia acusa. O ganho seria uma divisao por estilhaco, irrelevante
		---- perto da trigonometria que o C1 ja cortou.
		local phi = acos(-1 + 2 * (i - 0.5) / numPositions)
		phi = phi >= 1.4 and phi * 0.65 or phi * 2.5

		local zr = cos(phi) * radius

		---- vai para baixo mesmo com o offset mais favoravel: nem sorteia, nem aloca.
		if zr + maxRandomOffset > 0 then
			local xOffset = random(-maxRandomOffset, maxRandomOffset)
			local yOffset = random(-maxRandomOffset, maxRandomOffset)
			local zOffset = random(-maxRandomOffset, maxRandomOffset)

			if zr + zOffset > 0 then
				local theta = two_pi * (i - 1) / goldenRatio
				local sin_phi = sin(phi)

				---- a ordem das multiplicacoes e a MESMA da versao de duas passadas
				---- (sin*cos*radius + centro, nao (sin*radius)*cos): associacao diferente
				---- muda o ultimo bit do float e o teste de equivalencia pega isso.
				n = n + 1
				positions[n] = point(sin_phi * cos(theta) * radius + cx + xOffset,
				                     sin_phi * sin(theta) * radius + cy + yOffset, cz + zr + zOffset)
				if want_debug then
					phis_list[n] = phi
					theta_list[n] = theta
				end
			end
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
