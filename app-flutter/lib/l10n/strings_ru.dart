import 'app_strings.dart';

class StringsRu extends AppStrings {
  const StringsRu();

  static const _months = <String>[
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  @override
  String get localeCode => 'ru';

  @override
  String get appTitle => 'P2Pfiledrop';
  @override
  String get appSubtitle => 'Сквозное шифрование передачи';
  @override
  String get startingEngine => 'Запуск зашифрованного P2P-движка...';
  @override
  String engineInitFailed(Object error) => 'Ошибка запуска движка:\n$error';
  @override
  String get retry => 'Повторить';
  @override
  String get cancel => 'Отмена';
  @override
  String get confirm => 'ОК';
  @override
  String get close => 'Закрыть';
  @override
  String get save => 'Сохранить';
  @override
  String get delete => 'Удалить';
  @override
  String get remove => 'Убрать';
  @override
  String get open => 'Открыть';
  @override
  String get refresh => 'Обновить';
  @override
  String get clear => 'Очистить';
  @override
  String get resetDefault => 'Сбросить';
  @override
  String get recommendedBadge => 'Реком.';
  @override
  String get defaultAvatarFallback => 'У';

  @override
  String formatFullDate(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  @override
  String formatMonthDay(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}';
  @override
  String get todayLabel => 'Сегодня';
  @override
  String get yesterdayLabel => 'Вчера';
  @override
  String formatRemainingSeconds(int seconds) => 'Ост. $secondsс';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      'Ост. $minutesм $secondsс';

  @override
  String get navTransfers => 'Чаты';
  @override
  String get navDevices => 'Устройства';
  @override
  String get navThisDevice => 'Я';
  @override
  String get navAdd => 'Добавить';
  @override
  String get navFiles => 'Файлы';
  @override
  String get navFolder => 'Папка';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName (Настройки)';
  @override
  String get tooltipScanPair => 'Сканировать QR для связи / входа';
  @override
  String get tooltipAllFiles => 'Все переданные файлы и фото';
  @override
  String tooltipOpenReceiveFolder(String dir) => 'Открыть папку ($dir)';

  @override
  String get transportUsbTether => 'USB прямой';
  @override
  String get transportLanDirect => 'LAN прямой';
  @override
  String get transportWanP2p => 'Внеш. P2P';
  @override
  String get transportWanRelay => 'Через реле';
  @override
  String get transportOffline => 'Офлайн';
  @override
  String get usbTetherTag => 'USB прямой';

  @override
  String get msgStatusQueuedOffline => 'Ожидание сети';
  @override
  String get msgStatusHandshaking => 'Рукопожатие';
  @override
  String get msgStatusTransferring => 'Передача';
  @override
  String get msgStatusPausedReconnecting => 'Возобновление';
  @override
  String get msgStatusAwaitingDownload => 'Нажмите для загрузки';
  @override
  String get msgStatusDelivered => 'Доставлено';
  @override
  String get msgStatusFailedSourceMissing => 'Нет исходника';

  @override
  String deviceWithTag(String tag) => 'Устройство $tag';
  @override
  String deviceShortIdLabel(String shortId) => 'Устройство · $shortId';
  @override
  String get peerDeviceFallback => 'Удалённое устройство';
  @override
  String get defaultPersonalRoomName => 'Мои устройства (Personal)';
  @override
  String get defaultEncryptedGroupName => 'Новая шифр. группа';
  @override
  String get defaultPrivateRoomName => 'Новый приватный чат';
  @override
  String encryptedRoomWithId(String shortId) => 'Шифр. чат ($shortId)';
  @override
  String get homeNodeDefaultName => 'Домашний узел 24/7';

  @override
  String get chatListTitle => 'Чаты';
  @override
  String get chatListNewActionTooltip => 'Сканировать QR / Создать группу';
  @override
  String get menuScanPairOrJoin => 'Скан QR: добавить / войти';
  @override
  String get menuCreateGroup => 'Создать общую группу';
  @override
  String get menuMyPairingQr => 'Мой QR-код';
  @override
  String get menuOpenReceiveFolder => 'Открыть папку загрузки';
  @override
  String get menuProbeReconnect => 'Проверить / Переподключить';
  @override
  String get searchChatsHint => 'Поиск чатов или устройств...';
  @override
  String groupOnlineCount(int online, int total) =>
      'Группа ($online/$total в сети)';
  @override
  String groupOfflineCount(int total) => 'Группа ($total · офлайн)';
  @override
  String get emptyChatsSearch => 'Совпадений не найдено';
  @override
  String get emptyChatsNoRooms => 'Нет активных чатов';
  @override
  String get btnScanPairDevice => 'Связать по QR';
  @override
  String get btnGoToDevices => 'К устройствам';

  @override
  String get devicesListTitle => 'Устройства';
  @override
  String get searchPairedDevicesHint => 'Поиск связанных устройств...';
  @override
  String get btnAddNewDevice => 'Добавить / Скан QR';
  @override
  String get btnNewSharedGroup => 'Новая общая группа';
  @override
  String get btnAddDeviceShort => 'Добавить';
  @override
  String get btnNewGroupShort => 'Группа';
  @override
  String pairedDevicesCount(int count) => 'Связанные ($count)';
  @override
  String get emptyDevicesSearch => 'Устройства не найдены';
  @override
  String get emptyDevicesNone =>
      'Нет связанных устройств\nНажмите «Добавить / Скан QR» выше';
  @override
  String get selectDevicePrompt => 'Выберите устройство слева';
  @override
  String get btnScanFirstDevice => 'Связать первое устройство';
  @override
  String originalNameLabel(String name) => 'Модель: $name';
  @override
  String get deviceNodeIdLabel => 'ID узла (Endpoint ID)';
  @override
  String get tooltipCopyDeviceId => 'Копировать ID';
  @override
  String get toastCopiedDeviceId => 'ID устройства скопирован';
  @override
  String get btnSendMessageOrFile => 'Отправить сообщение / файл';
  @override
  String get btnEditRemark => 'Изменить имя';
  @override
  String get btnDeleteDevice => 'Удалить устройство';
  @override
  String get deletePeerDialogTitle => 'Удалить связанное устройство';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      'Удалить «$resolvedName» из доверенных и очистить прямой чат? (Сохранённые файлы не будут удалены).';
  @override
  String get btnConfirmDelete => 'Удалить';

  @override
  String get desktopWorkspaceTitle => 'Обмен файлами';
  @override
  String get btnOpenFolder => 'Папка';
  @override
  String get tooltipRoomFiles => 'Файлы и фото комнаты';
  @override
  String get tooltipInviteOrScan => 'Пригласить / Скан QR';
  @override
  String get tooltipRoomMembers => 'Инфо / Участники группы';
  @override
  String get desktopEmptyTitle => 'Выберите чат или устройство слева';
  @override
  String get desktopEmptySubtitle =>
      'Прямой LAN, приоритет USB-кабеля и шифрованный WAN. Перетащите файлы сюда для отправки.';
  @override
  String get moreActionsTooltip => 'Ещё действия';
  @override
  String get moreTooltip => 'Ещё';
  @override
  String get emptyRoomNoSession => 'Нет активного чата. Свяжите устройство по QR.';
  @override
  String get emptyRoomE2eeNotice =>
      'Комната защищена сквозным шифрованием: расшифровка возможна только на устройствах участников.';
  @override
  String get emptyRoomWindowsHint =>
      'Перетащите сюда файлы или фото либо напишите сообщение ниже.';
  @override
  String get emptyRoomMobileHint =>
      'Нажмите + ниже для выбора фото/файла или напишите текст.';
  @override
  String dropZonePrompt(String roomTitle) =>
      'Отпустите для шифр. отправки в «$roomTitle»';
  @override
  String get menuAddPairedToGroup => 'Добавить в группу';
  @override
  String get menuDeviceDetailsAndRemark => 'Детали и имя';
  @override
  String get menuGroupMembersAndManage => 'Участники и управление';
  @override
  String get noShareTargetsToast => 'Нет доступных чатов или устройств';
  @override
  String get fallbackShortTitle => 'P2P Обмен';

  @override
  String get tooltipGalleryImages => 'Фото из галереи';
  @override
  String get tooltipSendFile => 'Выбрать файл';
  @override
  String get tooltipSendImageOrFile => 'Отправить фото или файл';
  @override
  String get tooltipPasteClipboard => 'Вставить фото или текст';
  @override
  String get inputHintWindows =>
      'Сообщение, вставка или перетаскивание файлов...';
  @override
  String get inputHintMobile => 'Сообщение...';
  @override
  String get inputHintNoRoom => 'Сначала добавьте устройство (+)...';
  @override
  String get tooltipSendMessage => 'Отправить';

  @override
  String get newMessagesBelowSuffix => 'новых';
  @override
  String albumFailedCount(int failedCount) =>
      'Нет исходника для $failedCount фото';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      'Отправлено ($missingCount оригиналов удалено)';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      'Получено ($missingCount удалены локально)';
  @override
  String get albumAllDelivered => 'Всё доставлено';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      'Отправка $delivered/$total';
  @override
  String albumImageCount(int count) => '$count фото';
  @override
  String get btnExpand => 'Открыть';
  @override
  String collapseImagesCount(int count) => 'Свернуть ($count)';

  @override
  String get statusLargeFileAwaitConfirm => 'Ждёт подтверждения';
  @override
  String get statusGroupFileAwaitDownload => 'Готов к загрузке';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      'Уведомление ($acked/$total)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      'Подтвердить ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      'Доставлено всем ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) =>
      'Доставлено ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => 'Исходник удалён';
  @override
  String get statusLocalFileDeleted => 'Файл удалён локально';
  @override
  String get revokedByMe => 'Вы отменили отправку';
  @override
  String get revokedByPeer => 'Собеседник отменил сообщение';
  @override
  String get tooltipEditPeerRemark => 'Изменить имя';
  @override
  String get tooltipPeerAvatar => 'Удалённое устройство';
  @override
  String get toastCopiedText => 'Текст скопирован';
  @override
  String toastCopiedPath(String path) => 'Путь скопирован: $path';
  @override
  String get imageDeletedLocally => 'Фото удалено локально';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · Исходное фото удалено';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · Фото удалено (подробнее)';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · Исходник не найден';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · Удалено локально';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · Подтвердите крупный файл';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · Файл группы доступен';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · Ожидание скачивания';
  @override
  String btnDownloadToDevice(String sizeLabel) => 'Скачать ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => 'Отправить ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => 'Отправить при входе в сеть';
  @override
  String get actionCopyText => 'Копировать текст';
  @override
  String get actionForward => 'Переслать';
  @override
  String get actionOpenFile => 'Открыть файл';
  @override
  String get actionRevealInFolder => 'Показать в папке';
  @override
  String get actionCopyFilePath => 'Копировать путь';

  @override
  String get createGroupTitle => 'Создать шифр. группу';
  @override
  String get createGroupDesc =>
      'Выберите связанные устройства для создания группы со своим E2EE-ключом (без нового QR).';
  @override
  String get groupNameOptionalLabel => 'Название (необязательно)';
  @override
  String get groupNameAutoHint => 'Пусто — автоподбор по участникам';
  @override
  String get createGroupNoPeersNotice =>
      'Нет связанных устройств. Создайте группу и пригласите позже по QR.';
  @override
  String selectGroupDevicesCount(int count) => 'Выбрано устройств: $count';
  @override
  String get btnCreateGroup => 'Создать группу';
  @override
  String get defaultGroupNameFallback => 'Шифрованная группа';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => 'Группа: $joinedNames';
  @override
  String get nameSeparator => ', ';
  @override
  String get addMembersToGroupTitle => 'Добавить в группу';
  @override
  String get btnConfirmInvite => 'Пригласить';
  @override
  String get allPeersAlreadyInGroupToast =>
      'Все связанные устройства уже в этой группе';
  @override
  String get subtitleDmE2ee => 'Прямой P2P · E2EE шифрование';
  @override
  String subtitleGroupE2ee(int count) => 'Группа ($count устр.) · Свой ключ';
  @override
  String get tooltipEditGroupName => 'Переименовать';
  @override
  String get badgeThisTerminal => 'Это устр.';
  @override
  String get roleThisDevice => 'Это устройство (можно менять)';
  @override
  String get rolePeerDevice => 'Удалённое устройство';
  @override
  String get roleGroupMember => 'Участник';
  @override
  String get tooltipEditSelfProfile => 'Имя и аватар';
  @override
  String get tooltipRemoveFromGroup => 'Убрать из группы';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      'Разорвать связь и удалить «$roomTitle»? (Сохранённые файлы останутся на диске).';
  @override
  String get deleteGroupTitle => 'Удалить группу';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      'Удалить «$roomTitle» и историю с этого устройства? (Полученные файлы не удалятся).';
  @override
  String get btnDeleteAndLeave => 'Удалить и выйти';
  @override
  String get btnInviteNewDevice => 'Пригласить / Скан QR';
  @override
  String get editGroupNameTitle => 'Переименовать группу';
  @override
  String get localDisplayNameLabel => 'Локальное название';
  @override
  String editGroupNameHint(String defaultName) =>
      'Пусто для «$defaultName»';
  @override
  String get editProfileSelfTitle => 'Изменить имя и аватар';
  @override
  String get editProfilePeerTitle => 'Изменить имя устройства';
  @override
  String processImageFailed(Object error) => 'Ошибка изображения: $error';
  @override
  String get btnChangeAvatar => 'Сменить аватар';
  @override
  String get btnUploadAvatar => 'Загрузить аватар';
  @override
  String get btnRemoveImage => 'Удалить фото';
  @override
  String get avatarSyncNoticeSelf =>
      'Аватар шифруется и синхронизируется с вашими устройствами';
  @override
  String get avatarSyncNoticePeer =>
      'Имя сохраняется только здесь; аватар задаётся самим устройством';
  @override
  String get selfDisplayNameLabel => 'Имя этого устройства';
  @override
  String get peerRemarkNameLabel => 'Имя устройства';
  @override
  String get customDeviceNameHint => 'Введите своё название';
  @override
  String defaultNameDisplay(String fallbackModel) => 'По умолчанию: $fallbackModel';
  @override
  String get shareToTitle => 'Поделиться в...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "Фото" : "Файл"}: $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '$count ${allImages ? "фото" : "файлов"} · $size';
  @override
  String shareSummaryText(String text) => 'Текст: $text';
  @override
  String get sendToTitle => 'Отправить';
  @override
  String get targetTypeDm => 'Прямое устройство';
  @override
  String targetTypeGroup(int memberCount) => 'Группа · $memberCount устр.';
  @override
  String get targetTypePairedPeer => 'Связанное (P2P прямой)';
  @override
  String get btnReselect => 'Сменить';
  @override
  String btnSendCount(int count) => 'Отправить ($count)';
  @override
  String get btnSend => 'Отправить';
  @override
  String shareFileListMore(int count, String size) =>
      'и др. (всего $count) · $size';
  @override
  String shareFileListExact(int count, String size) => 'Всего $count · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      'Переслать ${isImage ? "фото" : "файл"}: $fileName';
  @override
  String forwardSummaryText(String text) => 'Переслать: $text';
  @override
  String get forwardToTitle => 'Переслать в...';
  @override
  String get searchRoomOrDeviceHint => 'Поиск чатов и устройств...';
  @override
  String get noAvailableTargets => 'Нет доступных чатов или устройств';
  @override
  String get noMatchingTargets => 'Нет совпадений';
  @override
  String get currentConversationLabel => 'Текущий чат';
  @override
  String get tooltipOpenWithDefaultApp => 'Открыть в приложении';
  @override
  String get tooltipDeleteMessage => 'Удалить сообщение';
  @override
  String get tooltipClosePreview => 'Закрыть';
  @override
  String get deletedImagePreviewTitle => 'Фото удалено локально';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '«$fileName» больше нет на этом устройстве.';
  @override
  String get btnDeleteThisRecord => 'Удалить запись';
  @override
  String get removeRevokeNoticeTitle => 'Примечание';
  @override
  String get removeRevokeNoticeBody =>
      'Запись можно безопасно убрать из истории чата, не затрагивая собеседника.';
  @override
  String get deleteOutgoingFileTitle => 'Удалить отправленный файл';
  @override
  String get deleteOutgoingTextTitle => 'Удалить сообщение';
  @override
  String get chooseDeleteMethod => 'Выберите действие:';
  @override
  String get deleteOutgoingFileDetail =>
      '• Отозвать у всех: удалит также автосохранённые копии на устройствах и релеях.\n• Удалить только здесь: очистит только вашу историю.\n\nВаш исходный файл на диске никогда не удаляется.';
  @override
  String get deleteOutgoingTextDetail =>
      '• Отозвать у всех: удалит у всех участников и в кэше реле.\n• Удалить только здесь: уберёт только с этого устройства.';
  @override
  String get btnRemoveLocalOnly => 'Только здесь';
  @override
  String get btnRevokeForAll => 'Отозвать у всех';
  @override
  String get deleteIncomingFileTitle => 'Удалить полученный файл';
  @override
  String get deleteIncomingTextTitle => 'Удалить полученное сообщение';
  @override
  String get deleteIncomingNote =>
      'Удаляется только на этом устройстве, не затрагивая отправителя.';
  @override
  String get checkboxDeleteLocalFile => 'Удалить также сохранённый файл';
  @override
  String get incomingFileAlreadyMissing =>
      'Локальный файл уже удалён; будет стёрта только запись.';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      'Просмотр ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => 'Подтвердить отправку ($count)';
  @override
  String get btnAddMore => 'Добавить';
  @override
  String batchLimitNotice(int maxFiles) =>
      'Максимум $maxFiles файлов за раз; оставлены первые $maxFiles.';
  @override
  String get tooltipPrevImage => 'Назад';
  @override
  String get tooltipNextImage => 'Вперёд';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '$count шт. · $size${showEnterHint ? ' (Enter — отправить)' : ''}';

  @override
  String inviteGroupTitle(String roomName) => 'Пригласить в «$roomName»';
  @override
  String get inviteDeviceTitle => 'Добавить / Скан QR';
  @override
  String get tabGroupInviteQr => 'QR группы';
  @override
  String get tabDevicePairingQr => 'Мой QR-код';
  @override
  String get tabScanOrPaste => 'Скан / Вставить';
  @override
  String get desktopQrImageUnsupported =>
      'Чтение QR с картинки на ПК недоступно. Вставьте JSON-тикет напрямую.';
  @override
  String get noQrDetectedInImage =>
      'QR-код на изображении не найден. Выберите более чёткое фото.';
  @override
  String galleryQrScanFailed(Object error) => 'Ошибка сканирования: $error';
  @override
  String generateQrFailed(Object error) => 'Ошибка генерации QR: $error';
  @override
  String get joinOrPairFailedHint =>
      'Не удалось подключить. Проверьте полноту JSON-тикета.';
  @override
  String groupInviteDesc(String roomName) =>
      'QR группы: при сканировании устройство входит в «$roomName» и получает E2EE-ключ.';
  @override
  String get devicePairingDesc =>
      'Мой QR: связывает устройства как доверенные и создаёт прямой шифр. канал.';
  @override
  String get toastCopiedQrJson => 'JSON-тикет скопирован';
  @override
  String get btnCopyTextTicket => 'Копировать тикет';
  @override
  String get btnRetryGenerateQr => 'Повторить QR';
  @override
  String get scannerPermDenied =>
      'Нет доступа к камере. Разрешите доступ или выберите QR из галереи.';
  @override
  String get scannerUnsupported =>
      'Камера недоступна. Выберите фото из галереи или вставьте тикет.';
  @override
  String get scannerReinitializing =>
      'Сброс камеры. Нажмите Повторить через секунду.';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      'Ошибка камеры ($details)';
  @override
  String get scannerGenericError =>
      'Не удалось запустить камеру. Повторите или выберите фото.';
  @override
  String get startingCamera => 'Запуск камеры...';
  @override
  String get btnPickQrFromGallery => 'QR из галереи';
  @override
  String get btnRetryCamera => 'Повторить';
  @override
  String get pasteTicketDialogTitle => 'Вставить тикет';
  @override
  String get pasteTicketFieldHint => 'Вставьте JSON приглашения или пары';
  @override
  String get btnJoinOrRegister => 'Войти / Добавить';
  @override
  String get cameraNotSupportedPlatform =>
      'Камера здесь не поддерживается. Нажмите «Вставить тикет» или выберите фото.';
  @override
  String get qrViewfinderHint => 'Наведите рамку на QR-код';
  @override
  String get analyzingImageQr => 'Распознавание QR...';
  @override
  String get verifyingHandshake => 'Проверка шифр. связи...';
  @override
  String get actionGallery => 'Галерея';
  @override
  String get actionPasteTicket => 'Вставить тикет';
  @override
  String get actionTorchOff => 'Выкл. вспышку';
  @override
  String get actionTorchOn => 'Вкл. вспышку';
  @override
  String get windowsPasteTicketHint =>
      'В Windows вставьте сюда «Тикет приглашения», чтобы войти в зашифрованную группу.';
  @override
  String get btnAnalyzingQr => 'Анализ QR...';
  @override
  String get btnRestartCamera => 'Перезапустить камеру';
  @override
  String get pasteTicketFieldLabel => 'Вставьте JSON приглашения или пары';
  @override
  String get btnJoinToThisDevice => 'Войти / Добавить здесь';

  @override
  String get allFilesTitle => 'Все файлы';
  @override
  String get roomFilesTitle => 'Файлы комнаты';
  @override
  String get tooltipOpenMainReceiveFolder => 'Открыть основную папку';
  @override
  String get searchFileNameHint => 'Поиск по имени файла...';
  @override
  String get allRoomsOption => 'Все комнаты';
  @override
  String tabImagesCount(int count) => 'Фото ($count)';
  @override
  String tabFilesCount(int count) => 'Файлы ($count)';
  @override
  String loadFilesFailed(String error) => 'Ошибка загрузки: $error';
  @override
  String get emptyImagesNone => 'В этой комнате пока нет фото';
  @override
  String get emptyImagesSearch => 'Фото не найдены';
  @override
  String get emptyFilesNone => 'В этой комнате пока нет файлов';
  @override
  String get emptyFilesSearch => 'Файлы не найдены';
  @override
  String get badgeLocallyRemoved => 'Удалено локально';
  @override
  String get unnamedFile => 'Без имени';
  @override
  String get toastLocalFileMissing => 'Файл перемещён или удалён локально';
  @override
  String get actionOpenShort => 'Открыть';

  @override
  String get sectionGeneral => 'Основные';
  @override
  String get sectionReceiveStorage => 'Приём и память';
  @override
  String get sectionResidencyNetwork => 'Фон и сеть';
  @override
  String get sectionAbout => 'О программе';
  @override
  String deviceModelLabel(String model) => 'Модель: $model';
  @override
  String get toastCopiedFullDeviceId => 'Полный ID скопирован';
  @override
  String get tooltipEditNameAvatar => 'Имя и аватар';
  @override
  String get toastThumbCacheCleared =>
      'Кэш миниатюр очищен (оригиналы не затронуты)';
  @override
  String toastSaveDirUpdated(String dir) => 'Папка изменена: $dir';
  @override
  String saveDirNotWritable(Object error) => 'Нет прав на запись: $error';
  @override
  String get needAllFilesPermTitle => 'Нужен доступ ко всем файлам';
  @override
  String get needAllFilesPermBody =>
      'Android требует разрешение для прямой записи в общую папку «Загрузки» (Downloads).';
  @override
  String get btnGoGrant => 'Разрешить';
  @override
  String get pickReceiveFolderDialogTitle => 'Выбрать папку приёма';
  @override
  String storageSizeSuffix(String size, int count) =>
      ' ($size · $count шт.)';
  @override
  String get storageModeDownloads => 'Общая папка «Загрузки» (Downloads)';
  @override
  String get storageModeDocuments => 'Общая папка «Документы» (Documents)';
  @override
  String get storageModeCustomTitle => 'Другая папка';
  @override
  String storageModeCustom(String compactPath) => 'Своя ($compactPath)';
  @override
  String get storageModeAppPrivate => 'Папка приложения (Android/data)';
  @override
  String get receiveLocationTitle => 'Папка сохранения файлов';
  @override
  String get storageDownloadsDesc =>
      'Удобно открывать через Проводник и любые приложения';
  @override
  String get storageDocumentsDesc =>
      'Подходит для хранения документов и PDF';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      'Текущий путь: $compactPath';
  @override
  String get storageCustomUnselectedDesc =>
      'Выбрать SD-карту или любую папку';
  @override
  String get btnChange => 'Изменить';
  @override
  String get storageAppPrivateTitle => 'Закрытая папка (удаляется с приложением)';
  @override
  String get storageAppPrivateDesc =>
      'Не видна в галерее и файлах; сотрётся при удалении';
  @override
  String get legacyStoragePermNotice =>
      'Требуется доступ к памяти для сохранения в Загрузки';
  @override
  String get btnAuthorize => 'Разрешить';
  @override
  String get btnChangeFolder => 'Сменить папку';
  @override
  String get pickReceiveDirDialogTitle => 'Папка автосохранения';
  @override
  String get windowsResidencyTitle => 'Трей Windows и автозапуск';
  @override
  String get windowsCloseToTrayTitle => 'Сворачивать в трей при закрытии';
  @override
  String get windowsCloseToTraySubtitle =>
      'Крестик × прячет окно в фон для приёма файлов и уведомлений';
  @override
  String get windowsAutoStartTitle => 'Запускать в фоне с Windows';
  @override
  String get windowsAutoStartSubtitle =>
      'Тихий запуск в системный трей при входе (--minimized)';
  @override
  String get btnHideToTrayNow => 'Свернуть в трей сейчас';
  @override
  String get btnQuitBackgroundService => 'Выйти полностью (со службой)';
  @override
  String get themeDialogTitle => 'Выбор темы';
  @override
  String get themeSystemTitle => 'Как в системе';
  @override
  String get themeSystemSubtitle => 'Автоматически по светлой/тёмной теме ОС';
  @override
  String get themeLightTitle => 'Светлая тема';
  @override
  String get themeLightSubtitle => 'Светлый фон с мягким мятным акцентом';
  @override
  String get themeDarkTitle => 'Тёмная тема';
  @override
  String get themeDarkSubtitle => 'Комфортная палитра для работы ночью';
  @override
  String get themeSystemShort => 'Системная';
  @override
  String get themeLightShort => 'Светлая';
  @override
  String get themeDarkShort => 'Тёмная';
  @override
  String get languageDialogTitle => 'Язык';
  @override
  String get languageSettingTitle => 'Язык';
  @override
  String get languageSystemTitle => 'Язык системы';
  @override
  String get languageSystemSubtitle =>
      'Автоматически следует настройкам устройства';
  @override
  String toastLanguageUpdated(String langName) => 'Язык изменён: $langName';
  @override
  String get storageManagerTitle => 'Память и кэш';
  @override
  String storageRecvStats(String size, int count) =>
      'Занято $size · $count файлов';
  @override
  String get countingStats => 'Подсчёт...';
  @override
  String get storageRecvUsedTitle => 'Полученные файлы';
  @override
  String get thumbCacheTitle => 'Кэш миниатюр';
  @override
  String thumbCacheDesc(String size) =>
      'Занято $size · Очистка не удаляет сохранённые файлы';
  @override
  String get btnClearThumbCache => 'Очистить кэш';
  @override
  String get mobileStorageTitle => 'Память и кэш';
  @override
  String legendReceivedFiles(String size) => 'Получено $size';
  @override
  String legendThumbCache(String size) => 'Кэш $size';
  @override
  String receivedFilesCountTitle(int count) => 'Полученные файлы ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => 'Кэш миниатюр ($size)';
  @override
  String get thumbCacheNoTouchNotice =>
      'Не удаляет исходные фото и файлы';
  @override
  String get noCacheToClear => 'Кэш пуст';
  @override
  String btnClearThumbCacheWithSize(String size) => 'Очистить кэш ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      'Файлы $recvSize · Кэш $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => 'Кэш $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      'Всего $totalSize · Кэш $cacheSize';
  @override
  String get storageAndCacheTitle => 'Память и кэш';
  @override
  String get aboutTitle => 'О P2P Приватном обмене';
  @override
  String aboutVersion(String version) => 'Версия: $version';
  @override
  String get aboutBody =>
      'Кроссплатформенный P2P-обмен со сквозным шифрованием без облака и ограничений.\n\n• Привязка к физ. NIC: обход VPN/TUN для реальной скорости LAN\n• Изолированные ключи комнат: домашний узел хранит только шифртекст\n• Защита USB-маршрута: предотвращает перехват интернета на Windows';
  @override
  String get aboutSubtitle => 'Сквозное шифрование без серверов';
  @override
  String get networkDiagTitle => 'Сеть и диагностика';
  @override
  String get networkDiagLoading => 'Проверка сетевых интерфейсов...';
  @override
  String networkDiagDesktopReady(int count) =>
      'Готово · Найдено $count прямых LAN/USB адаптеров';
  @override
  String get networkDiagDesktopWanOnly => 'Внешний шифрованный P2P-канал';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB готов · Найдено $count адаптеров';
  @override
  String get networkDiagMobileWanOnly => 'Сейчас: Внешний шифрованный канал';
  @override
  String get nicDetectionTitle => 'Физические LAN / USB адаптеры (обход VPN)';
  @override
  String get nicDetectionDesc =>
      'Игнорирует виртуальные TUN (Clash, Mihomo, WireGuard) и привязывает сокеты только к реальным NIC.';
  @override
  String get nicReading => 'Чтение интерфейсов...';
  @override
  String get nicNoneConnected => 'Активных физических адаптеров не найдено';
  @override
  String get btnRefreshNics => 'Обновить';
  @override
  String get usbProtectionTitle => 'Защита маршрута USB-модема (Windows)';
  @override
  String get usbProtectionDesc =>
      'При включении USB-модема на Android метрика ставится в 5000: быстрый порт 42420 без перехвата интернета ПК.';
  @override
  String get usbProtectionReady =>
      'Готово: USB-маршрут изолирован (Metric=5000)';
  @override
  String usbProtectionNeedsFix(String detail) => 'Нужна правка: $detail';
  @override
  String get usbProtectionNotPlugged =>
      'USB-модем не подключён; защита сработает автоматически';
  @override
  String get btnFixMetric => 'Исправить метрику';
  @override
  String get customRelayTitle => 'Свой сервер ретрансляции (Relay)';
  @override
  String get customRelayDesc =>
      'При сбое прямого P2P зашифрованные пакеты идут через реле (содержимое недоступно). Пусто — публичный реле.';
  @override
  String get customRelayLabel => 'URL реле-сервера (пусто = по умолчанию)';
  @override
  String get toastRelaySaved => 'URL реле сохранён';
  @override
  String get btnSaveRelay => 'Сохранить реле';
  @override
  String get deviceIdLabel => 'ID устройства';
  @override
  String get btnCopyDeviceId => 'Копировать полный ID';
  @override
  String get deviceIdCopiedBadge => 'Скопировано';

  @override
  String toastEventStreamError(Object error) => 'Ошибка потока: $error';
  @override
  String toastCreatedRoom(String name) => 'Комната «$name» создана';
  @override
  String toastCreateRoomFailed(Object error) => 'Ошибка создания: $error';
  @override
  String toastOpenChatFailed(Object error) => 'Ошибка открытия: $error';
  @override
  String toastCreatedGroup(String name) => 'Группа «$name» создана';
  @override
  String toastCreateGroupFailed(Object error) => 'Ошибка группы: $error';
  @override
  String toastJoinedRoom(String name) => 'Вы вошли в «$name»';
  @override
  String toastAddedDevice(String name) => 'Устройство «$name» добавлено';
  @override
  String toastPairFailed(Object error) => 'Ошибка связывания: $error';
  @override
  String toastSendTextFailed(Object error) => 'Ошибка отправки: $error';
  @override
  String get toastSelectRoomFirst => 'Сначала выберите чат или устройство';
  @override
  String toastSendFileFailed(String path, Object error) =>
      'Ошибка файла ($path): $error';
  @override
  String get toastForwardFileMissing => 'Пересылка невозможна: файл отсутствует';
  @override
  String get toastForwardEmptyText => 'Пересылка невозможна: пустой текст';
  @override
  String get fallbackTargetRoom => 'Выбранный чат';
  @override
  String toastForwardedTo(String targetName) => 'Переслано в «$targetName»';
  @override
  String toastForwardFailed(Object error) => 'Ошибка пересылки: $error';
  @override
  String get fallbackBigFile => 'Крупный файл';
  @override
  String toastConfirmedSend(String fileName) => 'Отправка «$fileName» подтверждена';
  @override
  String toastConfirmSendFailed(Object error) => 'Ошибка подтверждения: $error';
  @override
  String get fallbackFile => 'Файл';
  @override
  String toastPullingFile(String fileName) => 'Загрузка «$fileName»';
  @override
  String toastPullFileFailed(Object error) => 'Ошибка загрузки: $error';
  @override
  String get toastPeerDeleted => 'Устройство удалено';
  @override
  String toastDeletePeerFailed(Object error) => 'Ошибка удаления: $error';
  @override
  String get toastRoomDeleted => 'Чат удалён';
  @override
  String toastDeleteRoomFailed(Object error) => 'Ошибка удаления чата: $error';
  @override
  String get toastDeletedRecordAndFile => 'Запись и локальный файл удалены';
  @override
  String get toastRemovedLocalRecord => 'Удалено из локальной истории';
  @override
  String toastDeleteMsgFailed(Object error) => 'Ошибка удаления: $error';
  @override
  String get toastOnlyRevokeOwn => 'Можно отозвать только свои сообщения';
  @override
  String get toastRevokedForAll => 'Отозвано на всех устройствах';
  @override
  String toastRevokeFailed(Object error) => 'Ошибка отзыва: $error';
  @override
  String toastInvitedMembers(int count) => 'Приглашено устройств: $count';
  @override
  String toastAddMembersFailed(Object error) => 'Ошибка приглашения: $error';
  @override
  String get toastRemovedMember => 'Устройство убрано из группы';
  @override
  String toastRemoveMemberFailed(Object error) => 'Ошибка исключения: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => 'Ошибка метрики USB: $error';
  @override
  String toastReceiveDirFallback(String dir) => 'Папка приёма: $dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => 'Папка обновлена: $dir';
  @override
  String get toastClearedCustomSaveDir =>
      'Своя папка сброшена; используется стандартная';
  @override
  String toastSetDirFailed(Object error) => 'Ошибка смены папки: $error';
  @override
  String toastSyncAvatarFailed(Object error) => 'Ошибка синхронизации аватара: $error';
  @override
  String get toastSelfProfileUpdated => 'Профиль обновлён и синхронизирован';
  @override
  String get toastPeerRemarkUpdated => 'Имя устройства обновлено';
  @override
  String get toastRestoredGroupName => 'Название группы сброшено';
  @override
  String get toastUpdatedGroupName => 'Локальное название обновлено';
  @override
  String get toastAutoStartEnabled => 'Тихий автозапуск включён';
  @override
  String get toastAutoStartDisabled => 'Автозапуск выключен';
  @override
  String get toastCloseToTrayEnabled => 'Закрытие свернёт окно в трей';
  @override
  String get toastCloseToTrayDisabled => 'Закрытие завершит программу';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      'От $sender: $fileName';
  @override
  String get notifyFileFallbackBody => 'Новый файл сохранён';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      'Приём $fileLabel и др. (всего $totalCount)';
  @override
  String notifyNewFileTitle(String sender) => 'Новый файл · $sender';
  @override
  String notifyNewTextTitle(String sender) => 'Новое сообщение · $sender';
  @override
  String get notifyNewEncryptedText => 'Новое шифрованное сообщение';
  @override
  String get errorEmptyImageFile => 'Выбранный файл пуст';
  @override
  String get errorCompressAvatarFailed => 'Не удалось сжать аватар';
  @override
  String get errorPngEncodeFailed => 'Ошибка кодирования PNG';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'USB-модем не обнаружен';
    if (metricProtected) {
      return 'Метрика USB установлена в 5000 — интернет ПК не затронут';
    }
    if (needsElevation) {
      return 'Нужны права администратора для метрики USB = 5000';
    }
    return 'USB-модем найден, ожидание изоляции метрики';
  }

  @override
  String get winTrayTooltip => 'P2P Приватный обмен · Фоновый сервис';
  @override
  String get winTrayOpenWindow => 'Открыть главное окно';
  @override
  String get winTrayAutoStart => 'Автозапуск в свернутом виде';
  @override
  String get winTrayCloseToTray => 'Сворачивать в трей при закрытии';
  @override
  String get winTrayExitApp => 'Полностью выйти';
}
