local game = {}

--- takes in grid pos and converts it to map pos
--- @param grid_x number
--- @param grid_y number
--- @return number, number
function ConvertGridPos2MapPos(grid_x, grid_y)
    local cellsize = game.state.cell.size
    local map_x = grid_x * cellsize
    local map_y = grid_y * cellsize
    return map_x, map_y
end

--- takes in map pos and converts it to grid pos
--- @param map_x number
--- @param map_y number
--- @return number, number
function game.ConvertMapPos2GridPos(map_x, map_y)
    local cellsize = game.state.cell.size
    local grid_x = math.floor(map_x / cellsize)
    local grid_y = math.floor(map_y / cellsize)
    return grid_x, grid_y
end

--- @param grid_x number
--- @param grid_y number
--- @return number screen_x, number screen_y
function GetScreenPosFromGrid(grid_x, grid_y)
    local map_x, map_y = ConvertGridPos2MapPos(grid_x, grid_y)
    local screen_x = (map_x - game.state.camera.x)
    local screen_y = (map_y - game.state.camera.y)
    return screen_x, screen_y
end

--- @param mx number
--- @param my number
--- @return number sx, number sy
function game.ConvertScreen2Map(mx, my)
    local sx = mx * game.state.cell.size + game.state.screen.width
    local sy = my * game.state.cell.size + game.state.screen.height

    return sx, sy
end

--- cells use the grid for their position
--- @param grid_x number
--- @param grid_y number
function game.NewCell(grid_x, grid_y)
    game.state.cells[grid_x] = game.state.cells[grid_x] or {}
    game.state.cells[grid_x][grid_y] = true
end

--- @param grid_x number
--- @param grid_y number
function game.KillCell(grid_x, grid_y)
    if game.state.cells[grid_x] then
        game.state.cells[grid_x][grid_y] = nil
        -- Clean up empty columns
        if next(game.state.cells[grid_x]) == nil then
            game.state.cells[grid_x] = nil
        end
    end
end

local function isAlive(x, y)
    return game.state.cells[x] and game.state.cells[x][y]
end

function game.drawCell()
    -- Draw traces first (so they appear behind active cells)
    if game.state.traces then
        for x, col in pairs(game.state.traces) do
            for y, age in pairs(col) do
                local screen_x, screen_y = GetScreenPosFromGrid(x, y)
                local alpha = math.max(0, 1 - (age / game.state.cell.trace_lifetime))
                love.graphics.setColor(1, 1, 1, alpha * 0.5)
                love.graphics.rectangle(
                    "fill",
                    screen_x,
                    screen_y,
                    game.state.cell.size,
                    game.state.cell.size
                )
            end
        end
    end

    -- Draw active cells
    love.graphics.setColor(1, 1, 1, 1)
    for x, col in pairs(game.state.cells) do
        for y, _ in pairs(col) do
            local screen_x, screen_y = GetScreenPosFromGrid(x, y)
            love.graphics.rectangle(
                "fill",
                screen_x,
                screen_y,
                game.state.cell.size,
                game.state.cell.size
            )
        end
    end
end

function game.DrawCursor()
    local cellsize   = game.state.cell.size

    local camX       = game.state.camera.x
    local camY       = game.state.camera.y
    local screenW    = game.state.screen.width
    local screenH    = game.state.screen.height
    local x          = game.state.mouse.x
    local y          = game.state.mouse.y

    local worldX     = camX + (x - screenW / 2)
    local worldY     = camY + (y - screenH / 2)

    local gx, gy     = game.ConvertMapPos2GridPos(worldX, worldY)

    local mapX, mapY = GetScreenPosFromGrid(gx, gy)

    if isAlive(gx, gy) then
        love.graphics.setColor(0, 0, 1) -- Blue
        love.graphics.setLineWidth(10)
    else
        love.graphics.setColor(0, 1, 0) -- Green
        love.graphics.setLineWidth(3)
    end

    love.graphics.rectangle("line",
        mapX + screenW / 2,
        mapY + screenH / 2,
        cellsize,
        cellsize,
        5
    )
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 1)
end

local function getNeighbours(x, y)
    local count = 0
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                if isAlive(x + dx, y + dy) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

function game.updateGame()
    local newCells = {}
    local checked = {}

    -- Update traces
    if game.state.traces then
        local newTraces = {}
        for x, col in pairs(game.state.traces) do
            for y, age in pairs(col) do
                if age < game.state.cell.trace_lifetime then
                    newTraces[x] = newTraces[x] or {}
                    newTraces[x][y] = age + 1
                end
            end
        end
        game.state.traces = newTraces
    end

    -- Add current cells to traces
    game.state.traces = game.state.traces or {}
    for x, col in pairs(game.state.cells) do
        for y, _ in pairs(col) do
            game.state.traces[x] = game.state.traces[x] or {}
            game.state.traces[x][y] = 0
        end
    end

    for x, col in pairs(game.state.cells) do
        for y, _ in pairs(col) do
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local nx, ny = x + dx, y + dy
                    local id = nx .. "," .. ny
                    if not checked[id] then
                        checked[id] = true
                        local neighbours = getNeighbours(nx, ny)
                        local alive = isAlive(nx, ny)

                        if (alive and (neighbours == 2 or neighbours == 3))
                            or (not alive and neighbours == 3) then
                            newCells[nx] = newCells[nx] or {}
                            newCells[nx][ny] = true
                        end
                    end
                end
            end
        end
    end

    game.state.cells = newCells
end

game.options = {
    keys = {
        up = "w",
        left = "a",
        down = "r",
        right = "s",
        fps_up = "f",
        fps_down = "q"
    }
}

game.state = {
    paused = false,
    screen = {
        width = 1280,
        height = 720
    },
    cell = {
        size = 50,
        min_size = 1,
        max_size = 150,
        target_size = 50,
        changeDelta = 1, -- constant is the default delta with which cell.size will change
        changedDelta = 1, -- modified delta from the cell.mathfun to scale delta
        trace_lifetime = 30,
        mathfun = function(x)
            local h, k = 1, 1
            return 1e-3 * (x - h) ^ 2 + k
        end,
        update = function(self, dt)
            local smoothing = 10
            local difference = (self.target_size - self.size) * dt * smoothing

            local x = self.size
            self.changedDelta = self.changeDelta * self.mathfun(x)

            if math.abs(difference) < 1e-4 then
                difference = 0
                self.target_size = self.size
            end

            self.size = self.size + difference
        end
    },
    mouse = {
        x = 0,
        y = 0
    },
    camera = {
        x = 0,
        y = 0,
    },
    cells = {},
    traces = {}
}

return game
