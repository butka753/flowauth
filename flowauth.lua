-- FlowAuth isolated console (исправленная версия)
return (function(...)
    local kind, protect, raise = type, pcall, error
    local getEnvironment, setEnvironment, compile = getfenv, setfenv, loadstring
    
    if kind(getEnvironment) ~= "function" or kind(setEnvironment) ~= "function" then
        return nil, "Silent execution is unavailable in this executor"
    end
    
    local base = getEnvironment()
    local inherited = rawget(base, "__flowauth_console_scope")
    local shared = base
    
    if kind(getgenv) == "function" then
        local ok, value = protect(getgenv)
        if ok and kind(value) == "table" then
            shared = value
        end
    end
    
    if kind(inherited) == "table" and kind(inherited.base) == "table" and kind(inherited.compile) == "function" then
        base, shared, compile = inherited.base, inherited.shared, inherited.compile
    end
    
    local unpackValues = table.unpack or unpack
    
    local function pack(...)
        return {n = select("#", ...), ...}
    end
    
    local quiet = true
    local pending = {}
    local authoredError
    local nativePrint, nativeWarn = base.print, base.warn
    local nativeRawGet, nativeRawSet = rawget, rawset
    
    local function output(fn, ...)
        if quiet == nil then
            if #pending < 32 then
                pending[#pending + 1] = {fn, pack(...)}
            end
        elseif not quiet and kind(fn) == "function" then
            fn(...)
        end
    end
    
    local function decide(value)
        if quiet ~= nil then return end
        quiet = value
        if not quiet then
            for _, entry in ipairs(pending) do
                if kind(entry[1]) == "function" then
                    entry[1](unpackValues(entry[2], 1, entry[2].n))
                end
            end
        end
        pending = {}
    end
    
    local scope, sharedScope = {}, {}
    setmetatable(scope, {__index = base, __newindex = base})
    setmetatable(sharedScope, {__index = shared, __newindex = shared})
    
    local function mutedPrint(...)
        output(nativePrint, ...)
    end
    
    local function mutedWarn(...)
        output(nativeWarn, ...)
    end
    
    local function scopedCompile(text, name)
        if kind(text) == "string" then
            local prefix = string.sub(text, 1, 256)
            if string.find(prefix, "-- FlowAuth console: silent", 1, true) then
                decide(true)
            elseif string.find(prefix, "-- FlowAuth console: normal", 1, true) then
                decide(false)
            end
        end
        
        local chunk, reason = compile(text, name)
        if kind(chunk) == "function" then
            if name == "=FlowAuth" or name == "=FlowAuthInit" or name == "=FlowAuthUI" then
                setEnvironment(chunk, base)
                local function authored(fn)
                    return function(...)
                        local values = pack(protect(fn, ...))
                        if not values[1] then
                            authoredError = values[2]
                            raise(values[2], 0)
                        end
                        if name == "=FlowAuthInit" and kind(values[2]) == "function" then
                            values[2] = authored(values[2])
                        end
                        return unpackValues(values, 2, values.n)
                    end
                end
                return authored(chunk)
            end
            setEnvironment(chunk, scope)
        end
        return chunk, reason
    end
    
    local function scopedRawGet(environment, key)
        if environment == scope or environment == sharedScope then
            local own = nativeRawGet(environment, key)
            if own ~= nil then return own end
            return nativeRawGet(environment == scope and base or shared, key)
        end
        return nativeRawGet(environment, key)
    end
    
    local function scopedRawSet(environment, key, value)
        if environment == scope then
            nativeRawSet(base, key, value)
            return environment
        end
        if environment == sharedScope then
            nativeRawSet(shared, key, value)
            return environment
        end
        return nativeRawSet(environment, key, value)
    end
    
    for _, environment in ipairs({scope, sharedScope}) do
        rawset(environment, "__flowauth_console_scope", {base = base, shared = shared, compile = compile})
        rawset(environment, "rawget", scopedRawGet)
        rawset(environment, "rawset", scopedRawSet)
        rawset(environment, "print", mutedPrint)
        rawset(environment, "warn", mutedWarn)
        rawset(environment, "loadstring", scopedCompile)
        rawset(environment, "getgenv", function() return sharedScope end)
        rawset(environment, "_G", sharedScope)
    end
    
    local function run(...)
        local credential = ...
        local type, pcall, error, tostring, tonumber = type, pcall, error, tostring, tonumber
        local rawset, getfenv = rawset, getfenv
        local globals, host = _G, game
        local byte, gsub, find = string.byte, string.gsub, string.find
        local wait = type(task) == "table" and task.wait
        local clock = os.clock
        local compile = loadstring
        
        local function member(value, key)
            local ok, result = pcall(function() return value[key] end)
            if ok then return result end
        end
        
        local spawn = member(task, "spawn")
        local fetch = member(host, "HttpGet")
        local ok, scriptEnv = pcall(function() return getfenv() end)
        if not ok or type(scriptEnv) ~= "table" then scriptEnv = globals end
        
        local ok, environment = pcall(function() return getgenv() end)
        if not ok or type(environment) ~= "table" then environment = scriptEnv end
        
        local function global(key)
            return member(environment, key) or member(scriptEnv, key) or member(globals, key)
        end
        
        local requests, seen = {}, {}
        local function add(fn, name)
            if type(fn) == "function" and not seen[fn] then
                seen[fn] = true
                requests[#requests + 1] = {fn, name}
            end
        end
        
        add(global("request"), "request")
        add(global("http_request"), "http_request")
        add(global("httpRequest"), "httpRequest")
        add(global("httprequest"), "httprequest")
        add(member(global("http"), "request"), "http.request")
        add(member(global("syn"), "request"), "syn.request")
        
        local bufferText = member(global("buffer"), "tostring")
        local url = "https://flowauth.net/assets/flowauth/sha256/f03ffd96e3e62f565b915205a4b225df4eaea4d5bd7368326adb20e71c18d99f7/v4_bootstrap_marbeag.lua"
        local fallback = "https://37.187.136.187/assets/flowauth/sha256/f03ffd96e3e62f565b915205a4b225df4eaea4d5bd7368326adb20e71c18d99f7/v4_bootstrap_marbeag.lua"
        local pinned = url .. "?retry=12fa5812daef5024"
        local retry = gsub(url, "/sha256/[a-f0-9]+/", "/") .. "?retry=12fa5812daef5024"
        local expected = 680955
        
        local runtime, reason, issue, priority = nil, nil, "request failed", 0
        local transport, issueTransport = "HttpGet", "HttpGet"
        
        local function problem(message, rank)
            if rank >= priority then
                issue, priority, issueTransport = message, rank, transport
            end
        end
        
        local function accept(value)
            if type(value) == "buffer" then
                local ok, text = pcall(bufferText, value)
                value = ok and text or nil
            end
            if type(value) ~= "string" then
                problem("unsupported response body", 1)
                return
            end
            if #value ~= expected then
                if #value < 1024 and find(value, "Failed to send HTTP request.", 1, true) then
                    problem(find(value, "timed out", 1, true) and "HTTP request timed out" or "HTTP request failed", 2)
                else
                    problem("received " .. #value .. " bytes; expected " .. expected, 2)
                end
                return
            end
            
            -- Adler-32 checksum
            local s1, s2, i = 1.0, 0.0, 1
            while i + 7 <= #value do
                local a, b, c, d, e, f, g, h = byte(value, i, i + 7)
                s2 = (s2 + 8 * s1 + 8 * a + 7 * b + 6 * c + 5 * d + 4 * e + 3 * f + 2 * g + h) % 65521
                s1 = (s1 + a + b + c + d + e + f + g + h) % 65521
                i = i + 8
            end
            while i <= #value do
                s1 = (s1 + byte(value, i)) % 65521
                s2 = (s2 + s1) % 65521
                i = i + 1
            end
            
            if s2 * 65536.0 + s1 ~= 668314204 then
                problem("runtime checksum mismatch", 3)
                return
            end
            
            local ok, compiled, detail = pcall(compile, value, "=FlowAuthRuntime")
            if ok and type(compiled) == "function" then
                runtime = compiled
                return true
            end
            reason = (ok and detail or compiled) or "compiler returned no function"
            return false
        end
        
        local candidates = {{fetch, "HttpGet", url}}
        if fallback ~= "" then
            candidates[#candidates + 1] = {fetch, "HttpGet", fallback, true}
        end
        for i = 1, #requests do
            local candidate = requests[i]
            if fallback ~= "" then
                candidates[#candidates + 1] = {candidate[1], candidate[2], fallback, true}
            end
            candidates[#candidates + 1] = {candidate[1], candidate[2], pinned}
        end
        candidates[#candidates + 1] = {fetch, "HttpGet", retry}
        
        local started, nextIndex, lastStart = clock(), 1, 0
        local jobs, closed, alternate = {}, false, false
        local asynchronous = type(spawn) == "function" and type(wait) == "function"
        
        local function launch()
            local candidate = candidates[nextIndex]
            nextIndex = nextIndex + 1
            lastStart = clock()
            local job = {name = candidate[2], alternate = candidate[4]}
            jobs[#jobs + 1] = job
            
            local function run()
                if closed or job.started then return end
                job.started = true
                local ok, response
                if job.name == "HttpGet" then
                    ok, response = pcall(candidate[1], host, candidate[3])
                else
                    ok, response = pcall(candidate[1], {Url = candidate[3], Method = "GET"})
                end
                if not closed then
                    job.ok, job.response, job.done = ok, response, true
                end
            end
            
            if asynchronous then
                local ok, thread = pcall(spawn, run)
                job.thread = ok and thread or nil
                if not job.started and type(job.thread) ~= "thread" then
                    asynchronous = false
                    run()
                end
            else
                run()
            end
        end
        
        launch()
        
        for poll = 1, 600 do
            if clock() - started >= 15 then
                problem("HTTP download timed out after 15 seconds", 4)
                break
            end
            
            local active, completed = 0, false
            for i = 1, #jobs do
                local job = jobs[i]
                if not job.done then
                    active = active + 1
                elseif not job.read then
                    job.read = true
                    completed = true
                    transport = job.name
                    local response = job.response
                    job.response = nil
                    
                    if not job.ok then
                        problem("request failed", 1)
                    elseif type(response) == "table" then
                        local status = tonumber(member(response, "StatusCode") or member(response, "status_code") or member(response, "Status") or member(response, "status")) or 0
                        local success = member(response, "Success")
                        if success == nil then success = member(response, "success") end
                        if status == 0 and success == true then status = 200 end
                        if success == false and status < 400 then status = 500 end
                        if status >= 200 and status < 300 then
                            accept(member(response, "Body") or member(response, "body") or member(response, "ResponseBody") or member(response, "response_body"))
                        else
                            problem("HTTP " .. status, 2)
                        end
                    else
                        accept(response)
                    end
                    
                    if runtime or reason then
                        alternate = job.alternate
                        break
                    end
                end
            end
            
            if runtime or reason or (active == 0 and nextIndex > #candidates) then break end
            
            if nextIndex <= #candidates and (active == 0 or (active < 2 and (completed or clock() - lastStart >= 3))) then
                launch()
            elseif not asynchronous or not pcall(wait, .03) then
                problem("HTTP download wait unavailable", 4)
                break
            end
        end
        
        closed = true
        for i = 1, #jobs do
            jobs[i].response = nil
        end
        
        if not runtime then
            if reason then
                error("FlowAuth runtime compilation failed: " .. tostring(reason), 0)
            end
            error("FlowAuth runtime download failed (" .. issueTransport .. "): " .. tostring(issue) .. ". Please run the loader again.", 0)
        end
        
        if asynchronous then pcall(wait) end
        
        local handoff = alternate and {
            "\022\192\171\187\061\026\108\002\079\243\159\248\138\247\240\071\091\012\209\229\170\125\223\144\076\124\190\037\111\133\212\182\239\077\090\174\084\246\042\186\133\104\204\194\209\049\166\018\161\098\254\053\210\173\206\034\251\203\176\022\251\246\163\191\183\155\009\251\040\099\036\039\205\057\065\136\252\051\089\232\136\089\205\069\193\035\167\220\182\187\215\010\088\232\153\158\111\052\033\171\203\128\158\240\058\225\001\241\067\226\226\084\081\209\196\207\077\090\201\040\245\008\053\120\215\212\136\189\022\010\066\075\106\083\104\215\199\015\009\023\063\035\035\225\129\026\226\023\133\128\216\098\140\135\020\040\143\053\231\149\118\215\200\208\187\109\217\182\020\228\091\198\179\062\018\124\204\242\143\159\079\215\224\076\073\069\044\145\249\222\069\176\039\151\213\238\239\164\002\091\242\234\085\151\170\137\098\097\075\111\070\254\097\010\044\081\183\065\118\061\201\028\104\130\044\001\026\103\111\090\038\194\004\142\123\239\080\038\071\181\180\201\102\137\021\007\220\032\101\166\152\154\231\012\181\075\031\170\186\232\208\222\018\147\105\026\048\052\109\201\016\072\240\043\099\100\198\175\232\141\044\124\191\247\246\082\212\127\066\009\002\129\174\246\169\033\157\220\007\084\068\246\013\045\027\016\160",
            1100097070,
            3711722449
        } or {
            "\065\009\026\250\238\156\244\085\081\157\192\090\200\185\113\078\233\062\208\082\143\058\216\104\100\113\134\015\183\148\241\172\032\228\253\069\191\035\084\190\001\032\111\123\143\195\086\216\190\013\111\217\171\171\248\127\144\173\075\082\251\016\002\153\005\017\083\175\186\223\093\040\191\245\088\050\163\196\090\193\173\041\039\059\215\238\190\071\122\197\054\029\141\054\233\076\090\184\237\090\210\075\143\107\093\002\074\103\105\057\095\032\133\140\137\056\168\102\207\129\171\091\043\220\029\077\229\051\074\216\105\116\166\022\231\001\025\164\015\252\119\027\132\073\200\027\074\245\221\131\087\015\054\107\216\049\213\086\036\089\087\129\147\251\180\184\109\000\240\179\148\078\234\036\075\238\109\249\000\255\130\100\032\151\018\075\050\109\065\068\163\226\150\198\065\089\000\124\107\109\246\081\017\174\235\251\193\047\184\088\014\226\126\113\244\234\179\029\039\223\113\065\161\109\159\123\111\126\175\017\069\223\203\018\224\133\023\038\204\022\120\188\139\048\009\014\006\215\241\159\034\109\115\012\212\025\067\229\054\124\065\194\229\133\255\126\000\074\159\066\174\220\040\101\023\110\060\003\204\138\034\194\066\045\162\040\109\254\223\104\195\144\189\178\166\121\094\150\141\005\173\142\142\167\131",
            4203384944,
            3406390752
        }
        
        local function publish(target)
            if type(target) == "table" then
                pcall(rawset, target, "_bsdata0", handoff)
            end
        end
        
        publish(environment)
        publish(globals)
        _bsdata0 = handoff
        pcall(function() publish(getfenv(runtime)) end)
        handoff = nil
        return runtime(credential)
    end
    
    setEnvironment(run, scope)
    local result = pack(protect(run, ...))
    if not result[1] then
        if quiet == false or (authoredError ~= nil and authoredError == result[2]) then
            raise(result[2], 0)
        end
        return nil, result[2]
    end
    return unpackValues(result, 2, result.n)
end)(...)
