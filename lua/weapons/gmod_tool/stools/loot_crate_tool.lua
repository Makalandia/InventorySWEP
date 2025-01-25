TOOL.Name = "Loot Crate Tool"
TOOL.Category = "Construction"

TOOL.ClientConVar["model"] = "models/props_junk/wood_crate001a.mdl"
TOOL.ClientConVar["items"] = "weapon_smg1; item_healthkit"
TOOL.ClientConVar["chances"] = "100; 100"
TOOL.ClientConVar["color_r"] = "255"
TOOL.ClientConVar["color_g"] = "255"
TOOL.ClientConVar["color_b"] = "255"
TOOL.ClientConVar["material"] = ""
TOOL.ClientConVar["health"] = "100"
TOOL.ClientConVar["spawner"] = "0"
TOOL.ClientConVar["spawn_interval"] = "10"
TOOL.ClientConVar["spawn_chance"] = "100"

if CLIENT then
    language.Add("tool.loot_crate_tool.name", "Loot Crate Tool")
    language.Add("tool.loot_crate_tool.desc", "Спавнит ящики с лутом.")
    language.Add("tool.loot_crate_tool.0", "Левый клик для спавна ящика.")
end

local activeSpawners = {}
local spawnerTimers = {}

local function SpawnCrate(spawner)
    if not IsValid(spawner) then
        timer.Remove("LootCrateSpawner_" .. spawner:EntIndex())
        return
    end

    if IsValid(spawner.LootCrate) or math.random(0, 100) > spawner.SpawnChance then return end

    local crate = ents.Create("prop_physics")
    if not IsValid(crate) then return end

    crate:SetModel(spawner.LootModel)
    crate:SetPos(spawner:GetPos() + Vector(0, 0, 50))
    crate:Spawn()

    crate:SetColor(spawner.LootColor)
    if spawner.LootMaterial ~= "" then
        crate:SetMaterial(spawner.LootMaterial)
    end
    crate:SetHealth(spawner.LootHealth)
    crate:SetMaxHealth(spawner.LootHealth)

    crate.LootItems = spawner.LootItems
    crate.LootChances = spawner.LootChances

    function crate:OnTakeDamage(dmginfo)
        if self:Health() <= 0 then
            for i, item in ipairs(self.LootItems) do
                local chance = tonumber(self.LootChances[i]) or 100
                if math.random(0, 100) <= chance then
                    local loot = ents.Create(item)
                    if IsValid(loot) then
                        loot:SetPos(self:GetPos() + Vector(math.random(-10, 10), math.random(-10, 10), 10))
                        loot:Spawn()
                    end
                end
            end
            self:Remove()
            spawner.LootCrate = nil
            timer.Simple(spawner.SpawnInterval or 10, function() SpawnCrate(spawner) end)
        else
            self:SetHealth(self:Health() - dmginfo:GetDamage())
        end
    end

    spawner.LootCrate = crate
    undo.Create("Loot Crate")
    undo.AddEntity(crate)
    undo.SetPlayer(spawner:GetOwner())
    undo.Finish()
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    local model = self:GetClientInfo("model")
    local items = self:GetClientInfo("items")
    local chances = self:GetClientInfo("chances")
    local color_r = tonumber(self:GetClientInfo("color_r"))
    local color_g = tonumber(self:GetClientInfo("color_g"))
    local color_b = tonumber(self:GetClientInfo("color_b"))
    local material = self:GetClientInfo("material")
    local health = tonumber(self:GetClientInfo("health"))
    local spawner = tobool(self:GetClientInfo("spawner"))
    local spawn_interval = tonumber(self:GetClientInfo("spawn_interval")) or 10
    local spawn_chance = tonumber(self:GetClientInfo("spawn_chance")) or 100

    if not util.IsValidModel(model) or not util.IsValidProp(model) then return false end

    if spawner then
        local spawner_ent = ents.Create("prop_physics")
        if not IsValid(spawner_ent) then return false end

        spawner_ent:SetModel("models/hunter/blocks/cube025x025x025.mdl")
        spawner_ent:SetPos(trace.HitPos + trace.HitNormal * 16)
        spawner_ent:Spawn()
        spawner_ent:SetCollisionGroup(COLLISION_GROUP_WORLD)  -- Отключаем коллизию для ящика
        spawner_ent:GetPhysicsObject():EnableMotion(false)  -- Замораживаем проп

        spawner_ent.LootItems = string.Split(items, "; ")
        spawner_ent.LootChances = string.Split(chances, "; ")
        spawner_ent.LootModel = model
        spawner_ent.LootColor = Color(color_r, color_g, color_b)
        spawner_ent.LootMaterial = material
        spawner_ent.LootHealth = health
        spawner_ent.SpawnInterval = spawn_interval
        spawner_ent.SpawnChance = spawn_chance
        spawner_ent.LootCrate = nil

        table.insert(activeSpawners, spawner_ent)

        spawnerTimers[spawner_ent:EntIndex()] = true
        timer.Create("LootCrateSpawner_" .. spawner_ent:EntIndex(), spawner_ent.SpawnInterval, 0, function()
            if spawnerTimers[spawner_ent:EntIndex()] then
                SpawnCrate(spawner_ent)
            end
        end)

        undo.Create("Loot Crate Spawner")
        undo.AddEntity(spawner_ent)
        undo.SetPlayer(ply)
        undo.Finish()

        return true
    else
        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then return false end

        ent:SetModel(model)
        ent:SetPos(trace.HitPos + trace.HitNormal * 16)
        ent:Spawn()

        ent.LootItems = string.Split(items, "; ")
        ent.LootChances = string.Split(chances, "; ")

        -- Устанавливаем цвет ящика
        ent:SetColor(Color(color_r, color_g, color_b))

        -- Устанавливаем материал ящика
        if material ~= "" then
            ent:SetMaterial(material)
        end

        -- Устанавливаем здоровье ящика с проверкой на минимальное значение -1
        if health < -1 then
            health = -1
        end
        ent:SetHealth(health)
        ent:SetMaxHealth(health)

        -- Добавляем collision callback для определения уничтожения
        function ent:OnTakeDamage(dmginfo)
            if self:Health() <= 0 then
                for i, item in ipairs(self.LootItems) do
                    local chance = tonumber(self.LootChances[i]) or 100
                    if math.random(0, 100) <= chance then
                        local loot = ents.Create(item)
                        if IsValid(loot) then
                            loot:SetPos(self:GetPos() + Vector(math.random(-10, 10), math.random(-10, 10), 10))
                            loot:Spawn()
                        end
                    end
                end
                self:Remove()
            else
                self:SetHealth(self:Health() - dmginfo:GetDamage())
            end
        end

        undo.Create("Loot Crate")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
        undo.Finish()

        return true
    end
end

function TOOL:RightClick(trace)
    return false
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {Description = "Настройки Loot Crate Tool"})
    panel:AddControl("TextBox", {Label = "Модель ящика", Command = "loot_crate_tool_model", MaxLength = 256})
    panel:AddControl("TextBox", {Label = "Предметы внутри ящика (через ; )", Command = "loot_crate_tool_items", MaxLength = 256})
    panel:AddControl("TextBox", {Label = "Шанс предмета (через ; )", Command = "loot_crate_tool_chances", MaxLength = 256})
    panel:AddControl("Slider", {Label = "Здоровье ящика", Command = "loot_crate_tool_health", Type = "Float", Min = -1, Max = 1000})
    panel:AddControl("Color", {Label = "Цвет ящика", Red = "loot_crate_tool_color_r", Green = "loot_crate_tool_color_g", Blue = "loot_crate_tool_color_b"})
    panel:AddControl("TextBox", {Label = "Материал ящика", Command = "loot_crate_tool_material", MaxLength = 256})
    panel:AddControl("Slider", {Label = "Период времени спавна ящика (в секундах)", Command = "loot_crate_tool_spawn_interval", Type = "Float", Min = 1, Max = 3600})
    panel:AddControl("Slider", {Label = "Шанс спавна ящика (%)", Command = "loot_crate_tool_spawn_chance", Type = "Float", Min = 0, Max = 100})
    panel:AddControl("CheckBox", {Label = "Установить спавнер ящика", Command = "loot_crate_tool_spawner"})
    panel:AddControl("Button", {Label = "Удалить все заспавненные ящики", Command = "loot_crate_tool_remove_all"})
    panel:AddControl("Button", {Label = "Приостановить спавн ящиков", Command = "loot_crate_tool_pause_spawning"})
    panel:AddControl("Button", {Label = "Начать спавн ящиков", Command = "loot_crate_tool_start_spawning"})
end

if SERVER then
    util.AddNetworkString("LootCrateTool_RemoveAll")
    util.AddNetworkString("LootCrateTool_PauseSpawning")
    util.AddNetworkString("LootCrateTool_StartSpawning")

    net.Receive("LootCrateTool_RemoveAll", function(len, ply)
        for _, spawner in ipairs(activeSpawners) do
            if IsValid(spawner) and IsValid(spawner.LootCrate) then
                spawner.LootCrate:Remove()
            end
        end
    end)

    net.Receive("LootCrateTool_PauseSpawning", function(len, ply)
        for _, spawner in ipairs(activeSpawners) do
            if IsValid(spawner) then
                spawnerTimers[spawner:EntIndex()] = false
            end
        end
    end)

    net.Receive("LootCrateTool_StartSpawning", function(len, ply)
        for _, spawner in ipairs(activeSpawners) do
            if IsValid(spawner) then
                spawnerTimers[spawner:EntIndex()] = true
            end
        end
    end)
end

if CLIENT then
    concommand.Add("loot_crate_tool_remove_all", function()
        net.Start("LootCrateTool_RemoveAll")
        net.SendToServer()
    end)

    concommand.Add("loot_crate_tool_pause_spawning", function()
        net.Start("LootCrateTool_PauseSpawning")
        net.SendToServer()
    end)

    concommand.Add("loot_crate_tool_start_spawning", function()
        net.Start("LootCrateTool_StartSpawning")
        net.SendToServer()
    end)
end

-- Дополнительный хук для обработки урона
if SERVER then
    hook.Add("EntityTakeDamage", "LootCrateDamage", function(target, dmginfo)
        if target.LootItems then
            target:OnTakeDamage(dmginfo)
        end
    end)
end