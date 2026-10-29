/**
 * @author Shakib
 * @since 30/10/26
 */
package com.diatomicsoft.xiaomiremote.cursor;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.Intent;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.net.LocalServerSocket;
import android.net.LocalSocket;
import android.os.Handler;
import android.os.Looper;
import android.util.DisplayMetrics;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Set;

public class CursorService extends AccessibilityService {
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Object socketLock = new Object();
    private final Set<LocalSocket> clients = new HashSet<>();
    private LocalServerSocket server;
    private volatile boolean running;
    private WindowManager windowManager;
    private CursorView cursor;
    private int width, height, x, y;
    private final Runnable hide = () -> {
        if (cursor != null) cursor.setVisibility(View.GONE);
    };

    @Override protected void onServiceConnected() {
        super.onServiceConnected();
        if (running) return;
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        DisplayMetrics metrics = new DisplayMetrics();
        windowManager.getDefaultDisplay().getRealMetrics(metrics);
        width = metrics.widthPixels;
        height = metrics.heightPixels;
        x = width / 2;
        y = height / 2;
        cursor = new CursorView();
        cursor.setVisibility(View.GONE);
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT);
        params.gravity = Gravity.TOP | Gravity.START;
        windowManager.addView(cursor, params);
        running = true;
        new Thread(this::serve, "cursor-server").start();
    }

    private void serve() {
        try {
            LocalServerSocket listener = new LocalServerSocket("xr_cursor");
            synchronized (socketLock) {
                if (!running) {
                    listener.close();
                    return;
                }
                server = listener;
            }
            while (running) {
                LocalSocket client = listener.accept();
                try {
                    int uid = client.getPeerCredentials().getUid();
                    synchronized (socketLock) {
                        if (!running || (uid != 0 && uid != 2000)) {
                            client.close();
                            continue;
                        }
                        clients.add(client);
                    }
                    new Thread(() -> handle(client), "cursor-client").start();
                } catch (IOException e) {
                    client.close();
                }
            }
        } catch (IOException ignored) { }
    }

    private void handle(LocalSocket client) {
        try (LocalSocket socket = client;
             BufferedReader reader = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.US_ASCII))) {
            OutputStream output = socket.getOutputStream();
            String line;
            while (running && (line = reader.readLine()) != null) {
                String[] parts = line.trim().split(" +");
                if (parts.length == 1 && parts[0].equals("v")) {
                    output.write("xr_cursor 1\n".getBytes(StandardCharsets.US_ASCII));
                    output.flush();
                } else if (parts.length == 3 && parts[0].equals("m")) {
                    try {
                        int dx = Integer.parseInt(parts[1]);
                        int dy = Integer.parseInt(parts[2]);
                        main.post(() -> {
                            if (!running) return;
                            x = clamp((long) x + dx, width);
                            y = clamp((long) y + dy, height);
                            show();
                        });
                    } catch (NumberFormatException ignored) { }
                } else if (parts.length == 2 && parts[0].equals("s")) {
                    try {
                        int dy = Integer.parseInt(parts[1]);
                        main.post(() -> {
                            if (!running) return;
                            show();
                            int end = clamp((long) y + dy, height);
                            if (Math.abs(end - y) >= 2) gesture(x, y, x, end, 150);
                        });
                    } catch (NumberFormatException ignored) { }
                } else if (parts.length == 1) {
                    switch (parts[0]) {
                        case "c": main.post(() -> press(50)); break;
                        case "l": main.post(() -> press(650)); break;
                        case "b": main.post(() -> { if (running) performGlobalAction(GLOBAL_ACTION_BACK); }); break;
                        case "h": main.post(() -> { if (running) { main.removeCallbacks(hide); hide.run(); } }); break;
                        default: break;
                    }
                }
            }
        } catch (IOException ignored) {
        } finally {
            synchronized (socketLock) { clients.remove(client); }
        }
    }

    private static int clamp(long value, int size) {
        return (int) Math.max(0, Math.min(value, (long) size - 1));
    }

    private void show() {
        cursor.setVisibility(View.VISIBLE);
        cursor.invalidate();
        main.removeCallbacks(hide);
        main.postDelayed(hide, 6000);
    }

    private void press(long duration) {
        if (!running) return;
        show();
        gesture(x, y, x, y, duration);
    }

    private void gesture(int fromX, int fromY, int toX, int toY, long duration) {
        Path path = new Path();
        path.moveTo(fromX, fromY);
        if (fromX != toX || fromY != toY) path.lineTo(toX, toY);
        dispatchGesture(new GestureDescription.Builder()
                .addStroke(new GestureDescription.StrokeDescription(path, 0, duration)).build(), null, null);
    }

    private void stop() {
        running = false;
        synchronized (socketLock) {
            if (server != null) {
                try { server.close(); } catch (IOException ignored) { }
                server = null;
            }
            for (LocalSocket client : clients) {
                try { client.close(); } catch (IOException ignored) { }
            }
            clients.clear();
        }
        main.removeCallbacksAndMessages(null);
        if (cursor != null) {
            windowManager.removeView(cursor);
            cursor = null;
        }
    }

    @Override public boolean onUnbind(Intent intent) { stop(); return super.onUnbind(intent); }
    @Override public void onDestroy() { stop(); super.onDestroy(); }
    @Override public void onAccessibilityEvent(AccessibilityEvent event) { }
    @Override public void onInterrupt() { }

    private final class CursorView extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Path arrow = new Path();
        CursorView() { super(CursorService.this); }
        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            arrow.reset();
            arrow.moveTo(x, y);
            arrow.lineTo(x, y + 36);
            arrow.lineTo(x + 9, y + 27);
            arrow.lineTo(x + 16, y + 40);
            arrow.lineTo(x + 21, y + 37);
            arrow.lineTo(x + 14, y + 24);
            arrow.lineTo(x + 27, y + 24);
            arrow.close();
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.WHITE);
            canvas.drawPath(arrow, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(2.5f);
            paint.setStrokeJoin(Paint.Join.ROUND);
            paint.setColor(Color.rgb(32, 32, 32));
            canvas.drawPath(arrow, paint);
        }
    }
}
