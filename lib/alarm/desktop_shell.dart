import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows فقط: أيقونة في الـ tray، والإغلاق يخفي النافذة بدل إنهاء التطبيق (ليستمر التنبيه).
class DesktopShell with TrayListener, WindowListener {
  Future<void> init() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);

    await trayManager.setIcon('assets/icons/tray.ico');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'فتح'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'خروج'),
    ]));

    trayManager.addListener(this);
    windowManager.addListener(this);
  }

  @override
  void onTrayIconMouseDown() => windowManager.show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'quit') {
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}
