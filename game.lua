local game = {}

--- takes in grid pos and converts it to map pos
--- @param grid_x number
--- @param grid_y number
--- @return number, number
function ConvertGridPos2MapPos(grid_x, grid_y)
    local cellsize = game.state.options.cellsize
    local map_x = grid_x * cellsize
    local map_y = grid_y * cellsize
    return map_x, map_y
end

--- takes in map pos and converts it to grid pos
--- @param map_x number
--- @param map_y number
--- @return number, number
function game.ConvertMapPos2GridPos(map_x, map_y)
    local cellsize = game.state.options.cellsize
    local grid_x = math.floor(map_x / cellsize)
    local grid_y = math.floor(map_y / cellsize)
    return grid_x, grid_y
end

function GetScreenPosFromGrid(grid_x, grid_y)
    local map_x, map_y = ConvertGridPos2MapPos(grid_x, grid_y)
    local screen_x = (map_x - game.state.camera.x)
    local screen_y = (map_y - game.state.camera.y)
    return screen_x, screen_y
end

--- cells use the grid for their position
--- @param grid_x number
--- @param grid_y number
function game.NewCell(grid_x, grid_y)
    game.state.cells[grid_x] = game.state.cells[grid_x] or {}
    game.state.cells[grid_x][grid_y] = true
end

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
                local alpha = math.max(0, 1 - (age / game.state.options.trace_lifetime))
                love.graphics.setColor(1, 1, 1, alpha * 0.5)
                love.graphics.rectangle("fill", screen_x, screen_y, game.state.options.cellsize
                    -- * game.state.camera.zoom
                    ,
                    game.state.options.cellsize -- * game.state.camera.zoom
                )
            end
        end
    end

    -- Draw active cells
    love.graphics.setColor(1, 1, 1, 1)
    for x, col in pairs(game.state.cells) do
        for y, _ in pairs(col) do
            local screen_x, screen_y = GetScreenPosFromGrid(x, y)
            love.graphics.rectangle("fill", screen_x, screen_y, game.state.options.cellsize
                -- * game.state.camera.zoom
                ,
                game.state.options.cellsize
            -- * game.state.camera.zoom
            )
        end
    end
end

function game.drawGrid()
    if game.state.camera.zoom < 0.7 then
        return
    end
    local cellsize = game.state.options.cellsize
    local screen_width, screen_height = love.graphics.getDimensions()

    local start_x = math.floor((game.state.camera.x - screen_width) / cellsize)
    local end_x = math.ceil((game.state.camera.x + screen_width) / cellsize)
    local start_y = math.floor((game.state.camera.y - screen_height) / cellsize)
    local end_y = math.ceil((game.state.camera.y + screen_height) / cellsize)

    -- Set grid color (slightly darker than white)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)

    -- Draw vertical lines
    for x = start_x, end_x do
        local screen_x, _ = GetScreenPosFromGrid(x, 0)
        love.graphics.line(screen_x, -screen_height, screen_x, screen_height)
    end

    -- Draw horizontal lines
    for y = start_y, end_y do
        local _, screen_y = GetScreenPosFromGrid(0, y)
        love.graphics.line(-screen_width, screen_y, screen_width, screen_y)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function game.DrawCursor()
    local cellsize       = game.state.options.cellsize

    local mx             = game.state.mouse.x + game.state.camera.x + 10
    local my             = game.state.mouse.y + game.state.camera.y - 10
    local grid_x, grid_y = game.ConvertMapPos2GridPos(mx, my)
    local map_x, map_y   = GetScreenPosFromGrid(grid_x, grid_y)

    if isAlive(grid_x - 13, grid_y - 7) then -- no idea what these magic numbers are...
        love.graphics.setColor(0, 0, 1) -- Blue
        love.graphics.setLineWidth(10)
    else
        love.graphics.setColor(0, 1, 0) -- Green
        love.graphics.setLineWidth(3)
    end

    love.graphics.rectangle("line",
        map_x - 10,
        map_y + 10,
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
                if age < game.state.options.trace_lifetime then
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

                        if (alive and (neighbours == 2 or neighbours == 3)) or (not alive and neighbours == 3) then
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

game.state = {
    paused = false,
    options = {
        screen = {
            width = 1280,
            height = 720
        },
        cellsize = 50,
        trace_lifetime = 10, -- Number of frames a trace will last
        keys = {
            up = "w",
            left = "a",
            down = "r",
            right = "s",
            fps_up = "f",
            fps_down = "q",
        }
    },
    mouse = {
        x = 0,
        y = 0
    },
    camera = {
        x = 0,
        y = 0,
        zoom = 1,
        target_zoom = 1,
        zoom_delta = 0.1,
        min_zoom = 0.1,
        max_zoom = 5,
        update = function(self, dt)
            local zoom_smoothing = 5

            local dilf = (self.target_zoom - self.zoom) * dt * zoom_smoothing
            if math.abs(dilf) < 0.00000005 then
                dilf = 0
                self.zoom = self.target_zoom
            else
                self.zoom = self.zoom + dilf
            end
        end
    },
    cells = {},
    traces = {} -- New field to store cell traces
}

return game
