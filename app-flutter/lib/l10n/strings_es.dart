import 'app_strings.dart';

class StringsEs extends AppStrings {
  const StringsEs();

  static const _months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  @override
  String get localeCode => 'es';

  @override
  String get appTitle => 'P2Pfiledrop';
  @override
  String get appSubtitle => 'Transferencia cifrada de extremo a extremo';
  @override
  String get startingEngine => 'Iniciando motor de transferencia cifrada P2P...';
  @override
  String engineInitFailed(Object error) => 'Error al iniciar el motor:\n$error';
  @override
  String get retry => 'Reintentar';
  @override
  String get cancel => 'Cancelar';
  @override
  String get confirm => 'Aceptar';
  @override
  String get close => 'Cerrar';
  @override
  String get save => 'Guardar';
  @override
  String get delete => 'Eliminar';
  @override
  String get remove => 'Quitar';
  @override
  String get open => 'Abrir';
  @override
  String get refresh => 'Actualizar';
  @override
  String get clear => 'Limpiar';
  @override
  String get resetDefault => 'Restablecer';
  @override
  String get recommendedBadge => 'Recomendado';
  @override
  String get defaultAvatarFallback => 'D';

  @override
  String formatFullDate(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  @override
  String formatMonthDay(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}';
  @override
  String get todayLabel => 'Hoy';
  @override
  String get yesterdayLabel => 'Ayer';
  @override
  String formatRemainingSeconds(int seconds) => 'Quedan ${seconds}s';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      'Quedan ${minutes}m ${seconds}s';

  @override
  String get navTransfers => 'Chats';
  @override
  String get navDevices => 'Equipos';
  @override
  String get navThisDevice => 'Yo';
  @override
  String get navAdd => 'Añadir';
  @override
  String get navFiles => 'Archivos';
  @override
  String get navFolder => 'Carpeta';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName (Toca para ajustes)';
  @override
  String get tooltipScanPair => 'Escanear QR para vincular o unirse';
  @override
  String get tooltipAllFiles => 'Ver todos los archivos y fotos';
  @override
  String tooltipOpenReceiveFolder(String dir) => 'Abrir carpeta de recepción ($dir)';

  @override
  String get transportUsbTether => 'USB directo';
  @override
  String get transportLanDirect => 'LAN directa';
  @override
  String get transportWanP2p => 'P2P externo';
  @override
  String get transportWanRelay => 'Retransmisión';
  @override
  String get transportOffline => 'Sin conexión';
  @override
  String get usbTetherTag => 'USB directo';

  @override
  String get msgStatusQueuedOffline => 'Esperando conexión';
  @override
  String get msgStatusHandshaking => 'Cifrando enlace';
  @override
  String get msgStatusTransferring => 'Transfiriendo';
  @override
  String get msgStatusPausedReconnecting => 'Reanudando';
  @override
  String get msgStatusAwaitingDownload => 'Toca para descargar';
  @override
  String get msgStatusDelivered => 'Entregado';
  @override
  String get msgStatusFailedSourceMissing => 'Falta origen';

  @override
  String deviceWithTag(String tag) => 'Equipo $tag';
  @override
  String deviceShortIdLabel(String shortId) => 'Equipo · $shortId';
  @override
  String get peerDeviceFallback => 'Equipo remoto';
  @override
  String get defaultPersonalRoomName => 'Mis dispositivos (Personal)';
  @override
  String get defaultEncryptedGroupName => 'Nuevo grupo cifrado';
  @override
  String get defaultPrivateRoomName => 'Nueva sala privada cifrada';
  @override
  String encryptedRoomWithId(String shortId) => 'Sala cifrada ($shortId)';
  @override
  String get homeNodeDefaultName => 'Nodo doméstico 24h';

  @override
  String get chatListTitle => 'Chats';
  @override
  String get chatListNewActionTooltip => 'Escanear QR / Crear grupo';
  @override
  String get menuScanPairOrJoin => 'Escanear QR para vincular / unirse';
  @override
  String get menuCreateGroup => 'Crear grupo compartido';
  @override
  String get menuMyPairingQr => 'Mi código QR';
  @override
  String get menuOpenReceiveFolder => 'Abrir carpeta de recepción';
  @override
  String get menuProbeReconnect => 'Comprobar / Reconectar';
  @override
  String get searchChatsHint => 'Buscar chats o equipos...';
  @override
  String groupOnlineCount(int online, int total) =>
      'Grupo ($online/$total en línea)';
  @override
  String groupOfflineCount(int total) => 'Grupo ($total equipos · sin conexión)';
  @override
  String get emptyChatsSearch => 'No hay chats que coincidan';
  @override
  String get emptyChatsNoRooms => 'Aún no hay conversaciones';
  @override
  String get btnScanPairDevice => 'Escanear QR para vincular';
  @override
  String get btnGoToDevices => 'Ir a la pestaña Equipos';

  @override
  String get devicesListTitle => 'Equipos';
  @override
  String get searchPairedDevicesHint => 'Buscar equipos vinculados...';
  @override
  String get btnAddNewDevice => 'Añadir equipo / Escanear QR';
  @override
  String get btnNewSharedGroup => 'Nuevo grupo compartido';
  @override
  String get btnAddDeviceShort => 'Añadir equipo';
  @override
  String get btnNewGroupShort => 'Nuevo grupo';
  @override
  String pairedDevicesCount(int count) => 'Equipos vinculados ($count)';
  @override
  String get emptyDevicesSearch => 'No hay equipos que coincidan';
  @override
  String get emptyDevicesNone =>
      'No hay equipos vinculados\nToca "Añadir equipo / Escanear QR" arriba para empezar';
  @override
  String get selectDevicePrompt => 'Selecciona un equipo a la izquierda para ver detalles';
  @override
  String get btnScanFirstDevice => 'Vincular primer equipo';
  @override
  String originalNameLabel(String name) => 'Nombre original: $name';
  @override
  String get deviceNodeIdLabel => 'ID del nodo (Endpoint ID)';
  @override
  String get tooltipCopyDeviceId => 'Copiar ID';
  @override
  String get toastCopiedDeviceId => 'ID del equipo copiado';
  @override
  String get btnSendMessageOrFile => 'Enviar mensaje / archivo';
  @override
  String get btnEditRemark => 'Editar alias';
  @override
  String get btnDeleteDevice => 'Eliminar este equipo';
  @override
  String get deletePeerDialogTitle => 'Eliminar equipo vinculado';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      '¿Quieres quitar "$resolvedName" de los equipos de confianza y borrar su chat directo? (Los archivos ya guardados no se borrarán).';
  @override
  String get btnConfirmDelete => 'Eliminar';

  @override
  String get desktopWorkspaceTitle => 'Espacio de transferencia';
  @override
  String get btnOpenFolder => 'Abrir carpeta';
  @override
  String get tooltipRoomFiles => 'Archivos y fotos de la sala';
  @override
  String get tooltipInviteOrScan => 'Invitar por QR / Escanear';
  @override
  String get tooltipRoomMembers => 'Detalles / Miembros del grupo';
  @override
  String get desktopEmptyTitle => 'Elige un chat o equipo a la izquierda';
  @override
  String get desktopEmptySubtitle =>
      'Admíte LAN directa, cable USB prioritario y cifrado externo. Arrastra archivos aquí para enviar al instante.';
  @override
  String get moreActionsTooltip => 'Más acciones';
  @override
  String get moreTooltip => 'Más';
  @override
  String get emptyRoomNoSession => 'Sin chat activo. Escanea un QR para vincular primero.';
  @override
  String get emptyRoomE2eeNotice =>
      'Esta sala está cifrada de extremo a extremo; solo los miembros pueden descifrar los datos.';
  @override
  String get emptyRoomWindowsHint =>
      'Arrastra archivos o fotos aquí para enviar, o escribe un mensaje abajo.';
  @override
  String get emptyRoomMobileHint =>
      'Pulsa + abajo para enviar fotos/archivos o escribe un mensaje.';
  @override
  String dropZonePrompt(String roomTitle) =>
      'Suelta para enviar cifrado a "$roomTitle"';
  @override
  String get menuAddPairedToGroup => 'Añadir equipos al grupo';
  @override
  String get menuDeviceDetailsAndRemark => 'Detalles y alias del equipo';
  @override
  String get menuGroupMembersAndManage => 'Miembros y gestión del grupo';
  @override
  String get noShareTargetsToast => 'No hay equipos o salas disponibles aún';
  @override
  String get fallbackShortTitle => 'Privado P2P';

  @override
  String get tooltipGalleryImages => 'Fotos de la galería';
  @override
  String get tooltipSendFile => 'Elegir archivo';
  @override
  String get tooltipSendImageOrFile => 'Enviar foto o archivo';
  @override
  String get tooltipPasteClipboard => 'Pegar imagen o texto';
  @override
  String get inputHintWindows =>
      'Escribe un mensaje, pega o arrastra archivos...';
  @override
  String get inputHintMobile => 'Escribe un mensaje...';
  @override
  String get inputHintNoRoom => 'Añade primero un equipo arriba (+)...';
  @override
  String get tooltipSendMessage => 'Enviar';

  @override
  String get newMessagesBelowSuffix => 'mensajes nuevos';
  @override
  String albumFailedCount(int failedCount) =>
      'Falta el origen en $failedCount fotos';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      'Enviado ($missingCount orígenes eliminados)';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      'Recibido ($missingCount borradas localmente)';
  @override
  String get albumAllDelivered => 'Todo entregado';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      'Enviando $delivered/$total';
  @override
  String albumImageCount(int count) => '$count fotos';
  @override
  String get btnExpand => 'Ver';
  @override
  String collapseImagesCount(int count) => 'Ocultar ($count)';

  @override
  String get statusLargeFileAwaitConfirm => 'Pendiente de confirmar';
  @override
  String get statusGroupFileAwaitDownload => 'Listo para descargar';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      'Oferta enviada ($acked/$total)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      'Por confirmar ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      'Entregado a todos ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) =>
      'Entregado ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => 'Archivo origen quitado';
  @override
  String get statusLocalFileDeleted => 'Archivo local eliminado';
  @override
  String get revokedByMe => 'Anulaste el envío de este mensaje';
  @override
  String get revokedByPeer => 'El otro equipo anuló este mensaje';
  @override
  String get tooltipEditPeerRemark => 'Editar alias';
  @override
  String get tooltipPeerAvatar => 'Equipo remoto';
  @override
  String get toastCopiedText => 'Texto copiado';
  @override
  String toastCopiedPath(String path) => 'Ruta copiada: $path';
  @override
  String get imageDeletedLocally => 'Foto eliminada de este equipo';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · Foto origen quitada';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · Foto borrada (toca para detalles)';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · Falta archivo origen';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · Borrado localmente';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · Archivo grande por confirmar';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · Archivo de grupo disponible';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · Esperando descarga';
  @override
  String btnDownloadToDevice(String sizeLabel) => 'Descargar ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => 'Enviar ahora ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => 'Enviar al conectarse';
  @override
  String get actionCopyText => 'Copiar texto';
  @override
  String get actionForward => 'Reenviar';
  @override
  String get actionOpenFile => 'Abrir archivo';
  @override
  String get actionRevealInFolder => 'Mostrar en carpeta';
  @override
  String get actionCopyFilePath => 'Copiar ruta';

  @override
  String get createGroupTitle => 'Crear grupo cifrado';
  @override
  String get createGroupDesc =>
      'Marca equipos ya vinculados para formar un grupo con clave E2EE dedicada (sin volver a escanear QR).';
  @override
  String get groupNameOptionalLabel => 'Nombre del grupo (opcional)';
  @override
  String get groupNameAutoHint => 'Si se deja vacío se genera automáticamente';
  @override
  String get createGroupNoPeersNotice =>
      'No hay equipos vinculados todavía. Puedes crear el grupo y añadir miembros luego mediante QR.';
  @override
  String selectGroupDevicesCount(int count) =>
      'Elige equipos ($count seleccionados):';
  @override
  String get btnCreateGroup => 'Crear grupo';
  @override
  String get defaultGroupNameFallback => 'Grupo cifrado';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => 'Grupo $joinedNames';
  @override
  String get nameSeparator => ', ';
  @override
  String get addMembersToGroupTitle => 'Añadir equipos al grupo';
  @override
  String get btnConfirmInvite => 'Invitar';
  @override
  String get allPeersAlreadyInGroupToast =>
      'Todos los equipos vinculados ya están en el grupo';
  @override
  String get subtitleDmE2ee => 'P2P directo · Cifrado E2E';
  @override
  String subtitleGroupE2ee(int count) => 'Grupo ($count equipos) · Clave aislada';
  @override
  String get tooltipEditGroupName => 'Renombrar grupo';
  @override
  String get badgeThisTerminal => 'Este equipo';
  @override
  String get roleThisDevice => 'Este equipo (editable)';
  @override
  String get rolePeerDevice => 'Equipo remoto';
  @override
  String get roleGroupMember => 'Miembro del grupo';
  @override
  String get tooltipEditSelfProfile => 'Editar nombre y avatar';
  @override
  String get tooltipRemoveFromGroup => 'Quitar del grupo';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      '¿Desvincular y eliminar a "$roomTitle"? (Los archivos guardados permanecerán en el equipo).';
  @override
  String get deleteGroupTitle => 'Eliminar grupo';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      '¿Eliminar "$roomTitle" y su historial en este equipo? (Los archivos guardados no se borrarán).';
  @override
  String get btnDeleteAndLeave => 'Eliminar y salir';
  @override
  String get btnInviteNewDevice => 'Invitar / Escanear nuevo equipo';
  @override
  String get editGroupNameTitle => 'Renombrar grupo';
  @override
  String get localDisplayNameLabel => 'Nombre local';
  @override
  String editGroupNameHint(String defaultName) =>
      'Dejar vacío para usar "$defaultName"';
  @override
  String get editProfileSelfTitle => 'Editar nombre y avatar';
  @override
  String get editProfilePeerTitle => 'Editar alias del equipo';
  @override
  String processImageFailed(Object error) => 'Error al procesar imagen: $error';
  @override
  String get btnChangeAvatar => 'Cambiar avatar';
  @override
  String get btnUploadAvatar => 'Subir avatar';
  @override
  String get btnRemoveImage => 'Quitar foto';
  @override
  String get avatarSyncNoticeSelf =>
      'Al subir una foto se sincroniza cifrada con tus equipos';
  @override
  String get avatarSyncNoticePeer =>
      'El alias es solo local; el avatar refleja la foto configurada por el otro equipo';
  @override
  String get selfDisplayNameLabel => 'Nombre de este equipo';
  @override
  String get peerRemarkNameLabel => 'Alias del equipo';
  @override
  String get customDeviceNameHint => 'Introduce un nombre personalizado';
  @override
  String defaultNameDisplay(String fallbackModel) => 'Predeterminado: $fallbackModel';
  @override
  String get shareToTitle => 'Compartir en...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "Foto" : "Archivo"}: $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '$count ${allImages ? "fotos" : "archivos"} · $size';
  @override
  String shareSummaryText(String text) => 'Texto: $text';
  @override
  String get sendToTitle => 'Enviar a';
  @override
  String get targetTypeDm => 'Equipo directo';
  @override
  String targetTypeGroup(int memberCount) => 'Grupo · $memberCount equipos';
  @override
  String get targetTypePairedPeer => 'Equipo vinculado (P2P directo)';
  @override
  String get btnReselect => 'Cambiar';
  @override
  String btnSendCount(int count) => 'Enviar ($count)';
  @override
  String get btnSend => 'Enviar';
  @override
  String shareFileListMore(int count, String size) =>
      'y más ($count archivos) · $size';
  @override
  String shareFileListExact(int count, String size) => '$count archivos · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      'Reenviar ${isImage ? "foto" : "archivo"}: $fileName';
  @override
  String forwardSummaryText(String text) => 'Reenviar mensaje: $text';
  @override
  String get forwardToTitle => 'Reenviar a...';
  @override
  String get searchRoomOrDeviceHint => 'Buscar salas o equipos...';
  @override
  String get noAvailableTargets => 'No hay salas ni equipos disponibles';
  @override
  String get noMatchingTargets => 'No hay coincidencias';
  @override
  String get currentConversationLabel => 'Chat actual';
  @override
  String get tooltipOpenWithDefaultApp => 'Abrir con app predeterminada';
  @override
  String get tooltipDeleteMessage => 'Eliminar mensaje';
  @override
  String get tooltipClosePreview => 'Cerrar vista previa';
  @override
  String get deletedImagePreviewTitle => 'Foto eliminada localmente';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '"$fileName" ya no está en este equipo y no se puede previsualizar.';
  @override
  String get btnDeleteThisRecord => 'Eliminar este registro';
  @override
  String get removeRevokeNoticeTitle => 'Aviso';
  @override
  String get removeRevokeNoticeBody =>
      'Aunque falte el archivo local, puedes borrar el registro de tu historial sin afectar al otro equipo.';
  @override
  String get deleteOutgoingFileTitle => 'Eliminar archivo enviado';
  @override
  String get deleteOutgoingTextTitle => 'Eliminar mensaje enviado';
  @override
  String get chooseDeleteMethod => 'Elige cómo eliminar:';
  @override
  String get deleteOutgoingFileDetail =>
      '• Anular para todos: Notifica a los miembros y nodos relé para borrar también las copias autoguardadas.\n• Quitar solo aquí: Borra solo tu historial local.\n\nTu archivo original en disco nunca será modificado ni eliminado.';
  @override
  String get deleteOutgoingTextDetail =>
      '• Anular para todos: Borra este mensaje en todos los equipos y nodos relé.\n• Quitar solo aquí: Borra el mensaje solo en este equipo.';
  @override
  String get btnRemoveLocalOnly => 'Quitar solo aquí';
  @override
  String get btnRevokeForAll => 'Anular para todos';
  @override
  String get deleteIncomingFileTitle => 'Eliminar archivo recibido';
  @override
  String get deleteIncomingTextTitle => 'Eliminar mensaje recibido';
  @override
  String get deleteIncomingNote =>
      'Solo se elimina en este equipo, sin afectar al remitente.';
  @override
  String get checkboxDeleteLocalFile => 'Borrar también el archivo guardado aquí';
  @override
  String get incomingFileAlreadyMissing =>
      'El archivo local ya no existe; solo se eliminará el registro.';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      'Vista previa ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => 'Confirmar envío ($count archivos)';
  @override
  String get btnAddMore => 'Añadir más';
  @override
  String batchLimitNotice(int maxFiles) =>
      'Máximo $maxFiles archivos por lote; se conservaron los primeros $maxFiles.';
  @override
  String get tooltipPrevImage => 'Anterior';
  @override
  String get tooltipNextImage => 'Siguiente';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '$count elementos · $size${showEnterHint ? ' (Enter para enviar)' : ''}';

  @override
  String inviteGroupTitle(String roomName) => 'Invitar a "$roomName"';
  @override
  String get inviteDeviceTitle => 'Añadir equipo / Escanear QR';
  @override
  String get tabGroupInviteQr => 'QR del grupo';
  @override
  String get tabDevicePairingQr => 'Mi código QR';
  @override
  String get tabScanOrPaste => 'Escanear / Pegar';
  @override
  String get desktopQrImageUnsupported =>
      'En escritorio aún no se leen QR desde imagen. Pega el JSON del ticket directamente.';
  @override
  String get noQrDetectedInImage =>
      'No se detectó ningún QR en la imagen. Prueba con una foto más nítida.';
  @override
  String galleryQrScanFailed(Object error) => 'Error al leer QR: $error';
  @override
  String generateQrFailed(Object error) => 'Error al generar QR: $error';
  @override
  String get joinOrPairFailedHint =>
      'Error al procesar. Revisa que el ticket JSON esté completo.';
  @override
  String groupInviteDesc(String roomName) =>
      'QR del grupo: al escanearlo se une directamente a "$roomName" y sincroniza su clave E2EE.';
  @override
  String get devicePairingDesc =>
      'Mi código QR: vincula ambos equipos como de confianza y abre un canal cifrado P2P.';
  @override
  String get toastCopiedQrJson => 'Ticket JSON copiado al portapapeles';
  @override
  String get btnCopyTextTicket => 'Copiar ticket texto';
  @override
  String get btnRetryGenerateQr => 'Reintentar QR';
  @override
  String get scannerPermDenied =>
      'Sin permiso de cámara. Concede acceso o elige un QR de la galería.';
  @override
  String get scannerUnsupported =>
      'Cámara no disponible en este equipo. Elige imagen de galería o pega el ticket.';
  @override
  String get scannerReinitializing =>
      'Reiniciando cámara. Pulsa Reintentar en un momento.';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      'Error de cámara ($details)';
  @override
  String get scannerGenericError =>
      'No se pudo abrir la cámara. Reintenta o elige un QR de la galería.';
  @override
  String get startingCamera => 'Iniciando cámara...';
  @override
  String get btnPickQrFromGallery => 'Elegir QR de galería';
  @override
  String get btnRetryCamera => 'Reintentar';
  @override
  String get pasteTicketDialogTitle => 'Pegar ticket para unirse';
  @override
  String get pasteTicketFieldHint => 'Pega aquí el JSON de invitación o vinculación';
  @override
  String get btnJoinOrRegister => 'Unirse / Registrar';
  @override
  String get cameraNotSupportedPlatform =>
      'Cámara no compatible aquí. Usa "Pegar ticket" o elige una foto de galería.';
  @override
  String get qrViewfinderHint =>
      'Centra el código QR dentro del marco para vincular';
  @override
  String get analyzingImageQr => 'Analizando QR de la imagen...';
  @override
  String get verifyingHandshake => 'Verificando enlace cifrado...';
  @override
  String get actionGallery => 'Galería';
  @override
  String get actionPasteTicket => 'Pegar ticket';
  @override
  String get actionTorchOff => 'Apagar flash';
  @override
  String get actionTorchOn => 'Encender flash';
  @override
  String get windowsPasteTicketHint =>
      'En Windows puedes pegar directamente el "Ticket de invitación" para entrar al mismo grupo cifrado.';
  @override
  String get btnAnalyzingQr => 'Analizando QR...';
  @override
  String get btnRestartCamera => 'Reiniciar cámara';
  @override
  String get pasteTicketFieldLabel => 'Pega el JSON de invitación o vinculación';
  @override
  String get btnJoinToThisDevice => 'Unirse / Registrar aquí';

  @override
  String get allFilesTitle => 'Todos los archivos';
  @override
  String get roomFilesTitle => 'Archivos de la sala';
  @override
  String get tooltipOpenMainReceiveFolder => 'Abrir carpeta principal de recepción';
  @override
  String get searchFileNameHint => 'Buscar nombre de archivo...';
  @override
  String get allRoomsOption => 'Todas las salas';
  @override
  String tabImagesCount(int count) => 'Fotos ($count)';
  @override
  String tabFilesCount(int count) => 'Archivos ($count)';
  @override
  String loadFilesFailed(String error) => 'Error al cargar: $error';
  @override
  String get emptyImagesNone => 'Aún no hay fotos en esta sala';
  @override
  String get emptyImagesSearch => 'No hay fotos que coincidan';
  @override
  String get emptyFilesNone => 'Aún no hay archivos en esta sala';
  @override
  String get emptyFilesSearch => 'No hay archivos que coincidan';
  @override
  String get badgeLocallyRemoved => 'Borrado localmente';
  @override
  String get unnamedFile => 'Archivo sin nombre';
  @override
  String get toastLocalFileMissing => 'El archivo local fue movido o borrado';
  @override
  String get actionOpenShort => 'Abrir';

  @override
  String get sectionGeneral => 'General';
  @override
  String get sectionReceiveStorage => 'Recepción y almacenamiento';
  @override
  String get sectionResidencyNetwork => 'Segundo plano y red';
  @override
  String get sectionAbout => 'Acerca de';
  @override
  String deviceModelLabel(String model) => 'Modelo: $model';
  @override
  String get toastCopiedFullDeviceId => 'ID completo copiado';
  @override
  String get tooltipEditNameAvatar => 'Editar nombre y avatar';
  @override
  String get toastThumbCacheCleared =>
      'Caché de miniaturas limpia (tus archivos originales siguen intactos)';
  @override
  String toastSaveDirUpdated(String dir) => 'Carpeta de guardado cambiada: $dir';
  @override
  String saveDirNotWritable(Object error) => 'Sin permiso de escritura: $error';
  @override
  String get needAllFilesPermTitle => 'Se necesita acceso a todos los archivos';
  @override
  String get needAllFilesPermBody =>
      'Android requiere permiso para guardar archivos directamente en la carpeta pública "Descargas".';
  @override
  String get btnGoGrant => 'Conceder';
  @override
  String get pickReceiveFolderDialogTitle => 'Elegir carpeta de recepción';
  @override
  String storageSizeSuffix(String size, int count) =>
      ' ($size · $count archivos)';
  @override
  String get storageModeDownloads => 'Carpeta pública "Descargas" (Downloads)';
  @override
  String get storageModeDocuments => 'Carpeta pública "Documentos" (Documents)';
  @override
  String get storageModeCustomTitle => 'Carpeta personalizada';
  @override
  String storageModeCustom(String compactPath) => 'Personalizada ($compactPath)';
  @override
  String get storageModeAppPrivate => 'Privada de la app (Android/data)';
  @override
  String get receiveLocationTitle => 'Ubicación de archivos recibidos';
  @override
  String get storageDownloadsDesc =>
      'Fácil de abrir desde Archivos o cualquier otra aplicación';
  @override
  String get storageDocumentsDesc =>
      'Ideal para organizar documentos y PDF a largo plazo';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      'Ruta actual: $compactPath';
  @override
  String get storageCustomUnselectedDesc =>
      'Elige una tarjeta SD o cualquier carpeta propia';
  @override
  String get btnChange => 'Cambiar';
  @override
  String get storageAppPrivateTitle => 'Carpeta privada (se borra al desinstalar)';
  @override
  String get storageAppPrivateDesc =>
      'No aparece en la galería ni en Archivos; se elimina al desinstalar la app';
  @override
  String get legacyStoragePermNotice =>
      'Se requiere permiso de almacenamiento para escribir en Descargas';
  @override
  String get btnAuthorize => 'Autorizar';
  @override
  String get btnChangeFolder => 'Cambiar carpeta';
  @override
  String get pickReceiveDirDialogTitle => 'Elegir carpeta de autoguardado';
  @override
  String get windowsResidencyTitle => 'Bandeja de Windows e inicio automático';
  @override
  String get windowsCloseToTrayTitle => 'Minimizar a la bandeja al cerrar';
  @override
  String get windowsCloseToTraySubtitle =>
      'Pulsar × oculta la app en segundo plano para recibir archivos y avisos';
  @override
  String get windowsAutoStartTitle => 'Iniciar en segundo plano con Windows';
  @override
  String get windowsAutoStartSubtitle =>
      'Se inicia minimizado en la bandeja al encender el PC (--minimized)';
  @override
  String get btnHideToTrayNow => 'Ocultar en bandeja ahora';
  @override
  String get btnQuitBackgroundService => 'Salir por completo (incluido servicio)';
  @override
  String get themeDialogTitle => 'Elegir tema visual';
  @override
  String get themeSystemTitle => 'Seguir al sistema';
  @override
  String get themeSystemSubtitle => 'Cambia según el modo claro/oscuro del SO';
  @override
  String get themeLightTitle => 'Modo claro';
  @override
  String get themeLightSubtitle => 'Superficie clara con acentos menta suaves';
  @override
  String get themeDarkTitle => 'Modo oscuro';
  @override
  String get themeDarkSubtitle => 'Paleta nocturna cómoda para la vista';
  @override
  String get themeSystemShort => 'Sistema';
  @override
  String get themeLightShort => 'Claro';
  @override
  String get themeDarkShort => 'Oscuro';
  @override
  String get languageDialogTitle => 'Idioma';
  @override
  String get languageSettingTitle => 'Idioma';
  @override
  String get languageSystemTitle => 'Seguir idioma del sistema';
  @override
  String get languageSystemSubtitle =>
      'Se adapta automáticamente al idioma de tu dispositivo';
  @override
  String toastLanguageUpdated(String langName) =>
      'Idioma cambiado a $langName';
  @override
  String get storageManagerTitle => 'Almacenamiento y caché';
  @override
  String storageRecvStats(String size, int count) =>
      'Usado $size · $count archivos';
  @override
  String get countingStats => 'Calculando...';
  @override
  String get storageRecvUsedTitle => 'Espacio de archivos recibidos';
  @override
  String get thumbCacheTitle => 'Caché de miniaturas';
  @override
  String thumbCacheDesc(String size) =>
      'Usa $size · Limpiarla nunca borra los archivos guardados';
  @override
  String get btnClearThumbCache => 'Limpiar caché';
  @override
  String get mobileStorageTitle => 'Almacenamiento y caché';
  @override
  String legendReceivedFiles(String size) => 'Recibidos $size';
  @override
  String legendThumbCache(String size) => 'Caché $size';
  @override
  String receivedFilesCountTitle(int count) => 'Archivos recibidos ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => 'Caché miniaturas ($size)';
  @override
  String get thumbCacheNoTouchNotice =>
      'No borra tus fotos ni archivos originales';
  @override
  String get noCacheToClear => 'No hay caché para limpiar';
  @override
  String btnClearThumbCacheWithSize(String size) => 'Limpiar caché ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      'Recibidos $recvSize · Caché $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => 'Caché $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      'Total $totalSize · Caché $cacheSize';
  @override
  String get storageAndCacheTitle => 'Almacenamiento y caché';
  @override
  String get aboutTitle => 'Acerca de Transferencia P2P';
  @override
  String aboutVersion(String version) => 'Versión: $version';
  @override
  String get aboutBody =>
      'Herramienta P2P multiplataforma cifrada de extremo a extremo, sin nube ni límites de tamaño.\n\n• Vinculación a NIC física: evade VPN/TUN para velocidad LAN real\n• Claves aisladas por sala: el nodo doméstico guarda solo texto cifrado\n• Protección USB prioritaria: evita secuestro de ruta en Windows';
  @override
  String get aboutSubtitle => 'Transferencia cifrada sin servidores';
  @override
  String get networkDiagTitle => 'Red avanzada y diagnóstico';
  @override
  String get networkDiagLoading => 'Analizando interfaces de red...';
  @override
  String networkDiagDesktopReady(int count) =>
      'Listo · $count adaptadores LAN/USB directos detectados';
  @override
  String get networkDiagDesktopWanOnly => 'Canal P2P externo cifrado (sin LAN directa)';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB listo · $count adaptadores detectados';
  @override
  String get networkDiagMobileWanOnly => 'Actual: Canal cifrado externo (WAN)';
  @override
  String get nicDetectionTitle => 'Adaptadores físicos LAN / USB (evade VPN)';
  @override
  String get nicDetectionDesc =>
      'Omite adaptadores TUN virtuales (Clash, Mihomo, WireGuard) y fija sockets en interfaces físicas reales.';
  @override
  String get nicReading => 'Leyendo adaptadores...';
  @override
  String get nicNoneConnected => 'No se encontraron interfaces físicas conectadas';
  @override
  String get btnRefreshNics => 'Actualizar NICs';
  @override
  String get usbProtectionTitle => 'Protección de ruta USB Tether (Windows)';
  @override
  String get usbProtectionDesc =>
      'Al activar "Anclaje USB" en Android, aisla automáticamente la métrica en 5000 para transferencias rápidas por el puerto 42420 sin robar el internet del PC.';
  @override
  String get usbProtectionReady =>
      'Listo: Ruta USB aislada sin secuestro (Metric=5000)';
  @override
  String usbProtectionNeedsFix(String detail) => 'Requiere ajuste: $detail';
  @override
  String get usbProtectionNotPlugged =>
      'Sin cable USB conectado; se protegerá al activar anclaje USB';
  @override
  String get btnFixMetric => 'Corregir métrica';
  @override
  String get customRelayTitle => 'Servidor Relay personalizado (Avanzado)';
  @override
  String get customRelayDesc =>
      'Si falla la conexión directa LAN/WAN, el relé reenvía paquetes cifrados sin poder leer el contenido. Déjalo vacío para usar el relé público gratuito.';
  @override
  String get customRelayLabel => 'URL del servidor Relay (vacío = predeterminado)';
  @override
  String get toastRelaySaved => 'URL de Relay guardada';
  @override
  String get btnSaveRelay => 'Guardar URL Relay';
  @override
  String get deviceIdLabel => 'ID del equipo';
  @override
  String get btnCopyDeviceId => 'Copiar ID completo';
  @override
  String get deviceIdCopiedBadge => 'Copiado';

  @override
  String toastEventStreamError(Object error) => 'Error de flujo de eventos: $error';
  @override
  String toastCreatedRoom(String name) => 'Sala cifrada "$name" creada';
  @override
  String toastCreateRoomFailed(Object error) => 'Error al crear sala: $error';
  @override
  String toastOpenChatFailed(Object error) => 'Error al abrir chat: $error';
  @override
  String toastCreatedGroup(String name) => 'Grupo "$name" creado';
  @override
  String toastCreateGroupFailed(Object error) => 'Error al crear grupo: $error';
  @override
  String toastJoinedRoom(String name) => 'Te uniste a la sala "$name"';
  @override
  String toastAddedDevice(String name) => 'Equipo "$name" añadido';
  @override
  String toastPairFailed(Object error) => 'Error al vincular o unirse: $error';
  @override
  String toastSendTextFailed(Object error) => 'Error al enviar texto: $error';
  @override
  String get toastSelectRoomFirst => 'Selecciona primero un chat o equipo';
  @override
  String toastSendFileFailed(String path, Object error) =>
      'Error al enviar ($path): $error';
  @override
  String get toastForwardFileMissing =>
      'No se puede reenviar: falta el archivo local';
  @override
  String get toastForwardEmptyText =>
      'No se puede reenviar: el texto está vacío';
  @override
  String get fallbackTargetRoom => 'Sala destino';
  @override
  String toastForwardedTo(String targetName) => 'Reenviado a "$targetName"';
  @override
  String toastForwardFailed(Object error) => 'Error al reenviar: $error';
  @override
  String get fallbackBigFile => 'Archivo grande';
  @override
  String toastConfirmedSend(String fileName) => 'Envío confirmado: "$fileName"';
  @override
  String toastConfirmSendFailed(Object error) => 'Error al confirmar envío: $error';
  @override
  String get fallbackFile => 'Archivo';
  @override
  String toastPullingFile(String fileName) => 'Descargando "$fileName"';
  @override
  String toastPullFileFailed(Object error) => 'Error al descargar: $error';
  @override
  String get toastPeerDeleted => 'Equipo vinculado eliminado';
  @override
  String toastDeletePeerFailed(Object error) => 'Error al eliminar equipo: $error';
  @override
  String get toastRoomDeleted => 'Chat eliminado';
  @override
  String toastDeleteRoomFailed(Object error) => 'Error al eliminar chat: $error';
  @override
  String get toastDeletedRecordAndFile => 'Registro y archivo local eliminados';
  @override
  String get toastRemovedLocalRecord => 'Eliminado del historial local';
  @override
  String toastDeleteMsgFailed(Object error) => 'Error al eliminar mensaje: $error';
  @override
  String get toastOnlyRevokeOwn => 'Solo puedes anular tus propios mensajes';
  @override
  String get toastRevokedForAll => 'Mensaje anulado en todos los equipos';
  @override
  String toastRevokeFailed(Object error) => 'Error al anular: $error';
  @override
  String toastInvitedMembers(int count) => '$count equipos invitados al grupo';
  @override
  String toastAddMembersFailed(Object error) => 'Error al añadir miembros: $error';
  @override
  String get toastRemovedMember => 'Equipo quitado del grupo';
  @override
  String toastRemoveMemberFailed(Object error) => 'Error al quitar miembro: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => 'Error de métrica USB: $error';
  @override
  String toastReceiveDirFallback(String dir) => 'Carpeta de recepción: $dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => 'Carpeta actualizada: $dir';
  @override
  String get toastClearedCustomSaveDir =>
      'Carpeta personalizada quitada; se usará la predeterminada';
  @override
  String toastSetDirFailed(Object error) => 'Error al cambiar carpeta: $error';
  @override
  String toastSyncAvatarFailed(Object error) => 'Error al sincronizar avatar: $error';
  @override
  String get toastSelfProfileUpdated =>
      'Perfil actualizado y sincronizado';
  @override
  String get toastPeerRemarkUpdated => 'Alias del equipo actualizado';
  @override
  String get toastRestoredGroupName => 'Nombre del grupo restablecido';
  @override
  String get toastUpdatedGroupName => 'Nombre local del grupo actualizado';
  @override
  String get toastAutoStartEnabled => 'Inicio automático silencioso activado';
  @override
  String get toastAutoStartDisabled => 'Inicio automático desactivado';
  @override
  String get toastCloseToTrayEnabled => 'Cerrar minimizará a la bandeja';
  @override
  String get toastCloseToTrayDisabled => 'Cerrar finalizará la aplicación';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      'Recibido de $sender: $fileName';
  @override
  String get notifyFileFallbackBody => 'Archivo guardado automáticamente';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      'Recibiendo $fileLabel y $totalCount archivos';
  @override
  String notifyNewFileTitle(String sender) => 'Nuevo archivo · $sender';
  @override
  String notifyNewTextTitle(String sender) => 'Nuevo mensaje · $sender';
  @override
  String get notifyNewEncryptedText => 'Nuevo mensaje de texto cifrado';
  @override
  String get errorEmptyImageFile => 'La imagen seleccionada está vacía';
  @override
  String get errorCompressAvatarFailed => 'No se pudo comprimir el avatar';
  @override
  String get errorPngEncodeFailed => 'Error al codificar PNG';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'Sin adaptador USB tethering detectado';
    if (metricProtected) {
      return 'Métrica USB fijada en 5000 para no afectar el internet del PC';
    }
    if (needsElevation) {
      return 'Se requieren permisos de administrador para fijar la métrica USB en 5000';
    }
    return 'Anclaje USB detectado, esperando aislamiento de métrica';
  }

  @override
  String get winTrayTooltip => 'Transferencia Privada P2P · Servicio en segundo plano';
  @override
  String get winTrayOpenWindow => 'Abrir ventana principal';
  @override
  String get winTrayAutoStart => 'Iniciar minimizado con Windows';
  @override
  String get winTrayCloseToTray => 'Minimizar a la bandeja al cerrar';
  @override
  String get winTrayExitApp => 'Salir completamente';
}
