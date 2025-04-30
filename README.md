# game of life
- draw a grid
- make the screen a projection that can be moved around with wasd
- make pausing
- clicking a cell make it alive/dead
- zoom in/out

- only keep track of alive cells:
    ```lua
    alive_cell = {
        x,
        y,
        get_neighbours = function() end
    }
    ```