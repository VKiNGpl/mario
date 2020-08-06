--[[
    GD50
    Super Mario Bros. Remake

    -- PlayState Class --
]]

PlayState = Class{__includes = BaseState}

local levelWidth = 100

function PlayState:init()
    self.camX = 0
    self.camY = 0
    self.currentLevel = 1
    self.levelWidth = levelWidth
    self.level = LevelMaker.generate(self.levelWidth + (self.currentLevel - 1) * 10, 10)
    self.tileMap = self.level.tileMap
    self.background = math.random(3)
    self.backgroundX = 0
    self.flagPresent = false

    self.gravityOn = true
    self.gravityAmount = GRAVITY

    self.player = Player({
        x = self:findGround(), y = 0,
        width = 16, height = 20,
        texture = 'green-alien',
        stateMachine = StateMachine {
            ['idle'] = function() return PlayerIdleState(self.player) end,
            ['walking'] = function() return PlayerWalkingState(self.player) end,
            ['jump'] = function() return PlayerJumpState(self.player, self.gravityAmount) end,
            ['falling'] = function() return PlayerFallingState(self.player, self.gravityAmount) end
        },
        map = self.tileMap,
        level = self.level
    })

    self:spawnEnemies()

    self.player:changeState('falling')
end

function PlayState:enter(params)
    self.currentLevel = params.level
    self.player.score = params.score or 0
end

function PlayState:update(dt)
    Timer.update(dt)

    -- remove any nils from pickups, etc.
    self.level:clear()

    -- update player and level
    self.player:update(dt)
    self.level:update(dt)

    -- constrain player X no matter which state
    if self.player.x <= 0 then
        self.player.x = 0
    elseif self.player.x > TILE_SIZE * self.tileMap.width - self.player.width then
        self.player.x = TILE_SIZE * self.tileMap.width - self.player.width
    end

    self:updateCamera()
    self:spawnFlag()
end

function PlayState:render()
    love.graphics.push()
    love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], math.floor(-self.backgroundX), 0)
    love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], math.floor(-self.backgroundX),
        gTextures['backgrounds']:getHeight() / 3 * 2, 0, 1, -1)
    love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], math.floor(-self.backgroundX + 256), 0)
    love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], math.floor(-self.backgroundX + 256),
        gTextures['backgrounds']:getHeight() / 3 * 2, 0, 1, -1)
    
    -- translate the entire view of the scene to emulate a camera
    love.graphics.translate(-math.floor(self.camX), -math.floor(self.camY))
    
    self.level:render()

    self.player:render()
    love.graphics.pop()
    
    -- render score
    love.graphics.setFont(gFonts['medium'])
    love.graphics.setColor(0.0, 0.0, 0.0, 1.0)
    love.graphics.print(tostring(self.player.score), 5, 5)
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.print(tostring(self.player.score), 4, 4)

    -- render level
    love.graphics.setFont(gFonts['medium'])
    love.graphics.setColor(0.0, 0.0, 0.0, 1.0)
    love.graphics.print('LEVEL ' .. self.currentLevel, 190, 5)
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.print('LEVEL ' .. self.currentLevel, 190, 4)
end

function PlayState:updateCamera()
    -- clamp movement of the camera's X between 0 and the map bounds - virtual width,
    -- setting it half the screen to the left of the player so they are in the center
    self.camX = math.max(0,
        math.min(TILE_SIZE * self.tileMap.width - VIRTUAL_WIDTH,
        self.player.x - (VIRTUAL_WIDTH / 2 - 8)))

    -- adjust background X to move a third the rate of the camera for parallax
    self.backgroundX = (self.camX / 3) % 256
end

--[[
    Adds a series of enemies to the level randomly.
]]
function PlayState:spawnEnemies()
    -- spawn snails in the level
    for x = 1, self.tileMap.width do

        -- flag for whether there's ground on this column of the level
        local groundFound = false

        for y = 1, self.tileMap.height do
            if not groundFound then
                if self.tileMap.tiles[y][x].id == TILE_ID_GROUND then
                    groundFound = true

                    -- random chance, 1 in 20
                    if math.random(20) == 1 then
                        
                        -- instantiate snail, declaring in advance so we can pass it into state machine
                        local snail
                        snail = Snail {
                            texture = 'creatures',
                            x = (x - 1) * TILE_SIZE,
                            y = (y - 2) * TILE_SIZE + 2,
                            width = 16,
                            height = 16,
                            stateMachine = StateMachine {
                                ['idle'] = function() return SnailIdleState(self.tileMap, self.player, snail) end,
                                ['moving'] = function() return SnailMovingState(self.tileMap, self.player, snail) end,
                                ['chasing'] = function() return SnailChasingState(self.tileMap, self.player, snail) end
                            }
                        }
                        snail:changeState('idle', {
                            wait = math.random(5)
                        })

                        table.insert(self.level.entities, snail)
                    end
                end
            end
        end
    end
end

function PlayState:findGround()
    for x = 1, self.tileMap.width do

        -- flag for whether there's ground on this column of the level
        local groundFound = false

        for y = 1, self.tileMap.height do
            if not groundFound then
                if self.tileMap.tiles[y][x].id == TILE_ID_GROUND then
                    return (x - 1) * TILE_SIZE
                end
            end
        end
    end

    return 7
end

function PlayState:spawnFlag()
    

    if not self.flagPresent then
        for o = 1, #self.level.objects do
            if self.level.objects[o].isLock == true then
                return
            end
        end

        local flagType = math.random( 15, 18 )

        flagPostBase = GameObject {
            x = self.level.flagSpot * TILE_SIZE,
            y = 5 * TILE_SIZE,
            texture = 'flag-posts',
            width = 16,
            height = 16,
            frame = flagType,
            consumable = true,
            onConsume = function()
                levelWidth = levelWidth + 10
                gStateMachine:change('play', {
                    level = self.currentLevel + 1,
                    score = self.player.score,
                })
            end
        }
        flagPostMast = GameObject {
            x = self.level.flagSpot * TILE_SIZE,
            y = 4 * TILE_SIZE,
            texture = 'flag-posts',
            width = 16,
            height = 16,
            frame = flagType - 6,
            consumable = true,
            onConsume = function()
                levelWidth = levelWidth + 10
                gStateMachine:change('play', {
                    level = self.currentLevel + 1,
                    score = self.player.score,
                })
            end
        }
        flagPostTip = GameObject {
            x = self.level.flagSpot * TILE_SIZE,
            y = 3 * TILE_SIZE,
            texture = 'flag-posts',
            width = 16,
            height = 16,
            frame = flagType - 12,
            consumable = true,
            onConsume = function()
                levelWidth = levelWidth + 10
                gStateMachine:change('play', {
                    level = self.currentLevel + 1,
                    score = self.player.score,
                })
            end
        }
        flagPostFlag = GameObject {
            x = self.level.flagSpot * TILE_SIZE + (TILE_SIZE/2 - 2),
            y = 3 * TILE_SIZE + (TILE_SIZE/4 + 2),
            texture = 'flags',
            width = 16,
            height = 16,
            frame = flagType - 14 
        }

        table.insert( self.level.objects, flagPostBase )
        table.insert( self.level.objects, flagPostMast )
        table.insert( self.level.objects, flagPostTip )
        table.insert( self.level.objects, flagPostFlag )
        self.flagPresent = true
    end
end