require "TrueQuests/TQ_Core"

TrueQuests.Events = TrueQuests.Events or {}

local EventsApi = TrueQuests.Events
EventsApi.listeners = EventsApi.listeners or {}

function EventsApi.on(name, callback)
    if type(name) ~= "string" or type(callback) ~= "function" then
        return false
    end

    EventsApi.listeners[name] = EventsApi.listeners[name] or {}
    table.insert(EventsApi.listeners[name], callback)
    return true
end

function EventsApi.trigger(name, ...)
    local listeners = EventsApi.listeners[name]
    if type(listeners) ~= "table" then
        return
    end

    for _, callback in ipairs(listeners) do
        local ok, err = pcall(callback, ...)
        if not ok then
            TrueQuests.warn("Event listener failed for " .. tostring(name) .. ": " .. tostring(err))
        end
    end
end

