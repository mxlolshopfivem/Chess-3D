ChessEngine = {}

local function cloneBoard(board)
    local copy = {}
    for r = 1, 8 do
        copy[r] = {}
        for f = 1, 8 do
            local p = board[r][f]
            if p then
                copy[r][f] = { color = p.color, type = p.type, moved = p.moved }
            end
        end
    end
    return copy
end

function ChessEngine.NewGame()
    local board = {}
    for r = 1, 8 do board[r] = {} end

    local backRank = { "rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook" }
    for f = 1, 8 do
        board[1][f] = { color = "white", type = backRank[f], moved = false }
        board[2][f] = { color = "white", type = "pawn", moved = false }
        board[7][f] = { color = "black", type = "pawn", moved = false }
        board[8][f] = { color = "black", type = backRank[f], moved = false }
    end

    return {
        board = board,
        turn = "white",
        enPassant = nil, 
        halfmoveClock = 0,
        fullmove = 1,
        status = "playing", 
        drawReason = nil,   
        history = {},
        positionCounts = {}, 
    }
end

local function inBounds(f, r)
    return f >= 1 and f <= 8 and r >= 1 and r <= 8
end

local function opponent(color)
    return color == "white" and "black" or "white"
end

local function pseudoMoves(state, file, rank)
    local board = state.board
    local piece = board[rank][file]
    if not piece then return {} end

    local moves = {}
    local color = piece.color

    local function tryAdd(f, r, onlyCapture, onlyMove)
        if not inBounds(f, r) then return false end
        local target = board[r][f]
        if not target then
            if not onlyCapture then
                table.insert(moves, { file = f, rank = r })
            end
            return true 
        elseif target.color ~= color then
            if not onlyMove then
                table.insert(moves, { file = f, rank = r, capture = true })
            end
            return false 
        else
            return false 
        end
    end

    if piece.type == "pawn" then
        local dir = (color == "white") and 1 or -1
        local startRank = (color == "white") and 2 or 7
        if inBounds(file, rank + dir) and not board[rank + dir][file] then
            table.insert(moves, { file = file, rank = rank + dir })
            if rank == startRank and not board[rank + dir * 2][file] then
                table.insert(moves, { file = file, rank = rank + dir * 2, doubleStep = true })
            end
        end

        for _, df in ipairs({ -1, 1 }) do
            local nf, nr = file + df, rank + dir
            if inBounds(nf, nr) then
                local target = board[nr][nf]
                if target and target.color ~= color then
                    table.insert(moves, { file = nf, rank = nr, capture = true })
                elseif state.enPassant and state.enPassant.file == nf and state.enPassant.rank == nr then
                    table.insert(moves, { file = nf, rank = nr, capture = true, enPassant = true })
                end
            end
        end

    elseif piece.type == "knight" then
        local deltas = {
            {1,2},{2,1},{2,-1},{1,-2},{-1,-2},{-2,-1},{-2,1},{-1,2}
        }
        for _, d in ipairs(deltas) do
            tryAdd(file + d[1], rank + d[2])
        end

    elseif piece.type == "bishop" or piece.type == "rook" or piece.type == "queen" then
        local dirs = {}
        if piece.type == "bishop" or piece.type == "queen" then
            for _, d in ipairs({{1,1},{1,-1},{-1,1},{-1,-1}}) do table.insert(dirs, d) end
        end
        if piece.type == "rook" or piece.type == "queen" then
            for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do table.insert(dirs, d) end
        end
        for _, d in ipairs(dirs) do
            local f, r = file + d[1], rank + d[2]
            while inBounds(f, r) do
                local cont = tryAdd(f, r)
                if not cont then break end
                f = f + d[1]
                r = r + d[2]
            end
        end

    elseif piece.type == "king" then
        for df = -1, 1 do
            for dr = -1, 1 do
                if df ~= 0 or dr ~= 0 then
                    tryAdd(file + df, rank + dr)
                end
            end
        end

        if not piece.moved then
            local r = rank
            local rookKing = board[r][8]
            if rookKing and rookKing.type == "rook" and not rookKing.moved
                and not board[r][6] and not board[r][7] then
                table.insert(moves, { file = file + 2, rank = r, castle = "king" })
            end

            local rookQueen = board[r][1]
            if rookQueen and rookQueen.type == "rook" and not rookQueen.moved
                and not board[r][2] and not board[r][3] and not board[r][4] then
                table.insert(moves, { file = file - 2, rank = r, castle = "queen" })
            end
        end
    end

    return moves
end

function ChessEngine.IsSquareAttacked(state, file, rank, byColor)
    local board = state.board
    for r = 1, 8 do
        for f = 1, 8 do
            local p = board[r][f]
            if p and p.color == byColor then
                if p.type == "pawn" then
                    local dir = (p.color == "white") and 1 or -1
                    if rank == r + dir and (file == f - 1 or file == f + 1) then
                        return true
                    end
                else
                    local moves = pseudoMoves(state, f, r)
                    for _, m in ipairs(moves) do
                        if m.file == file and m.rank == rank and not m.castle then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function findKing(state, color)
    for r = 1, 8 do
        for f = 1, 8 do
            local p = state.board[r][f]
            if p and p.color == color and p.type == "king" then
                return f, r
            end
        end
    end
    return nil
end

function ChessEngine.IsInCheck(state, color)
    local kf, kr = findKing(state, color)
    if not kf then return false end
    return ChessEngine.IsSquareAttacked(state, kf, kr, opponent(color))
end

local function leavesKingInCheck(state, fromFile, fromRank, move)
    local boardCopy = cloneBoard(state.board)
    local fakeState = { board = boardCopy, enPassant = state.enPassant }

    local piece = boardCopy[fromRank][fromFile]
    boardCopy[fromRank][fromFile] = nil
    if move.enPassant then
        boardCopy[fromRank][move.file] = nil 
    end
    boardCopy[move.rank][move.file] = piece

    if move.castle then
    end

    return ChessEngine.IsInCheck(fakeState, piece.color)
end

function ChessEngine.LegalMoves(state, file, rank)
    local piece = state.board[rank][file]
    if not piece or piece.color ~= state.turn then return {} end

    local moves = pseudoMoves(state, file, rank)
    local legal = {}

    for _, m in ipairs(moves) do
        local ok = true

        if m.castle then
            local color = piece.color
            local dir = (m.castle == "king") and 1 or -1
            if ChessEngine.IsInCheck(state, color) then
                ok = false
            else
                for step = 1, 2 do
                    local checkFile = file + dir * step
                    if ChessEngine.IsSquareAttacked(state, checkFile, rank, opponent(color)) then
                        ok = false
                        break
                    end
                end
            end
        end

        if ok and leavesKingInCheck(state, file, rank, m) then
            ok = false
        end

        if ok then
            table.insert(legal, m)
        end
    end

    return legal
end

local function positionKey(state)
    local board = state.board
    local parts = {}
    for r = 1, 8 do
        for f = 1, 8 do
            local p = board[r][f]
            if p then
                table.insert(parts, f .. r .. p.color:sub(1,1) .. p.type:sub(1,1))
            end
        end
    end
    table.sort(parts)

    local rights = {}
    for _, c in ipairs({ "white", "black" }) do
        local rank = (c == "white") and 1 or 8
        local king = board[rank][5]
        local rookK = board[rank][8]
        local rookQ = board[rank][1]
        local kingUnmoved = king and king.type == "king" and not king.moved
        rights[#rights+1] = (kingUnmoved and rookK and rookK.type == "rook" and not rookK.moved) and "K" .. c:sub(1,1) or ""
        rights[#rights+1] = (kingUnmoved and rookQ and rookQ.type == "rook" and not rookQ.moved) and "Q" .. c:sub(1,1) or ""
    end

    local ep = state.enPassant and (state.enPassant.file .. "_" .. state.enPassant.rank) or "-"

    return table.concat(parts, ",") .. "|" .. state.turn .. "|" .. table.concat(rights, "") .. "|" .. ep
end

function ChessEngine.IsInsufficientMaterial(state)
    local board = state.board
    local pieces = {}
    for r = 1, 8 do
        for f = 1, 8 do
            local p = board[r][f]
            if p and p.type ~= "king" then
                table.insert(pieces, { color = p.color, type = p.type, file = f, rank = r })
            end
        end
    end

    if #pieces == 0 then return true end 

    if #pieces == 1 then
        local t = pieces[1].type
        return t == "bishop" or t == "knight" 
    end

    if #pieces == 2 and pieces[1].type == "bishop" and pieces[2].type == "bishop"
        and pieces[1].color ~= pieces[2].color then
        local color1 = (pieces[1].file + pieces[1].rank) % 2
        local color2 = (pieces[2].file + pieces[2].rank) % 2
        return color1 == color2
    end

    return false
end

function ChessEngine.ApplyMove(state, fromFile, fromRank, toFile, toRank, promotion)
    local board = state.board
    local piece = board[fromRank][fromFile]
    if not piece then return { ok = false, error = "no_piece" } end
    if piece.color ~= state.turn then return { ok = false, error = "not_your_turn" } end
    if state.status == "checkmate" or state.status == "draw" then return { ok = false, error = "game_over" } end

    local legal = ChessEngine.LegalMoves(state, fromFile, fromRank)
    local chosen = nil
    for _, m in ipairs(legal) do
        if m.file == toFile and m.rank == toRank then
            chosen = m
            break
        end
    end
    if not chosen then return { ok = false, error = "illegal_move" } end

    local captured = nil
    if chosen.capture then
        if chosen.enPassant then
            captured = board[fromRank][toFile] 
            board[fromRank][toFile] = nil
        else
            captured = board[toRank][toFile]
        end
    end

    if piece.type == "pawn" or captured then
        state.halfmoveClock = 0
    else
        state.halfmoveClock = state.halfmoveClock + 1
    end

    if piece.color == "black" then
        state.fullmove = state.fullmove + 1
    end

    board[fromRank][fromFile] = nil
    board[toRank][toFile] = piece
    piece.moved = true

    if chosen.castle then
        local rookFromFile = (chosen.castle == "king") and 8 or 1
        local rookToFile = (chosen.castle == "king") and (toFile - 1) or (toFile + 1)
        local rook = board[toRank][rookFromFile]
        board[toRank][rookFromFile] = nil
        board[toRank][rookToFile] = rook
        if rook then rook.moved = true end
    end

    local promoted = nil
    if piece.type == "pawn" and (toRank == 8 or toRank == 1) then
        local validPromotions = { queen = true, rook = true, bishop = true, knight = true }
        promoted = validPromotions[promotion] and promotion or "queen"
        piece.type = promoted
    end

    if chosen.doubleStep then
        local dir = (piece.color == "white") and -1 or 1
        state.enPassant = { file = toFile, rank = toRank + dir }
    else
        state.enPassant = nil
    end

    state.turn = opponent(piece.color)

    local inCheck = ChessEngine.IsInCheck(state, state.turn)
    local hasMoves = false
    for r = 1, 8 do
        for f = 1, 8 do
            local p = board[r][f]
            if p and p.color == state.turn then
                if #ChessEngine.LegalMoves(state, f, r) > 0 then
                    hasMoves = true
                    break
                end
            end
        end
        if hasMoves then break end
    end

    local checkmate, stalemate = false, false
    local drawReason = nil

    if not hasMoves then
        if inCheck then
            checkmate = true
            state.status = "checkmate"
        else
            stalemate = true
            state.status = "draw"
            drawReason = "stalemate"
        end
    else
        state.status = inCheck and "check" or "playing"

        if state.halfmoveClock >= 100 then 
            state.status = "draw"
            drawReason = "fifty_move"
        elseif ChessEngine.IsInsufficientMaterial(state) then
            state.status = "draw"
            drawReason = "insufficient_material"
        else
            local key = positionKey(state)
            state.positionCounts[key] = (state.positionCounts[key] or 0) + 1
            if state.positionCounts[key] >= 3 then
                state.status = "draw"
                drawReason = "threefold_repetition"
            end
        end
    end

    state.drawReason = drawReason

    table.insert(state.history, {
        from = { file = fromFile, rank = fromRank },
        to = { file = toFile, rank = toRank },
        color = piece.color,
        capture = chosen.capture or false,
        enPassant = chosen.enPassant or false,
        castle = chosen.castle,
        promotion = promoted,
    })

    return {
        ok = true,
        captured = captured,
        promoted = promoted,
        castle = chosen.castle,
        enPassantCapture = chosen.enPassant,
        check = inCheck,
        checkmate = checkmate,
        stalemate = stalemate,
        draw = (drawReason ~= nil),
        drawReason = drawReason,
    }
end

return ChessEngine
