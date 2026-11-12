package shark.macros;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr.Field;
import sys.FileSystem;
#end

class NativeSource
{
	public static macro function include(file:String):Array<Field>
	{
		var localClass = Context.getLocalClass().get();
		var directory:String = Path.directory(FileSystem.fullPath(Context.getPosInfos(localClass.pos).file));
		var source:String = Path.normalize('$directory/$file');

		if (!FileSystem.exists(source))
			Context.error('Native source not found: $source', localClass.pos);

		localClass.meta.add(":buildXml", [macro $v{'<files id="haxe"><file name="$source" /></files>'}], localClass.pos);

		return Context.getBuildFields();
	}
}
