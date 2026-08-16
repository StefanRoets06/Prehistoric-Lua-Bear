local game_functions = {}

math.randomseed(os.time())

local text = ""
local turn = 0
local is_paused = false
local is_game_over = false
local player_took_damage = false

local Heal_Cost = 500
local Heal_Target_Percent = 0.8

local function check_pause_toggle(key, terminal)
    if key == terminal.TK_ESCAPE then
        is_paused = not is_paused
    end
end

local function game_over()
    is_game_over = true
end

local function generate_terrain()
    for x = 1, 57 do
        Terrain_Grid[x] = {}
        for y = 1, 29 do
            local random_num = math.random()
            if random_num <= 0.01 then
                Terrain_Grid[x][y] = "t"
            elseif random_num <= 0.03 then
                Terrain_Grid[x][y] = "b"
            end
        end
    end
end

local function draw_terrain(terminal)
    terminal.layer(Terrain_Layer)
    terminal.color(Tree_Color)
    for x = 1, 57 do
        for y = 1, 29 do
            if Terrain_Grid[x][y] then
                terminal.print(x, y, Terrain_Grid[x][y])
            end
        end
    end
end

local function rebuild_mob_grid()
    Mob_Grid = {}
    for _, mob in ipairs(Live_Mobs) do
        Mob_Grid[mob.x] = Mob_Grid[mob.x] or {}
        Mob_Grid[mob.x][mob.y] = mob
    end
end

local function get_mob_at(x, y)
    return Mob_Grid[x] and Mob_Grid[x][y]
end

local function array_contains(array, target)
    for _, value in ipairs(array) do
        if value == target then
            return true
        end
    end
    return false
end

local function is_terrain_walkable(x, y, terminal)
    if x < 1 or x > 57 or y < 1 or y > 29 then
        return false
    end

    local invalid_terrain = {"t", "m"}
    terminal.layer(Terrain_Layer)
    local code = terminal.pick(x, y, 0)
    local char = code > 0 and string.char(code) or ""
    if array_contains(invalid_terrain, char) then
        return false
    end

    return true
end

local function is_position_valid(x, y, terminal)
    if not is_terrain_walkable(x, y, terminal) then
        return false
    end

    if get_mob_at(x, y) then
        return false
    end

    if x == Player_Position.x and y == Player_Position.y then
        return false
    end

    return true
end

local function pick_random_mob_type()
    local total_rarity = 0
    for _, def in pairs(Mob_Types) do
        total_rarity = total_rarity + def.rerity
    end
    local roll = math.random(total_rarity)
    local cumulative = 0
    for name, def in pairs(Mob_Types) do
        cumulative = cumulative + def.rerity
        if roll <= cumulative then
            return name
        end
    end
end

local function find_valid_spawn_near(x, y, radius, terminal)
    local candidates = {}
    for sx = math.max(1, x - radius), math.min(57, x + radius) do
        for sy = math.max(1, y - radius), math.min(29, y + radius) do
            if is_position_valid(sx, sy, terminal) then
                table.insert(candidates, {x = sx, y = sy})
            end
        end
    end
    if #candidates == 0 then
        return nil, nil
    end
    local pick = candidates[math.random(#candidates)]
    return pick.x, pick.y
end

local function spawn_specific_mob(type_name, terminal, x, y)
    local def = Mob_Types[type_name]
    if not def then
        return
    end

    local spawn_x, spawn_y

    if x and y then
        spawn_x, spawn_y = find_valid_spawn_near(x, y, 3, terminal)
    end

    if not spawn_x then
        local attempts = 0
        repeat
            spawn_x = math.random(1, 57)
            spawn_y = math.random(1, 29)
            attempts = attempts + 1
        until is_position_valid(spawn_x, spawn_y, terminal) or attempts > 100
        if attempts > 100 then
            return
        end
    end

    table.insert(Live_Mobs, {
        type = type_name,
        char = def.char,
        temperament = def.temperament,
        damage = def.damage,
        detection_range = def.detection_range,
        flee_range = def.flee_range,
        turns_since_meal = 0,
        meals_eaten = 0,
        x = spawn_x,
        y = spawn_y
    })

    rebuild_mob_grid()
end

local function spawn_mob(terminal)
    if #Live_Mobs >= Max_Mobs then
        return
    end

    local type_name = pick_random_mob_type()
    spawn_specific_mob(type_name, terminal)
end

local function chebyshev(x1, y1, x2, y2)
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

local function step_toward(fx, fy, tx, ty)
    local dx = 0
    local dy = 0
    if tx > fx then dx = 1
    elseif tx < fx then dx = -1 end
    if ty > fy then dy = 1
    elseif ty < fy then dy = -1 end
    if dx ~= 0 and dy ~= 0 then
        if math.random() < 0.5 then dy = 0 else dx = 0 end
    end
    return dx, dy
end

local function random_step()
    local dir = math.random(4)
    if dir == 1 then return 0, -1
    elseif dir == 2 then return 1, 0
    elseif dir == 3 then return 0, 1
    else return -1, 0 end
end

local function find_nearest_same_type(mob, range)
    local best, target
    for _, other in ipairs(Live_Mobs) do
        if other ~= mob and other.type == mob.type then
            local d = chebyshev(mob.x, mob.y, other.x, other.y)
            if d <= range and (not best or d < best) then
                best = d
                target = other
            end
        end
    end
    return target
end

local function find_nearest_bush(x, y, radius)
    local best, bx, by
    for sx = math.max(1, x - radius), math.min(57, x + radius) do
        for sy = math.max(1, y - radius), math.min(29, y + radius) do
            if Terrain_Grid[sx] and Terrain_Grid[sx][sy] == "b" then
                local d = chebyshev(x, y, sx, sy)
                if not best or d < best then
                    best = d
                    bx = sx
                    by = sy
                end
            end
        end
    end
    return bx, by
end

local function find_nearest_target(mob, range, temperament)
    local best, target
    for _, other in ipairs(Live_Mobs) do
        if other ~= mob and other.temperament == temperament then
            local d = chebyshev(mob.x, mob.y, other.x, other.y)
            if d <= range and (not best or d < best) then
                best = d
                target = other
            end
        end
    end
    return target
end

local function pick_random_aggressive_type()
    local aggressive_types = {}
    for name, def in pairs(Mob_Types) do
        if def.temperament == "Aggresive" then
            table.insert(aggressive_types, name)
        end
    end
    if #aggressive_types == 0 then
        return nil
    end
    return aggressive_types[math.random(#aggressive_types)]
end

local function mob_movement(terminal)
    local to_remove = {}
    local to_breed = {}

    for _, mob in ipairs(Live_Mobs) do
        local dx = 0
        local dy = 0
        local move_chance = 1
        local ate_this_turn = false

        if mob.temperament == "Aggresive" then
            move_chance = Aggresive_Move_Chance
            local detection_range = mob.detection_range or 0

            local nearest_prey = detection_range > 0 and find_nearest_target(mob, detection_range, "Passive") or nil
            local prey_dist = nearest_prey and chebyshev(mob.x, mob.y, nearest_prey.x, nearest_prey.y) or math.huge
            local player_dist = chebyshev(mob.x, mob.y, Player_Position.x, Player_Position.y)

            local closest_target = nil
            local target_dist = math.huge

            if player_dist <= detection_range and player_dist <= prey_dist then
                closest_target = "player"
                target_dist = player_dist
            elseif nearest_prey and prey_dist <= detection_range then
                closest_target = "prey"
                target_dist = prey_dist
            end

            if closest_target == "player" then
                if target_dist <= 1 then
                    Health = math.max(0, Health - mob.damage)
                    player_took_damage = true
                    ate_this_turn = false
                else
                    dx, dy = step_toward(mob.x, mob.y, Player_Position.x, Player_Position.y)
                end
            elseif closest_target == "prey" and nearest_prey then
                if target_dist <= 1 then
                    table.insert(to_remove, nearest_prey)
                    ate_this_turn = true
                else
                    dx, dy = step_toward(mob.x, mob.y, nearest_prey.x, nearest_prey.y)
                end
            else
                dx, dy = random_step()
            end

            if ate_this_turn then
                mob.turns_since_meal = 0
                mob.meals_eaten = (mob.meals_eaten or 0) + 1
                if mob.meals_eaten >= Breed_Meals_Required then
                    mob.meals_eaten = 0
                    table.insert(to_breed, {type = mob.type, x = mob.x, y = mob.y})
                end
            else
                mob.turns_since_meal = mob.turns_since_meal + 1
                if mob.turns_since_meal >= Starve_Turns then
                    table.insert(to_remove, mob)
                end
            end

        elseif mob.temperament == "Passive" then
            move_chance = Passive_Move_Chance
            local flee_range = mob.flee_range or 0
            local detection_range = mob.detection_range or 0

            if flee_range > 0 and chebyshev(mob.x, mob.y, Player_Position.x, Player_Position.y) <= flee_range then
                local tx, ty = step_toward(mob.x, mob.y, Player_Position.x, Player_Position.y)
                dx, dy = -tx, -ty
            else
                local herd_target = detection_range > 0 and find_nearest_same_type(mob, detection_range) or nil
                if herd_target then
                    dx, dy = step_toward(mob.x, mob.y, herd_target.x, herd_target.y)
                else
                    local bx, by = find_nearest_bush(mob.x, mob.y, detection_range)
                    if bx and math.random() < 0.7 then
                        dx, dy = step_toward(mob.x, mob.y, bx, by)
                    else
                        dx, dy = random_step()
                    end
                end
            end

        else
            move_chance = Passive_Move_Chance
            if chebyshev(mob.x, mob.y, Player_Position.x, Player_Position.y) <= 1 then
                Health = math.max(0, Health - mob.damage)
                player_took_damage = true
            else
                dx, dy = random_step()
            end
        end

        if (dx ~= 0 or dy ~= 0) and math.random() <= move_chance then
            local new_x = mob.x + dx
            local new_y = mob.y + dy
            if is_position_valid(new_x, new_y, terminal) then
                mob.x = new_x
                mob.y = new_y
                rebuild_mob_grid()
            end
        end
    end

    if #to_remove > 0 then
        for _, dead in ipairs(to_remove) do
            for i = #Live_Mobs, 1, -1 do
                if Live_Mobs[i] == dead then
                    table.remove(Live_Mobs, i)
                    break
                end
            end
        end
        rebuild_mob_grid()
    end

    for _, breed in ipairs(to_breed) do
        spawn_specific_mob(breed.type, terminal, breed.x, breed.y)
    end

    local aggressive_count = 0
    for _, mob in ipairs(Live_Mobs) do
        if mob.temperament == "Aggresive" then
            aggressive_count = aggressive_count + 1
        end
    end
    if aggressive_count == 0 then
        local type_name = pick_random_aggressive_type()
        if type_name then
            spawn_specific_mob(type_name, terminal)
        end
    end

    if Health < 100 and math.random() <= Health_Regen_Chance then
        Health = math.min(100, Health + Health_Regen_Amount)
    end

    if Health <= 0 then
        game_over()
    end
end

local function draw_mobs(terminal)
    terminal.layer(Mob_Layer)
    for _, mob in ipairs(Live_Mobs) do
        terminal.color(Temperament_Colors[mob.temperament] or "white")
        terminal.print(mob.x, mob.y, mob.char)
    end
    terminal.color()
end

local function draw_ui(terminal)
    terminal.layer(Ui_Layer)
    terminal.color("grey")

    terminal.print(0, 0, TL_Corner_Wall)
    terminal.print(0, Screen_Size[2] - 1, BL_Corner_Wall)
    terminal.print(Screen_Size[1] - 1, 0, TR_Corner_Wall)
    terminal.print(Screen_Size[1] - 1, Screen_Size[2] - 1, BR_Corner_Wall)
    for i = 1, Screen_Size[1] - 2 do
        terminal.print(i, 0, Horizontal_Wall)
        terminal.print(i, Screen_Size[2] - 1, Horizontal_Wall)
    end
    for i = 1, Screen_Size[2] - 2 do
        terminal.print(0, i, Vertical_Wall)
        terminal.print(Screen_Size[1] - 1, i, Vertical_Wall)
    end
    terminal.print(2, 0, "World")

    terminal.print(0, Screen_Size[2] - 5, L_T_Wall)
    for i = 1, Screen_Size[1] - 22 do
        terminal.print(i, Screen_Size[2] - 5, Horizontal_Wall)
    end

    terminal.print(2, Screen_Size[2] - 5, "Hover Context")

    terminal.set("input.filter={keyboard, mouse}")
    local mx = terminal.state(terminal.TK_MOUSE_X)
    local my = terminal.state(terminal.TK_MOUSE_Y)

    terminal.layer(Terrain_Layer)
    local terrain_char_code = terminal.pick(mx, my, 0)
    local terrain_char_str = terrain_char_code > 0 and string.char(terrain_char_code) or ""
    local terrain_description = Tile_Descriptors[terrain_char_str] or "Nothing"
    terminal.layer(Ui_Layer)
    terminal.print(1, Screen_Size[2] - 3, "Terrain: " .. terrain_description)

    terminal.layer(Mob_Layer)
    local mob_char_code = terminal.pick(mx, my, 0)
    local mob_char_str = mob_char_code > 0 and utf8.char(mob_char_code) or ""
    local mob_description = Tile_Descriptors[mob_char_str] or "Nothing"
    local mob_color = terminal.pick_color(mx, my, 0)
    local mob_temperament = ""
    if mob_color and Temperaments[mob_color] then
        mob_temperament = "(" .. Temperaments[mob_color] .. ")"
    end
    terminal.layer(Ui_Layer)
    local mob_text = "Mob: " .. mob_description
    local mob_text_length = #mob_text
    terminal.print(1, Screen_Size[2] - 4, mob_text)
    terminal.color(mob_color)
    terminal.print(1 + mob_text_length, Screen_Size[2] - 4, mob_temperament)

    terminal.layer(Ui_Layer)
    terminal.color("grey")
    for i = 1, Screen_Size[2] - 2 do
        terminal.print(Screen_Size[1] - 22, i, Vertical_Wall)
    end
    terminal.print(Screen_Size[1] - 22, Screen_Size[2] - 5, R_T_Wall)
    terminal.print(Screen_Size[1] - 22, Screen_Size[2] - 1, B_T_Wall)
    terminal.print(Screen_Size[1] - 22, 0, T_T_Wall)

    terminal.print(Screen_Size[1] - 20, 0, "Controls")
    terminal.print(Screen_Size[1] - 21, 1, "Esc - Pause")
    terminal.print(Screen_Size[1] - 21, 2, "↑/W - Move Up")
    terminal.print(Screen_Size[1] - 21, 3, "→/D - Move Right")
    terminal.print(Screen_Size[1] - 21, 4, "↓/S - Move Down")
    terminal.print(Screen_Size[1] - 21, 5, "←/A - Move Left")
    terminal.print(Screen_Size[1] - 21, 6, "Space - Heal " .. Heal_Cost .. "pts")

    for i = 1, 5 do
        terminal.print(30, Screen_Size[2] - i, Vertical_Wall)
    end
    terminal.print(30, Screen_Size[2] - 1, B_T_Wall)
    terminal.print(30, Screen_Size[2] - 5, T_T_Wall)
    terminal.print(32, Screen_Size[2] - 5, "Stats")
    if player_took_damage then
        terminal.color("crimson")
    else
        terminal.color("grey")
    end
    terminal.print(31, Screen_Size[2] - 4, "Health: " .. Health)
    terminal.color("grey")
    terminal.print(31, Screen_Size[2] - 3, "Score: " .. Score)

    for i = 1, 22 do
        terminal.print(Screen_Size[1] - i, Screen_Size[2] / 3, Horizontal_Wall)
    end
    terminal.print(Screen_Size[1] - 1, Screen_Size[2] / 3, R_T_Wall)
    terminal.print(Screen_Size[1] - 22, Screen_Size[2] / 3, L_T_Wall)
    terminal.print(Screen_Size[1] - 20, Screen_Size[2] / 3, "Harvests")

    local index = 0
    for key, value in pairs(Harvests) do
        index = index + 1
        terminal.print(Screen_Size[1] - 21, Screen_Size[2] / 3 + index, tostring(value) .. " x " .. tostring(key))
    end

    terminal.color()
end

local function draw_player(terminal)
    terminal.layer(Mob_Layer)
    terminal.color("cyan")
    terminal.print(Player_Position.x, Player_Position.y, Player_Icon)
    terminal.color()
end

local Harvest_Points = {
    ["Passive"] = 25,
    ["Neutral"] = 100,
    ["Aggresive"] = 250,
}

local Aggresive_Harvest_Chance = 0.5

local function harvest_mob(mob, terminal)
    local harvested = true

    if mob.temperament == "Aggresive" then
        harvested = math.random() <= Aggresive_Harvest_Chance
    end

    if harvested then
        for i = #Live_Mobs, 1, -1 do
            if Live_Mobs[i] == mob then
                table.remove(Live_Mobs, i)
                break
            end
        end
        rebuild_mob_grid()

        local item_name = Tile_Descriptors[mob.char] or mob.type
        Harvests[item_name] = (Harvests[item_name] or 0) + 1

        Score = Score + (Harvest_Points[mob.temperament] or 0)
        
        Max_Mobs = Max_Mobs + 1
    end

    if mob.temperament ~= "Passive" then
        Health = math.max(0, Health - mob.damage)
        player_took_damage = true

        if Health <= 0 then
            game_over()
        end
    end
end

local function try_player_move(dx, dy, terminal)
    local new_x = Player_Position.x + dx
    local new_y = Player_Position.y + dy

    if not is_terrain_walkable(new_x, new_y, terminal) then
        return false
    end

    local mob = get_mob_at(new_x, new_y)
    if mob then
        harvest_mob(mob, terminal)
        return true
    end

    Player_Position.x = new_x
    Player_Position.y = new_y
    return true
end

local function try_player_heal()
    local target_health = math.floor(100 * Heal_Target_Percent)

    if Score < Heal_Cost then
        return false
    end

    if Health >= target_health then
        return false
    end

    Score = Score - Heal_Cost
    Health = target_health
    return true
end

local function player_movement(terminal, key)
    local turn_taken = false

    if key == terminal.TK_SPACE then
        player_took_damage = false
        turn_taken = try_player_heal()
    else
        local dx, dy = 0, 0

        if key == terminal.TK_W or key == terminal.TK_UP then
            dy = -1
        elseif key == terminal.TK_D or key == terminal.TK_RIGHT then
            dx = 1
        elseif key == terminal.TK_S or key == terminal.TK_DOWN then
            dy = 1
        elseif key == terminal.TK_A or key == terminal.TK_LEFT then
            dx = -1
        end

        if dx == 0 and dy == 0 then
            return
        end

        player_took_damage = false
        turn_taken = try_player_move(dx, dy, terminal)
    end

    if turn_taken then
        rebuild_mob_grid()
        mob_movement(terminal)

        if #Live_Mobs < Max_Mobs and math.random() <= Mob_Spawn_Chance then
            spawn_mob(terminal)
        end
    end
end

function game_functions.restart(terminal)
    Health = 100
    Stamina = 100
    Score = 0
    Max_Mobs = 10

    Player_Position.x = 10
    Player_Position.y = 10

    Live_Mobs = {}
    Mob_Grid = {}
    Harvests = {}

    Terrain_Grid = {}
    generate_terrain()
    Terrain_Grid[10][10] = nil

    is_paused = false
    is_game_over = false
    player_took_damage = false
end

function game_functions.start(terminal)
    generate_terrain()
    Terrain_Grid[10][10] = nil
end

function game_functions.loop(terminal, key)
    if key then
        check_pause_toggle(key, terminal)
    end

    terminal.clear()

    if is_paused then
        terminal.color("crimson")
        terminal.print(2, Screen_Size[2] / 4, 80, 1, terminal.TK_ALIGN_CENTER, "= Paused =")

        terminal.color("sky")
        terminal.print(2, Screen_Size[2] / 4 + 1, 80, 1, terminal.TK_ALIGN_CENTER, "1. Resume")
        terminal.print(2, Screen_Size[2] / 4 + 2, 80, 1, terminal.TK_ALIGN_CENTER, "2. Restart")
        terminal.print(2, Screen_Size[2] / 4 + 3, 80, 1, terminal.TK_ALIGN_CENTER, "3. Exit Game")
        terminal.color()

        if key == terminal.TK_1 or key == terminal.TK_KP_1 then
            is_paused = false
        end

        if key == terminal.TK_2 or key == terminal.TK_KP_2 then
            game_functions.restart(terminal)
        end

        if key == terminal.TK_3 or key == terminal.TK_KP_3 then
            Close_Game()
        end
        return
    end

    if is_game_over then
        terminal.clear()
        terminal.color("crimson")
        terminal.print(2, Screen_Size[2] / 4, 80, 1, terminal.TK_ALIGN_CENTER, "= Game Over =")
        terminal.color("green")
        terminal.print(2, Screen_Size[2] / 4 + 1, 80, 1, terminal.TK_ALIGN_CENTER, "Score: " .. Score)

        terminal.color("sky")
        terminal.print(2, Screen_Size[2] / 4 + 3, 80, 1, terminal.TK_ALIGN_CENTER, "1. Restart")
        terminal.print(2, Screen_Size[2] / 4 + 4, 80, 1, terminal.TK_ALIGN_CENTER, "2. Exit Game")
        terminal.color()

        if key == terminal.TK_1 or key == terminal.TK_KP_1 then
            is_game_over = false
            game_functions.restart(terminal)
        end

        if key == terminal.TK_2 or key == terminal.TK_KP_2 then
            Close_Game()
        end
        return
    end

    draw_terrain(terminal)
    rebuild_mob_grid()
    player_movement(terminal, key)
    rebuild_mob_grid()
    draw_mobs(terminal)
    draw_player(terminal)
    draw_ui(terminal)
end

return game_functions