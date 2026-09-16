const.EO = const.EO or {}




const.EO.DazedCTHPenalty = -30
const.EO.HeavyRainIEDMisfireMul = 115

---- Estilhacos: forma da distribuicao (ver FUNCTIONS_Shrapnel_VectorGenerators.lua).
---- Estes defaults reproduzem a distribuicao que a v1 produzia por descarte.
const.EO.ShrapTracedPct = 55 ---- % do r_shrap_num que vira raio tracado (v1: 55,4%)
const.EO.ShrapElevMain = 38 ---- graus: teto da banda principal -- o dial lateral
const.EO.ShrapElevMax = 82 ---- graus: teto do respingo alto
const.EO.ShrapMainPct = 95 ---- % dos raios na banda principal
const.EO.ShrapElevShape = 100 ---- expoente x100 na banda: 100 = uniforme, >100 rasante

------- Deviation Params ---- MOTOR ABSOLUTO
--
-- O raio do erro e desenhado direto em tiles, sem clamp:
--
--     miss = (roll - gate) / (100 - gate)                 gate = stat * sfp / 100
--     r    = r_min(stat) + (r_max(stat) - r_min(stat)) * miss^const.EO.DeviationShape
--     dir  = 90deg * sinal(u) * |u|^const.EO.DeviationDirBias  (u uniforme em [-1,1]) + flip de 180deg
--
-- |erro| = r sempre. O r_min e um piso de imprecisao de verdade, e o vies mora na
-- DIRECAO, nao na magnitude. Nao existe max()/min() no caminho, entao a distribuicao
-- nao tem atomo (a versao com piso por clamp empilhava metade da massa num raio so).
--
-- A distancia NAO multiplica mais o erro. Ela entra por um canal so: const.EO.DeviationGrenadeDistPen,
-- que desconta do stat. Por isso o clamp de unidades tiles-vs-mundo deixou de existir
-- junto com o bloco geometrico antigo.
--
-- Tudo em milesimos de tile e percentuais inteiros: Lua 5.3 com '/' inteiro, e float
-- em caminho sincronizado vaza para o NetUpdateHash (ver CLAUDE.md).

---- Ajustados por fit ancorado em 15 TILES, contra o alvo do autor:
----   Great tipico 1 t | Good 2 t | Inaccurate 3.5 t | Terrible 5 t
---- Depois escalados 1.20x a pedido ("uns 20% mais desviado").
---- A 15t: stat 90 -> 1.38/2.54 | 75 -> 1.98/3.48 | 60 -> 2.83/4.52 | 45 -> 3.71/5.58
---- r_max(100) fica em 0.61 t de proposito: se ele chegasse a zero, um merc de ui alto
---- em curta distancia teria r_max = r_min = 0 e TODO arremesso viraria Perfect.
-- const.EO.DeviationMinBASE =  1171 ---- erro minimo no stat 0, em milesimos de tile
-- const.EO.DeviationMinSCALE = 2292 ---- r_min chega a zero por volta de ui 51
-- const.EO.DeviationMaxBASE = 8742 ---- erro maximo no stat 0
-- const.EO.DeviationMaxSCALE = 8011 ---- quanto a skill baixa o teto -> r_max(100) = 0.73 t

const.EO.DeviationMinBASE = 1350 ---- erro minimo no stat 0, em milesimos de tile
const.EO.DeviationMinSCALE = 750 ---- r_min chega a zero por volta de ui 51
const.EO.DeviationMaxBASE = 6900--6900 ---- erro maximo no stat 0
const.EO.DeviationMaxSCALE = 6000--5500-- ---- quanto a skill baixa o teto -> r_max(100) = 0.73 t

---- (const.EO.DeviationMaxSCALE - const.EO.DeviationMinSCALE) e a taxa com que a faixa ESTREITA conforme a skill sobe:
---- positivo = skill compra consistencia; zero = skill desloca a faixa inteira (precisao pura)

---- CANAL 2 da distancia: ela mexe na LARGURA da faixa, sem tocar no piso.
----   spread(L) = PERTO + (LONGE - PERTO) * L / alcance_maximo     (em %)
----   r_max_efetivo = r_min + (r_max - r_min) * spread / 100
----
---- Duas pontas, para dar as duas direcoes:
----   PERTO 100, LONGE 100 -> canal desligado
----   PERTO 100, LONGE 160 -> perto igual, LONGE 60% mais largo   (piora com o alcance)
----   PERTO  60, LONGE 100 -> longe igual, PERTO 40% mais estreito (aperta de perto)
----   PERTO  80, LONGE 140 -> as duas coisas ao mesmo tempo
----
---- O piso nunca se mexe, entao apertar de perto nao devolve o arremesso cirurgico.
---- O const.EO.DeviationGrenadeDistPen continua existindo e continua sendo quem move a tooltip.
const.EO.DeviationSpreadNEAR = 80
const.EO.DeviationSpreadFAR = 160



const.EO.DeviationShape = 1 ---- expoente INTEIRO. 1 = linear. >1 concentra perto do piso (precisao comum),
---- a curva espelhada 1-(1-miss)^k faz o oposto (precisao rara) -- ver const.EO.DeviationShapeMirror abaixo
const.EO.DeviationShapeMirror = false ---- true troca miss^k por 1-(1-miss)^k

const.EO.DeviationDirBias = 2 ---- expoente INTEIRO. 1 = isotropico. >1 concentra no eixo do arremesso
const.EO.DeviationShortMul = 100 ---- % do lado que volta pro arremessador. 100 = simetrico, <100 encurta
const.EO.DeviationLauncherRadiusMul = 90 ---- % do raio para GL/RPG (no motor antigo eles desviavam ~12% menos)

const.EO.DeviationStatFactorForPerfectThrow = 26 ---- gate = stat * isto / 100; roll abaixo dele = acerto exato

---- rotulos por distancia absoluta, em milesimos de tile.
---- O texto significa a MESMA coisa para qualquer merc e qualquer granada: a skill muda
---- com que frequencia cada um sai, nao o que ele quer dizer.
---- ATENCAO: sao derivados da distribuicao. Mexeu em r_min/r_max/const.EO.DeviationShape, recalibre
---- (a bancada tem o botao "Calibrar rotulos").
---- FONTE UNICA das bandas de rotulo.
---- Leem daqui, e so daqui: o texto flutuante no jogo, o print de debug e os aneis
---- desenhados no mapa. Mexeu num raio aqui, mexeu nos tres ao mesmo tempo.
----   max  = raio maximo da banda, em milesimos de tile (a ultima nao tem: pega o resto)
----   ring = cor do anel no mapa (false = nao desenha)
----   warn = pinta o texto flutuante com AmmoAPColor

const.EO.DeviationLabelBands = {
    {name = "Perfect", max = 0, ring = false}, {name = "Great", max = 1200, ring = "clrGreen"},
    {name = "Normal", max = 2100, ring = "clrYellow", silent = true},
    {name = "Innacurate", max = 3200, ring = "clrRed", warn = true},
    {name = "Terrible", ring = false, warn = true}
}

----------Class x Dist
const.EO.DeviationGrenadeDistPen = 10 -- 20 -- 25 ---- Higher = less accurate
const.EO.DeviationRPGDistPen = 6 -- 12 ---- Higher = less accurate
const.EO.DeviationGLDistPen = 6 -- 12 ---- Higher = less accurate

---- status effects/ other penalties
const.EO.DeviationWoundStackPenalty = 5 ---- Higher = less accurate
const.EO.DeviationInnacuratePenalty = 15 ---- Higher = less accurate
const.EO.DeviationBlindDazedPenalty = 20 ---- Higher = less accurate
--const.EO.DeviationHeavyRainPenalty = 10 ---- Higher = less accurate

------ Get item accuracy modidifers
const.EO.DeviationUnderSlungGLModifier = -10 --- higher = more accurate
const.EO.ShapedChargeOthersAccModifier = -25
const.EO.ShapedChargeBarryAccModifier = 5
