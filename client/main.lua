local activeTables = {} 
local localSit = nil 
local standUpFromChair 

local function key(file, rank) return file .. "_" .. rank end

local function pieceModel(color, ptype)
    return Config.PieceModels[color] and Config.PieceModels[color][ptype]
end

CreateThread(function()
    for _, models in pairs(Config.PieceModels) do
        for _, model in pairs(models) do
            RequestModel(model)
        end
    end
    for _, models in pairs(Config.PieceModels) do
        for _, model in pairs(models) do
            while not HasModelLoaded(model) do Wait(0) end
        end
    end
end)

local function spawnTableProp(tableCfg)
    if not tableCfg.tableProp then return nil end
    RequestModel(tableCfg.tableProp)
    while not HasModelLoaded(tableCfg.tableProp) do Wait(0) end

    local coord = tableCfg._boardCoord or tableCfg.coord
    local heading = tableCfg._boardHeading or tableCfg.heading

    local entity = CreateObject(tableCfg.tableProp, coord.x, coord.y, coord.z, false, false, false)
    SetEntityHeading(entity, heading)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, true, true)
    return entity
end

local function spawnFurnitureProp(model, coord, heading)
    if not model then return nil end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local entity = CreateObject(model, coord.x, coord.y, coord.z, false, false, false)
    SetEntityHeading(entity, heading)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, true, true)
    return entity
end

local ChairInfo = {} 

local function spawnFurniture(tableCfg)
    local furn = Config.GetFurnitureConfig(tableCfg)
    if not furn then return {} end

    local entities = {}
    ChairInfo[tableCfg.id] = nil

    if furn.tableProp then
        local coord = Config.GetFurnitureWorldCoord(tableCfg, furn.tableOffset)
        local heading = tableCfg.heading + furn.tableRotationOffset
        local ent = spawnFurnitureProp(furn.tableProp, coord, heading)
        if ent then table.insert(entities, ent) end
    end

    if furn.chairProp then
        local chairs = {}

        local whiteCoord = Config.GetFurnitureWorldCoord(tableCfg, furn.chairOffsetWhite)
        local whiteHeading = tableCfg.heading + furn.chairRotationOffsetWhite
        local whiteEnt = spawnFurnitureProp(furn.chairProp, whiteCoord, whiteHeading)
        if whiteEnt then
            table.insert(entities, whiteEnt)
            chairs.white = {
                entity = whiteEnt,
                coord = whiteCoord,
                heading = Config.GetFacingHeadingToBoard(tableCfg, whiteCoord),
            }
        end

        local blackCoord = Config.GetFurnitureWorldCoord(tableCfg, furn.chairOffsetBlack)
        local blackHeading = tableCfg.heading + furn.chairRotationOffsetBlack
        local blackEnt = spawnFurnitureProp(furn.chairProp, blackCoord, blackHeading)
        if blackEnt then
            table.insert(entities, blackEnt)
            chairs.black = {
                entity = blackEnt,
                coord = blackCoord,
                heading = Config.GetFacingHeadingToBoard(tableCfg, blackCoord),
            }
        end

        ChairInfo[tableCfg.id] = chairs
    end

    return entities
end

local function spawnPieceProp(tableCfg, color, ptype, file, rank)
    local model = pieceModel(color, ptype)
    if not model then return nil end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local coord = Config.GetSquareCoord(tableCfg, file, rank)
    local entity = CreateObject(model, coord.x, coord.y, coord.z, false, false, false)
    SetEntityHeading(entity, tableCfg.heading)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, false, false)

    local t = activeTables[tableCfg.id]
    if t then
        t.allEntities = t.allEntities or {}
        table.insert(t.allEntities, entity)
    end

    return entity
end

local function clearTableProps(tableId)
    local t = activeTables[tableId]
    if not t then return end
    for _, ent in ipairs(t.allEntities or {}) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    t.allEntities = {}
    t.props = {}
end

local TableCfgIndex = {}
for _, t in ipairs(Config.Tables) do
    TableCfgIndex[t.id] = t
end

local function tableCfgById(tableId)
    return TableCfgIndex[tableId]
end

local function setupCamera(tableId, side)
    local tableCfg = tableCfgById(tableId)
    local camCfg = Config.CameraSides[side]
    if not tableCfg or not camCfg then return end

    local t = activeTables[tableId]
    if t.cam and DoesCamExist(t.cam) then
        DestroyCam(t.cam, false)
        t.cam = nil
    end

    local camCoord = Config.GetCameraCoord(tableCfg, side)
    local lookAt = Config.GetCameraLookAt(tableCfg)

    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA",
        camCoord.x, camCoord.y, camCoord.z,
        0.0, 0.0, 0.0, camCfg.fov or 45.0, false, 0)

    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)

    local rot = GetCamRot(cam, 2)
    SetCamRot(cam, camCfg.pitch or rot.x, rot.y, rot.z, 2)

    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
    DisplayRadar(false)

    t.cam = cam
end

local function teardownCamera(tableId)
    local t = activeTables[tableId]
    if not t or not t.cam then return end
    if DoesCamExist(t.cam) then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(t.cam, false)
    end
    t.cam = nil
    DisplayRadar(true)
end

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if localSit then standUpFromChair() end
    SetPlayerInvisibleLocally(PlayerId(), false)
    for tableId, t in pairs(activeTables) do
        teardownCamera(tableId)
        for _, ent in ipairs(t.furnitureEntities or {}) do
            if DoesEntityExist(ent) then DeleteEntity(ent) end
        end

        for _, ent in ipairs(t.allEntities or {}) do
            if DoesEntityExist(ent) then DeleteEntity(ent) end
        end
        if t.tableEntity and DoesEntityExist(t.tableEntity) then
            DeleteEntity(t.tableEntity)
        end
    end
end)

RegisterNetEvent("chess:staffcmd_cam_offset", function(args)
    local side, axis, delta = args[1], args[2], tonumber(args[3])
    if not (side and axis and delta) or not Config.CameraSides[side] then
        TriggerEvent("chess:notify", "use: /chess_cam_offset white|black x|y|z <delta>")
        return
    end
    local cfg = Config.CameraSides[side]
    cfg.offset = vector3(
        cfg.offset.x + (axis == "x" and delta or 0.0),
        cfg.offset.y + (axis == "y" and delta or 0.0),
        cfg.offset.z + (axis == "z" and delta or 0.0)
    )
    TriggerEvent("chess:notify", side .. " offset = " .. tostring(cfg.offset))

    for tableId, t in pairs(activeTables) do
        if t.side == side then setupCamera(tableId, side) end
    end
end)

RegisterNetEvent("chess:staffcmd_cam_pitch", function(args)
    local side, delta = args[1], tonumber(args[2])
    if not (side and delta) or not Config.CameraSides[side] then
        TriggerEvent("chess:notify", "use: /chess_cam_pitch white|black <delta>")
        return
    end
    local cfg = Config.CameraSides[side]
    cfg.pitch = cfg.pitch + delta
    TriggerEvent("chess:notify", side .. " pitch = " .. tostring(cfg.pitch))

    for tableId, t in pairs(activeTables) do
        if t.side == side then setupCamera(tableId, side) end
    end
end)

RegisterNetEvent("chess:staffcmd_cam_fov", function(args)
    local side, delta = args[1], tonumber(args[2])
    if not (side and delta) or not Config.CameraSides[side] then
        TriggerEvent("chess:notify", "use: /chess_cam_fov white|black <delta>")
        return
    end
    local cfg = Config.CameraSides[side]
    cfg.fov = cfg.fov + delta
    TriggerEvent("chess:notify", side .. " fov = " .. tostring(cfg.fov))

    for tableId, t in pairs(activeTables) do
        if t.side == side then setupCamera(tableId, side) end
    end
end)

local function tweenEntity(entity, fromCoord, toCoord, durationMs, onFinish)
    CreateThread(function()
        local start = GetGameTimer()
        FreezeEntityPosition(entity, false)
        while true do
            local now = GetGameTimer()
            local t = (now - start) / durationMs
            if t >= 1.0 then t = 1.0 end
            local easedT = 1 - (1 - t) * (1 - t) 
            local x = fromCoord.x + (toCoord.x - fromCoord.x) * easedT
            local y = fromCoord.y + (toCoord.y - fromCoord.y) * easedT
            local z = fromCoord.z + (toCoord.z - fromCoord.z) * easedT
            if DoesEntityExist(entity) then
                SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
            else
                return
            end
            if t >= 1.0 then break end
            Wait(0)
        end
        if DoesEntityExist(entity) then
            FreezeEntityPosition(entity, true)
        end
        if onFinish then onFinish() end
    end)
end

local function fullRenderState(tableId, state)
    local tableCfg = tableCfgById(tableId)
    if not tableCfg then return end

    local t = activeTables[tableId]
    t.state = state
    clearTableProps(tableId)

    for rank = 1, 8 do
        for file = 1, 8 do
            local piece = state.board[rank] and state.board[rank][file]
            if piece then
                local ent = spawnPieceProp(tableCfg, piece.color, piece.type, file, rank)
                if ent then t.props[key(file, rank)] = ent end
            end
        end
    end
end

local function diffRenderState(tableId, state)
    local tableCfg = tableCfgById(tableId)
    if not tableCfg then return end
    local t = activeTables[tableId]
    local oldState = t.state

    if not oldState or not oldState.history then
        fullRenderState(tableId, state)
        return
    end

    if #state.history ~= #oldState.history + 1 then
        fullRenderState(tableId, state)
        return
    end

    local move = state.history[#state.history]
    local fromKey = key(move.from.file, move.from.rank)
    local toKey = key(move.to.file, move.to.rank)
    local movingEnt = t.props[fromKey]

    if not movingEnt or not DoesEntityExist(movingEnt) then
        fullRenderState(tableId, state)
        return
    end

    if move.capture and not move.enPassant then
        local captured = t.props[toKey]
        if captured and DoesEntityExist(captured) then DeleteEntity(captured) end
        t.props[toKey] = nil
    end

    if move.enPassant then
        local epKey = key(move.to.file, move.from.rank)
        local captured = t.props[epKey]
        if captured and DoesEntityExist(captured) then DeleteEntity(captured) end
        t.props[epKey] = nil
    end

    local fromCoord = Config.GetSquareCoord(tableCfg, move.from.file, move.from.rank)
    local toCoord = Config.GetSquareCoord(tableCfg, move.to.file, move.to.rank)

    t.props[fromKey] = nil

    if move.promotion then
        tweenEntity(movingEnt, fromCoord, toCoord, 350, function()
            if DoesEntityExist(movingEnt) then DeleteEntity(movingEnt) end
            local newEnt = spawnPieceProp(tableCfg, move.color, move.promotion, move.to.file, move.to.rank)
            t.props[toKey] = newEnt
        end)
    else
        tweenEntity(movingEnt, fromCoord, toCoord, 350)
        t.props[toKey] = movingEnt
    end

    if move.castle then
        local rookFromFile = (move.castle == "king") and 8 or 1
        local rookToFile = (move.castle == "king") and (move.to.file - 1) or (move.to.file + 1)
        local rookFromKey = key(rookFromFile, move.to.rank)
        local rookToKey = key(rookToFile, move.to.rank)
        local rookEnt = t.props[rookFromKey]
        if rookEnt and DoesEntityExist(rookEnt) then
            local rFrom = Config.GetSquareCoord(tableCfg, rookFromFile, move.to.rank)
            local rTo = Config.GetSquareCoord(tableCfg, rookToFile, move.to.rank)
            tweenEntity(rookEnt, rFrom, rTo, 350)
            t.props[rookFromKey] = nil
            t.props[rookToKey] = rookEnt
        end
    end

    t.state = state
end

RegisterNetEvent("chess:stateSync", function(tableId, state, players)
    if not activeTables[tableId] then
        activeTables[tableId] = { props = {} }
    end
    local t = activeTables[tableId]

    if t.rendering then
        t.pendingState = state
        t.pendingPlayers = players
        return
    end

    t.rendering = true
    diffRenderState(tableId, state)
    t.players = players
    t.rendering = false

    if t.selected then
        local p = state.board[t.selected.rank] and state.board[t.selected.rank][t.selected.file]
        if not p or p.color ~= t.side or state.turn ~= t.side then
            if t.selectedEntity and DoesEntityExist(t.selectedEntity) then
                SetEntityDrawOutline(t.selectedEntity, false)
            end
            t.selected = nil
            t.selectedEntity = nil
            t.legalMoves = nil
        end
    end

    while t.pendingState do
        local nextState, nextPlayers = t.pendingState, t.pendingPlayers
        t.pendingState, t.pendingPlayers = nil, nil
        t.rendering = true
        diffRenderState(tableId, nextState)
        t.players = nextPlayers
        t.rendering = false
    end
end)

local function playIdleSitAnim(ped)
    local d = Config.SitAnim
    RequestAnimDict(d.dict)
    while not HasAnimDictLoaded(d.dict) do Wait(0) end
    TaskPlayAnim(ped, d.dict, d.idle, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function playMoveAnim()
    if Config.EnableAnimation == false then return end
    if not localSit then return end
    local ped = PlayerPedId()
    local d = Config.SitAnim
    RequestAnimDict(d.dict)
    while not HasAnimDictLoaded(d.dict) do Wait(0) end
    TaskPlayAnim(ped, d.dict, d.move, 8.0, -8.0, -1, 0, 0, false, false, false) 

    CreateThread(function()
        local duration = GetAnimDuration(d.dict, d.move)
        if duration <= 0.0 then duration = 1.0 end
        Wait(math.floor(duration * 1000))
        if localSit and DoesEntityExist(PlayerPedId()) then
            playIdleSitAnim(PlayerPedId())
        end
    end)
end

local function pickFloorSitAnim()
    local list = Config.FloorSitAnims
    if not list or #list == 0 then return nil end
    return list[math.random(#list)]
end

local function sitAtChair(tableId, side)
    local tableCfg = tableCfgById(tableId)
    if not tableCfg then return false end

    local ped = PlayerPedId()
    if localSit then
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
    end

    if tableCfg.furniture then
        local info = ChairInfo[tableId] and ChairInfo[tableId][side]
        if not info then return false end

        SetEntityCoords(ped, info.coord.x, info.coord.y, info.coord.z - 0.35, false, false, false, false)
        SetEntityHeading(ped, info.heading - 90.00) 
        FreezeEntityPosition(ped, true)
        playIdleSitAnim(ped)
    else
        local sideKey = (side == "white") and "chairWhite" or "chairBlack"
        local d = Config.FurnitureDefaults[sideKey]
        if not d then return false end

        local anim = pickFloorSitAnim()
        local animOffset = (anim and anim.offset) or vector3(0.0, 0.0, 0.0)

        if side == "black" then
            animOffset = vector3(animOffset.x, -animOffset.y, animOffset.z)
        end

        local totalOffset = d.offset + animOffset

        local coord = Config.GetFurnitureWorldCoord(tableCfg, totalOffset)
        local heading = Config.GetFacingHeadingToBoard(tableCfg, coord)

        SetEntityCoords(ped, coord.x, coord.y, coord.z, false, false, false, false)
        SetEntityHeading(ped, heading - 90.00) 
        FreezeEntityPosition(ped, true)

        if anim and anim.dict ~= "" and anim.anim ~= "" then
            RequestAnimDict(anim.dict)
            while not HasAnimDictLoaded(anim.dict) do Wait(0) end
            TaskPlayAnim(ped, anim.dict, anim.anim, 8.0, -8.0, -1, 1, 0, false, false, false) 
        end
    end

    localSit = { tableId = tableId, side = side }
    return true
end

standUpFromChair = function()
    if not localSit then return end
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if DoesEntityExist(ped) then FreezeEntityPosition(ped, false) end
    localSit = nil
end

RegisterCommand("chess_standup", function()
    if not localSit then return end
    local t = activeTables[localSit.tableId]
    if t and t.side then
        TriggerServerEvent("chess:leaveTable", localSit.tableId)
        return
    end
    standUpFromChair()
end, false)
RegisterKeyMapping("chess_standup", translate.GET_UP_FROM_THE_CHAR_CHESS, "keyboard", "x")

RegisterNetEvent("chess:joined", function(tableId, side)
    if not activeTables[tableId] then activeTables[tableId] = { props = {} } end
    activeTables[tableId].side = side
    TriggerServerEvent("chess:requestState", tableId)
    setupCamera(tableId, side)
    sitAtChair(tableId, side) 
    SetPlayerInvisibleLocally(PlayerId(), true) 
end)

RegisterNetEvent("chess:left", function(tableId)
    if activeTables[tableId] then activeTables[tableId].side = nil end
    teardownCamera(tableId)
    SetPlayerInvisibleLocally(PlayerId(), false) 
    if localSit and localSit.tableId == tableId then
        standUpFromChair()
    end
end)

RegisterNetEvent("chess:spectateLeft", function(tableId)
    local t = activeTables[tableId]
    if not t or t.side then return end
    clearTableProps(tableId)
    t.state = nil
end)

RegisterNetEvent("chess:notify", function(msg)
    SendNUIMessage({
        action = "chessNotify",
        message = msg,
    })
end)

RegisterNetEvent("chess:legalMoves", function(tableId, file, rank, moves)
    local t = activeTables[tableId]
    if not t then return end
    if t.selected and t.selected.file == file and t.selected.rank == rank then
        t.legalMoves = moves
    end
end)

RegisterNetEvent("chess:playMoveAnim", function(tableId)
    if not localSit or localSit.tableId ~= tableId then return end
    playMoveAnim()
end)

local function despawnAIPed(tableId)
    local t = activeTables[tableId]
    if not t then return end
    t.aiPed = nil
    t.aiSide = nil
end

local function spawnAIPed(tableId, side)
    if not activeTables[tableId] then activeTables[tableId] = { props = {} } end
    local t = activeTables[tableId]
    t.aiPed = nil
    t.aiSide = side
end

RegisterNetEvent("chess:aiOpponent", function(tableId, side, active)
    if active and side then
        spawnAIPed(tableId, side)
    else
        despawnAIPed(tableId)
    end
end)

local function setupTargetForTable(tableCfg, entity)
    local options = {
        {
            name = "chess_join_white_" .. tableCfg.id,
            label = translate.TARGET_PLAY_WHITE,
            icon = "fa-solid fa-chess",
            distance = 2.5,
            canInteract = function()
                local t = activeTables[tableCfg.id]
                return not (t and t.side)
            end,
            onSelect = function()
                TriggerServerEvent("chess:joinTable", tableCfg.id, "white")
            end,
        },
        {
            name = "chess_join_black_" .. tableCfg.id,
            label = translate.TARGET_PLAY_BLACK,
            icon = "fa-solid fa-chess",
            distance = 2.5,
            canInteract = function()
                local t = activeTables[tableCfg.id]
                return not (t and t.side)
            end,
            onSelect = function()
                TriggerServerEvent("chess:joinTable", tableCfg.id, "black")
            end,
        },
        {
            name = "chess_leave_" .. tableCfg.id,
            label = translate.TARGET_LEAVE_THE_TABLE,
            icon = "fa-solid fa-door-open",
            distance = 2.5,
            canInteract = function()
                local t = activeTables[tableCfg.id]
                return t and t.side ~= nil
            end,
            onSelect = function()
                TriggerServerEvent("chess:leaveTable", tableCfg.id)
            end,
        },
        {
            name = "chess_ai_white_" .. tableCfg.id,
            label = translate.TARGET_PLAYING_IA_IN_WHITE,
            icon = "fa-solid fa-robot",
            distance = 2.5,
            canInteract = function()
                local t = activeTables[tableCfg.id]
                return not (t and t.side)
            end,
            onSelect = function()
                TriggerServerEvent("chess:joinVsAI", tableCfg.id, "white")
            end,
        },
        {
            name = "chess_ai_black_" .. tableCfg.id,
            label = translate.TARGET_PLAYING_IA_IN_BLACK,
            icon = "fa-solid fa-robot",
            distance = 2.5,
            canInteract = function()
                local t = activeTables[tableCfg.id]
                return not (t and t.side)
            end,
            onSelect = function()
                TriggerServerEvent("chess:joinVsAI", tableCfg.id, "black")
            end,
        },
        {
            name = "chess_restart_" .. tableCfg.id,
            label = translate.TARGET_RESTART_MATCH,
            icon = "fa-solid fa-arrow-rotate-left",
            distance = 2.5,
            canInteract = function()
                local t = activeTables[tableCfg.id]
                return t and t.side ~= nil
            end,
            onSelect = function()
                TriggerServerEvent("chess:resetTable", tableCfg.id)
            end,
        },
        {
            name = "chess_refreshcam_" .. tableCfg.id,
            label = translate.TARGET_READJUST_CAMERA,
            icon = "fa-solid fa-camera-rotate",
            distance = 2.5,
            canInteract = function()
                local t = activeTables[tableCfg.id]
                return t and t.side ~= nil
            end,
            onSelect = function()
                local t = activeTables[tableCfg.id]
                if not t or not t.side then return end
                teardownCamera(tableCfg.id)
                setupCamera(tableCfg.id, t.side)
                TriggerEvent("chess:notify", translate.NOTIFY_CAMERA_READJUSTED)
            end,
        },
        {
            name = "chess_removeboard_" .. tableCfg.id,
            label = translate.TARGET_REMOVE_TABLE,
            icon = "fa-solid fa-trash",
            distance = 2.5,
            canInteract = function()
                return tableCfg.isRuntime == true
            end,
            onSelect = function()
                TriggerServerEvent("chess:removeBoard", tableCfg.id)
            end,
        },
    }

    if entity then
        exports.ox_target:addLocalEntity(entity, options)
    else
        exports.ox_target:addSphereZone({
            coords = tableCfg.coord,
            radius = tableCfg.zoneRadius or 2.0,
            debug = false,
            options = options,
        })
    end
end

local function setupChairTargets(tableCfg)
    local chairs = ChairInfo[tableCfg.id]
    if not chairs then return end

    for side, info in pairs(chairs) do
        if info.entity and DoesEntityExist(info.entity) then
            exports.ox_target:addLocalEntity(info.entity, {
                {
                    name = "chess_sit_" .. side .. "_" .. tableCfg.id,
                    label = translate.TARGET_TO_SIT,
                    icon = "fa-solid fa-chair",
                    distance = 2.5,
                    canInteract = function()
                        return localSit == nil
                    end,
                    onSelect = function()
                        sitAtChair(tableCfg.id, side)
                    end,
                },
            })
        end
    end
end

local function spawnAndSetupTable(tableCfg)
    if not activeTables[tableCfg.id] then activeTables[tableCfg.id] = { props = {} } end
    if activeTables[tableCfg.id].tableEntity and DoesEntityExist(activeTables[tableCfg.id].tableEntity) then
        return
    end
    local entity = spawnTableProp(tableCfg)
    activeTables[tableCfg.id].tableEntity = entity
    activeTables[tableCfg.id].furnitureEntities = spawnFurniture(tableCfg)
    setupTargetForTable(tableCfg, entity)
    setupChairTargets(tableCfg)
end

local function despawnTable(tableId)
    local t = activeTables[tableId]
    if not t then return end

    clearTableProps(tableId)
    if t.tableEntity and DoesEntityExist(t.tableEntity) then DeleteEntity(t.tableEntity) end
    t.tableEntity = nil
    for _, ent in ipairs(t.furnitureEntities or {}) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    t.furnitureEntities = {}

    teardownCamera(tableId)
    if localSit and localSit.tableId == tableId then
        standUpFromChair()
    end
    if t.side then
        SetPlayerInvisibleLocally(PlayerId(), false)
    end
end

local function rotationToDirection(rotation)
    local rx = rotation.x * (math.pi / 180.0)
    local rz = rotation.z * (math.pi / 180.0)
    local cosX = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * cosX, math.cos(rz) * cosX, math.sin(rx))
end

local function furnitureWorldCoordFromRaw(coord, heading, offset)
    local rad = heading * math.pi / 180.0
    local cos_ = math.cos(rad)
    local sin_ = math.sin(rad)
    local rx = offset.x * cos_ - offset.y * sin_
    local ry = offset.x * sin_ + offset.y * cos_
    return vector3(coord.x + rx, coord.y + ry, coord.z + offset.z)
end

local function drawPlacementHelp(msg)
    SetTextFont(4)
    SetTextScale(0.36, 0.36)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(msg)
    DrawText(0.5, 0.85)
end

local placingBoard = false 
local function startBoardPlacement(furniture, noSave)
    if placingBoard then
        TriggerEvent("chess:notify", translate.NOTIFY_THERE_IS_ALREADY_A_TABLE_POSITIONING_PROCESS)
        return
    end
    placingBoard = true

    local ghostModel = `bzzz_chess_board_a`
    RequestModel(ghostModel)
    while not HasModelLoaded(ghostModel) do Wait(0) end

    local ghost = CreateObject(ghostModel, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(ghost, 160, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)

    local furnGhosts = {} 
    if furniture then
        local d = Config.FurnitureDefaults
        local defs = {
            { key = "table", model = Config.FurnitureTableProp, offset = d.table.offset, rotOffset = d.table.rotationOffset },
            { key = "chairWhite", model = Config.ChairProp, offset = d.chairWhite.offset, rotOffset = d.chairWhite.rotationOffset },
            { key = "chairBlack", model = Config.ChairProp, offset = d.chairBlack.offset, rotOffset = d.chairBlack.rotationOffset },
        }
        for _, def in ipairs(defs) do
            if def.model then
                RequestModel(def.model)
                while not HasModelLoaded(def.model) do Wait(0) end
                local ent = CreateObject(def.model, 0.0, 0.0, 0.0, false, false, false)
                SetEntityAlpha(ent, 160, false)
                SetEntityCollision(ent, false, false)
                FreezeEntityPosition(ent, true)
                furnGhosts[def.key] = { entity = ent, offset = def.offset, rotOffset = def.rotOffset }
            end
        end
    end

    local heading = GetEntityHeading(PlayerPedId())
    local lastCoord = nil

    CreateThread(function()
        while placingBoard do
            local camCoord = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            local direction = rotationToDirection(camRot)
            local destination = camCoord + direction * 25.0

            local rayHandle = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z,
                destination.x, destination.y, destination.z, -1, PlayerPedId(), 0)
            local _, hit, endCoord = GetShapeTestResult(rayHandle)
            local coord = (hit == 1) and endCoord or destination
            lastCoord = coord

            if DoesEntityExist(ghost) then
                SetEntityCoordsNoOffset(ghost, coord.x, coord.y, coord.z, false, false, false)
                SetEntityHeading(ghost, heading)
            end

            for _, fg in pairs(furnGhosts) do
                if DoesEntityExist(fg.entity) then
                    local fCoord = furnitureWorldCoordFromRaw(coord, heading, fg.offset)
                    SetEntityCoordsNoOffset(fg.entity, fCoord.x, fCoord.y, fCoord.z, false, false, false)
                    SetEntityHeading(fg.entity, heading + fg.rotOffset)
                end
            end

            if IsControlJustPressed(0, 241) then 
                heading = (heading + 5.0) % 360.0
            elseif IsControlJustPressed(0, 242) then 
                heading = (heading - 5.0) % 360.0
            end

            drawPlacementHelp(translate.TEXT3D_COMMANDS)

            if IsControlJustPressed(0, 38) then 
                placingBoard = false
                if noSave then
                    print(string.format([[
                    {
                        coord = vec3(%.2f, %.2f, %.2f),
                        heading = %.2f,
                        furniture = %s,
                    },
                    ]], coord.x, coord.y, coord.z, heading, tostring(furniture)))
                    TriggerEvent("chess:notify", translate.NOTIFY_TABLE_INFO_CAPTURED_VIEW_THE_INFO_BY_F8)
                else
                    TriggerServerEvent("chess:addBoard", coord, heading, furniture)
                end
            elseif IsControlJustPressed(0, 194) or IsControlJustPressed(0, 200) then 
                placingBoard = false
                TriggerEvent("chess:notify", translate.NOTIFY_TABLE_PLACEMENT_CANCELLED)
            end

            Wait(0)
        end

        if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        for _, fg in pairs(furnGhosts) do
            if DoesEntityExist(fg.entity) then DeleteEntity(fg.entity) end
        end
    end)
end

RegisterNetEvent("chess:staffcmd_addboard", function(args, noSave)
    local mode = tonumber(args[1])
    if mode ~= 1 and mode ~= 2 then
        TriggerEvent("chess:notify", translate.NOTIFY_USE_ADDBOARD)
        return
    end

    startBoardPlacement(mode == 2, noSave)
end)

RegisterNetEvent("chess:boardAdded", function(tableCfgData)
    local tableCfg = tableCfgData
    tableCfg.coord = vector3(tableCfgData.coord.x, tableCfgData.coord.y, tableCfgData.coord.z)

    TableCfgIndex[tableCfg.id] = tableCfg
    local existingIdx = nil
    for i, t in ipairs(Config.Tables) do
        if t.id == tableCfg.id then existingIdx = i break end
    end
    if existingIdx then
        Config.Tables[existingIdx] = tableCfg
    else
        table.insert(Config.Tables, tableCfg)
    end
    Config.ResolveBoardOrigin(tableCfg)
end)

RegisterNetEvent("chess:boardRemoved", function(tableId)
    despawnTable(tableId)
    activeTables[tableId] = nil
    ChairInfo[tableId] = nil
    TableCfgIndex[tableId] = nil

    for i = #Config.Tables, 1, -1 do
        if Config.Tables[i].id == tableId then
            table.remove(Config.Tables, i)
            break
        end
    end

    TriggerEvent("chess:notify", (translate.NOTIFY_TABLEID_REMOVED):format(tableId))
end)

RegisterNetEvent("chess:boardSpawn", function(tableCfgData)
    local tableCfg = tableCfgData
    tableCfg.coord = vector3(tableCfgData.coord.x, tableCfgData.coord.y, tableCfgData.coord.z)

    TableCfgIndex[tableCfg.id] = tableCfg
    local existingIdx = nil
    for i, t in ipairs(Config.Tables) do
        if t.id == tableCfg.id then existingIdx = i break end
    end
    if existingIdx then
        Config.Tables[existingIdx] = tableCfg
    else
        table.insert(Config.Tables, tableCfg)
    end
    Config.ResolveBoardOrigin(tableCfg)

    spawnAndSetupTable(tableCfg)
end)

RegisterNetEvent("chess:boardDespawn", function(tableId)
    despawnTable(tableId)
end)

local HOVER_THRESHOLD = 0.018 

local function clearOutline(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityDrawOutline(entity, false)
    end
end

local function setOutline(entity, kind)
    if not entity or not DoesEntityExist(entity) then return end
    SetEntityDrawOutline(entity, true)
end

local function refreshOutlineColor(t)
    SetEntityDrawOutlineShader(1)
    if t.selected then
        SetEntityDrawOutlineColor(60, 220, 90, 255)   
    elseif t.hovered then
        SetEntityDrawOutlineColor(255, 255, 255, 200) 
    end
end

local function findHoveredPiece(t, cursorX, cursorY)
    local bestEnt, bestDist = nil, HOVER_THRESHOLD
    for _, ent in pairs(t.props) do
        if DoesEntityExist(ent) then
            local coords = GetEntityCoords(ent)
            local onScreen, sx, sy = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
            if onScreen then
                local dx, dy = sx - cursorX, sy - cursorY
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < bestDist then
                    bestDist = dist
                    bestEnt = ent
                end
            end
        end
    end
    return bestEnt
end

local function squareUnderCursor(tableCfg, cursorX, cursorY)
    local worldNear, normal = GetWorldCoordFromScreenCoord(cursorX, cursorY)
    local destination = worldNear + normal * 15.0
    local rayHandle = StartShapeTestRay(worldNear.x, worldNear.y, worldNear.z,
        destination.x, destination.y, destination.z, -1, PlayerPedId(), 0)
    local _, hit, endCoord = GetShapeTestResult(rayHandle)
    if hit == 1 then
        return Config.WorldToSquare(tableCfg, endCoord)
    end
    return nil
end

local function drawMovePreview(tableCfg, moves)
    for _, m in ipairs(moves) do
        local coord = Config.GetSquareCoord(tableCfg, m.file, m.rank)
        local r, g, b = 60, 220, 90 
        if m.enPassant then
            r, g, b = 240, 200, 40 
        elseif m.capture then
            r, g, b = 230, 60, 60 
        elseif m.castle then
            r, g, b = 60, 140, 230 
        end
        DrawMarker(1, coord.x, coord.y, coord.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            Config.SquareSize * 0.8, Config.SquareSize * 0.8, 0.015, r, g, b, 160, false, false, 2, false, nil, nil, false)
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)

        local activeTableId, activeCfg = nil, nil
        for id, t in pairs(activeTables) do
            if t.side then
                local cfg = tableCfgById(id)
                if cfg and #(pedCoords - cfg.coord) < (cfg.zoneRadius or 2.5) then
                    activeTableId, activeCfg = id, cfg
                    break
                end
            end
        end

        if activeTableId then
            local t = activeTables[activeTableId]

            SetMouseCursorActiveThisFrame()
            DisableControlAction(0, 24, true)  
            DisableControlAction(0, 25, true)  
            DisableControlAction(0, 140, true) 
            DisableControlAction(0, 142, true) 

            local cursorX = GetControlNormal(0, 239) 
            local cursorY = GetControlNormal(0, 240) 

            local hovered = findHoveredPiece(t, cursorX, cursorY)

            if hovered ~= t.hovered then
                if t.hovered and t.hovered ~= t.selectedEntity then
                    clearOutline(t.hovered)
                end
                if hovered and hovered ~= t.selectedEntity then
                    setOutline(hovered, "hover")
                end
                t.hovered = hovered
            end

            refreshOutlineColor(t)

            if IsDisabledControlJustPressed(0, 24) then 
                if not t.selected then
                    if hovered then
                        local file, rank = squareUnderCursor(activeCfg, cursorX, cursorY)
                        local piece = file and t.state and t.state.board[rank] and t.state.board[rank][file]
                        if piece and piece.color == t.side then
                            t.selected = { file = file, rank = rank }
                            t.selectedEntity = hovered
                            t.legalMoves = nil 
                            setOutline(hovered, "selected")
                            TriggerServerEvent("chess:requestLegalMoves", activeTableId, file, rank)
                        end
                    end
                else
                    local file, rank = squareUnderCursor(activeCfg, cursorX, cursorY)
                    if file then
                        if hovered and t.state and t.state.board[rank] and t.state.board[rank][file]
                            and t.state.board[rank][file].color == t.side and hovered ~= t.selectedEntity then
                            clearOutline(t.selectedEntity)
                            t.selected = { file = file, rank = rank }
                            t.selectedEntity = hovered
                            t.legalMoves = nil
                            setOutline(hovered, "selected")
                            TriggerServerEvent("chess:requestLegalMoves", activeTableId, file, rank)
                        else
                            TriggerServerEvent("chess:requestMove", activeTableId,
                                t.selected.file, t.selected.rank, file, rank, "queen")
                            clearOutline(t.selectedEntity)
                            t.selected = nil
                            t.selectedEntity = nil
                            t.legalMoves = nil
                        end
                    end
                end
            end

            if IsDisabledControlJustPressed(0, 25) and t.selected then 
                clearOutline(t.selectedEntity)
                t.selected = nil
                t.selectedEntity = nil
                t.legalMoves = nil
            end

            if t.selected and t.legalMoves then
                drawMovePreview(activeCfg, t.legalMoves)
            end

            if Config.pedInvisible then
                SetPlayerInvisibleLocally(PlayerId(), true)
            end
            Wait(0) 
        else
            Wait(250)
        end
    end
end)

local calibrating = {}

RegisterNetEvent("chess:staffcmd_rotate", function(args)
    local delta = tonumber(args[1]) or 5.0
    Config.ExtraRotation = (Config.ExtraRotation + delta) % 360.0
    TriggerEvent("chess:notify", "ExtraRotation = " .. tostring(Config.ExtraRotation))
end)

RegisterNetEvent("chess:staffcmd_flipfile", function()
    Config.FlipFile = not Config.FlipFile
    TriggerEvent("chess:notify", "FlipFile = " .. tostring(Config.FlipFile))
end)

RegisterNetEvent("chess:staffcmd_fliprank", function()
    Config.FlipRank = not Config.FlipRank
    TriggerEvent("chess:notify", "FlipRank = " .. tostring(Config.FlipRank))
end)

RegisterNetEvent("chess:staffcmd_calibrate", function(args)
    local tableId = args[1] or (Config.Tables[1] and Config.Tables[1].id)
    if not tableId then return end
    calibrating[tableId] = not calibrating[tableId]

    if calibrating[tableId] then
        CreateThread(function()
            local tableCfg = tableCfgById(tableId)
            if not tableCfg then return end
            while calibrating[tableId] do
                for rank = 1, 8 do
                    for file = 1, 8 do
                        local coord = Config.GetSquareCoord(tableCfg, file, rank)
                        local isWhiteSquare = (file + rank) % 2 == 0
                        local r, g, b = 255, 60, 60
                        if isWhiteSquare then r, g, b = 60, 140, 255 end
                        DrawMarker(28, coord.x, coord.y, coord.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            0.02, 0.02, 0.02, r, g, b, 200, false, false, 2, false, nil, nil, false)
                    end
                end
                Wait(0)
            end
        end)
        TriggerEvent("chess:notify", "Calibracao ON para " .. tableId .. " (rode de novo pra desligar)")
    else
        TriggerEvent("chess:notify", "Calibracao OFF para " .. tableId)
    end
end)
