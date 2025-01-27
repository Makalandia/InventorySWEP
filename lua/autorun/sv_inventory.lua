if SERVER then
    util.AddNetworkString("AddToInventory")
    util.AddNetworkString("SpawnItem")
    util.AddNetworkString("RequestInventory")
    util.AddNetworkString("SyncInventory")
    util.AddNetworkString("ClearInventory")

    local playerInventories = {}
    local playerDied = {}

    -- Функция добавления предмета в инвентарь игрока
    local function AddToInventory(ply, item)
        if not IsValid(item) then return end

        local itemClass = item:GetClass()
        local itemModel = item:GetModel()

        -- Получаем массу предмета, если это физический объект
        local itemWeight = 2.5  -- Если масса не установлена, то даем значение по умолчанию

        -- Проверка на наличие физического объекта
        local physObj = item:GetPhysicsObject()
        if IsValid(physObj) then
            itemWeight = physObj:GetMass() or itemWeight
        end

        -- Инициализация инвентаря игрока, если он еще не существует
        if not playerInventories[ply] then
            playerInventories[ply] = {}
        end

        -- Добавление предмета в инвентарь
        table.insert(playerInventories[ply], {class = itemClass, model = itemModel, weight = itemWeight})

        -- Синхронизация инвентаря с клиентом
        net.Start("AddToInventory")
        net.WriteString(itemClass)
        net.WriteString(itemModel)
        net.WriteFloat(itemWeight)
        net.Send(ply)

        -- Удаление предмета с мира
        item:Remove()

        -- Вывод сообщения в консоль
        print(ply:Nick() .. " подобрал предмет: " .. itemClass .. " с массой: " .. itemWeight)
    end

    -- Функция спауна предмета
    local function SpawnItem(ply, itemClass, itemModel, spawnPos)
        local spawnedItem

        -- Создание объекта в зависимости от класса
        if scripted_ents.Get(itemClass) then
            spawnedItem = ents.Create(itemClass)
        elseif weapons.Get(itemClass) then
            spawnedItem = ents.Create(itemClass)
        else
            spawnedItem = ents.Create("prop_physics")
            spawnedItem:SetModel(itemModel)
        end

        -- Позиционирование и спаун объекта
        if IsValid(spawnedItem) then
            spawnedItem:SetPos(spawnPos)
            spawnedItem:Spawn()
            print(ply:Nick() .. " выбросил предмет: " .. itemClass)
        else
            print("Ошибка: не удалось заспавнить предмет " .. itemClass)
        end
    end

    -- Получение инвентаря игрока
    net.Receive("RequestInventory", function(_, ply)
        local inventory = playerInventories[ply] or {}
        net.Start("SyncInventory")
        net.WriteTable(inventory)
        net.Send(ply)
    end)

    -- Синхронизация инвентаря с клиентом
    net.Receive("SyncInventory", function(_, ply)
        playerInventories[ply] = net.ReadTable()
    end)

    -- Обработка выброса предмета
    net.Receive("SpawnItem", function(_, ply)
        local itemClass = net.ReadString()
        local itemModel = net.ReadString()

        if not playerInventories[ply] then return end

        -- Удаление предмета из инвентаря
        for i, item in ipairs(playerInventories[ply]) do
            if item and item.class == itemClass and item.model == itemModel then
                table.remove(playerInventories[ply], i)
                break
            end
        end

        -- Спавн предмета перед игроком
        local spawnPos = ply:GetPos() + ply:GetForward() * 100 + Vector(0, 0, 50)
        SpawnItem(ply, itemClass, itemModel, spawnPos)

        -- Синхронизация инвентаря
        net.Start("SyncInventory")
        net.WriteTable(playerInventories[ply])
        net.Send(ply)
    end)

    -- Обработка нажатия на кнопку подбора предмета
    hook.Add("PlayerButtonDown", "PickupItemKey", function(ply, button)
        if button == MOUSE_MIDDLE then
            local trace = ply:GetEyeTrace()
            if trace and IsValid(trace.Entity) then
                local distance = ply:GetPos():Distance(trace.Entity:GetPos())
                if distance <= 100 then
                    AddToInventory(ply, trace.Entity)
                else
                    ply:ChatPrint("Вы слишком далеко, чтобы подобрать этот предмет.")
                end
            end
        end
    end)

    -- Функция расчета общего веса инвентаря игрока
    local function GetInventoryWeight(ply)
        local totalWeight = 0
        if playerInventories[ply] then
            for _, item in ipairs(playerInventories[ply]) do
                if item then
                    totalWeight = totalWeight + (item.weight or 0)
                end
            end
        end
        return totalWeight
    end

    -- Обновление скорости игрока в зависимости от веса инвентаря
    hook.Add("Think", "UpdatePlayerSpeed", function()
        for _, ply in ipairs(player.GetAll()) do
            local totalWeight = GetInventoryWeight(ply)
            local maxWeight = 50  -- Максимально допустимый вес для нормальной скорости

            -- Вычисляем коэффициент замедления на основе веса
            local speedFactor = math.max(1 - ((totalWeight - maxWeight) / 100), 0.5)

            -- Задаем минимальную скорость 15
            local walkSpeed = math.max(15, 200 * speedFactor)
            local runSpeed = math.max(15, 300 * speedFactor)

            -- Устанавливаем скорость
            ply:SetWalkSpeed(walkSpeed)
            ply:SetRunSpeed(runSpeed)
        end
    end)

    -- Обработка смерти игрока
    hook.Add("PlayerDeath", "DropItemsOnDeath", function(ply)
        if playerInventories[ply] then
            for _, item in ipairs(playerInventories[ply]) do
                if item then
                    -- Спавн предмета на месте смерти игрока
                    local deathPos = ply:GetPos()
                    SpawnItem(ply, item.class, item.model, deathPos)
                end
            end
            playerInventories[ply] = {}
            net.Start("ClearInventory")
            net.Send(ply)
        end
    end)
end