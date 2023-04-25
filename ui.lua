local anti_aim, vector = require("gamesense/antiaim_funcs"), require("vector")

local menu = {
    keybinds = ui.new_checkbox("lua", "b", "enable keybinds list"),
    information = ui.new_checkbox("lua", "b", "enable information list"),
    label = ui.new_label("lua", "b", "indicator accent"),
    color = ui.new_color_picker("lua", "b", "a", 222, 160, 235, 255),
    animation = ui.new_slider("lua", "b", "animation speed", 1, 20, 6)
}

local references = {
    doubletap = { ui.reference("rage", "aimbot", "double tap") },
    hideshots = { ui.reference("aa", "other", "on shot anti-aim") },

    damage_override = { ui.reference("rage", "aimbot", "minimum damage override") },
    safe_point = { ui.reference("rage", "aimbot", "force safe point") },
    body_aim = { ui.reference("rage", "aimbot", "force body aim") },

    auto_peek = { ui.reference("rage", "other", "quick peek assist") },
    duck_peek = { ui.reference("rage", "other", "duck peek assist") },

    freestand = { ui.reference("aa", "anti-aimbot angles", "freestanding") },
    slow_walk = { ui.reference("aa", "other", "slow motion") }
}

local storage = {
    timer,
    fortcalc,
    timer_max,
    c4_time_frozen,

    information = {
        defensive_shift = 0,
        prev_sim_time = 0,
        defensive_dur = 0
    }
}

local k_a = { }
for i = 1, #references do
    k_a[i] = 0
end

local t_a = { }
for i = 1, #references do
    t_a[i] = 0
end

local window = {
    keybinds = {
        x = database.read("keybinds_x") or 10,
        y = database.read("keybinds_y") or 600,

        w = 170,
        h = 50
    },

    round = {
        x = database.read("round_x") or 10,
        y = database.read("round_y") or 900,

        w = 170,
        h = 50
    },

    dragging = false
}

local visuals = { }
function visuals.outline(x, y, w, h, r, g, b, a, radius, thickness)
    y = y + radius
    local data_circle = {
        {x + radius, y, 180},
        {x + w - radius, y, 270},
        {x + radius, y + h - radius * 2, 90},
        {x + w - radius, y + h - radius * 2, 0},
    }

    local data = {
        {x + radius, y - radius, w - radius * 2, thickness},
        {x + radius, y + h - radius - thickness, w - radius * 2, thickness},
        {x, y, thickness, h - radius * 2},
        {x + w - thickness, y, thickness, h - radius * 2},
    }

    for _, data in next, data_circle do
        renderer.circle_outline(data[1], data[2], r, g, b, a, radius, data[3], 0.25, thickness)
    end


    for _, data in next, data do
        renderer.rectangle(data[1], data[2], data[3], data[4], r, g, b, a)
    end
end

function visuals.rounded_rectangle(x, y, w, h, r, g, b, a, radius)
    y = y + radius
    local data_circle = {
        {x + radius, y, 180},
        {x + w - radius, y, 90},
        {x + radius, y + h - radius * 2, 270},
        {x + w - radius, y + h - radius * 2, 0},
    }

    local data = {
        {x + radius, y, w - radius * 2, h - radius * 2},
        {x + radius, y - radius, w - radius * 2, radius},
        {x + radius, y + h - radius * 2, w - radius * 2, radius},
        {x, y, radius, h - radius * 2},
        {x + w - radius, y, radius, h - radius * 2},
    }

    for _, data in next, data_circle do
        renderer.circle(data[1], data[2], r, g, b, a, radius, data[3], 0.25)
    end

    for _, data in next, data do
        renderer.rectangle(data[1], data[2], data[3], data[4], r, g, b, a)
    end
end

function visuals.outlined_string(x, y, r, g, b, a, flags, max_width, ...)
    local offset = {
        { -1, 1, -1, 1},
        { 1, 1, -1, -1}
    }

    for i = 1, 4 do
        renderer.text(x + offset[1][i], y + offset[2][i], 0, 0, 0, 255, flags, max_width, ...)
    end

    renderer.text(x, y, r, g, b, 255, flags, max_width, ...)
end

function visuals.lerp(start, end_pos, time)
    return start + (end_pos - start) * time
end

function visuals.clamp(value, minimum, maximum)
	if minimum > maximum then
		return math.min(math.max(value, maximum), minimum)
	else
		return math.min(math.max(value, minimum), maximum)
	end
end

function visuals.insert_information_board(x, y, w, h, r, g, b, a, a2, t_1, t_2, l)
    local secondary = { ui.get(menu.color) }

    renderer.gradient(x + 1, y, 149, 17, r, g, b, 10 * a2, r, g, b, 0, true)
    renderer.rectangle(x + 1, y, 1, 17, r, g, b, 255 * a2)

    renderer.text(x + 5, y + 2, 175, 175, 175, 255 * a2, "", nil, t_1)
    renderer.text(x + 140 + l, y + 2, secondary[1], secondary[2], secondary[3], 255 * a2, "r", nil, t_2)
end

function visuals.intersect(x, y, w, h) 
	local cx, cy = ui.mouse_position()
	return cx >= x and cx <= x + w and cy >= y and cy <= y + h
end

function visuals.keybinds()
    if not ui.get(menu.keybinds) then
        return
    end

    -- @docs establish required variables
    local x, y = window.keybinds.x, window.keybinds.y

    local r, g, b, a = ui.get(menu.color)

    local items = { }
    local h = 0

    -- @docs create references and data into tables
    if ui.get(references.doubletap[1]) and ui.get(references.doubletap[2]) then
        h = h + 1
        items[1] = { true, "doubletap", anti_aim.get_double_tap() and "charged" or "unavailable", 1 }
    else
        items[1] = { false, "doubletap", "on", 1 }
    end

    if ui.get(references.hideshots[1]) and ui.get(references.hideshots[2]) then
        h = h + 1
        items[2] = { true, "hideshot", items[1][1] and "conflict" or "on", 2 }
    else
        items[2] = { false, "hideshot", "on", 2 }
    end

    if ui.get(references.damage_override[1]) and ui.get(references.damage_override[2]) then
        h = h + 1
        items[3] = { true, "damage override", ui.get(references.damage_override[3]), 3 }
    else
        items[3] = { false, "damage override", ui.get(references.damage_override[3]), 3 }
    end

    if ui.get(references.safe_point[1]) then
        h = h + 1
        items[4] = { true, "force safe point", "on", 4 }
    else
        items[4] = { false, "force safe point", "on", 4 }
    end

    if ui.get(references.body_aim[1]) then
        h = h + 1
        items[5] = { true, "force body aim", "on", 5 }
    else
        items[5] = { false, "force body aim", "on", 5 }
    end

    if ui.get(references.auto_peek[1]) and ui.get(references.auto_peek[2]) then
        h = h + 1
        items[6] = { true, "auto peek", "on", 6 }
    else
        items[6] = { false, "auto peek", "on", 6 }
    end

    if ui.get(references.duck_peek[1]) then
        h = h + 1
        items[7] = { true, "fake duck", "on", 7 }
    else
        items[7] = { false, "fake duck", "on", 7 }
    end

    if ui.get(references.freestand[1]) and ui.get(references.freestand[2]) then
        h = h + 1
        items[8] = { true, "freestand", "on", 8 }
    else
        items[8] = { false, "freestand", "on", 8 }
    end

    if ui.get(references.slow_walk[1]) and ui.get(references.slow_walk[2]) then
        h = h + 1
        items[9] = { true, "slow walk", "on", 9 }
    else
        items[9] = { false, "slow walk", "on", 9 }
    end

    -- @docs handle animation based height
    if m_h == nil then
        m_h = h
    end

    m_h = visuals.lerp(m_h, h, globals.frametime() * ui.get(menu.animation))
    h = visuals.clamp(m_h, 0, m_h - 0.0000000000001)

    -- @docs inner rectangle
    visuals.rounded_rectangle(x + 10, y + 30, 150, 12 + h * 18, 13, 13, 13, 255, 5)

    -- @docs render active binds
    for i = 1, #items do
        local limit = h - 1 * 17.9
        local idx = items[i][4]
        local count = 0

        if h * 18.1 <= limit then
            k_a[idx] = 0
            goto skip
        end

        if k_a[idx] == nil or not items[i][1] then
            k_a[idx] = 0
        elseif k_a[idx] <= 0.95 then
            k_a[idx] = k_a[idx] + 0.01
        else
            k_a[idx] = 1
        end

        for c = 1, i do
            if items[c][1] then
                count = count + 1
            end
        end

        visuals.insert_information_board(x + 13, y + 36 + 18 * (count - 1), 150, 17, r, g, b, 10, k_a[i], items[i][2], items[i][3], 0)
    end

    ::skip::

    -- @docs outer rectangle
    visuals.outline(x, y, 170, 26, 19, 19, 19, 255, 5, 12 + 5)
    visuals.outline(x, y + 20, 170, 32 + h * 18, 19, 19, 19, 255, 5, 12)
    visuals.outline(x + 1, y + 01, 168, 50 + h * 18, 53, 53, 53, 255, 5, 1)
    visuals.outlined_string(x + 10, y + 11, 255, 255, 255, 255, "", nil, "keybinds")

    -- @docs inner outline
    visuals.outline(x + 10, y + 30, 150, 12 + h * 18, 53, 53, 53, 255, 5, 1)
    visuals.outline(x + 11, y + 31, 148, 10 + h * 18, 0, 0, 0, 255, 5, 1)

    -- @docs dragging
    if ui.is_menu_open() then
        local mouse_x, mouse_y = ui.mouse_position()

        if window.keybinds.dragging and not client.key_state(0x01) then
            alpha = 0
            window.keybinds.dragging = false
        end

        if window.keybinds.dragging and client.key_state(0x01) then
            window.keybinds.x = mouse_x - drag_x
            window.keybinds.y = mouse_y - drag_y
        end

        if visuals.intersect(window.keybinds.x, window.keybinds.y, 150, 50 + h * 18) and client.key_state(0x01) then
            window.keybinds.dragging = true
            drag_x = mouse_x - window.keybinds.x
            drag_y = mouse_y - window.keybinds.y

            renderer.rectangle(window.keybinds.x - 2, window.keybinds.y - 2, 174, 50 + h * 18 + 6, 255, 0, 0, 55)
        end
    end
end

local bomb_damage = function(ent)
    local local_origin, bomb_origin = vector(entity.get_origin(entity.get_local_player())), vector(entity.get_origin(ent))
    local dist = local_origin:dist(bomb_origin)
    local armor = entity.get_prop(entity.get_local_player(), "m_ArmorValue")
    local a, b, c = 450.7, 75.68, 789.2
    local d = (dist - b) / c
    local damage = a * math.exp(-d * d)

    if armor > 0 then
        local new = damage * 0.5
        local placeholder = (damage - new) * 0.5
        if placeholder > armor then
            placeholder = armor * (1 / 0.5)
            new = damage - armor
        end

        damage = new
    end

    return damage
end

local bomb_time = function(ent)
    local bomb_time = entity.get_prop(ent, "m_flC4Blow") - globals.curtime()
    return bomb_time ~= nil and bomb_time > 0 and bomb_time or 0 
end

local defuseable = function(ent)
    local bomb_time, has_defuser = bomb_time(ent), entity.get_prop(ent, "m_hBombDefuser")

    if has_defuser then
        if storage.c4_time_froze < entity.get_prop(ent, "m_flDefureCountDown") - globals.curtime() then
            return true
        end
    else
        if bomb_time > 6 then
            return true
        end
    end

    return false
end

local function invulnerable()
    local player = entity.get_local_player()
    local prop = entity.get_prop(player, "m_flSimulationTime")

    local sim_time = math.floor(0.5 + (prop / globals.tickinterval()))
    local prev_sim_time = storage.information.prev_sim_time
    local tickcount = globals.tickcount()

    if storage.information.prev_sim_time == 0 then
        storage.information.prev_sim_time = sim_time
        return
    end

    local sim_delta = sim_time - prev_sim_time
    
    if sim_delta < 0 then
        local shift = math.abs(sim_delta)
        storage.information.defensive_dur = globals.tickcount() + shift
        storage.information.defensive_shift = shift
    end

    storage.information.prev_sim_time = sim_time
end

function visuals.round_info()
    if not ui.get(menu.information) then
        return
    end

    -- @docs initialising required variables
    local x, y = window.round.x, window.round.y

    local r, g, b, a = ui.get(menu.color)

    local info = { }
    local j = 0
    local l = (client.current_threat() == nil or not entity.is_alive(entity.get_local_player())) and 0 or renderer.measure_text("", entity.get_player_name(client.current_threat())) - 40

    local bomb = entity.get_all("CPlantedC4")[1]
    
    if bomb == nil then
        goto next
    end

    defuse_timer = entity.get_prop(bomb, "m_flDefuseCountDown") - globals.curtime()

    storage.timer, storage.fortcalc, storage.timer_max = math.ceil(bomb_time(bomb) * 10 ^ 1 - 0.5) / 10 ^ 1 - 0.5, bomb_time(bomb), client.get_cvar("mp_c4timer")

    if entity.get_prop(bomb, "m_hBombDefuser") then
        storage.timer = math.ceil(defuse_timer * 10 ^ 1 - 0.5)/10 ^ 1 - 0.5
        storage.fortcalc = defuse_timer
        storage.timer_max = 10
    end

    storage.timer = storage.timer > 0 and storage.timer or 0
    
    timer_calc = (math.max(0, math.min(storage.timer_max, storage.fortcalc))) / storage.timer_max

    damage = math.floor(bomb_damage(bomb))
    site = entity.get_prop(bomb, "m_nBombSite")
    site = site == 1 and "b" or "a"

    ::next::

    invulnerable()
    local modifier = entity.get_prop(entity.get_local_player(), "m_flVelocityModifier")
    local overlap = anti_aim.get_overlap(true)

    -- @docs create references and data into tables
    if bomb == nil or entity.get_prop(bomb, "m_bBombDefused") == 1 or storage.timer == 0 then
        info[1] = { false, "x", "unavailable", 1 }
    else
        j = j + 1

        info[1] = { true, "bomb planted " .. site, storage.timer .. "s", 1 }
    end

    if bomb == nil or damage == nil or damage < 1 or storage.timer == 0 or not entity.is_alive(entity.get_local_player()) or entity.get_prop(bomb, "m_bBombDefused") == 1 then
        info[2] = { false, "x", "unavailable", 2 }
    else
        j = j + 1

        info[2] = { true, "bomb lethality", damage >= entity.get_prop(entity.get_local_player(), "m_iHealth") and "fatal" or damage, 2 }
    end

    if client.current_threat() == nil or not entity.is_alive(entity.get_local_player()) then
        info[3] = { false, "x", "unavailable", 3 }
    else
        j = j + 1

        info[3] = { true, "anti-aim target", entity.get_player_name(client.current_threat()), 3 }
    end

    if storage.information.defensive_dur + 20 < globals.tickcount() or not entity.is_alive(entity.get_local_player()) then
        info[4] = { false, "x", "unavailable", 4 }
    else
        j = j + 1

        info[4] = { true, "defensive", storage.information.defensive_dur < globals.tickcount() and "expired" or "active", 4 }
    end

    if modifier == 1 or not entity.is_alive(entity.get_local_player()) then
        info[5] = { false, "x", "unavailable", 5 }
    else
        j = j + 1

        info[5] = { true, "slowed", math.floor((255 * modifier) / 255 * 100) .. "%", 5 }
    end

    if not entity.is_alive(entity.get_local_player()) then
        info[6] = { false, "x", "unavailable", 6 }
    else
        j = j + 1

        info[6] = { true, "anti-aim overlap", math.floor(overlap * 100) .. "%", 6 }
    end

    -- @docs handle animation based height
    if m_j == nil then
        m_j = j
    end
    
    m_j = visuals.lerp(m_j, j, globals.frametime() * ui.get(menu.animation))
    j = visuals.clamp(m_j, 0, m_j - 0.0000000000001)

    if l_j == nil then
        l_j = l
    end

    l_j = visuals.lerp(l_j, l, globals.frametime() * ui.get(menu.animation))
    l = visuals.clamp(l_j, 0, l_j - 0.0000000000001)


    -- @docs inner rectangle
    visuals.rounded_rectangle(x + 10, y + 30, 150 + l, 12 + j * 18, 13, 13, 13, 255, 5)

    -- @docs render active binds
    for i = 1, #info do
        local limit = j - 1 * 17.9
        local idx = info[i][4]
        local count = 0

        if j * 18.1 <= limit then
            t_a[idx] = 0
            goto skip
        end

        if t_a[idx] == nil or not info[i][1] then
            t_a[idx] = 0
        elseif t_a[idx] <= 0.95 then
            t_a[idx] = t_a[idx] + 0.01
        else
            t_a[idx] = 1
        end

        for c = 1, i do
            if info[c][1] then
                count = count + 1
            end
        end

        visuals.insert_information_board(x + 13, y + 36 + 18 * (count - 1), 150 + l, 17, r, g, b, 10, t_a[i], info[i][2], info[i][3], l)
    end

    ::skip::

    -- @docs outer rectangle
    visuals.outline(x, y, 170 + l, 26, 19, 19, 19, 255, 5, 12 + 5)
    visuals.outline(x, y + 20, 170 + l, 32 + j * 18, 19, 19, 19, 255, 5, 12)
    visuals.outline(x + 1, y + 01, 168 + l, 50 + j * 18, 53, 53, 53, 255, 5, 1)
    visuals.outlined_string(x + 10, y + 11, 255, 255, 255, 255, "", nil, "additional information")

    -- @docs inner outline
    visuals.outline(x + 10, y + 30, 150 + l, 12 + j * 18, 53, 53, 53, 255, 5, 1)
    visuals.outline(x + 11, y + 31, 148 + l, 10 + j * 18, 0, 0, 0, 255, 5, 1)

    if ui.is_menu_open() then
        local mouse_x, mouse_y = ui.mouse_position()

        if window.round.dragging and not client.key_state(0x01) then
            alpha = 0
            window.round.dragging = false
        end

        if window.round.dragging and client.key_state(0x01) then
            window.round.x = mouse_x - drag_x
            window.round.y = mouse_y - drag_y
        end

        if visuals.intersect(window.round.x, window.round.y, 150, 50 + j * 18) and client.key_state(0x01) then
            window.round.dragging = true
            drag_x = mouse_x - window.round.x
            drag_y = mouse_y - window.round.y

            renderer.rectangle(window.round.x - 2, window.round.y - 2, 174, 50 + j * 18 + 6, 255, 0, 0, 55)
        end
    end
end

local function shutdown()
    database.write("keybinds_x", window.keybinds.x)
    database.write("keybinds_y", window.keybinds.y)
    database.write("round_x", window.round.x)
    database.write("round_y", window.round.y)
end

local function paint()
    visuals.keybinds()
    visuals.round_info()
end

client.set_event_callback("bomb_begindefuse", function()
    storage.c4_time_frozen = math.ceil(bomb_time(entity.get_all("CPlantedC4")[1]) * 10 ^ 1 - 0.5)/10 ^ 1 - 0.5
end)

client.set_event_callback("paint", paint)
client.set_event_callback("shutdown", shutdown)
