if CLIENT then
    local inventory = {}
    local inventoryOpen = false

    net.Receive("AddToInventory", function()
        local itemClass = net.ReadString()
        local itemModel = net.ReadString()
        local itemWeight = net.ReadFloat()  -- Вес предмета
        table.insert(inventory, {class = itemClass, model = itemModel, weight = itemWeight})
    end)

    local function RemoveItemFromInventory(index)
        local function printInventory(msg)
            print(msg)
            for i, v in ipairs(inventory) do
                print(i, v.class, v.model, v.weight)
            end
        end

        printInventory("Before shift:")

        table.remove(inventory, index)

        printInventory("After shift:")
    end

    local function UpdateInventoryUI(grid)
        for _, slot in ipairs(grid:GetItems()) do
            slot:Clear()
        end

        for index, item in ipairs(inventory) do
            local slot = grid:GetItems()[index]
            if slot then
                slot:SetText("")

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

                    RemoveItemFromInventory(index)

                    UpdateInventoryUI(grid)

                    net.Start("SyncInventory")
                    net.WriteTable(inventory)
                    net.SendToServer()
                end
            end
        end
    end

    local function OpenInventory()
        if inventoryOpen then return end
        inventoryOpen = true

        local frame = vgui.Create("DFrame")
        frame:SetTitle("Инвентарь")
        frame:SetSize(500, 500)
        frame:Center()
        frame:MakePopup()

        frame.OnClose = function()
            inventoryOpen = false
        end

        local grid = vgui.Create("DGrid", frame)
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

        UpdateInventoryUI(grid)
    end

    hook.Add("Think", "OpenInventoryKey", function()
        if input.IsKeyDown(KEY_I) and not inventoryOpen then
            OpenInventory()
        end
    end)
end
