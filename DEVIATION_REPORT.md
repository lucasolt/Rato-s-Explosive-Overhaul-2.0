# DEVIATION_REPORT.md — desvio de granadas

Análise de `Code/FUNCTIONS_DeviateGrenade.lua` (v1.21): o que o sistema faz hoje,
onde ele não faz o que o código parece dizer, e quais botões girar.
Companheiro do [`SHRAPNEL_REPORT.md`](SHRAPNEL_REPORT.md).

- **Bancada interativa:** https://claude.ai/code/artifact/9c27d1ad-0603-4ab3-8ee5-d783521190b2
  (sliders para todas as constantes, planta de impacto, bandas por stat)
- **Modelo reproduzível:** `tools/deviation_model.py` — réplica linha a linha do Lua.
  `python tools/deviation_model.py` imprime a tabela principal.

Todas as distribuições aqui são **exatas** (enumeração dos 2500 resultados do dado ×
2 sinais de ângulo × 2 sinais radiais), não Monte Carlo. A geometria assume terreno
plano; `validate_deviated_gren_pos`, quique e colisão agem depois e só podem afastar
mais o ponto final.

---

## 1. O pipeline em uma tela

```
GetMishapChance                                    rat_custom_deviation
─────────────────                                  ────────────────────
stat0 = max(45, (Dex+Expl)/2 [+10 perk])           stat_ef = stat_ui + 6 - ai_mod
      − formato do item (0 … −6, −25 shaped)       roll    = 2d50 + 1        (1..99)
      − round(dist/max_range × 18)                 diff    = stat_ef − roll
      − opção de dificuldade                       dev     = ((100−diff)/100)² × 2
      − wounds×5, Inaccurate 15, Blind 15, chuva 10
      = stat_ui   (é este que a UI mostra)         ângulo  = 4° × dev  (×0,85 se dev≤0,75)
                                                   radial  = ±10% × dev
```

O ponto de explosão é `attack_pos + Rotate(dir, ângulo)` reescalado para
`|dir| × (1 ± radial)`.

### Duas fórmulas fechadas

O comportamento inteiro cabe em duas linhas, e elas batem com a simulação até a
terceira casa:

```
deviation mediano   = 2 × ((144 − stat_ui) / 100)²        (144 = 100 + 50 − 6)
erro em tiles       ≈ 0,12 × deviation × distância
```

de onde sai a regra de bolso:

> **erro mediano (tiles) ≈ 0,24 × distância × ((144 − stat_ui)/100)²**

O `0,12` é `hypot(length_factor, rot_factor × π/900)` = `hypot(0,10, 0,070)`.
Repare na proporção: **o encurtamento radial responde por ~76% do erro, o ângulo por
~24%**. Quem quer mexer na dispersão mexe em `grenade_length_factor` primeiro;
`base_gr_rotation_factor` é o ajuste fino.

---

## 2. Como está hoje

Merc com Dex = Expl, granada `Can` (−3), sem perk, alcance 15 tiles.
`ui` = stat mostrado na tooltip. Erros em tiles.

| dex/expl | dist | Perfect | Great | **(mudo)** | Inaccurate | Terrible | p50 | p90 | ≤2t |
|---|---|---|---|---|---|---|---|---|---|
| 50 (ui 43) | 3t | 1,4% | 0,8% | **44,8%** | 41,0% | 12,0% | 0,72 | 1,15 | 100% |
| 50 (ui 35) | 10t | 1,1% | 0,0% | **31,7%** | 46,1% | 21,1% | 2,78 | 4,28 | 21% |
| 50 (ui 29) | 15t | 0,6% | 0,0% | **23,2%** | 46,6% | 29,6% | 4,62 | 6,96 | 2% |
| 65 (ui 50) | 10t | 2,2% | 3,9% | **54,3%** | 33,5% | 6,1% | 2,09 | 3,45 | 45% |
| 80 (ui 65) | 10t | 3,6% | 17,5% | **61,5%** | 17,3% | 0,1% | 1,49 | 2,69 | 72% |
| 80 (ui 59) | 15t | 2,6% | 11,4% | **60,8%** | 23,8% | 1,4% | 2,58 | 4,47 | 31% |
| 95 (ui 80) | 10t | 5,4% | 39,7% | **50,7%** | 4,2% | 0,0% | 0,99 | 2,01 | 90% |
| 95 (ui 74) | 15t | 4,2% | 30,2% | **57,2%** | 8,4% | 0,0% | 1,76 | 3,40 | 59% |

Três leituras:

**a) A banda modal não tem nome.** A faixa `0,75 < dev < 2,0` não emite texto
flutuante nenhum e concentra 45–62% dos arremessos em praticamente todo o range de
stat. O jogador recebe feedback na minoria das vezes.

**b) As pontas estão fora de alcance.** `Perfect` satura em 8,4% mesmo com stat_ui
100; `Terrible` (≥3,2) é inatingível acima de stat_ui ~70. Só dois dos cinco rótulos
aparecem com frequência real, e ambos no meio-baixo da escala.

**c) A distância pune duas vezes.** O erro já é proporcional ao vetor de arremesso, e
`GR_dist_pen = 18` ainda derruba o stat conforme a razão dist/alcance. O composto é
superlinear: para o merc de stat 80, ir de 3t para 15t é 5× mais distância e **7,2×
mais erro**.

### Por que o miolo domina: os dados

`throw_dice(100, 2)` soma `2 × InteractionRand(50)` e devolve 1..99 — distribuição
**triangular**, não uniforme. Isso comprime tudo para perto do roll 50:

| gate | uniforme (1d100) | atual (2d50) |
|---|---|---|
| P(roll ≤ 10) | 10,0% | **2,2%** |
| P(roll ≤ 17) | 17,0% | **6,1%** |

O portão de Perfect é `roll ≤ stat_ui/100 × 20`. Com stat_ui 80 o portão fica em 16 —
que valeria ~16% com dado uniforme e vale 5,4% com dois dados. **A troca para 2 dados
cortou os Perfect em ~3× e matou os Terrible; foi uma mudança de variância que não veio
acompanhada de recalibração dos limiares.**

---

## 3. Três coisas que o código não faz o que parece

### BUG 1 — o clamp de distância compara tiles com unidades de mundo

```lua
if is_grenade and sign > 0 then
    distance_deviation = distance_deviation <= cRound(max_range * 1.5) and distance_deviation or
                             dir:Len() * (1 + distance_multiplier * -1)
end
```

`max_range` vem de `Grenade:GetMaxAimRange`, que devolve **tiles** (~15).
`distance_deviation` vem de `dir:Len()`, em **unidades de mundo** (tiles ×
`const.SlabSizeX`). A comparação é praticamente sempre falsa — em qualquer arremesso
de 1 tile ou mais, o lado esquerdo já é centenas de vezes maior que o direito.
O ramo de fallback dispara **todas** as vezes e inverte o sinal positivo.

O próprio `GetMishapChance`, 40 linhas acima, faz a conversão certa:
`max_range = max_range * const.SlabSizeX`.

> **Efeito:** a granada **nunca** passa do alvo. Os dois sinais radiais colapsam no
> mesmo resultado e todo erro cai curto — na direção do esquadrão que avança. É o pior
> viés possível para uma arma de área.

Verificação numérica (dev 2,0 a 10 tiles): hoje os dois sinais dão `2,36 / 2,36`;
corrigido dariam `2,52 / 2,36`.

**Correção:**

```lua
if is_grenade and sign > 0 then
    local cap = cRound(max_range * const.SlabSizeX * 3 / 2)   -- BUGFIX: tiles -> unidades de mundo
    distance_deviation = distance_deviation <= cap and distance_deviation or
                             dir:Len() * (1 + distance_multiplier * -1)
end
```

Impacto no balanço: quase nulo em magnitude (p50 1,68 → 1,72 no cenário padrão), grande
em sensação — metade dos erros passa a ser longa.

### BUG 2 — a penalidade de Wounded se cancela

`GetDeviationModifier` já subtrai `wound_penalty` do stat. Logo depois,
`rat_custom_deviation` faz:

```lua
stat = stat + base_skill_modifier - ai_modifier + ai_handicap + wound_penalty
```

somando de volta exatamente o que tinha sido tirado.

| Wounded | stat_ui (o que a UI diz) | p50 real hoje | p50 se descontasse |
|---|---|---|---|
| 0 | 60 | 1,68 t | 1,68 t |
| 2 | 50 | **1,68 t** | 2,09 t |
| 4 | 40 | **1,68 t** | 2,54 t |

> **Efeito:** com 4 stacks a tooltip cai de "Medium" para "Low" e **nada muda** no
> resultado. A UI mente. (Só não cancela quando o `Max(0, …)` já tinha travado o stat
> no chão — caso raro.)

**Correção:** remover o `+ wound_penalty` da linha. O desconto correto já acontece
dentro de `GetDeviationModifier`.

### PENDÊNCIA 3 — floats entrando em caminho sincronizado

`deviation` sai de `^` (sempre float em Lua 5.3), e daí saem `angle_of_rotation` e
`distance_deviation` — ambos entregues direto a `Rotate` / `SetLen`. Pela regra do
próprio projeto (`CLAUDE.md`: aritmética sempre `MulDivRound`, nunca float), qualquer
float num caminho de decisão sincronizada vaza para o `NetUpdateHash`. É o mesmo padrão
que o `BUGFIX (B7)` do `WEIGHTS_AUDIT.md` conserta no AI Overhaul.

Caminho: representar `deviation` em milésimos inteiros (`dev_m = 0..5000`) e trocar
as três multiplicações finais por `MulDivRound`. Não muda balanço; fecha um risco de
desync em co-op.

---

## 4. Os botões, por ordem de força

| Constante | Hoje | O que faz | Sensibilidade |
|---|---|---|---|
| `grenade_length_factor` | 0.10 | encurtamento/alongamento radial | **linear e dominante** — 76% do erro |
| `base_gr_rotation_factor` | 20.0 | ângulo = `rot × dev / 5` graus | linear, 24% do erro |
| `potent` | 2 | curvatura da conversão diff→dev | abre/fecha a distância entre bom e mau arremesso |
| `magnitude_effect` | 100 | escala do numerador | desloca a curva inteira |
| `num_dice` | 2 | variância do roll | 1 = sorte pesa; 3+ = quase determinístico |
| `base_skill_modifier` | 6 | soma direta no stat | +10 stat ≈ −13% de erro perto de stat 70 |
| `GR_dist_pen` | 18 | penalidade de stat por distância | é a segunda mordida da distância |
| `stat_factor_perfect_throw` | 20 | portão de Perfect | ver tabela abaixo |

Portão de Perfect com 2 dados:

| `stat_factor` | stat_ui 45 | 60 | 75 | 90 |
|---|---|---|---|---|
| 20 (atual) | 1,8% | 3,1% | 4,8% | 6,8% |
| **30** | 3,6% | 6,8% | 10,1% | 15,1% |
| 40 | 6,8% | 12,0% | 18,6% | 26,6% |

---

## 5. Duas propostas de tuning

Ambas assumem os dois bugs corrigidos. Erros em tiles, p50 / p90.

**Proposta A — "erro menor, curva igual"**
`grenade_length_factor 0.10 → 0.075`, `base_gr_rotation_factor 20 → 15`,
`GR_dist_pen 18 → 8`, `stat_factor_perfect_throw 20 → 30`,
limiares `great 0.75 → 0.70`, `inacc 2.00 → 1.50`, `terrible 3.20 → 2.50`.

**Proposta B — A, mas com `potent 2 → 3`**
Mesmo teto de erro para o merc bom, cauda bem mais longa para o ruim: skill passa a
separar de verdade.

| dex/expl | dist | Atual | Só bugs corrigidos | Proposta A | Proposta B |
|---|---|---|---|---|---|
| 50 | 3t | 0,72 / 1,15 | 0,75 / 1,20 | 0,54 / 0,87 | 0,54 / 1,11 |
| 50 | 10t | 2,78 / 4,28 | 2,89 / 4,55 | 1,91 / 3,06 | 1,94 / **3,96** |
| 50 | 15t | 4,62 / 6,96 | 4,85 / 7,41 | 3,05 / 4,82 | 3,17 / **6,34** |
| 80 | 10t | 1,49 / 2,69 | 1,53 / 2,78 | 0,96 / 1,82 | **0,69** / 1,82 |
| 80 | 15t | 2,58 / 4,47 | 2,64 / 4,62 | 1,56 / 2,89 | **1,17** / 2,99 |
| 95 | 10t | 0,99 / 2,01 | 1,01 / 2,05 | 0,57 / 1,31 | **0,32** / 1,11 |
| 95 | 15t | 1,76 / 3,40 | 1,81 / 3,47 | 1,00 / 2,12 | **0,57** / 1,84 |

Recomendação: **B**. Ela resolve o problema real — hoje um merc de stat 95 no alcance
máximo erra por 1,76 tiles na mediana, quase o mesmo que um de stat 80 a 10 tiles.
Investir em Explosivos praticamente não compra precisão. Com `potent 3` o expert passa
a acertar (0,57t) e o novato continua espalhando granada (3,17t p50, 6,34t p90).

O corte de `GR_dist_pen` de 18 para 8 é o que tira a dupla punição de distância; o erro
continua crescendo com o alcance, porque já é proporcional ao vetor — só para de crescer
duas vezes.

### Recalibração dos rótulos

Independente dos números acima: a faixa muda precisa de nome. Com os limiares das
propostas (`0,70 / 1,50 / 2,50`) e um rótulo novo na faixa do meio, as cinco bandas
finalmente cobrem a distribuição inteira — abaixo, a Proposta B a 10 tiles:

| dev | rótulo | dex/expl 50 | 80 | 95 |
|---|---|---|---|---|
| = 0 | Perfect Throw | 3% | 9% | 14% |
| ≤ 0,70 | Great Throw | 4% | 38% | 59% |
| 0,70–1,50 | **Good Throw** (novo) | 23% | 33% | 21% |
| 1,50–2,50 | Innacurate Throw | 31% | 16% | 5% |
| ≥ 2,50 | Terrible Throw | 40% | 4% | — |

Compare com a coluna "(mudo)" da seção 2, onde uma única faixa sem nome levava
45–62% de todos os arremessos.

---

## 6. Ordem sugerida

1. `BUGFIX` do clamp de unidades — muda direção do erro, não a magnitude.
2. `BUGFIX` do `wound_penalty` — faz o Wounded existir e a tooltip parar de mentir.
3. Rótulo novo na faixa muda — feedback antes de balanço.
4. Tuning: `potent`, `grenade_length_factor`, `GR_dist_pen` (Proposta B), validando na
   bancada.
5. Hardening de floats para `MulDivRound`.

Os itens 1, 2 e 5 valem igual para `GrenadeLauncher` e `RocketLauncher`, que passam
pelo mesmo `rat_custom_deviation`. O clamp em si é `is_grenade`-only, mas o
`wound_penalty` e os floats afetam os três.
