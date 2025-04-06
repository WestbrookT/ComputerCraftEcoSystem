os.loadAPI("inventory.lua")

local pretty = require "cc.pretty"

function pt(obj)
  pretty.pretty_print(obj)
--   rep = pretty.pretty(obj)
--   textutils.pagedTabulate(rep)
end

--[[

Chests:
    return chest: This returns items to the inventory system.
    output chest: This sends the items to the player, typically a ender chest.
    input chest: This is where the head librarian receives items from librarians.

]]



DISPATCH_REQUEST_PROTOCOL = "LIBRARIAN_DISPATCH_REQUEST" -- From librarian -> head_librarian
DISPATCH_RESPONSE_PROTOCOL = "LIBRARIAN_DISPATCH_RESPONSE" -- From head_librarian -> all_librarians

INVENTORY_REQUEST_PROTOCOL = "INVENTORY_REQUEST"
INVENTORY_RESPONSE_PROTOCOL = "INVENTORY_RESPONSE"

DISPATCHER_HOSTNAME = "TOP_LIBRARIAN"

CHECK_RATE = 2

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function _initialize_dispatcher(dispatcher)
    local modem = peripheral.find("modem")
    dispatcher._modem_name = peripheral.getName(modem)
    dispatcher._modem = modem
    rednet.open(dispatcher._modem_name)
    rednet.host(DISPATCH_REQUEST_PROTOCOL, DISPATCHER_HOSTNAME)
    rednet.host(INVENTORY_REQUEST_PROTOCOL, DISPATCHER_HOSTNAME)
end

function consolidate_requests(requests)
    --[[
        requests: A map of request ids to the list of selector requests.
            Example: {
                1 = {
                    requester_id = some_number,
                    selectors = {["$:minecraft:sandstone"] = 64}
                }
            }

        It takes this list of selector requests and consolidates it into a single entity that librarians
        can look for.
    ]]

    local consolidated_selectors = {}

    if requests == nil then
        return nil
    end

    print("requests", textutils.serialise(requests))
    for request_id, request_data in pairs(requests) do
        for selector, newly_requested in pairs(request_data.selectors) do
            local current_requested = consolidated_selectors[selector]
            -- print("current_requested", selector, textutils.serialise(current_requested), textutils.serialise(newly_requested))
            if current_requested ~= nil then
                consolidated_selectors[selector] = current_requested + newly_requested
            else
                consolidated_selectors[selector] = newly_requested
            end
        end
    end
    print("fresh_selectors", textutils.serialise(consolidated_selectors))
    return consolidated_selectors
end

function _librarian_dispatch(dispatcher)
    while true do
        local librarian_id, message = rednet.receive(DISPATCH_REQUEST_PROTOCOL)
        local consolidated_requests = consolidate_requests(dispatcher._requests)
        print("librarian #", librarian_id, "requesting order. Order:", textutils.serialize(consolidated_requests))
        rednet.send(librarian_id, consolidated_requests, DISPATCH_RESPONSE_PROTOCOL)
    end
end

function _receive_request(dispatcher)
    while true do
        local requester_id, message = rednet.receive(INVENTORY_REQUEST_PROTOCOL)

        print("received", requester_id, textutils.serialise(message))

        dispatcher._requests[dispatcher._current_request_id] = {
            ["requester_id"] = requester_id,
            ["selectors"] = message
        }

        dispatcher._current_request_id = dispatcher._current_request_id + 1
    end
end

function _send_completion_message(dispatcher, request_data)
    return
end

function update_request_log(dispatcher, selector, count)

    for request_id, request_data in spairs(dispatcher._requests) do
        local request_finished = true
        for request_selector in pairs(request_data.selectors) do
            if selector == request_selector then
                local request_amount_fufilled = math.min(request_data.selectors[selector], count)
                request_data.selectors[selector] = request_data.selectors[selector] - request_amount_fufilled
                count = count - request_amount_fufilled
            end
            if request_data.selectors[selector] > 0 then
                request_finished = false
            end
            if count < 1 then
                break
            end
        end
        if request_finished then
            _send_completion_message(dispatcher, request_data)
            dispatcher._requests[request_id] = nil
        end
    end
end

function _transfer_items(dispatcher)
    while true do
        local consolidated_selectors = consolidate_requests(dispatcher._requests)
        for slot, slot_data in pairs(dispatcher.input_chest.list())  do
            local slot_used = false
            for selector, count in pairs(consolidated_selectors) do 
                if inventory.slot_match(dispatcher.input_chest, slot, selector) then
                    local limit = math.min(count, slot_data.count)
                    dispatcher.input_chest.pushItems(dispatcher._output_chest_name, slot, limit)
                    update_request_log(dispatcher, selector, slot_data.count)
                end
            end
            if not slot_used then
                dispatcher.input_chest.pushItems(dispatcher._return_chest_name, slot)
            end
        end
        sleep(CHECK_RATE)
    end
end

function _run(dispatcher)
    while true do
        parallel.waitForAny(
            dispatcher.receive_request, 
            dispatcher.librarian_dispatch,
            dispatcher.transfer_items
        )
    end
end



function Dispatcher(return_chest_name, input_chest_name, output_chest_name)

    local dispatcher = {
        -- Attributes
        _modem = nil,
        _modem_name = nil,
        _current_request_id = 1,
        _requests = {},

        return_chest = peripheral.wrap(return_chest_name),
        _return_chest_name = return_chest_name,

        input_chest = peripheral.wrap(input_chest_name),
        _input_chest_name = _input_chest_name,

        output_chest = peripheral.wrap(output_chest_name),
        _output_chest_name = output_chest_name,

        -- Methods
        initialize_dispatcher = _initialize_dispatcher,
        librarian_setup = _librarian_setup,

        -- Parrallel actions
        librarian_dispatch_fn = _librarian_dispatch,
        receive_request_fn = _receive_request,
        transfer_items_fn = _transfer_items,

        run = _run,
    }

    dispatcher.librarian_dispatch = function () dispatcher:librarian_dispatch_fn() end
    dispatcher.receive_request = function () dispatcher:receive_request_fn() end
    dispatcher.transfer_items = function () dispatcher:transfer_items_fn() end


    dispatcher:initialize_dispatcher()

    return dispatcher
end

head_librarian = Dispatcher("bottom", "front", "top")
head_librarian:run()
