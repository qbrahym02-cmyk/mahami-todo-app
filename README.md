# 📝 مهامي — تطبيق To-Do بـ Flutter مع تحديث عن بعد

تطبيق قائمة مهام عربي (RTL) يمكنك تحديثه **عن بعد** بدون ما يحتاج المستخدم يحمّله من جديد من أي متجر.

## ✨ المميزات
- إضافة / تعديل / حذف المهام (مع تراجع عن الحذف)
- أولويات، تصنيفات، تاريخ استحقاق، تنبيه للمهام المتأخرة
- إحصائيات الإنجاز، فلترة (الكل / النشطة / المنجزة) وحسب التصنيف
- وضع ليلي تلقائي، Material 3، يعمل بدون إنترنت (التخزين محلي)

---

## 🔄 طرق التحديث عن بعد (3 مستويات)

| النوع | ماذا يغيّر | كيف | متى يصل للمستخدم |
|---|---|---|---|
| **1. إعدادات عن بعد** | العنوان، الألوان، الإعلانات، وضع الصيانة، تشغيل/إيقاف الميزات، التصنيفات | عدّل `remote/config.json` على GitHub | فوراً عند فتح التطبيق أو سحب الشاشة للأسفل (⏱ حتى ~5 دقائق كاش) |
| **2. تحديث كود التطبيق (أندرويد)** | أي شيء: شاشات جديدة، ميزات، إصلاحات | Actions ← **Release Android** ← Run workflow | تظهر نافذة "يتوفر تحديث" ← ضغطة واحدة ← ينزل ويثبت من داخل التطبيق |
| **3. نسخة الويب** | أي شيء | `git push` على main | تلقائياً عند فتح الرابط |

### 1️⃣ تعديل الإعدادات (بدون أي بناء)
افتح `remote/config.json` في GitHub ← ✏️ ← عدّل ← Commit. أمثلة:

```jsonc
"announcement": { "enabled": true, "type": "warning", "text": "عرض خاص اليوم!" }  // type: info | success | warning
"primary_color": "#E91E63"                       // لون التطبيق
"theme_mode": "dark"                             // system | light | dark
"maintenance": { "enabled": true, "message": "صيانة لمدة ساعة" }   // يقفل التطبيق مؤقتاً
"features": { "stats": false }                   // إخفاء ميزة
"categories": ["عمل", "رياضة", "عائلة"]          // التصنيفات
"min_supported_version": "1.2.0"                 // يجبر من عنده نسخة أقدم على التحديث
```

### 2️⃣ نشر إصدار جديد من التطبيق (أندرويد)
1. عدّل الكود وارفعه على `main`.
2. في GitHub: **Actions ← Release Android ← Run workflow**
3. اكتب رقم الإصدار (أكبر من الحالي، مثل `1.0.1`) وملاحظات "ما الجديد".
4. خلال ~5 دقائق يُبنى ملف APK ويُنشر في **Releases**.
5. كل من عنده التطبيق ستظهر له نافذة التحديث ← **تحديث الآن** ← تثبيت. ✅ المهام لا تُحذف.

أو من الطرفية: `git tag v1.0.1 && git push origin v1.0.1`

> ⚠️ أول مرة فقط: أندرويد سيطلب السماح لـ"مهامي" بتثبيت التطبيقات (Install unknown apps). هذا طبيعي.

---

## 🔐 مفتاح التوقيع (مهم جداً)
كل تحديث يجب أن يُوقَّع **بنفس المفتاح**، وإلا يرفض أندرويد تثبيته فوق النسخة القديمة.
المفتاح محفوظ في GitHub Secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`)
**واحتفظ بنسخة احتياطية** من `upload-keystore.p12` وكلمة المرور في مكان آمن — ليسا في هذا المستودع.

للبناء محلياً، أنشئ `android/key.properties` (مُستثنى من git):
```properties
storeFile=/path/to/upload-keystore.p12
storePassword=...
keyPassword=...
keyAlias=upload
```

## 🛠 التشغيل محلياً
```bash
flutter pub get
flutter run
```

## 📁 هيكل المشروع
```
lib/
  app_config.dart                 ← رابط المستودع (غيّره إذا نقلته)
  main.dart
  models/todo.dart
  services/
    remote_config_service.dart    ← جلب config.json وتخزينه
    update_service.dart           ← فحص GitHub Releases
    todo_storage.dart             ← حفظ المهام محلياً
  screens/home_screen.dart
  widgets/ (update_dialog, todo_tile, todo_editor_sheet)
remote/config.json                ← الإعدادات عن بعد
.github/workflows/
  release-android.yml             ← بناء ونشر APK
  deploy-web.yml                  ← نشر نسخة الويب
```

## 💡 ملاحظات
- **iOS**: آبل لا تسمح بتنزيل التطبيقات من خارج المتجر. للـ iOS استخدم نسخة الويب، أو [Shorebird](https://shorebird.dev) لتحديث كود Dart عبر المتجر.
- لتحديث كود Dart **بدون إعادة تثبيت إطلاقاً** على أندرويد أيضاً، يمكن إضافة Shorebird لاحقاً (يحتاج حساب).
