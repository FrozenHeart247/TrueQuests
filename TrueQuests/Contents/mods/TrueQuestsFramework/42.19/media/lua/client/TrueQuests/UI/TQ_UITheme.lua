TQ_UITheme = TQ_UITheme or {}

TQ_UITheme.Colors = {
    windowBg = { r = 0.075, g = 0.078, b = 0.090, a = 0.98 },
    panelBg = { r = 0.095, g = 0.098, b = 0.115, a = 0.94 },
    panelAlt = { r = 0.115, g = 0.120, b = 0.140, a = 0.95 },
    listBg = { r = 0.070, g = 0.073, b = 0.085, a = 0.96 },
    rowAlt = { r = 0.110, g = 0.115, b = 0.132, a = 0.74 },
    selected = { r = 0.180, g = 0.275, b = 0.240, a = 0.88 },
    hover = { r = 0.170, g = 0.180, b = 0.210, a = 0.82 },
    border = { r = 0.365, g = 0.405, b = 0.455, a = 1.00 },
    borderSoft = { r = 0.210, g = 0.240, b = 0.285, a = 1.00 },
    title = { r = 0.960, g = 0.910, b = 0.790, a = 1.00 },
    text = { r = 0.880, g = 0.890, b = 0.870, a = 1.00 },
    dim = { r = 0.600, g = 0.640, b = 0.660, a = 1.00 },
    green = { r = 0.310, g = 0.620, b = 0.390, a = 1.00 },
    blue = { r = 0.300, g = 0.450, b = 0.650, a = 1.00 },
    amber = { r = 0.680, g = 0.510, b = 0.270, a = 1.00 },
    red = { r = 0.610, g = 0.270, b = 0.270, a = 1.00 },
    purple = { r = 0.470, g = 0.370, b = 0.640, a = 1.00 },
    button = { r = 0.235, g = 0.270, b = 0.315, a = 1.00 },
    buttonHover = { r = 0.315, g = 0.365, b = 0.425, a = 1.00 },
    disabled = { r = 0.185, g = 0.190, b = 0.205, a = 0.76 },
}

local buttonKinds = {
    default = { bg = "button", hover = "buttonHover", border = "border", text = "text" },
    primary = { bg = "green", hover = "green", border = "border", text = "text" },
    info = { bg = "blue", hover = "blue", border = "border", text = "text" },
    warning = { bg = "amber", hover = "amber", border = "border", text = "text" },
    danger = { bg = "red", hover = "red", border = "border", text = "text" },
    muted = { bg = "panelAlt", hover = "button", border = "borderSoft", text = "dim" },
}

local function getColor(name)
    return TQ_UITheme.Colors[name] or TQ_UITheme.Colors.text
end

function TQ_UITheme.color(name, alpha)
    local c = getColor(name)
    return { r = c.r, g = c.g, b = c.b, a = alpha or c.a }
end

function TQ_UITheme.rgba(name, alpha)
    local c = getColor(name)
    return c.r, c.g, c.b, alpha or c.a
end

function TQ_UITheme.argb(name, alpha)
    local c = getColor(name)
    return alpha or c.a, c.r, c.g, c.b
end

function TQ_UITheme.applyWindow(window)
    if not window then
        return
    end

    window.background = false
    window.backgroundColor = TQ_UITheme.color("windowBg")
    window.borderColor = TQ_UITheme.color("border")
end

function TQ_UITheme.styleButton(button, kind)
    if not button then
        return
    end

    local style = buttonKinds[kind or "default"] or buttonKinds.default
    button.backgroundColor = TQ_UITheme.color(style.bg, 0.86)
    button.backgroundColorMouseOver = TQ_UITheme.color(style.hover, 0.96)
    button.borderColor = TQ_UITheme.color(style.border)
    button.textColor = TQ_UITheme.color(style.text)
end

function TQ_UITheme.drawPanel(target, x, y, width, height, fill, border)
    target:drawRect(x, y, width, height, TQ_UITheme.argb(fill or "panelBg"))
    target:drawRectBorder(x, y, width, height, TQ_UITheme.argb(border or "borderSoft"))
end

function TQ_UITheme.drawAccent(target, x, y, width, height, colorName)
    target:drawRect(x, y, width, height, TQ_UITheme.argb(colorName or "blue", 0.80))
end

function TQ_UITheme.drawPill(target, x, y, width, height, label, colorName)
    TQ_UITheme.drawPanel(target, x, y, width, height, "panelAlt", colorName or "border")
    local c = getColor(colorName or "text")
    target:drawTextCentre(tostring(label or ""), x + width / 2, y + 4, c.r, c.g, c.b, 1, UIFont.Small)
end

function TQ_UITheme.measure(font, text)
    local manager = getTextManager and getTextManager() or nil
    if manager and manager.MeasureStringX then
        return manager:MeasureStringX(font or UIFont.Small, tostring(text or ""))
    end

    return string.len(tostring(text or "")) * 7
end

function TQ_UITheme.truncate(text, width, font)
    text = tostring(text or "")
    if TQ_UITheme.measure(font or UIFont.Small, text) <= width then
        return text
    end

    local suffix = "..."
    local available = width - TQ_UITheme.measure(font or UIFont.Small, suffix)
    if available <= 8 then
        return suffix
    end

    local result = ""
    for i = 1, string.len(text) do
        local nextText = string.sub(text, 1, i)
        if TQ_UITheme.measure(font or UIFont.Small, nextText) > available then
            break
        end
        result = nextText
    end

    return result .. suffix
end

function TQ_UITheme.drawWrapped(target, text, x, y, width, maxLines, colorName, font)
    text = tostring(text or "")
    font = font or UIFont.Small
    local line = ""
    local lines = 0
    local lineHeight = 17
    local c = getColor(colorName or "text")

    for word in string.gmatch(text, "%S+") do
        local candidate = line == "" and word or (line .. " " .. word)
        if TQ_UITheme.measure(font, candidate) > width and line ~= "" then
            target:drawText(line, x, y + lines * lineHeight, c.r, c.g, c.b, c.a, font)
            lines = lines + 1
            line = word
            if maxLines and lines >= maxLines then
                return y + lines * lineHeight
            end
        else
            line = candidate
        end
    end

    if line ~= "" and (not maxLines or lines < maxLines) then
        target:drawText(line, x, y + lines * lineHeight, c.r, c.g, c.b, c.a, font)
        lines = lines + 1
    end

    return y + lines * lineHeight
end

function TQ_UITheme.drawTextRight(target, text, rightX, y, colorName, font)
    text = tostring(text or "")
    font = font or UIFont.Small
    local c = getColor(colorName or "text")
    local x = rightX - TQ_UITheme.measure(font, text)
    target:drawText(text, x, y, c.r, c.g, c.b, c.a, font)
end
