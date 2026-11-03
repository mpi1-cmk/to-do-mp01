# مهامي — Tasks Alarm

تطبيق مهام (Android + Windows) بأسلوب Microsoft To-Do مع تنبيه صوتي حقيقي.

## الحصول على ملف APK بدون تثبيت أي شيء (عبر GitHub)

1. أنشئ حساباً على github.com ثم مستودعاً جديداً (New repository).
2. ارفع كل محتويات هذا المجلد إليه (Add file → Upload files).
   - إذا لم يظهر مجلد `.github` بعد الرفع: Add file → Create new file، واكتب الاسم
     `.github/workflows/build.yml` والصق فيه محتوى الملف الموجود في هذا المجلد.
3. افتح تبويب **Actions** ← **Build** ← **Run workflow**.
4. بعد 8–12 دقيقة ينتهي البناء. افتح التشغيل ونزّل **tasks-apk** من قسم Artifacts.
5. فك الضغط، انقل `app-release.apk` إلى هاتفك وثبّته (اسمح بالتثبيت من مصدر غير معروف).
   (نسخة Windows تظهر في **tasks-windows**.)

## البناء على جهازك (Flutter مثبت)

```bash
flutter create --platforms=android,windows --org com.mp.tasks --project-name tasks_alarm .
python tool/patch_android.py
flutter pub get
flutter run            # أو: flutter build apk --release
```

## أول تشغيل على Android 13

1. اسمح بالإشعارات عند ظهور الطلب.
2. الإعدادات (⚙) ← **جرّب التنبيه بعد 10 ثوانٍ** ثم اقفل الشاشة وانتظر.
3. إعدادات الهاتف ← التطبيقات ← مهامي ← البطارية ← **غير مقيّدة** (مهم خصوصاً في Xiaomi/Huawei/Samsung).

## ملاحظات

- البيانات محفوظة محلياً في ملف JSON (`tasks.json`) داخل مجلد التطبيق.
- Windows: التنبيه يعمل والتطبيق يعمل في الـ tray؛ زر الإغلاق (X) يخفي النافذة فقط.
