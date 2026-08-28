# SHRAPNEL_REPORT.md — estilhaços

Análise de `Code/FUNCTIONS_Shrapnel.lua` e `Code/FUNCTIONS_Shrapnel_VectorGenerators.lua`
(v1.21). Companheiro do [`DEVIATION_REPORT.md`](DEVIATION_REPORT.md).

- **Bancada interativa:** https://claude.ai/code/artifact/f711de15-8b4a-44f9-9283-db5b55646996
  (perfil dos raios, teto por tier, a escada de `r_shrap_num`, sliders de tuning)
- **Modelo reproduzível:** `tools/shrapnel_model.py` — réplica do Lua.
  `python tools/shrapnel_model.py` imprime as tabelas principais.

Os vetores são **enumerados exatamente como no Lua** (espiral de Fibonacci determinística);
só os offsets aleatórios de posição não entram no modelo. A geometria de acerto assume
terreno plano e alvo em pé de 1,8 m × 0,6 m; cobertura e paredes só podem reduzir os
números (`penetration_class = -1` faz cada raio parar no primeiro objeto).
Conversão assumida: 1 tile = 1 m, com `radius = 13000` = 13 tiles de alcance.

---

## 1. O pipeline

```
r_shrap_num  ──► get_FragLevel  ──► frag_args {diminish, shrap_ceiling, step_mul}
     │              (>630 High, >280 Medium, >200 Low, >0 Very Low)
     │
     ├──► × opção shrap_num ──► generateShrapnelVectors (Fibonacci + viés de phi)
     │                          └─► descarta tudo com z ≤ centro   (−44,5%)
     │                              └─► CheckLOF por raio, para no 1º objeto
     │
     └──► por acerto: dmg = 9 × opção_dmg × random_f × dist_t × (1 − redução)
                      redução = min(0,95, (recebidos − diminish) × step_mul)
                      acima de shrap_ceiling o raio é descartado inteiro
```

### A conta que importa

Como o teto por alvo é pequeno e o número de acertos dentro da explosão é grande, o dano
converge para uma constante por tier:

> **dano de estilhaço = 9 × (soma dos multiplicadores da tier) × (fator de zona)**

O `r_shrap_num` não aparece. Ele entra só de duas formas: escolhendo a **tier** e decidindo
quão longe a saturação se mantém.

---

## 2. Para onde os estilhaços vão

`generateShrapnelVectors` distribui uniformemente na esfera e depois aplica um viés:

```lua
phi = phi >= 1.4 and phi * 0.65 or phi * 2.5
```

É um degrau, não uma curva — e ele parte a população em duas:

| ramo | fatia dos raios | o que acontece | sobra |
|---|---|---|---|
| `phi < 1,4` → ×2,5 | 41,5% | espalha de 0° a 3,5 rad; 7% do total passa de 180° | **23%** sobrevive |
| `phi ≥ 1,4` → ×0,65 | 58,5% | comprime numa faixa de 0° a 37,9° de elevação | **78,5%** sobrevive |

Depois `generateShrapnelPositions` descarta tudo com `z > center:z()` falso.
**Resultado: 44,5% dos raios são apagados antes de virar um `CheckLOF`.**

O padrão que sobra é razoável — 89% dos sobreviventes entre 0° e 36° de elevação, que é mais
ou menos o que uma granada de fragmentação faz de verdade. Mas o mecanismo chega lá por
descarte, não por desenho: `r_shrap_num = 700` traça 388 raios.

| r_shrap_num | raios traçados | % |
|---|---|---|
| 75 | 42 | 56,0% |
| 240 | 133 | 55,4% |
| 300 | 166 | 55,3% |
| 350 | 194 | 55,4% |
| 680 | 377 | 55,4% |
| 700 | 388 | 55,4% |

---

## 3. O teto

`shrap_received` conta acertos por unidade e é zerado a cada explosão. A redução é
`(shrap_received − diminish) × step_mul`, avaliada **antes** do incremento — então quando
`shrap_received == diminish` a conta dá zero e aquele acerto ainda sai cheio.

| tier | `diminish` / `ceiling` / `step` | multiplicadores do 1º ao último acerto | soma | dano máx. |
|---|---|---|---|---|
| High | 2 / 5 / 0,5 | 1,00 · 1,00 · 1,00 · 0,50 · 0,05 | 3,55 | **32** |
| Medium | 1 / 3 / 0,75 | 1,00 · 1,00 · 0,25 | 2,25 | **20** |
| Low | 1 / 2 / 0,8 | 1,00 · 1,00 | 2,00 | **18** |
| Very Low | fallback 1 / 1 / 1 | 1,00 | 1,00 | **9** |

"Very Low" e "None" não têm entrada em `frag_args` e caem no fallback
`{diminish=1, shrap_ceiling=1, step_mul=1, max_penalty=1}` — um acerto e acabou.

### Quantos acertos um alvo leva de verdade

HE_Grenade (700, AoE 3), alvo em pé:

| dist | acertos esperados | zona | dano | teto da tier ali |
|---|---|---|---|---|
| 1t | 35,4 | 100% | 31,9 | 31,9 |
| 2t | 17,5 | 100% | 31,9 | 31,9 |
| 3t | 9,4 | 100% | 31,9 | 31,9 |
| 4t | 5,4 | 88% | 28,1 | 28,1 |
| 5t | 3,4 | 88% | 25,5 | 28,1 |
| 6t | 2,4 | 88% | 18,8 | 28,1 |
| 7t | 1,7 | **30%** | 4,6 | 9,6 |
| 9t | 1,0 | 30% | 2,8 | 9,6 |
| 13t | 0,5 | 30% | 1,3 | 9,6 |

Dentro do AoE o alvo leva 7× mais acertos do que o teto permite contar. **A explosão inteira
roda saturada.** O que faz o dano cair não é a geometria — é o degrau de `dist_t`: 100% dentro
do AoE, 88% até o dobro (`radius_mul`), e **30%** depois. De 6t para 7t o dano cai 4×.

---

## 4. A escada

Dano a 2 tiles, varrendo `r_shrap_num`:

| num | tier | dano |
|---|---|---|
| 150 | Very Low | 9,0 |
| 200 | Very Low | 9,0 |
| **201** | **Low** | **18,0** ← degrau |
| 280 | Low | 18,0 |
| **281** | **Medium** | **20,2** ← degrau |
| 400 | Medium | 20,2 |
| 630 | Medium | 20,2 |
| **631** | **High** | **31,9** ← degrau |
| 700 | High | 31,9 |
| 1000 | High | 31,9 |

Entre dois degraus a linha é perfeitamente plana. Um estilhaço a mais em 200 dobra o dano;
300 estilhaços a mais em 700 não fazem nada.

Repare também no tamanho desigual dos degraus: Very Low → Low **dobra** (9 → 18), mas
Low → Medium sobe só 12% (18 → 20,2). O salto Low→Medium acrescenta um acerto que já vale
apenas 0,25.

### Os explosivos do mod

| explosivo | `r_shrap_num` | tier | teto | dano @2t |
|---|---|---|---|---|
| HE_Grenade | 700 | High | 5 | 31,9 |
| NailBomb_IED | 680 | High | 5 | 31,9 |
| HE_Grenade_1 | 350 | Medium | 3 | 20,2 |
| FragGrenade | 300 | Medium | 3 | 20,2 |
| TNTBolt_IED | 300 | Medium | 3 | 20,2 |
| PipeBomb | 240 | Low | 2 | 18,0 |
| C4 / PETN / TNT | 75 | Very Low | 1 | 9,0 |

FragGrenade (300) e HE_Grenade_1 (350) são numericamente diferentes e **mecanicamente
idênticos** — mesma tier, mesmo dano. A diferença de 50 estilhaços só custa CPU.

---

## 5. Achados

### A1 — A opção `shrap_num` não faz o que promete

`get_FragLevel(self)` roda **antes** de `num_shrap` receber o multiplicador da opção:

```lua
local frag_level = get_FragLevel(self)              -- usa r_shrap_num cru
...
num_shrap = MulDivRound(num_shrap, tonumber(CurrentModOptions.shrap_num) or 100, 100)
```

| opção | raios traçados | tier | dano @2t |
|---|---|---|---|
| 25% | 175 | High | 31,7 |
| 50% | 350 | High | 31,9 |
| 100% | 700 | High | 31,9 |
| 200% | 1400 | High | 31,9 |

A opção controla o custo de `CheckLOF` e quase nada mais. Isso é defensável como escolha
(a opção não quebra o balanço), mas o texto dela sugere outra coisa — e a 25% o jogador
paga um quarto do custo de CPU sem perder dano nenhum. Vale ou renomear para o que ela é
(uma opção de performance) ou fazê-la mexer na tier.

### A2 — Os geradores de vetor usam `math.random`

O resto do arquivo é disciplinado: `attacker:Random()` para o seed, para o `random_f`, para
o roll de efeito. Mas os geradores não:

```lua
-- generateShrapnelPositions
local xOffset = math.random(-maxRandomOffset, maxRandomOffset)
local yOffset = math.random(-maxRandomOffset, maxRandomOffset)
local zOffset = math.random(-maxRandomOffset, maxRandomOffset)

-- generateShrapnelPositionsInCone
local theta = math.random() * 2 * math.pi
local h = math.random() * radius * math.tan(angle_radians / 2)
```

Esses offsets decidem quais raios passam pelo filtro `z > center:z()` e para onde apontam —
ou seja, entram direto no dano. Em co-op, dois clientes geram padrões diferentes a partir
da mesma explosão. É a mesma classe de problema que a opção `SkipIEDLootChanges` já
reconhece neste mod.

Troca direta: `InteractionRand(2 * maxRandomOffset, "RATONADE_Shrap", attacker) - maxRandomOffset`.

### A3 — No cone, o `1.12` escala o Z absoluto do mapa

```lua
p = p:SetZ(p:z() * 1.12)
```

Isso multiplica a coordenada Z **absoluta**, não o deslocamento em relação ao centro da
explosão. A elevação do cone passa a depender da altitude do ponto no mapa: a mesma
ShapedCharge aponta mais alto num telhado do que num porão, e o filtro `p:z() >= center:z()`
logo abaixo passa a descartar frações diferentes conforme a altura.

Forma neutra:

```lua
p = p:SetZ(center:z() + MulDivRound(p:z() - center:z(), 112, 100))
```

### A4 — `diminish` começa um acerto depois do que o nome sugere

Na tier High (`diminish = 2`), os acertos 1, 2 **e 3** saem cheios; a queda só começa no
quarto. Não é um bug — é consistente entre as tiers — mas o nome engana na hora de tunar,
e é a razão de Low→Medium ser um degrau tão pequeno.

### A5 — O fallback silencioso de "Very Low"

`get_FragLevel` devolve `"Very Low"` para `0 < num ≤ 200`, e `get_shrap_args` não tem
entrada para essa chave. O `if not entry then` a captura e devolve
`{diminish=1, shrap_ceiling=1, step_mul=1, max_penalty=1}`. Funciona, mas é a tier que todos
os explosivos plantados (C4/PETN/TNT, 75) usam, e ela está definida por acidente e não por
escolha. Vale escrevê-la explicitamente na tabela.

---

## 6. Tuning

Os únicos números que movem o balanço:

| botão | hoje | efeito |
|---|---|---|
| limiares 200 / 280 / 630 | — | definem qual explosivo cai em qual tier. **É o dial principal.** |
| `shrap_ceiling` por tier | 5 / 3 / 2 / 1 | teto duro de acertos por alvo por explosão |
| `diminish` e `step_mul` | — | formato da queda dentro do teto |
| `weapon_shrapnel.Damage` | 9 | escala tudo linearmente |
| `radius_mul` / `secondary_radius_f` / `outer_radius_t` | 2,0 / 88 / 30 | as três zonas; o degrau 88→30 é a queda real |
| `r_shrap_num` | — | só a tier e o alcance da saturação |

Duas sugestões concretas:

**T1 — suavizar o degrau da zona externa.** `outer_radius_t = 30` corta o dano 4× de um tile
para o outro. Com `secondary_radius_f 88 → 80` e `outer_radius_t 30 → 55`, a curva vira uma
descida em vez de um penhasco, e a zona externa passa a existir no jogo (HE_Grenade):

| dist | hoje | com T1 |
|---|---|---|
| 5t | 25,5 | 23,2 |
| 6t | 18,8 | 17,1 |
| 7t | **4,6** | **8,5** |
| 9t | 2,8 | 5,1 |

**T2 — abrir espaço entre Low e Medium.** Hoje Low→Medium vale +12% e Medium→High vale +58%.
Baixar `step_mul` de Medium de 0,75 para 0,4 dá multiplicadores `1,00 · 1,00 · 0,60`
(soma 2,60, dano 23) e distribui melhor os degraus: **9 → 18 → 23 → 32**.

Nada disso precisa mexer em `r_shrap_num` de item nenhum.

---

## 7. Ordem sugerida

> Nada desta seção foi aplicado ainda; a seção 8 cobre uma leva separada, só de performance.

1. `math.random` → `InteractionRand` nos dois geradores (**A2**) — risco de desync em co-op.
2. O `1.12` do cone (**A3**) — comportamento dependente da altitude do mapa.
3. Escrever a tier "Very Low" explicitamente em `frag_args` (**A5**).
4. Tuning das zonas (**T1**) e do `step_mul` de Medium (**T2**), validando na bancada.
5. Decidir o que a opção `shrap_num` deve ser (**A1**): performance ou balanço.

---

## 8. Performance — o que foi aplicado

Marcadores `PERF (C1)` a `PERF (C5)`. **Nenhuma dessas mudanças altera balanço**: o
conjunto de estilhaços gerados é bit a bit o mesmo, e há teste provando isso.

### C1 — o descarte agora vem antes do trabalho caro (o principal)

Era o pedido original: não gastar processamento com o estilhaço que vai para o chão.
O pipeline antigo tinha duas passadas — `generateShrapnelVectors` montava N tabelas
`{x,y,z}` mais dois arrays de debug, e só então `generateShrapnelPositions` jogava fora
os ~44,5% que apontam para baixo. Ou seja: pagava-se trigonometria completa, três
sorteios e várias alocações **por vetor** para descobrir depois que quase metade nem
seria traçada.

Os dois geradores viraram um laço só, com o teste de descarte logo depois do `acos`/`cos`
— antes de `sin(phi)`, das duas funções de `theta`, dos sorteios e do `point()`. Um
estilhaço que vai para o chão passou a custar duas chamadas de trigonometria e nada mais.

O corte é conservador de propósito: usa a margem do offset aleatório
(`zr + maxOffset <= 0` ⇒ morto para qualquer sorteio possível), então **nenhum vetor que
sobrevivia antes passa a ser descartado**.

| HE_Grenade, 700 estilhaços | antes | agora |
|---|---|---|
| chamadas de trigonometria | 4201 | 2565 (**−38%**) |
| tabelas `{x,y,z}` alocadas | 700 | 0 |
| arrays intermediários | 3 (vectors/phis/thetas) | 0 (phi/theta só com debug ligado) |
| chamadas de `math.random` | 2100 | ~1170 |
| posições sobreviventes | 388 | 388 (idênticas) |

### C2 — `reverseTable`

Alocava um array inteiro só para poder percorrer de trás para frente. A ordem importa
(quem chega primeiro conta cheio no teto de `shrap_received`), a cópia não: um laço
decrescente faz o mesmo de graça.

### C3 — invariantes dentro do laço quente

`base_radius` e o raio da faixa secundária são constantes da explosão e estavam sendo
recalculados a cada estilhaço que acerta; `cRound(gren_random / 2)` idem. E o segundo
bloco relia `lof`/`hit`/`hit_pos`, que o bloco acima já tinha calculado no mesmo giro.

### C4 — invariantes do cone

`tan(angle/2)`, `radius²` e `2π` saíram do laço; `point(1,0,0)` e `point(0,0,1)`
deixaram de ser reconstruídos a cada iteração.

### C5 — `coneAngle * num_shrap / 230` → `MulDivRound`

Dependia do `/` da engine para não virar float e alimentar um `for i = 1, numPositions`
com limite float. `MulDivRound` é a forma que o `CLAUDE.md` manda usar e devolve inteiro
sempre. Muda a contagem em ±1 estilhaço (arredonda em vez de truncar).

### Verificação

`tools/shrapnel_perf_test.lua` roda o gerador **real** do repo contra uma reimplementação
da versão antiga e compara as saídas posição a posição. Como o gerador novo sorteia menos
vezes, os dois fluxos de `math.random` divergem por construção — então o teste fixa
`math.random` num valor constante, e aí a contagem de chamadas deixa de importar e as
saídas têm que bater exatamente. Roda no offset central e nos dois extremos, que é onde o
corte conservador do C1 poderia errar:

```
$ lua5.3 tools/shrapnel_perf_test.lua
offset     +0 | antigo 388 pos, 4201 trig | novo 388 pos, 2565 trig | IDENTICO
offset   +150 | antigo 393 pos, 4201 trig | novo 393 pos, 2580 trig | IDENTICO
offset   -150 | antigo 383 pos, 4201 trig | novo 383 pos, 2550 trig | IDENTICO
```

Durante o desenvolvimento este teste pegou duas regressões reais que passariam batido em
revisão: hastear `2*pi/goldenRatio` para fora do laço (`(2π*(i-1))/g` e `(2π/g)*(i-1)`
arredondam diferente) e trocar a associação de `sin*cos*radius + centro` por
`(sin*radius)*cos + centro`. Nos dois casos a contagem de sobreviventes batia e só as
coordenadas mudavam no último bit — exatamente o tipo de coisa que só aparece comparando.

### Achado durante o C4/C5: o caminho do cone está morto

Ao otimizar `generateShrapnelPositionsInCone` ficou claro que **ele nunca roda**. O
gatilho é `if self.coneShaped then` (`FUNCTIONS_Shrapnel.lua`), e `coneShaped` não é
definido nem atribuído em lugar nenhum do mod:

```
$ grep -rin "coneShaped\|coneAngle" --include=*.lua .
Code/FUNCTIONS_Shrapnel.lua:121:    if self.coneShaped then      <- unica LEITURA
Code/PATCH_EO_explosives.lua:87:   ShapedCharge.coneAngle= 40
```

Nada em `items.lua`, nada em `PROPERTIES_Explosives.lua`. Ou seja: `self.coneShaped` é
`nil` para todo explosivo, a ShapedCharge dispersa estilhaço em esfera como qualquer
outro, e o `ShapedCharge.coneAngle = 40` recém-adicionado não tem efeito nenhum — falta
o `ShapedCharge.coneShaped = true` ao lado dele.

Isto **não foi corrigido aqui**: ligar o cone troca a dispersão da ShapedCharge de
esférica para cônica, o que é mudança de balanço e decisão do autor, não de uma leva de
performance. As otimizações C4/C5 ficam prontas para quando o caminho for ligado.

Vale notar que, quando ligar, o C5 muda a contagem em 1 estilhaço para a ShapedCharge
(`r_shrap_num` 350, cone 40°): 60 → 61, porque `MulDivRound` arredonda onde o `/` da
engine truncava. E o A3 (o `1.12` sobre o Z absoluto) só passa a ter efeito real a
partir daí — é no cone que ele vive.

### O que NÃO foi feito, e por quê

**Rejeitar por raycast o estilhaço que entra no chão** — a leitura literal do pedido — não
dá para fazer sem mudar comportamento, e vale registrar o porquê:

- O filtro que já existe (`z > center:z()`) mede o **ponto final** a 13 tiles. Numa
  explosão em terreno plano, todo raio sobrevivente sobe: nenhum "vai para o chão".
- Em rampa ou encostado numa parede, boa parte do hemisfério de cima aponta para dentro do
  terreno. Dava para detectar isso barato com `terrain.GetHeight` no ponto final — mas
  **uma unidade pode estar no caminho, antes da colisão com o chão**. Rejeitar o raio
  perderia esse acerto.
- Encurtar o raio até o ponto de entrada no terreno não ajuda: é exatamente o que o
  `CheckLOF` já faz (`penetration_class = -1`, para no primeiro obstáculo).
- Pular o `CheckLOF` de raios que geometricamente não alcançam unidade nenhuma também não
  fecha: a mesma chamada é quem corta o traçador visual na parede. Sem ela o efeito
  atravessaria paredes.

O ganho real dessa ideia é o C1 — é o mesmo raciocínio ("não pague pelo estilhaço que vai
para baixo"), só movido para onde ele é seguro: antes da geração, não depois do raycast.

Para quem quiser menos raycast de fato, a alavanca já existe e está documentada em **A1**:
a opção `shrap_num` a 25% traça um quarto dos raios sem perder dano nenhum.

### Ainda pendente

Esta leva foi só performance. Continuam abertos, do item 7: **A2** (`math.random` →
`InteractionRand`, risco de desync em co-op — o C1 reduz o número de chamadas mas não
troca a fonte), **A3** (o `1.12` que escala o Z absoluto do mapa) e **A5**.
