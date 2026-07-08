Config = {
    pedInvisible = false,
    ChairProp = `bzzz_chess_chair_a`,
    FurnitureTableProp = `bzzz_chess_table_a`,

    PieceModels = {
        white = {
            king   = `bzzz_chess_color_a6`,
            queen  = `bzzz_chess_color_a5`,
            rook   = `bzzz_chess_color_a2`,
            bishop = `bzzz_chess_color_a4`,
            knight = `bzzz_chess_color_a3`,
            pawn   = `bzzz_chess_color_a1`,
        },
        black = {
            king   = `bzzz_chess_color_b6`,
            queen  = `bzzz_chess_color_b5`,
            rook   = `bzzz_chess_color_b2`,
            bishop = `bzzz_chess_color_b4`,
            knight = `bzzz_chess_color_b3`,
            pawn   = `bzzz_chess_color_b1`,
        }
    },

    SpectatorRadius = 30.0,
    BoardSpawnRadius = 30.0,

    Tables = {
        {  
            id = "mesa_1",
            zoneRadius = 3.0,
            tableProp = `bzzz_chess_board_a`,

            coord = vec3(-782.07, 5570.12, 32.49),
            heading = 179.38,
            furniture = true,
            -- furniture = { 
            --     boardOffset = vector3(0.0, 0.0, 0.0), 
            --     boardRotationOffset = 0.0,
            --     tableProp = `bzzz_chess_table_a`,
            --     tableOffset = vector3(0.0, 0.0, -0.95),
            --     tableRotationOffset = 0.0,
            --     chairProp = `bzzz_chess_chair_a`,
            --     chairOffsetWhite = vector3(0.0, -0.55, -0.95),
            --     chairRotationOffsetWhite = 0.0,
            --     chairOffsetBlack = vector3(0.0, 0.55, -0.95),
            --     chairRotationOffsetBlack = 180.0,
            -- },
        },

        {  
            id = "mesa_2",
            zoneRadius = 3.0,
            tableProp = `bzzz_chess_board_a`,

            coord = vec3(-779.74, 5570.25, 32.49),
            heading = 358.74,
            furniture = true,
        },

        {  
            id = "mesa_3",
            zoneRadius = 3.0,
            tableProp = `bzzz_chess_board_a`,

            coord = vec3(-778.71, 5574.40, 32.49),
            heading = 2.61,
            furniture = false,
        },

        {  
            id = "mesa_4",
            zoneRadius = 3.0,
            tableProp = `bzzz_chess_board_a`,

            coord = vec3(-779.05, 5577.08, 32.49),
            heading = 266.52,
            furniture = false,
        },
    },

    CameraSides = {
        white = {
            offset = vector3(-0.0, -0.31, 0.41), 
            pitch = -0.0,
            fov = 60.0,
        },
        black = {
            offset = vector3(-0.0, 0.31, 0.41), 
            pitch = -35.0,
            fov = 60.0,
        },
    },
    CameraLookAtLocal = vector3(-0.0, 0.0, 0.0),

    SitAnim = {
        dict = "bzzz_chess_animations",
        idle = "bzzz_chess_sit_a",  
        move = "bzzz_chess_sit_b",  
        timerStartMovePiece = 2450,
        moveDurationMs = 1000,
    },

    EnableAnimation = true,
    FloorSitAnims = {
        { dict = "anim@amb@business@bgen@bgen_no_work@", anim = "sit_phone_phoneputdown_idle_nowork", offset = vector3(0.0, -0.5, 0.0) },
        { dict = "rcm_barry3", anim = "barry_3_sit_loop", offset = vector3(0.0, -0.6, 0.0) },
        { dict = "amb@world_human_picnic@female@idle_a", anim = "idle_a", offset = vector3(0.0, -0.3, 0.0) },
        { dict = "anim@heists@fleeca_bank@ig_7_jetski_owner", anim = "owner_idle", offset = vector3(0.0, -0.6, 0.0) },
        { dict = "sitonground1@sharror", anim = "sitonground1_clip", offset = vector3(0.0, -0.5, 0.0) },
    },

    SquareSize = 0.060,
    BoardOrigin = vector3(-0.21, -0.21, 0.02),
    PieceZOffset = 0.0,

    FurnitureDefaults = {
        board = {
            offset = vector3(0.0, 0.0, 0.8), 
            rotationOffset = 0.0,
        },
        table = {
            offset = vector3(0.0, 0.0, -0.0), 
            rotationOffset = 0.0,
        },
        chairWhite = {
            offset = vector3(0.0, -0.55, -0.0), 
            rotationOffset = 0.0,
        },
        chairBlack = {
            offset = vector3(0.0, 0.55, -0.0), 
            rotationOffset = 180.0,
        },
    },

    ExtraRotation = -0.0,
    FlipFile = false,
    FlipRank = false,

    AI = {
        pedModel = `a_m_y_business_03`, -- Não usado
        scenario = "WORLD_HUMAN_STAND_IMPATIENT",  -- Não usado
        thinkDelayMin = 700,  -- ms mínimo de "pensamento" antes da IA jogar (só estética)
        thinkDelayMax = 2200, -- ms máximo
        difficulty = "easy", -- "easy" ou "normal" (Melhor porem pesado, muito pesado, use o EASY sempre)
    },

    -- Não usado
    PedSides = {
        white = { offset = vector3(0.0, -0.55, -0.0) },
        black = { offset = vector3(0.0, 0.55, -0.0) },
    },
}

translate = {
    PAWN = "Pawn",
    KNIGHT = "Knight",
    BISHOP = "Bishop",
    ROOK = "Rook",
    QUEEN = "Queen",
    KING = "King",

    WHITE = "White",
    BLACK = "Black",

    FIFTY_MOVE = "Draw by the fifty-move rule with no pawn movement or capture.",
    INSUFFICIENT_MATERIAL = "Draw due to insufficient material to deliver checkmate.",
    THREEFOLD_REPETITION = "Draw by threefold repetition of the same position.",
    STALEMATE = "Draw by stalemate (the king is not in check, but no legal moves are available).",

    GET_UP_FROM_THE_CHAR_CHESS = "Get up from the chair (Chess)",

    TARGET_PLAY_WHITE = "Play as White",
    TARGET_PLAY_BLACK = "Play as Black",
    TARGET_LEAVE_THE_TABLE = "Leave the table",
    TARGET_PLAYING_IA_IN_WHITE = "Play vs AI (White)",
    TARGET_PLAYING_IA_IN_BLACK = "Play vs AI (Black)",
    TARGET_RESTART_MATCH = "Restart match",
    TARGET_READJUST_CAMERA = "Readjust camera",
    TARGET_REMOVE_TABLE = "Remove table",
    TARGET_TO_SIT = "Sit",

    TEXT3D_COMMANDS = "[E] Confirm position   |   [BACKSPACE] Cancel   |   Mouse wheel: rotate",

    NOTIFY_THERE_IS_ALREADY_A_TABLE_POSITIONING_PROCESS = "A table placement process is already in progress.",
    NOTIFY_CAMERA_READJUSTED = "Camera readjusted.",
    NOTIFY_TABLE_INFO_CAPTURED_VIEW_THE_INFO_BY_F8 = "Table information captured! Check the info in F8!",
    NOTIFY_TABLE_PLACEMENT_CANCELLED = "Table placement cancelled.",
    NOTIFY_USE_ADDBOARD = "use: /addboard 1 (no furniture) or /addboard 2 (with furniture)",
    NOTIFY_TABLEID_REMOVED = "Table %s removed.",

    NOTIFY_YOU_ARE_WATCHING_THE_GAME_AT_TABLE = "You are watching the game at table %s.",
    NOTIFY_CAPTURE_EN_PASSANT = "En passant capture! You captured a Pawn.",
    NOTIFY_YOUR_PAWN_WAS_CAPTURED_EN_PASSANT = "Your pawn was captured en passant.",
    NOTIFY_YOU_CAPTURED_FROM_YOUR_OPPONENT = "You captured %s %s from your opponent!",
    NOTIFY_YOUR_HAS_BEEN_CAPTURED = "Your %s has been captured!",
    NOTIFY_MADE_THE_MOVE_ROQUE = "%s performed castling %s.",
    NOTIFY_YOUR_PAWN_HAS_BEEN_PROMOTED_TO = "Your pawn has been promoted to %s!",
    NOTIFY_THE_OPPONENTS_PAWN_WAS_PROMOTED_TO = "The opponent's pawn was promoted to %s!",
    NOTIFY_CHECKMATE_YOUVE_WON_THE_GAME = "Checkmate! You’ve won the game.",
    NOTIFY_CHECKMATE_YOUVE_LOST_THE_GAME = "Checkmate! You’ve lost the game.",
    NOTIFY_THE_MATCH_ENDED_IN_A_DRAM = "The match ended in a draw.",
    NOFITY_CHECK_YOU_ATTACKED_THE_OPPOSING_KING = "Check! You attacked the opposing king.",
    NOTIFY_CHECK_YOUR_TURN_TO_PLAY = "Check! Your turn to play.",
    NOTIFY_YOUR_TURN_TO_PLAY = "Your turn to play",
    NOTIFY_TABLE_OCCUPIED = "Table occupied (AI match in progress).",
    NOTIFY_THIS_TABLE_OCCUPIED = "Table occupied. Choose another table.",
    NOTIFY_THIS_SIDE_IS_ALREADY_OCCUPIED = "That side is already occupied.",
    NOTIFY_YOU_SAT_PLAYING_ = "You sat playing as %s.",
    NOTIFY_A_PLAYER_SAT_DOWN_PLAYING_ = "A player sat down playing as %s.",
    NOTIFY_BOTH_SIDES_ARE_READY_THE_MATCH_CAN_BEGIN = "Both sides are ready! The match can begin.",
    NOTIFY_YOUR_TURN_TO_PLAY2 = "Your turn to play.",
    NOTIFY_TABLE_OCCUPIED_AI = "Table occupied (AI match in progress)",
    NOTIFY_THIS_TABLE_OCCUPIED_ = "This table already has another player. Choose another one.",
    NOTIFY_MATCH_AI = "AI match started. You are %s.",
    NOTIFY_THE_AI_WILL_PLAY = "The AI will play first. Please wait.",
    NOTIFY_YOU_LEFT_THE_TABLE = "You left the table.",
    NOTIFY_YOUR_OPPONENT_LEFT_THE_TABLE = "Your opponent left the table. The match has ended and the board has been reset.",
    NOTIFY_YOU_ARE_NOT_SITTING = "You are not sitting at this table.",
    NOTIFY_ITS_NOT_YOUR_TURN = "It’s not your turn.",
    NOTIFY_PLEASE_WAIT_FOR_THE_PREV_BID_TO_FINISHI = "Please wait for the previous move to finish.",
    NOTIFY_INVALID_MOVE = "Invalid move.",
    NOTIFY_THE_MATCH_HAS_ENDED = "The match has already ended. Restart to play again.",
    NOTIFY_THERE_IS_NO_PIECE_IN_THIS_HOUSE = "There is no piece on this square.",
    NOTIFY_THIS_MOVE_IS_NOT_ALLOWED_BY_THE_RULES = "This move is not allowed by chess rules.",
    NOTIFY_YOUR_OPPONENT_DISCONNECT = "Your opponent disconnected. The match has ended and the board has been reset.",
    NOTIFY__THE_GAME_HAS_RESTART = "Match restarted. Your turn to play.",
    NOTIFY_TABLE_CREATED = "Table %s created (furniture = %s).",
    NOTIFY_THIS_TABLE_IS_FIXED = "This table is fixed (config.lua) and cannot be removed.",
    NOTIFY_TABLE_HAS_BEEN_REMOVED = "Table %s has been removed. The match has ended.",
}   

local function rotateOffset(x, y, heading)
    local totalHeading = heading + Config.ExtraRotation
    local rad = totalHeading * math.pi / 180.0
    local cos_ = math.cos(rad)
    local sin_ = math.sin(rad)
    local rx = x * cos_ - y * sin_
    local ry = x * sin_ + y * cos_
    return rx, ry
end

function Config.GetSquareCoord(tableCfg, file, rank)
    local f = Config.FlipFile and (9 - file) or file
    local r = Config.FlipRank and (9 - rank) or rank

    local localX = Config.BoardOrigin.x + (f - 1) * Config.SquareSize
    local localY = Config.BoardOrigin.y + (r - 1) * Config.SquareSize

    local boardCoord = tableCfg._boardCoord or tableCfg.coord
    local boardHeading = tableCfg._boardHeading or tableCfg.heading
    local rx, ry = rotateOffset(localX, localY, boardHeading)

    return vector3(
        boardCoord.x + rx,
        boardCoord.y + ry,
        boardCoord.z + Config.BoardOrigin.z + Config.PieceZOffset
    )
end

function Config.GetCameraCoord(tableCfg, side)
    local cfg = Config.CameraSides[side]
    if not cfg then return nil end

    local boardCoord = tableCfg._boardCoord or tableCfg.coord
    local boardHeading = tableCfg._boardHeading or tableCfg.heading
    local totalHeading = boardHeading + Config.ExtraRotation
    local rad = totalHeading * math.pi / 180.0
    local cos_ = math.cos(rad)
    local sin_ = math.sin(rad)
    local rx = cfg.offset.x * cos_ - cfg.offset.y * sin_
    local ry = cfg.offset.x * sin_ + cfg.offset.y * cos_

    return vector3(
        boardCoord.x + rx,
        boardCoord.y + ry,
        boardCoord.z + cfg.offset.z
    )
end

function Config.GetCameraLookAt(tableCfg)
    local boardCoord = tableCfg._boardCoord or tableCfg.coord
    local boardHeading = tableCfg._boardHeading or tableCfg.heading
    local totalHeading = boardHeading + Config.ExtraRotation
    local rad = totalHeading * math.pi / 180.0
    local cos_ = math.cos(rad)
    local sin_ = math.sin(rad)
    local lx, ly = Config.CameraLookAtLocal.x, Config.CameraLookAtLocal.y
    local rx = lx * cos_ - ly * sin_
    local ry = lx * sin_ + ly * cos_

    return vector3(
        boardCoord.x + rx,
        boardCoord.y + ry,
        boardCoord.z + Config.CameraLookAtLocal.z
    )
end

function Config.WorldToSquare(tableCfg, worldCoord)
    local boardCoord = tableCfg._boardCoord or tableCfg.coord
    local boardHeading = tableCfg._boardHeading or tableCfg.heading
    local dx = worldCoord.x - boardCoord.x
    local dy = worldCoord.y - boardCoord.y

    local totalHeading = boardHeading + Config.ExtraRotation
    local rad = -totalHeading * math.pi / 180.0
    local cos_ = math.cos(rad)
    local sin_ = math.sin(rad)
    local localX = dx * cos_ - dy * sin_
    local localY = dx * sin_ + dy * cos_

    local file = math.floor(((localX - Config.BoardOrigin.x) / Config.SquareSize) + 0.5) + 1
    local rank = math.floor(((localY - Config.BoardOrigin.y) / Config.SquareSize) + 0.5) + 1

    if Config.FlipFile then file = 9 - file end
    if Config.FlipRank then rank = 9 - rank end

    if file < 1 or file > 8 or rank < 1 or rank > 8 then return nil end
    return file, rank
end

function Config.GetPedCoord(tableCfg, side)
    local cfg = Config.PedSides[side]
    if not cfg then return nil end

    local boardCoord = tableCfg._boardCoord or tableCfg.coord
    local boardHeading = tableCfg._boardHeading or tableCfg.heading
    local totalHeading = boardHeading + Config.ExtraRotation
    local rad = totalHeading * math.pi / 180.0
    local cos_ = math.cos(rad)
    local sin_ = math.sin(rad)
    local rx = cfg.offset.x * cos_ - cfg.offset.y * sin_
    local ry = cfg.offset.x * sin_ + cfg.offset.y * cos_

    return vector3(
        boardCoord.x + rx,
        boardCoord.y + ry,
        boardCoord.z + (cfg.offset.z or 0.0)
    )
end

function Config.GetPedHeading(tableCfg, side)
    local pedCoord = Config.GetPedCoord(tableCfg, side)
    if not pedCoord then return tableCfg._boardHeading or tableCfg.heading end

    local lookAt = Config.GetCameraLookAt(tableCfg)
    local dx, dy = lookAt.x - pedCoord.x, lookAt.y - pedCoord.y
    return math.atan(dy, dx) * 180.0 / math.pi
end

function Config.GetFacingHeadingToBoard(tableCfg, fromCoord)
    local lookAt = Config.GetCameraLookAt(tableCfg)
    local dx, dy = lookAt.x - fromCoord.x, lookAt.y - fromCoord.y
    return math.atan(dy, dx) * 180.0 / math.pi
end

function Config.GetFurnitureWorldCoord(tableCfg, offset)
    local rad = tableCfg.heading * math.pi / 180.0
    local cos_ = math.cos(rad)
    local sin_ = math.sin(rad)
    local rx = offset.x * cos_ - offset.y * sin_
    local ry = offset.x * sin_ + offset.y * cos_

    return vector3(
        tableCfg.coord.x + rx,
        tableCfg.coord.y + ry,
        tableCfg.coord.z + offset.z
    )
end

function Config.GetFurnitureConfig(tableCfg)
    if not tableCfg.furniture then return nil end

    local f = type(tableCfg.furniture) == "table" and tableCfg.furniture or {}
    local d = Config.FurnitureDefaults

    return {
        boardOffset = f.boardOffset or d.board.offset,
        boardRotationOffset = f.boardRotationOffset or d.board.rotationOffset,

        tableProp = f.tableProp or Config.FurnitureTableProp,
        tableOffset = f.tableOffset or d.table.offset,
        tableRotationOffset = f.tableRotationOffset or d.table.rotationOffset,

        chairProp = f.chairProp or Config.ChairProp,
        chairOffsetWhite = f.chairOffsetWhite or d.chairWhite.offset,
        chairRotationOffsetWhite = f.chairRotationOffsetWhite or d.chairWhite.rotationOffset,
        chairOffsetBlack = f.chairOffsetBlack or d.chairBlack.offset,
        chairRotationOffsetBlack = f.chairRotationOffsetBlack or d.chairBlack.rotationOffset,
    }
end

function Config.ResolveBoardOrigin(tableCfg)
    local furn = Config.GetFurnitureConfig(tableCfg)
    if not furn then
        tableCfg._boardCoord = tableCfg.coord
        tableCfg._boardHeading = tableCfg.heading
        return
    end

    tableCfg._boardCoord = Config.GetFurnitureWorldCoord(tableCfg, furn.boardOffset)
    tableCfg._boardHeading = tableCfg.heading + furn.boardRotationOffset
end

for _, tableCfg in ipairs(Config.Tables) do
    Config.ResolveBoardOrigin(tableCfg)
end
