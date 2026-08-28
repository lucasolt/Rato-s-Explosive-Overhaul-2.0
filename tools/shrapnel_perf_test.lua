-- tools/shrapnel_perf_test.lua -- PERF (C1)
--
-- Prova que o gerador fundido produz EXATAMENTE o mesmo conjunto de estilhacos que a
-- versao de duas passadas, e mede quanta trigonometria/alocacao deixou de ser paga.
-- Nao precisa do jogo:
--
--     lua5.3 tools/shrapnel_perf_test.lua        (a partir da RAIZ do repo)
--
-- Como o novo gerador chama math.random menos vezes (o estilhaco que vai para o chao nem
-- sorteia), os dois fluxos de random divergem por construcao. Para comparar maca com maca
-- o teste fixa math.random num valor CONSTANTE -- ai a contagem de chamadas deixa de
-- importar e as saidas tem que bater byte a byte. Roda com o offset no centro e nos dois
-- extremos, que e onde o corte conservador do C1 poderia errar.

const = {SlabSizeX = 1000}
function MulDivRound(a, b, c) return math.floor(a * b / c + 0.5) end

local P = {}
P.__index = P
function point(x, y, z) return setmetatable({_x = x, _y = y, _z = z}, P) end
function P:x() return self._x end
function P:y() return self._y end
function P:z() return self._z end
function P:SetZ(z) return point(self._x, self._y, z) end

-- Os stubs precisam estar instalados ANTES de carregar o gerador: o arquivo faz
-- "local sin, cos, ... = math.sin, ..." no topo, entao ele congela o que estiver la na
-- hora do load. Trocar math.sin depois nao teria efeito nenhum sobre ele.
local trig = 0
local real = {sin = math.sin, cos = math.cos, acos = math.acos, sqrt = math.sqrt}
local RANDOM_IMPL = math.random

math.random = function(a, b) return RANDOM_IMPL(a, b) end
for name, fn in pairs(real) do
    math[name] = function(v) trig = trig + 1; return fn(v) end
end

-- ============ implementacao ANTIGA (duas passadas), copiada do git ============
local function old_vectors(numVectors)
    local vectors, phis, thetas = {}, {}, {}
    local goldenRatio = (1 + math.sqrt(5)) / 2
    for i = 1, numVectors do
        local theta = 2 * math.pi * (i - 1) / goldenRatio
        local phi = math.acos(-1 + 2 * (i - 0.5) / numVectors)
        phi = phi >= 1.4 and phi * 0.65 or phi * 2.5
        table.insert(vectors, {math.sin(phi) * math.cos(theta), math.sin(phi) * math.sin(theta),
                               math.cos(phi)})
        table.insert(phis, phi); table.insert(thetas, theta)
    end
    return vectors, phis, thetas
end

local function old_positions(numPositions, radius, center)
    local positions = {}
    local vectors = old_vectors(numPositions)
    local maxRandomOffset = const.SlabSizeX * 0.15
    for i, v in ipairs(vectors) do
        local x = v[1] * radius + center:x()
        local y = v[2] * radius + center:y()
        local z = v[3] * radius + center:z()
        x = x + math.random(-maxRandomOffset, maxRandomOffset)
        y = y + math.random(-maxRandomOffset, maxRandomOffset)
        z = z + math.random(-maxRandomOffset, maxRandomOffset)
        if z > center:z() then table.insert(positions, point(x, y, z)) end
    end
    return positions
end

-- ============ implementacao NOVA (a do repo) ============
local src = assert(io.open("Code/FUNCTIONS_Shrapnel_VectorGenerators.lua")):read("a")
assert(load(src, "gen", "t", _G))()

-- ============ comparacao ============
local NUM, RADIUS = 700, 13000
local center = point(5000, 7000, 2000)
local maxOff = const.SlabSizeX * 0.15
local ok = true

for _, off in ipairs({0, maxOff, -maxOff}) do
    RANDOM_IMPL = function() return off end

    trig = 0
    local a = old_positions(NUM, RADIUS, center)
    local trig_old = trig

    trig = 0
    local b = generateShrapnelPositions(NUM, RADIUS, center)
    local trig_new = trig

    local same = #a == #b
    if same then
        for i = 1, #a do
            if a[i]:x() ~= b[i]:x() or a[i]:y() ~= b[i]:y() or a[i]:z() ~= b[i]:z() then
                same = false; break
            end
        end
    end
    print(string.format("offset %+6d | antigo %d pos, %d trig | novo %d pos, %d trig | %s",
                        off, #a, trig_old, #b, trig_new, same and "IDENTICO" or "DIFERE"))
    ok = ok and same
    if off == 0 then T_OLD, T_NEW = trig_old, trig_new end
end

print("")
print(string.format("trigonometria por explosao de %d estilhacos:  antes %d  ->  agora %d  (-%d%%)",
                    NUM, T_OLD, T_NEW, math.floor((T_OLD - T_NEW) * 100 / T_OLD)))
print((ok and "  PASS  " or "  FAIL  ") .. "conjunto de sobreviventes identico ao da versao antiga")
os.exit(ok and 0 or 1)
