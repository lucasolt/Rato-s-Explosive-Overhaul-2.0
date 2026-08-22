# Console Lua remoto no jogo rodando

O executável do Jagged Alliance 3 **é** um debug adapter: serve DAP (Debug Adapter
Protocol) em `127.0.0.1:8165`. É a porta que a extensão `SolEngineLua.vsix`
(HaemimontGames) usa com `"request": "attach"` — mas dá para falar DAP direto, sem VS
Code no meio.

`tools/dap_probe.py` faz isso. Stdlib do Python 3, sem pip.

## O achado que importa

**`evaluate` funciona com o jogo rodando livre**, sem breakpoint e sem `frameId`. Ou
seja: é um console Lua no processo vivo, não um inspetor que só funciona pausado.

Capabilities que o adapter devolve:

```json
{
  "completionTriggerCharacters": [".", ":", "}"],
  "supportTerminateDebuggee": true,
  "supportsBreakpointLocationsRequest": true,
  "supportsCompletionsRequest": true,
  "supportsConditionalBreakpoints": true,
  "supportsConfigurationDoneRequest": true,
  "supportsHitConditionalBreakpoints": true,
  "supportsLogPoints": true,
  "supportsSetExpression": false,
  "supportsSetVariable": true,
  "supportsTerminateRequest": true,
  "supportsVariableType": true
}
```

`threads` / `stackTrace` / `scopes` / `variables` / `setBreakpoints` também respondem —
`--frame` pega um `frameId` do primeiro frame quando for preciso avaliar num escopo
local. Para o uso normal (ler e mexer em globais do jogo) não é preciso.

## Pré-requisito

A porta só existe no **`JA3Debug.exe`**. Confira com o jogo aberto:

```powershell
netstat -ano | findstr 8165
```

Sem `LISTENING`, não adianta insistir na sonda — o jogo aberto é o `JA3.exe` normal.
Aparecer uma linha `ESTABLISHED` junto é normal (VS Code ou uma sonda anterior); o
adapter aceita mais de um cliente.

## Uso

```bash
# expressões soltas
python tools/dap_probe.py 'tostring(RATOAI_Debug)' 'tostring(g_Combat.current_turn)'

# um bloco de várias linhas
python tools/dap_probe.py -f consulta.lua

# via stdin
echo 'tostring(SelectedObj.session_id)' | python tools/dap_probe.py -

# só o handshake, para ver as capabilities
python tools/dap_probe.py --caps
```

Flags: `-v` ecoa todo o tráfego DAP em stderr, `--events` imprime os eventos recebidos,
`--raw` desliga a limpeza do rodapé de `metatable` que o adapter anexa a todo valor,
`--frame` avalia dentro do primeiro stack frame.

Para várias linhas numa expressão só, embrulhe numa função anônima aplicada — é a forma
que devolve valor de forma confiável:

```lua
(function()
    local out = {}
    for _, t in ipairs(g_Teams or {}) do
        for _, u in ipairs(t.units or {}) do
            if u.ai_context then out[#out+1] = tostring(u.session_id) end
        end
    end
    return table.concat(out, " | ")
end)()
```

## Cuidados

- **Nada de breakpoint sem alguém no teclado.** Um breakpoint que dispara sem `continue`
  congela o jogo. A sonda não põe nenhum.
- A sonda sempre manda `disconnect` no fim, inclusive em caminho de erro (`try/finally`).
- **Avaliar não é grátis.** Chamar `AIPrecalcDamageScore` consome RNG (`unit:RandRange`,
  `InteractionRand`) e mexe no `ai_context` da unidade. Em partida valendo isso altera o
  estado. Use `context.dbg_freeze_target_rand = true` antes, que é o que a própria
  `IModeAIDebug:PrecalcForDebug` faz.
- **Regra dura, aprendida quebrando: a sonda é para LER.** Ler campo (`unit.ActionPoints`,
  `context.dbg_targets[dest]`, `pol.Weight`) é seguro. Chamar função de engine com
  posição/voxel **construído na mão** não é: `point_pack(WorldToVoxel(...))` montado na
  query, ou `policy:EvalDest(context, dest, grid_voxel)` invocado fora do fluxo normal,
  dispara `assert` de point inválido (`IsValidPos`, `RATOAI_ValidatePosZ`) e polui a
  sessão de quem está jogando. Se precisar de um valor derivado, prefira ler o que o
  próprio turno já gravou — é para isso que o `DEBUG (D1)` existe.
- Benchmark é a exceção tolerável, mas use posições que vieram do jogo
  (`GetPassSlab(unit)`, `unit:GetPos()`), nunca coordenadas remontadas.
- Timeout de 5s por requisição, sem bloqueio infinito.

## Exemplo real: como isto achou o B16

A página Alvo do painel de debug mostrava todas as colunas novas com `-`. Três
expressões resolveram:

```
tostring(RATOAI_Debug)                                              => false
tostring(Platform.developer) .. " / " .. tostring(Platform.cheats)  => true / true
tostring(IModeAIDebug.PrecalcForDebug ~= nil)                       => true
```

Código novo carregado, cheats ligados, e ainda assim a flag `false`: ela era avaliada uma
vez no load, antes de o `ForceDev.lua` do mod *Rato Dev* ligar as `Platform.*`. Ver
**B16** no `WEIGHTS_AUDIT.md`.

Depois, com `RATOAI_Debug = true` setado ao vivo e um `AIPrecalcDamageScore` refeito no
`ai_context` de um inimigo, a captura do `DEBUG (D1)` apareceu inteira — que foi a prova
de que só faltava a flag:

```
alvos=4  best=117  thr=94  total=228  roll=84  finalistas=2  chosen=Barry
  Grizzly  dist=24  shots=1  cth1=28  hit=28  score=111
  Barry    dist=14  shots=1  cth1=51  hit=51  score=117   <- escolhido
  MD       dist=19  shots=1  cth1=0                        rej="soma de CTH 0 <= 0"
  Kalyna   dist=25  shots=1  cth1=8   hit=8   score=82     (abaixo do corte)
```

## Consultas úteis

```lua
-- estado do debug do mod
tostring(RATOAI_Debug)

-- quem tem ai_context vivo (o jogo apaga no fim do turno da unidade)
(function()
    local out = {}
    for _, t in ipairs(g_Teams or {}) do
        for _, u in ipairs(t.units or {}) do
            if u.ai_context then
                out[#out+1] = string.format("%s side=%s dests=%d",
                    tostring(u.session_id), tostring(t.side),
                    #(u.ai_context.destinations or {}))
            end
        end
    end
    return table.concat(out, " | ")
end)()

-- linhas por alvo de um destino (precisa de RATOAI_Debug ligado no turno)
(function()
    local u = SelectedObj
    local c = u and u.ai_context
    local d = c and c.ai_destination
    local dd = d and c.dbg_targets and c.dbg_targets[d]
    if not dd then return "sem dbg_targets" end
    local out = {}
    for tgt, row in pairs(dd.by_target) do
        out[#out+1] = string.format("%s cth1=%s hit=%s score=%s rej=%s",
            tostring(tgt.session_id), tostring(row.cth1), tostring(row.hit),
            tostring(row.score), tostring(row.reject))
    end
    return table.concat(out, " ;; ")
end)()
```
