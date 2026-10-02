# تحويل لوحة توسل إلى APK

## قبل البدء
- استخدم دومين Vercel الأساسي الثابت (مثل tawassul-xxx.vercel.app) وليس رابط الـDeploy المؤقت.
- ارفع كل ملفات هذا المجلد إلى المشروع وانتظر انتهاء الـDeploy.
- تأكد أن هذه الروابط تفتح: /admin-manifest.json و /sw.js و /icon-512.png

## الطريقة (PWABuilder)
1. افتح pwabuilder.com والصق: https://دومينك/admin
2. اضغط Start وانتظر الفحص (يجب أن يظهر Manifest و Service Worker بلون أخضر).
3. اضغط Package for stores ثم Android ثم Generate.
4. اضبط: Package ID مثل com.tawassul.admin، و App name = توسل - الأدمن.
5. في Signing key اختر New، واحفظ ملف الـkeystore وكلمة سره في مكان آمن (لن تستطيع تحديث التطبيق بدونهما).
6. حمّل الملف المضغوط، وفيه ملف APK (للتجربة المباشرة) وملف AAB (لمتجر Google Play).

## ربط التطبيق بالموقع (لإخفاء شريط المتصفح)
1. من ملفات PWABuilder افتح assetlinks.json أو انسخ بصمة SHA-256 من ملف signing-key-info.txt.
2. ضع القيم في .well-known/assetlinks.json: package_name والبصمة.
3. ارفع الملف وتأكد أن https://دومينك/.well-known/assetlinks.json يفتح.
إن لم تفعل هذه الخطوة سيظهر شريط عنوان المتصفح أعلى التطبيق.

## التثبيت
انقل ملف APK إلى الهاتف، وافتحه، وفعّل «السماح بالتثبيت من هذا المصدر» عند الطلب.
