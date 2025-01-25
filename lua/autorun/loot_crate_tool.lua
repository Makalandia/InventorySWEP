if SERVER then
    AddCSLuaFile()
end

if CLIENT then
    language.Add("tool.loot_crate_tool.name", "Loot Crate Tool")
    language.Add("tool.loot_crate_tool.desc", "Спавнит ящики с лутом.")
    language.Add("tool.loot_crate_tool.0", "Левый клик для спавна ящика.")
end