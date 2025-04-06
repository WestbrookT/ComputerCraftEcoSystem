--[[
Inventory

reserved_slots_max: Highest slot id of reserved slots.

transfer_placement: front/up/down

insert(item_name, max_count)

extract(item_name, max_count)

]]

CHEST_SLOT = 1
TURTLE_MAX_SLOT = 15


function _buffer_methods(manager)
    -- print("buffer_methods")

    local methods = {}

    if manager._buffer_name == "top" then
        methods.drop = turtle.dropUp
        methods.suck = turtle.suckUp
        methods.dig = turtle.digUp
        methods.place = turtle.placeUp
    elseif manager._buffer_name == "bottom" then
        methods.drop = turtle.dropDown
        methods.suck = turtle.suckDown
        methods.dig = turtle.digDown
        methods.place = turtle.placeDown
    elseif manager._buffer_name == "front" then
        methods.drop = turtle.drop
        methods.suck = turtle.suck
        methods.dig = turtle.dig
        methods.place = turtle.place
    else
        return nil
    end
    return methods
end


function _check_buffer(manager)
    -- print("check_buffer", manager, manager.buffer)
    local slot_detail = manager.buffer.getItemDetail(1)
    if slot_detail == nil then
        return 0
    end
    local count = slot_detail.count
    return count
end

function _place_buffer(manager)
    -- print("place_buffer")
    local old_slot = turtle.getSelectedSlot()
    turtle.select(CHEST_SLOT)
    if not turtle.detectUp() then
        turtle.placeUp()
        manager._buffer_name = "top"
    elseif not turtle.detectDown() then
        turtle.placeDown()
        manager._buffer_name = "bottom"
    elseif not turtle.detect() then
        turtle.place()
        manager._buffer_name = "front"
    end
    turtle.select(old_slot)
end

function _remove_buffer(manager)
    -- print("remove_buffer")
    local old_slot = turtle.getSelectedSlot()
    turtle.select(CHEST_SLOT)
    _buffer_methods(manager).dig()
    turtle.select(old_slot)
    manager._buffer_name = nil
end

function _turtle_to_buffer(manager, slot)
    -- print("turtle_to_buffer")
    local old_slot = turtle.getSelectedSlot()
    turtle.select(slot)
    _buffer_methods(manager).drop()

    turtle.select(old_slot)

    return manager.buffer.getItemDetail(1).count
end

function _turtle_item_capacity(item_detail, slot)
    -- print("turtle_item_capacity")

    local capacity = 0

    for slot = slot, TURTLE_MAX_SLOT do
        local slot_detail = turtle.getItemDetail(slot)

        if slot_detail == nil then
            capacity = capacity + item_detail.maxCount
        elseif slot_detail.name == item_detail.name then
            capacity = capacity + item_detail.maxCount - slot_detail.count
        end
    end
    return capacity
end

function _buffer_to_turtle(manager, slot)
    -- print("buffer_to_turtle")

    local old_slot = turtle.getSelectedSlot()

    turtle.select(slot)

    local item_detail = manager.buffer.getItemDetail(1)
    local items_in_buffer = 0

    -- print("item detail", -- print(textutils.serialize(item_detail)))

    if item_detail ~= nil then
        items_in_buffer = item_detail.count
        _buffer_methods(manager).suck(math.min(item_detail.count, _turtle_item_capacity(item_detail, slot)))
    end

    local item_detail_after = manager.buffer.getItemDetail(1)
    local items_in_buffer_after = 0

    if item_detail_after ~= nil then
        items_in_buffer_after = item_detail_after.count
    end

    turtle.select(old_slot)

    -- print("buffer_to_turtle_end")
    return items_in_buffer - items_in_buffer_after
end

function _buffer_to_inventory(manager, count)
    -- print("buffer_to_inventory")
    return manager.buffer.pushItems(manager._inventory_name, 1, count)
end

function find_slot(selector, min_slot, max_slot, item_detail_fn)
    -- print("find_slot")
    for slot = min_slot, max_slot do
        local info = item_detail_fn(slot)
        if match(selector, info) then
            return slot
        end
    end
    return -1
end

function _inventory_to_buffer(manager, selector, count)
    -- print("inventory_to_buffer")
    if count < 1 then
        return 0
    end
    
    local slot = find_slot(selector, 1, manager.inventory.size()-1, manager.inventory.getItemDetail)
    local transfered = manager.inventory.pushItems(manager._buffer_name, slot, count)

    return transfered
end

function _turtle_to_inventory(manager, selector, count)
    -- print("turtle_to_inventory")
    local slot = find_slot(selector, manager.inventory_slots_start, TURTLE_MAX_SLOT, turtle.getItemDetail)
    _turtle_to_buffer(manager, slot)
    local transfered = _buffer_to_inventory(manager, count)
    _buffer_to_turtle(manager, turtle.getSelectedSlot())
    return transfered
end

function _inventory_to_turtle(manager, selector, count)
    -- print("inventory_to_turtle")
    _inventory_to_buffer(manager, selector, count)
    local transfered = _buffer_to_turtle(manager, manager.inventory_slots_start)
    local items_in_buffer = _check_buffer(manager)
    if items_in_buffer > 0 then
        _buffer_to_inventory(manager, items_in_buffer)
    end
    return transfered
end



function _open(manager, name)
    -- print("open", manager, name)
    _place_buffer(manager)
    manager._inventory_name = name
    manager.buffer = peripheral.wrap(manager._buffer_name)
    manager.inventory = peripheral.wrap(manager._inventory_name)
    manager.opened = true
end

function _close(manager)
    -- print("close")
    _remove_buffer(manager)
    manager.buffer = nil
    manager.inventory = nil
    manager.opened = false
end

function name_selector(item_name)
    return "$:" .. item_name
end



function parse_selector(selection)
    local _, _, _hint = string.find(selection, "^([^:]+):")
    local _, _, _item_descriptor = string.find(selection, "^[^:]+:(.*)$")
    -- print("parse selector", _hint, _item_descriptor)
    return {
        hint = _hint, 
        item_descriptor = _item_descriptor
    }
end

function match(selection, item_data)
    -- print("match")
    local selector_data = parse_selector(selection)

    if item_data == nil then
        return false
    end

    if selector_data.hint == "@" then
        -- Display Name
        return selector_data.item_descriptor == item_data.displayName
    elseif selector_data.hint == "#" then
        -- Tags
        return item_data.tags[selector_data.item_descriptor] ~= nil
    elseif selector_data.hint == "$" then
        -- name
        return selector_data.item_descriptor == item_data.name
    else
        print("Got an unexpected value for selector hint.")
        return false
    end
end

function get_inventory(inventory)
    if type(inventory) == "string" then 
        inventory = peripheral.wrap(name)
    end
    return inventory
end

function slot_match(inventory, slot, selection)
    inventory = get_inventory(inventory)

    local item_data = inventory.getItemDetail(slot)
    return match(selection, item_data)
end

function _insert(manager, selector, max_amount)
    -- print("insert", manager, selector, max_amount)

    inserted_count = 0
    insert_successful = true

    local old_slot = turtle.getSelectedSlot()

    -- print("old_bane")
    local slot = find_slot(selector, manager.inventory_slots_start, TURTLE_MAX_SLOT, turtle.getItemDetail)
    local transfer_success = true

    local total_transfered = 0
    -- print("here")
    while slot > 0 and transfer_success do
        local transfered = _turtle_to_inventory(manager, selector, max_amount - total_transfered)
        total_transfered = total_transfered + transfered
        if total_transfered >= max_amount then
            break
        end
        transfer_success = transfered > 0
        slot = find_slot(selector, slot, TURTLE_MAX_SLOT, turtle.getItemDetail)
    end
    return total_transfered
end

function _extract(manager, selector, max_amount)
    -- print("extract", manager, selector, max_amount)

    extracted_count = 0
    extracted_successful = true

    local old_slot = turtle.getSelectedSlot()

    -- print("old_bane")
    local slot = find_slot(selector, 1, manager.inventory.size(), manager.inventory.getItemDetail)
    local transfer_success = true

    local total_transfered = 0
    -- print("here")
    while slot > 0 and transfer_success do
        local transfered = _inventory_to_turtle(manager, selector, max_amount - total_transfered)
        total_transfered = total_transfered + transfered
        if total_transfered >= max_amount then
            break
        end
        transfer_success = transfered > 0
        slot = find_slot(selector, 1, manager.inventory.size(), manager.inventory.getItemDetail)
    end
    return total_transfered
end

function contains(inventory, selector, start_slot)
    -- inventory can be either the string specifying the chest to search, or the wrapped connection.
    print("inventory", inventory, "selector", selector, "start_slot", start_slot)
    if start_slot == nil then
        start_slot = 1
    end
    if type(inventory) == "string" then 
        inventory_wrapped = peripheral.wrap(inventory)
    end
    return find_slot(selector, start_slot, inventory_wrapped.size(), inventory_wrapped.getItemDetail)
end


function InventoryManager(reserved_slots)
    turtle.select(reserved_slots + 1)
    return {
        -- Attributes
        inventory_slots_start = reserved_slots + 1,
        _buffer_name = nil,
        _inventory_name = nil,
        opened = false,


        -- Public Methods
        open = _open,
        close = _close,
        insert = _insert,
        extract = _extract,
        dump = _dump
    }
end

function main()
    local manager = InventoryManager(3)

    local inventory = manager:open("front")

    -- print(manager:extract("$:ars_nouveau:ab_mosaic", 65))
    manager:close()
end