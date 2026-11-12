package shark.backend.storage;

#if android
import lime.system.JNI;
#end

class NativeStorage
{
	public static function getExternalDirectory():String
	{
		#if android
		return nonEmpty(callAndroid("getExternalFilesDirectory", "()Ljava/lang/String;", []));
		#elseif ios
		return nonEmpty(IOSStorage.documentsDirectory());
		#else
		return null;
		#end
	}

	public static function getFreeSpace(path:String):Float
	{
		#if android
		return callAndroid("getFreeSpace", "(Ljava/lang/String;)D", [path], -1);
		#elseif ios
		return IOSStorage.freeSpace(path);
		#else
		return -1;
		#end
	}

	public static function getTotalSpace(path:String):Float
	{
		#if android
		return callAndroid("getTotalSpace", "(Ljava/lang/String;)D", [path], -1);
		#elseif ios
		return IOSStorage.totalSpace(path);
		#else
		return -1;
		#end
	}

	public static function hasGalleryPermission():Bool
	{
		#if android
		return callAndroid("hasGalleryPermission", "()Z", [], false);
		#else
		return isGallerySupported();
		#end
	}

	public static function requestGalleryPermission():Void
	{
		#if android
		callAndroid("requestGalleryPermission", "()V", []);
		#end
	}

	public static function isGallerySupported():Bool
	{
		#if (android || ios)
		return true;
		#else
		return false;
		#end
	}

	public static function saveImageToGallery(path:String, title:String):Bool
	{
		#if android
		return callAndroid("saveImageToGallery", "(Ljava/lang/String;Ljava/lang/String;)Z", [path, title], false);
		#elseif ios
		return IOSStorage.saveImageToGallery(path);
		#else
		return false;
		#end
	}

	public static function excludeFromBackup(path:String):Bool
	{
		#if ios
		return IOSStorage.excludeFromBackup(path);
		#else
		return true;
		#end
	}

	static function nonEmpty(value:String):String
	{
		return value != null && value.length > 0 ? value : null;
	}

	#if android
	static final ANDROID_CLASS:String = "com/brenninho/shark/SharkStorage";
	static var methods:Map<String, Dynamic> = new Map();

	static function callAndroid(name:String, signature:String, args:Array<Dynamic>, ?fallback:Dynamic):Dynamic
	{
		try
		{
			if (!methods.exists(name))
				methods.set(name, JNI.createStaticMethod(ANDROID_CLASS, name, signature));

			return Reflect.callMethod(null, methods.get(name), args);
		}
		catch (e:Dynamic)
		{
			return fallback;
		}
	}
	#end
}

#if ios
@:build(shark.macros.NativeSource.include("native/ios/SharkStorage.mm"))
@:headerCode('
extern "C" {
	const char *shark_storage_documents_directory();
	double shark_storage_free_space(const char *path);
	double shark_storage_total_space(const char *path);
	bool shark_storage_exclude_from_backup(const char *path);
	bool shark_storage_save_image_to_gallery(const char *path);
}
')
private class IOSStorage
{
	public static function documentsDirectory():String
	{
		return untyped __cpp__("::String(shark_storage_documents_directory())");
	}

	public static function freeSpace(path:String):Float
	{
		return untyped __cpp__("shark_storage_free_space({0}.utf8_str())", path);
	}

	public static function totalSpace(path:String):Float
	{
		return untyped __cpp__("shark_storage_total_space({0}.utf8_str())", path);
	}

	public static function excludeFromBackup(path:String):Bool
	{
		return untyped __cpp__("shark_storage_exclude_from_backup({0}.utf8_str())", path);
	}

	public static function saveImageToGallery(path:String):Bool
	{
		return untyped __cpp__("shark_storage_save_image_to_gallery({0}.utf8_str())", path);
	}
}
#end
