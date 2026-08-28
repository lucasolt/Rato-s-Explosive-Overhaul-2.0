-- tools/traj_angle_test.lua -- BUGFIX (B10)
--
-- Roda a implementacao REAL de Grenade:GetTrajectory com a engine stubada, para
-- provar a selecao de angulo depois do desvio. Nao precisa do jogo.
--
--     lua5.3 tools/traj_angle_test.lua        (a partir da RAIZ do repo)
--
-- Cenario: alvo a 10 tiles, parede a 5 tiles alta o bastante para barrar os arcos
-- Low e Level; so o Incline passa por cima.

const = {
    SlabSizeX = 100,
    SlabSizeZ = 50,
    Combat = {
        GrenadeLaunchAngle_Low = 600,
        GrenadeLaunchAngle = 2700,
        GrenadeLaunchAngle_Incline = 4500,
        Gravity = 1000,
    },
}
GameState = {Underground = false}

-- ponto minimo: x horizontal, z vertical
local P = {}
P.__index = P
local function pt(x, z) return setmetatable({_x = x, _z = z}, P) end
function P:x() return self._x end
function P:y() return 0 end
function P:z() return self._z end
function P:SetTerrainZ() return pt(self._x, 0) end
function P:Dist(o) local dx, dz = self._x - o._x, self._z - o._z
    return math.floor(math.sqrt(dx * dx + dz * dz)) end
function P:Equal2D(o) return self._x == o._x end

function IsCloser(a, b, d) return a:Dist(b) < d end
function DbgAddCircle_rat() end
function cRound(x) return math.floor(x + 0.5) end
function grenade_mass_factor_adjusted() return 0 end
function Min(a, b) return a < b and a or b end
function Max(a, b) return a > b and a or b end

-- ============ o cenario fisico ============
WALL_AT, WALL_H = 500, 700   -- Low(150) e Level(675) batem; Incline(1125) passa
local TARGET = pt(1000, 0)
local ATTACK = pt(0, 0)

-- altura do arco no ponto x, para um angulo (modelo grosseiro mas monotonico no angulo)
local function arc_height(angle, x, range)
    local peak = range * angle / 4000        -- quanto maior o angulo, mais alto o apice
    local u = x / range
    return 4 * peak * u * (1 - u)
end

local calls = {}
local Grenade = {}
Grenade.__index = Grenade
function Grenade:CalcTrajectory(attack_args, target_pos, angle, bounces)
    calls[#calls + 1] = angle
    local range = target_pos:x() - ATTACK:x()
    local traj = {{pos = ATTACK, t = 0}}
    for step = 1, 20 do
        local x = range * step / 20
        local z = arc_height(angle, x, range)
        if x >= WALL_AT and (x - range / 20) < WALL_AT and z < WALL_H then
            -- bate na parede: para aqui
            traj[#traj + 1] = {pos = pt(WALL_AT, z), t = step * 20}
            return traj
        end
        traj[#traj + 1] = {pos = pt(x, z), t = step * 20}
    end
    return traj
end
Grenade.Ratonade_Bounce_CalcTrajectory = Grenade.CalcTrajectory

-- carrega a implementacao REAL
local src = assert(io.open("Code/SOURCE_GrenadeGetTrajectory.lua")):read("a")
-- o arquivo declara "function Grenade:GetTrajectory"; damos o Grenade a ele
local env = setmetatable({Grenade = Grenade}, {__index = _G})
local chunk = assert(load(src, "GetTrajectory", "t", env))
chunk()

local attacker = {GetDist = function(_, p) return ATTACK:Dist(p) end}

local function run(label, args)
    calls = {}
    args.obj = attacker
    local traj, angle = Grenade.GetTrajectory(Grenade, args, ATTACK, TARGET, false)
    local hit = traj and #traj > 0 and traj[#traj].pos
    print(string.format("%-42s angulos testados=%-22s pousou x=%-5s (alvo 1000)  angulo=%s",
        label, table.concat(calls, ","), hit and hit:x() or "?", tostring(angle)))
    return hit and hit:x()
end

print("parede a x=500 altura 700; Low=600 Level=2700 Incline=4500\n")

local a = run("1. normal, sem desvio (rat_angle=Low)", {rat_angle = 600})
local b = run("2. DESVIADO, nao-IA (B10 deve expandir)", {rat_angle = 600, rat_deviate = true})
local c = run("3. DESVIADO, IA bounce (nao expande)",
              {rat_angle = 600, rat_deviate = true, rat_bounce_aim = true})
local d = run("4. sem rat_angle (ramo elseif de sempre)", {})

print("")
local ok = true
local function check(cond, msg)
    print((cond and "  PASS  " or "  FAIL  ") .. msg); ok = ok and cond
end
check(a == 500, "1: sem desvio testa SO o angulo comprometido e para na parede (inalterado)")
check(b == 1000, "2: desviado expande e alcanca o alvo por cima da parede")
check(c == 500, "3: IA com bounce mantem o par angulo/mira, nao expande")
check(d == 1000, "4: ramo padrao segue testando os 3 arcos")


-- 5. parede baixa: o angulo comprometido ainda serve -> tem que parar no 1o candidato
WALL_H = 75
local e = run("5. DESVIADO mas o angulo ainda serve", {rat_angle = 600, rat_deviate = true})
check(#calls == 1 and e == 1000, "5: para no 1o candidato quando ele ja resolve (sem custo extra)")
os.exit(ok and 0 or 1)
