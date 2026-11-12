package com.brenninho.shark;

import android.Manifest;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.StatFs;
import android.provider.MediaStore;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import org.haxe.extension.Extension;

public class SharkStorage {
	private static final String GALLERY_FOLDER = "Shark";
	private static final int PERMISSION_REQUEST_CODE = 7301;

	public static String getExternalFilesDirectory() {
		File directory = Extension.mainContext.getExternalFilesDir(null);
		return directory != null ? directory.getAbsolutePath() : "";
	}

	public static double getFreeSpace(String path) {
		try {
			return (double) new StatFs(path).getAvailableBytes();
		} catch (Exception e) {
			return -1;
		}
	}

	public static double getTotalSpace(String path) {
		try {
			return (double) new StatFs(path).getTotalBytes();
		} catch (Exception e) {
			return -1;
		}
	}

	public static boolean hasGalleryPermission() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
			return true;
		}

		return Extension.mainContext.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
	}

	public static void requestGalleryPermission() {
		if (hasGalleryPermission()) {
			return;
		}

		final Activity activity = Extension.mainActivity;

		activity.runOnUiThread(new Runnable() {
			@Override
			public void run() {
				activity.requestPermissions(new String[] { Manifest.permission.WRITE_EXTERNAL_STORAGE }, PERMISSION_REQUEST_CODE);
			}
		});
	}

	public static boolean saveImageToGallery(String path, String title) {
		File source = new File(path);

		if (!source.isFile()) {
			return false;
		}

		try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				return saveWithMediaStore(source, title);
			}

			return saveToPicturesFolder(source, title);
		} catch (Exception e) {
			return false;
		}
	}

	private static boolean saveWithMediaStore(File source, String title) throws IOException {
		ContentResolver resolver = Extension.mainContext.getContentResolver();
		ContentValues values = new ContentValues();

		values.put(MediaStore.Images.Media.DISPLAY_NAME, title + ".png");
		values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
		values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/" + GALLERY_FOLDER);
		values.put(MediaStore.Images.Media.IS_PENDING, 1);

		Uri uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);

		if (uri == null) {
			return false;
		}

		try (InputStream input = new FileInputStream(source); OutputStream output = resolver.openOutputStream(uri)) {
			if (output == null) {
				resolver.delete(uri, null, null);
				return false;
			}

			copy(input, output);
		} catch (IOException e) {
			resolver.delete(uri, null, null);
			throw e;
		}

		values.clear();
		values.put(MediaStore.Images.Media.IS_PENDING, 0);
		resolver.update(uri, values, null, null);

		return true;
	}

	private static boolean saveToPicturesFolder(File source, String title) throws IOException {
		if (!hasGalleryPermission()) {
			return false;
		}

		File directory = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), GALLERY_FOLDER);

		if (!directory.isDirectory() && !directory.mkdirs()) {
			return false;
		}

		File target = new File(directory, title + ".png");

		try (InputStream input = new FileInputStream(source); OutputStream output = new FileOutputStream(target)) {
			copy(input, output);
		}

		Context context = Extension.mainContext;
		MediaScannerConnection.scanFile(context, new String[] { target.getAbsolutePath() }, new String[] { "image/png" }, null);

		return true;
	}

	private static void copy(InputStream input, OutputStream output) throws IOException {
		byte[] buffer = new byte[8192];
		int read;

		while ((read = input.read(buffer)) != -1) {
			output.write(buffer, 0, read);
		}
	}
}
