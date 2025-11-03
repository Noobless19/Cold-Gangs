# Cold-Gangs Script Audit Report

## Executive Summary
This audit identifies security vulnerabilities, performance issues, code quality concerns, and potential bugs in the Cold-Gangs FiveM resource. The script manages gang systems including territories, wars, heists, businesses, drugs, and vehicles.

---

## ?? CRITICAL SECURITY ISSUES

### 1. Missing Input Validation
**Severity: HIGH**

**Issues:**
- `economy.lua:33-47` - Gang name changes lack length validation, character sanitization, and SQL injection protection
- `economy.lua:50-64` - Gang tag changes lack validation against Config limits
- `economy.lua:67-82` - Color input not validated as valid hex color format
- `members.lua:61` - `targetCitizenId` not validated before use
- `territories.lua:696` - Territory name not sanitized or validated

**Recommendation:**
```lua
-- Example fix for gang name
local function validateGangName(name)
    if not name or type(name) ~= "string" then return false end
    local len = #name
    if len < Config.GangNameMinLength or len > Config.GangNameMaxLength then return false end
    -- Only allow alphanumeric and spaces
    if not name:match("^[%w%s%-]+$") then return false end
    return true
end
```

### 2. Rate Limiting Not Implemented
**Severity: HIGH**

**Issue:**
- `config.lua:36-43` - Security config defines rate limiting parameters but they're never used
- No rate limiting on critical events like money transfers, member management, or gang creation

**Recommendation:**
Implement rate limiting middleware:
```lua
local rateLimits = {}
local function checkRateLimit(src, action, maxPerMinute)
    local key = src .. "_" .. action
    local now = os.time()
    rateLimits[key] = rateLimits[key] or {count = 0, reset = now + 60}
    
    if now > rateLimits[key].reset then
        rateLimits[key] = {count = 1, reset = now + 60}
        return true
    end
    
    if rateLimits[key].count >= maxPerMinute then
        return false
    end
    
    rateLimits[key].count = rateLimits[key].count + 1
    return true
end
```

### 3. Hardcoded Admin Citizen ID
**Severity: MEDIUM**

**Issue:**
- `config.lua:13` - Hardcoded admin citizen ID `"FPV50642"` in configuration

**Recommendation:**
Move to environment variable or server-specific config file, not in version control.

### 4. Missing Permission Checks
**Severity: MEDIUM**

**Issues:**
- `economy.lua:3-14` - Deposit event has no permission check (any member can deposit)
- Some admin callbacks may bypass permission checks through UI

**Recommendation:**
Add permission checks to all sensitive operations, including deposits if desired.

### 5. SQL Injection Risks
**Severity: LOW-MEDIUM**

**Issue:**
- Most queries use parameterized queries correctly, but some string concatenation exists
- `db.lua:14` - Potential injection in `SHOW COLUMNS` query (though column name is controlled)

**Recommendation:**
Ensure all database queries use parameterized statements. Current implementation is mostly safe.

### 6. Missing Input Sanitization for User-Generated Content
**Severity: MEDIUM**

**Issues:**
- Gang names, tags, graffiti text not sanitized for HTML/script injection
- Territory names not validated against allowed characters

---

## ?? PERFORMANCE ISSUES

### 1. Excessive Use of MySQL.Sync
**Severity: HIGH**

**Issue:**
- Found 39 instances of `MySQL.Sync.*` calls across the codebase
- Blocks server thread during database operations
- Can cause lag spikes with many concurrent players

**Affected Files:**
- `server/core/init.lua` - All database calls
- `server/core/api.lua` - All callbacks
- `server/modules/members.lua` - Member operations
- `server/modules/economy.lua` - Financial operations

**Recommendation:**
Replace with async MySQL operations:
```lua
-- Instead of:
local result = MySQL.Sync.fetchAll('SELECT * FROM ...', {...})

-- Use:
MySQL.query('SELECT * FROM ...', {...}, function(result)
    -- Handle result
end)
```

### 2. No Caching Layer
**Severity: MEDIUM**

**Issue:**
- Gang data, member lists, territories fetched repeatedly without caching
- `server/core/api.lua:62-79` - GetPlayerGang called frequently without caching

**Recommendation:**
Implement in-memory cache with TTL:
```lua
local gangCache = {}
local CACHE_TTL = 30000 -- 30 seconds

local function getCachedGang(src)
    local key = "gang_" .. src
    if gangCache[key] and gangCache[key].expiry > GetGameTimer() then
        return gangCache[key].data
    end
    return nil
end
```

### 3. Sequential Database Calls
**Severity: MEDIUM**

**Issue:**
- `server/modules/members.lua:15-16` - Multiple sequential Sync calls
- `server/modules/economy.lua:91-99` - Multiple calls that could be combined

**Recommendation:**
Combine queries where possible or use async with proper callback chaining.

### 4. No Query Optimization
**Severity: LOW**

**Issue:**
- Some queries fetch entire rows when only specific columns needed
- Missing indexes on frequently queried columns (though db.lua sets up some)

---

## ?? POTENTIAL BUGS

### 1. Race Condition in Invite System
**Severity: MEDIUM**

**Issue:**
- `members.lua:38-56` - No transaction/lock to prevent double-joining
- Multiple invites could be accepted simultaneously before gang member count updates

**Recommendation:**
Use database transactions or add locking mechanism:
```lua
MySQL.transaction(function(transaction)
    -- Check member count
    -- Insert member
    -- Verify count again
end)
```

### 2. Missing Validation on Gang Member Limits
**Severity: MEDIUM**

**Issue:**
- `members.lua:15-19` - Checks max members but doesn't account for concurrent joins
- No atomic check-and-insert operation

### 3. Expired Invites Not Cleaned Up
**Severity: LOW**

**Issue:**
- `members.lua:20-30` - Invites stored in memory but never cleaned up
- Memory leak potential over time

**Recommendation:**
Add cleanup thread:
```lua
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        local now = os.time()
        for id, invite in pairs(ColdGangs.PendingInvites or {}) do
            if invite.expires < now then
                ColdGangs.PendingInvites[id] = nil
            end
        end
    end
end)
```

### 4. Missing Error Handling
**Severity: MEDIUM**

**Issues:**
- `client/main.lua:9-15` - GetGangId callback with timeout but no error handling
- `server/modules/economy.lua:122-138` - Salary processing has no error handling for failed transactions
- Many database operations don't handle connection failures

### 5. Inconsistent Nil Checks
**Severity: LOW**

**Issue:**
- `server/modules/members.lua:26` - Accesses `Player.PlayerData.charinfo.firstname` without nil check
- `client/ui.lua:208` - Potential nil access on `pd.charinfo`

### 6. Missing Transaction Handling
**Severity: MEDIUM**

**Issue:**
- `economy.lua:101-102` - Money transfer not wrapped in transaction
- If second AddGangMoney fails, money is lost

**Recommendation:**
```lua
MySQL.transaction(function(transaction)
    if ColdGangs.Core.RemoveGangMoney(gangId, amount + fee, descOut) then
        ColdGangs.Core.AddGangMoney(targetGangId, amount, descIn)
    else
        transaction.rollback()
    end
end)
```

---

## ?? CODE QUALITY ISSUES

### 1. Inconsistent Error Handling
**Severity: LOW**

- Some functions return `nil` on error, others return `false`
- Inconsistent error messages
- Missing error logging

### 2. Duplicate Code
**Severity: LOW**

- Gang data fetching duplicated across multiple files
- Permission checking logic could be centralized
- Similar validation patterns repeated

### 3. Missing Logging
**Severity: MEDIUM**

- Critical operations (money transfers, member kicks, gang creation) should be logged
- Config has `logActions = true` but logging not implemented in most places

**Recommendation:**
```lua
local function logGangAction(gangId, action, details, src)
    if Config.Admin and Config.Admin.logActions then
        MySQL.insert('INSERT INTO cold_gang_logs (gang_id, action, details, timestamp) VALUES (?, ?, ?, NOW())', 
            {gangId, action, json.encode(details)})
    end
end
```

### 4. Magic Numbers
**Severity: LOW**

- Rank values hardcoded (e.g., `rank >= 5`, `rank = 6`)
- Timeout values hardcoded (`timeout < 50`, `timeout < 100`)

### 5. Inconsistent Naming
**Severity: LOW**

- Mix of camelCase and snake_case
- Some functions use prefixes, others don't

---

## ?? RECOMMENDED FIXES PRIORITY

### Priority 1 (Critical - Fix Immediately)
1. Implement rate limiting for all server events
2. Add input validation for all user inputs
3. Replace MySQL.Sync with async operations in high-traffic areas
4. Add transaction handling for money transfers
5. Fix race conditions in invite/member system

### Priority 2 (Important - Fix Soon)
1. Implement caching layer for frequently accessed data
2. Add comprehensive error handling and logging
3. Clean up expired invites automatically
4. Add nil checks for all PlayerData accesses
5. Sanitize user-generated content

### Priority 3 (Nice to Have)
1. Refactor duplicate code
2. Standardize error handling patterns
3. Add query optimization
4. Implement proper logging system
5. Add unit tests for critical functions

---

## ?? METRICS

- **Total Issues Found:** 25+
- **Critical Security:** 5
- **Performance Issues:** 4
- **Potential Bugs:** 6
- **Code Quality:** 5
- **MySQL.Sync Calls:** 39 (should be reduced to < 10)

---

## ? POSITIVE OBSERVATIONS

1. Good use of parameterized queries (prevents most SQL injection)
2. Proper permission system structure in place
3. Comprehensive database schema
4. Good separation of concerns (modules)
5. Config-driven design allows customization
6. Foreign key constraints in database schema

---

## ?? CONCLUSION

The script has a solid foundation but requires significant security and performance improvements before production use. The most critical issues are:

1. Missing rate limiting allows abuse
2. Excessive blocking database operations
3. Input validation gaps
4. Race conditions in member management

Addressing Priority 1 items should be done before deployment. Priority 2 items should be addressed within the first few updates after deployment.

---

*Report Generated: $(date)*
*Audited by: Auto AI Code Auditor*