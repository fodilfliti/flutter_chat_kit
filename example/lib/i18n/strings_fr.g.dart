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
class TranslationsFr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <fr>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsFr _root = this; // ignore: unused_field

	@override 
	TranslationsFr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFr(meta: meta ?? this.$meta);

	// Translations
	@override String get languageName => 'Français';
	@override late final _Translations$app$fr app = _Translations$app$fr._(_root);
	@override late final _Translations$custom$fr custom = _Translations$custom$fr._(_root);
	@override late final _Translations$style$fr style = _Translations$style$fr._(_root);
	@override late final _Translations$chat$fr chat = _Translations$chat$fr._(_root);
}

// Path: app
class _Translations$app$fr extends Translations$app$en {
	_Translations$app$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exemple flutter_chat_kit';
	@override String get chats => 'Discussions';
	@override String chatsWithUnread({required Object n}) => 'Discussions (${n})';
	@override String get language => 'Langue';
	@override String get randomFailures => 'Échecs d\'envoi aléatoires';
	@override String get resetDemo => 'Réinitialiser la démo';
	@override String get resetDemoHint => 'Discussions d\'exemple et style par défaut';
	@override String get goOffline => 'Passer hors ligne';
	@override String get goOnline => 'Passer en ligne';
	@override String get offlineBanner => 'Hors ligne : les messages sont mis en file d\'attente et envoyés à la reconnexion.';
	@override String couldNotOpen({required Object error}) => 'Ouverture impossible : ${error}';
	@override String get makeOffer => 'Faire une offre';
	@override String get roomDetails => 'Ouvrez ici les détails de la discussion';
	@override String forward({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n,
		one: 'Transférer 1 message : choisissez une discussion ici',
		other: 'Transférer ${n} messages : choisissez une discussion ici',
	);
	@override late final _Translations$app$filters$fr filters = _Translations$app$filters$fr._(_root);
}

// Path: custom
class _Translations$custom$fr extends Translations$custom$en {
	_Translations$custom$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get offer => 'Offre';
	@override String get quote => 'Devis';
	@override String get booking => 'Rendez-vous';
	@override String get meeting => 'Réunion';
	@override String offerPreview({required Object title, required Object amount}) => 'Offre : ${title} (${amount})';
	@override String quotePreview({required Object title, required Object amount}) => 'Devis : ${title} (${amount})';
	@override String get decline => 'Refuser';
	@override String get accept => 'Accepter';
	@override String get acceptQuote => 'Accepter le devis';
	@override String get total => 'Total';
	@override String validFor({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n,
		one: 'Valable 1 jour',
		other: 'Valable ${n} jours',
	);
	@override String get deal => 'Marché conclu ! ✅';
	@override String get noThanks => 'Non merci, une prochaine fois';
	@override String get quoteAccepted => 'Devis accepté, vous pouvez commencer ✅';
	@override String get customOrder => 'Commande personnalisée';
	@override String get wallet => 'Portefeuille en cuir';
	@override String get engraving => 'Gravure du nom';
	@override String get giftBox => 'Boîte cadeau';
	@override String get what => 'Quoi';
	@override String get price => 'Prix';
	@override String get cancel => 'Annuler';
	@override String get send => 'Envoyer';
}

// Path: style
class _Translations$style$fr extends Translations$style$en {
	_Translations$style$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get button => 'Style du chat';
	@override String get preset => 'Modèle';
	@override String get colors => 'Couleurs';
	@override String get darkMode => 'Mode sombre';
	@override String get size => 'Taille';
	@override String get design => 'Maquette';
	@override String get byScreen => 'Selon l\'écran';
	@override String get scaleKit => 'Scale kit';
	@override String get zoom => 'Zoom';
	@override String get textSize => 'Taille du texte';
	@override String get messages => 'Messages';
	@override String get messageFontSize => 'Taille des messages';
	@override String get greyText => 'Texte des messages en gris';
	@override String get bubbleRadius => 'Arrondi des bulles';
	@override String get bubbleShadows => 'Ombre des bulles';
	@override String get bubbleBorder => 'Bordure des bulles';
	@override String get inbox => 'Liste des discussions';
	@override String get plain => 'Simple';
	@override String get lines => 'Lignes';
	@override String get cards => 'Cartes';
	@override String get cardRadius => 'Arrondi des cartes';
	@override String get squareAvatars => 'Avatars carrés';
	@override String reset({required Object name}) => 'Réinitialiser « ${name} »';
	@override late final _Translations$style$presets$fr presets = _Translations$style$presets$fr._(_root);
}

// Path: chat
class _Translations$chat$fr extends Translations$chat$en {
	_Translations$chat$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get typeMessage => 'Message';
	@override String get today => 'Aujourd\'hui';
	@override String get yesterday => 'Hier';
	@override String get newMessages => 'Nouveaux messages';
	@override String get reply => 'Répondre';
	@override String get copy => 'Copier';
	@override String get copied => 'Copié';
	@override String get edit => 'Modifier';
	@override String get delete => 'Supprimer';
	@override String get retry => 'Réessayer';
	@override String get cancel => 'Annuler';
	@override String get send => 'Envoyer';
	@override String get failedToSend => 'Échec de l\'envoi';
	@override String get messageDeleted => 'Ce message a été supprimé';
	@override String get unsupportedMessage => 'Message non pris en charge';
	@override String get edited => 'modifié';
	@override String get editing => 'Modification';
	@override String get you => 'Vous';
	@override String get online => 'en ligne';
	@override String get slideToCancel => 'Glisser pour annuler';
	@override String get searchChats => 'Rechercher';
	@override String get noChats => 'Aucune discussion pour l\'instant';
	@override String get noMessages => 'Dites bonjour';
	@override String get loadFailed => 'Impossible de charger les messages';
	@override String get startOfConversation => 'Début de la discussion';
	@override String get scrollToBottom => 'Aller aux derniers messages';
	@override String get photo => 'Photo';
	@override String get video => 'Vidéo';
	@override String get voice => 'Message vocal';
	@override String get file => 'Fichier';
	@override String get camera => 'Appareil photo';
	@override String get gallery => 'Galerie';
	@override String get attachmentTooLarge => 'Fichier trop volumineux';
	@override String get readMore => 'Lire la suite';
	@override String get readLess => 'Réduire';
	@override String get replyUnavailable => 'Message d\'origine indisponible';
	@override String get statusPending => 'Envoi en cours';
	@override String get statusSent => 'Envoyé';
	@override String get statusDelivered => 'Distribué';
	@override String get statusSeen => 'Vu';
	@override String get messageOptions => 'Options du message';
	@override String get save => 'Enregistrer';
	@override String get saved => 'Enregistré';
	@override String get download => 'Télécharger';
	@override String get downloadFailed => 'Échec du téléchargement';
	@override String get play => 'Lire';
	@override String get pause => 'Pause';
	@override String get close => 'Fermer';
	@override String get attach => 'Joindre';
	@override String get removeAttachment => 'Retirer';
	@override String get recordVoice => 'Enregistrer un message vocal';
	@override String get holdToRecord => 'Maintenez pour enregistrer, relâchez pour envoyer';
	@override String get microphoneDenied => 'Autorisez l\'accès au micro pour enregistrer';
	@override String get slideUpToLock => 'Glisser vers le haut pour verrouiller';
	@override String get stopRecording => 'Arrêter l\'enregistrement';
	@override String get back => 'Retour';
	@override String get forward => 'Transférer';
	@override String get select => 'Sélectionner';
	@override String get pin => 'Épingler';
	@override String get unpin => 'Désépingler';
	@override String get mute => 'Sourdine';
	@override String get unmute => 'Réactiver';
	@override String get clearSearch => 'Effacer la recherche';
	@override String get noResults => 'Aucun résultat';
	@override String get loadChatsFailed => 'Impossible de charger les discussions';
	@override String get switchProfile => 'Changer de profil';
	@override String get businessProfile => 'Entreprise';
	@override String typingOne({required Object name}) => '${name} écrit…';
	@override String typingTwo({required Object a, required Object b}) => '${a} et ${b} écrivent…';
	@override String typingMany({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n,
		one: '${n} personne écrit…',
		other: '${n} personnes écrivent…',
	);
	@override String lastSeen({required Object when}) => 'vu pour la dernière fois : ${when}';
	@override String photos({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n,
		one: 'Photo',
		other: '${n} photos',
	);
	@override String reaction({required num n, required Object emoji}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n,
		one: '${emoji}, 1 réaction',
		other: '${emoji}, ${n} réactions',
	);
	@override String reactWith({required Object emoji}) => 'Réagir avec ${emoji}';
	@override String playbackSpeed({required Object speed}) => '${speed}x';
	@override String moreMedia({required Object n}) => '+${n}';
	@override String mediaPosition({required Object index, required Object total}) => '${index} sur ${total}';
	@override String members({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n,
		one: '1 membre',
		other: '${n} membres',
	);
	@override String selectedCount({required Object n}) => '${n}';
	@override String previewWithAuthor({required Object author, required Object text}) => '${author} : ${text}';
	@override String unreadCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n,
		one: '1 message non lu',
		other: '${n} messages non lus',
	);
	@override late final _Translations$chat$system$fr system = _Translations$chat$system$fr._(_root);
}

// Path: app.filters
class _Translations$app$filters$fr extends Translations$app$filters$en {
	_Translations$app$filters$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get all => 'Toutes';
	@override String get chats => 'Privées';
	@override String get groups => 'Groupes';
	@override String get unread => 'Non lues';
	@override String get friends => 'Amis';
}

// Path: style.presets
class _Translations$style$presets$fr extends Translations$style$presets$en {
	_Translations$style$presets$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get classic => 'Classique';
	@override String get whatsApp => 'WhatsApp';
	@override String get telegram => 'Telegram';
	@override String get minimal => 'Minimal';
	@override String get cards => 'Cartes';
}

// Path: chat.system
class _Translations$chat$system$fr extends Translations$chat$system$en {
	_Translations$chat$system$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String roomCreated({required Object name, required Object title}) => '${name} a créé le groupe « ${title} »';
}

/// The flat map containing all translations for locale <fr>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsFr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'languageName' => 'Français',
			'app.title' => 'Exemple flutter_chat_kit',
			'app.chats' => 'Discussions',
			'app.chatsWithUnread' => ({required Object n}) => 'Discussions (${n})',
			'app.language' => 'Langue',
			'app.randomFailures' => 'Échecs d\'envoi aléatoires',
			'app.resetDemo' => 'Réinitialiser la démo',
			'app.resetDemoHint' => 'Discussions d\'exemple et style par défaut',
			'app.goOffline' => 'Passer hors ligne',
			'app.goOnline' => 'Passer en ligne',
			'app.offlineBanner' => 'Hors ligne : les messages sont mis en file d\'attente et envoyés à la reconnexion.',
			'app.couldNotOpen' => ({required Object error}) => 'Ouverture impossible : ${error}',
			'app.makeOffer' => 'Faire une offre',
			'app.roomDetails' => 'Ouvrez ici les détails de la discussion',
			'app.forward' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n, one: 'Transférer 1 message : choisissez une discussion ici', other: 'Transférer ${n} messages : choisissez une discussion ici', ), 
			'app.filters.all' => 'Toutes',
			'app.filters.chats' => 'Privées',
			'app.filters.groups' => 'Groupes',
			'app.filters.unread' => 'Non lues',
			'app.filters.friends' => 'Amis',
			'custom.offer' => 'Offre',
			'custom.quote' => 'Devis',
			'custom.booking' => 'Rendez-vous',
			'custom.meeting' => 'Réunion',
			'custom.offerPreview' => ({required Object title, required Object amount}) => 'Offre : ${title} (${amount})',
			'custom.quotePreview' => ({required Object title, required Object amount}) => 'Devis : ${title} (${amount})',
			'custom.decline' => 'Refuser',
			'custom.accept' => 'Accepter',
			'custom.acceptQuote' => 'Accepter le devis',
			'custom.total' => 'Total',
			'custom.validFor' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n, one: 'Valable 1 jour', other: 'Valable ${n} jours', ), 
			'custom.deal' => 'Marché conclu ! ✅',
			'custom.noThanks' => 'Non merci, une prochaine fois',
			'custom.quoteAccepted' => 'Devis accepté, vous pouvez commencer ✅',
			'custom.customOrder' => 'Commande personnalisée',
			'custom.wallet' => 'Portefeuille en cuir',
			'custom.engraving' => 'Gravure du nom',
			'custom.giftBox' => 'Boîte cadeau',
			'custom.what' => 'Quoi',
			'custom.price' => 'Prix',
			'custom.cancel' => 'Annuler',
			'custom.send' => 'Envoyer',
			'style.button' => 'Style du chat',
			'style.preset' => 'Modèle',
			'style.colors' => 'Couleurs',
			'style.darkMode' => 'Mode sombre',
			'style.size' => 'Taille',
			'style.design' => 'Maquette',
			'style.byScreen' => 'Selon l\'écran',
			'style.scaleKit' => 'Scale kit',
			'style.zoom' => 'Zoom',
			'style.textSize' => 'Taille du texte',
			'style.messages' => 'Messages',
			'style.messageFontSize' => 'Taille des messages',
			'style.greyText' => 'Texte des messages en gris',
			'style.bubbleRadius' => 'Arrondi des bulles',
			'style.bubbleShadows' => 'Ombre des bulles',
			'style.bubbleBorder' => 'Bordure des bulles',
			'style.inbox' => 'Liste des discussions',
			'style.plain' => 'Simple',
			'style.lines' => 'Lignes',
			'style.cards' => 'Cartes',
			'style.cardRadius' => 'Arrondi des cartes',
			'style.squareAvatars' => 'Avatars carrés',
			'style.reset' => ({required Object name}) => 'Réinitialiser « ${name} »',
			'style.presets.classic' => 'Classique',
			'style.presets.whatsApp' => 'WhatsApp',
			'style.presets.telegram' => 'Telegram',
			'style.presets.minimal' => 'Minimal',
			'style.presets.cards' => 'Cartes',
			'chat.typeMessage' => 'Message',
			'chat.today' => 'Aujourd\'hui',
			'chat.yesterday' => 'Hier',
			'chat.newMessages' => 'Nouveaux messages',
			'chat.reply' => 'Répondre',
			'chat.copy' => 'Copier',
			'chat.copied' => 'Copié',
			'chat.edit' => 'Modifier',
			'chat.delete' => 'Supprimer',
			'chat.retry' => 'Réessayer',
			'chat.cancel' => 'Annuler',
			'chat.send' => 'Envoyer',
			'chat.failedToSend' => 'Échec de l\'envoi',
			'chat.messageDeleted' => 'Ce message a été supprimé',
			'chat.unsupportedMessage' => 'Message non pris en charge',
			'chat.edited' => 'modifié',
			'chat.editing' => 'Modification',
			'chat.you' => 'Vous',
			'chat.online' => 'en ligne',
			'chat.slideToCancel' => 'Glisser pour annuler',
			'chat.searchChats' => 'Rechercher',
			'chat.noChats' => 'Aucune discussion pour l\'instant',
			'chat.noMessages' => 'Dites bonjour',
			'chat.loadFailed' => 'Impossible de charger les messages',
			'chat.startOfConversation' => 'Début de la discussion',
			'chat.scrollToBottom' => 'Aller aux derniers messages',
			'chat.photo' => 'Photo',
			'chat.video' => 'Vidéo',
			'chat.voice' => 'Message vocal',
			'chat.file' => 'Fichier',
			'chat.camera' => 'Appareil photo',
			'chat.gallery' => 'Galerie',
			'chat.attachmentTooLarge' => 'Fichier trop volumineux',
			'chat.readMore' => 'Lire la suite',
			'chat.readLess' => 'Réduire',
			'chat.replyUnavailable' => 'Message d\'origine indisponible',
			'chat.statusPending' => 'Envoi en cours',
			'chat.statusSent' => 'Envoyé',
			'chat.statusDelivered' => 'Distribué',
			'chat.statusSeen' => 'Vu',
			'chat.messageOptions' => 'Options du message',
			'chat.save' => 'Enregistrer',
			'chat.saved' => 'Enregistré',
			'chat.download' => 'Télécharger',
			'chat.downloadFailed' => 'Échec du téléchargement',
			'chat.play' => 'Lire',
			'chat.pause' => 'Pause',
			'chat.close' => 'Fermer',
			'chat.attach' => 'Joindre',
			'chat.removeAttachment' => 'Retirer',
			'chat.recordVoice' => 'Enregistrer un message vocal',
			'chat.holdToRecord' => 'Maintenez pour enregistrer, relâchez pour envoyer',
			'chat.microphoneDenied' => 'Autorisez l\'accès au micro pour enregistrer',
			'chat.slideUpToLock' => 'Glisser vers le haut pour verrouiller',
			'chat.stopRecording' => 'Arrêter l\'enregistrement',
			'chat.back' => 'Retour',
			'chat.forward' => 'Transférer',
			'chat.select' => 'Sélectionner',
			'chat.pin' => 'Épingler',
			'chat.unpin' => 'Désépingler',
			'chat.mute' => 'Sourdine',
			'chat.unmute' => 'Réactiver',
			'chat.clearSearch' => 'Effacer la recherche',
			'chat.noResults' => 'Aucun résultat',
			'chat.loadChatsFailed' => 'Impossible de charger les discussions',
			'chat.switchProfile' => 'Changer de profil',
			'chat.businessProfile' => 'Entreprise',
			'chat.typingOne' => ({required Object name}) => '${name} écrit…',
			'chat.typingTwo' => ({required Object a, required Object b}) => '${a} et ${b} écrivent…',
			'chat.typingMany' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n, one: '${n} personne écrit…', other: '${n} personnes écrivent…', ), 
			'chat.lastSeen' => ({required Object when}) => 'vu pour la dernière fois : ${when}',
			'chat.photos' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n, one: 'Photo', other: '${n} photos', ), 
			'chat.reaction' => ({required num n, required Object emoji}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n, one: '${emoji}, 1 réaction', other: '${emoji}, ${n} réactions', ), 
			'chat.reactWith' => ({required Object emoji}) => 'Réagir avec ${emoji}',
			'chat.playbackSpeed' => ({required Object speed}) => '${speed}x',
			'chat.moreMedia' => ({required Object n}) => '+${n}',
			'chat.mediaPosition' => ({required Object index, required Object total}) => '${index} sur ${total}',
			'chat.members' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n, one: '1 membre', other: '${n} membres', ), 
			'chat.selectedCount' => ({required Object n}) => '${n}',
			'chat.previewWithAuthor' => ({required Object author, required Object text}) => '${author} : ${text}',
			'chat.unreadCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n, one: '1 message non lu', other: '${n} messages non lus', ), 
			'chat.system.roomCreated' => ({required Object name, required Object title}) => '${name} a créé le groupe « ${title} »',
			_ => null,
		};
	}
}
