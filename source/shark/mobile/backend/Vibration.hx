package shark.mobile.backend;

import haxe.Timer;

#if (android || ios)
import lime.ui.Haptic;
#end

#if js
import js.Browser;
#end

enum abstract HapticStyle(Int)
{
	var LIGHT = 0;
	var MEDIUM = 1;
	var HEAVY = 2;
	var SELECTION = 3;
	var SUCCESS = 4;
	var WARNING = 5;
	var FAILURE = 6;
	var NOTIFICATION = 7;
}

class Vibration
{
	static inline var MIN_INTERVAL_MS:Float = 40;

	public static var enabled(default, null):Bool = true;
	public static var globalIntensity(default, null):Float = 1;

	static var reducedMotionProvider:Void->Bool;
	static var lastTriggerTimeMs:Float = -1000;
	static var totalTriggers:Int = 0;
	static var totalSkipped:Int = 0;
	static var lastStyle:HapticStyle = LIGHT;

	public static function trigger(style:HapticStyle, critical:Bool = false):Void
	{
		if (!canPlay(critical))
		{
			totalSkipped++;
			return;
		}

		var base:Array<Int> = patternFor(style);
		var pattern:Array<Int> = [for (i in 0...base.length) i % 2 == 0 ? Std.int(Math.max(1, base[i] * globalIntensity)) : base[i]];

		lastStyle = style;
		lastTriggerTimeMs = Timer.stamp() * 1000;
		totalTriggers++;

		play(pattern);
	}

	public static function menuSelect():Void
	{
		trigger(SELECTION);
	}

	public static function menuConfirm():Void
	{
		trigger(MEDIUM);
	}

	public static function cancel():Void
	{
		#if js
		if (hasWebVibration())
			Browser.navigator.vibrate(0);
		#end
	}

	public static function setEnabled(value:Bool):Void
	{
		enabled = value;

		if (!value)
			cancel();
	}

	public static function setGlobalIntensity(value:Float):Void
	{
		globalIntensity = Math.max(0, Math.min(1, value));
	}

	public static function setReducedMotionProvider(provider:Void->Bool):Void
	{
		reducedMotionProvider = provider;
	}

	public static function isSupported():Bool
	{
		#if (android || ios)
		return true;
		#elseif js
		return hasWebVibration();
		#else
		return false;
		#end
	}

	public static function getStatusSummary():String
	{
		return 'enabled: $enabled, supported: ${isSupported()}, intensity: $globalIntensity\n'
			+ 'triggers: $totalTriggers, skipped: $totalSkipped, last style: $lastStyle';
	}

	static function canPlay(critical:Bool):Bool
	{
		if (!enabled || globalIntensity <= 0 || !isSupported())
			return false;

		if (critical)
			return true;

		if (reducedMotionProvider != null && reducedMotionProvider())
			return false;

		return Timer.stamp() * 1000 - lastTriggerTimeMs >= MIN_INTERVAL_MS;
	}

	static function play(pattern:Array<Int>):Void
	{
		#if (android || ios)
		if (pattern.length == 1)
			Haptic.vibrate(0, pattern[0]);
		else
			playPulses(pattern, 0);
		#elseif js
		Browser.navigator.vibrate(pattern);
		#end
	}

	#if (android || ios)
	static function playPulses(pattern:Array<Int>, index:Int):Void
	{
		if (index >= pattern.length)
			return;

		Haptic.vibrate(0, pattern[index]);

		var gap:Int = index + 1 < pattern.length ? pattern[index + 1] : 0;

		Timer.delay(() -> playPulses(pattern, index + 2), pattern[index] + gap);
	}
	#end

	#if js
	static function hasWebVibration():Bool
	{
		return Browser.navigator != null && Reflect.hasField(Browser.navigator, "vibrate");
	}
	#end

	static function patternFor(style:HapticStyle):Array<Int>
	{
		return switch (style)
		{
			case LIGHT: [10];
			case MEDIUM: [20];
			case HEAVY: [35];
			case SELECTION: [8];
			case SUCCESS: [15, 50, 15];
			case WARNING: [25, 80, 25];
			case FAILURE: [40, 60, 40, 60, 40];
			case NOTIFICATION: [20, 100, 20, 100, 20];
		}
	}
}
