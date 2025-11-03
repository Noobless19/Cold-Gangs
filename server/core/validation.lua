-- Input Validation Utilities for Cold-Gangs
ColdGangs = ColdGangs or {}
ColdGangs.Validation = ColdGangs.Validation or {}

function ColdGangs.Validation.ValidateGangName(name)
    if not name or type(name) ~= "string" then
        return false, "Gang name must be a string"
    end
    
    local len = #name
    if len < Config.GangNameMinLength or len > Config.GangNameMaxLength then
        return false, string.format("Gang name must be between %d and %d characters", 
            Config.GangNameMinLength, Config.GangNameMaxLength)
    end
    
    -- Only allow alphanumeric, spaces, hyphens, and underscores
    if not name:match("^[%w%s%-_]+$") then
        return false, "Gang name can only contain letters, numbers, spaces, hyphens, and underscores"
    end
    
    -- Check for profanity/banned words (extend as needed)
    local bannedWords = {"admin", "god", "moderator", "staff"} -- Add more as needed
    local lower = name:lower()
    for _, word in ipairs(bannedWords) do
        if lower:find(word, 1, true) then
            return false, "Gang name contains banned words"
        end
    end
    
    return true, nil
end

function ColdGangs.Validation.ValidateGangTag(tag)
    if not tag or type(tag) ~= "string" then
        return false, "Gang tag must be a string"
    end
    
    local len = #tag
    if len < Config.GangTagMinLength or len > Config.GangTagMaxLength then
        return false, string.format("Gang tag must be between %d and %d characters", 
            Config.GangTagMinLength, Config.GangTagMaxLength)
    end
    
    -- Only allow alphanumeric and no spaces
    if not tag:match("^[%w]+$") then
        return false, "Gang tag can only contain letters and numbers"
    end
    
    return true, nil
end

function ColdGangs.Validation.ValidateColor(color)
    if not color or type(color) ~= "string" then
        return false, "Color must be a string"
    end
    
    -- Validate hex color format (#RRGGBB or #RGB)
    if not color:match("^#?[0-9A-Fa-f]{6}$") and not color:match("^#?[0-9A-Fa-f]{3}$") then
        return false, "Color must be a valid hex color (e.g., #FF0000 or #F00)"
    end
    
    return true, nil
end

function ColdGangs.Validation.ValidateCitizenId(citizenId)
    if not citizenId or type(citizenId) ~= "string" then
        return false, "Citizen ID must be a string"
    end
    
    if #citizenId < 5 or #citizenId > 50 then
        return false, "Invalid citizen ID format"
    end
    
    -- Basic format validation (alphanumeric and hyphens/underscores)
    if not citizenId:match("^[%w%-_]+$") then
        return false, "Invalid citizen ID format"
    end
    
    return true, nil
end

function ColdGangs.Validation.ValidateAmount(amount)
    if amount == nil then
        return false, "Amount cannot be nil"
    end
    
    local num = tonumber(amount)
    if not num then
        return false, "Amount must be a number"
    end
    
    if num <= 0 then
        return false, "Amount must be greater than 0"
    end
    
    if num > 999999999 then
        return false, "Amount is too large"
    end
    
    return true, num
end

function ColdGangs.Validation.ValidateTerritoryName(name)
    if not name or type(name) ~= "string" then
        return false, "Territory name must be a string"
    end
    
    if #name < 1 or #name > 50 then
        return false, "Territory name must be between 1 and 50 characters"
    end
    
    -- Only allow alphanumeric, spaces, hyphens, underscores
    if not name:match("^[%w%s%-_]+$") then
        return false, "Territory name contains invalid characters"
    end
    
    return true, nil
end

function ColdGangs.Validation.SanitizeString(str, maxLength)
    if not str or type(str) ~= "string" then
        return ""
    end
    
    -- Remove HTML tags and scripts
    str = str:gsub("<[^>]+>", "")
    str = str:gsub("javascript:", "")
    str = str:gsub("on%w+=", "")
    
    -- Limit length
    if maxLength and #str > maxLength then
        str = str:sub(1, maxLength)
    end
    
    return str
end

exports('ValidateGangName', ColdGangs.Validation.ValidateGangName)
exports('ValidateGangTag', ColdGangs.Validation.ValidateGangTag)
exports('ValidateColor', ColdGangs.Validation.ValidateColor)
exports('ValidateCitizenId', ColdGangs.Validation.ValidateCitizenId)
exports('ValidateAmount', ColdGangs.Validation.ValidateAmount)
exports('SanitizeString', ColdGangs.Validation.SanitizeString)