ChessAI = {}

local PieceValue = {
    pawn = 100, knight = 320, bishop = 330, rook = 500, queen = 900, king = 0,
}

local function cloneState(state)
    local board = {}
    for r = 1, 8 do
        board[r] = {}
        for f = 1, 8 do
            local p = state.board[r][f]
            if p then
                board[r][f] = { color = p.color, type = p.type, moved = p.moved }
            end
        end
    end
    return {
        board = board,
        turn = state.turn,
        enPassant = state.enPassant and { file = state.enPassant.file, rank = state.enPassant.rank } or nil,
        halfmoveClock = state.halfmoveClock or 0,
        fullmove = state.fullmove or 1,
        status = "playing",
        drawReason = nil,
        history = {},
        positionCounts = {},
    }
end

local function evaluateMaterial(state, color)
    local score = 0
    for r = 1, 8 do
        for f = 1, 8 do
            local p = state.board[r][f]
            if p then
                local v = PieceValue[p.type] or 0
                score = score + (p.color == color and v or -v)
            end
        end
    end
    return score
end

local CenterFileBonus = { 0, 1, 2, 3, 3, 2, 1, 0 }

local function advancement(rank, color)
    return (color == "white") and (rank - 1) or (8 - rank)
end

local function positionalScore(state, color)
    local score = 0
    local board = state.board

    for r = 1, 8 do
        for f = 1, 8 do
            local p = board[r][f]
            if p then
                local sign = (p.color == color) and 1 or -1
                local centerBonus = CenterFileBonus[f] or 0
                local homeRank = (p.color == "white") and 1 or 8

                if p.type == "pawn" then
                    score = score + sign * (advancement(r, p.color) * 3 + centerBonus)
                elseif p.type == "knight" or p.type == "bishop" then
                    local developed = (r ~= homeRank) and 4 or 0
                    score = score + sign * (developed + centerBonus)
                elseif p.type == "rook" then
                    local seventhRank = (p.color == "white") and 7 or 2
                    score = score + sign * ((r == seventhRank) and 6 or 0)
                elseif p.type == "queen" then
                    score = score + sign * (centerBonus * 0.5)
                elseif p.type == "king" then
                    if r == homeRank then
                        score = score + sign * ((f <= 3 or f >= 7) and 5 or 2)
                    else
                        score = score + sign * -3
                    end
                end
            end
        end
    end

    return score
end

local function evaluate(state, color)
    return evaluateMaterial(state, color) + positionalScore(state, color)
end

local function allLegalMoves(state, color)
    local out = {}
    for r = 1, 8 do
        for f = 1, 8 do
            local p = state.board[r][f]
            if p and p.color == color then
                local moves = ChessEngine.LegalMoves(state, f, r)
                for _, m in ipairs(moves) do
                    table.insert(out, { fromFile = f, fromRank = r, toFile = m.file, toRank = m.rank })
                end
            end
        end
    end
    return out
end

local function worstReplyFor(simState, aiColor)
    if simState.status == "checkmate" then
        return 100000 
    end
    if simState.status == "draw" then
        return 0
    end

    local oppColor = simState.turn
    local worst = nil
    for _, mv in ipairs(allLegalMoves(simState, oppColor)) do
        local sim2 = cloneState(simState)
        local res2 = ChessEngine.ApplyMove(sim2, mv.fromFile, mv.fromRank, mv.toFile, mv.toRank, "queen")
        if res2.ok then
            local score
            if res2.checkmate then
                score = -100000 
            else
                score = evaluate(sim2, aiColor)
                if res2.check then
                    score = score - 8
                end
            end
            if worst == nil or score < worst then worst = score end
        end
    end
    return worst or 0
end

function ChessAI.ChooseMove(state, aiColor, difficulty)
    difficulty = difficulty or "normal"
    local candidates = allLegalMoves(state, aiColor)
    if #candidates == 0 then return nil end

    local best = {}
    local bestScore = nil

    for _, mv in ipairs(candidates) do
        local sim = cloneState(state)
        local result = ChessEngine.ApplyMove(sim, mv.fromFile, mv.fromRank, mv.toFile, mv.toRank, "queen")
        if result.ok then
            local score
            if result.checkmate then
                score = 100000
            elseif difficulty == "easy" then
                score = evaluate(sim, aiColor) + math.random(-30, 30)
            else
                score = worstReplyFor(sim, aiColor)
            end

            if result.check and not result.checkmate then
                score = score + 10
            end

            if bestScore == nil or score > bestScore + 0.01 then
                bestScore = score
                best = { mv }
            elseif math.abs(score - bestScore) <= 0.01 then
                table.insert(best, mv)
            end
        end
    end

    if #best == 0 then return nil end
    local chosen = best[math.random(#best)]
    return {
        fromFile = chosen.fromFile,
        fromRank = chosen.fromRank,
        toFile = chosen.toFile,
        toRank = chosen.toRank,
        promotion = "queen",
    }
end

return ChessAI
