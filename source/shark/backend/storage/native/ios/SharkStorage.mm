#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <string>

static NSString *sharkStoragePath(const char *path)
{
	return path != NULL ? [NSString stringWithUTF8String:path] : nil;
}

static double sharkStorageAttribute(const char *path, NSString *key)
{
	@autoreleasepool
	{
		NSString *target = sharkStoragePath(path);

		if (target == nil)
			return -1;

		NSError *error = nil;
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:target error:&error];
		NSNumber *value = attributes[key];

		return value != nil ? [value doubleValue] : -1;
	}
}

extern "C" const char *shark_storage_documents_directory()
{
	static std::string result;

	@autoreleasepool
	{
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		result = paths.count > 0 ? [(NSString *)paths.firstObject UTF8String] : "";
	}

	return result.c_str();
}

extern "C" double shark_storage_free_space(const char *path)
{
	return sharkStorageAttribute(path, NSFileSystemFreeSize);
}

extern "C" double shark_storage_total_space(const char *path)
{
	return sharkStorageAttribute(path, NSFileSystemSize);
}

extern "C" bool shark_storage_exclude_from_backup(const char *path)
{
	@autoreleasepool
	{
		NSString *target = sharkStoragePath(path);

		if (target == nil)
			return false;

		NSURL *url = [NSURL fileURLWithPath:target];
		NSError *error = nil;

		return [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error];
	}
}

extern "C" bool shark_storage_save_image_to_gallery(const char *path)
{
	@autoreleasepool
	{
		NSString *target = sharkStoragePath(path);

		if (target == nil)
			return false;

		UIImage *image = [UIImage imageWithContentsOfFile:target];

		if (image == nil)
			return false;

		dispatch_async(dispatch_get_main_queue(), ^{
			UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
		});

		return true;
	}
}
