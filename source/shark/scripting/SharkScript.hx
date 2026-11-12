package shark.scripting;

import hscript.Parser;
import hscript.Interp;
import hscript.Expr;
import haxe.Timer;
import haxe.crypto.Md5;
import shark.ui.security.Guard;
import shark.ui.debug.CrasherLog;

typedef ScriptResult = {
    success:Bool,
    value:Dynamic,
    ?error:String,
    ?executionTimeMs:Float
}

typedef ScriptHistoryEntry = {
    codeSnippet:String,
    success:Bool,
    executionTimeMs:Float,
    timestamp:Float
}

class SharkScript
{
    public static var maxScriptLength:Int = 5000;
    public static var slowScriptThresholdMs:Float = 50;
    public static var rateLimitBucket:String = "hscript";
    public static var enforceRateLimit:Bool = true;
    public static inline var MAX_HISTORY:Int = 20;
    public static var maxCacheEntries:Int = 64;
    public static var maxOutputEntries:Int = 256;
    public static var maxOutputLength:Int = 2048;

    public var lastResult(default, null):ScriptResult;
    public var executionCount(default, null):Int = 0;
    public var failureCount(default, null):Int = 0;
    public var cacheHits(default, null):Int = 0;
    public var totalExecutionTimeMs(default, null):Float = 0;

    var parser:Parser;
    var interp:Interp;
    var exposedVariables:Map<String, Dynamic> = new Map();
    var astCache:Map<String, Expr> = new Map();
    var cacheOrder:Array<String> = [];
    var output:Array<String> = [];
    var history:Array<ScriptHistoryEntry> = [];
    var running:Bool = false;

    public function new()
    {
        parser = new Parser();
        interp = new Interp();
        exposeDefaults();
    }

    function exposeDefaults():Void
    {
        expose("Math", Math);
        expose("Std", Std);
        expose("StringTools", StringTools);
        expose("print", function(value:Dynamic):Void
        {
            if (output.length >= maxOutputEntries)
                return;

            var message:String = Std.string(value);
            if (maxOutputLength >= 0 && message.length > maxOutputLength)
                message = message.substr(0, maxOutputLength);
            output.push(message);
        });
    }

    public function expose(name:String, value:Dynamic):Void
    {
        if (name == null || StringTools.trim(name).length == 0)
            return;

        exposedVariables.set(name, value);
        interp.variables.set(name, value);
    }

    public function exposeMultiple(values:Map<String, Dynamic>):Void
    {
        if (values == null)
            return;

        for (name => value in values)
            expose(name, value);
    }

    public function unexpose(name:String):Void
    {
        if (name == null)
            return;

        exposedVariables.remove(name);
        interp.variables.remove(name);
    }

    public function run(code:String):ScriptResult
    {
        if (running)
            return failure("Script execution already in progress", 0);

        if (code == null)
            return failure("Empty script", 0);

        if (maxScriptLength >= 0 && code.length > maxScriptLength)
            return failure('Script exceeds $maxScriptLength characters', 0);

        if (enforceRateLimit && !Guard.checkAndRegister(rateLimitBucket))
            return failure("Too many scripts running, please slow down", 0);

        var sanitized:String;
        try
        {
            sanitized = Guard.sanitizeInput(code);
        }
        catch (e:Dynamic)
        {
            return failure('Input validation failed: ${Std.string(e)}', 0);
        }

        if (sanitized == null || StringTools.trim(sanitized).length == 0)
            return failure("Empty script", 0);

        if (maxScriptLength >= 0 && sanitized.length > maxScriptLength)
            return failure('Script exceeds $maxScriptLength characters', 0);

        var startTime:Float = nowMs();
        running = true;
        output = [];

        try
        {
            var expr:Expr = getOrParse(sanitized);
            var value:Dynamic = interp.execute(expr);
            var elapsed:Float = nowMs() - startTime;
            finish(sanitized, true, elapsed);
            lastResult = {success: true, value: value, executionTimeMs: elapsed};
            running = false;
            return lastResult;
        }
        catch (e:hscript.Expr.Error)
        {
            var elapsed:Float = nowMs() - startTime;
            finish(sanitized, false, elapsed);
            lastResult = {success: false, value: null, error: 'Parse error: ${Std.string(e)}', executionTimeMs: elapsed};
            running = false;
            return lastResult;
        }
        catch (e:Dynamic)
        {
            var elapsed:Float = nowMs() - startTime;
            finish(sanitized, false, elapsed);
            lastResult = {success: false, value: null, error: Std.string(e), executionTimeMs: elapsed};
            running = false;
            return lastResult;
        }
    }

    function getOrParse(code:String):Expr
    {
        var key:String = Md5.encode(code);
        var cached:Expr = astCache.get(key);
        if (cached != null)
        {
            cacheHits++;
            cacheOrder.remove(key);
            cacheOrder.push(key);
            return cached;
        }

        var expr:Expr = parser.parseString(code);
        if (maxCacheEntries > 0)
        {
            while (cacheOrder.length >= maxCacheEntries)
            {
                var oldest:String = cacheOrder.shift();
                astCache.remove(oldest);
            }
            astCache.set(key, expr);
            cacheOrder.push(key);
        }
        return expr;
    }

    function finish(code:String, success:Bool, elapsed:Float):Void
    {
        executionCount++;
        if (!success)
            failureCount++;
        totalExecutionTimeMs += elapsed;
        recordHistory(code, success, elapsed);
        warnIfSlow(elapsed);
    }

    function failure(message:String, elapsed:Float):ScriptResult
    {
        lastResult = {success: false, value: null, error: message, executionTimeMs: elapsed};
        return lastResult;
    }

    static function nowMs():Float
    {
        return Timer.stamp() * 1000;
    }

    function warnIfSlow(elapsedMs:Float):Void
    {
        if (slowScriptThresholdMs >= 0 && elapsedMs > slowScriptThresholdMs)
            CrasherLog.logWarning('Slow hscript execution: ${Math.round(elapsedMs)}ms');
    }

    function recordHistory(code:String, success:Bool, elapsedMs:Float):Void
    {
        var snippet:String = code.length > 60 ? code.substr(0, 60) + "..." : code;
        history.push({
            codeSnippet: snippet,
            success: success,
            executionTimeMs: elapsedMs,
            timestamp: Date.now().getTime() / 1000
        });
        while (history.length > MAX_HISTORY)
            history.shift();
    }

    public function getHistory():Array<ScriptHistoryEntry>
    {
        return history.copy();
    }

    public function callFunction(name:String, ?args:Array<Dynamic>):Dynamic
    {
        if (name == null || !interp.variables.exists(name))
            return null;
        var fn:Dynamic = interp.variables.get(name);
        if (!Reflect.isFunction(fn))
            return null;
        try
        {
            return Reflect.callMethod(null, fn, args != null ? args : []);
        }
        catch (e:Dynamic)
        {
            CrasherLog.logWarning('HScript function $name failed: ${Std.string(e)}');
            return null;
        }
    }

    public function hasFunction(name:String):Bool
    {
        return name != null && interp.variables.exists(name) && Reflect.isFunction(interp.variables.get(name));
    }

    public function getOutput():Array<String>
    {
        return output.copy();
    }

    public function getVariable(name:String):Dynamic
    {
        return name != null ? interp.variables.get(name) : null;
    }

    public function setVariable(name:String, value:Dynamic):Void
    {
        expose(name, value);
    }

    public function hasVariable(name:String):Bool
    {
        return name != null && interp.variables.exists(name);
    }

    public function clearOutput():Void
    {
        output = [];
    }

    public function reset():Void
    {
        if (running)
            return;
        interp = new Interp();
        for (name => value in exposedVariables)
            interp.variables.set(name, value);
        output = [];
        lastResult = null;
    }

    public function clearCache():Void
    {
        astCache = new Map();
        cacheOrder = [];
        cacheHits = 0;
    }

    public function clearHistory():Void
    {
        history = [];
    }

    public function resetStatistics():Void
    {
        executionCount = 0;
        failureCount = 0;
        cacheHits = 0;
        totalExecutionTimeMs = 0;
    }
}
