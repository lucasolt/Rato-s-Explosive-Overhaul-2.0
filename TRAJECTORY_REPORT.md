# TRAJECTORY_REPORT.md — a trajetória até o ponto desviado

Diagnóstico apenas, sem alterações de código. Escopo: **não** é o motor de desvio
(`Code/FUNCTIONS_DeviateGrenade.lua`, já reescrito — ver `DEVIATION_REPORT.md`, que
descreve o motor antigo e está desatualizado nesse ponto). O problema aqui é o que
acontece **depois** que o ponto desviado existe: qual trajetória a granada percorre
para chegar até ele.

## 1. Sintoma

Um obstáculo no meio do caminho, combinado com um ângulo baixo e um desvio pequeno na
posição, faz a granada colidir e parar muito antes do ponto esperado — mesmo em casos
onde uma parábola mais alta (Incline) claramente passaria por cima. O usuário quer
manter esse comportamento como parte do "caos" de arremessos ruins, mas eliminar a
imprecisão excessiva nos casos em que a unidade "claramente tentaria" jogar por cima.

## 2. O mecanismo já existe — e já faz exatamente isso

`Grenade:GetTrajectory` (`Code/SOURCE_GrenadeGetTrajectory.lua`) tem uma rotina de
teste-e-escolha de ângulo:

```lua
elseif valid_target or mishap or attack_args.rat_deviate and not bounce_angle then
    if target_pos:z() - attack_pos:z() >= 2 * const.SlabSizeZ then
        angles[1] = const.Combat.GrenadeLaunchAngle_Incline
        angles[2] = const.Combat.GrenadeLaunchAngle
    else
        if target_pos:z() - attack_pos:z() <= const.SlabSizeZ / 2 then
            angles[1] = const.Combat.GrenadeLaunchAngle_Low
        end
        angles[#angles + 1] = const.Combat.GrenadeLaunchAngle
        if not GameState.Underground then
            angles[#angles + 1] = const.Combat.GrenadeLaunchAngle_Incline
        end
    end
end
```

e mais embaixo, o critério de escolha:

```lua
for _, angle in ipairs(angles) do
    local trajectory = self:CalcTrajectory(attack_args, target_pos, angle, ...)
    local hit_pos = (#trajectory > 0) and trajectory[#trajectory].pos
    if hit_pos and (hit_pos:Dist(trajectory[1].pos) > 0) then
        if IsCloser(hit_pos, target_pos, const.SlabSizeX) then
            best_trajectory, final_angle = trajectory, angle
            break                                    -- bom o suficiente, para
        end
        local dist = hit_pos:Dist(target_pos)
        if dist < best_dist then
            best_dist, best_trajectory = dist, trajectory   -- guarda a melhor até agora
            final_angle = angle
        end
    end
end
```

Isso é literalmente "testar trajetórias e escolher a melhor por um critério" — até três
candidatas (Low/Level/Incline, conforme a diferença de altura), cada uma simulada por
`CalcTrajectory` → `CalcBounceParabolaTrajectory` (que já resolve colisão, `no_col =
false`), com a que chega mais perto do alvo vencendo. **Não precisa ser desenhado do
zero — precisa ser destravado para o caso de posição desviada.**

## 3. Por que ele não roda quando a posição é desviada

`Code/SOURCE_GrenadeGetAttackResults.lua` chama `GetTrajectory` **duas vezes** por
arremesso, no mesmo `attack_args` (mutado in-place, não é cópia):

```
1) traj, angle = self:GetTrajectory(attack_args, attack_pos, target_pos, mishap)
                 -- target_pos ainda é o ORIGINAL (pré-desvio)
   if angle then attack_args.rat_angle = angle end

2) target_pos, deviate = self:rat_deviation(...)   -- agora target_pos é o desviado

3) trajectory = not deviate and (ai_trajectory or traj)
                or self:GetTrajectory(attack_args, attack_pos, target_pos, mishap)
                 -- target_pos aqui já é o desviado; attack_args.rat_angle
                 -- ainda carrega o ângulo escolhido no passo (1)
```

E o topo de `GetTrajectory`:

```lua
if attack_args.rat_angle and not bounce_angle and not mishap then
    angles = {attack_args.rat_angle}          -- <-- SEMPRE cai aqui na chamada (3)
elseif valid_target or mishap or attack_args.rat_deviate and not bounce_angle then
    ...                                        -- o teste de 3 ângulos, nunca alcançado
end
```

Como `deviate` é verdadeiro sempre que o raio de desvio é > 0 (a maioria dos
arremessos, ver `DEVIATION_REPORT.md` seção 2 — mesmo com o motor novo isso continua
valendo em espírito), a chamada (3) roda quase sempre. E como o passo (1) quase sempre
encontra um ângulo válido para o alvo original e grava em `attack_args.rat_angle`, a
condição `attack_args.rat_angle and not bounce_angle and not mishap` é verdadeira na
chamada (3) — o branch de teste múltiplo nunca executa para a posição já desviada.

**A granada desviada herda o ângulo que funcionou para uma posição diferente da que
ela de fato precisa alcançar**, e testa exatamente **uma** trajetória. Se essa
trajetória bate num obstáculo, não há segunda tentativa: `best_trajectory` é o que
sobrou da única simulação, por mais curto que tenha ficado.

Achado colateral: a flag `attack_args.rat_deviate`, escrita especificamente para esse
`elseif` (linha 93 do `GetAttackResults`, "attack_args.rat_deviate = deviate"), é
**inalcançável** nesse ponto — não só pela precedência do `if` anterior, mas porque
`valid_target` está *hardcoded* `true` (o sanity-check foi comentado: "Removed the
sanity check. Why not? :)", linha 13-25 do mesmo arquivo `GetTrajectory`). Ou seja, a
condição do `elseif`, quando alcançável, é sempre verdadeira de qualquer forma — o
autor parece ter escrito o gatilho certo (`rat_deviate`) no lugar certo, mas o cache de
`rat_angle` do passo (1) intercepta antes que ele seja avaliado.

## 4. O caminho de IA com bounce é um caso à parte — não é o mesmo bug

`Code/FUNCTIONS_AIAdjustment.lua` → `AI_adj_targetpos_for_bounce` roda um loop próprio
de até 40 tentativas testando posições de alvo candidatas (para achar um ricochete que
pouse perto do alvo real), e devolve `best_target_pos`, `best_traj`, `best_angle`. Em
`GetAttackResults`:

```lua
if can_bounce and not attack_args.prediction and EO_IsAI(attacker) then
    target_pos, ai_trajectory, ai_angle = AI_adj_targetpos_for_bounce(attack_args,
                                                                       target_pos, attack_pos, self)
    if ai_angle then attack_args.rat_angle = ai_angle end
end
if not attack_args.prediction and not mishap and not ai_angle then
    traj, angle = self:GetTrajectory(...)     -- pulado quando ai_angle existe
end
```

Superficialmente parece o mesmo cache do item 3 (`ai_angle` grava em
`attack_args.rat_angle` e é reusado depois do desvio). Mas aqui **`target_pos` também
é reatribuído** pelo retorno de `AI_adj_targetpos_for_bounce` — ou seja, o ponto que
`rat_deviation` desvia não é mais o alvo que o jogador/IA originalmente mirou, é o
**ponto de mira compensado**: a posição de onde, jogando com `ai_angle`, o ricochete
calculado por `get_bounces` pousa perto do alvo de verdade. Esse par
(`ai_angle`, ponto de mira) não é arbitrário — foi resolvido por uma busca de 40
tentativas justamente para cancelar o efeito do bounce que o mod acrescentou. É por
isso que essa granada precisa de tratamento especial e **não** pode simplesmente cair
no mesmo conserto do item 3.

Duas consequências, uma da lógica de ângulo e outra da lógica de bounce em si:

**a) Reusar `ai_angle` para o ponto de mira desviado quebra o acoplamento fino que fez
o ricochete funcionar.** A física de bounce é sensível à combinação exata
ângulo+ponto de mira — um pequeno deslocamento no ponto (efeito do desvio) muda onde a
granada bate primeiro e, por consequência não-linear, onde ela ricocheteia depois. Não
dá para simplesmente destravar o teste de 3 ângulos (a correção do item 5) para este
caso: esses 3 ângulos (Low/Level/Incline) foram pensados para arco direto, não para
recalcular um ricochete — testar contra o ponto de mira desviado com esses ângulos
ignora a lógica de bounce inteira e provavelmente erra de outro jeito.

**b) Mais grave: para o arremesso desviado, o pós-processamento de bounce nem roda.**
Mais abaixo em `GetAttackResults`:

```lua
if not ai_trajectory and #trajectory > 0 and can_bounce and not mishap then
    trajectory, bounce_pos = get_bounces(self, trajectory, attack_args, explosion_pos)
end
```

A guarda é `not ai_trajectory` — mas `ai_trajectory` é a variável local setada lá em
cima pela chamada de `AI_adj_targetpos_for_bounce`, e ela continua truthy pelo resto da
função **mesmo depois que `trajectory` foi sobrescrita** pela chamada 3 do item
anterior (a recomputação pós-desvio). Ou seja: quando há desvio (`deviate = true`,
quase sempre), `trajectory` passa a ser a parábola direta recém-calculada com
`ai_angle` contra o ponto de mira desviado — mas o bloco que chama `get_bounces` é
pulado, porque olha para o `ai_trajectory` antigo (da chamada pré-desvio), não para se
a trajetória *atual* já passou por um ricochete. **Resultado: para granadas de IA com
bounce habilitado, assim que há desvio, o ricochete simplesmente não é simulado — a
explosão acontece na primeira colisão da parábola direta**, como se `can_bounce` fosse
falso. Isso é independente do bug do item 3 e provavelmente pesa mais no sintoma
descrito (a granada "batendo e parando antes" seria, no caso de IA, uma granada que
deveria ricochetear e não ricocheteia).

Não tenho uma correção pronta para este caso — ao contrário do item 3, aqui não dá para
simplesmente "destravar" o teste de ângulos, porque o problema não é falta de teste, é
que o alvo do teste (o ponto de mira compensado) e o critério de sucesso (chegar perto
do ponto de mira) já não descrevem o que se quer quando o alvo real mudou por desvio.
Um encaminhamento possível, a validar depois:

- Aplicar o desvio **antes** de `AI_adj_targetpos_for_bounce`, sobre o alvo real
  (o que o ataque de fato mirava), e deixar a busca de 40 tentativas resolver de novo
  o ponto de mira/ângulo para esse alvo já desviado — mais correto fisicamente, mas
  reexecuta a busca cara (até 40× `GetTrajectory`) a cada arremesso de IA com desvio,
  o que já era descrito como ponto de atenção de performance no `PERF_PLAN.md`.
- Ou, se o custo acima for proibitivo, ao menos consertar a guarda `not ai_trajectory`
  do bloco de bounce para refletir a trajetória *atual* (pós-desvio) em vez do sinal
  desatualizado — resolve pelo menos a consequência (b), mesmo mantendo (a) sem
  solução ideal.

Qualquer uma das duas precisa de teste dedicado antes de mexer — este é o ponto do
relatório com mais incerteza, e foi sinalizado pelo autor como tal.

## 5. O que a correção do caso não-IA (item 3) provavelmente é (não aplicada)

Não é preciso inventar um critério de escolha novo — o critério "testa até 3 ângulos,
prefere o que cai a ≤1 tile do alvo, senão o de menor distância" já é razoável e já
existe. O bug é só o cache indevido. Duas direções possíveis, sem tocar em código
agora:

- **Invalidar `attack_args.rat_angle` antes da chamada (3)** em
  `GetAttackResults`, já que o alvo mudou (desvio). Isso faz a chamada pós-desvio cair
  no `elseif` e testar Low/Level/Incline de verdade contra o ponto desviado.
- Alternativa mais cirúrgica: em `GetTrajectory`, também exigir
  `not attack_args.rat_deviate` na condição do primeiro `if`, para que a flag que já
  existe (e já é escrita no lugar certo) volte a fazer o que o nome promete.

**Isso vale só para o caminho sem bounce de IA** (jogador, ou IA sem `can_bounce`/sem
`ai_angle`). Para o caso do item 4, aplicar a mesma invalidação de `rat_angle` teria um
efeito colateral: o teste de 3 ângulos rodaria contra o ponto de mira compensado como
se fosse um alvo direto, ignorando que aquele ponto só faz sentido dentro da lógica de
ricochete. Os dois consertos precisam ficar desacoplados — provavelmente condicionando
a invalidação a `not ai_angle` (ou tratando o ramo de IA com bounce à parte,
como descrito no item 4).

Qualquer uma das duas (para o caso não-IA) preserva o comportamento desejado para
arremessos ruins: se o raio de desvio for tão grande que **nenhum** dos três ângulos
consegue alcançar perto do ponto sem colidir, a seleção por menor distância ainda vai
devolver a trajetória mais curta disponível — ou seja, o "caos" de um Terrible Throw
continua existindo, porque nesse caso as três parábolas testadas genuinamente falham.
O que passa a não acontecer mais é o caso que motivou o relatório: um desvio pequeno,
com uma parábola alternativa (tipicamente Incline) que teria passado por cima do
obstáculo sem problema, sendo descartada só porque o ângulo escolhido pertencia ao
arremesso pré-desvio.

## 6. Onde olhar para validar antes de mexer

- `Code/SOURCE_GrenadeGetAttackResults.lua:62-94` — as duas chamadas de
  `GetTrajectory` e a escrita de `rat_angle`/`rat_deviate`.
- `Code/SOURCE_GrenadeGetTrajectory.lua:36-55` — a condição que decide 1 ângulo vs. 3.
- `Code/FUNCTIONS_AIAdjustment.lua:36-47` — a busca de 40 tentativas que resolve
  ângulo + ponto de mira compensado para o bounce da IA.
- `Code/SOURCE_GrenadeGetAttackResults.lua:160` — a guarda `not ai_trajectory` que
  pula `get_bounces` para o resultado pós-desvio.
- A bancada do `DEVIATION_REPORT.md` desenha os anéis de percentil/rótulo mas não
  visualiza colisão de trajetória; para confirmar o achado em jogo, `EO_DeviationDebug
  = true` mostra o raio/direção do desvio, e os `DbgAddCircle_rat` já espalhados em
  `GetAttackResults` (linha ~163) desenham os passos da trajetória final — dá para ver
  ao vivo a granada parando na primeira colisão da única parábola testada.
