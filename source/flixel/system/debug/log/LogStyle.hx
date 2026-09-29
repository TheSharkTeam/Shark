package flixel.system.debug.log;

import flixel.system.debug.log.FlxLogStyle;
import flixel.util.FlxColor;
import haxe.PosInfos;

/**
 * A class that allows you to create a custom style for `FlxG.log.advanced()`.
 * Also used internally for the pre-defined styles.
 *
 * This is a local override of flixel's own `LogStyle`. The upstream version declares static
 * fields literally named `ERROR` and `WARNING`, which makes hxcpp emit those exact identifiers
 * as C++ symbols. On Windows that collides with the `ERROR` macro from `wingdi.h`
 * (`#define ERROR 0`, pulled in transitively by some other native dependency after hxcpp's own
 * `hx/Undefine.h` protection already ran for this translation unit) and fails native compilation
 * with "syntax error: 'constant'". Renaming the fields isn't safe here: flixel's own
 * `LogFrontEnd.hx` writes to them via `@:bypassAccessor` from a different generated file, and a
 * renamed field's bypassed write loses its enclosing-class qualifier there (a separate hxcpp
 * codegen gap). Instead, `@:headerCode` injects a defensive `#undef` directly into this shared
 * generated header, right before the risky declarations, regardless of what polluted the macro
 * namespace earlier in whichever file includes it.
 */
@:forward
@:deprecated("LogStyle is deprecated, use FlxLogStyle, instead")
@:headerCode("
#ifdef ERROR
#undef ERROR
#endif
#ifdef WARNING
#undef WARNING
#endif
")
abstract LogStyle(FlxLogStyle) from FlxLogStyle to FlxLogStyle
{
	@:deprecated("LogStyle.NORMAL is deprecated, use FlxG.log.styles.NORMAL, instead")
	public static var NORMAL(default, set):LogStyle;
	static function set_NORMAL(style:LogStyle)
	{
		@:bypassAccessor
		FlxG.log.styles.normal = style;
		return NORMAL = style;
	}

	@:deprecated("LogStyle.WARNING is deprecated, use FlxG.log.styles.WARNING, instead")
	public static var WARNING(default, set):LogStyle;
	static function set_WARNING(style:LogStyle)
	{
		@:bypassAccessor
		FlxG.log.styles.warning = style;
		return WARNING = style;
	}

	@:deprecated("LogStyle.ERROR is deprecated, use FlxG.log.styles.ERROR, instead")
	public static var ERROR(default, set):LogStyle;
	static function set_ERROR(style:LogStyle)
	{
		@:bypassAccessor
		FlxG.log.styles.error = style;
		return ERROR = style;
	}

	@:deprecated("LogStyle.NOTICE is deprecated, use FlxG.log.styles.NOTICE, instead")
	public static var NOTICE(default, set):LogStyle;
	static function set_NOTICE(style:LogStyle)
	{
		@:bypassAccessor
		FlxG.log.styles.notice = style;
		return NOTICE = style;
	}

	@:deprecated("LogStyle.CONSOLE is deprecated, use FlxG.log.styles.CONSOLE, instead")
	public static var CONSOLE(default, set):LogStyle;
	static function set_CONSOLE(style:LogStyle)
	{
		@:bypassAccessor
		FlxG.log.styles.console = style;
		return CONSOLE = style;
	}

	public var color(get, set):String;
	inline function get_color() return this.format.getColorString();
	inline function set_color(value:String) return this.format.setColorString(value);

	public var size(get, set):Int;
	inline function get_size() return this.format.size;
	inline function set_size(value:Int) return this.format.size = value;

	public var bold(get, set):Bool;
	inline function get_bold() return this.format.bold;
	inline function set_bold(value:Bool) return this.format.bold = value;

	public var italic(get, set):Bool;
	inline function get_italic() return this.format.italic;
	inline function set_italic(value:Bool) return this.format.italic = value;

	public var underlined(get, set):Bool;
	inline function get_underlined() return this.format.underlined;
	inline function set_underlined(value:Bool) return this.format.underlined = value;

	@:deprecated("LogStyle is deprecated, use FlxLogStyle, instead")
	public function new(prefix = "", color = "FFFFFF", size = 12, bold = false, italic = false, underlined = false,
			?errorSound:String, openConsole = false, ?callbackFunction:()->Void, ?callback:(Any, ?PosInfos)->Void, throwException = false)
	{
		final format = new FlxLogFormat(FlxColor.fromString('#$color'), size, bold, italic, underlined);
		this = new FlxLogStyle(prefix, format, errorSound, openConsole, throwException);

		this.callbackFunction = callbackFunction;
		if (callback != null)
			this.onLog.add(callback);
	}
}
