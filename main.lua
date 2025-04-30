local game = require "game"

game.NewCell(0, -1)
game.NewCell(0, 0)
game.NewCell(0, 1)

game.NewCell(2, 3)
game.NewCell(2, 4)
game.NewCell(2, 5)

function love.load()
    love.window.setMode(game.state.options.screen.width, game.state.options.screen.height, {
        fullscreen = false,
        vsync = false,
        resizable = true,
        msaa = 4 -- Anti-aliasing (4x Multisample)
    })
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    if key == "space" then game.state.paused = not game.state.paused end
    if key == "lctrl" then
        game.state.camera.zoom = 1
        game.state.camera.target_zoom = 1
    end
end

local mouseDown = false
local lastCellX, lastCellY = nil, nil

function love.mousepressed(x, y, button)
    if button == 1 then
        mouseDown = true
        HandleMouseAction(x, y)
    end
end

function love.mousereleased(_, _, button)
    if button == 1 then
        mouseDown = false
        lastCellX, lastCellY = nil, nil -- reset tracking
    end
end

function love.mousemoved(x, y, _, _)
    game.state.mouse.x = x
    game.state.mouse.y = y
    if mouseDown and game.state.paused then
        HandleMouseAction(x, y)
    end
end

function HandleMouseAction(x, y)
    if game.state.paused then
        local camX    = game.state.camera.x
        local camY    = game.state.camera.y
        local screenW = game.state.options.screen.width
        local screenH = game.state.options.screen.height
        local worldX  = camX + (x - screenW / 2)
        local worldY  = camY + (y - screenH / 2)


        local gx, gy = game.ConvertMapPos2GridPos(worldX, worldY)

        if gx == lastCellX and gy == lastCellY then return end
        lastCellX, lastCellY = gx, gy

        if game.state.cells[gx] and game.state.cells[gx][gy] then
            game.KillCell(gx, gy)
        else
            game.NewCell(gx, gy)
        end
    end
end

function love.wheelmoved(_, y)
    if y > 0 then
        game.state.camera.target_zoom = game.state.camera.target_zoom + game.state.camera.zoom_delta
    elseif y < 0 then
        game.state.camera.target_zoom = game.state.camera.target_zoom - game.state.camera.zoom_delta
    end

    -- Clamp zoom to a reasonable range
    game.state.camera.target_zoom =
        math.max(
            game.state.camera.min_zoom,
            math.min(
                game.state.camera.max_zoom,
                game.state.camera.target_zoom
            )
        )
end

FPS = 3
local accumulator = 0
local function flooredFPS()
    return math.floor(FPS)
end
local function fixed_dt()
    return 1 / flooredFPS()
end

-- camera updates in real time but the cells update at a fixed interval
function love.update(dt)
    Debug()
    game.state.options.screen.width, game.state.options.screen.height = love.graphics.getDimensions()
    game.state.camera:update(dt)
    if game.state.paused then
        game.state.camera.zoom = 1
        game.state.camera.target_zoom = 1
    end

    local dx, dy = 0, 0

    if love.keyboard.isDown(game.state.options.keys.up) then dy = dy - 1 end
    if love.keyboard.isDown(game.state.options.keys.down) then dy = dy + 1 end
    if love.keyboard.isDown(game.state.options.keys.left) then dx = dx - 1 end
    if love.keyboard.isDown(game.state.options.keys.right) then dx = dx + 1 end

    -- Normalize direction
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end

    local camSpeed = 1000 / (game.state.camera.zoom ^ 1.2)
    game.state.camera.x = game.state.camera.x + dx * camSpeed * dt
    game.state.camera.y = game.state.camera.y + dy * camSpeed * dt


    if love.keyboard.isDown(game.state.options.keys.fps_up) then
        FPS = FPS + 0.1
        FPS = math.min(120, FPS)
    end
    if love.keyboard.isDown(game.state.options.keys.fps_down) then
        FPS = FPS - 0.1
        FPS = math.max(1, FPS) -- Allow for intervals up to 10 seconds
    end

    -- enforce FPS
    accumulator = accumulator + dt
    while accumulator >= fixed_dt() do
        if not game.state.paused then
            game.updateGame()
        end
        accumulator = accumulator - fixed_dt()
    end
end

function love.draw()
    -- screen (camera.pos)
    love.graphics.push()
    love.graphics.translate(game.state.options.screen.width / 2, game.state.options.screen.height / 2)
    love.graphics.scale(game.state.camera.zoom, game.state.camera.zoom)

    -- draw game
    game.drawCell()
    game.drawGrid()

    -- screen (0, 0)
    love.graphics.pop()

    -- TODO : figure out what's wrong
    if game.state.camera.zoom == 1 then
        game.DrawCursor()
    end


    -- draw camera pointer
    love.graphics.setColor(1, 0, 0)
    love.graphics.circle("fill", game.state.options.screen.width / 2, game.state.options.screen.height / 2, 2.5)

    -- print coordinate of camera
    love.graphics.print(
        string.format(
            "%.2f ; %.2f",
            game.state.camera.x,
            game.state.camera.y
        ), 50, game.state.options.screen.height - 50)
    local cxg, cyg = game.ConvertMapPos2GridPos(game.state.camera.x, game.state.camera.y)
    love.graphics.print(
        string.format(
            "%.2f ; %.2f",
            cxg, cyg
        ), 50, game.state.options.screen.height - 100)
    love.graphics.setColor(1, 1, 1)

    -- show infos
    love.graphics.setFont(love.graphics.newFont(36))
    local offset = 10
    local step = 40
    love.graphics.print(string.format("Paused : %s", game.state.paused), 10, offset + step * 0)
    love.graphics.print(string.format("FPS : %s", flooredFPS()), 10, offset + step * 1)
    love.graphics.print(string.format("%s", FPS), 10, offset + step * 2)
    love.graphics.print(string.format("zoom : %.3f", game.state.camera.zoom), 10, offset + step * 3)
end

function Debug()
    -- for x, col in pairs(game.state.cells) do
    --     for y, _ in pairs(col) do
    --         print(x, y, game.state.cells[x][y], game.state.camera.zoom, game.state.camera.x, game.state.camera.y)
    --     end
    -- end
end
