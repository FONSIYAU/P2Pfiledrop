import 'app_strings.dart';

class StringsDe extends AppStrings {
  const StringsDe();

  static const _months = <String>[
    'Jan.',
    'Feb.',
    'März',
    'Apr.',
    'Mai',
    'Juni',
    'Juli',
    'Aug.',
    'Sept.',
    'Okt.',
    'Nov.',
    'Dez.',
  ];

  @override
  String get localeCode => 'de';

  @override
  String get appTitle => 'P2Pfiledrop';
  @override
  String get appSubtitle => 'Ende-zu-Ende-verschlüsselte Übertragung';
  @override
  String get startingEngine => 'Verschlüsselte P2P-Engine wird gestartet...';
  @override
  String engineInitFailed(Object error) => 'Start der Engine fehlgeschlagen:\n$error';
  @override
  String get retry => 'Wiederholen';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get confirm => 'OK';
  @override
  String get close => 'Schließen';
  @override
  String get save => 'Speichern';
  @override
  String get delete => 'Löschen';
  @override
  String get remove => 'Entfernen';
  @override
  String get open => 'Öffnen';
  @override
  String get refresh => 'Aktualisieren';
  @override
  String get clear => 'Leeren';
  @override
  String get resetDefault => 'Standard';
  @override
  String get recommendedBadge => 'Empfohlen';
  @override
  String get defaultAvatarFallback => 'G';

  @override
  String formatFullDate(DateTime dt) =>
      '${dt.day}. ${_months[dt.month - 1]} ${dt.year}';
  @override
  String formatMonthDay(DateTime dt) => '${dt.day}. ${_months[dt.month - 1]}';
  @override
  String get todayLabel => 'Heute';
  @override
  String get yesterdayLabel => 'Gestern';
  @override
  String formatRemainingSeconds(int seconds) => 'Noch ${seconds}s';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      'Noch ${minutes}m ${seconds}s';

  @override
  String get navTransfers => 'Chats';
  @override
  String get navDevices => 'Geräte';
  @override
  String get navThisDevice => 'Ich';
  @override
  String get navAdd => 'Neu';
  @override
  String get navFiles => 'Dateien';
  @override
  String get navFolder => 'Ordner';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName (Einstellungen)';
  @override
  String get tooltipScanPair => 'QR scannen zum Koppeln / Beitreten';
  @override
  String get tooltipAllFiles => 'Alle übertragenen Dateien & Fotos ansehen';
  @override
  String tooltipOpenReceiveFolder(String dir) => 'Empfangsordner öffnen ($dir)';

  @override
  String get transportUsbTether => 'USB-Direkt';
  @override
  String get transportLanDirect => 'LAN-Direkt';
  @override
  String get transportWanP2p => 'WAN P2P';
  @override
  String get transportWanRelay => 'Relay';
  @override
  String get transportOffline => 'Offline';
  @override
  String get usbTetherTag => 'USB-Direkt';

  @override
  String get msgStatusQueuedOffline => 'Wartet auf Peer';
  @override
  String get msgStatusHandshaking => 'Handshake läuft';
  @override
  String get msgStatusTransferring => 'Wird gesendet';
  @override
  String get msgStatusPausedReconnecting => 'Wird fortgesetzt';
  @override
  String get msgStatusAwaitingDownload => 'Zum Laden tippen';
  @override
  String get msgStatusDelivered => 'Zugestellt';
  @override
  String get msgStatusFailedSourceMissing => 'Quelle fehlt';

  @override
  String deviceWithTag(String tag) => '$tag-Gerät';
  @override
  String deviceShortIdLabel(String shortId) => 'Gerät · $shortId';
  @override
  String get peerDeviceFallback => 'Partnergerät';
  @override
  String get defaultPersonalRoomName => 'Meine Geräte (Personal)';
  @override
  String get defaultEncryptedGroupName => 'Neue verschlüsselte Gruppe';
  @override
  String get defaultPrivateRoomName => 'Neuer verschlüsselter Raum';
  @override
  String encryptedRoomWithId(String shortId) => 'Verschl. Raum ($shortId)';
  @override
  String get homeNodeDefaultName => '24h-Heimknoten';

  @override
  String get chatListTitle => 'Chats';
  @override
  String get chatListNewActionTooltip => 'QR scannen / Gruppe erstellen';
  @override
  String get menuScanPairOrJoin => 'QR scannen: Koppeln / Beitreten';
  @override
  String get menuCreateGroup => 'Geteilte Gruppe erstellen';
  @override
  String get menuMyPairingQr => 'Mein Kopplungs-QR';
  @override
  String get menuOpenReceiveFolder => 'Empfangsordner öffnen';
  @override
  String get menuProbeReconnect => 'Verbindung prüfen';
  @override
  String get searchChatsHint => 'Chats oder Geräte suchen...';
  @override
  String groupOnlineCount(int online, int total) =>
      'Gruppe ($online/$total online)';
  @override
  String groupOfflineCount(int total) => 'Gruppe ($total Geräte · offline)';
  @override
  String get emptyChatsSearch => 'Keine passenden Chats';
  @override
  String get emptyChatsNoRooms => 'Noch keine Chats vorhanden';
  @override
  String get btnScanPairDevice => 'Per QR koppeln';
  @override
  String get btnGoToDevices => 'Zu Geräten wechseln';

  @override
  String get devicesListTitle => 'Geräte';
  @override
  String get searchPairedDevicesHint => 'Gekoppelte Geräte suchen...';
  @override
  String get btnAddNewDevice => 'Gerät hinzufügen / QR';
  @override
  String get btnNewSharedGroup => 'Neue Gruppe erstellen';
  @override
  String get btnAddDeviceShort => 'Hinzufügen';
  @override
  String get btnNewGroupShort => 'Neue Gruppe';
  @override
  String pairedDevicesCount(int count) => 'Gekoppelte Geräte ($count)';
  @override
  String get emptyDevicesSearch => 'Keine passenden Geräte';
  @override
  String get emptyDevicesNone =>
      'Noch keine gekoppelten Geräte\nTippe oben auf "Gerät hinzufügen / QR"';
  @override
  String get selectDevicePrompt => 'Links ein Gerät für Details wählen';
  @override
  String get btnScanFirstDevice => 'Erstes Gerät koppeln';
  @override
  String originalNameLabel(String name) => 'Originalname: $name';
  @override
  String get deviceNodeIdLabel => 'Geräte-Node-ID (Endpoint ID)';
  @override
  String get tooltipCopyDeviceId => 'ID kopieren';
  @override
  String get toastCopiedDeviceId => 'Geräte-ID kopiert';
  @override
  String get btnSendMessageOrFile => 'Nachricht / Datei senden';
  @override
  String get btnEditRemark => 'Alias bearbeiten';
  @override
  String get btnDeleteDevice => 'Dieses Gerät entfernen';
  @override
  String get deletePeerDialogTitle => 'Gekoppeltes Gerät entfernen';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      '"$resolvedName" aus vertrauenswürdigen Geräten entfernen und Direktchat löschen? (Gespeicherte Dateien bleiben erhalten).';
  @override
  String get btnConfirmDelete => 'Entfernen';

  @override
  String get desktopWorkspaceTitle => 'Transfer-Arbeitsbereich';
  @override
  String get btnOpenFolder => 'Ordner öffnen';
  @override
  String get tooltipRoomFiles => 'Dateien & Fotos des Raums';
  @override
  String get tooltipInviteOrScan => 'Per QR einladen / Scannen';
  @override
  String get tooltipRoomMembers => 'Gerätedetails / Gruppenverwaltung';
  @override
  String get desktopEmptyTitle => 'Links einen Chat oder ein Gerät wählen';
  @override
  String get desktopEmptySubtitle =>
      'Direktes LAN, USB-Kabel-Priorität und verschlüsselte Fernübertragung. Dateien einfach hierher ziehen.';
  @override
  String get moreActionsTooltip => 'Weitere Aktionen';
  @override
  String get moreTooltip => 'Mehr';
  @override
  String get emptyRoomNoSession => 'Kein aktiver Chat. Kopple zuerst ein Gerät per QR.';
  @override
  String get emptyRoomE2eeNotice =>
      'Dieser Raum ist Ende-zu-Ende-verschlüsselt; nur Mitglieder können Inhalte entschlüsseln.';
  @override
  String get emptyRoomWindowsHint =>
      'Dateien oder Fotos zum Senden hierher ziehen oder unten Text eingeben.';
  @override
  String get emptyRoomMobileHint =>
      'Tippe unten auf + für Fotos/Dateien oder gib eine Nachricht ein.';
  @override
  String dropZonePrompt(String roomTitle) =>
      'Loslassen für verschlüsselten Versand an "$roomTitle"';
  @override
  String get menuAddPairedToGroup => 'Gekoppelte Geräte einladen';
  @override
  String get menuDeviceDetailsAndRemark => 'Gerätedetails & Alias';
  @override
  String get menuGroupMembersAndManage => 'Gruppenmitglieder & Verwaltung';
  @override
  String get noShareTargetsToast => 'Noch keine Geräte oder Chats verfügbar';
  @override
  String get fallbackShortTitle => 'Privattransfer';

  @override
  String get tooltipGalleryImages => 'Galeriefotos';
  @override
  String get tooltipSendFile => 'Datei wählen';
  @override
  String get tooltipSendImageOrFile => 'Foto oder Datei senden';
  @override
  String get tooltipPasteClipboard => 'Bild / Text einfügen';
  @override
  String get inputHintWindows =>
      'Nachricht schreiben, einfügen oder Dateien ablegen...';
  @override
  String get inputHintMobile => 'Nachricht schreiben...';
  @override
  String get inputHintNoRoom => 'Füge oben (+) zuerst ein Gerät hinzu...';
  @override
  String get tooltipSendMessage => 'Senden';

  @override
  String get newMessagesBelowSuffix => 'neue Nachrichten';
  @override
  String albumFailedCount(int failedCount) =>
      'Quelle bei $failedCount Fotos fehlt';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      'Gesendet ($missingCount Originale gelöscht)';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      'Empfangen ($missingCount lokal gelöscht)';
  @override
  String get albumAllDelivered => 'Alle zugestellt';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      'Sende $delivered/$total';
  @override
  String albumImageCount(int count) => '$count Fotos';
  @override
  String get btnExpand => 'Öffnen';
  @override
  String collapseImagesCount(int count) => 'Einklappen ($count)';

  @override
  String get statusLargeFileAwaitConfirm => 'Bestätigung ausstehend';
  @override
  String get statusGroupFileAwaitDownload => 'Bereit zum Laden';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      'Angebot gesendet ($acked/$total)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      'Bestätigen ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      'An alle zugestellt ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) =>
      'Zugestellt ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => 'Quelldatei entfernt';
  @override
  String get statusLocalFileDeleted => 'Lokale Datei gelöscht';
  @override
  String get revokedByMe => 'Du hast diese Nachricht zurückgerufen';
  @override
  String get revokedByPeer => 'Absender hat diese Nachricht zurückgerufen';
  @override
  String get tooltipEditPeerRemark => 'Alias bearbeiten';
  @override
  String get tooltipPeerAvatar => 'Partnergerät';
  @override
  String get toastCopiedText => 'Text kopiert';
  @override
  String toastCopiedPath(String path) => 'Pfad kopiert: $path';
  @override
  String get imageDeletedLocally => 'Foto lokal gelöscht';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · Originalfoto entfernt';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · Foto gelöscht (tippen für Details)';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · Quelle fehlt';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · Lokal gelöscht';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · Große Datei bestätigen';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · Gruppendatei verfügbar';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · Warte auf Abruf';
  @override
  String btnDownloadToDevice(String sizeLabel) => 'Laden ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => 'Jetzt senden ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => 'Bei Verbindung senden';
  @override
  String get actionCopyText => 'Text kopieren';
  @override
  String get actionForward => 'Weiterleiten';
  @override
  String get actionOpenFile => 'Datei öffnen';
  @override
  String get actionRevealInFolder => 'Im Ordner anzeigen';
  @override
  String get actionCopyFilePath => 'Pfad kopieren';

  @override
  String get createGroupTitle => 'Verschlüsselte Gruppe erstellen';
  @override
  String get createGroupDesc =>
      'Gekoppelte Geräte wählen, um sofort eine Gruppe mit eigenem E2EE-Schlüssel zu starten.';
  @override
  String get groupNameOptionalLabel => 'Gruppenname (optional)';
  @override
  String get groupNameAutoHint => 'Leer lassen für automatischen Namen';
  @override
  String get createGroupNoPeersNotice =>
      'Noch keine gekoppelten Geräte. Erstelle die Gruppe und lade später per QR ein.';
  @override
  String selectGroupDevicesCount(int count) =>
      'Geräte wählen ($count markiert):';
  @override
  String get btnCreateGroup => 'Gruppe erstellen';
  @override
  String get defaultGroupNameFallback => 'Verschlüsselte Gruppe';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => '$joinedNames Gruppe';
  @override
  String get nameSeparator => ', ';
  @override
  String get addMembersToGroupTitle => 'Geräte zur Gruppe hinzufügen';
  @override
  String get btnConfirmInvite => 'Einladen';
  @override
  String get allPeersAlreadyInGroupToast =>
      'Alle gekoppelten Geräte sind bereits in dieser Gruppe';
  @override
  String get subtitleDmE2ee => 'P2P-Direkt · E2E-verschlüsselt';
  @override
  String subtitleGroupE2ee(int count) => 'Gruppe ($count Geräte) · Isolierter Schlüssel';
  @override
  String get tooltipEditGroupName => 'Gruppe umbenennen';
  @override
  String get badgeThisTerminal => 'Dieses';
  @override
  String get roleThisDevice => 'Dieses Gerät (bearbeitbar)';
  @override
  String get rolePeerDevice => 'Partnergerät';
  @override
  String get roleGroupMember => 'Mitglied';
  @override
  String get tooltipEditSelfProfile => 'Name & Avatar bearbeiten';
  @override
  String get tooltipRemoveFromGroup => 'Aus Gruppe entfernen';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      'Kopplung mit "$roomTitle" aufheben und entfernen? (Gespeicherte Dateien bleiben erhalten).';
  @override
  String get deleteGroupTitle => 'Gruppe löschen';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      'Gruppe "$roomTitle" und lokalen Verlauf löschen? (Empfangene Dateien bleiben erhalten).';
  @override
  String get btnDeleteAndLeave => 'Löschen & verlassen';
  @override
  String get btnInviteNewDevice => 'Neues Gerät einladen / QR';
  @override
  String get editGroupNameTitle => 'Gruppe umbenennen';
  @override
  String get localDisplayNameLabel => 'Lokaler Anzeigename';
  @override
  String editGroupNameHint(String defaultName) =>
      'Leer für "$defaultName"';
  @override
  String get editProfileSelfTitle => 'Name & Avatar bearbeiten';
  @override
  String get editProfilePeerTitle => 'Geräte-Alias bearbeiten';
  @override
  String processImageFailed(Object error) => 'Bildfehler: $error';
  @override
  String get btnChangeAvatar => 'Avatar ändern';
  @override
  String get btnUploadAvatar => 'Avatar hochladen';
  @override
  String get btnRemoveImage => 'Bild entfernen';
  @override
  String get avatarSyncNoticeSelf =>
      'Hochgeladene Avatare werden verschlüsselt mit Peers synchronisiert';
  @override
  String get avatarSyncNoticePeer =>
      'Der Alias bleibt lokal; der Avatar zeigt das Bild des Partners';
  @override
  String get selfDisplayNameLabel => 'Eigener Gerätename';
  @override
  String get peerRemarkNameLabel => 'Geräte-Alias';
  @override
  String get customDeviceNameHint => 'Eigenen Namen eingeben';
  @override
  String defaultNameDisplay(String fallbackModel) => 'Standard: $fallbackModel';
  @override
  String get shareToTitle => 'Teilen an...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "Foto" : "Datei"}: $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '$count ${allImages ? "Fotos" : "Dateien"} · $size';
  @override
  String shareSummaryText(String text) => 'Text: $text';
  @override
  String get sendToTitle => 'Senden an';
  @override
  String get targetTypeDm => 'Direktgerät';
  @override
  String targetTypeGroup(int memberCount) => 'Gruppe · $memberCount Geräte';
  @override
  String get targetTypePairedPeer => 'Gekoppelt (P2P-Direkt)';
  @override
  String get btnReselect => 'Ändern';
  @override
  String btnSendCount(int count) => 'Senden ($count)';
  @override
  String get btnSend => 'Senden';
  @override
  String shareFileListMore(int count, String size) =>
      'und weitere ($count Dateien) · $size';
  @override
  String shareFileListExact(int count, String size) => '$count Dateien · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      '${isImage ? "Foto" : "Datei"} weiterleiten: $fileName';
  @override
  String forwardSummaryText(String text) => 'Nachricht weiterleiten: $text';
  @override
  String get forwardToTitle => 'Weiterleiten an...';
  @override
  String get searchRoomOrDeviceHint => 'Räume oder Geräte suchen...';
  @override
  String get noAvailableTargets => 'Keine Räume oder Geräte verfügbar';
  @override
  String get noMatchingTargets => 'Keine Treffer';
  @override
  String get currentConversationLabel => 'Aktueller Chat';
  @override
  String get tooltipOpenWithDefaultApp => 'Mit Standard-App öffnen';
  @override
  String get tooltipDeleteMessage => 'Nachricht löschen';
  @override
  String get tooltipClosePreview => 'Vorschau schließen';
  @override
  String get deletedImagePreviewTitle => 'Foto lokal gelöscht';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '"$fileName" befindet sich nicht mehr auf diesem Gerät.';
  @override
  String get btnDeleteThisRecord => 'Diesen Eintrag löschen';
  @override
  String get removeRevokeNoticeTitle => 'Hinweis';
  @override
  String get removeRevokeNoticeBody =>
      'Auch wenn die lokale Datei fehlt, kannst du den Eintrag hier sauber löschen.';
  @override
  String get deleteOutgoingFileTitle => 'Gesendete Datei löschen';
  @override
  String get deleteOutgoingTextTitle => 'Gesendete Nachricht löschen';
  @override
  String get chooseDeleteMethod => 'Löschmethode wählen:';
  @override
  String get deleteOutgoingFileDetail =>
      '• Für alle zurückrufen: Informiert Mitglieder & Relays, um auch gespeicherte Kopien zu löschen.\n• Nur hier entfernen: Löscht nur deinen lokalen Verlauf.\n\nDeine Originaldatei wird niemals verändert oder gelöscht.';
  @override
  String get deleteOutgoingTextDetail =>
      '• Für alle zurückrufen: Auf allen Geräten und Relays entfernen.\n• Nur hier entfernen: Nur lokal aus dem Verlauf löschen.';
  @override
  String get btnRemoveLocalOnly => 'Nur lokal';
  @override
  String get btnRevokeForAll => 'Für alle zurückrufen';
  @override
  String get deleteIncomingFileTitle => 'Empfangene Datei löschen';
  @override
  String get deleteIncomingTextTitle => 'Empfangene Nachricht löschen';
  @override
  String get deleteIncomingNote =>
      'Löscht nur auf diesem Gerät, nicht beim Absender.';
  @override
  String get checkboxDeleteLocalFile => 'Gespeicherte Datei ebenfalls löschen';
  @override
  String get incomingFileAlreadyMissing =>
      'Lokale Datei fehlt bereits; nur der Eintrag wird gelöscht.';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      'Vorschau ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => 'Senden bestätigen ($count)';
  @override
  String get btnAddMore => 'Mehr';
  @override
  String batchLimitNotice(int maxFiles) =>
      'Maximal $maxFiles Dateien pro Sendung; erste $maxFiles behalten.';
  @override
  String get tooltipPrevImage => 'Zurück';
  @override
  String get tooltipNextImage => 'Weiter';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '$count Elemente · $size${showEnterHint ? ' (Enter zum Senden)' : ''}';

  @override
  String inviteGroupTitle(String roomName) => 'In "$roomName" einladen';
  @override
  String get inviteDeviceTitle => 'Gerät hinzufügen / QR';
  @override
  String get tabGroupInviteQr => 'Gruppen-QR';
  @override
  String get tabDevicePairingQr => 'Mein QR';
  @override
  String get tabScanOrPaste => 'Scannen / Einfügen';
  @override
  String get desktopQrImageUnsupported =>
      'Bild-QR-Erkennung am Desktop noch nicht unterstützt. Bitte Ticket-JSON direkt einfügen.';
  @override
  String get noQrDetectedInImage =>
      'Kein QR-Code erkannt. Bitte ein schärferes Bild wählen.';
  @override
  String galleryQrScanFailed(Object error) => 'QR-Scan fehlgeschlagen: $error';
  @override
  String generateQrFailed(Object error) => 'QR-Erstellung fehlgeschlagen: $error';
  @override
  String get joinOrPairFailedHint =>
      'Verbindung fehlgeschlagen. Prüfe das vollständige Ticket-JSON.';
  @override
  String groupInviteDesc(String roomName) =>
      'Gruppen-QR: Scannen tritt direkt "$roomName" bei und teilt den E2EE-Schlüssel.';
  @override
  String get devicePairingDesc =>
      'Mein QR: Koppelt Geräte als vertrauenswürdig und öffnet einen P2P-Kanal.';
  @override
  String get toastCopiedQrJson => 'Ticket-JSON kopiert';
  @override
  String get btnCopyTextTicket => 'Text-Ticket kopieren';
  @override
  String get btnRetryGenerateQr => 'QR neu laden';
  @override
  String get scannerPermDenied =>
      'Kamerazugriff verweigert. Bitte freigeben oder QR aus Galerie wählen.';
  @override
  String get scannerUnsupported =>
      'Keine Kamera verfügbar. Bild aus Galerie wählen oder Ticket einfügen.';
  @override
  String get scannerReinitializing =>
      'Kamera wird zurückgesetzt. Kurz warten und Wiederholen tippen.';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      'Kamerafehler ($details)';
  @override
  String get scannerGenericError =>
      'Kamera konnte nicht gestartet werden. Wiederholen oder Galerie wählen.';
  @override
  String get startingCamera => 'Kamera wird gestartet...';
  @override
  String get btnPickQrFromGallery => 'QR aus Galerie wählen';
  @override
  String get btnRetryCamera => 'Wiederholen';
  @override
  String get pasteTicketDialogTitle => 'Ticket einfügen';
  @override
  String get pasteTicketFieldHint => 'Einladungs- oder Kopplungs-JSON einfügen';
  @override
  String get btnJoinOrRegister => 'Beitreten / Koppeln';
  @override
  String get cameraNotSupportedPlatform =>
      'Kamera hier nicht unterstützt. "Ticket einfügen" oder Galerie nutzen.';
  @override
  String get qrViewfinderHint => 'QR-Code im Rahmen ausrichten';
  @override
  String get analyzingImageQr => 'QR-Code wird gelesen...';
  @override
  String get verifyingHandshake => 'Verschlüsselung wird geprüft...';
  @override
  String get actionGallery => 'Galerie';
  @override
  String get actionPasteTicket => 'Ticket einfügen';
  @override
  String get actionTorchOff => 'Blitz aus';
  @override
  String get actionTorchOn => 'Blitz ein';
  @override
  String get windowsPasteTicketHint =>
      'Unter Windows kannst du das "Einladungs-Ticket" direkt hier einfügen, um derselben Gruppe beizutreten.';
  @override
  String get btnAnalyzingQr => 'Analysiere QR...';
  @override
  String get btnRestartCamera => 'Kamera neu starten';
  @override
  String get pasteTicketFieldLabel => 'Einladungs- oder Kopplungs-JSON einfügen';
  @override
  String get btnJoinToThisDevice => 'Hier beitreten / koppeln';

  @override
  String get allFilesTitle => 'Alle Dateien';
  @override
  String get roomFilesTitle => 'Raumdateien';
  @override
  String get tooltipOpenMainReceiveFolder => 'Haupt-Empfangsordner öffnen';
  @override
  String get searchFileNameHint => 'Dateinamen suchen...';
  @override
  String get allRoomsOption => 'Alle Räume';
  @override
  String tabImagesCount(int count) => 'Fotos ($count)';
  @override
  String tabFilesCount(int count) => 'Dateien ($count)';
  @override
  String loadFilesFailed(String error) => 'Laden fehlgeschlagen: $error';
  @override
  String get emptyImagesNone => 'Noch keine Fotos in diesem Raum';
  @override
  String get emptyImagesSearch => 'Keine passenden Fotos';
  @override
  String get emptyFilesNone => 'Noch keine Dateien in diesem Raum';
  @override
  String get emptyFilesSearch => 'Keine passenden Dateien';
  @override
  String get badgeLocallyRemoved => 'Lokal entfernt';
  @override
  String get unnamedFile => 'Unbenannte Datei';
  @override
  String get toastLocalFileMissing => 'Datei wurde lokal verschoben oder gelöscht';
  @override
  String get actionOpenShort => 'Öffnen';

  @override
  String get sectionGeneral => 'Allgemein';
  @override
  String get sectionReceiveStorage => 'Empfang & Speicher';
  @override
  String get sectionResidencyNetwork => 'Hintergrund & Netzwerk';
  @override
  String get sectionAbout => 'Über';
  @override
  String deviceModelLabel(String model) => 'Modell: $model';
  @override
  String get toastCopiedFullDeviceId => 'Vollständige Geräte-ID kopiert';
  @override
  String get tooltipEditNameAvatar => 'Name & Avatar ändern';
  @override
  String get toastThumbCacheCleared =>
      'Vorschaubild-Cache geleert (Originale bleiben erhalten)';
  @override
  String toastSaveDirUpdated(String dir) => 'Speicherordner aktualisiert: $dir';
  @override
  String saveDirNotWritable(Object error) => 'Ordner nicht beschreibbar: $error';
  @override
  String get needAllFilesPermTitle => 'Vollzugriff auf Dateien nötig';
  @override
  String get needAllFilesPermBody =>
      'Android benötigt diese Freigabe, um direkt im öffentlichen Ordner "Downloads" zu speichern.';
  @override
  String get btnGoGrant => 'Erlauben';
  @override
  String get pickReceiveFolderDialogTitle => 'Empfangsordner wählen';
  @override
  String storageSizeSuffix(String size, int count) =>
      ' ($size · $count Dateien)';
  @override
  String get storageModeDownloads => 'Öffentlicher Ordner „Downloads“';
  @override
  String get storageModeDocuments => 'Öffentlicher Ordner „Dokumente“ (Documents)';
  @override
  String get storageModeCustomTitle => 'Benutzerdefinierter Ordner';
  @override
  String storageModeCustom(String compactPath) => 'Eigener ($compactPath)';
  @override
  String get storageModeAppPrivate => 'App-Privatordner (Android/data)';
  @override
  String get receiveLocationTitle => 'Speicherort für Empfangenes';
  @override
  String get storageDownloadsDesc =>
      'Schnell über Dateien-App und andere Apps erreichbar';
  @override
  String get storageDocumentsDesc =>
      'Ideal für Dokumente, PDFs und geordnete Ablage';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      'Aktueller Pfad: $compactPath';
  @override
  String get storageCustomUnselectedDesc =>
      'SD-Karte oder eigenen Ordner auswählen';
  @override
  String get btnChange => 'Ändern';
  @override
  String get storageAppPrivateTitle => 'Privatordner (wird bei Deinstallation gelöscht)';
  @override
  String get storageAppPrivateDesc =>
      'Versteckt in Galerie/Dateien; wird mit App gelöscht';
  @override
  String get legacyStoragePermNotice =>
      'Speicherberechtigung für Downloads erforderlich';
  @override
  String get btnAuthorize => 'Freigeben';
  @override
  String get btnChangeFolder => 'Ordner ändern';
  @override
  String get pickReceiveDirDialogTitle => 'Zielordner wählen';
  @override
  String get windowsResidencyTitle => 'Windows-Infoleiste & Autostart';
  @override
  String get windowsCloseToTrayTitle => 'Beim Schließen in Infoleiste minimieren';
  @override
  String get windowsCloseToTraySubtitle =>
      '× versteckt das Fenster in den Hintergrund für ständigen Empfang';
  @override
  String get windowsAutoStartTitle => 'Im Hintergrund mit Windows starten';
  @override
  String get windowsAutoStartSubtitle =>
      'Startet minimiert in der Infoleiste (--minimized)';
  @override
  String get btnHideToTrayNow => 'Jetzt in Infoleiste minimieren';
  @override
  String get btnQuitBackgroundService => 'Vollständig beenden (inkl. Dienst)';
  @override
  String get themeDialogTitle => 'Erscheinungsbild';
  @override
  String get themeSystemTitle => 'Systemstandard';
  @override
  String get themeSystemSubtitle => 'Folgt Hell-/Dunkelmodus des Systems';
  @override
  String get themeLightTitle => 'Heller Modus';
  @override
  String get themeLightSubtitle => 'Helle Oberfläche mit dezenten Mint-Akzenten';
  @override
  String get themeDarkTitle => 'Dunkler Modus';
  @override
  String get themeDarkSubtitle => 'Augenschonend bei wenig Licht';
  @override
  String get themeSystemShort => 'System';
  @override
  String get themeLightShort => 'Hell';
  @override
  String get themeDarkShort => 'Dunkel';
  @override
  String get languageDialogTitle => 'Sprache';
  @override
  String get languageSettingTitle => 'Sprache';
  @override
  String get languageSystemTitle => 'Systemsprache folgen';
  @override
  String get languageSystemSubtitle =>
      'Passt sich automatisch an die Gerätesprache an';
  @override
  String toastLanguageUpdated(String langName) =>
      'Sprache geändert zu $langName';
  @override
  String get storageManagerTitle => 'Speicher & Cache';
  @override
  String storageRecvStats(String size, int count) =>
      'Belegt $size · $count Dateien';
  @override
  String get countingStats => 'Wird berechnet...';
  @override
  String get storageRecvUsedTitle => 'Empfangene Dateien';
  @override
  String get thumbCacheTitle => 'Vorschaubild-Cache';
  @override
  String thumbCacheDesc(String size) =>
      'Belegt $size · Leeren löscht keine gespeicherten Dateien';
  @override
  String get btnClearThumbCache => 'Cache leeren';
  @override
  String get mobileStorageTitle => 'Speicher & Cache';
  @override
  String legendReceivedFiles(String size) => 'Empfangen $size';
  @override
  String legendThumbCache(String size) => 'Cache $size';
  @override
  String receivedFilesCountTitle(int count) => 'Empfangene Dateien ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => 'Vorschau-Cache ($size)';
  @override
  String get thumbCacheNoTouchNotice =>
      'Originalfotos & Dateien bleiben unberührt';
  @override
  String get noCacheToClear => 'Kein Cache vorhanden';
  @override
  String btnClearThumbCacheWithSize(String size) => 'Cache leeren ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      'Empfangen $recvSize · Cache $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => 'Cache $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      'Gesamt $totalSize · Cache $cacheSize';
  @override
  String get storageAndCacheTitle => 'Speicher & Cache';
  @override
  String get aboutTitle => 'Über P2P-Privattransfer';
  @override
  String aboutVersion(String version) => 'Version: $version';
  @override
  String get aboutBody =>
      'Plattformübergreifende E2E-verschlüsselte P2P-Übertragung ohne Cloud oder Dateigrößenlimit.\n\n• Physische NIC-Bindung: umgeht VPN/TUN für echtes LAN\n• Raum-Schlüsselisolierung: Heimknoten speichern nur Chiffretext\n• USB-Tethering-Schutz: verhindert Routenübernahme unter Windows';
  @override
  String get aboutSubtitle => 'Serverloser E2E-verschlüsselter Transfer';
  @override
  String get networkDiagTitle => 'Netzwerk & Diagnose';
  @override
  String get networkDiagLoading => 'Netzwerkschnittstellen werden geprüft...';
  @override
  String networkDiagDesktopReady(int count) =>
      'Bereit · $count direkte LAN/USB-Adapter erkannt';
  @override
  String get networkDiagDesktopWanOnly => 'Externer verschlüsselter P2P-Kanal';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB bereit · $count Schnittstellen erkannt';
  @override
  String get networkDiagMobileWanOnly => 'Aktiv: Externer verschlüsselter Kanal';
  @override
  String get nicDetectionTitle => 'Physische LAN-/USB-Adapter (ohne VPN)';
  @override
  String get nicDetectionDesc =>
      'Ignoriert virtuelle TUN-Adapter (Clash, Mihomo, WireGuard) und bindet direkt an echte Hardware.';
  @override
  String get nicReading => 'Lese Adapter...';
  @override
  String get nicNoneConnected => 'Keine aktiven physischen Adapter gefunden';
  @override
  String get btnRefreshNics => 'NICs aktualisieren';
  @override
  String get usbProtectionTitle => 'USB-Tethering-Routenschutz (Windows)';
  @override
  String get usbProtectionDesc =>
      'Bei aktivem Android-USB-Tethering wird die Metrik automatisch auf 5000 gesetzt – schnelles Port-42420-Routing ohne PC-Internet zu kappen.';
  @override
  String get usbProtectionReady =>
      'Bereit: USB-Route sicher isoliert (Metric=5000)';
  @override
  String usbProtectionNeedsFix(String detail) => 'Korrektur nötig: $detail';
  @override
  String get usbProtectionNotPlugged =>
      'Kein USB-Tethering aktiv; schützt automatisch bei Verbindung';
  @override
  String get btnFixMetric => 'Metrik reparieren';
  @override
  String get customRelayTitle => 'Eigener Relay-Server (Erweitert)';
  @override
  String get customRelayDesc =>
      'Schlägt Direkt-P2P fehl, leitet der Relay verschlüsselte Pakete blind weiter. Leer lassen für Standard-Relay.';
  @override
  String get customRelayLabel => 'Relay-URL (leer = öffentlicher Standard)';
  @override
  String get toastRelaySaved => 'Relay-URL gespeichert';
  @override
  String get btnSaveRelay => 'Relay-URL speichern';
  @override
  String get deviceIdLabel => 'Geräte-ID';
  @override
  String get btnCopyDeviceId => 'Vollständige ID kopieren';
  @override
  String get deviceIdCopiedBadge => 'Kopiert';

  @override
  String toastEventStreamError(Object error) => 'Ereignisfehler: $error';
  @override
  String toastCreatedRoom(String name) => 'Verschlüsselter Raum "$name" erstellt';
  @override
  String toastCreateRoomFailed(Object error) => 'Raumfehler: $error';
  @override
  String toastOpenChatFailed(Object error) => 'Chatfehler: $error';
  @override
  String toastCreatedGroup(String name) => 'Gruppe "$name" erstellt';
  @override
  String toastCreateGroupFailed(Object error) => 'Gruppenfehler: $error';
  @override
  String toastJoinedRoom(String name) => 'Raum "$name" beigetreten';
  @override
  String toastAddedDevice(String name) => 'Gerät "$name" hinzugefügt';
  @override
  String toastPairFailed(Object error) => 'Kopplung fehlgeschlagen: $error';
  @override
  String toastSendTextFailed(Object error) => 'Senden fehlgeschlagen: $error';
  @override
  String get toastSelectRoomFirst => 'Bitte zuerst einen Chat oder ein Gerät wählen';
  @override
  String toastSendFileFailed(String path, Object error) =>
      'Dateifehler ($path): $error';
  @override
  String get toastForwardFileMissing =>
      'Weiterleitung fehlgeschlagen: lokale Datei fehlt';
  @override
  String get toastForwardEmptyText =>
      'Weiterleitung fehlgeschlagen: Text ist leer';
  @override
  String get fallbackTargetRoom => 'Zielraum';
  @override
  String toastForwardedTo(String targetName) => 'Weitergeleitet an "$targetName"';
  @override
  String toastForwardFailed(Object error) => 'Weiterleitungsfehler: $error';
  @override
  String get fallbackBigFile => 'Große Datei';
  @override
  String toastConfirmedSend(String fileName) => 'Versand bestätigt: "$fileName"';
  @override
  String toastConfirmSendFailed(Object error) => 'Bestätigungsfehler: $error';
  @override
  String get fallbackFile => 'Datei';
  @override
  String toastPullingFile(String fileName) => 'Lade "$fileName"';
  @override
  String toastPullFileFailed(Object error) => 'Downloadfehler: $error';
  @override
  String get toastPeerDeleted => 'Gekoppeltes Gerät entfernt';
  @override
  String toastDeletePeerFailed(Object error) => 'Löschfehler: $error';
  @override
  String get toastRoomDeleted => 'Chat gelöscht';
  @override
  String toastDeleteRoomFailed(Object error) => 'Löschfehler: $error';
  @override
  String get toastDeletedRecordAndFile => 'Eintrag und lokale Datei gelöscht';
  @override
  String get toastRemovedLocalRecord => 'Aus lokalem Verlauf entfernt';
  @override
  String toastDeleteMsgFailed(Object error) => 'Nachrichtenfehler: $error';
  @override
  String get toastOnlyRevokeOwn => 'Nur eigene Nachrichten sind rückrufbar';
  @override
  String get toastRevokedForAll => 'Für alle Geräte zurückgerufen';
  @override
  String toastRevokeFailed(Object error) => 'Rückruffehler: $error';
  @override
  String toastInvitedMembers(int count) => '$count Geräte eingeladen';
  @override
  String toastAddMembersFailed(Object error) => 'Einladungsfehler: $error';
  @override
  String get toastRemovedMember => 'Gerät aus Gruppe entfernt';
  @override
  String toastRemoveMemberFailed(Object error) => 'Entfernungsfehler: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => 'USB-Metrikfehler: $error';
  @override
  String toastReceiveDirFallback(String dir) => 'Empfangsordner: $dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => 'Ordner geändert: $dir';
  @override
  String get toastClearedCustomSaveDir =>
      'Eigener Ordner gelöscht; Standardordner aktiv';
  @override
  String toastSetDirFailed(Object error) => 'Ordnerfehler: $error';
  @override
  String toastSyncAvatarFailed(Object error) => 'Avatar-Sync-Fehler: $error';
  @override
  String get toastSelfProfileUpdated => 'Profil aktualisiert & synchronisiert';
  @override
  String get toastPeerRemarkUpdated => 'Alias aktualisiert';
  @override
  String get toastRestoredGroupName => 'Gruppenname zurückgesetzt';
  @override
  String get toastUpdatedGroupName => 'Lokaler Gruppenname geändert';
  @override
  String get toastAutoStartEnabled => 'Stiller Autostart aktiviert';
  @override
  String get toastAutoStartDisabled => 'Autostart deaktiviert';
  @override
  String get toastCloseToTrayEnabled => 'Schließen minimiert in Infoleiste';
  @override
  String get toastCloseToTrayDisabled => 'Schließen beendet das Programm';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      'Von $sender erhalten: $fileName';
  @override
  String get notifyFileFallbackBody => 'Neue Datei automatisch gespeichert';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      'Empfange $fileLabel und weitere ($totalCount Dateien)';
  @override
  String notifyNewFileTitle(String sender) => 'Neue Datei · $sender';
  @override
  String notifyNewTextTitle(String sender) => 'Neue Nachricht · $sender';
  @override
  String get notifyNewEncryptedText => 'Neue verschlüsselte Textnachricht';
  @override
  String get errorEmptyImageFile => 'Die ausgewählte Bilddatei ist leer';
  @override
  String get errorCompressAvatarFailed => 'Avatar-Komprimierung fehlgeschlagen';
  @override
  String get errorPngEncodeFailed => 'PNG-Codierung fehlgeschlagen';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'Kein USB-Tethering-Adapter erkannt';
    if (metricProtected) {
      return 'USB-Metrik auf 5000 isoliert – PC-Internet bleibt unbeeinflusst';
    }
    if (needsElevation) {
      return 'Admin-Rechte nötig, um USB-Metrik auf 5000 zu setzen';
    }
    return 'USB-Tethering erkannt, Metrik-Schutz ausstehend';
  }

  @override
  String get winTrayTooltip => 'P2P-Privattransfer · Hintergrunddienst';
  @override
  String get winTrayOpenWindow => 'Hauptfenster öffnen';
  @override
  String get winTrayAutoStart => 'Minimiert mit Windows starten';
  @override
  String get winTrayCloseToTray => 'Beim Schließen in Infoleiste minimieren';
  @override
  String get winTrayExitApp => 'App vollständig beenden';
}
