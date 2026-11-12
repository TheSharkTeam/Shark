package shark.modding;

import shark.modding.api.ModVersion;
import shark.ui.debug.CrasherLog;

#if sys
import flixel.FlxG;
import polymod.Polymod;
import polymod.Polymod.ModMetadata;
import polymod.Polymod.PolymodError;
#end

class PolymodHandler
{
	public static var loadedModIds(default, null):Array<String> = [];

	public static function initialize():Void
	{
		#if sys
		if (!Module.ensureModsDirectory())
			return;

		var available:Array<String> = [for (meta in scan()) meta.id];
		var loaded:Array<ModMetadata> = Polymod.init({
			modRoot: Module.getModsDirectory(),
			dirs: available,
			framework: FLIXEL,
			apiVersionRule: apiVersionRule(),
			errorCallback: onPolymodError,
			ignoredFiles: Polymod.getDefaultIgnoreList()
		});

		loadedModIds = [for (meta in loaded) meta.id];
		#end
	}

	#if sys
	public static function scan():Array<ModMetadata>
	{
		return Polymod.scan({
			modRoot: Module.getModsDirectory(),
			apiVersionRule: apiVersionRule(),
			errorCallback: onPolymodError
		});
	}
	#end

	public static function reload():Void
	{
		#if sys
		loadedModIds = [for (meta in Polymod.reload()) meta.id];
		FlxG.bitmap.clearCache();
		#end
	}

	public static function getStatusSummary():String
	{
		return loadedModIds.length == 0 ? "Polymod: no mods loaded" : 'Polymod: ${loadedModIds.join(", ")}';
	}

	static function apiVersionRule():String
	{
		return '^${ModVersion.CURRENT}';
	}

	#if sys
	static function onPolymodError(error:PolymodError):Void
	{
		switch (error.severity)
		{
			case ERROR:
				CrasherLog.logWarning('Polymod error (${error.code}): ${error.message}', "mods");
			case WARNING:
				CrasherLog.addBreadcrumb('Polymod warning (${error.code}): ${error.message}', "mods");
			default:
		}
	}
	#end
}
