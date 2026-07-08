/// إعدادات الاتصال بـ Supabase — نفس قاعدة بيانات الموقع الإلكتروني.
///
/// القيم الافتراضية هنا مطابقة لما هو موجود بالفعل في `supabase-config.js`
/// على الموقع (anon/publishable key، وليس مفتاحاً سرياً). يمكن تجاوزها وقت
/// البناء عبر: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wjufmsnnpdisjeduikwz.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_uhjLOZvwOpNQCfqQZS8s-w_V1VI0KP8',
  );

  /// رابط الموقع الأساسي، تُبنى منه رابط صفحة الاتصال call.html ورابط
  /// دالة ai-intake الخلفية (Netlify Functions تُنشر مع نفس الموقع).
  static const websiteBaseUrl = String.fromEnvironment(
    'WEBSITE_BASE_URL',
    defaultValue: 'https://guileless-caramel-0ae41c.netlify.app',
  );

  /// نفس القيمة الافتراضية المستخدمة بالموقع (window.__EMAIL_SECRET) للتحقق
  /// من ترويسة x-api-secret عند مناداة Netlify Functions — ليست سرًا قويًا،
  /// فقط تمنع الاستدعاء العشوائي المباشر لدالة ai-intake.
  static const apiSecret = String.fromEnvironment(
    'API_SECRET',
    defaultValue: '',
  );
}
