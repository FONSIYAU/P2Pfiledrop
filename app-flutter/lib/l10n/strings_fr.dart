import 'app_strings.dart';

class StringsFr extends AppStrings {
  const StringsFr();

  static const _months = <String>[
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  @override
  String get localeCode => 'fr';

  @override
  String get appTitle => 'BubbleDrop';
  @override
  String get appSubtitle => 'Transfert chiffré de bout en bout';
  @override
  String get startingEngine => 'Démarrage du moteur chiffré P2P...';
  @override
  String engineInitFailed(Object error) => 'Échec d\'initialisation :\n$error';
  @override
  String get retry => 'Réessayer';
  @override
  String get cancel => 'Annuler';
  @override
  String get confirm => 'OK';
  @override
  String get close => 'Fermer';
  @override
  String get save => 'Enregistrer';
  @override
  String get delete => 'Supprimer';
  @override
  String get remove => 'Retirer';
  @override
  String get open => 'Ouvrir';
  @override
  String get refresh => 'Actualiser';
  @override
  String get clear => 'Effacer';
  @override
  String get resetDefault => 'Réinitialiser';
  @override
  String get recommendedBadge => 'Recommandé';
  @override
  String get defaultAvatarFallback => 'A';

  @override
  String formatFullDate(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  @override
  String formatMonthDay(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}';
  @override
  String get todayLabel => 'Aujourd\'hui';
  @override
  String get yesterdayLabel => 'Hier';
  @override
  String formatRemainingSeconds(int seconds) => '${seconds}s rest.';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      '${minutes}m ${seconds}s rest.';

  @override
  String get navTransfers => 'Chats';
  @override
  String get navDevices => 'Appareils';
  @override
  String get navThisDevice => 'Moi';
  @override
  String get navAdd => 'Ajouter';
  @override
  String get navFiles => 'Fichiers';
  @override
  String get navFolder => 'Dossier';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName (Paramètres)';
  @override
  String get tooltipScanPair => 'Scanner QR pour associer / rejoindre';
  @override
  String get tooltipAllFiles => 'Parcourir tous les fichiers et photos';
  @override
  String tooltipOpenReceiveFolder(String dir) => 'Ouvrir dossier reçu ($dir)';

  @override
  String get transportUsbTether => 'USB direct';
  @override
  String get transportLanDirect => 'LAN direct';
  @override
  String get transportWanP2p => 'P2P externe';
  @override
  String get transportWanRelay => 'Relais';
  @override
  String get transportOffline => 'Hors ligne';
  @override
  String get usbTetherTag => 'USB direct';

  @override
  String get msgStatusQueuedOffline => 'En attente de connexion';
  @override
  String get msgStatusHandshaking => 'Chiffrement';
  @override
  String get msgStatusTransferring => 'Transfert en cours';
  @override
  String get msgStatusPausedReconnecting => 'Reprise';
  @override
  String get msgStatusAwaitingDownload => 'Toucher pour télécharger';
  @override
  String get msgStatusDelivered => 'Distribué';
  @override
  String get msgStatusFailedSourceMissing => 'Source introuvable';

  @override
  String deviceWithTag(String tag) => 'Appareil $tag';
  @override
  String deviceShortIdLabel(String shortId) => 'Appareil · $shortId';
  @override
  String get peerDeviceFallback => 'Appareil distant';
  @override
  String get defaultPersonalRoomName => 'Mes appareils (Personal)';
  @override
  String get defaultEncryptedGroupName => 'Nouveau groupe chiffré';
  @override
  String get defaultPrivateRoomName => 'Nouveau salon privé chiffré';
  @override
  String encryptedRoomWithId(String shortId) => 'Salon chiffré ($shortId)';
  @override
  String get homeNodeDefaultName => 'Nœud domestique 24h';

  @override
  String get chatListTitle => 'Discussions';
  @override
  String get chatListNewActionTooltip => 'Scanner QR / Créer un groupe';
  @override
  String get menuScanPairOrJoin => 'Scanner QR pour associer / rejoindre';
  @override
  String get menuCreateGroup => 'Créer un groupe partagé';
  @override
  String get menuMyPairingQr => 'Mon code QR';
  @override
  String get menuOpenReceiveFolder => 'Ouvrir dossier de réception';
  @override
  String get menuProbeReconnect => 'Vérifier / Reconnecter';
  @override
  String get searchChatsHint => 'Rechercher discussions ou appareils...';
  @override
  String groupOnlineCount(int online, int total) =>
      'Groupe ($online/$total en ligne)';
  @override
  String groupOfflineCount(int total) => 'Groupe ($total appareils · hors ligne)';
  @override
  String get emptyChatsSearch => 'Aucune discussion correspondante';
  @override
  String get emptyChatsNoRooms => 'Aucune discussion active';
  @override
  String get btnScanPairDevice => 'Associer par QR';
  @override
  String get btnGoToDevices => 'Aller aux appareils';

  @override
  String get devicesListTitle => 'Appareils';
  @override
  String get searchPairedDevicesHint => 'Rechercher appareils associés...';
  @override
  String get btnAddNewDevice => 'Ajouter un appareil / QR';
  @override
  String get btnNewSharedGroup => 'Nouveau groupe partagé';
  @override
  String get btnAddDeviceShort => 'Ajouter';
  @override
  String get btnNewGroupShort => 'Nouveau groupe';
  @override
  String pairedDevicesCount(int count) => 'Appareils associés ($count)';
  @override
  String get emptyDevicesSearch => 'Aucun appareil correspondant';
  @override
  String get emptyDevicesNone =>
      'Aucun appareil associé\nAppuyez sur "Ajouter un appareil / QR" ci-dessus';
  @override
  String get selectDevicePrompt => 'Sélectionnez un appareil à gauche';
  @override
  String get btnScanFirstDevice => 'Associer un premier appareil';
  @override
  String originalNameLabel(String name) => 'Nom d\'origine : $name';
  @override
  String get deviceNodeIdLabel => 'ID du nœud (Endpoint ID)';
  @override
  String get tooltipCopyDeviceId => 'Copier l\'ID';
  @override
  String get toastCopiedDeviceId => 'ID de l\'appareil copié';
  @override
  String get btnSendMessageOrFile => 'Envoyer message / fichier';
  @override
  String get btnEditRemark => 'Modifier le surnom';
  @override
  String get btnDeleteDevice => 'Supprimer cet appareil';
  @override
  String get deletePeerDialogTitle => 'Supprimer l\'appareil associé';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      'Retirer "$resolvedName" de vos appareils de confiance et effacer son chat direct ? (Les fichiers déjà reçus restent intactes).';
  @override
  String get btnConfirmDelete => 'Supprimer';

  @override
  String get desktopWorkspaceTitle => 'Espace de transfert';
  @override
  String get btnOpenFolder => 'Ouvrir dossier';
  @override
  String get tooltipRoomFiles => 'Fichiers et photos du salon';
  @override
  String get tooltipInviteOrScan => 'Inviter par QR / Scanner';
  @override
  String get tooltipRoomMembers => 'Détails / Membres du groupe';
  @override
  String get desktopEmptyTitle => 'Choisissez une discussion ou un appareil à gauche';
  @override
  String get desktopEmptySubtitle =>
      'Prend en charge LAN direct, câble USB prioritaire et chiffrement externe. Déposez vos fichiers ici pour envoyer.';
  @override
  String get moreActionsTooltip => 'Plus d\'actions';
  @override
  String get moreTooltip => 'Plus';
  @override
  String get emptyRoomNoSession => 'Aucun chat actif. Associez d\'abord un appareil par QR.';
  @override
  String get emptyRoomE2eeNotice =>
      'Ce salon est chiffré de bout en bout ; seuls les membres peuvent déchiffrer les données.';
  @override
  String get emptyRoomWindowsHint =>
      'Glissez-déposez des fichiers ici pour envoyer ou rédigez un message.';
  @override
  String get emptyRoomMobileHint =>
      'Touchez + ci-dessous pour envoyer photos/fichiers ou tapez un message.';
  @override
  String dropZonePrompt(String roomTitle) =>
      'Relâchez pour envoyer chiffré à "$roomTitle"';
  @override
  String get menuAddPairedToGroup => 'Ajouter des appareils au groupe';
  @override
  String get menuDeviceDetailsAndRemark => 'Détails et surnom';
  @override
  String get menuGroupMembersAndManage => 'Membres et gestion du groupe';
  @override
  String get noShareTargetsToast => 'Aucun appareil ou salon disponible';
  @override
  String get fallbackShortTitle => 'Privé P2P';

  @override
  String get tooltipGalleryImages => 'Photos de la galerie';
  @override
  String get tooltipSendFile => 'Choisir un fichier';
  @override
  String get tooltipSendImageOrFile => 'Envoyer photo ou fichier';
  @override
  String get tooltipPasteClipboard => 'Coller image ou texte';
  @override
  String get inputHintWindows =>
      'Écrire un message, coller ou déposer des fichiers...';
  @override
  String get inputHintMobile => 'Écrire un message...';
  @override
  String get inputHintNoRoom => 'Ajoutez d\'abord un appareil (+)...';
  @override
  String get tooltipSendMessage => 'Envoyer';

  @override
  String get newMessagesBelowSuffix => 'nouveaux messages';
  @override
  String albumFailedCount(int failedCount) =>
      'Source manquante pour $failedCount photos';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      'Envoyé ($missingCount sources supprimées)';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      'Reçu ($missingCount supprimées localement)';
  @override
  String get albumAllDelivered => 'Tout distribué';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      'Envoi $delivered/$total';
  @override
  String albumImageCount(int count) => '$count photos';
  @override
  String get btnExpand => 'Voir';
  @override
  String collapseImagesCount(int count) => 'Réduire ($count)';

  @override
  String get statusLargeFileAwaitConfirm => 'En attente de confirmation';
  @override
  String get statusGroupFileAwaitDownload => 'Prêt à télécharger';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      'Offre envoyée ($acked/$total)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      'À confirmer ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      'Distribué à tous ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) =>
      'Distribué ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => 'Fichier source retiré';
  @override
  String get statusLocalFileDeleted => 'Fichier local supprimé';
  @override
  String get revokedByMe => 'Vous avez annulé l\'envoi de ce message';
  @override
  String get revokedByPeer => 'L\'expéditeur a retiré ce message';
  @override
  String get tooltipEditPeerRemark => 'Modifier le surnom';
  @override
  String get tooltipPeerAvatar => 'Appareil distant';
  @override
  String get toastCopiedText => 'Texte copié';
  @override
  String toastCopiedPath(String path) => 'Chemin copié : $path';
  @override
  String get imageDeletedLocally => 'Photo supprimée de cet appareil';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · Photo source retirée';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · Photo supprimée (toucher pour détails)';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · Source introuvable';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · Supprimé localement';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · Gros fichier à confirmer';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · Fichier de groupe prêt';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · En attente de téléchargement';
  @override
  String btnDownloadToDevice(String sizeLabel) => 'Télécharger ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => 'Envoyer ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => 'Envoyer dès connexion';
  @override
  String get actionCopyText => 'Copier le texte';
  @override
  String get actionForward => 'Transférer';
  @override
  String get actionOpenFile => 'Ouvrir le fichier';
  @override
  String get actionRevealInFolder => 'Afficher dans le dossier';
  @override
  String get actionCopyFilePath => 'Copier le chemin';

  @override
  String get createGroupTitle => 'Créer un groupe chiffré';
  @override
  String get createGroupDesc =>
      'Cochez les appareils associés pour créer un groupe avec clé E2EE dédiée (sans rescanner de QR).';
  @override
  String get groupNameOptionalLabel => 'Nom du groupe (facultatif)';
  @override
  String get groupNameAutoHint => 'Généré automatiquement si vide';
  @override
  String get createGroupNoPeersNotice =>
      'Aucun appareil associé. Créez le groupe puis invitez via QR.';
  @override
  String selectGroupDevicesCount(int count) =>
      'Choisir des appareils ($count sélectionnés) :';
  @override
  String get btnCreateGroup => 'Créer le groupe';
  @override
  String get defaultGroupNameFallback => 'Groupe chiffré';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => 'Groupe $joinedNames';
  @override
  String get nameSeparator => ', ';
  @override
  String get addMembersToGroupTitle => 'Ajouter au groupe';
  @override
  String get btnConfirmInvite => 'Inviter';
  @override
  String get allPeersAlreadyInGroupToast =>
      'Tous les appareils associés sont déjà dans ce groupe';
  @override
  String get subtitleDmE2ee => 'P2P direct · Chiffrement E2E';
  @override
  String subtitleGroupE2ee(int count) => 'Groupe ($count app.) · Clé isolée';
  @override
  String get tooltipEditGroupName => 'Renommer le groupe';
  @override
  String get badgeThisTerminal => 'Cet app.';
  @override
  String get roleThisDevice => 'Cet appareil (modifiable)';
  @override
  String get rolePeerDevice => 'Appareil distant';
  @override
  String get roleGroupMember => 'Membre du groupe';
  @override
  String get tooltipEditSelfProfile => 'Modifier nom et avatar';
  @override
  String get tooltipRemoveFromGroup => 'Retirer du groupe';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      'Dissocier et supprimer "$roomTitle" ? (Les fichiers déjà enregistrés restent intacts).';
  @override
  String get deleteGroupTitle => 'Supprimer le groupe';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      'Supprimer "$roomTitle" et son historique local ? (Les fichiers reçus ne sont pas effacés).';
  @override
  String get btnDeleteAndLeave => 'Supprimer et quitter';
  @override
  String get btnInviteNewDevice => 'Inviter / Scanner QR';
  @override
  String get editGroupNameTitle => 'Renommer le groupe';
  @override
  String get localDisplayNameLabel => 'Nom local';
  @override
  String editGroupNameHint(String defaultName) =>
      'Laisser vide pour "$defaultName"';
  @override
  String get editProfileSelfTitle => 'Modifier nom et avatar';
  @override
  String get editProfilePeerTitle => 'Modifier le surnom de l\'appareil';
  @override
  String processImageFailed(Object error) => 'Erreur image : $error';
  @override
  String get btnChangeAvatar => 'Changer d\'avatar';
  @override
  String get btnUploadAvatar => 'Importer avatar';
  @override
  String get btnRemoveImage => 'Retirer l\'image';
  @override
  String get avatarSyncNoticeSelf =>
      'L\'image est synchronisée et chiffrée vers vos appareils';
  @override
  String get avatarSyncNoticePeer =>
      'Le surnom est local ; l\'avatar affiche la photo choisie par l\'appareil';
  @override
  String get selfDisplayNameLabel => 'Nom de cet appareil';
  @override
  String get peerRemarkNameLabel => 'Surnom de l\'appareil';
  @override
  String get customDeviceNameHint => 'Entrez un nom personnalisé';
  @override
  String defaultNameDisplay(String fallbackModel) => 'Par défaut : $fallbackModel';
  @override
  String get shareToTitle => 'Partager vers...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "Photo" : "Fichier"} : $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '$count ${allImages ? "photos" : "fichiers"} · $size';
  @override
  String shareSummaryText(String text) => 'Texte : $text';
  @override
  String get sendToTitle => 'Envoyer à';
  @override
  String get targetTypeDm => 'Appareil direct';
  @override
  String targetTypeGroup(int memberCount) => 'Groupe · $memberCount app.';
  @override
  String get targetTypePairedPeer => 'Appareil associé (P2P direct)';
  @override
  String get btnReselect => 'Changer';
  @override
  String btnSendCount(int count) => 'Envoyer ($count)';
  @override
  String get btnSend => 'Envoyer';
  @override
  String shareFileListMore(int count, String size) =>
      'et plus ($count fichiers) · $size';
  @override
  String shareFileListExact(int count, String size) => '$count fichiers · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      'Transférer ${isImage ? "photo" : "fichier"} : $fileName';
  @override
  String forwardSummaryText(String text) => 'Transférer message : $text';
  @override
  String get forwardToTitle => 'Transférer vers...';
  @override
  String get searchRoomOrDeviceHint => 'Rechercher salons ou appareils...';
  @override
  String get noAvailableTargets => 'Aucun salon ou appareil disponible';
  @override
  String get noMatchingTargets => 'Aucun résultat';
  @override
  String get currentConversationLabel => 'Chat actuel';
  @override
  String get tooltipOpenWithDefaultApp => 'Ouvrir avec l\'app par défaut';
  @override
  String get tooltipDeleteMessage => 'Supprimer le message';
  @override
  String get tooltipClosePreview => 'Fermer l\'aperçu';
  @override
  String get deletedImagePreviewTitle => 'Photo supprimée localement';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '"$fileName" n\'est plus sur cet appareil et ne peut pas être prévisualisée.';
  @override
  String get btnDeleteThisRecord => 'Supprimer cette entrée';
  @override
  String get removeRevokeNoticeTitle => 'Information';
  @override
  String get removeRevokeNoticeBody =>
      'Même sans le fichier local, vous pouvez nettoyer cette entrée de votre historique sans affecter le pair.';
  @override
  String get deleteOutgoingFileTitle => 'Supprimer fichier envoyé';
  @override
  String get deleteOutgoingTextTitle => 'Supprimer message envoyé';
  @override
  String get chooseDeleteMethod => 'Choisir le mode de suppression :';
  @override
  String get deleteOutgoingFileDetail =>
      '• Retirer pour tous : Demande aux membres et relais d\'effacer aussi leurs copies enregistrées.\n• Retirer ici seulement : Efface uniquement votre historique.\n\nVotre fichier source original n\'est jamais modifié ni supprimé.';
  @override
  String get deleteOutgoingTextDetail =>
      '• Retirer pour tous : Supprime sur tous les appareils et nœuds relais.\n• Retirer ici seulement : Supprime uniquement sur cet appareil.';
  @override
  String get btnRemoveLocalOnly => 'Retirer ici';
  @override
  String get btnRevokeForAll => 'Retirer pour tous';
  @override
  String get deleteIncomingFileTitle => 'Supprimer fichier reçu';
  @override
  String get deleteIncomingTextTitle => 'Supprimer message reçu';
  @override
  String get deleteIncomingNote =>
      'Supprime uniquement sur cet appareil, sans affecter l\'expéditeur.';
  @override
  String get checkboxDeleteLocalFile => 'Supprimer aussi le fichier enregistré';
  @override
  String get incomingFileAlreadyMissing =>
      'Le fichier local n\'existe plus ; seul l\'historique sera supprimé.';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      'Aperçu ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => 'Confirmer l\'envoi ($count)';
  @override
  String get btnAddMore => 'Ajouter';
  @override
  String batchLimitNotice(int maxFiles) =>
      'Max. $maxFiles fichiers par lot ; les $maxFiles premiers ont été gardés.';
  @override
  String get tooltipPrevImage => 'Précédente';
  @override
  String get tooltipNextImage => 'Suivante';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '$count éléments · $size${showEnterHint ? ' (Entrée pour envoyer)' : ''}';

  @override
  String inviteGroupTitle(String roomName) => 'Inviter dans "$roomName"';
  @override
  String get inviteDeviceTitle => 'Ajouter / Scanner QR';
  @override
  String get tabGroupInviteQr => 'QR du groupe';
  @override
  String get tabDevicePairingQr => 'Mon QR';
  @override
  String get tabScanOrPaste => 'Scanner / Coller';
  @override
  String get desktopQrImageUnsupported =>
      'Lecture d\'image QR non prise en charge sur PC. Collez le ticket JSON directement.';
  @override
  String get noQrDetectedInImage =>
      'Aucun QR code détecté. Essayez une image plus nette.';
  @override
  String galleryQrScanFailed(Object error) => 'Échec lecture QR : $error';
  @override
  String generateQrFailed(Object error) => 'Échec génération QR : $error';
  @override
  String get joinOrPairFailedHint =>
      'Échec d\'association. Vérifiez que le ticket JSON est complet.';
  @override
  String groupInviteDesc(String roomName) =>
      'QR du groupe : le scan fait rejoindre "$roomName" et synchronise sa clé E2EE.';
  @override
  String get devicePairingDesc =>
      'Mon code QR : associe deux appareils de confiance et établit un canal P2P chiffré.';
  @override
  String get toastCopiedQrJson => 'Ticket JSON copié';
  @override
  String get btnCopyTextTicket => 'Copier ticket texte';
  @override
  String get btnRetryGenerateQr => 'Réessayer QR';
  @override
  String get scannerPermDenied =>
      'Accès caméra refusé. Autorisez la caméra ou choisissez un QR en galerie.';
  @override
  String get scannerUnsupported =>
      'Caméra indisponible ici. Choisissez une image ou collez un ticket.';
  @override
  String get scannerReinitializing =>
      'Réinitialisation caméra. Touchez Réessayer dans un instant.';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      'Erreur caméra ($details)';
  @override
  String get scannerGenericError =>
      'Impossible d\'ouvrir la caméra. Réessayez ou utilisez la galerie.';
  @override
  String get startingCamera => 'Démarrage caméra...';
  @override
  String get btnPickQrFromGallery => 'Choisir QR en galerie';
  @override
  String get btnRetryCamera => 'Réessayer';
  @override
  String get pasteTicketDialogTitle => 'Coller un ticket';
  @override
  String get pasteTicketFieldHint => 'Collez le JSON d\'invitation ou d\'association';
  @override
  String get btnJoinOrRegister => 'Rejoindre / Enregistrer';
  @override
  String get cameraNotSupportedPlatform =>
      'Caméra non gérée ici. Utilisez "Coller ticket" ou la galerie.';
  @override
  String get qrViewfinderHint => 'Placez le code QR dans le cadre';
  @override
  String get analyzingImageQr => 'Analyse du code QR...';
  @override
  String get verifyingHandshake => 'Vérification du canal chiffré...';
  @override
  String get actionGallery => 'Galerie';
  @override
  String get actionPasteTicket => 'Coller ticket';
  @override
  String get actionTorchOff => 'Éteindre flash';
  @override
  String get actionTorchOn => 'Allumer flash';
  @override
  String get windowsPasteTicketHint =>
      'Sur Windows, collez le "Ticket d\'invitation" directement pour rejoindre le même groupe chiffré.';
  @override
  String get btnAnalyzingQr => 'Analyse QR...';
  @override
  String get btnRestartCamera => 'Relancer caméra';
  @override
  String get pasteTicketFieldLabel => 'Collez le JSON d\'invitation ou d\'association';
  @override
  String get btnJoinToThisDevice => 'Rejoindre / Enregistrer ici';

  @override
  String get allFilesTitle => 'Tous les fichiers';
  @override
  String get roomFilesTitle => 'Fichiers du salon';
  @override
  String get tooltipOpenMainReceiveFolder => 'Ouvrir dossier principal reçu';
  @override
  String get searchFileNameHint => 'Rechercher un nom de fichier...';
  @override
  String get allRoomsOption => 'Tous les salons';
  @override
  String tabImagesCount(int count) => 'Photos ($count)';
  @override
  String tabFilesCount(int count) => 'Fichiers ($count)';
  @override
  String loadFilesFailed(String error) => 'Échec du chargement : $error';
  @override
  String get emptyImagesNone => 'Aucune photo dans ce salon';
  @override
  String get emptyImagesSearch => 'Aucune photo correspondante';
  @override
  String get emptyFilesNone => 'Aucun fichier dans ce salon';
  @override
  String get emptyFilesSearch => 'Aucun fichier correspondant';
  @override
  String get badgeLocallyRemoved => 'Supprimé localement';
  @override
  String get unnamedFile => 'Fichier sans nom';
  @override
  String get toastLocalFileMissing => 'Fichier déplacé ou supprimé localement';
  @override
  String get actionOpenShort => 'Ouvrir';

  @override
  String get sectionGeneral => 'Général';
  @override
  String get sectionReceiveStorage => 'Réception et stockage';
  @override
  String get sectionResidencyNetwork => 'Arrière-plan et réseau';
  @override
  String get sectionAbout => 'À propos';
  @override
  String deviceModelLabel(String model) => 'Modèle : $model';
  @override
  String get toastCopiedFullDeviceId => 'ID complet copié';
  @override
  String get tooltipEditNameAvatar => 'Modifier nom et avatar';
  @override
  String get toastThumbCacheCleared =>
      'Cache des miniatures vidé (fichiers originaux préservés)';
  @override
  String toastSaveDirUpdated(String dir) => 'Dossier mis à jour : $dir';
  @override
  String saveDirNotWritable(Object error) => 'Dossier non inscriptible : $error';
  @override
  String get needAllFilesPermTitle => 'Accès à tous les fichiers requis';
  @override
  String get needAllFilesPermBody =>
      'Android requiert cette autorisation pour enregistrer directement dans "Téléchargements".';
  @override
  String get btnGoGrant => 'Autoriser';
  @override
  String get pickReceiveFolderDialogTitle => 'Choisir le dossier de réception';
  @override
  String storageSizeSuffix(String size, int count) =>
      ' ($size · $count fichiers)';
  @override
  String get storageModeDownloads => 'Dossier public "Téléchargements" (Downloads)';
  @override
  String get storageModeDocuments => 'Dossier public "Documents"';
  @override
  String get storageModeCustomTitle => 'Dossier personnalisé';
  @override
  String storageModeCustom(String compactPath) => 'Personnalisé ($compactPath)';
  @override
  String get storageModeAppPrivate => 'Stockage privé de l\'app (Android/data)';
  @override
  String get receiveLocationTitle => 'Emplacement des fichiers reçus';
  @override
  String get storageDownloadsDesc =>
      'Facile d\'accès via Fichiers et d\'autres applications';
  @override
  String get storageDocumentsDesc =>
      'Idéal pour ranger documents et PDF durablement';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      'Dossier actuel : $compactPath';
  @override
  String get storageCustomUnselectedDesc =>
      'Choisir une carte SD ou un dossier personnalisé';
  @override
  String get btnChange => 'Changer';
  @override
  String get storageAppPrivateTitle => 'Dossier privé (effacé si désinstallé)';
  @override
  String get storageAppPrivateDesc =>
      'Masqué de la galerie et de Fichiers ; effacé à la désinstallation';
  @override
  String get legacyStoragePermNotice =>
      'Autorisation stockage requise pour écrire dans Téléchargements';
  @override
  String get btnAuthorize => 'Autoriser';
  @override
  String get btnChangeFolder => 'Changer dossier';
  @override
  String get pickReceiveDirDialogTitle => 'Choisir le dossier automatique';
  @override
  String get windowsResidencyTitle => 'Zone de notification et démarrage';
  @override
  String get windowsCloseToTrayTitle => 'Réduire dans la zone de notification';
  @override
  String get windowsCloseToTraySubtitle =>
      'Cliquer sur × garde l\'app active pour recevoir fichiers et alertes';
  @override
  String get windowsAutoStartTitle => 'Lancer en arrière-plan avec Windows';
  @override
  String get windowsAutoStartSubtitle =>
      'Démarre réduit dans la zone de notification (--minimized)';
  @override
  String get btnHideToTrayNow => 'Réduire dans la zone maintenant';
  @override
  String get btnQuitBackgroundService => 'Quitter complètement (service inclus)';
  @override
  String get themeDialogTitle => 'Choisir le thème';
  @override
  String get themeSystemTitle => 'Suivre le système';
  @override
  String get themeSystemSubtitle => 'Suit le thème clair/sombre de l\'appareil';
  @override
  String get themeLightTitle => 'Mode clair';
  @override
  String get themeLightSubtitle => 'Fond clair aux accents menthe doux';
  @override
  String get themeDarkTitle => 'Mode sombre';
  @override
  String get themeDarkSubtitle => 'Palette sombre confortable la nuit';
  @override
  String get themeSystemShort => 'Système';
  @override
  String get themeLightShort => 'Clair';
  @override
  String get themeDarkShort => 'Sombre';
  @override
  String get languageDialogTitle => 'Langue';
  @override
  String get languageSettingTitle => 'Langue';
  @override
  String get languageSystemTitle => 'Suivre la langue du système';
  @override
  String get languageSystemSubtitle =>
      'S\'adapte automatiquement à la langue du système';
  @override
  String toastLanguageUpdated(String langName) =>
      'Langue changée pour $langName';
  @override
  String get storageManagerTitle => 'Stockage et cache';
  @override
  String storageRecvStats(String size, int count) =>
      'Utilisé : $size · $count fichiers';
  @override
  String get countingStats => 'Calcul en cours...';
  @override
  String get storageRecvUsedTitle => 'Espace fichiers reçus';
  @override
  String get thumbCacheTitle => 'Cache des miniatures';
  @override
  String thumbCacheDesc(String size) =>
      '$size utilisés · Vider ne touche pas vos fichiers reçus';
  @override
  String get btnClearThumbCache => 'Vider le cache';
  @override
  String get mobileStorageTitle => 'Stockage et cache';
  @override
  String legendReceivedFiles(String size) => 'Reçus $size';
  @override
  String legendThumbCache(String size) => 'Cache $size';
  @override
  String receivedFilesCountTitle(int count) => 'Fichiers reçus ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => 'Cache miniatures ($size)';
  @override
  String get thumbCacheNoTouchNotice =>
      'Ne supprime pas vos photos ou fichiers originaux';
  @override
  String get noCacheToClear => 'Aucun cache à vider';
  @override
  String btnClearThumbCacheWithSize(String size) => 'Vider le cache ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      'Reçus $recvSize · Cache $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => 'Cache $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      'Total $totalSize · Cache $cacheSize';
  @override
  String get storageAndCacheTitle => 'Stockage et cache';
  @override
  String get aboutTitle => 'À propos de Transfert Privé P2P';
  @override
  String aboutVersion(String version) => 'Version : $version';
  @override
  String get aboutBody =>
      'Outil P2P multiplateforme chiffré de bout en bout, sans cloud ni limite de taille.\n\n• Fixation NIC physique : contourne VPN/TUN en réseau local\n• Clés isolées par salon : le nœud domestique ne stocke que du chiffré\n• Route USB prioritaire : protège Windows contre le détournement de route';
  @override
  String get aboutSubtitle => 'Transfert chiffré sans serveur';
  @override
  String get networkDiagTitle => 'Réseau avancé et diagnostic';
  @override
  String get networkDiagLoading => 'Analyse des interfaces réseau...';
  @override
  String networkDiagDesktopReady(int count) =>
      'Prêt · $count adaptateurs LAN/USB directs détectés';
  @override
  String get networkDiagDesktopWanOnly => 'Canal P2P externe chiffré (pas de LAN)';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB prêt · $count interfaces détectées';
  @override
  String get networkDiagMobileWanOnly => 'Actuel : Canal chiffré externe (WAN)';
  @override
  String get nicDetectionTitle => 'Interfaces physiques LAN / USB (anti-VPN)';
  @override
  String get nicDetectionDesc =>
      'Ignore les interfaces TUN virtuelles (Clash, Mihomo, WireGuard) et utilise uniquement les cartes physiques.';
  @override
  String get nicReading => 'Lecture des interfaces...';
  @override
  String get nicNoneConnected => 'Aucune interface physique connectée';
  @override
  String get btnRefreshNics => 'Actualiser';
  @override
  String get usbProtectionTitle => 'Protection de route USB Tether (Windows)';
  @override
  String get usbProtectionDesc =>
      'Lorsque le partage USB Android est actif, isole la métrique à 5000 pour transférer vite sur le port 42420 sans couper l\'internet du PC.';
  @override
  String get usbProtectionReady =>
      'Prêt : Route USB isolée sans détournement (Metric=5000)';
  @override
  String usbProtectionNeedsFix(String detail) => 'Ajustement requis : $detail';
  @override
  String get usbProtectionNotPlugged =>
      'USB non branché ; protégé automatiquement dès connexion';
  @override
  String get btnFixMetric => 'Corriger métrique';
  @override
  String get customRelayTitle => 'Serveur Relais personnalisé (Avancé)';
  @override
  String get customRelayDesc =>
      'En cas d\'échec P2P direct, le relais transmet des paquets chiffrés sans pouvoir les lire. Laisser vide pour le relais public.';
  @override
  String get customRelayLabel => 'URL du relais (vide = relais public)';
  @override
  String get toastRelaySaved => 'URL du relais enregistrée';
  @override
  String get btnSaveRelay => 'Enregistrer URL';
  @override
  String get deviceIdLabel => 'ID de l\'appareil';
  @override
  String get btnCopyDeviceId => 'Copier l\'ID complet';
  @override
  String get deviceIdCopiedBadge => 'Copié';

  @override
  String toastEventStreamError(Object error) => 'Erreur flux d\'événements : $error';
  @override
  String toastCreatedRoom(String name) => 'Salon chiffré "$name" créé';
  @override
  String toastCreateRoomFailed(Object error) => 'Échec création salon : $error';
  @override
  String toastOpenChatFailed(Object error) => 'Échec ouverture chat : $error';
  @override
  String toastCreatedGroup(String name) => 'Groupe "$name" créé';
  @override
  String toastCreateGroupFailed(Object error) => 'Échec création groupe : $error';
  @override
  String toastJoinedRoom(String name) => 'Vous avez rejoint "$name"';
  @override
  String toastAddedDevice(String name) => 'Appareil "$name" ajouté';
  @override
  String toastPairFailed(Object error) => 'Échec d\'association : $error';
  @override
  String toastSendTextFailed(Object error) => 'Échec d\'envoi texte : $error';
  @override
  String get toastSelectRoomFirst => 'Sélectionnez d\'abord un salon ou appareil';
  @override
  String toastSendFileFailed(String path, Object error) =>
      'Échec d\'envoi ($path) : $error';
  @override
  String get toastForwardFileMissing =>
      'Transfert impossible : fichier local manquant';
  @override
  String get toastForwardEmptyText =>
      'Transfert impossible : texte vide';
  @override
  String get fallbackTargetRoom => 'Salon cible';
  @override
  String toastForwardedTo(String targetName) => 'Transféré à "$targetName"';
  @override
  String toastForwardFailed(Object error) => 'Échec transfert : $error';
  @override
  String get fallbackBigFile => 'Gros fichier';
  @override
  String toastConfirmedSend(String fileName) => 'Envoi confirmé : "$fileName"';
  @override
  String toastConfirmSendFailed(Object error) => 'Échec confirmation : $error';
  @override
  String get fallbackFile => 'Fichier';
  @override
  String toastPullingFile(String fileName) => 'Téléchargement de "$fileName"';
  @override
  String toastPullFileFailed(Object error) => 'Échec téléchargement : $error';
  @override
  String get toastPeerDeleted => 'Appareil associé supprimé';
  @override
  String toastDeletePeerFailed(Object error) => 'Échec suppression : $error';
  @override
  String get toastRoomDeleted => 'Discussion supprimée';
  @override
  String toastDeleteRoomFailed(Object error) => 'Échec suppression chat : $error';
  @override
  String get toastDeletedRecordAndFile => 'Entrée et fichier local supprimés';
  @override
  String get toastRemovedLocalRecord => 'Retiré de l\'historique local';
  @override
  String toastDeleteMsgFailed(Object error) => 'Échec suppression : $error';
  @override
  String get toastOnlyRevokeOwn => 'Vous ne pouvez retirer que vos propres messages';
  @override
  String get toastRevokedForAll => 'Message retiré sur tous les appareils';
  @override
  String toastRevokeFailed(Object error) => 'Échec retrait : $error';
  @override
  String toastInvitedMembers(int count) => '$count appareils invités';
  @override
  String toastAddMembersFailed(Object error) => 'Échec ajout membres : $error';
  @override
  String get toastRemovedMember => 'Appareil retiré du groupe';
  @override
  String toastRemoveMemberFailed(Object error) => 'Échec retrait membre : $error';
  @override
  String toastFixUsbMetricFailed(Object error) => 'Échec métrique USB : $error';
  @override
  String toastReceiveDirFallback(String dir) => 'Dossier de réception : $dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => 'Dossier mis à jour : $dir';
  @override
  String get toastClearedCustomSaveDir =>
      'Dossier personnalisé effacé ; dossier par défaut actif';
  @override
  String toastSetDirFailed(Object error) => 'Échec configuration dossier : $error';
  @override
  String toastSyncAvatarFailed(Object error) => 'Échec synchro avatar : $error';
  @override
  String get toastSelfProfileUpdated => 'Profil mis à jour et synchronisé';
  @override
  String get toastPeerRemarkUpdated => 'Surnom mis à jour';
  @override
  String get toastRestoredGroupName => 'Nom du groupe réinitialisé';
  @override
  String get toastUpdatedGroupName => 'Nom local du groupe mis à jour';
  @override
  String get toastAutoStartEnabled => 'Démarrage silencieux activé';
  @override
  String get toastAutoStartDisabled => 'Démarrage automatique désactivé';
  @override
  String get toastCloseToTrayEnabled => 'Fermer réduira dans la zone';
  @override
  String get toastCloseToTrayDisabled => 'Fermer quittera l\'application';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      'Reçu de $sender : $fileName';
  @override
  String get notifyFileFallbackBody => 'Nouveau fichier enregistré';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      'Réception de $fileLabel et autres ($totalCount fichiers)';
  @override
  String notifyNewFileTitle(String sender) => 'Nouveau fichier · $sender';
  @override
  String notifyNewTextTitle(String sender) => 'Nouveau message · $sender';
  @override
  String get notifyNewEncryptedText => 'Nouveau message chiffré';
  @override
  String get errorEmptyImageFile => 'Le fichier image est vide';
  @override
  String get errorCompressAvatarFailed => 'Échec compression avatar';
  @override
  String get errorPngEncodeFailed => 'Échec encodage PNG';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'Aucun adaptateur USB tethering détecté';
    if (metricProtected) {
      return 'Métrique USB fixée à 5000 pour préserver l\'internet du PC';
    }
    if (needsElevation) {
      return 'Droits administrateur requis pour fixer la métrique USB à 5000';
    }
    return 'Partage USB détecté, en attente d\'isolation métrique';
  }

  @override
  String get winTrayTooltip => 'Transfert Privé P2P · Service actif';
  @override
  String get winTrayOpenWindow => 'Ouvrir la fenêtre principale';
  @override
  String get winTrayAutoStart => 'Démarrer réduit avec Windows';
  @override
  String get winTrayCloseToTray => 'Réduire dans la zone à la fermeture';
  @override
  String get winTrayExitApp => 'Quitter l\'application';
}
