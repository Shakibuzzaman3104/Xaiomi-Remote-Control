/**
 * @author Shakib
 * @since 29/10/26
 */
package com.diatomicsoft.xiaomiremote.helper;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.os.IBinder;
import android.os.Looper;
import android.util.Base64;

import java.io.ByteArrayOutputStream;
import java.lang.reflect.Method;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Runs on the TV via app_process and prints app labels/icons or edits the clipboard. */
public final class Main {

    public static void main(String[] args) throws Exception {
        Looper.prepareMainLooper();
        Context context = systemContext();
        String command = args.length > 0 ? args[0] : "apps";
        switch (command) {
            case "apps":
                printLauncherApps(context, args.length > 1 ? Integer.parseInt(args[1]) : 96);
                break;
            case "seek":
                seek(context, args[1], Long.parseLong(args[2]));
                break;
            case "clipboard-get":
                printClipboard(context);
                break;
            case "clipboard-set":
                setClipboard(context, new String(Base64.decode(args[1], Base64.NO_WRAP), "UTF-8"));
                break;
            default:
                System.err.println("unknown command " + command);
                System.exit(2);
        }
        System.exit(0);
    }

    private static Context systemContext() throws Exception {
        Class<?> activityThread = Class.forName("android.app.ActivityThread");
        Object thread = activityThread.getMethod("systemMain").invoke(null);
        return (Context) activityThread.getMethod("getSystemContext").invoke(thread);
    }

    private static void printLauncherApps(Context context, int iconSize) throws Exception {
        PackageManager pm = context.getPackageManager();
        Set<String> seen = new HashSet<>();
        for (String category : new String[] {Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER}) {
            Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(category);
            List<ResolveInfo> activities = pm.queryIntentActivities(intent, 0);
            for (ResolveInfo info : activities) {
                String pkg = info.activityInfo.packageName;
                if (!seen.add(pkg)) continue;
                String label = info.loadLabel(pm).toString().replace('\t', ' ').replace('\n', ' ');
                Drawable icon = info.loadIcon(pm);
                boolean tv = Intent.CATEGORY_LEANBACK_LAUNCHER.equals(category);
                System.out.println(pkg + "\t" + label + "\t" + (tv ? "tv" : "phone") + "\t" + encodePng(icon, iconSize));
            }
        }
    }

    private static String encodePng(Drawable drawable, int size) {
        Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, size, size);
        drawable.draw(canvas);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
    }

    private static void seek(Context context, String pkg, long positionMs) {
        List<MediaController> controllers;
        try {
            MediaSessionManager sessions = (MediaSessionManager) context.getSystemService(Context.MEDIA_SESSION_SERVICE);
            controllers = sessions.getActiveSessions(null);
        } catch (Throwable e) {
            System.out.println("unsupported");
            return;
        }
        for (MediaController controller : controllers) {
            if (controller.getPackageName().equals(pkg)) {
                controller.getTransportControls().seekTo(Math.max(0, positionMs));
                System.out.println("ok");
                return;
            }
        }
        System.out.println("no session");
    }

    private static void printClipboard(Context context) throws Exception {
        ClipData clip = readPrimaryClip();
        CharSequence text = clip == null || clip.getItemCount() == 0 ? null : clip.getItemAt(0).coerceToText(context);
        String value = text == null ? "" : text.toString();
        System.out.println("clip:" + Base64.encodeToString(value.getBytes(java.nio.charset.StandardCharsets.UTF_8), Base64.NO_WRAP));
    }

    /** Asks the clipboard service directly as the shell package; the system context's "android" is refused. */
    private static ClipData readPrimaryClip() throws Exception {
        Class<?> serviceManager = Class.forName("android.os.ServiceManager");
        IBinder binder = (IBinder) serviceManager.getMethod("getService", String.class).invoke(null, "clipboard");
        Object service = Class.forName("android.content.IClipboard$Stub").getMethod("asInterface", IBinder.class).invoke(null, binder);
        for (Method method : service.getClass().getMethods()) {
            if (!method.getName().equals("getPrimaryClip")) continue;
            Class<?>[] types = method.getParameterTypes();
            Object[] args = new Object[types.length];
            boolean firstString = true;
            for (int i = 0; i < types.length; i++) {
                if (types[i] == String.class) {
                    args[i] = firstString ? "com.android.shell" : null;
                    firstString = false;
                } else if (types[i] == int.class) {
                    args[i] = 0;
                } else {
                    args = null;
                    break;
                }
            }
            if (args != null) return (ClipData) method.invoke(service, args);
        }
        throw new IllegalStateException("no getPrimaryClip");
    }

    private static void setClipboard(Context context, String text) {
        ClipboardManager clipboard = (ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
        clipboard.setPrimaryClip(ClipData.newPlainText("xiaomi_remote", text));
        System.out.println("ok");
    }
}
