---- classes: tabela de lookup das classes. Em ClassesGenerate e o `classdefs` do Msg
---- (todo o codigo de todos os mods ja carregou, entao _22m_HE do ToG patch ja existe,
---- independente da ordem dos mods). Depois do build e g_Classes.
function EO_alterExternalItems(classes)
    classes = classes or g_Classes
    local _40fragshrap, _40fragconcussivf
    local _40frag = classes["_40mmFragGrenade"]
    if _40frag then
        _40fragshrap = _40frag.r_shrap_num
        _40fragconcussivf = _40frag.r_concussive_force
    end
    local _22he = classes["_22m_HE"]
    if _22he then
        _22he.BaseDamage = 32
        _22he.r_shrap_num = _40fragshrap or 350
        _22he.r_concussive_force = _40fragconcussivf or 4
        _22he.AdditionalHint = T(98765432561, "<EO_description_hints>")
    end
end

---- rede de seguranca: reaplica caso algo redefina a classe depois do build
function OnMsg.ModsReloaded()
    EO_alterExternalItems()
end
function OnMsg.DataLoaded()
    EO_alterExternalItems()
end
