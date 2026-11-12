package shark.modding;

import shark.scripting.SharkScript;

#if sys
import sys.io.File;
import sys.FileSystem;
import lime.system.System;
#end

class Module
{
	public static inline var MODS_FOLDER:String = "mods";
	public static inline var SCRIPT_EXTENSION:String = "hxs";
	public static inline var MOD_META_FILE:String = "_polymod_meta.json";
	public static inline var MOD_SCRIPTS_FOLDER:String = "scripts";

	public var name(default, null):String;
	public var isLoaded(default, null):Bool = false;
	public var isEnabled:Bool = true;
	public var lastError(default, null):String;

	var script:SharkScript;

	public function new(name:String)
	{
		this.name = name;
		script = new SharkScript();
	}

	public function bind(apiName:String, value:Dynamic):Void
	{
		script.expose(apiName, value);
	}

	public function bindAll(values:Map<String, Dynamic>):Void
	{
		script.exposeMultiple(values);
	}

	public function load():Bool
	{
		var code:String = readModuleFile(name);

		if (code == null)
		{
			lastError = 'Module file not found: $name.$SCRIPT_EXTENSION';
			isLoaded = false;
			return false;
		}

		var result = script.run(code);

		isLoaded = result.success;
		lastError = result.error;

		if (isLoaded)
			callHook("onCreate");

		return isLoaded;
	}

	public function loadFromSource(code:String):Bool
	{
		var result = script.run(code);

		isLoaded = result.success;
		lastError = result.error;

		if (isLoaded)
			callHook("onCreate");

		return isLoaded;
	}

	public function callHook(hookName:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!isLoaded || !isEnabled)
			return null;

		return script.callFunction(hookName, args);
	}

	public function hasHook(hookName:String):Bool
	{
		return isLoaded && script.hasFunction(hookName);
	}

	public function update(elapsed:Float):Void
	{
		if (hasHook("onUpdate"))
			callHook("onUpdate", [elapsed]);
	}

	public function destroy():Void
	{
		if (isLoaded)
			callHook("onDestroy");

		isLoaded = false;
		isEnabled = false;
	}

	public function reload():Bool
	{
		script.reset();
		return load();
	}

	public function getOutput():Array<String>
	{
		return script.getOutput();
	}

	public function getScriptHistory()
	{
		return script.getHistory();
	}

	static function readModuleFile(name:String):String
	{
		#if sys
		try
		{
			var path:String = getModulePath(name);

			if (!FileSystem.exists(path))
				return null;

			return File.getContent(path);
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	public static function getModsDirectory():String
	{
		#if sys
		var base:String = System.applicationStorageDirectory;

		if (!StringTools.endsWith(base, "/") && !StringTools.endsWith(base, "\\"))
			base += "/";

		return base + MODS_FOLDER;
		#else
		return "";
		#end
	}

	public static function getModulePath(name:String):String
	{
		return '${getModsDirectory()}/$name.$SCRIPT_EXTENSION';
	}

	public static function ensureModsDirectory():Bool
	{
		#if sys
		try
		{
			var path:String = getModsDirectory();

			if (!FileSystem.exists(path))
				FileSystem.createDirectory(path);

			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function listAvailableModules():Array<String>
	{
		#if sys
		var root:String = getModsDirectory();

		if (!FileSystem.exists(root))
			return [];

		var names:Array<String> = scriptsIn(root, "");

		for (entry in FileSystem.readDirectory(root))
		{
			var folder:String = '$root/$entry';

			if (FileSystem.isDirectory(folder) && FileSystem.exists('$folder/$MOD_META_FILE') && FileSystem.exists('$folder/$MOD_SCRIPTS_FOLDER'))
				names = names.concat(scriptsIn('$folder/$MOD_SCRIPTS_FOLDER', '$entry/$MOD_SCRIPTS_FOLDER/'));
		}

		return names;
		#else
		return [];
		#end
	}

	#if sys
	static function scriptsIn(path:String, prefix:String):Array<String>
	{
		var suffix:String = "." + SCRIPT_EXTENSION;

		return [
			for (fileName in FileSystem.readDirectory(path))
				if (StringTools.endsWith(fileName, suffix))
					prefix + fileName.substr(0, fileName.length - suffix.length)
		];
	}
	#end
}
