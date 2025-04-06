os.loadAPI("ComputerCraftEcoSystem/head_librarian.lua")

local pretty = require "cc.pretty"

p = pretty.pretty_print

modem = peripheral.find("modem")

p(modem)

rednet.open("back")

request = {}

selectors = {}
selectors["$:minecraft:cobblestone"] = 15

p(selectors)

request.selectors = selectors

rednet.broadcast(selectors, head_librarian.DISPATCH_REQUEST_PROTOCOL)
