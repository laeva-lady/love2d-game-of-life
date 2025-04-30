local bmp_util = {}

local function read_file(filename)
    local file = assert(io.open(filename, "rb"))

    -- Read BMP header
    local signature = file:read(2)
    if signature ~= "BM" then
        error("Not a valid BMP file")
    end

    file:seek("set", 10)
    local dataOffset = string.unpack("<I4", file:read(4))

    file:seek("set", 18)
    local width = string.unpack("<I4", file:read(4))
    local height = string.unpack("<I4", file:read(4))

    file:seek("set", 28)
    local bitsPerPixel = string.unpack("<I2", file:read(2))
    if bitsPerPixel ~= 24 then
        error("Only 24-bit BMP files are supported in this example")
    end

    file:seek("set", dataOffset)

    local rowSize = math.floor((bitsPerPixel * width + 31) / 32) * 4
    local padding = rowSize - width * 3
    local pixels = {}

    for y = height - 1, 0, -1 do
        pixels[y] = {}
        for x = 0, width - 1 do
            local b, g, r = string.unpack("BBB", file:read(3))
            pixels[y][x] = { r = r, g = g, b = b }
        end
        _ = file:read(padding)
    end

    file:close()
    return {
        width = width,
        height = height,
        pixels = pixels
    }
end

function bmp_util.getGridFromPixels(filename)
    local bit = read_file(filename)
    local grid = {}
    for x = 1, bit.height do
        grid[x] = {}
        for y = 1, bit.width do
            local pixel = bit.pixels[y][x]
            local color = pixel.r > 155

            if color then
                grid[x][y] = true
            else
                grid[x][y] = false
            end
        end
    end
    return grid
end

return bmp_util
