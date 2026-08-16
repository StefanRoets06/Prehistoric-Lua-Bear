package.cpath = ".\\?.dll;.\\loadall.dll;"
package.path  = ".\\?.lua;.\\?\\init.lua;"

local terminal = require 'BearLibTerminal'
local game_functions = require 'game'

Screen_Size = {82, 35}
Version = "0.1.0"

Ui_Layer = 200
Terrain_Layer = 10
Mob_Layer = 100

Horizontal_Wall = "═"
Vertical_Wall = "║"
TL_Corner_Wall = "╔"
TR_Corner_Wall = "╗"
BL_Corner_Wall = "╚"
BR_Corner_Wall = "╝"
T_T_Wall = "╦"
B_T_Wall = "╩"
L_T_Wall = "╠"
R_T_Wall = "╣"
X_Wall = "╬"

Player_Icon = "☺"

Health = 100
Stamina = 100
Score = 0

Player_Position = {
    ["x"] = 10,
    ["y"] = 10
}

Terrain_Grid = {}

Harvests = {}

Tile_Descriptors = {
    ["t"] = "Tree",
    ["m"] = "Mountain",
    ["b"] = "Bush",
    ["T"] = "T-Rex",
    ["☺"] = "Player",
    ["B"] = "Lunar Bear",
    ["3"] = "Triceratops",
    ["D"] = "Diplodocus",
    ["P"] = "Parasaurolophus",
    ["V"] = "Velociraptor",
    ["A"] = "Ankylosaurus",
}

Temperament_Colors = {
    ["Aggresive"] = "red",
    ["Neutral"] = "yellow",
    ["Passive"] = "sea"
}

Max_Mobs = 10

Live_Mobs = {}

Mob_Grid = {}

Mob_Types = {
    lunar_bear = {
        char = "B",
        temperament = "Aggresive",
        damage = 15,
        rerity = 1,
        detection_range = 6,
    },
    t_rex = {
        char = "T",
        temperament = "Aggresive",
        damage = 35,
        rerity = 10,
        detection_range = 10,
    },
    triceratops = {
        char = "3",
        temperament = "Neutral",
        damage = 20,
        rerity = 19,
        detection_range = 0,
    },
    diplodocus = {
        char = "D",
        temperament = "Passive",
        damage = 0,
        rerity = 40,
        flee_range = 4,
        detection_range = 6,
    },
    parasaurolophus = {
        char = "P",
        temperament = "Passive",
        damage = 0,
        rerity = 40,
        flee_range = 3,
        detection_range = 6,
    },
    velociraptor = {
        char = "V",
        temperament = "Aggresive",
        damage = 25,
        rerity = 15,
        detection_range = 10,
    },
    ankylosaurus = {
        char = "A",
        temperament = "Neutral",
        damage = 20,
        rerity = 10,
        detection_range = 0,
    },
}

Mob_Spawn_Chance = 0.4
Starve_Turns = 25
Aggresive_Move_Chance = 0.9
Passive_Move_Chance = 0.65
Health_Regen_Amount = 8
Health_Regen_Chance = 0.5
Breed_Meals_Required = 2

function Close_Game()
    terminal.close()
end

function Clear_Input_Buffer()
    while terminal.has_input() do
        terminal.read()
    end
end

terminal.open()

Temperaments = {
    [terminal.color_from_name("red")] = "Aggresive",
    [terminal.color_from_name("yellow")] = "Neutral",
    [terminal.color_from_name("sea")]  = "Passive"
}

Tree_Color = terminal.color_from_argb(100, 0, 255, 0)

--terminal.set("window.resizeable=true")
terminal.refresh()
terminal.print(2, 2, "size_set_return_code: " .. tostring(terminal.set("window.size='" .. Screen_Size[1] .. "x" .. Screen_Size[2] .. "'")))
terminal.delay(250)
terminal.refresh()
terminal.print(2, 3, "title_set_return_code: " .. tostring(terminal.set("window.title='Prehistoric Moon Bears'")))
terminal.delay(250)
terminal.refresh()
terminal.print(2, 4, "icon_set_return_code: " .. tostring(terminal.set("window.icon='icon.ico'")))
terminal.delay(250)
terminal.refresh()
terminal.print(2, 5, "log_set_return_code: " .. tostring(terminal.set("log.level='error'")))
terminal.delay(250)
terminal.refresh()
terminal.color("green")
terminal.print(2, 7, "Loading a prehistoric artstyle")
terminal.delay(250)
terminal.refresh()

terminal.color("purple")
terminal.print(2, 1, "Version: " .. Version)
terminal.delay(250)
terminal.refresh()

terminal.color("sea")
terminal.print(2, 9, "Configuring Done!")
terminal.color("amber")
terminal.print(2, 11, "Did You Know: You can mod this game by editing the lua files")
terminal.color()
terminal.delay(250)
terminal.refresh()

terminal.delay(250)
Clear_Input_Buffer()
terminal.color("sky")
terminal.print(2, Screen_Size[2] / 4 * 3, 80, 1, terminal.TK_ALIGN_CENTER, "+ Press Any Key +")
terminal.refresh()
terminal.color()

terminal.read()
terminal.clear()
terminal.refresh()
terminal.delay(500)
terminal.color("crimson")
terminal.print(2, Screen_Size[2] / 4, 80, 1, terminal.TK_ALIGN_CENTER, "= Prehistoric Moon Bears =")
terminal.refresh()
terminal.delay(1500)
terminal.color("sky")
Clear_Input_Buffer()
terminal.print(2, Screen_Size[2] / 4 * 3, 80, 1, terminal.TK_ALIGN_CENTER, "+ Press Any Key +")
terminal.color()
terminal.refresh()

terminal.read()
terminal.clear()
terminal.refresh()

local running = true

game_functions.start(terminal)

while running do
    local key = nil
    
    if terminal.has_input() then
        key = terminal.read()
        if key == terminal.TK_CLOSE then
            running = false
        end
    end

    game_functions.loop(terminal, key)
    terminal.refresh()
end

Close_Game()