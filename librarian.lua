os.loadAPI("inventory.lua")
os.loadAPI("dispatcher.lua")

INVENTORY_SLOTS_START = 3
INVENTORY_SLOTS_END = 16

BUFFER_SLOT = 1
FUEL_SLOT = 2

LEFT = 3
RIGHT = 1
CHEST = 0

TURTLE_X_START = 0
TURTLE_Y_START = -1

TURTLE_ORIENTATION_START = 0


--[[

Set up configuration:

Turtle should be a mining turtle with the pickaxe on the right side. Wireless modem on the left.
Buffer chest goes into slot one.

Overall storage page configuration:

    Should be a wall of chests with a boundary in front on the perimeter.
    The turtle's "home" is at the bottom right of the wall of chests, lowered by one level.
    The turtle hides at floor level.

    The home should have 3 chests:

        To the right of the wall at floor level is the output chest.
        Under the wall at floor level is the fuel chest.
        Under the turtle is the return chest (which returns excess items to the inventory system).
]]



function _orientation_modulus(current_orientation, direction_change)
    return (current_orientation + direction_change) % 4
end

function _right_turn_distance(current_orientation, new_orientation)
    return (current_orientation + new_orientation) % 4
end

function _left_turn_distance(current_orientation, new_orientation)
    return (current_orientation - new_orientation) % 4
end

function _face_orientation(librarian, orientation)

    local right_faster = (
        _right_turn_distance(librarian._turtle_orientation, orientation) 
        <= 
        _left_turn_distance(librarian._turtle_orientation, orientation)
    )

    if right_faster then
        while librarian._turtle_orientation ~= orientation do
            librarian._turtle_orientation = _orientation_modulus(librarian._turtle_orientation, 1)
            turtle.turnRight()
        end
    else
        while librarian._turtle_orientation ~= orientation do
            librarian._turtle_orientation = _orientation_modulus(librarian._turtle_orientation, -1)
            turtle.turnLeft()
        end
    end
end

function _move_left(librarian)
    _face_orientation(librarian, LEFT)
    librarian._turtle_x = librarian._turtle_x + 1
    return turtle.forward()
end

function _move_right(librarian)
    _face_orientation(librarian, RIGHT)
    librarian._turtle_x = librarian._turtle_x - 1
    return turtle.forward()
end

function _move_up(librarian)
    librarian._turtle_y = librarian._turtle_y + 1
    return turtle.up()
end

function _move_down(librarian)
    librarian._turtle_y = librarian._turtle_y - 1
    return turtle.down()
end

function move_to(librarian, x, y)

    local vertical_fn = nil
    if librarian._turtle_y < y then
        vertical_fn = _move_up
    else
        vertical_fn = _move_down
    end

    local horizontal_fn = nil
    if librarian._turtle_x < y then
        horizontal_fn = _move_right
    else
        horizontal_fn = _move_left
    end

    while librarian._turtle_y ~= y do
        vertical_fn(librarian)
    end
    while librarian._turtle_x ~= x do
        horizontal_fn(librarian)
    end
end

function drop_off(selectors)
    -- selectors example: {"$:chest" = 5}
    -- Assumes the request dropoff chest is to the right of the turtle.
    -- Assumes the fuel chest is in front of the turtle.
    -- Assumes the re-sort chest is under the turtle.

    if selectors == nil then
        selectors = {}
    end

    local old_slot = turtle.getSelectedSlot()

    turtle.turnRight()

    -- Drop all items matching the selectors into the request dropoff chest.
    for selector, count in pairs(selectors) do
        local slot = inventory.find_slot(selector, INVENTORY_SLOTS_START, INVENTORY_SLOTS_END, turtle.getItemDetail)

        while slot > 0 do
            turtle.select(slot)
            turtle.drop()
            slot = inventory.find_slot(selector, INVENTORY_SLOTS_START, INVENTORY_SLOTS_END, turtle.getItemDetail)
        end
    end

    turtle.turnLeft()

    -- Drop any remaining items into the re-sort chest.
    for slots = INVENTORY_SLOTS_START, INVENTORY_SLOTS_END do
        turtle.dropDown()
    end

    turtle.select(old_slot)
end

function fuel_up()
    -- Assumes the fuel chest is in front of the turtle.

    local old_slot = turtle.getSelectedSlot()

    turtle.suck()

    turtle.refuel(turtle.getItemCount())

    drop_off()
    turtle.select(old_slot)
end

function _check_home(librarian)


end

function _return_home(librarian, selectors)

    local already_home = peripheral.isPresent("bottom")

    -- Go all the way to the bottom floor.
    while turtle.down() do
        if peripheral.isPresent("bottom") then
            print("already home")
            already_home = true
            break
        else
            already_home = false
        end
    end

    if not already_home then
        -- Turn until we find a chest.
        while not peripheral.isPresent("front") do
            turtle.turnRight()
        end

        -- Turn again to get us looking in the right direction.
        turtle.turnRight()

        -- Go forward until we find the hole that the turtle lives in.
        while turtle.detectDown() do
            turtle.forward()
        end

        turtle.down()
    end

    while not (peripheral.isPresent("right") and peripheral.isPresent("front")) do
        turtle.turnLeft()
    end

    librarian._turtle_x = TURTLE_X_START
    librarian._turtle_y = TURTLE_Y_START
    librarian._turtle_orientation = TURTLE_ORIENTATION_START

    drop_off(selectors)
end

function _initialize_page_size(librarian)
    fuel_up()

    local height = -1
    local width = 0

    repeat
        height = height + 1
    until not turtle.up()

    turtle.turnLeft()

    repeat
        width = width + 1
    until not turtle.forward()

    librarian.page_height = height
    librarian.page_width = width
    librarian:return_home()
    print("page height:", height, "page width:", width)
end

function _request_complete(selectors)
    local complete = true
    for selector, requested_amount in pairs(selectors) do
        print("selector", selector, "req", requested_amount)
        if requested_amount > 0 then
            complete = false
            break
        end
    end
    return complete
end

function _get_vertical_fn_and_limit(librarian)
    if librarian._turtle_x % 2 == 0 then
        return _move_up, librarian.page_height
    else
        return _move_down, 0
    end
end

function _search_chest(librarian, selectors)
    _face_orientation(librarian, CHEST)

    for selector, _ in pairs(selectors) do

        local count = selectors[selector]
        local selector_found = false
        
        if inventory.contains("front", selector) > 0 and count > 0 and not librarian._inventory_manager.opened then
            librarian._inventory_manager:open("front")
        end
        if librarian._inventory_manager.opened then
            print("selector:", selector, "count:", count)
            selectors[selector] = count - librarian._inventory_manager:extract(selector, count)
        end
    end
    if librarian._inventory_manager.opened then
        librarian._inventory_manager:close()
    end
end

function _find_items(librarian, selectors)
    -- selectors is a key value store with keys being the selector string, and the values being the counts requested.
    -- Returns true if all selectors orders were completed.

    if selectors == nil or _request_complete(selectors) then
        print("Got nil request.")
        return false
    end
    if _request_complete(selectors) then
        print("Got empty request.")
        return false
    end

    local vertical_fn = _get_vertical_fn_and_limit(librarian)
    local horizontal_fn = _move_left

    _move_up(librarian)

    while librarian._turtle_x < librarian.page_width do
        local vertical_fn, vertical_limit = _get_vertical_fn_and_limit(librarian)
        while librarian._turtle_y ~= vertical_limit do
            print("Searching chest...")
            _search_chest(librarian, selectors)
            print("Chest Searched...")
            if _request_complete(selectors) then
                librarian:return_home(selectors)
                return true
            end
            vertical_fn(librarian)
        end
        horizontal_fn(librarian)
    end
    librarian:return_home(selectors)
    return false
end




function Librarian()

    local librarian = {
        -- Attributes
        page_height = nil,
        page_width = nil,

        _turtle_y = TURTLE_Y_START,
        _turtle_x = TURTLE_X_START,
        _turtle_orientation = TURTLE_ORIENTATION_START,

        _inventory_manager = inventory.InventoryManager(INVENTORY_SLOTS_START),


        -- Methods
        find_items = _find_items,
        initialize_page_size = _initialize_page_size,
        return_home = _return_home,
        watch = _watch
    }

    librarian:return_home()
    librarian:initialize_page_size()

    return librarian
end

function initialize_rednet()
    local modem = peripheral.find("modem")
    rednet.open(peripheral.getName(modem))
    local head_librarian_id = rednet.lookup(dispatcher.DISPATCH_REQUEST_PROTOCOL, dispatcher.DISPATCHER_HOSTNAME) 
    print("head_librarian_id", head_librarian_id)
    return head_librarian_id
end

function get_orders(head_librarian_id)
    rednet.send(head_librarian_id, nil, dispatcher.DISPATCH_REQUEST_PROTOCOL)
    print("waiting...")
    local _, selectors = rednet.receive(dispatcher.DISPATCH_RESPONSE_PROTOCOL, 5) 
    print("Received order: ", textutils.serialise(selectors))
    return selectors
end

function main()
    local librarian = Librarian()
    local head_librarian_id = initialize_rednet()
    while true do
    librarian:find_items(get_orders(head_librarian_id))
    -- orders = {}
    -- orders["$:minecraft:cobblestone"] = 1
    -- librarian:find_items(orders)
        -- sleep(2)
    end
end

main()