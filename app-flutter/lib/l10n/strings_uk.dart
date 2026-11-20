import 'app_strings.dart';

class StringsUk extends AppStrings {
  const StringsUk();

  static const _months = <String>[
    'січ',
    'лют',
    'бер',
    'кві',
    'тра',
    'чер',
    'лип',
    'сер',
    'вер',
    'жов',
    'лис',
    'гру',
  ];

  @override
  String get localeCode => 'uk';

  @override
  String get appTitle => 'P2Pfiledrop';
  @override
  String get appSubtitle => 'Наскрізно шифрований обмін';
  @override
  String get startingEngine => 'Запуск шифрованого P2P-рушія...';
  @override
  String engineInitFailed(Object error) => 'Помилка запуску рушія:\n$error';
  @override
  String get retry => 'Повторити';
  @override
  String get cancel => 'Скасувати';
  @override
  String get confirm => 'ОК';
  @override
  String get close => 'Закрити';
  @override
  String get save => 'Зберегти';
  @override
  String get delete => 'Видалити';
  @override
  String get remove => 'Прибрати';
  @override
  String get open => 'Відкрити';
  @override
  String get refresh => 'Оновити';
  @override
  String get clear => 'Очистити';
  @override
  String get resetDefault => 'Скинути';
  @override
  String get recommendedBadge => 'Реком.';
  @override
  String get defaultAvatarFallback => 'П';

  @override
  String formatFullDate(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  @override
  String formatMonthDay(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}';
  @override
  String get todayLabel => 'Сьогодні';
  @override
  String get yesterdayLabel => 'Вчора';
  @override
  String formatRemainingSeconds(int seconds) => 'Зал. $secondsс';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      'Зал. $minutesхв $secondsс';

  @override
  String get navTransfers => 'Чати';
  @override
  String get navDevices => 'Пристрої';
  @override
  String get navThisDevice => 'Я';
  @override
  String get navAdd => 'Додати';
  @override
  String get navFiles => 'Файли';
  @override
  String get navFolder => 'Тека';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName (Налаштування)';
  @override
  String get tooltipScanPair => 'Сканувати QR для зв\'язку / входу';
  @override
  String get tooltipAllFiles => 'Усі передані файли та фото';
  @override
  String tooltipOpenReceiveFolder(String dir) => 'Відкрити теку ($dir)';

  @override
  String get transportUsbTether => 'USB прямий';
  @override
  String get transportLanDirect => 'LAN прямий';
  @override
  String get transportWanP2p => 'Зовн. P2P';
  @override
  String get transportWanRelay => 'Через реле';
  @override
  String get transportOffline => 'Офлайн';
  @override
  String get usbTetherTag => 'USB прямий';

  @override
  String get msgStatusQueuedOffline => 'Очікування мережі';
  @override
  String get msgStatusHandshaking => 'Шифрування';
  @override
  String get msgStatusTransferring => 'Передача';
  @override
  String get msgStatusPausedReconnecting => 'Відновлення';
  @override
  String get msgStatusAwaitingDownload => 'Натисніть для завантаження';
  @override
  String get msgStatusDelivered => 'Доставлено';
  @override
  String get msgStatusFailedSourceMissing => 'Немає джерела';

  @override
  String deviceWithTag(String tag) => 'Пристрій $tag';
  @override
  String deviceShortIdLabel(String shortId) => 'Пристрій · $shortId';
  @override
  String get peerDeviceFallback => 'Віддалений пристрій';
  @override
  String get defaultPersonalRoomName => 'Мої пристрої (Personal)';
  @override
  String get defaultEncryptedGroupName => 'Нова шифр. група';
  @override
  String get defaultPrivateRoomName => 'Новий приватний чат';
  @override
  String encryptedRoomWithId(String shortId) => 'Шифр. чат ($shortId)';
  @override
  String get homeNodeDefaultName => 'Домашній вузол 24/7';

  @override
  String get chatListTitle => 'Чати';
  @override
  String get chatListNewActionTooltip => 'Скан QR / Створити групу';
  @override
  String get menuScanPairOrJoin => 'Скан QR: додати / увійти';
  @override
  String get menuCreateGroup => 'Створити спільну групу';
  @override
  String get menuMyPairingQr => 'Мій QR-код';
  @override
  String get menuOpenReceiveFolder => 'Відкрити теку завантажень';
  @override
  String get menuProbeReconnect => 'Перевірити / Перепідключити';
  @override
  String get searchChatsHint => 'Пошук чатів або пристроїв...';
  @override
  String groupOnlineCount(int online, int total) =>
      'Група ($online/$total онлайн)';
  @override
  String groupOfflineCount(int total) => 'Група ($total · офлайн)';
  @override
  String get emptyChatsSearch => 'Нічого не знайдено';
  @override
  String get emptyChatsNoRooms => 'Активних чатів ще немає';
  @override
  String get btnScanPairDevice => 'Зв\'язати за QR';
  @override
  String get btnGoToDevices => 'До пристроїв';

  @override
  String get devicesListTitle => 'Пристрої';
  @override
  String get searchPairedDevicesHint => 'Пошук зв\'язаних пристроїв...';
  @override
  String get btnAddNewDevice => 'Додати пристрій / QR';
  @override
  String get btnNewSharedGroup => 'Нова спільна група';
  @override
  String get btnAddDeviceShort => 'Додати';
  @override
  String get btnNewGroupShort => 'Група';
  @override
  String pairedDevicesCount(int count) => 'Зв\'язані ($count)';
  @override
  String get emptyDevicesSearch => 'Пристрої не знайдено';
  @override
  String get emptyDevicesNone =>
      'Немає зв\'язаних пристроїв\nНатисніть «Додати пристрій / QR» вгорі';
  @override
  String get selectDevicePrompt => 'Виберіть пристрій ліворуч';
  @override
  String get btnScanFirstDevice => 'Зв\'язати перший пристрій';
  @override
  String originalNameLabel(String name) => 'Модель: $name';
  @override
  String get deviceNodeIdLabel => 'ID вузла (Endpoint ID)';
  @override
  String get tooltipCopyDeviceId => 'Копіювати ID';
  @override
  String get toastCopiedDeviceId => 'ID пристрою скопійовано';
  @override
  String get btnSendMessageOrFile => 'Надіслати текст / файл';
  @override
  String get btnEditRemark => 'Змінити псевдонім';
  @override
  String get btnDeleteDevice => 'Видалити пристрій';
  @override
  String get deletePeerDialogTitle => 'Видалити зв\'язаний пристрій';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      'Вилучити «$resolvedName» з довірених і очистити прямий чат? (Збережені файли залишаться).';
  @override
  String get btnConfirmDelete => 'Видалити';

  @override
  String get desktopWorkspaceTitle => 'Робоча зона обміну';
  @override
  String get btnOpenFolder => 'Тека';
  @override
  String get tooltipRoomFiles => 'Файли та фото чату';
  @override
  String get tooltipInviteOrScan => 'Запросити / Скан QR';
  @override
  String get tooltipRoomMembers => 'Деталі / Учасники групи';
  @override
  String get desktopEmptyTitle => 'Виберіть чат або пристрій ліворуч';
  @override
  String get desktopEmptySubtitle =>
      'Прямий LAN, пріоритет USB-кабелю та шифрований WAN. Перетягніть файли сюди для миттєвої відправки.';
  @override
  String get moreActionsTooltip => 'Ще дії';
  @override
  String get moreTooltip => 'Ще';
  @override
  String get emptyRoomNoSession => 'Немає активного чату. Зв\'яжіть пристрій за QR.';
  @override
  String get emptyRoomE2eeNotice =>
      'Ця кімната захищена наскрізним шифруванням: розшифрувати дані можуть лише учасники.';
  @override
  String get emptyRoomWindowsHint =>
      'Перетягніть сюди файли чи фото або введіть повідомлення нижче.';
  @override
  String get emptyRoomMobileHint =>
      'Натисніть + нижче для вибору фото/файлу або введіть текст.';
  @override
  String dropZonePrompt(String roomTitle) =>
      'Відпустіть для шифр. відправки в «$roomTitle»';
  @override
  String get menuAddPairedToGroup => 'Додати до групи';
  @override
  String get menuDeviceDetailsAndRemark => 'Деталі й псевдонім';
  @override
  String get menuGroupMembersAndManage => 'Учасники та керування';
  @override
  String get noShareTargetsToast => 'Немає доступних чатів або пристроїв';
  @override
  String get fallbackShortTitle => 'P2P Обмін';

  @override
  String get tooltipGalleryImages => 'Фото з галереї';
  @override
  String get tooltipSendFile => 'Обрати файл';
  @override
  String get tooltipSendImageOrFile => 'Надіслати фото або файл';
  @override
  String get tooltipPasteClipboard => 'Вставити фото або текст';
  @override
  String get inputHintWindows =>
      'Повідомлення, вставка або перетягування файлів...';
  @override
  String get inputHintMobile => 'Повідомлення...';
  @override
  String get inputHintNoRoom => 'Спочатку додайте пристрій (+)...';
  @override
  String get tooltipSendMessage => 'Надіслати';

  @override
  String get newMessagesBelowSuffix => 'нових';
  @override
  String albumFailedCount(int failedCount) =>
      'Немає джерела для $failedCount фото';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      'Надіслано ($missingCount оригіналів видалено)';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      'Отримано ($missingCount видалено локально)';
  @override
  String get albumAllDelivered => 'Усе доставлено';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      'Надсилання $delivered/$total';
  @override
  String albumImageCount(int count) => '$count фото';
  @override
  String get btnExpand => 'Відкрити';
  @override
  String collapseImagesCount(int count) => 'Згорнути ($count)';

  @override
  String get statusLargeFileAwaitConfirm => 'Очікує підтвердження';
  @override
  String get statusGroupFileAwaitDownload => 'Готово до завантаження';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      'Сповіщення ($acked/$total)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      'Підтвердити ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      'Доставлено всім ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) =>
      'Доставлено ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => 'Оригінал прибрано';
  @override
  String get statusLocalFileDeleted => 'Файл видалено локально';
  @override
  String get revokedByMe => 'Ви скасували це повідомлення';
  @override
  String get revokedByPeer => 'Співрозмовник скасував повідомлення';
  @override
  String get tooltipEditPeerRemark => 'Змінити псевдонім';
  @override
  String get tooltipPeerAvatar => 'Віддалений пристрій';
  @override
  String get toastCopiedText => 'Текст скопійовано';
  @override
  String toastCopiedPath(String path) => 'Шлях скопійовано: $path';
  @override
  String get imageDeletedLocally => 'Фото видалено локально';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · Оригінальне фото прибрано';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · Фото видалено (докладніше)';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · Джерело відсутнє';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · Видалено локально';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · Підтвердьте великий файл';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · Файл групи доступний';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · Очікування завантаження';
  @override
  String btnDownloadToDevice(String sizeLabel) => 'Завантажити ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => 'Надіслати ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => 'Надіслати, коли з\'явиться в мережі';
  @override
  String get actionCopyText => 'Копіювати текст';
  @override
  String get actionForward => 'Переслати';
  @override
  String get actionOpenFile => 'Відкрити файл';
  @override
  String get actionRevealInFolder => 'Показати в теці';
  @override
  String get actionCopyFilePath => 'Копіювати шлях';

  @override
  String get createGroupTitle => 'Створити шифр. групу';
  @override
  String get createGroupDesc =>
      'Оберіть зв\'язані пристрої, щоб створити групу зі своїм E2EE-ключем (без нового QR).';
  @override
  String get groupNameOptionalLabel => 'Назва (необов\'язково)';
  @override
  String get groupNameAutoHint => 'Порожньо — автоматично з імен';
  @override
  String get createGroupNoPeersNotice =>
      'Ще немає зв\'язаних пристроїв. Створіть групу та запросіть пізніше за QR.';
  @override
  String selectGroupDevicesCount(int count) => 'Вибрано пристроїв: $count';
  @override
  String get btnCreateGroup => 'Створити групу';
  @override
  String get defaultGroupNameFallback => 'Шифрована група';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => 'Група: $joinedNames';
  @override
  String get nameSeparator => ', ';
  @override
  String get addMembersToGroupTitle => 'Додати до групи';
  @override
  String get btnConfirmInvite => 'Запросити';
  @override
  String get allPeersAlreadyInGroupToast =>
      'Усі зв\'язані пристрої вже в цій групі';
  @override
  String get subtitleDmE2ee => 'Прямий P2P · E2EE шифрування';
  @override
  String subtitleGroupE2ee(int count) => 'Група ($count пр.) · Свій ключ';
  @override
  String get tooltipEditGroupName => 'Перейменувати';
  @override
  String get badgeThisTerminal => 'Цей пр.';
  @override
  String get roleThisDevice => 'Цей пристрій (змінюється)';
  @override
  String get rolePeerDevice => 'Віддалений пристрій';
  @override
  String get roleGroupMember => 'Учасник';
  @override
  String get tooltipEditSelfProfile => 'Ім\'я та аватар';
  @override
  String get tooltipRemoveFromGroup => 'Прибрати з групи';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      'Розірвати зв\'язок та видалити «$roomTitle»? (Збережені файли залишаться).';
  @override
  String get deleteGroupTitle => 'Видалити групу';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      'Видалити «$roomTitle» та історію з цього пристрою? (Отримані файли збережуться).';
  @override
  String get btnDeleteAndLeave => 'Видалити й вийти';
  @override
  String get btnInviteNewDevice => 'Запросити / Скан QR';
  @override
  String get editGroupNameTitle => 'Перейменувати групу';
  @override
  String get localDisplayNameLabel => 'Локальна назва';
  @override
  String editGroupNameHint(String defaultName) =>
      'Порожньо для «$defaultName»';
  @override
  String get editProfileSelfTitle => 'Змінити ім\'я та аватар';
  @override
  String get editProfilePeerTitle => 'Змінити псевдонім пристрою';
  @override
  String processImageFailed(Object error) => 'Помилка зображення: $error';
  @override
  String get btnChangeAvatar => 'Змінити аватар';
  @override
  String get btnUploadAvatar => 'Завантажити аватар';
  @override
  String get btnRemoveImage => 'Прибрати фото';
  @override
  String get avatarSyncNoticeSelf =>
      'Аватар шифрується та синхронізується з вашими пристроями';
  @override
  String get avatarSyncNoticePeer =>
      'Псевдонім зберігається локально; аватар задає сам пристрій';
  @override
  String get selfDisplayNameLabel => 'Ім\'я цього пристрою';
  @override
  String get peerRemarkNameLabel => 'Псевдонім пристрою';
  @override
  String get customDeviceNameHint => 'Введіть власне ім\'я';
  @override
  String defaultNameDisplay(String fallbackModel) => 'За замовч.: $fallbackModel';
  @override
  String get shareToTitle => 'Поділитися в...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "Фото" : "Файл"}: $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '$count ${allImages ? "фото" : "файлів"} · $size';
  @override
  String shareSummaryText(String text) => 'Текст: $text';
  @override
  String get sendToTitle => 'Надіслати';
  @override
  String get targetTypeDm => 'Прямий пристрій';
  @override
  String targetTypeGroup(int memberCount) => 'Група · $memberCount пр.';
  @override
  String get targetTypePairedPeer => 'Зв\'язаний (P2P прямий)';
  @override
  String get btnReselect => 'Змінити';
  @override
  String btnSendCount(int count) => 'Надіслати ($count)';
  @override
  String get btnSend => 'Надіслати';
  @override
  String shareFileListMore(int count, String size) =>
      'та ін. (всього $count) · $size';
  @override
  String shareFileListExact(int count, String size) => 'Всього $count · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      'Переслати ${isImage ? "фото" : "файл"}: $fileName';
  @override
  String forwardSummaryText(String text) => 'Переслати: $text';
  @override
  String get forwardToTitle => 'Переслати в...';
  @override
  String get searchRoomOrDeviceHint => 'Пошук чатів і пристроїв...';
  @override
  String get noAvailableTargets => 'Немає доступних чатів або пристроїв';
  @override
  String get noMatchingTargets => 'Немає збігів';
  @override
  String get currentConversationLabel => 'Поточний чат';
  @override
  String get tooltipOpenWithDefaultApp => 'Відкрити типовою програмою';
  @override
  String get tooltipDeleteMessage => 'Видалити повідомлення';
  @override
  String get tooltipClosePreview => 'Закрити';
  @override
  String get deletedImagePreviewTitle => 'Фото видалено локально';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '«$fileName» більше немає на цьому пристрої.';
  @override
  String get btnDeleteThisRecord => 'Видалити запис';
  @override
  String get removeRevokeNoticeTitle => 'Примітка';
  @override
  String get removeRevokeNoticeBody =>
      'Запис можна безпечно прибрати зі своєї історії чату, не зачіпаючи співрозмовника.';
  @override
  String get deleteOutgoingFileTitle => 'Видалити надісланий файл';
  @override
  String get deleteOutgoingTextTitle => 'Видалити повідомлення';
  @override
  String get chooseDeleteMethod => 'Оберіть дію:';
  @override
  String get deleteOutgoingFileDetail =>
      '• Скасувати для всіх: видалить також автозбережені копії в учасників і на релеях.\n• Прибрати лише тут: очистить тільки вашу історію.\n\nВаш початковий файл на диску не видаляється.';
  @override
  String get deleteOutgoingTextDetail =>
      '• Скасувати для всіх: видалить на всіх пристроях і вузлах.\n• Прибрати лише тут: видалить тільки на цьому пристрої.';
  @override
  String get btnRemoveLocalOnly => 'Лише тут';
  @override
  String get btnRevokeForAll => 'Скасувати для всіх';
  @override
  String get deleteIncomingFileTitle => 'Видалити отриманий файл';
  @override
  String get deleteIncomingTextTitle => 'Видалити отримане повідомлення';
  @override
  String get deleteIncomingNote =>
      'Видаляється лише на цьому пристрої, без впливу на відправника.';
  @override
  String get checkboxDeleteLocalFile => 'Видалити також збережений файл';
  @override
  String get incomingFileAlreadyMissing =>
      'Локальний файл вже відсутній; буде прибрано лише запис.';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      'Перегляд ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => 'Підтвердити надсилання ($count)';
  @override
  String get btnAddMore => 'Додати';
  @override
  String batchLimitNotice(int maxFiles) =>
      'Максимум $maxFiles файлів за раз; залишено перші $maxFiles.';
  @override
  String get tooltipPrevImage => 'Назад';
  @override
  String get tooltipNextImage => 'Далі';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '$count шт. · $size${showEnterHint ? ' (Enter — надіслати)' : ''}';

  @override
  String inviteGroupTitle(String roomName) => 'Запросити в «$roomName»';
  @override
  String get inviteDeviceTitle => 'Додати / Скан QR';
  @override
  String get tabGroupInviteQr => 'QR групи';
  @override
  String get tabDevicePairingQr => 'Мій QR-код';
  @override
  String get tabScanOrPaste => 'Скан / Вставити';
  @override
  String get desktopQrImageUnsupported =>
      'Розпізнавання QR із зображення на ПК недоступне. Вставте JSON-тікет напряму.';
  @override
  String get noQrDetectedInImage =>
      'QR-код на зображенні не знайдено. Оберіть чіткіше фото.';
  @override
  String galleryQrScanFailed(Object error) => 'Помилка сканування: $error';
  @override
  String generateQrFailed(Object error) => 'Помилка генерації QR: $error';
  @override
  String get joinOrPairFailedHint =>
      'Помилка підключення. Перевірте цілісність JSON-тікета.';
  @override
  String groupInviteDesc(String roomName) =>
      'QR групи: сканування додає до «$roomName» та передає E2EE-ключ.';
  @override
  String get devicePairingDesc =>
      'Мій QR: зв\'язує пристрої як довірені та відкриває прямий шифр. канал.';
  @override
  String get toastCopiedQrJson => 'JSON-тікет скопійовано';
  @override
  String get btnCopyTextTicket => 'Копіювати тікет';
  @override
  String get btnRetryGenerateQr => 'Повторити QR';
  @override
  String get scannerPermDenied =>
      'Доступ до камери заборонено. Дозвольте камеру або виберіть QR з галереї.';
  @override
  String get scannerUnsupported =>
      'Камера недоступна. Виберіть фото з галереї або вставте тікет.';
  @override
  String get scannerReinitializing =>
      'Скидання камери. Натисніть Повторити за мить.';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      'Помилка камери ($details)';
  @override
  String get scannerGenericError =>
      'Не вдалося запустити камеру. Повторіть або оберіть фото.';
  @override
  String get startingCamera => 'Запуск камери...';
  @override
  String get btnPickQrFromGallery => 'QR з галереї';
  @override
  String get btnRetryCamera => 'Повторити';
  @override
  String get pasteTicketDialogTitle => 'Вставити тікет';
  @override
  String get pasteTicketFieldHint => 'Вставте JSON запрошення чи пари';
  @override
  String get btnJoinOrRegister => 'Увійти / Додати';
  @override
  String get cameraNotSupportedPlatform =>
      'Камера тут не підтримується. Натисніть «Вставити тікет» або оберіть фото.';
  @override
  String get qrViewfinderHint => 'Наведіть рамку на QR-код';
  @override
  String get analyzingImageQr => 'Розпізнавання QR...';
  @override
  String get verifyingHandshake => 'Перевірка шифр. з\'єднання...';
  @override
  String get actionGallery => 'Галерея';
  @override
  String get actionPasteTicket => 'Вставити тікет';
  @override
  String get actionTorchOff => 'Вимк. спалах';
  @override
  String get actionTorchOn => 'Увімк. спалах';
  @override
  String get windowsPasteTicketHint =>
      'У Windows вставте «Тікет запрошення» напряму, щоб увійти до тієї ж шифр. групи.';
  @override
  String get btnAnalyzingQr => 'Аналіз QR...';
  @override
  String get btnRestartCamera => 'Перезапустити камеру';
  @override
  String get pasteTicketFieldLabel => 'Вставте JSON запрошення чи пари';
  @override
  String get btnJoinToThisDevice => 'Увійти / Додати тут';

  @override
  String get allFilesTitle => 'Усі файли';
  @override
  String get roomFilesTitle => 'Файли чату';
  @override
  String get tooltipOpenMainReceiveFolder => 'Відкрити основну теку';
  @override
  String get searchFileNameHint => 'Пошук за назвою файлу...';
  @override
  String get allRoomsOption => 'Усі чати';
  @override
  String tabImagesCount(int count) => 'Фото ($count)';
  @override
  String tabFilesCount(int count) => 'Файли ($count)';
  @override
  String loadFilesFailed(String error) => 'Помилка завантаження: $error';
  @override
  String get emptyImagesNone => 'У цьому чаті ще немає фото';
  @override
  String get emptyImagesSearch => 'Фото не знайдено';
  @override
  String get emptyFilesNone => 'У цьому чаті ще немає файлів';
  @override
  String get emptyFilesSearch => 'Файли не знайдено';
  @override
  String get badgeLocallyRemoved => 'Видалено локально';
  @override
  String get unnamedFile => 'Без назви';
  @override
  String get toastLocalFileMissing => 'Файл переміщено або видалено локально';
  @override
  String get actionOpenShort => 'Відкрити';

  @override
  String get sectionGeneral => 'Загальні';
  @override
  String get sectionReceiveStorage => 'Прийом і пам\'ять';
  @override
  String get sectionResidencyNetwork => 'Фон і мережа';
  @override
  String get sectionAbout => 'Про програму';
  @override
  String deviceModelLabel(String model) => 'Модель: $model';
  @override
  String get toastCopiedFullDeviceId => 'Повний ID скопійовано';
  @override
  String get tooltipEditNameAvatar => 'Ім\'я та аватар';
  @override
  String get toastThumbCacheCleared =>
      'Кеш мініатюр очищено (оригінали збережено)';
  @override
  String toastSaveDirUpdated(String dir) => 'Теку змінено: $dir';
  @override
  String saveDirNotWritable(Object error) => 'Немає прав запису: $error';
  @override
  String get needAllFilesPermTitle => 'Потрібен доступ до всіх файлів';
  @override
  String get needAllFilesPermBody =>
      'Android вимагає дозвіл для прямого запису до публічної теки «Завантаження» (Downloads).';
  @override
  String get btnGoGrant => 'Надати';
  @override
  String get pickReceiveFolderDialogTitle => 'Обрати теку прийому';
  @override
  String storageSizeSuffix(String size, int count) =>
      ' ($size · $count шт.)';
  @override
  String get storageModeDownloads => 'Публічна тека «Завантаження» (Downloads)';
  @override
  String get storageModeDocuments => 'Публічна тека «Документи» (Documents)';
  @override
  String get storageModeCustomTitle => 'Власна тека';
  @override
  String storageModeCustom(String compactPath) => 'Власна ($compactPath)';
  @override
  String get storageModeAppPrivate => 'Приватна тека (Android/data)';
  @override
  String get receiveLocationTitle => 'Місце збереження файлів';
  @override
  String get storageDownloadsDesc =>
      'Легко відкривати з Файлів чи будь-яких додатків';
  @override
  String get storageDocumentsDesc =>
      'Зручно для довгострокового зберігання документів';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      'Поточний шлях: $compactPath';
  @override
  String get storageCustomUnselectedDesc =>
      'Вибрати SD-карту або довільну теку';
  @override
  String get btnChange => 'Змінити';
  @override
  String get storageAppPrivateTitle => 'Приватна тека (видалиться з додатком)';
  @override
  String get storageAppPrivateDesc =>
      'Прихована від галереї й Файлів; зникне при видаленні';
  @override
  String get legacyStoragePermNotice =>
      'Потрібен доступ до пам\'яті для запису в Завантаження';
  @override
  String get btnAuthorize => 'Надати';
  @override
  String get btnChangeFolder => 'Змінити теку';
  @override
  String get pickReceiveDirDialogTitle => 'Тека автозбереження';
  @override
  String get windowsResidencyTitle => 'Трей Windows та автозапуск';
  @override
  String get windowsCloseToTrayTitle => 'Згортати у трей при закритті';
  @override
  String get windowsCloseToTraySubtitle =>
      'Кнопка × ховає вікно у фон для прийому файлів і сповіщень';
  @override
  String get windowsAutoStartTitle => 'Запускати у фоні з Windows';
  @override
  String get windowsAutoStartSubtitle =>
      'Тихий старт у трей під час входу (--minimized)';
  @override
  String get btnHideToTrayNow => 'Згорнути у трей зараз';
  @override
  String get btnQuitBackgroundService => 'Вийти повністю (зі службою)';
  @override
  String get themeDialogTitle => 'Оформлення';
  @override
  String get themeSystemTitle => 'Як у системі';
  @override
  String get themeSystemSubtitle => 'Автоматично під світлу/темну тему ОС';
  @override
  String get themeLightTitle => 'Світла тема';
  @override
  String get themeLightSubtitle => 'Світле тло з м\'ятними акцентами';
  @override
  String get themeDarkTitle => 'Темна тема';
  @override
  String get themeDarkSubtitle => 'Комфортна палітра для ночі';
  @override
  String get themeSystemShort => 'Системна';
  @override
  String get themeLightShort => 'Світла';
  @override
  String get themeDarkShort => 'Темна';
  @override
  String get languageDialogTitle => 'Мова';
  @override
  String get languageSettingTitle => 'Мова';
  @override
  String get languageSystemTitle => 'Мова системи';
  @override
  String get languageSystemSubtitle =>
      'Автоматично підлаштовується під систему';
  @override
  String toastLanguageUpdated(String langName) => 'Мову змінено: $langName';
  @override
  String get storageManagerTitle => 'Пам\'ять і кеш';
  @override
  String storageRecvStats(String size, int count) =>
      'Зайнято $size · $count файлів';
  @override
  String get countingStats => 'Підрахунок...';
  @override
  String get storageRecvUsedTitle => 'Отримані файли';
  @override
  String get thumbCacheTitle => 'Кеш мініатюр';
  @override
  String thumbCacheDesc(String size) =>
      'Зайнято $size · Очищення не чіпає збережені файли';
  @override
  String get btnClearThumbCache => 'Очистити кеш';
  @override
  String get mobileStorageTitle => 'Пам\'ять і кеш';
  @override
  String legendReceivedFiles(String size) => 'Отримано $size';
  @override
  String legendThumbCache(String size) => 'Кеш $size';
  @override
  String receivedFilesCountTitle(int count) => 'Отримані файли ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => 'Кеш мініатюр ($size)';
  @override
  String get thumbCacheNoTouchNotice =>
      'Не видаляє вихідні фото та файли';
  @override
  String get noCacheToClear => 'Кеш порожній';
  @override
  String btnClearThumbCacheWithSize(String size) => 'Очистити кеш ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      'Файли $recvSize · Кеш $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => 'Кеш $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      'Усього $totalSize · Кеш $cacheSize';
  @override
  String get storageAndCacheTitle => 'Пам\'ять і кеш';
  @override
  String get aboutTitle => 'Про P2P Приватний обмін';
  @override
  String aboutVersion(String version) => 'Версія: $version';
  @override
  String get aboutBody =>
      'Кросплатформний P2P-обмін із наскрізним шифруванням без хмари та лімітів.\n\n• Прив\'язка до фіз. NIC: обхід VPN/TUN для повної швидкості LAN\n• Ізольовані ключі кімнат: домашній вузол зберігає лише шифртекст\n• Захист USB-маршруту: запобігає перехопленню інтернету у Windows';
  @override
  String get aboutSubtitle => 'Наскрізно шифрований обмін без серверів';
  @override
  String get networkDiagTitle => 'Мережа та діагностика';
  @override
  String get networkDiagLoading => 'Перевірка мережевих інтерфейсів...';
  @override
  String networkDiagDesktopReady(int count) =>
      'Готово · Знайдено $count прямих LAN/USB адаптерів';
  @override
  String get networkDiagDesktopWanOnly => 'Зовнішній шифрований P2P-канал';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB готовий · Знайдено $count адаптерів';
  @override
  String get networkDiagMobileWanOnly => 'Зараз: Зовнішній шифрований канал';
  @override
  String get nicDetectionTitle => 'Фізичні LAN / USB адаптери (обхід VPN)';
  @override
  String get nicDetectionDesc =>
      'Ігнорує віртуальні TUN (Clash, Mihomo, WireGuard) та прив\'язує сокети до реального обладнання.';
  @override
  String get nicReading => 'Читання інтерфейсів...';
  @override
  String get nicNoneConnected => 'Активних фізичних адаптерів не знайдено';
  @override
  String get btnRefreshNics => 'Оновити';
  @override
  String get usbProtectionTitle => 'Захист маршруту USB-модема (Windows)';
  @override
  String get usbProtectionDesc =>
      'Коли на Android увімкнено USB-модем, метрика стає 5000: швидкий порт 42420 без перехоплення інтернету ПК.';
  @override
  String get usbProtectionReady =>
      'Готово: USB-маршрут ізольовано (Metric=5000)';
  @override
  String usbProtectionNeedsFix(String detail) => 'Потрібна правка: $detail';
  @override
  String get usbProtectionNotPlugged =>
      'USB-модем не підключено; захист спрацює автоматично';
  @override
  String get btnFixMetric => 'Виправити метрику';
  @override
  String get customRelayTitle => 'Власний сервер ретрансляції (Relay)';
  @override
  String get customRelayDesc =>
      'Якщо прямий P2P недоступний, реле пересилає шифровані пакети без доступу до вмісту. Порожньо — публічний реле.';
  @override
  String get customRelayLabel => 'URL реле-сервера (порожньо = типовий)';
  @override
  String get toastRelaySaved => 'URL реле збережено';
  @override
  String get btnSaveRelay => 'Зберегти реле';
  @override
  String get deviceIdLabel => 'ID пристрою';
  @override
  String get btnCopyDeviceId => 'Копіювати повний ID';
  @override
  String get deviceIdCopiedBadge => 'Скопійовано';

  @override
  String toastEventStreamError(Object error) => 'Помилка потоку: $error';
  @override
  String toastCreatedRoom(String name) => 'Кімнату «$name» створено';
  @override
  String toastCreateRoomFailed(Object error) => 'Помилка створення: $error';
  @override
  String toastOpenChatFailed(Object error) => 'Помилка відкриття: $error';
  @override
  String toastCreatedGroup(String name) => 'Групу «$name» створено';
  @override
  String toastCreateGroupFailed(Object error) => 'Помилка групи: $error';
  @override
  String toastJoinedRoom(String name) => 'Ви приєдналися до «$name»';
  @override
  String toastAddedDevice(String name) => 'Пристрій «$name» додано';
  @override
  String toastPairFailed(Object error) => 'Помилка зв\'язування: $error';
  @override
  String toastSendTextFailed(Object error) => 'Помилка надсилання: $error';
  @override
  String get toastSelectRoomFirst => 'Спочатку оберіть чат або пристрій';
  @override
  String toastSendFileFailed(String path, Object error) =>
      'Помилка файлу ($path): $error';
  @override
  String get toastForwardFileMissing => 'Пересилання неможливе: файл відсутній';
  @override
  String get toastForwardEmptyText => 'Пересилання неможливе: порожній текст';
  @override
  String get fallbackTargetRoom => 'Обраний чат';
  @override
  String toastForwardedTo(String targetName) => 'Переслано до «$targetName»';
  @override
  String toastForwardFailed(Object error) => 'Помилка пересилання: $error';
  @override
  String get fallbackBigFile => 'Великий файл';
  @override
  String toastConfirmedSend(String fileName) => 'Надсилання «$fileName» підтверджено';
  @override
  String toastConfirmSendFailed(Object error) => 'Помилка підтвердження: $error';
  @override
  String get fallbackFile => 'Файл';
  @override
  String toastPullingFile(String fileName) => 'Завантаження «$fileName»';
  @override
  String toastPullFileFailed(Object error) => 'Помилка завантаження: $error';
  @override
  String get toastPeerDeleted => 'Пристрій видалено';
  @override
  String toastDeletePeerFailed(Object error) => 'Помилка видалення: $error';
  @override
  String get toastRoomDeleted => 'Чат видалено';
  @override
  String toastDeleteRoomFailed(Object error) => 'Помилка видалення чату: $error';
  @override
  String get toastDeletedRecordAndFile => 'Запис і локальний файл видалено';
  @override
  String get toastRemovedLocalRecord => 'Прибрано з локальної історії';
  @override
  String toastDeleteMsgFailed(Object error) => 'Помилка видалення: $error';
  @override
  String get toastOnlyRevokeOwn => 'Можна скасувати лише власні повідомлення';
  @override
  String get toastRevokedForAll => 'Скасовано на всіх пристроях';
  @override
  String toastRevokeFailed(Object error) => 'Помилка скасування: $error';
  @override
  String toastInvitedMembers(int count) => 'Запрошено пристроїв: $count';
  @override
  String toastAddMembersFailed(Object error) => 'Помилка запрошення: $error';
  @override
  String get toastRemovedMember => 'Пристрій прибрано з групи';
  @override
  String toastRemoveMemberFailed(Object error) => 'Помилка виключення: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => 'Помилка метрики USB: $error';
  @override
  String toastReceiveDirFallback(String dir) => 'Тека прийому: $dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => 'Теку оновлено: $dir';
  @override
  String get toastClearedCustomSaveDir =>
      'Власну теку скинуто; діє типова тека';
  @override
  String toastSetDirFailed(Object error) => 'Помилка зміни теки: $error';
  @override
  String toastSyncAvatarFailed(Object error) => 'Помилка синхронізації аватара: $error';
  @override
  String get toastSelfProfileUpdated => 'Профіль оновлено й синхронізовано';
  @override
  String get toastPeerRemarkUpdated => 'Псевдонім оновлено';
  @override
  String get toastRestoredGroupName => 'Назву групи скинуто';
  @override
  String get toastUpdatedGroupName => 'Локальну назву оновлено';
  @override
  String get toastAutoStartEnabled => 'Тихий автозапуск увімкнено';
  @override
  String get toastAutoStartDisabled => 'Автозапуск вимкнено';
  @override
  String get toastCloseToTrayEnabled => 'Закриття згорне вікно у трей';
  @override
  String get toastCloseToTrayDisabled => 'Закриття завершить програму';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      'Від $sender: $fileName';
  @override
  String get notifyFileFallbackBody => 'Новий файл збережено';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      'Прийом $fileLabel та ін. (усього $totalCount)';
  @override
  String notifyNewFileTitle(String sender) => 'Новий файл · $sender';
  @override
  String notifyNewTextTitle(String sender) => 'Нове повідомлення · $sender';
  @override
  String get notifyNewEncryptedText => 'Нове шифроване повідомлення';
  @override
  String get errorEmptyImageFile => 'Вибраний файл зображення порожній';
  @override
  String get errorCompressAvatarFailed => 'Не вдалося стиснути аватар';
  @override
  String get errorPngEncodeFailed => 'Помилка кодування PNG';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'USB-модем не виявлено';
    if (metricProtected) {
      return 'Метрика USB задана 5000 — інтернет ПК не порушено';
    }
    if (needsElevation) {
      return 'Потрібні права адміністратора для метрики USB = 5000';
    }
    return 'USB-модем знайдено, очікування ізоляції метрики';
  }

  @override
  String get winTrayTooltip => 'P2P Приватний обмін · Фоновий сервіс';
  @override
  String get winTrayOpenWindow => 'Відкрити головне вікно';
  @override
  String get winTrayAutoStart => 'Автозапуск згорнутим у трей';
  @override
  String get winTrayCloseToTray => 'Згортати у трей при закритті';
  @override
  String get winTrayExitApp => 'Повністю вийти';
}
