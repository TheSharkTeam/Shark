package shark.system;

import shark.system.WindowInput;
import shark.system.PerformanceManager;
import shark.system.Diagnostics;
import shark.ui.security.Guard;

#if cpp
import shark.native.CPP;
#end

class NativeSystems
{
	public static var isInitialized(default, null):Bool = false;

	public static function initialize():Void
	{
		if (isInitialized)
			return;

		isInitialized = true;

		PerformanceManager.initialize();
		WindowInput.initialize();
	}

	public static var platform(get, never):String;

	static function get_platform():String
	{
		return PerformanceManager.getPlatformName();
	}

	public static var isMobile(get, never):Bool;

	static function get_isMobile():Bool
	{
		return PerformanceManager.isMobileTarget;
	}

	public static var isDesktop(get, never):Bool;

	static function get_isDesktop():Bool
	{
		return PerformanceManager.isDesktopTarget;
	}

	public static var isWeb(get, never):Bool;

	static function get_isWeb():Bool
	{
		return PerformanceManager.isWebTarget;
	}

	public static var isDebugBuild(get, never):Bool;

	static function get_isDebugBuild():Bool
	{
		return PerformanceManager.isDebugBuild;
	}

	public static var isLowEndDevice(get, never):Bool;

	static function get_isLowEndDevice():Bool
	{
		return Diagnostics.isLowEndDevice;
	}

	public static function showKeyboard():Void
	{
		WindowInput.showSoftKeyboard();
	}

	public static function hideKeyboard():Void
	{
		WindowInput.hideSoftKeyboard();
	}

	public static function getPerformanceSummary():String
	{
		return PerformanceManager.getPerformanceSummary();
	}

	public static function getDiagnostics():String
	{
		return Diagnostics.getDiagnosticsReport();
	}

	public static function getBuildSummary():String
	{
		return PerformanceManager.getBuildSummary();
	}

	public static function getMemoryUsageMB():Float
	{
		#if cpp
		return CPP.getMemoryUsageMB();
		#else
		return 0;
		#end
	}

	public static function collectGarbage(major:Bool = false):Void
	{
		#if cpp
		CPP.collectGarbage(major);
		#end
	}

	public static function getCpuCoreCount():Int
	{
		#if cpp
		return CPP.getCpuCoreCount();
		#else
		return 1;
		#end
	}

	public static function generateSecureToken(length:Int = 16):String
	{
		return Guard.generateToken(length);
	}
}
