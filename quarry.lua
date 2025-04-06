--[[
A quarry program by swiftsIayer

Features:
Exact hole size
Auto-Fueling
Auto-Item-Dropoff
Mines 3 blocks at once
3 times more efficient movement
Displays blocks mined
Displays fuel used
Mob proof
Gravel proof

The fuel chest goes in slot 1
The dropoff chest goes in slot 2
This version should work with any size of hole
]]

print("Length?")
l = tonumber(io.read())
print("Width?")
w = tonumber(io.read())
print("Height?")
h = tonumber(io.read())
x = 1
g = 1
f = l
d = w - 1
t = math.floor(h/2)
n = 0
p = 0

function move()
	if turtle.forward() == true then
		p = p + 1
	elseif turtle.forward() == false then
		for i = 1, 30 do
			turtle.attack()
		end
		turtle.forward()
		block()
		turtle.forward()
		p = p + 1
	end
end

function move1()
	if turtle.up() == true then
		p = p + 1
	end
end

function move2()
	if turtle.down() == true then
		p = p + 1
	end
end

function block()
	if turtle.dig() == true then
		n = n + 1
		turtle.dig()
	end
	if turtle.digUp() == true then
		n = n + 1
		turtle.digUp()
	end
	if turtle.digDown() == true then
		n = n + 1
		turtle.digDown()
	end
end

function block1()
	if turtle.digUp() == true then
		n = n + 1
		turtle.digUp()
	end
	if turtle.digDown() == true then
		n = n + 1
		turtle.digDown()
	end
end

function chest()
	turtle.digUp()
	turtle.select(1)
	turtle.placeUp()
	turtle.suckUp()
	turtle.refuel(64)
	turtle.digUp()
end

function fuel()
	if turtle.getFuelLevel() < 100 then
		chest()
	end
end

function ender()
	if turtle.getItemCount(8) >= 1 then
		turtle.digUp()
		turtle.select(2)
		turtle.placeUp()
		for i = 3, 8 do
			turtle.select(i)
			turtle.dropUp()
		end
			turtle.select(2)
			turtle.digUp()
	end
end

function start()
	if h%3 == 0 then
		turtle.dig()
		move()
		block()
		move2()
		block()
		move2()
		t = h/3
		r = h/3
	elseif h%3 == 1 then
		turtle.dig()
		move()
		t = math.ceil(h/3)
		r = math.ceil(h/3)
	elseif h%3 == 2 then
		turtle.dig()
		move()
		block()
		move2()
		block()
		t = math.ceil(h/3)
		r = math.ceil(h/3)
	end
end

function forward()
	block()
	block()
	fuel()
	ender()
	move()
	block1()
end

function length()
	for i = 2, l do
		forward()
	end
end

function turn()
	if g == 1 then
		turtle.turnRight()
		forward()
		turtle.turnRight()
		length()
		g = 0
	elseif g == 0 then
		turtle.turnLeft()
		forward()
		turtle.turnLeft()
		length()
		g = 1
	end
end

function width()
	block()
	length()
	for q = 1, d do
		turn()
	end
end

function height()
	if w%2 == 0 then
		turtle.turnRight()
		for i = 2, w do
			move()
		end
		turtle.turnRight()
		g = 1
	else
		turtle.turnLeft()
		for i = 2, w do
			move()
		end
		turtle.turnLeft()
		for i = 2, l do
			move()
		end
		turtle.turnRight()
		turtle.turnRight()
	end
	if t > 1 then
		move2()
		block()
		move2()
		block()
		move2()
		t = t - 1
	else
		for i = 1, h do
			move1()
		end
	end
end

function quarry()
	if h == 1 then
		width()
		height()
	else
		for i = 1, r do
		width()
		height()
		end
	end
end

start()
quarry()
term.clear()
print("Blocks mined: " .. n)
print("Fuel used: " .. p)