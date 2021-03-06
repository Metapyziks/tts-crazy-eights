function onLoad(save_state)
    self.setLock(true)
    self.setScale(Vector(1, 0.125, 1))
    self.setPosition(Vector(0, 0.875, 0))

    hideAll()
end

function hideAll()
    hideSuitButtons()
    hideSuitText()
    hideCrankText()
end

function onClick(player, value, id)
    Global.call("onSuitButtonClick", { player = player, suit = tonumber(id) })
end

function setEnabledSuits(suit_choice)
    hideSuitText()
    hideCrankText()

    for suit, enabled in pairs(suit_choice) do
        self.UI.setAttribute(tostring(suit), "interactable", enabled)
    end

    self.UI.setAttribute("2", "textColor", "#ff0000")
    self.UI.setAttribute("3", "textColor", "#ff0000")
    
    self.UI.show("suit_buttons")
end

function hideSuitButtons()
    self.UI.hide("suit_buttons")
end

function showSuitText(params)
    hideSuitButtons()
    hideCrankText()

    self.UI.setValue("suit_text", params.value)
    self.UI.setAttribute("suit_text", "color", params.color)
    self.UI.show("suit_text")
end

function hideSuitText()
    self.UI.hide("suit_text")
end

function showCrankText(params)
    hideSuitButtons()
    hideSuitText()

    self.UI.setValue("crank_text", params.value)
    self.UI.show("crank_text")
end

function hideCrankText()
    self.UI.hide("crank_text")
end
