-- tools/shrapnel_dist_test.lua
--
-- Compara a distribuicao de estilhacos da v1 (uniforme na esfera + dois multiplicadores
-- + descarte) com a v2 do repo (banda desenhada, sem descarte), e mede o custo das duas.
-- Nao precisa do jogo:
--
--     lua5.3 tools/shrapnel_dist_test.lua        (a partir da RAIZ do repo)
--
-- Mexeu nos const.EO.Shrap* do __EOParams.lua? Rode isto para ver o que mudou na
-- elevacao antes de entrar no jogo.

const = {SlabSizeX = 1000}
empty_table = {}
function MulDivRound(a, b, c) return math.floor(a * b / c + 0.5) end

local P = {}
P.__index = P
function point(x, y, z) return setmetatable({_x = x, _y = y, _z = z}, P) end
function P:x() return self._x end
function P:y() return self._y end
function P:z() return self._z end
function P:SetZ(z) return point(self._x, self._y, z) end

-- stubs instalados ANTES do load: o gerador congela math.* em locais no topo do arquivo
local trig = 0
local real = {sin = math.sin, cos = math.cos, acos = math.acos, sqrt = math.sqrt, asin = math.asin}
math.random = function() return 0 end -- offsets neutros: isolam a forma da distribuicao
for name, fn in pairs(real) do
    if name ~= "asin" then math[name] = function(v) trig = trig + 1; return fn(v) end end
end

-- le os const.EO.Shrap* do proprio __EOParams.lua, para o teste seguir os defaults reais
const.EO = {}
for line in io.lines("Code/__EOParams.lua") do
    local k, v = line:match("^const%.EO%.(%w+)%s*=%s*(-?%d+)")
    if k then const.EO[k] = tonumber(v) end
end

local src = assert(io.open("Code/FUNCTIONS_Shrapnel_VectorGenerators.lua")):read("a")
assert(load(src, "gen", "t", _G))()

local RADIUS = 13000
local center = point(0, 0, 0)

-- ============ v1: uniforme na esfera + multiplicadores + descarte ============
local function v1(num)
    local out = {}
    local golden = (1 + real.sqrt(5)) / 2
    for i = 1, num do
        local phi = math.acos(-1 + 2 * (i - 0.5) / num)   -- contado
        phi = phi >= 1.4 and phi * 0.65 or phi * 2.5
        local z = math.cos(phi) * RADIUS                  -- contado
        if z > 0 then
            local theta = 2 * math.pi * (i - 1) / golden
            math.sin(phi); math.cos(theta); math.sin(theta) -- o que a v1 gastava por sobrevivente
            out[#out + 1] = {elev = real.asin(z / RADIUS), theta = theta}
        end
    end
    return out
end

local function elev_of(p) -- graus, a partir do ponto gerado
    local h = real.sqrt(p:x() * p:x() + p:y() * p:y())
    return math.deg(real.asin(p:z() / real.sqrt(h * h + p:z() * p:z())))
end

local NUM = 700
trig = 0
local a = v1(NUM)
local trig_v1 = trig

local traced = MulDivRound(NUM, const.EO.ShrapTracedPct or 55, 100)
trig = 0
local b = generateShrapnelPositions(traced, RADIUS, center)
local trig_v2 = trig

-- ============ histogramas ============
local bins = {{0, 5}, {5, 10}, {10, 15}, {15, 20}, {20, 25}, {25, 30}, {30, 40}, {40, 60},
              {60, 90}}
local function hist(vals)
    local h = {}
    for bi, r in ipairs(bins) do
        h[bi] = 0
        for _, v in ipairs(vals) do if v >= r[1] and v < r[2] then h[bi] = h[bi] + 1 end end
    end
    return h
end

local ea, eb = {}, {}
for _, r in ipairs(a) do ea[#ea + 1] = math.deg(r.elev) end
for _, p in ipairs(b) do eb[#eb + 1] = elev_of(p) end
local ha, hb = hist(ea), hist(eb)

local function bar(pct) return string.rep("#", math.floor(pct / 2 + 0.5)) end

print(string.format("r_shrap_num %d   |   v1: %d raios tracados   v2: %d raios tracados", NUM,
                    #a, #b))
print(string.format("custo de trigonometria:   v1 %d   ->   v2 %d   (-%d%%)", trig_v1, trig_v2,
                    math.floor((trig_v1 - trig_v2) * 100 // trig_v1)))
print(string.format("parametros: ElevMain %d  ElevMax %d  MainPct %d  Shape %d  TracedPct %d",
                    const.EO.ShrapElevMain, const.EO.ShrapElevMax, const.EO.ShrapMainPct,
                    const.EO.ShrapElevShape, const.EO.ShrapTracedPct))
print("")
print("elevacao          v1 (descarte)            v2 (banda desenhada)")
for bi, r in ipairs(bins) do
    local pa, pb = 100 * ha[bi] / #a, 100 * hb[bi] / #b
    print(string.format("  %2d-%2d deg   %5.1f%% %-18s   %5.1f%% %s", r[1], r[2], pa, bar(pa), pb,
                        bar(pb)))
end

-- cobertura azimutal: o angulo aureo deve espalhar bem em qualquer subconjunto
local function azim_worst_gap(vals)
    local t = {}
    for _, v in ipairs(vals) do t[#t + 1] = v % (2 * math.pi) end
    table.sort(t)
    local worst = t[1] + 2 * math.pi - t[#t]
    for i = 2, #t do worst = math.max(worst, t[i] - t[i - 1]) end
    return math.deg(worst)
end
local ta, tb = {}, {}
for _, r in ipairs(a) do ta[#ta + 1] = r.theta end
for _, p in ipairs(b) do tb[#tb + 1] = math.atan(p:y(), p:x()) end
print("")
print(string.format("maior buraco no azimute:   v1 %.2f deg   v2 %.2f deg   (ideal ~%.2f)",
                    azim_worst_gap(ta), azim_worst_gap(tb), 360.0 / #b))

-- ============ o dial lateral ============
-- Quanto dos raios cai rasante (0-15 deg), que e onde mora quem esta em pe e longe.
print("")
print("o dial lateral -- % dos raios em cada faixa, variando os botoes:")
print("  ElevMain Shape |  0-15deg  15-30deg  30+deg")
local function sweep(main, shape)
    const.EO.ShrapElevMain, const.EO.ShrapElevShape = main, shape
    local p = generateShrapnelPositions(traced, RADIUS, center)
    local lo, mid, hi = 0, 0, 0
    for _, v in ipairs(p) do
        local e = elev_of(v)
        if e < 15 then lo = lo + 1 elseif e < 30 then mid = mid + 1 else hi = hi + 1 end
    end
    print(string.format("     %3d    %3d  |   %5.1f%%    %5.1f%%   %5.1f%%%s", main, shape,
                        100.0 * lo / #p, 100.0 * mid / #p, 100.0 * hi / #p,
                        (main == 38 and shape == 100) and "   <- default (= v1 hoje)" or ""))
end
for _, m in ipairs({38, 25}) do
    for _, sh in ipairs({100, 150, 200}) do sweep(m, sh) end
end
