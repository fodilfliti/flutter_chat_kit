///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations

	/// en: 'English'
	String get languageName => 'English';

	late final Translations$app$en app = Translations$app$en.internal(_root);
	late final Translations$custom$en custom = Translations$custom$en.internal(_root);
	late final Translations$style$en style = Translations$style$en.internal(_root);
	late final Translations$chat$en chat = Translations$chat$en.internal(_root);
}

// Path: app
class Translations$app$en {
	Translations$app$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'flutter_chat_pro example'
	String get title => 'flutter_chat_pro example';

	/// en: 'Chats'
	String get chats => 'Chats';

	/// en: 'Chats ($n)'
	String chatsWithUnread({required Object n}) => 'Chats (${n})';

	/// en: 'Language'
	String get language => 'Language';

	/// en: 'Random send failures'
	String get randomFailures => 'Random send failures';

	/// en: 'Turn on incoming messages'
	String get startLiveMessages => 'Turn on incoming messages';

	/// en: 'Turn off incoming messages'
	String get stopLiveMessages => 'Turn off incoming messages';

	/// en: 'Reset demo'
	String get resetDemo => 'Reset demo';

	/// en: 'Sample chats and default style'
	String get resetDemoHint => 'Sample chats and default style';

	/// en: 'Go offline'
	String get goOffline => 'Go offline';

	/// en: 'Go online'
	String get goOnline => 'Go online';

	/// en: 'Offline: messages are queued and sent when you reconnect.'
	String get offlineBanner => 'Offline: messages are queued and sent when you reconnect.';

	/// en: 'Could not open: $error'
	String couldNotOpen({required Object error}) => 'Could not open: ${error}';

	/// en: 'Make an offer'
	String get makeOffer => 'Make an offer';

	/// en: 'Open the room details here'
	String get roomDetails => 'Open the room details here';

	/// en: '(one) {Forward 1 message: pick a room here} (other) {Forward $n messages: pick a room here}'
	String forward({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Forward 1 message: pick a room here',
		other: 'Forward ${n} messages: pick a room here',
	);

	late final Translations$app$filters$en filters = Translations$app$filters$en.internal(_root);
}

// Path: custom
class Translations$custom$en {
	Translations$custom$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Offer'
	String get offer => 'Offer';

	/// en: 'Quote'
	String get quote => 'Quote';

	/// en: 'Booking'
	String get booking => 'Booking';

	/// en: 'Meeting'
	String get meeting => 'Meeting';

	/// en: 'Offer: $title ($amount)'
	String offerPreview({required Object title, required Object amount}) => 'Offer: ${title} (${amount})';

	/// en: 'Quote: $title ($amount)'
	String quotePreview({required Object title, required Object amount}) => 'Quote: ${title} (${amount})';

	/// en: 'Decline'
	String get decline => 'Decline';

	/// en: 'Accept'
	String get accept => 'Accept';

	/// en: 'Accept quote'
	String get acceptQuote => 'Accept quote';

	/// en: 'Total'
	String get total => 'Total';

	/// en: '(one) {Valid for 1 day} (other) {Valid for $n days}'
	String validFor({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Valid for 1 day',
		other: 'Valid for ${n} days',
	);

	/// en: 'Deal! ✅'
	String get deal => 'Deal! ✅';

	/// en: 'No thanks, maybe next time'
	String get noThanks => 'No thanks, maybe next time';

	/// en: 'Quote accepted, please go ahead ✅'
	String get quoteAccepted => 'Quote accepted, please go ahead ✅';

	/// en: 'Custom order'
	String get customOrder => 'Custom order';

	/// en: 'Leather wallet'
	String get wallet => 'Leather wallet';

	/// en: 'Name engraving'
	String get engraving => 'Name engraving';

	/// en: 'Gift box'
	String get giftBox => 'Gift box';

	/// en: 'What'
	String get what => 'What';

	/// en: 'Price'
	String get price => 'Price';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Send'
	String get send => 'Send';
}

// Path: style
class Translations$style$en {
	Translations$style$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Chat style'
	String get button => 'Chat style';

	/// en: 'Preset'
	String get preset => 'Preset';

	/// en: 'Colors'
	String get colors => 'Colors';

	/// en: 'Dark mode'
	String get darkMode => 'Dark mode';

	/// en: 'Size'
	String get size => 'Size';

	/// en: 'Design'
	String get design => 'Design';

	/// en: 'By screen'
	String get byScreen => 'By screen';

	/// en: 'Scale kit'
	String get scaleKit => 'Scale kit';

	/// en: 'Zoom'
	String get zoom => 'Zoom';

	/// en: 'Text size'
	String get textSize => 'Text size';

	/// en: 'Messages'
	String get messages => 'Messages';

	/// en: 'Message font size'
	String get messageFontSize => 'Message font size';

	/// en: 'Grey message text'
	String get greyText => 'Grey message text';

	/// en: 'Bubble radius'
	String get bubbleRadius => 'Bubble radius';

	/// en: 'Bubble shadows'
	String get bubbleShadows => 'Bubble shadows';

	/// en: 'Bubble border'
	String get bubbleBorder => 'Bubble border';

	/// en: 'Inbox'
	String get inbox => 'Inbox';

	/// en: 'Plain'
	String get plain => 'Plain';

	/// en: 'Lines'
	String get lines => 'Lines';

	/// en: 'Cards'
	String get cards => 'Cards';

	/// en: 'Card radius'
	String get cardRadius => 'Card radius';

	/// en: 'Square avatars'
	String get squareAvatars => 'Square avatars';

	/// en: 'Reset "$name"'
	String reset({required Object name}) => 'Reset "${name}"';

	/// en: 'Random style'
	String get shuffle => 'Random style';

	/// en: 'Shuffle every few seconds'
	String get autoShuffle => 'Shuffle every few seconds';

	/// en: 'Start style shuffle'
	String get startShuffle => 'Start style shuffle';

	/// en: 'Stop style shuffle'
	String get stopShuffle => 'Stop style shuffle';

	late final Translations$style$presets$en presets = Translations$style$presets$en.internal(_root);
}

// Path: chat
class Translations$chat$en {
	Translations$chat$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Message'
	String get typeMessage => 'Message';

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';

	/// en: 'New messages'
	String get newMessages => 'New messages';

	/// en: 'Reply'
	String get reply => 'Reply';

	/// en: 'Copy'
	String get copy => 'Copy';

	/// en: 'Copied'
	String get copied => 'Copied';

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Send'
	String get send => 'Send';

	/// en: 'Failed to send'
	String get failedToSend => 'Failed to send';

	/// en: 'This message was deleted'
	String get messageDeleted => 'This message was deleted';

	/// en: 'Unsupported message'
	String get unsupportedMessage => 'Unsupported message';

	/// en: 'edited'
	String get edited => 'edited';

	/// en: 'Editing'
	String get editing => 'Editing';

	/// en: 'You'
	String get you => 'You';

	/// en: 'online'
	String get online => 'online';

	/// en: 'Slide to cancel'
	String get slideToCancel => 'Slide to cancel';

	/// en: 'Search'
	String get searchChats => 'Search';

	/// en: 'No conversations yet'
	String get noChats => 'No conversations yet';

	/// en: 'Say hello'
	String get noMessages => 'Say hello';

	/// en: 'Couldn't load messages'
	String get loadFailed => 'Couldn\'t load messages';

	/// en: 'This is the start of the conversation'
	String get startOfConversation => 'This is the start of the conversation';

	/// en: 'Scroll to latest'
	String get scrollToBottom => 'Scroll to latest';

	/// en: 'Photo'
	String get photo => 'Photo';

	/// en: 'Video'
	String get video => 'Video';

	/// en: 'Voice message'
	String get voice => 'Voice message';

	/// en: 'File'
	String get file => 'File';

	/// en: 'Camera'
	String get camera => 'Camera';

	/// en: 'Gallery'
	String get gallery => 'Gallery';

	/// en: 'File is too large'
	String get attachmentTooLarge => 'File is too large';

	/// en: 'This file is no longer available. Delete it and send it again.'
	String get fileUnavailable => 'This file is no longer available. Delete it and send it again.';

	/// en: 'Compressing'
	String get compressing => 'Compressing';

	/// en: 'Read more'
	String get readMore => 'Read more';

	/// en: 'Show less'
	String get readLess => 'Show less';

	/// en: 'Original message unavailable'
	String get replyUnavailable => 'Original message unavailable';

	/// en: 'Sending'
	String get statusPending => 'Sending';

	/// en: 'Sent'
	String get statusSent => 'Sent';

	/// en: 'Delivered'
	String get statusDelivered => 'Delivered';

	/// en: 'Seen'
	String get statusSeen => 'Seen';

	/// en: 'Message options'
	String get messageOptions => 'Message options';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Saved'
	String get saved => 'Saved';

	/// en: 'Download'
	String get download => 'Download';

	/// en: 'Couldn't download'
	String get downloadFailed => 'Couldn\'t download';

	/// en: 'Play'
	String get play => 'Play';

	/// en: 'Pause'
	String get pause => 'Pause';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Attach'
	String get attach => 'Attach';

	/// en: 'Remove'
	String get removeAttachment => 'Remove';

	/// en: 'Record voice message'
	String get recordVoice => 'Record voice message';

	/// en: 'Hold to record, release to send'
	String get holdToRecord => 'Hold to record, release to send';

	/// en: 'Allow microphone access to record'
	String get microphoneDenied => 'Allow microphone access to record';

	/// en: 'Slide up to lock'
	String get slideUpToLock => 'Slide up to lock';

	/// en: 'Stop recording'
	String get stopRecording => 'Stop recording';

	/// en: 'Back'
	String get back => 'Back';

	/// en: 'Forward'
	String get forward => 'Forward';

	/// en: 'Select'
	String get select => 'Select';

	/// en: 'Pin'
	String get pin => 'Pin';

	/// en: 'Unpin'
	String get unpin => 'Unpin';

	/// en: 'Mute'
	String get mute => 'Mute';

	/// en: 'Unmute'
	String get unmute => 'Unmute';

	/// en: 'Clear search'
	String get clearSearch => 'Clear search';

	/// en: 'No results'
	String get noResults => 'No results';

	/// en: 'Couldn't load conversations'
	String get loadChatsFailed => 'Couldn\'t load conversations';

	/// en: 'Switch profile'
	String get switchProfile => 'Switch profile';

	/// en: 'Business'
	String get businessProfile => 'Business';

	/// en: '$name is typing'
	String typingOne({required Object name}) => '${name} is typing';

	/// en: '$a and $b are typing'
	String typingTwo({required Object a, required Object b}) => '${a} and ${b} are typing';

	/// en: '(one) {$n person is typing} (other) {$n people are typing}'
	String typingMany({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} person is typing',
		other: '${n} people are typing',
	);

	/// en: 'last seen $when'
	String lastSeen({required Object when}) => 'last seen ${when}';

	/// en: '(one) {Photo} (other) {$n photos}'
	String photos({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Photo',
		other: '${n} photos',
	);

	/// en: '(one) {$emoji, 1 reaction} (other) {$emoji, $n reactions}'
	String reaction({required num n, required Object emoji}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${emoji}, 1 reaction',
		other: '${emoji}, ${n} reactions',
	);

	/// en: 'React with $emoji'
	String reactWith({required Object emoji}) => 'React with ${emoji}';

	/// en: '${speed}x'
	String playbackSpeed({required Object speed}) => '${speed}x';

	/// en: '+$n'
	String moreMedia({required Object n}) => '+${n}';

	/// en: '$index of $total'
	String mediaPosition({required Object index, required Object total}) => '${index} of ${total}';

	/// en: '(one) {1 member} (other) {$n members}'
	String members({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '1 member',
		other: '${n} members',
	);

	/// en: '$n'
	String selectedCount({required Object n}) => '${n}';

	/// en: '$author: $text'
	String previewWithAuthor({required Object author, required Object text}) => '${author}: ${text}';

	/// en: '(one) {1 unread message} (other) {$n unread messages}'
	String unreadCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '1 unread message',
		other: '${n} unread messages',
	);

	late final Translations$chat$system$en system = Translations$chat$system$en.internal(_root);
}

// Path: app.filters
class Translations$app$filters$en {
	Translations$app$filters$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'All'
	String get all => 'All';

	/// en: 'Chats'
	String get chats => 'Chats';

	/// en: 'Groups'
	String get groups => 'Groups';

	/// en: 'Unread'
	String get unread => 'Unread';

	/// en: 'Friends'
	String get friends => 'Friends';
}

// Path: style.presets
class Translations$style$presets$en {
	Translations$style$presets$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Classic'
	String get classic => 'Classic';

	/// en: 'WhatsApp'
	String get whatsApp => 'WhatsApp';

	/// en: 'WhatsApp (new)'
	String get whatsAppNew => 'WhatsApp (new)';

	/// en: 'Telegram'
	String get telegram => 'Telegram';

	/// en: 'iMessage'
	String get iMessage => 'iMessage';

	/// en: 'Messenger'
	String get messenger => 'Messenger';

	/// en: 'Minimal'
	String get minimal => 'Minimal';

	/// en: 'Cards'
	String get cards => 'Cards';

	/// en: 'Glass'
	String get glass => 'Glass';
}

// Path: chat.system
class Translations$chat$system$en {
	Translations$chat$system$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '$name created the group "$title"'
	String roomCreated({required Object name, required Object title}) => '${name} created the group "${title}"';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'languageName' => 'English',
			'app.title' => 'flutter_chat_pro example',
			'app.chats' => 'Chats',
			'app.chatsWithUnread' => ({required Object n}) => 'Chats (${n})',
			'app.language' => 'Language',
			'app.randomFailures' => 'Random send failures',
			'app.startLiveMessages' => 'Turn on incoming messages',
			'app.stopLiveMessages' => 'Turn off incoming messages',
			'app.resetDemo' => 'Reset demo',
			'app.resetDemoHint' => 'Sample chats and default style',
			'app.goOffline' => 'Go offline',
			'app.goOnline' => 'Go online',
			'app.offlineBanner' => 'Offline: messages are queued and sent when you reconnect.',
			'app.couldNotOpen' => ({required Object error}) => 'Could not open: ${error}',
			'app.makeOffer' => 'Make an offer',
			'app.roomDetails' => 'Open the room details here',
			'app.forward' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Forward 1 message: pick a room here', other: 'Forward ${n} messages: pick a room here', ), 
			'app.filters.all' => 'All',
			'app.filters.chats' => 'Chats',
			'app.filters.groups' => 'Groups',
			'app.filters.unread' => 'Unread',
			'app.filters.friends' => 'Friends',
			'custom.offer' => 'Offer',
			'custom.quote' => 'Quote',
			'custom.booking' => 'Booking',
			'custom.meeting' => 'Meeting',
			'custom.offerPreview' => ({required Object title, required Object amount}) => 'Offer: ${title} (${amount})',
			'custom.quotePreview' => ({required Object title, required Object amount}) => 'Quote: ${title} (${amount})',
			'custom.decline' => 'Decline',
			'custom.accept' => 'Accept',
			'custom.acceptQuote' => 'Accept quote',
			'custom.total' => 'Total',
			'custom.validFor' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Valid for 1 day', other: 'Valid for ${n} days', ), 
			'custom.deal' => 'Deal! ✅',
			'custom.noThanks' => 'No thanks, maybe next time',
			'custom.quoteAccepted' => 'Quote accepted, please go ahead ✅',
			'custom.customOrder' => 'Custom order',
			'custom.wallet' => 'Leather wallet',
			'custom.engraving' => 'Name engraving',
			'custom.giftBox' => 'Gift box',
			'custom.what' => 'What',
			'custom.price' => 'Price',
			'custom.cancel' => 'Cancel',
			'custom.send' => 'Send',
			'style.button' => 'Chat style',
			'style.preset' => 'Preset',
			'style.colors' => 'Colors',
			'style.darkMode' => 'Dark mode',
			'style.size' => 'Size',
			'style.design' => 'Design',
			'style.byScreen' => 'By screen',
			'style.scaleKit' => 'Scale kit',
			'style.zoom' => 'Zoom',
			'style.textSize' => 'Text size',
			'style.messages' => 'Messages',
			'style.messageFontSize' => 'Message font size',
			'style.greyText' => 'Grey message text',
			'style.bubbleRadius' => 'Bubble radius',
			'style.bubbleShadows' => 'Bubble shadows',
			'style.bubbleBorder' => 'Bubble border',
			'style.inbox' => 'Inbox',
			'style.plain' => 'Plain',
			'style.lines' => 'Lines',
			'style.cards' => 'Cards',
			'style.cardRadius' => 'Card radius',
			'style.squareAvatars' => 'Square avatars',
			'style.reset' => ({required Object name}) => 'Reset "${name}"',
			'style.shuffle' => 'Random style',
			'style.autoShuffle' => 'Shuffle every few seconds',
			'style.startShuffle' => 'Start style shuffle',
			'style.stopShuffle' => 'Stop style shuffle',
			'style.presets.classic' => 'Classic',
			'style.presets.whatsApp' => 'WhatsApp',
			'style.presets.whatsAppNew' => 'WhatsApp (new)',
			'style.presets.telegram' => 'Telegram',
			'style.presets.iMessage' => 'iMessage',
			'style.presets.messenger' => 'Messenger',
			'style.presets.minimal' => 'Minimal',
			'style.presets.cards' => 'Cards',
			'style.presets.glass' => 'Glass',
			'chat.typeMessage' => 'Message',
			'chat.today' => 'Today',
			'chat.yesterday' => 'Yesterday',
			'chat.newMessages' => 'New messages',
			'chat.reply' => 'Reply',
			'chat.copy' => 'Copy',
			'chat.copied' => 'Copied',
			'chat.edit' => 'Edit',
			'chat.delete' => 'Delete',
			'chat.retry' => 'Retry',
			'chat.cancel' => 'Cancel',
			'chat.send' => 'Send',
			'chat.failedToSend' => 'Failed to send',
			'chat.messageDeleted' => 'This message was deleted',
			'chat.unsupportedMessage' => 'Unsupported message',
			'chat.edited' => 'edited',
			'chat.editing' => 'Editing',
			'chat.you' => 'You',
			'chat.online' => 'online',
			'chat.slideToCancel' => 'Slide to cancel',
			'chat.searchChats' => 'Search',
			'chat.noChats' => 'No conversations yet',
			'chat.noMessages' => 'Say hello',
			'chat.loadFailed' => 'Couldn\'t load messages',
			'chat.startOfConversation' => 'This is the start of the conversation',
			'chat.scrollToBottom' => 'Scroll to latest',
			'chat.photo' => 'Photo',
			'chat.video' => 'Video',
			'chat.voice' => 'Voice message',
			'chat.file' => 'File',
			'chat.camera' => 'Camera',
			'chat.gallery' => 'Gallery',
			'chat.attachmentTooLarge' => 'File is too large',
			'chat.fileUnavailable' => 'This file is no longer available. Delete it and send it again.',
			'chat.compressing' => 'Compressing',
			'chat.readMore' => 'Read more',
			'chat.readLess' => 'Show less',
			'chat.replyUnavailable' => 'Original message unavailable',
			'chat.statusPending' => 'Sending',
			'chat.statusSent' => 'Sent',
			'chat.statusDelivered' => 'Delivered',
			'chat.statusSeen' => 'Seen',
			'chat.messageOptions' => 'Message options',
			'chat.save' => 'Save',
			'chat.saved' => 'Saved',
			'chat.download' => 'Download',
			'chat.downloadFailed' => 'Couldn\'t download',
			'chat.play' => 'Play',
			'chat.pause' => 'Pause',
			'chat.close' => 'Close',
			'chat.attach' => 'Attach',
			'chat.removeAttachment' => 'Remove',
			'chat.recordVoice' => 'Record voice message',
			'chat.holdToRecord' => 'Hold to record, release to send',
			'chat.microphoneDenied' => 'Allow microphone access to record',
			'chat.slideUpToLock' => 'Slide up to lock',
			'chat.stopRecording' => 'Stop recording',
			'chat.back' => 'Back',
			'chat.forward' => 'Forward',
			'chat.select' => 'Select',
			'chat.pin' => 'Pin',
			'chat.unpin' => 'Unpin',
			'chat.mute' => 'Mute',
			'chat.unmute' => 'Unmute',
			'chat.clearSearch' => 'Clear search',
			'chat.noResults' => 'No results',
			'chat.loadChatsFailed' => 'Couldn\'t load conversations',
			'chat.switchProfile' => 'Switch profile',
			'chat.businessProfile' => 'Business',
			'chat.typingOne' => ({required Object name}) => '${name} is typing',
			'chat.typingTwo' => ({required Object a, required Object b}) => '${a} and ${b} are typing',
			'chat.typingMany' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} person is typing', other: '${n} people are typing', ), 
			'chat.lastSeen' => ({required Object when}) => 'last seen ${when}',
			'chat.photos' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Photo', other: '${n} photos', ), 
			'chat.reaction' => ({required num n, required Object emoji}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${emoji}, 1 reaction', other: '${emoji}, ${n} reactions', ), 
			'chat.reactWith' => ({required Object emoji}) => 'React with ${emoji}',
			'chat.playbackSpeed' => ({required Object speed}) => '${speed}x',
			'chat.moreMedia' => ({required Object n}) => '+${n}',
			'chat.mediaPosition' => ({required Object index, required Object total}) => '${index} of ${total}',
			'chat.members' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '1 member', other: '${n} members', ), 
			'chat.selectedCount' => ({required Object n}) => '${n}',
			'chat.previewWithAuthor' => ({required Object author, required Object text}) => '${author}: ${text}',
			'chat.unreadCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '1 unread message', other: '${n} unread messages', ), 
			'chat.system.roomCreated' => ({required Object name, required Object title}) => '${name} created the group "${title}"',
			_ => null,
		};
	}
}
