///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsAr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsAr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ar,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ar>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsAr _root = this; // ignore: unused_field

	@override 
	TranslationsAr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsAr(meta: meta ?? this.$meta);

	// Translations
	@override String get languageName => 'العربية';
	@override late final _Translations$app$ar app = _Translations$app$ar._(_root);
	@override late final _Translations$custom$ar custom = _Translations$custom$ar._(_root);
	@override late final _Translations$style$ar style = _Translations$style$ar._(_root);
	@override late final _Translations$chat$ar chat = _Translations$chat$ar._(_root);
}

// Path: app
class _Translations$app$ar extends Translations$app$en {
	_Translations$app$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'مثال flutter_chat_pro';
	@override String get chats => 'المحادثات';
	@override String chatsWithUnread({required Object n}) => 'المحادثات (${n})';
	@override String get language => 'اللغة';
	@override String get randomFailures => 'فشل إرسال عشوائي';
	@override String get startLiveMessages => 'تشغيل الرسائل الواردة';
	@override String get stopLiveMessages => 'إيقاف الرسائل الواردة';
	@override String get resetDemo => 'إعادة ضبط العرض';
	@override String get resetDemoHint => 'المحادثات التجريبية والمظهر الافتراضي';
	@override String get goOffline => 'قطع الاتصال';
	@override String get goOnline => 'الاتصال';
	@override String get offlineBanner => 'غير متصل: تُحفظ الرسائل وتُرسل عند عودة الاتصال.';
	@override String couldNotOpen({required Object error}) => 'تعذّر الفتح: ${error}';
	@override String get makeOffer => 'تقديم عرض';
	@override String get roomDetails => 'افتح تفاصيل المحادثة هنا';
	@override String forward({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: 'لا رسائل لإعادة توجيهها',
		one: 'إعادة توجيه رسالة واحدة: اختر محادثة هنا',
		two: 'إعادة توجيه رسالتين: اختر محادثة هنا',
		few: 'إعادة توجيه ${n} رسائل: اختر محادثة هنا',
		many: 'إعادة توجيه ${n} رسالة: اختر محادثة هنا',
		other: 'إعادة توجيه ${n} رسالة: اختر محادثة هنا',
	);
	@override late final _Translations$app$filters$ar filters = _Translations$app$filters$ar._(_root);
}

// Path: custom
class _Translations$custom$ar extends Translations$custom$en {
	_Translations$custom$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get offer => 'عرض';
	@override String get quote => 'عرض سعر';
	@override String get booking => 'موعد';
	@override String get meeting => 'اجتماع';
	@override String offerPreview({required Object title, required Object amount}) => 'عرض: ${title} (${amount})';
	@override String quotePreview({required Object title, required Object amount}) => 'عرض سعر: ${title} (${amount})';
	@override String get decline => 'رفض';
	@override String get accept => 'قبول';
	@override String get acceptQuote => 'قبول عرض السعر';
	@override String get total => 'المجموع';
	@override String validFor({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: 'صالح اليوم فقط',
		one: 'صالح ليوم واحد',
		two: 'صالح ليومين',
		few: 'صالح لمدة ${n} أيام',
		many: 'صالح لمدة ${n} يومًا',
		other: 'صالح لمدة ${n} يوم',
	);
	@override String get deal => 'اتفقنا! ✅';
	@override String get noThanks => 'لا شكرًا، ربما في المرة القادمة';
	@override String get quoteAccepted => 'تم قبول عرض السعر، يمكنك البدء ✅';
	@override String get customOrder => 'طلب مخصص';
	@override String get wallet => 'محفظة جلدية';
	@override String get engraving => 'نقش الاسم';
	@override String get giftBox => 'علبة هدية';
	@override String get what => 'ماذا';
	@override String get price => 'السعر';
	@override String get cancel => 'إلغاء';
	@override String get send => 'إرسال';
}

// Path: style
class _Translations$style$ar extends Translations$style$en {
	_Translations$style$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get button => 'مظهر المحادثة';
	@override String get preset => 'النمط';
	@override String get colors => 'الألوان';
	@override String get darkMode => 'الوضع الداكن';
	@override String get size => 'الحجم';
	@override String get design => 'التصميم';
	@override String get byScreen => 'حسب الشاشة';
	@override String get scaleKit => 'Scale kit';
	@override String get zoom => 'التكبير';
	@override String get textSize => 'حجم النص';
	@override String get messages => 'الرسائل';
	@override String get messageFontSize => 'حجم خط الرسائل';
	@override String get greyText => 'نص الرسائل باللون الرمادي';
	@override String get bubbleRadius => 'استدارة الفقاعات';
	@override String get bubbleShadows => 'ظل الفقاعات';
	@override String get bubbleBorder => 'حدود الفقاعات';
	@override String get inbox => 'قائمة المحادثات';
	@override String get plain => 'بسيط';
	@override String get lines => 'خطوط';
	@override String get cards => 'بطاقات';
	@override String get cardRadius => 'استدارة البطاقات';
	@override String get squareAvatars => 'صور شخصية مربعة';
	@override String reset({required Object name}) => 'إعادة ضبط «${name}»';
	@override String get shuffle => 'مظهر عشوائي';
	@override String get autoShuffle => 'التبديل كل بضع ثوانٍ';
	@override String get startShuffle => 'بدء تبديل المظاهر';
	@override String get stopShuffle => 'إيقاف تبديل المظاهر';
	@override late final _Translations$style$presets$ar presets = _Translations$style$presets$ar._(_root);
}

// Path: chat
class _Translations$chat$ar extends Translations$chat$en {
	_Translations$chat$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get typeMessage => 'رسالة';
	@override String get today => 'اليوم';
	@override String get yesterday => 'أمس';
	@override String get newMessages => 'رسائل جديدة';
	@override String get reply => 'رد';
	@override String get copy => 'نسخ';
	@override String get copied => 'تم النسخ';
	@override String get edit => 'تعديل';
	@override String get delete => 'حذف';
	@override String get retry => 'إعادة المحاولة';
	@override String get cancel => 'إلغاء';
	@override String get send => 'إرسال';
	@override String get failedToSend => 'تعذّر الإرسال';
	@override String get messageDeleted => 'تم حذف هذه الرسالة';
	@override String get unsupportedMessage => 'رسالة غير مدعومة';
	@override String get edited => 'معدّلة';
	@override String get editing => 'تعديل الرسالة';
	@override String get you => 'أنت';
	@override String get online => 'متصل الآن';
	@override String get slideToCancel => 'اسحب للإلغاء';
	@override String get searchChats => 'بحث';
	@override String get noChats => 'لا توجد محادثات بعد';
	@override String get noMessages => 'قل مرحبًا';
	@override String get loadFailed => 'تعذّر تحميل الرسائل';
	@override String get startOfConversation => 'هذه بداية المحادثة';
	@override String get scrollToBottom => 'الانتقال إلى الأحدث';
	@override String get photo => 'صورة';
	@override String get video => 'فيديو';
	@override String get voice => 'رسالة صوتية';
	@override String get file => 'ملف';
	@override String get camera => 'الكاميرا';
	@override String get gallery => 'المعرض';
	@override String get attachmentTooLarge => 'الملف كبير جدًا';
	@override String get fileUnavailable => 'هذا الملف لم يعد متاحًا. احذفه وأرسله مرة أخرى.';
	@override String get compressing => 'جارٍ الضغط';
	@override String get readMore => 'اقرأ المزيد';
	@override String get readLess => 'عرض أقل';
	@override String get replyUnavailable => 'الرسالة الأصلية غير متاحة';
	@override String get statusPending => 'جارٍ الإرسال';
	@override String get statusSent => 'تم الإرسال';
	@override String get statusDelivered => 'تم التسليم';
	@override String get statusSeen => 'تمت المشاهدة';
	@override String get messageOptions => 'خيارات الرسالة';
	@override String get save => 'حفظ';
	@override String get saved => 'تم الحفظ';
	@override String get download => 'تنزيل';
	@override String get downloadFailed => 'تعذّر التنزيل';
	@override String get play => 'تشغيل';
	@override String get pause => 'إيقاف مؤقت';
	@override String get close => 'إغلاق';
	@override String get attach => 'إرفاق';
	@override String get removeAttachment => 'إزالة';
	@override String get recordVoice => 'تسجيل رسالة صوتية';
	@override String get holdToRecord => 'اضغط مطولًا للتسجيل، وارفع إصبعك للإرسال';
	@override String get microphoneDenied => 'اسمح بالوصول إلى الميكروفون للتسجيل';
	@override String get slideUpToLock => 'اسحب لأعلى للقفل';
	@override String get stopRecording => 'إيقاف التسجيل';
	@override String get back => 'رجوع';
	@override String get forward => 'إعادة توجيه';
	@override String get select => 'تحديد';
	@override String get pin => 'تثبيت';
	@override String get unpin => 'إلغاء التثبيت';
	@override String get mute => 'كتم';
	@override String get unmute => 'إلغاء الكتم';
	@override String get clearSearch => 'مسح البحث';
	@override String get noResults => 'لا توجد نتائج';
	@override String get loadChatsFailed => 'تعذّر تحميل المحادثات';
	@override String get switchProfile => 'تبديل الملف الشخصي';
	@override String get businessProfile => 'حساب تجاري';
	@override String typingOne({required Object name}) => '${name} يكتب…';
	@override String typingTwo({required Object a, required Object b}) => '${a} و${b} يكتبان…';
	@override String typingMany({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: 'لا أحد يكتب',
		one: 'شخص واحد يكتب…',
		two: 'شخصان يكتبان…',
		few: '${n} أشخاص يكتبون…',
		many: '${n} شخصًا يكتبون…',
		other: '${n} شخص يكتبون…',
	);
	@override String lastSeen({required Object when}) => 'آخر ظهور ${when}';
	@override String photos({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: 'لا صور',
		one: 'صورة',
		two: 'صورتان',
		few: '${n} صور',
		many: '${n} صورة',
		other: '${n} صورة',
	);
	@override String reaction({required num n, required Object emoji}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: '${emoji}، لا تفاعلات',
		one: '${emoji}، تفاعل واحد',
		two: '${emoji}، تفاعلان',
		few: '${emoji}، ${n} تفاعلات',
		many: '${emoji}، ${n} تفاعلًا',
		other: '${emoji}، ${n} تفاعل',
	);
	@override String reactWith({required Object emoji}) => 'تفاعل بـ ${emoji}';
	@override String playbackSpeed({required Object speed}) => '${speed}x';
	@override String moreMedia({required Object n}) => '+${n}';
	@override String mediaPosition({required Object index, required Object total}) => '${index} من ${total}';
	@override String members({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: 'لا أعضاء',
		one: 'عضو واحد',
		two: 'عضوان',
		few: '${n} أعضاء',
		many: '${n} عضوًا',
		other: '${n} عضو',
	);
	@override String selectedCount({required Object n}) => '${n}';
	@override String previewWithAuthor({required Object author, required Object text}) => '${author}: ${text}';
	@override String unreadCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: 'لا رسائل غير مقروءة',
		one: 'رسالة واحدة غير مقروءة',
		two: 'رسالتان غير مقروءتين',
		few: '${n} رسائل غير مقروءة',
		many: '${n} رسالة غير مقروءة',
		other: '${n} رسالة غير مقروءة',
	);
	@override late final _Translations$chat$system$ar system = _Translations$chat$system$ar._(_root);
}

// Path: app.filters
class _Translations$app$filters$ar extends Translations$app$filters$en {
	_Translations$app$filters$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get all => 'الكل';
	@override String get chats => 'خاصة';
	@override String get groups => 'مجموعات';
	@override String get unread => 'غير مقروءة';
	@override String get friends => 'الأصدقاء';
}

// Path: style.presets
class _Translations$style$presets$ar extends Translations$style$presets$en {
	_Translations$style$presets$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get classic => 'كلاسيكي';
	@override String get whatsApp => 'واتساب';
	@override String get whatsAppNew => 'واتساب (الجديد)';
	@override String get telegram => 'تيليجرام';
	@override String get iMessage => 'آي مسج';
	@override String get messenger => 'ماسنجر';
	@override String get minimal => 'بسيط';
	@override String get cards => 'بطاقات';
	@override String get glass => 'زجاجي';
}

// Path: chat.system
class _Translations$chat$system$ar extends Translations$chat$system$en {
	_Translations$chat$system$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String roomCreated({required Object name, required Object title}) => 'أنشأ ${name} المجموعة «${title}»';
}

/// The flat map containing all translations for locale <ar>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsAr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'languageName' => 'العربية',
			'app.title' => 'مثال flutter_chat_pro',
			'app.chats' => 'المحادثات',
			'app.chatsWithUnread' => ({required Object n}) => 'المحادثات (${n})',
			'app.language' => 'اللغة',
			'app.randomFailures' => 'فشل إرسال عشوائي',
			'app.startLiveMessages' => 'تشغيل الرسائل الواردة',
			'app.stopLiveMessages' => 'إيقاف الرسائل الواردة',
			'app.resetDemo' => 'إعادة ضبط العرض',
			'app.resetDemoHint' => 'المحادثات التجريبية والمظهر الافتراضي',
			'app.goOffline' => 'قطع الاتصال',
			'app.goOnline' => 'الاتصال',
			'app.offlineBanner' => 'غير متصل: تُحفظ الرسائل وتُرسل عند عودة الاتصال.',
			'app.couldNotOpen' => ({required Object error}) => 'تعذّر الفتح: ${error}',
			'app.makeOffer' => 'تقديم عرض',
			'app.roomDetails' => 'افتح تفاصيل المحادثة هنا',
			'app.forward' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: 'لا رسائل لإعادة توجيهها', one: 'إعادة توجيه رسالة واحدة: اختر محادثة هنا', two: 'إعادة توجيه رسالتين: اختر محادثة هنا', few: 'إعادة توجيه ${n} رسائل: اختر محادثة هنا', many: 'إعادة توجيه ${n} رسالة: اختر محادثة هنا', other: 'إعادة توجيه ${n} رسالة: اختر محادثة هنا', ), 
			'app.filters.all' => 'الكل',
			'app.filters.chats' => 'خاصة',
			'app.filters.groups' => 'مجموعات',
			'app.filters.unread' => 'غير مقروءة',
			'app.filters.friends' => 'الأصدقاء',
			'custom.offer' => 'عرض',
			'custom.quote' => 'عرض سعر',
			'custom.booking' => 'موعد',
			'custom.meeting' => 'اجتماع',
			'custom.offerPreview' => ({required Object title, required Object amount}) => 'عرض: ${title} (${amount})',
			'custom.quotePreview' => ({required Object title, required Object amount}) => 'عرض سعر: ${title} (${amount})',
			'custom.decline' => 'رفض',
			'custom.accept' => 'قبول',
			'custom.acceptQuote' => 'قبول عرض السعر',
			'custom.total' => 'المجموع',
			'custom.validFor' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: 'صالح اليوم فقط', one: 'صالح ليوم واحد', two: 'صالح ليومين', few: 'صالح لمدة ${n} أيام', many: 'صالح لمدة ${n} يومًا', other: 'صالح لمدة ${n} يوم', ), 
			'custom.deal' => 'اتفقنا! ✅',
			'custom.noThanks' => 'لا شكرًا، ربما في المرة القادمة',
			'custom.quoteAccepted' => 'تم قبول عرض السعر، يمكنك البدء ✅',
			'custom.customOrder' => 'طلب مخصص',
			'custom.wallet' => 'محفظة جلدية',
			'custom.engraving' => 'نقش الاسم',
			'custom.giftBox' => 'علبة هدية',
			'custom.what' => 'ماذا',
			'custom.price' => 'السعر',
			'custom.cancel' => 'إلغاء',
			'custom.send' => 'إرسال',
			'style.button' => 'مظهر المحادثة',
			'style.preset' => 'النمط',
			'style.colors' => 'الألوان',
			'style.darkMode' => 'الوضع الداكن',
			'style.size' => 'الحجم',
			'style.design' => 'التصميم',
			'style.byScreen' => 'حسب الشاشة',
			'style.scaleKit' => 'Scale kit',
			'style.zoom' => 'التكبير',
			'style.textSize' => 'حجم النص',
			'style.messages' => 'الرسائل',
			'style.messageFontSize' => 'حجم خط الرسائل',
			'style.greyText' => 'نص الرسائل باللون الرمادي',
			'style.bubbleRadius' => 'استدارة الفقاعات',
			'style.bubbleShadows' => 'ظل الفقاعات',
			'style.bubbleBorder' => 'حدود الفقاعات',
			'style.inbox' => 'قائمة المحادثات',
			'style.plain' => 'بسيط',
			'style.lines' => 'خطوط',
			'style.cards' => 'بطاقات',
			'style.cardRadius' => 'استدارة البطاقات',
			'style.squareAvatars' => 'صور شخصية مربعة',
			'style.reset' => ({required Object name}) => 'إعادة ضبط «${name}»',
			'style.shuffle' => 'مظهر عشوائي',
			'style.autoShuffle' => 'التبديل كل بضع ثوانٍ',
			'style.startShuffle' => 'بدء تبديل المظاهر',
			'style.stopShuffle' => 'إيقاف تبديل المظاهر',
			'style.presets.classic' => 'كلاسيكي',
			'style.presets.whatsApp' => 'واتساب',
			'style.presets.whatsAppNew' => 'واتساب (الجديد)',
			'style.presets.telegram' => 'تيليجرام',
			'style.presets.iMessage' => 'آي مسج',
			'style.presets.messenger' => 'ماسنجر',
			'style.presets.minimal' => 'بسيط',
			'style.presets.cards' => 'بطاقات',
			'style.presets.glass' => 'زجاجي',
			'chat.typeMessage' => 'رسالة',
			'chat.today' => 'اليوم',
			'chat.yesterday' => 'أمس',
			'chat.newMessages' => 'رسائل جديدة',
			'chat.reply' => 'رد',
			'chat.copy' => 'نسخ',
			'chat.copied' => 'تم النسخ',
			'chat.edit' => 'تعديل',
			'chat.delete' => 'حذف',
			'chat.retry' => 'إعادة المحاولة',
			'chat.cancel' => 'إلغاء',
			'chat.send' => 'إرسال',
			'chat.failedToSend' => 'تعذّر الإرسال',
			'chat.messageDeleted' => 'تم حذف هذه الرسالة',
			'chat.unsupportedMessage' => 'رسالة غير مدعومة',
			'chat.edited' => 'معدّلة',
			'chat.editing' => 'تعديل الرسالة',
			'chat.you' => 'أنت',
			'chat.online' => 'متصل الآن',
			'chat.slideToCancel' => 'اسحب للإلغاء',
			'chat.searchChats' => 'بحث',
			'chat.noChats' => 'لا توجد محادثات بعد',
			'chat.noMessages' => 'قل مرحبًا',
			'chat.loadFailed' => 'تعذّر تحميل الرسائل',
			'chat.startOfConversation' => 'هذه بداية المحادثة',
			'chat.scrollToBottom' => 'الانتقال إلى الأحدث',
			'chat.photo' => 'صورة',
			'chat.video' => 'فيديو',
			'chat.voice' => 'رسالة صوتية',
			'chat.file' => 'ملف',
			'chat.camera' => 'الكاميرا',
			'chat.gallery' => 'المعرض',
			'chat.attachmentTooLarge' => 'الملف كبير جدًا',
			'chat.fileUnavailable' => 'هذا الملف لم يعد متاحًا. احذفه وأرسله مرة أخرى.',
			'chat.compressing' => 'جارٍ الضغط',
			'chat.readMore' => 'اقرأ المزيد',
			'chat.readLess' => 'عرض أقل',
			'chat.replyUnavailable' => 'الرسالة الأصلية غير متاحة',
			'chat.statusPending' => 'جارٍ الإرسال',
			'chat.statusSent' => 'تم الإرسال',
			'chat.statusDelivered' => 'تم التسليم',
			'chat.statusSeen' => 'تمت المشاهدة',
			'chat.messageOptions' => 'خيارات الرسالة',
			'chat.save' => 'حفظ',
			'chat.saved' => 'تم الحفظ',
			'chat.download' => 'تنزيل',
			'chat.downloadFailed' => 'تعذّر التنزيل',
			'chat.play' => 'تشغيل',
			'chat.pause' => 'إيقاف مؤقت',
			'chat.close' => 'إغلاق',
			'chat.attach' => 'إرفاق',
			'chat.removeAttachment' => 'إزالة',
			'chat.recordVoice' => 'تسجيل رسالة صوتية',
			'chat.holdToRecord' => 'اضغط مطولًا للتسجيل، وارفع إصبعك للإرسال',
			'chat.microphoneDenied' => 'اسمح بالوصول إلى الميكروفون للتسجيل',
			'chat.slideUpToLock' => 'اسحب لأعلى للقفل',
			'chat.stopRecording' => 'إيقاف التسجيل',
			'chat.back' => 'رجوع',
			'chat.forward' => 'إعادة توجيه',
			'chat.select' => 'تحديد',
			'chat.pin' => 'تثبيت',
			'chat.unpin' => 'إلغاء التثبيت',
			'chat.mute' => 'كتم',
			'chat.unmute' => 'إلغاء الكتم',
			'chat.clearSearch' => 'مسح البحث',
			'chat.noResults' => 'لا توجد نتائج',
			'chat.loadChatsFailed' => 'تعذّر تحميل المحادثات',
			'chat.switchProfile' => 'تبديل الملف الشخصي',
			'chat.businessProfile' => 'حساب تجاري',
			'chat.typingOne' => ({required Object name}) => '${name} يكتب…',
			'chat.typingTwo' => ({required Object a, required Object b}) => '${a} و${b} يكتبان…',
			'chat.typingMany' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: 'لا أحد يكتب', one: 'شخص واحد يكتب…', two: 'شخصان يكتبان…', few: '${n} أشخاص يكتبون…', many: '${n} شخصًا يكتبون…', other: '${n} شخص يكتبون…', ), 
			'chat.lastSeen' => ({required Object when}) => 'آخر ظهور ${when}',
			'chat.photos' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: 'لا صور', one: 'صورة', two: 'صورتان', few: '${n} صور', many: '${n} صورة', other: '${n} صورة', ), 
			'chat.reaction' => ({required num n, required Object emoji}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: '${emoji}، لا تفاعلات', one: '${emoji}، تفاعل واحد', two: '${emoji}، تفاعلان', few: '${emoji}، ${n} تفاعلات', many: '${emoji}، ${n} تفاعلًا', other: '${emoji}، ${n} تفاعل', ), 
			'chat.reactWith' => ({required Object emoji}) => 'تفاعل بـ ${emoji}',
			'chat.playbackSpeed' => ({required Object speed}) => '${speed}x',
			'chat.moreMedia' => ({required Object n}) => '+${n}',
			'chat.mediaPosition' => ({required Object index, required Object total}) => '${index} من ${total}',
			'chat.members' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: 'لا أعضاء', one: 'عضو واحد', two: 'عضوان', few: '${n} أعضاء', many: '${n} عضوًا', other: '${n} عضو', ), 
			'chat.selectedCount' => ({required Object n}) => '${n}',
			'chat.previewWithAuthor' => ({required Object author, required Object text}) => '${author}: ${text}',
			'chat.unreadCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: 'لا رسائل غير مقروءة', one: 'رسالة واحدة غير مقروءة', two: 'رسالتان غير مقروءتين', few: '${n} رسائل غير مقروءة', many: '${n} رسالة غير مقروءة', other: '${n} رسالة غير مقروءة', ), 
			'chat.system.roomCreated' => ({required Object name, required Object title}) => 'أنشأ ${name} المجموعة «${title}»',
			_ => null,
		};
	}
}
