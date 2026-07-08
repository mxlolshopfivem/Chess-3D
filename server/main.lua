local Games = {} 

local PieceNamePT = {
    pawn = translate.PAWN,
    knight = translate.KNIGHT,
    bishop = translate.BISHOP,
    rook = translate.ROOK,
    queen = translate.QUEEN,
    king = translate.KING,
}

local SideNamePT = {
    white = translate.WHITE,
    black = translate.BLACK,
}

local DrawReasonPT = {
    fifty_move = translate.FIFTY_MOVE,
    insufficient_material = translate.INSUFFICIENT_MATERIAL,
    threefold_repetition = translate.THREEFOLD_REPETITION,
    stalemate = translate.STALEMATE,
}

local serializeTableCfg 

local function getOrCreateGame(tableId)
    if not Games[tableId] then
        Games[tableId] = {
            game = ChessEngine.NewGame(),
            players = { white = nil, black = nil },
            ai = { white = false, black = false },
            spectators = {}, 
            gen = 0, 
        }
    end
    return Games[tableId]
end

local TableCfgIndex = {}
for _, t in ipairs(Config.Tables) do
    TableCfgIndex[t.id] = t
end

local function tableCfgById(tableId)
    return TableCfgIndex[tableId]
end

local function broadcastState(tableId)
    local g = Games[tableId]
    if not g then return end
    local recipients = {}
    if g.players.white then table.insert(recipients, g.players.white) end
    if g.players.black then table.insert(recipients, g.players.black) end
    for src in pairs(g.spectators or {}) do
        table.insert(recipients, src)
    end

    for _, src in ipairs(recipients) do
        TriggerClientEvent("chess:stateSync", src, tableId, g.game, g.players)
    end
end

local function refreshAllSpectators()
    local radius = Config.SpectatorRadius or 30.0
    local radiusSq = radius * radius

    local seatedSrc = {}
    for _, g in pairs(Games) do
        if g.players.white then seatedSrc[g.players.white] = true end
        if g.players.black then seatedSrc[g.players.black] = true end
    end

    local nearestTableForSrc = {}
    for _, strSrc in ipairs(GetPlayers()) do
        local src = tonumber(strSrc)
        if src and not seatedSrc[src] then
            local ped = GetPlayerPed(strSrc)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local bestTableId, bestDistSq = nil, nil

                for tableId in pairs(Games) do
                    local tableCfg = tableCfgById(tableId)
                    if tableCfg and tableCfg.coord then
                        local dx = coords.x - tableCfg.coord.x
                        local dy = coords.y - tableCfg.coord.y
                        local dz = coords.z - tableCfg.coord.z
                        local distSq = dx * dx + dy * dy + dz * dz
                        if distSq <= radiusSq and (not bestDistSq or distSq < bestDistSq) then
                            bestDistSq = distSq
                            bestTableId = tableId
                        end
                    end
                end

                if bestTableId then
                    nearestTableForSrc[src] = bestTableId
                end
            end
        end
    end

    for tableId, g in pairs(Games) do
        g.spectators = g.spectators or {}
        local stillNear = {}

        for src, nearestId in pairs(nearestTableForSrc) do
            if nearestId == tableId then
                stillNear[src] = true
                if not g.spectators[src] then
                    TriggerClientEvent("chess:stateSync", src, tableId, g.game, g.players)
                    if g.players.white or g.players.black then
                        TriggerClientEvent("chess:notify", src, (translate.NOTIFY_YOU_ARE_WATCHING_THE_GAME_AT_TABLE):format(tableId))
                    end
                end
            end
        end

        for src in pairs(g.spectators) do
            if not stillNear[src] then
                TriggerClientEvent("chess:spectateLeft", src, tableId)
            end
        end

        g.spectators = stillNear
    end
end

CreateThread(function()
    while true do
        Wait(3000)
        refreshAllSpectators()
    end
end)

local PlayerNearBoards = {} 

local function refreshBoardProximity()
    local radius = Config.BoardSpawnRadius or 60.0
    local radiusSq = radius * radius

    local connected = {}
    for _, strSrc in ipairs(GetPlayers()) do
        connected[tonumber(strSrc)] = true
    end

    for src in pairs(PlayerNearBoards) do
        if not connected[src] then PlayerNearBoards[src] = nil end
    end

    for _, strSrc in ipairs(GetPlayers()) do
        local src = tonumber(strSrc)
        if src then
            local ped = GetPlayerPed(strSrc)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local nearNow = {}

                for tableId, tableCfg in pairs(TableCfgIndex) do
                    if tableCfg.coord then
                        local dx = coords.x - tableCfg.coord.x
                        local dy = coords.y - tableCfg.coord.y
                        local dz = coords.z - tableCfg.coord.z
                        if (dx * dx + dy * dy + dz * dz) <= radiusSq then
                            nearNow[tableId] = true
                        end
                    end
                end

                local wasNear = PlayerNearBoards[src] or {}

                for tableId in pairs(nearNow) do
                    if not wasNear[tableId] then
                        local tableCfg = TableCfgIndex[tableId]
                        TriggerClientEvent("chess:boardSpawn", src, serializeTableCfg(tableCfg))

                        local g = Games[tableId]
                        if g and (g.players.white or g.players.black or g.ai.white or g.ai.black) then
                            TriggerClientEvent("chess:stateSync", src, tableId, g.game, g.players)
                        end
                    end
                end

                for tableId in pairs(wasNear) do
                    if not nearNow[tableId] then
                        TriggerClientEvent("chess:boardDespawn", src, tableId)
                    end
                end

                PlayerNearBoards[src] = nearNow
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(2000)
        refreshBoardProximity()
    end
end)

local function notifyBoth(g, msg)
    if g.players.white then TriggerClientEvent("chess:notify", g.players.white, msg) end
    if g.players.black then TriggerClientEvent("chess:notify", g.players.black, msg) end
end

local function notifySide(g, side, msg)
    local src = g.players[side]
    if src then TriggerClientEvent("chess:notify", src, msg) end
end

local function endMatch(g)
    g.game = ChessEngine.NewGame()
    g.ai.white, g.ai.black = false, false
    g.lockedUntil = nil
    g.gen = (g.gen or 0) + 1
end

local applyMoveAndNotify 
local finishMoveAndNotify
local scheduleAIMove

scheduleAIMove = function(tableId)
    CreateThread(function()
        local delayMin = (Config.AI and Config.AI.thinkDelayMin) or 700
        local delayMax = (Config.AI and Config.AI.thinkDelayMax) or 2000
        Wait(math.random(delayMin, delayMax))

        local g = Games[tableId]
        if not g then return end

        local aiSide = g.game.turn
        if not g.ai[aiSide] then return end 
        if g.game.status == "checkmate" or g.game.status == "draw" then return end

        local difficulty = (Config.AI and Config.AI.difficulty) or "normal"
        local move = ChessAI.ChooseMove(g.game, aiSide, difficulty)
        if not move then return end 

        applyMoveAndNotify(tableId, g, aiSide, move.fromFile, move.fromRank, move.toFile, move.toRank, move.promotion)
    end)
end

applyMoveAndNotify = function(tableId, g, side, fromFile, fromRank, toFile, toRank, promotion)
    local result = ChessEngine.ApplyMove(g.game, fromFile, fromRank, toFile, toRank, promotion)
    if not result.ok then
        return result
    end

    local tableCfg = tableCfgById(tableId)
    local sitAnim = Config.SitAnim or {}
    local animEnabled = (Config.EnableAnimation ~= false) and tableCfg ~= nil and tableCfg.furniture and true or false

    local startDelay = animEnabled and (sitAnim.timerStartMovePiece or 0) or 0
    local totalDelay = animEnabled and (sitAnim.moveDurationMs or 0) or 0
    if totalDelay < startDelay then totalDelay = startDelay end

    g.lockedUntil = GetGameTimer() + totalDelay
    local gen = g.gen 
                       
    local moverSrc = g.players[side]
    if moverSrc and animEnabled then
        TriggerClientEvent("chess:playMoveAnim", moverSrc, tableId)
    end

    CreateThread(function()
        if startDelay > 0 then Wait(startDelay) end
        if g.gen ~= gen then return end 
        broadcastState(tableId) 

        local remaining = totalDelay - startDelay
        if remaining > 0 then Wait(remaining) end
        if g.gen ~= gen then return end

        finishMoveAndNotify(tableId, g, side, result)
    end)

    return result
end

finishMoveAndNotify = function(tableId, g, side, result)
    local otherSide = (side == "white") and "black" or "white"

    if result.captured then
        local capName = PieceNamePT[result.captured.type] or result.captured.type
        if result.enPassantCapture then
            notifySide(g, side, translate.NOTIFY_CAPTURE_EN_PASSANT)
            notifySide(g, otherSide, translate.NOTIFY_YOUR_PAWN_WAS_CAPTURED_EN_PASSANT)
        else
            notifySide(g, side, (translate.NOTIFY_YOU_CAPTURED_FROM_YOUR_OPPONENT):format(
                result.captured.color == "white" and "o" or "a",
                capName
            ))
            notifySide(g, otherSide, (translate.NOTIFY_YOUR_HAS_BEEN_CAPTURED):format(capName))
        end
    end

    if result.castle then
        local castleName = (result.castle == "king") and "pequeno" or "grande"
        notifyBoth(
            g,
            (translate.NOTIFY_MADE_THE_MOVE_ROQUE):format(
                SideNamePT[side],
                castleName
            )
        )
    end

    if result.promoted then
        local promName = PieceNamePT[result.promoted] or result.promoted
        notifySide(g, side, (translate.NOTIFY_YOUR_PAWN_HAS_BEEN_PROMOTED_TO):format(promName))
        notifySide(
            g,
            otherSide,
            (translate.NOTIFY_THE_OPPONENTS_PAWN_WAS_PROMOTED_TO):format(promName)
        )
    end

    if result.checkmate then
        notifySide(g, side, translate.NOTIFY_CHECKMATE_YOUVE_WON_THE_GAME)
        notifySide(g, otherSide, translate.NOTIFY_CHECKMATE_YOUVE_LOST_THE_GAME)
    elseif result.draw then
        local msg = DrawReasonPT[result.drawReason] or translate.NOTIFY_THE_MATCH_ENDED_IN_A_DRAM
        notifyBoth(g, msg)
    else
        if result.check then
            notifySide(g, side, translate.NOFITY_CHECK_YOU_ATTACKED_THE_OPPOSING_KING)
        end

        local turnMsg = result.check and translate.NOTIFY_CHECK_YOUR_TURN_TO_PLAY or translate.NOTIFY_YOUR_TURN_TO_PLAY
        notifySide(g, g.game.turn, turnMsg)

        if g.ai[g.game.turn] then
            scheduleAIMove(tableId)
        end
    end

    return result
end

RegisterNetEvent("chess:joinTable", function(tableId, side)
    local src = source
    if not tableCfgById(tableId) then return end
    if side ~= "white" and side ~= "black" then return end

    local g = getOrCreateGame(tableId)

    local aiActive = g.ai.white or g.ai.black
    if aiActive then
        local aiHumanSrc = g.players.white or g.players.black
        if aiHumanSrc and aiHumanSrc ~= src then
            TriggerClientEvent("chess:notify", src, translate.NOTIFY_TABLE_OCCUPIED)
            return
        end
    end

    if g.players.white and g.players.black
        and g.players.white ~= src and g.players.black ~= src then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_THIS_TABLE_OCCUPIED)
        return
    end

    if g.players[side] and g.players[side] ~= src then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_THIS_SIDE_IS_ALREADY_OCCUPIED)
        return
    end

    for _, gg in pairs(Games) do
        if gg.players.white == src then gg.players.white = nil end
        if gg.players.black == src then gg.players.black = nil end
    end

    local otherSide = (side == "white") and "black" or "white"
    local opponentAlreadySeated = g.players[otherSide] ~= nil

    g.ai[side] = false
    g.players[side] = src
    TriggerClientEvent("chess:joined", src, tableId, side)
    TriggerClientEvent("chess:aiOpponent", src, tableId, nil, false) 
    TriggerClientEvent("chess:notify", src, (translate.NOTIFY_YOU_SAT_PLAYING_):format(SideNamePT[side]))
    notifySide(g, otherSide, (translate.NOTIFY_A_PLAYER_SAT_DOWN_PLAYING_):format(SideNamePT[side]))

    broadcastState(tableId)

    if opponentAlreadySeated then
        notifyBoth(g, translate.NOTIFY_BOTH_SIDES_ARE_READY_THE_MATCH_CAN_BEGIN)
    end

    if g.game.turn == side then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_YOUR_TURN_TO_PLAY2)
    end
end)

RegisterNetEvent("chess:joinVsAI", function(tableId, humanSide)
    local src = source
    local tableCfg = tableCfgById(tableId)
    if not tableCfg then return end
    if humanSide ~= "white" and humanSide ~= "black" then return end

    local g = getOrCreateGame(tableId)
    local aiSide = (humanSide == "white") and "black" or "white"

    local aiActive = g.ai.white or g.ai.black
    local existingHumanSrc = g.players.white or g.players.black
    if aiActive and existingHumanSrc and existingHumanSrc ~= src then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_TABLE_OCCUPIED_AI)
        return
    end

    if g.players[humanSide] and g.players[humanSide] ~= src then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_THIS_SIDE_IS_ALREADY_OCCUPIED)
        return
    end
    if g.players[aiSide] then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_THIS_TABLE_OCCUPIED_)
        return
    end

    for _, gg in pairs(Games) do
        if gg.players.white == src then gg.players.white = nil end
        if gg.players.black == src then gg.players.black = nil end
    end

    endMatch(g)
    g.players.white, g.players.black = nil, nil
    g.players[humanSide] = src
    g.ai[aiSide] = true

    TriggerClientEvent("chess:joined", src, tableId, humanSide)
    TriggerClientEvent("chess:aiOpponent", src, tableId, aiSide, true)
    TriggerClientEvent("chess:notify", src, (translate.NOTIFY_MATCH_AI):format(SideNamePT[humanSide]))

    broadcastState(tableId)

    if g.game.turn == humanSide then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_YOUR_TURN_TO_PLAY)
    else
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_THE_AI_WILL_PLAY)
        scheduleAIMove(tableId)
    end
end)

RegisterNetEvent("chess:leaveTable", function(tableId)
    local src = source
    local g = Games[tableId]
    if not g then return end

    local side = nil
    if g.players.white == src then side = "white"; g.players.white = nil end
    if g.players.black == src then side = "black"; g.players.black = nil end
    if not side then return end 

    local hadAI = g.ai.white or g.ai.black
    local otherSide = (side == "white") and "black" or "white"
    local otherSrc = g.players[otherSide]

    endMatch(g)

    TriggerClientEvent("chess:left", src, tableId)
    TriggerClientEvent("chess:aiOpponent", src, tableId, nil, false)
    TriggerClientEvent("chess:notify", src, translate.NOTIFY_YOU_LEFT_THE_TABLE)

    if otherSrc and not hadAI then
        notifySide(g, otherSide, translate.NOTIFY_YOUR_OPPONENT_LEFT_THE_TABLE)
    end

    broadcastState(tableId)
end)

RegisterNetEvent("chess:requestMove", function(tableId, fromFile, fromRank, toFile, toRank, promotion)
    local src = source
    local g = Games[tableId]
    if not g then return end

    local side = nil
    if g.players.white == src then side = "white" end
    if g.players.black == src then side = "black" end
    if not side then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_YOU_ARE_NOT_SITTING)
        return
    end

    if g.game.turn ~= side then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_ITS_NOT_YOUR_TURN)
        return
    end

    if g.lockedUntil and GetGameTimer() < g.lockedUntil then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_PLEASE_WAIT_FOR_THE_PREV_BID_TO_FINISHI)
        return
    end

    local result = applyMoveAndNotify(tableId, g, side, fromFile, fromRank, toFile, toRank, promotion)
    if not result.ok then
        local msg = translate.NOTIFY_INVALID_MOVE
        if result.error == "game_over" then msg = translate.NOTIFY_THE_MATCH_HAS_ENDED end
        if result.error == "not_your_turn" then msg = translate.NOTIFY_ITS_NOT_YOUR_TURN end
        if result.error == "no_piece" then msg = translate.NOTIFY_THERE_IS_NO_PIECE_IN_THIS_HOUSE end
        if result.error == "illegal_move" then msg = translate.NOTIFY_THIS_MOVE_IS_NOT_ALLOWED_BY_THE_RULES end
        TriggerClientEvent("chess:notify", src, msg)
    end
end)

RegisterNetEvent("chess:requestLegalMoves", function(tableId, file, rank)
    local src = source
    local g = Games[tableId]
    if not g then return end

    local side = nil
    if g.players.white == src then side = "white" end
    if g.players.black == src then side = "black" end
    if not side then return end

    local piece = g.game.board[rank] and g.game.board[rank][file]
    if not piece or piece.color ~= side then
        TriggerClientEvent("chess:legalMoves", src, tableId, file, rank, {})
        return
    end

    if g.game.turn ~= side then
        TriggerClientEvent("chess:legalMoves", src, tableId, file, rank, {})
        return
    end

    local moves = ChessEngine.LegalMoves(g.game, file, rank)
    TriggerClientEvent("chess:legalMoves", src, tableId, file, rank, moves)
end)

RegisterNetEvent("chess:requestState", function(tableId)
    local src = source
    local g = getOrCreateGame(tableId)
    TriggerClientEvent("chess:stateSync", src, tableId, g.game, g.players)
end)

AddEventHandler("playerDropped", function()
    local src = source
    PlayerNearBoards[src] = nil
    for tableId, g in pairs(Games) do
        local side = nil
        if g.players.white == src then side = "white"; g.players.white = nil end
        if g.players.black == src then side = "black"; g.players.black = nil end

        if side then
            local hadAI = g.ai.white or g.ai.black
            local otherSide = (side == "white") and "black" or "white"
            local otherSrc = g.players[otherSide]

            endMatch(g)

            if otherSrc and not hadAI then
                notifySide(g, otherSide, translate.NOTIFY_YOUR_OPPONENT_DISCONNECT)
            end

            broadcastState(tableId)
        end
    end
end)

RegisterNetEvent("chess:resetTable", function(tableId)
    local src = source
    local g = Games[tableId]
    if not g then return end
    if g.players.white ~= src and g.players.black ~= src then return end
    g.game = ChessEngine.NewGame()
    g.lockedUntil = nil
    g.gen = (g.gen or 0) + 1
    broadcastState(tableId)
    notifySide(g, "white", translate.NOTIFY__THE_GAME_HAS_RESTART)
    notifySide(g, "black", translate.NOTIFY__THE_GAME_HAS_RESTART)

    if g.ai[g.game.turn] then
        scheduleAIMove(tableId)
    end
end)

local RuntimeBoards = {}

local function serializeTableCfgImpl(tableCfg)
    return {
        id = tableCfg.id,
        coord = { x = tableCfg.coord.x, y = tableCfg.coord.y, z = tableCfg.coord.z },
        heading = tableCfg.heading,
        zoneRadius = tableCfg.zoneRadius,
        tableProp = tableCfg.tableProp,
        furniture = tableCfg.furniture,
        isRuntime = tableCfg.isRuntime and true or false,
    }
end
serializeTableCfg = serializeTableCfgImpl

local function nextBoardNumber()
    local max = 0
    for _, t in ipairs(Config.Tables) do
        local n = tonumber(string.match(t.id or "", "^mesa_(%d+)$"))
        if n and n > max then max = n end
    end
    return max + 1
end

CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS chess_boards (
            id VARCHAR(64) NOT NULL PRIMARY KEY,
            x FLOAT NOT NULL,
            y FLOAT NOT NULL,
            z FLOAT NOT NULL,
            heading FLOAT NOT NULL,
            furniture TINYINT(1) NOT NULL DEFAULT 0
        )
    ]], {})

    exports.oxmysql:query("SELECT * FROM chess_boards", {}, function(rows)
        rows = rows or {}
        for _, row in ipairs(rows) do
            local tableCfg = {
                id = row.id,
                coord = vector3(row.x, row.y, row.z),
                heading = row.heading,
                zoneRadius = 3.0,
                tableProp = `bzzz_chess_board_a`,
                furniture = (row.furniture == 1 or row.furniture == true),
                isRuntime = true, 
            }
            Config.ResolveBoardOrigin(tableCfg)
            table.insert(Config.Tables, tableCfg)
            TableCfgIndex[tableCfg.id] = tableCfg
            table.insert(RuntimeBoards, tableCfg)
        end

        if #rows > 0 then
            for _, tableCfg in ipairs(RuntimeBoards) do
                TriggerClientEvent("chess:boardAdded", -1, serializeTableCfg(tableCfg))
            end
        end
    end)
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local src = source
    for _, tableCfg in ipairs(RuntimeBoards) do
        TriggerClientEvent("chess:boardAdded", src, serializeTableCfg(tableCfg))
    end
end)

RegisterNetEvent("chess:addBoard", function(coord, heading, furniture)
    local src = source

    local id = "mesa_" .. tostring(nextBoardNumber())
    local tableCfg = {
        id = id,
        coord = vector3(coord.x, coord.y, coord.z),
        heading = heading,
        zoneRadius = 3.0,
        tableProp = `bzzz_chess_board_a`,
        furniture = furniture and true or false,
        isRuntime = true, 
    }

    Config.ResolveBoardOrigin(tableCfg)
    table.insert(Config.Tables, tableCfg)
    TableCfgIndex[id] = tableCfg
    table.insert(RuntimeBoards, tableCfg)

    exports.oxmysql:insert(
        "INSERT INTO chess_boards (id, x, y, z, heading, furniture) VALUES (?, ?, ?, ?, ?, ?)",
        { tableCfg.id, tableCfg.coord.x, tableCfg.coord.y, tableCfg.coord.z, tableCfg.heading, tableCfg.furniture and 1 or 0 }
    )

    TriggerClientEvent("chess:boardAdded", -1, serializeTableCfg(tableCfg))

    TriggerClientEvent("chess:notify", src, (translate.NOTIFY_TABLE_CREATED):format(id, tostring(tableCfg.furniture)))
end)

RegisterNetEvent("chess:removeBoard", function(tableId)
    local src = source
    local tableCfg = TableCfgIndex[tableId]
    if not tableCfg then return end

    if not tableCfg.isRuntime then
        TriggerClientEvent("chess:notify", src, translate.NOTIFY_THIS_TABLE_IS_FIXED)
        return
    end

    local g = Games[tableId]
    if g then
        notifyBoth(g, (translate.NOTIFY_TABLE_HAS_BEEN_REMOVED):format(tableId))
        Games[tableId] = nil
    end

    TableCfgIndex[tableId] = nil
    for i = #Config.Tables, 1, -1 do
        if Config.Tables[i].id == tableId then
            table.remove(Config.Tables, i)
            break
        end
    end
    for i = #RuntimeBoards, 1, -1 do
        if RuntimeBoards[i].id == tableId then
            table.remove(RuntimeBoards, i)
            break
        end
    end

    exports.oxmysql:execute("DELETE FROM chess_boards WHERE id = ?", { tableId })

    TriggerClientEvent("chess:boardRemoved", -1, tableId)
end)

RegisterCommand("chess_cam_offset", function(src, args)
    TriggerClientEvent("chess:staffcmd_cam_offset", src, args)
end, true)

RegisterCommand("chess_cam_pitch", function(src, args)
    TriggerClientEvent("chess:staffcmd_cam_pitch", src, args)
end, true)

RegisterCommand("chess_cam_fov", function(src, args)
    TriggerClientEvent("chess:staffcmd_cam_fov", src, args)
end, true)

RegisterCommand("addboard", function(src, args)
    TriggerClientEvent("chess:staffcmd_addboard", src, args)
end, true)

RegisterCommand("addboardInfo", function(src, args)
    TriggerClientEvent("chess:staffcmd_addboard", src, args, true)
end, true)

RegisterCommand("chess_rotate", function(src, args)
    TriggerClientEvent("chess:staffcmd_rotate", src, args)
end, true)

RegisterCommand("chess_flipfile", function(src, args)
    TriggerClientEvent("chess:staffcmd_flipfile", src, args)
end, true)

RegisterCommand("chess_fliprank", function(src, args)
    TriggerClientEvent("chess:staffcmd_fliprank", src, args)
end, true)

RegisterCommand("chess_calibrate", function(src, args)
    TriggerClientEvent("chess:staffcmd_calibrate", src, args)
end, true)
