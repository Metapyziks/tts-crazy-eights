--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]
require("vscode/console")

-- todo: handle emptying the deck and reshuffling
-- todo: end of round do a scoring animation and start next turn

globals = {
    deck_guid = "f42a3c",
    deck = nil,

    suit_buttons_guid = "76191e",
    suit_buttons = nil,
    
    discard_zone = nil,

    starting_hand_size = 10,

    deck_transform = {
        position = Vector(-1.25, 1, 0),
        rotation = Vector(0, 180, 180),
        rotation_snap = true
    },

    discard_transform = {
        position = Vector(1.25, 1, 0),
        rotation = Vector(0, 180, 0),
        rotation_snap = true
    },

    card_suits = {
        "Clubs",
        "Diamonds",
        "Hearts",
        "Spades"
    },

    suit_icons = {
        "♣",
        "♦",
        "♥",
        "♠"
    },

    suit_colors = {
        "#000000",
        "#ff0000",
        "#ff0000",
        "#000000"
    },

    card_values = {
        "Ace",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "10",
        "Jack",
        "Queen",
        "King"
    },

    card_scores = {
        1,  -- Ace
        2,  -- 2
        3,  -- 3
        4, -- 4
        5, -- 5
        6, -- 6
        7, -- 7
        50, -- 8
        9, -- 9
        10, -- 10
        10, -- Jack
        10, -- Queen
        10  -- King
    },

    -- is this really necessary??
    card_guids = {
        -- clubs
        "813bbb",
        "ae81e0",
        "20ff3c",
        "617c70",
        "881f53",
        "7c9338",
        "42b4eb",
        "fe747d",
        "8d4df0",
        "361cd8",
        "ef31ef",
        "df644d",
        "cc6907",

        -- diamonds
        "6cae49",
        "8f61c5",
        "ba685d",
        "c2ea94",
        "122772",
        "49bf7a",
        "3e97d3",
        "5460ac",
        "fbe0b8",
        "cdc92b",
        "224e73",
        "bd4af8",
        "07176a",

        -- hearts
        "b5433b",
        "a2e8ce",
        "c1d72d",
        "b85cd1",
        "c6d070",
        "113891",
        "d700da",
        "431035",
        "7d7535",
        "9a49f9",
        "0b299b",
        "fc90b1",
        "48fc5d",

        -- spades
        "45d047",
        "18a554",
        "fdd8d3",
        "e7c89d",
        "0b6b13",
        "dfe013",
        "592298",
        "c956d7",
        "b3d1e1",
        "bb6438",
        "e42fba",
        "e96351",
        "048a8f"
    },
    card_guid_map = {},
}

state = {}

for index, guid in ipairs(globals.card_guids) do
    local suit = math.floor((index - 1) / 13) + 1
    local value = ((index - 1) % 13) + 1
    globals.card_guid_map[guid] = {
        suit = suit,
        value = value,
        name = globals.card_values[value] .. " of " .. globals.card_suits[suit],
        guid = guid,
        score = globals.card_scores[value]
    }
end

function resetState()
    state = {    
        hand_size = -1,
        players = {},
    
        allow_actions = false,
        discarded_card_infos = {},
        last_played_card_info = nil,
    
        current_suit = 0,
        current_value = 0,
        crank_value = 0,
    
        -- post-turn config
        skip_turn = false,
        keep_turn = false,
        players_to_pickup = nil,
        suit_choice = nil
    }
end

resetState()

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad(save_state)
    log(save_state)

    globals.deck = getObjectFromGUID(globals.deck_guid)
    globals.suit_buttons = getObjectFromGUID(globals.suit_buttons_guid)

    globals.deck.setLock(true)
    globals.deck.interactable = false
    
    Global.setSnapPoints({
        globals.deck_transform,
        globals.discard_transform,
    })

    globals.discard_zone = spawnObject({
        position = globals.discard_transform.position,
        rotation = globals.discard_transform.rotation,
        scale = Vector(2.25, 1, 3),
        type = "ScriptingTrigger"
    })

    newGame()
end

function onSave()
    return state
end

function clearPlayerUI(player_ui)
    for _, obj in pairs(player_ui) do
        destroyObject(obj)
    end
end

function spawnPlayerText(player, x, y, value, color)
    local hand_pos = player.getHandTransform().position
    
    local text_pos = hand_pos:scale(0.75)
    local angle = text_pos:heading("y")
    
    text_pos.y = 1.25

    local axis_x = Vector(1, 0, 0):rotateOver('y', angle)
    local axis_y = Vector(0, 0, 1):rotateOver('y', angle)

    local text = spawnObject({
        position = text_pos + axis_x:scale(x) - axis_y:scale(y),
        rotation = Vector(90, angle, 0),
        type = "3DText"
    })
    text.TextTool.setFontColor(color or player.color)
    text.TextTool.setValue(value)

    return text
end

function createPlayerText(player)
    spawnPlayerText(player, -1.5, 0, "Score:", Color(1, 1, 1))
    spawnPlayerText(player, -2.05, 1, "Shuffles:", Color(1, 1, 1))

    return {
        score = spawnPlayerText(player, 1, 0, "0"),
        shuffles = spawnPlayerText(player, 1, 1, "0"),
        turn = spawnPlayerText(player, 0, 4.5, "My turn!"),
        order = spawnPlayerText(player, 0, 6, "-->")
    }
end

function updatePlayerText(player_data, my_turn)
    player_data.text.score.TextTool.setValue(tostring(player_data.score))
    player_data.text.shuffles.TextTool.setValue(tostring(player_data.shuffles))

    if my_turn then 
        player_data.text.order.TextTool.setValue(Turns.reverse_order and "<--" or "-->")
    end

    local turn_pos = player_data.text.turn.getPosition()
    turn_pos.y = my_turn and 1.25 or -999
    player_data.text.turn.setPosition(turn_pos)
    
    local order_pos = player_data.text.order.getPosition()
    order_pos.y = my_turn and 1.25 or -999
    player_data.text.order.setPosition(order_pos)
end

function updatePlayerTexts()
    for _, player in ipairs(Player.getPlayers()) do
        local player_data = state.players[player.color]
        if player_data then
            updatePlayerText(player_data, Turns.turn_color == player.color)
        end
    end
end

function newGame()
    state.hand_size = globals.starting_hand_size

    for _, player_data in pairs(state.players) do
        clearPlayerUI(player_data.text)
    end

    state.players = {}

    for _, player in ipairs(Player.getPlayers()) do
        if player.seated then
            state.players[player.color] = {
                text = createPlayerText(player),
                score = 0,
                shuffles = 0
            }

            updatePlayerTexts(player)
        end
    end

    startLuaCoroutine(Global, "newRoundAsync")
end

function wait(duration_seconds)
    local end_time = Time.time + duration_seconds
    repeat
        coroutine.yield(0)
    until Time.time >= end_time
end

function newRoundAsync()
    state.allow_actions = false
    state.discarded_card_infos = {}
    state.last_played_card_info = nil

    state.current_suit = 0
    state.current_value = 0
    state.crank_value = 0

    state.skip_turn = false
    state.keep_turn = false
    state.players_to_pickup = nil
    state.suit_choice = nil

    if state.hand_size == 1 then
        printToAll("Last round!")
    else
        printToAll("A new round begins!")
    end

    globals.suit_buttons.call("hideAll")

    local discard_pile = getDiscardPile()

    if discard_pile != nil then
        discard_pile.setRotationSmooth(globals.deck_transform.rotation)
        wait(1)
        
        discard_pile.setPositionSmooth(globals.deck_transform.position + Vector(0, 1, 0))

        if globals.deck == nil or getCardInfo(globals.deck) ~= nil then
            globals.deck = discard_pile
        end
        wait(2)
    else
        globals.deck.setPosition(globals.deck_transform.position)
        globals.deck.setRotation(globals.deck_transform.rotation)
    end
    
    globals.deck.reset()

    wait(1)
    
    printToAll("Everyone gets " .. state.hand_size .. (state.hand_size == 1 and " card." or " cards."))

    globals.deck.deal(state.hand_size)
    
    wait(1)

    playFromTopOfDeck()
    
    Turns.enable = true
    Turns.pass_turns = false
    Turns.disable_interactations = true
    Turns.type = 1
    Turns.reverse_order = false
    
    wait(0.5)

    if canPlayAnyCards(Player[Turns.turn_color]) then
        state.allow_actions = true
    else
        forcePickupAsync(Player[Turns.turn_color])
    end

    return 1
end

function getCardInfo(card)
    if card == nil or card.isDestroyed() then return nil end

    local guid = card.getGUID()
    return globals.card_guid_map[guid]
end

function onPlayerTurn(player)
    updatePlayerTexts()
    updateSuitUIRotation(player)
end

function canPlayAnyCards(player)
    local hand_objects = player.getHandObjects()

    for _, obj in ipairs(hand_objects) do
        local card_info = getCardInfo(obj)
        if card_info ~= nil then
            if canPlayCard(card_info) then
                return true
            end
        end
    end
    
    return false
end

function forcePickupAsync(player)
    state.players_to_pickup = {[player.color] = math.max(1, state.crank_value)}
    state.allow_actions = false
    state.crank_value = 0

    printToAll(player.steam_name .. " can't play any cards!")

    return endTurnAsync()
end

function onObjectSpawn(spawn_object)
    local card_info = getCardInfo(spawn_object)
    if card_info == nil then return end

    spawn_object.setName(card_info.name)
end

function onObjectEnterContainer(container, enter_object)
    local card_info = getCardInfo(enter_object)
    if card_info == nil then return end

    container.interactable = false
end

function onObjectDrop(player_color, dropped_object)
    local card_info = getCardInfo(dropped_object)
    if card_info == nil then return end

    if not state.allow_actions or player_color != Turns.turn_color or not canPlayCard(card_info) then
        dropped_object.deal(1, player_color)
        return
    end

    local obj_position = dropped_object.getPosition()
    local discard_dist = (obj_position - globals.discard_transform.position):magnitude()
    local hand_dist = (obj_position - Player[player_color].getHandTransform().position):magnitude()

    if hand_dist < discard_dist then
        dropped_object.deal(1, player_color)
        return
    end
    
    dropped_object.setPositionSmooth(globals.discard_transform.position + Vector(0, 0.5, 0))
    dropped_object.setRotationSmooth(globals.discard_transform.rotation)
    onCardPlayed(player_color, dropped_object, card_info)
end

function canPlayCard(card_info)
    if state.crank_value > 0 then
        return card_info.value == 1 or card_info.value == 2
    end

    return card_info.value == 8
        or card_info.value == 9
        or card_info.value == state.current_value
        or card_info.suit == state.current_suit
end

function getOppositePlayerColor(player_color)
    for index, color in ipairs(Turns.order) do
        if index == player_color then
            local opposite_index = math.ceil(index + #Turns.order / 2) % #Turns.order
            return Turns.order[opposite_index]
        end
    end

    return nil
end

function onCardPlayed(player_color, card, card_info)
    local previous_card_info = state.last_played_card_info

    card.interactable = false

    state.allow_actions = false
    state.last_played_card_info = card_info
    state.current_value = card_info.value
    state.current_suit = card_info.suit
    table.insert(state.discarded_card_infos, card_info)
    
    globals.suit_buttons.call("hideSuitText")

    if card_info.value == 10 then
        Turns.reverse_order = not Turns.reverse_order
    end

    if player_color == nil then return end

    if card_info.value == 1 then
        if state.crank_value > 0 then
            state.crank_value = state.crank_value + 1
        end
    elseif card_info.value == 2 then
        if state.crank_value == 0 then
            printToAll("Crank it up!")
        end

        state.crank_value = state.crank_value + 2
    elseif card_info.value == 4 then
        state.skip_turn = true
    elseif card_info.value == 5 then
        state.players_to_pickup = {}

        for color, player_data in pairs(state.players) do
            if player_color ~= color then
               state.players_to_pickup[color] = 1
            end
        end
    elseif card_info.value == 6 then
        state.keep_turn = true
    elseif card_info.value == 7 then
        local opposite_color = getOppositePlayerColor(player_color)
        if opposite_color ~= nil then
            state.players_to_pickup = {[opposite_color] = 1}
        end
    elseif card_info.value == 8 then
        state.suit_choice = {
            [1] = true,
            [2] = true,
            [3] = true,
            [4] = true
        }
    elseif card_info.value == 9 then
        if previous_card_info.suit == 1 or previous_card_info.suit == 4 then
            state.suit_choice = {
                [1] = true,
                [2] = false,
                [3] = false,
                [4] = true
            }
        else
            state.suit_choice = {
                [1] = false,
                [2] = true,
                [3] = true,
                [4] = false
            }
        end
    end

    if state.crank_value > 0 then
        globals.suit_buttons.call("showCrankText", { value = state.crank_value })
    end

    startLuaCoroutine(Global, "endTurnAsync")
end

-- Get a table containing player colors in turn order,
-- starting with the current player.
function getTurnOrder()
    local turn_order = Player.getColors()

    -- Filter out players that aren't taking part
    for i = #turn_order, 1, -1 do
        if state.players[turn_order[i]] == nil then
            table.remove(turn_order, i)
        end
    end

    -- Reverse if necessary
    if Turns.reverse_order then
        for i = 1, math.floor(#turn_order / 2) do
            local temp = turn_order[i]
            turn_order[i] = turn_order[#turn_order - i + 1]
            turn_order[#turn_order - i + 1] = temp
        end
    end

    -- Rotate until the current player is first
    local iters = #turn_order
    while turn_order[1] ~= Turns.turn_color and iters > 0 do
        local first = turn_order[1]
        table.remove(turn_order, 1)
        table.insert(turn_order, first)

        iters = iters - 1
    end

    return turn_order
end

function playerPickupAsync()
    local turn_order = getTurnOrder()

    for _, player_color in ipairs(turn_order) do
        local card_count = state.players_to_pickup[player_color]

        if card_count ~= nil then
            printToAll(player_color .. " picks up " .. tostring(card_count))

            if not drawForPlayerAsync(player_color, card_count) then
                return false
            end

            wait(0.5)
        end
    end

    return true
end

function getDiscardPile()
    for _, obj in ipairs(globals.discard_zone.getObjects()) do
        if obj.getQuantity() > 0 then
            return obj
        end

        if getCardInfo(obj) ~= nil then
            return obj
        end
    end

    return nil
end

function getDeckQuantity()
    if globals.deck == nil then
        return 0
    end

    if getCardInfo(globals.deck) ~= nil then
        return 1
    end

    return globals.deck.getQuantity()
end

function playFromTopOfDeck()
    local card = globals.deck.takeObject(globals.discard_transform)
    local card_info = getCardInfo(card)

    onCardPlayed(nil, card, card_info)
end

function drawFromDeck(player_color, count)
    if getCardInfo(globals.deck) ~= nil then
        -- This was the last card
        globals.deck.deal(count, player_color)
        globals.deck = nil
        return
    end

    local deck_cards = globals.deck.getObjects()

    globals.deck.deal(count, player_color)
    
    if count == #deck_cards then
        -- Deck is empty!
        globals.deck = nil
    elseif count == #deck_cards - 1 then
        -- One card left
        globals.deck = getObjectFromGUID(deck_cards[#deck_cards].guid)
        globals.deck.interactable = false
    end
end

function reshuffleDiscardPileAsync()
    state.discarded_card_infos = {}

    globals.deck = getDiscardPile()

    globals.deck.setRotationSmooth(globals.deck_transform.rotation)
    wait(0.5)

    if globals.deck.getQuantity() > 1 then
        globals.deck.shuffle()
        wait(0.5)
    end

    globals.deck.setPositionSmooth(globals.deck_transform.position)
end

function drawForPlayerAsync(player_color, count)
    local deck_count = getDeckQuantity()

    if deck_count >= count then
        drawFromDeck(player_color, count)
        return true
    end
    
    if getDiscardPile() == nil then
        return false
    end

    if deck_count > 0 then
        count = count - deck_count
        drawFromDeck(player_color, deck_count)
    end

    wait(1.0)

    printToAll(player_color .. " causes a reshuffle!")

    local player_data = state.players[player_color]
    player_data.shuffles = player_data.shuffles + 1
    player_data.score = player_data.score + player_data.shuffles * 5

    updatePlayerTexts()

    reshuffleDiscardPileAsync()
    wait(0.5)
    playFromTopOfDeck()
    
    wait(1.0)

    return drawForPlayerAsync(player_color, count)
end

function chooseSuitAsync()
    globals.suit_buttons.call("hideSuitText")

    globals.suit_buttons.call("setEnabledSuits", state.suit_choice)

    while state.suit_choice ~= nil do
        coroutine.yield(0)
    end
    
    globals.suit_buttons.call("hideSuitButtons")

    printToAll("The current suit is now " .. globals.card_suits[state.current_suit] .. "!")

    updateSuitText()
end

function onSuitButtonClick(params)
    local player = params.player
    local suit = params.suit

    if state.suit_choice == nil then return end
    if Turns.turn_color ~= player.color then return end
    if state.suit_choice[suit] == nil then return end

    state.suit_choice = nil
    state.current_suit = suit
end

function updateSuitUIRotation(player)
    if player == nil then return end

    local hand_transform = player.getHandTransform()
    if hand_transform == nil then return end

    globals.suit_buttons.setRotation(Vector(0, hand_transform.position:heading("y") + 180, 0))
end

function updateSuitText()
    globals.suit_buttons.call("showSuitText", { value = globals.suit_icons[state.current_suit], color = globals.suit_colors[state.current_suit] })
end

function advanceTurns(count)
    local turn_order = getTurnOrder()
    local index = (count % #turn_order) + 1

    Turns.turn_color = turn_order[index]
end

function shouldEndRound()
    local any_player_has_cards = false
    local all_players_have_cards = true

    for player_color, _ in pairs(state.players) do
        local player = Player[player_color]
        local has_cards = false

        for _, hand_obj in ipairs(player.getHandObjects()) do
            local card_info = getCardInfo(hand_obj)
            if card_info ~= nil then
                has_cards = true
                break
            end
        end

        if has_cards then
            any_player_has_cards = true
        else
            all_players_have_cards = false
        end
    end

    return not (all_players_have_cards or state.crank_value > 0 and any_player_has_cards) or true
end

function endTurnAsync()
    wait(0.5)

    if state.players_to_pickup ~= nil then
        if not playerPickupAsync() then
            return endRoundAsync()
        end
        wait(0.5)
        
        globals.suit_buttons.call("hideCrankText")
    end

    if not state.keep_turn and shouldEndRound() then
        return endRoundAsync()
    end
    
    if state.suit_choice ~= nil then
        chooseSuitAsync()
        wait(0.5)
    end

    if not state.keep_turn then
        if state.skip_turn then
            advanceTurns(2)
        else
            advanceTurns(1)
        end
    end

    state.keep_turn = false
    state.skip_turn = false
    state.players_to_pickup = nil
    state.suit_choice = nil
    
    if canPlayAnyCards(Player[Turns.turn_color]) then
        state.allow_actions = true
        return 1
    else
        return forcePickupAsync(Player[Turns.turn_color])
    end
end

function endRoundAsync()
    printToAll("The round has ended!")
    
    wait(2)

    -- Score for each player
    local turn_order = getTurnOrder()
    for _, player_color in ipairs(turn_order) do
        scorePlayerAsync(player_color)
        wait(2)
    end

    if state.hand_size == 1 then
        return endGameAsync()
    end
    
    state.hand_size = state.hand_size - 1

    return newRoundAsync()
end

function compareCards(a, b)
    return a.score < b.score
end

function scorePlayerAsync(player_color)
    local cards = {}
    local threes = {}

    local high_card_count = 0

    for _, obj in ipairs(Player[player_color].getHandObjects()) do
        local card_info = getCardInfo(obj)
        if card_info ~= nil then
            if card_info.score > 3 then
                high_card_count = high_card_count + 1
            end
            
            if card_info.value == 3 then
                table.insert(threes, card_info)
            else
                table.insert(cards, card_info)
            end
        end
    end

    local total_cards = #cards + #threes

    if total_cards == 0 then
        printToAll(player_color .. " has an empty hand!")
        return 1
    end

    if total_cards == 1 then
        printToAll(player_color .. " has 1 card!")
    else
        printToAll(player_color .. " has " .. total_cards .. " cards!")
    end

    if #threes > high_card_count then
        local spare_threes = #threes - high_card_count
        for i = 1, spare_threes do
            table.insert(cards, table.remove(threes))
        end
    end

    table.sort(cards, compareCards)

    local player_data = state.players[player_color]
    local total_score = 0

    while #cards > 0 do
        local next_card = table.remove(cards)
        local card_obj = getObjectFromGUID(next_card.guid)
        
        local discard_pile = getDiscardPile()
        discard_pile.putObject(card_obj)

        local card_score = 0

        if #threes > 0 then
            wait(0.5)
            local three = table.remove(threes)
            discard_pile.putObject(getObjectFromGUID(three.guid))

            card_score = 3
            printToAll("  +" .. card_score .. " (was " .. next_card.score .. ")")
        else
            card_score = next_card.score
            printToAll("  +" .. card_score)
        end

        player_data.score = player_data.score + card_score
        total_score = total_score + card_score
        updatePlayerTexts()

        wait(1)
    end

    printToAll("Total this round: " .. total_score)

    return 1
end

function endGameAsync()
    local best_color = nil
    local best_data = nil

    for player_color, player_data in pairs(state.players) do
        if best_data == nil
            or player_data.score < best_data.score
            or player_data.score == best_data.score and player_data.shuffles < best_data.shuffles
            then

                best_color = player_color
            best_data = player_data
        end
    end

    if best_color ~= nil then
        printToAll(best_color .. " wins with " .. best_data.score .. " points!")
    end

    Turns.enable = false

    return 1
end
