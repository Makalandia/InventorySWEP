if CLIENT then
    local inventory = {}
    local inventoryOpen = false
    local inventoryFrame = nil
    local playerDied = false

    net.Receive("SyncInventory", function()
        inventory = net.ReadTable()
    end)

    net.Receive("AddToInventory", function()
        local itemClass = net.ReadString()
        local itemModel = net.ReadString()
        local itemWeight = net.ReadFloat() -- Вес предмета
        table.insert(inventory, {class = itemClass, model = itemModel, weight = itemWeight})
        UpdateInventoryUI()
    end)

    net.Receive("ClearInventory", function()
        inventory = {}
        playerDied = true
    end)

    local function OpenInventory()
        if inventoryOpen then return end
        inventoryOpen = true

        if playerDied then
            inventory = {}
            playerDied = false
            net.Start("SyncInventory")
            net.WriteTable(inventory)
            net.SendToServer()
        end

        net.Start("RequestInventory")
        net.SendToServer()

        inventoryFrame = vgui.Create("DFrame")
        inventoryFrame:SetTitle("Инвентарь")
        inventoryFrame:SetSize(500, 500)
        inventoryFrame:Center()
        inventoryFrame:MakePopup()

        inventoryFrame.OnClose = function()
            inventoryOpen = false
            net.Start("SyncInventory")
            net.WriteTable(inventory)
            net.SendToServer()
            inventoryFrame = nil
        end

        local grid = vgui.Create("DGrid", inventoryFrame)
        grid:SetPos(10, 30)
        grid:SetCols(10)
        grid:SetColWide(48)
        grid:SetRowHeight(48)

        for i = 1, 100 do
            local slot = vgui.Create("DButton")
            slot:SetSize(48, 48)
            slot:SetText("")
            grid:AddItem(slot)
        end

        UpdateInventoryUI()
    end

    function UpdateInventoryUI()
        if not inventoryFrame then return end

        local grid = inventoryFrame:GetChildren()[2]
        if not grid then return end

        for index, slot in ipairs(grid:GetItems()) do
            slot:Clear()
            local item = inventory[index]
            if item then
                local model = item.model or "models/props_junk/watermelon01.mdl"

                local icon = vgui.Create("SpawnIcon", slot)
                icon:SetSize(48, 48)
                icon:SetModel(model)
                icon:SetToolTip(item.class)
                icon.DoClick = function()
                    net.Start("SpawnItem")
                    net.WriteString(item.class)
                    net.WriteString(item.model)
                    net.SendToServer()

                    inventory[index] = nil
                    icon:Remove()

                    net.Start("SyncInventory")
                    net.WriteTable(inventory)
                    net.SendToServer()
                end
            end
        end
    end

    hook.Add("Think", "OpenInventoryKey", function()
        if input.IsKeyDown(KEY_I) and not inventoryOpen then
            OpenInventory()
        end
    end)
end