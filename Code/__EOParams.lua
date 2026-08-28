const.EO = const.EO or {}




const.EO.DazedCTHPenalty = -30
const.EO.HeavyRainIEDMisfireMul = 110
const.EO.ShapedChargeAccPenalty = -25
const.EO.ShapedChargeBarryAccBonus = 5

---- Estilhacos: forma da distribuicao (ver FUNCTIONS_Shrapnel_VectorGenerators.lua).
---- Estes defaults reproduzem a distribuicao que a v1 produzia por descarte.
const.EO.ShrapTracedPct = 55 ---- % do r_shrap_num que vira raio tracado (v1: 55,4%)
const.EO.ShrapElevMain = 38 ---- graus: teto da banda principal -- o dial lateral
const.EO.ShrapElevMax = 82 ---- graus: teto do respingo alto
const.EO.ShrapMainPct = 95 ---- % dos raios na banda principal
const.EO.ShrapElevShape = 100 ---- expoente x100 na banda: 100 = uniforme, >100 rasante

