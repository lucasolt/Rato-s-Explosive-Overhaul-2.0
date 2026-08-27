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

## 4. O mesmo padrão se repete no caminho de IA com bounce

`Code/FUNCTIONS_AIAdjustment.lua` → `AI_adj_targetpos_for_bounce` roda um loop próprio
de até 40 tentativas testando posições de alvo candidatas (para achar um ricochete que
pouse perto do alvo real), e devolve `best_angle`. Em `GetAttackResults`:

```lua
if can_bounce and not attack_args.prediction and EO_IsAI(attacker) then
    target_pos, ai_trajectory, ai_angle = AI_adj_targetpos_for_bounce(...)
    if ai_angle then attack_args.rat_angle = ai_angle end
end
if not attack_args.prediction and not mishap and not ai_angle then
    traj, angle = self:GetTrajectory(...)     -- pulado quando ai_angle existe
end
```

Quando a IA usa bounce, `ai_angle` já grava em `attack_args.rat_angle` **antes** da
etapa de desvio — e a chamada (3) do item anterior reusa esse ângulo do mesmo jeito.
Vale a mesma correção nos dois lugares.

## 5. O que a correção provavelmente é (não aplicada)

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

Qualquer uma das duas preserva o comportamento desejado para arremessos ruins: se o
raio de desvio for tão grande que **nenhum** dos três ângulos consegue alcançar perto
do ponto sem colidir, a seleção por menor distância ainda vai devolver a trajetória
mais curta disponível — ou seja, o "caos" de um Terrible Throw continua existindo,
porque nesse caso as três parábolas testadas genuinamente falham. O que passa a não
acontecer mais é o caso que motivou o relatório: um desvio pequeno, com uma parábola
alternativa (tipicamente Incline) que teria passado por cima do obstáculo sem
problema, sendo descartada só porque o ângulo escolhido pertencia ao arremesso
pré-desvio.

## 6. Onde olhar para validar antes de mexer

- `Code/SOURCE_GrenadeGetAttackResults.lua:62-94` — as duas chamadas de
  `GetTrajectory` e a escrita de `rat_angle`/`rat_deviate`.
- `Code/SOURCE_GrenadeGetTrajectory.lua:36-55` — a condição que decide 1 ângulo vs. 3.
- `Code/FUNCTIONS_AIAdjustment.lua:36-47` — o mesmo cache via `ai_angle` no caminho de
  bounce da IA.
- A bancada do `DEVIATION_REPORT.md` desenha os anéis de percentil/rótulo mas não
  visualiza colisão de trajetória; para confirmar o achado em jogo, `EO_DeviationDebug
  = true` mostra o raio/direção do desvio, e os `DbgAddCircle_rat` já espalhados em
  `GetAttackResults` (linha ~163) desenham os passos da trajetória final — dá para ver
  ao vivo a granada parando na primeira colisão da única parábola testada.
