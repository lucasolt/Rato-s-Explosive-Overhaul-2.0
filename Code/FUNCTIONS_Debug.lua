local enabled
function rat_printGR(...)
    local enabled

    if enabled then
        print(...)
    end
end

function DbgAddVector_rat(attack_args, a, b, color)
    if true then
        return
    end
    if not attack_args or attack_args.prediction then
        return
    end
    DbgAddVector(a, b, color)
end

function rat_printBounce(...)
    local enabled -- = true

    if enabled then
        print(...)
    end
end

function DbgAddText_rat(attack_args, text, pos, color)
    if true then
        return
    end
    if not attack_args or attack_args.prediction then
        return
    end
    DbgAddText(text, pos, color)
end

function DbgAddCircle_rat(attack_args, a, b, color)
    if true then
        return
    end
    if not attack_args or attack_args.prediction then
        return
    end
    DbgAddCircle(a, b, color)
end

function DbgAddCircle_collide_test(pos, r, c)
    -- local enabled = true
    if enabled then
        DbgAddCircle(pos, r, c)
    end
end

---- Os dois respeitam a chave mestra EO_DeviationDebug (definida em
---- FUNCTIONS_DeviateGrenade.lua). Assim EO_DeviationDebug = false apaga tudo que o
---- desvio desenha, inclusive o ponto de impacto e o vetor, que nao passam pelos
---- toggles de anel.
function DbgAddCircle_devi(a, b, color)
    if EO_DeviationDebug ~= false then
        DbgAddCircle(a, b, color)
    end
end

function DbgAddVector_devi(a, b, color)
    if EO_DeviationDebug ~= false then
        DbgAddVector(a, b, color)
    end
end

function DbgAddCircle_ai_adj(a, b, c)
    -- local enabled = true
    if enabled then
        DbgAddCircle(a, b, c)
    end
end

function DbgAddVector_ai_adj(a, b, c)
    -- local enabled = true
    if enabled then
        DbgAddVector(a, b, c)
    end
end
