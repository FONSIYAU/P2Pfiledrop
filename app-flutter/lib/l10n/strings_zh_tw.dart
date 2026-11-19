import 'package:intl/intl.dart';

import 'app_strings.dart';

class StringsZhTw extends AppStrings {
  const StringsZhTw();

  @override
  String get localeCode => 'zh_TW';

  @override
  String get appTitle => '文件隨手傳';
  @override
  String get appSubtitle => '端到端加密傳輸';
  @override
  String get startingEngine => '正在啟動 P2P 加密傳輸引擎...';
  @override
  String engineInitFailed(Object error) => '引擎初始化失敗:\n$error';
  @override
  String get retry => '重試';
  @override
  String get cancel => '取消';
  @override
  String get confirm => '確定';
  @override
  String get close => '關閉';
  @override
  String get save => '儲存';
  @override
  String get delete => '刪除';
  @override
  String get remove => '移除';
  @override
  String get open => '開啟';
  @override
  String get refresh => '重新整理';
  @override
  String get clear => '清除';
  @override
  String get resetDefault => '恢復預設';
  @override
  String get recommendedBadge => '推薦';
  @override
  String get defaultAvatarFallback => '裝';

  @override
  String formatFullDate(DateTime dt) => DateFormat('yyyy年M月d日').format(dt);
  @override
  String formatMonthDay(DateTime dt) => DateFormat('MM月dd日').format(dt);
  @override
  String get todayLabel => '今天';
  @override
  String get yesterdayLabel => '昨天';
  @override
  String formatRemainingSeconds(int seconds) => '剩餘 ${seconds}s';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      '剩餘 ${minutes}m${seconds}s';

  @override
  String get navTransfers => '傳輸';
  @override
  String get navDevices => '裝置';
  @override
  String get navThisDevice => '本機';
  @override
  String get navAdd => '新增';
  @override
  String get navFiles => '檔案';
  @override
  String get navFolder => '資料夾';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName（點擊進入「本機」）';
  @override
  String get tooltipScanPair => '掃碼新增裝置 / 加入群組';
  @override
  String get tooltipAllFiles => '檢視全部傳輸檔案與圖片';
  @override
  String tooltipOpenReceiveFolder(String dir) => '開啟接收資料夾 ($dir)';

  @override
  String get transportUsbTether => 'USB 專線';
  @override
  String get transportLanDirect => '區網直連';
  @override
  String get transportWanP2p => '外網 P2P';
  @override
  String get transportWanRelay => '中繼轉發';
  @override
  String get transportOffline => '離線待命';
  @override
  String get usbTetherTag => 'USB專線';

  @override
  String get msgStatusQueuedOffline => '等待對方上線';
  @override
  String get msgStatusHandshaking => '安全交握中';
  @override
  String get msgStatusTransferring => '高速傳輸中';
  @override
  String get msgStatusPausedReconnecting => '斷點續傳恢復中';
  @override
  String get msgStatusAwaitingDownload => '待點擊下載至本機';
  @override
  String get msgStatusDelivered => '已送達';
  @override
  String get msgStatusFailedSourceMissing => '來源檔案已移除';

  @override
  String deviceWithTag(String tag) => '$tag 裝置';
  @override
  String deviceShortIdLabel(String shortId) => '裝置 · $shortId';
  @override
  String get peerDeviceFallback => '對端裝置';
  @override
  String get defaultPersonalRoomName => '個人裝置群組 (Personal)';
  @override
  String get defaultEncryptedGroupName => '新建加密群組';
  @override
  String get defaultPrivateRoomName => '新建私密加密房間';
  @override
  String encryptedRoomWithId(String shortId) => '加密房間 $shortId';
  @override
  String get homeNodeDefaultName => '家庭常駐盲盒節點';

  @override
  String get chatListTitle => '傳輸對話';
  @override
  String get chatListNewActionTooltip => '新建共享組 / 新增裝置';
  @override
  String get menuScanPairOrJoin => '掃碼新增裝置 / 入群';
  @override
  String get menuCreateGroup => '新建多裝置共享組';
  @override
  String get menuMyPairingQr => '我的配對 QR Code';
  @override
  String get menuOpenReceiveFolder => '開啟接收資料夾';
  @override
  String get menuProbeReconnect => '立即探測重連';
  @override
  String get searchChatsHint => '搜尋傳輸紀錄或裝置...';
  @override
  String groupOnlineCount(int online, int total) => '$online/$total 台上線';
  @override
  String groupOfflineCount(int total) => '離線待命 · $total 台裝置';
  @override
  String get emptyChatsSearch => '沒有符合的傳輸對話或裝置';
  @override
  String get emptyChatsNoRooms => '暫無傳輸對話\n新增裝置後即可直接互傳檔案與訊息';
  @override
  String get btnScanPairDevice => '掃碼配對裝置';
  @override
  String get btnGoToDevices => '前往裝置頁發起傳輸';

  @override
  String get devicesListTitle => '裝置列表';
  @override
  String get searchPairedDevicesHint => '搜尋已配對裝置...';
  @override
  String get btnAddNewDevice => '新增裝置';
  @override
  String get btnNewSharedGroup => '新建共享組';
  @override
  String get btnAddDeviceShort => '新增裝置';
  @override
  String get btnNewGroupShort => '新建群組';
  @override
  String pairedDevicesCount(int count) => '已配對裝置 ($count)';
  @override
  String get emptyDevicesSearch => '找不到符合的裝置';
  @override
  String get emptyDevicesNone => '尚無已配對裝置\n點擊上方「新增裝置 / 掃碼配對」開始互聯';
  @override
  String get selectDevicePrompt => '在左側選擇一台裝置檢視詳情或開始傳輸';
  @override
  String get btnScanFirstDevice => '掃碼新增第一台裝置';
  @override
  String originalNameLabel(String name) => '原始名稱：$name';
  @override
  String get deviceNodeIdLabel => '裝置節點 ID';
  @override
  String get tooltipCopyDeviceId => '複製裝置 ID';
  @override
  String get toastCopiedDeviceId => '已複製裝置 ID';
  @override
  String get btnSendMessageOrFile => '傳訊息 / 傳檔案';
  @override
  String get btnEditRemark => '修改備註名稱';
  @override
  String get btnDeleteDevice => '刪除裝置';
  @override
  String get deletePeerDialogTitle => '刪除已配對裝置';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      '確定移除裝置「$resolvedName」？\n\n這會移除該裝置並清空與它的一對一傳輸紀錄，但不會刪除你已經儲存至本機的檔案。';
  @override
  String get btnConfirmDelete => '確認刪除';

  @override
  String get desktopWorkspaceTitle => 'P2P 加密傳輸工作台';
  @override
  String get btnOpenFolder => '開啟資料夾';
  @override
  String get tooltipRoomFiles => '傳輸檔案與圖片';
  @override
  String get tooltipInviteOrScan => '邀請裝置加入 / 掃碼';
  @override
  String get tooltipRoomMembers => '房間成員與管理';
  @override
  String get desktopEmptyTitle => '選擇左側對話開始文字與高速檔案互傳';
  @override
  String get desktopEmptySubtitle => '支援拖入任意檔案、Ctrl+V 直接貼上截圖或檔案、區網/USB 專線直連';
  @override
  String get moreActionsTooltip => '更多操作';
  @override
  String get moreTooltip => '更多';
  @override
  String get emptyRoomNoSession => '暫無對話，先去掃碼配對裝置吧';
  @override
  String get emptyRoomE2eeNotice => '所有文字與檔案皆使用目前房間獨立金鑰端到端加密';
  @override
  String get emptyRoomWindowsHint => '直接拖入檔案或 Ctrl+V 貼上，支援千兆區網 & USB 專線直連';
  @override
  String get emptyRoomMobileHint => '點擊底部 + 傳送檔案，或從系統其他 App「分享」至此房間';
  @override
  String dropZonePrompt(String roomTitle) => '放開滑鼠，加密傳送檔案至「$roomTitle」';
  @override
  String get menuAddPairedToGroup => '加入已配對裝置進組';
  @override
  String get menuDeviceDetailsAndRemark => '裝置詳情與備註';
  @override
  String get menuGroupMembersAndManage => '共享組成員與管理';
  @override
  String get noShareTargetsToast => '尚無可分享的裝置或對話，請先掃碼配對裝置';
  @override
  String get fallbackShortTitle => 'P2P 快傳';

  @override
  String get tooltipGalleryImages => '相簿圖片';
  @override
  String get tooltipSendFile => '傳送檔案';
  @override
  String get tooltipSendImageOrFile => '傳送原圖或檔案';
  @override
  String get tooltipPasteClipboard => '貼上剪貼簿圖片或檔案 (Ctrl+V)';
  @override
  String get inputHintWindows => '輸入文字或貼上，支援拖入檔案';
  @override
  String get inputHintMobile => '輸入文字或貼上...';
  @override
  String get inputHintNoRoom => '請先建立或加入房間';
  @override
  String get tooltipSendMessage => '傳送訊息';

  @override
  String get newMessagesBelowSuffix => '則新訊息';
  @override
  String albumFailedCount(int failedCount) => '有 $failedCount 張傳輸失敗';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      '全部已送達 · $missingCount 張來源檔已移除';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      '全部已送達 · $missingCount 張本機已刪除';
  @override
  String get albumAllDelivered => '全部已送達';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      '正在傳輸 $delivered/$total';
  @override
  String albumImageCount(int count) => '共 $count 張圖片';
  @override
  String get btnExpand => '展開';
  @override
  String collapseImagesCount(int count) => '收合這 $count 張圖片';

  @override
  String get statusLargeFileAwaitConfirm => '大檔案待確認傳送';
  @override
  String get statusGroupFileAwaitDownload => '群大檔案 · 待點擊下載';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      '已傳檔案卡片 ($acked/$total 已下載)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      '大檔案待確認 ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) => '全員已送達 ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) => '已送達 ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => '本機來源檔已移除';
  @override
  String get statusLocalFileDeleted => '本機檔案已刪除';
  @override
  String get revokedByMe => '你收回了此訊息';
  @override
  String get revokedByPeer => '對方收回了此訊息';
  @override
  String get tooltipEditPeerRemark => '點擊修改此裝置備註名稱';
  @override
  String get tooltipPeerAvatar => '對端裝置頭像';
  @override
  String get toastCopiedText => '已複製文字內容';
  @override
  String toastCopiedPath(String path) => '已複製路徑: $path';
  @override
  String get imageDeletedLocally => '圖片已從本機刪除';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) => '$sizeLabel · 原圖來源檔已移除';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · 圖片已從本機刪除（點擊檢視）';
  @override
  String fileSizeSourceMissing(String sizeLabel) => '$sizeLabel · 來源檔案已不在原目錄';
  @override
  String fileSizeFileDeleted(String sizeLabel) => '$sizeLabel · 檔案已從本機刪除';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) => '$sizeLabel · 未當場直傳，待點擊確認傳送';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · 群共享大檔案，點擊下載';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · 已傳檔案卡片，等待群成員下載';
  @override
  String btnDownloadToDevice(String sizeLabel) => '點擊下載至本機 ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => '對方已上線 · 確認立即傳送 ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => '確認排隊傳送（對方上線後自動傳輸）';
  @override
  String get actionCopyText => '複製文字內容';
  @override
  String get actionForward => '轉寄';
  @override
  String get actionOpenFile => '開啟檔案';
  @override
  String get actionRevealInFolder => '在資料夾中顯示';
  @override
  String get actionCopyFilePath => '複製檔案路徑';

  @override
  String get createGroupTitle => '新建多裝置共享組';
  @override
  String get createGroupDesc => '勾選已配對的裝置直接建組（無需重新掃碼），組內共享專屬端到端加密金鑰。';
  @override
  String get groupNameOptionalLabel => '共享組名稱（選填）';
  @override
  String get groupNameAutoHint => '留空將依所選裝置自動產生名稱';
  @override
  String get createGroupNoPeersNotice =>
      '尚無已配對裝置。你可以先建立共享組，稍後再透過右上角 QR Code 掃碼加入裝置。';
  @override
  String selectGroupDevicesCount(int count) => '選擇要加入的裝置（已選 $count 台）：';
  @override
  String get btnCreateGroup => '建立共享組';
  @override
  String get defaultGroupNameFallback => '加密共享組';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => '$joinedNames 共享組';
  @override
  String get nameSeparator => '、';
  @override
  String get addMembersToGroupTitle => '加入已配對裝置進組';
  @override
  String get btnConfirmInvite => '確定邀請';
  @override
  String get allPeersAlreadyInGroupToast => '已配對裝置均已在目前共享組中';
  @override
  String get subtitleDmE2ee => '點對點直連 · 端到端加密';
  @override
  String subtitleGroupE2ee(int count) => '共享組 ($count 台裝置) · 端到端金鑰隔離';
  @override
  String get tooltipEditGroupName => '編輯共享組名稱';
  @override
  String get badgeThisTerminal => '本機終端';
  @override
  String get roleThisDevice => '本機裝置';
  @override
  String get rolePeerDevice => '對端裝置';
  @override
  String get roleGroupMember => '組成員';
  @override
  String get tooltipEditSelfProfile => '修改本機名稱與頭像';
  @override
  String get tooltipRemoveFromGroup => '移出共享組';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      '確定移除裝置「$roomTitle」並清空一對一傳輸紀錄？';
  @override
  String get deleteGroupTitle => '刪除共享組';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      '確定刪除共享組「$roomTitle」並清空本機傳輸紀錄？';
  @override
  String get btnDeleteAndLeave => '刪除並退出';
  @override
  String get btnInviteNewDevice => '邀請新裝置';
  @override
  String get editGroupNameTitle => '編輯共享組名稱';
  @override
  String get localDisplayNameLabel => '本機顯示名稱';
  @override
  String editGroupNameHint(String defaultName) =>
      '僅在本機生效；留空儲存可恢復預設名稱「$defaultName」。';
  @override
  String get editProfileSelfTitle => '修改本機名稱與頭像';
  @override
  String get editProfilePeerTitle => '修改裝置備註名稱';
  @override
  String processImageFailed(Object error) => '處理圖片失敗: $error';
  @override
  String get btnChangeAvatar => '更換頭像圖片';
  @override
  String get btnUploadAvatar => '上傳頭像圖片';
  @override
  String get btnRemoveImage => '移除圖片';
  @override
  String get avatarSyncNoticeSelf => '上傳圖片後將自動加密同步給已配對裝置';
  @override
  String get avatarSyncNoticePeer => '裝置頭像由對方上傳並自動加密同步；此處可修改你本機顯示的備註名稱';
  @override
  String get selfDisplayNameLabel => '本機顯示名稱';
  @override
  String get peerRemarkNameLabel => '裝置備註名稱';
  @override
  String get customDeviceNameHint => '輸入自訂裝置名稱';
  @override
  String defaultNameDisplay(String fallbackModel) => '預設名稱: $fallbackModel';
  @override
  String get shareToTitle => '分享至...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "圖片" : "檔案"}：$name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '共 $count ${allImages ? "張圖片" : "個檔案"} · $size';
  @override
  String shareSummaryText(String text) => '文字：$text';
  @override
  String get sendToTitle => '傳送給';
  @override
  String get targetTypeDm => '直連裝置';
  @override
  String targetTypeGroup(int memberCount) => '共享組 · $memberCount 台裝置';
  @override
  String get targetTypePairedPeer => '已配對裝置（點對點直連）';
  @override
  String get btnReselect => '重選';
  @override
  String btnSendCount(int count) => '傳送 ($count)';
  @override
  String get btnSend => '傳送';
  @override
  String shareFileListMore(int count, String size) => '等共 $count 個檔案 · $size';
  @override
  String shareFileListExact(int count, String size) => '共 $count 個檔案 · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      '${isImage ? "轉寄圖片" : "轉寄檔案"}：$fileName';
  @override
  String forwardSummaryText(String text) => '轉寄訊息：$text';
  @override
  String get forwardToTitle => '轉寄給...';
  @override
  String get searchRoomOrDeviceHint => '搜尋裝置或共享組...';
  @override
  String get noAvailableTargets => '尚無可選對話或已配對裝置';
  @override
  String get noMatchingTargets => '找不到符合的對話或裝置';
  @override
  String get currentConversationLabel => '目前對話';
  @override
  String get tooltipOpenWithDefaultApp => '使用系統預設應用程式開啟';
  @override
  String get tooltipDeleteMessage => '刪除訊息';
  @override
  String get tooltipClosePreview => '關閉預覽';
  @override
  String get deletedImagePreviewTitle => '此圖片已從本機刪除';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '檔案「$fileName」已不在本機目錄中，無法載入原圖預覽。';
  @override
  String get btnDeleteThisRecord => '刪除這筆訊息紀錄';
  @override
  String get removeRevokeNoticeTitle => '移除收回提示';
  @override
  String get removeRevokeNoticeBody => '僅從本機傳輸紀錄中移除這條收回提示？';
  @override
  String get deleteOutgoingFileTitle => '刪除已傳送的檔案/圖片';
  @override
  String get deleteOutgoingTextTitle => '刪除已傳送的訊息';
  @override
  String get chooseDeleteMethod => '請選擇刪除方式：';
  @override
  String get deleteOutgoingFileDetail =>
      '• 從對方裝置收回刪除：通知對方裝置與家庭中繼節點移除，並刪除對方自動儲存的副本。\n• 僅從本機移除紀錄：只清除本機傳輸列表中的紀錄，對方裝置仍會保留內容。\n\n本機傳送資料夾中的原始來源檔不會被刪除或修改。';
  @override
  String get deleteOutgoingTextDetail =>
      '• 從對方裝置收回刪除：通知所有成員及家庭中繼節點移除此訊息。\n• 僅從本機移除紀錄：只清除本機傳輸紀錄，不影響對方裝置。';
  @override
  String get btnRemoveLocalOnly => '僅從本機移除';
  @override
  String get btnRevokeForAll => '同時從對方裝置收回刪除';
  @override
  String get deleteIncomingFileTitle => '刪除收到的檔案';
  @override
  String get deleteIncomingTextTitle => '刪除收到的訊息';
  @override
  String get deleteIncomingNote => '僅從本機刪除，不會影響傳送方裝置上的訊息紀錄。';
  @override
  String get checkboxDeleteLocalFile => '同時刪除本機儲存的檔案';
  @override
  String get incomingFileAlreadyMissing => '本機已不存在該檔案本體，將直接移除此筆失效紀錄。';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      '預覽傳送 ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => '確認傳送 ($count 個檔案)';
  @override
  String get btnAddMore => '繼續新增';
  @override
  String batchLimitNotice(int maxFiles) =>
      '單次最多傳送 $maxFiles 個檔案，已自動保留前 $maxFiles 個。';
  @override
  String get tooltipPrevImage => '上一張';
  @override
  String get tooltipNextImage => '下一張';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '共 $count 項 · $size${showEnterHint ? '（Enter 傳送）' : ''}';

  @override
  String inviteGroupTitle(String roomName) => '邀請裝置入組 · $roomName';
  @override
  String get inviteDeviceTitle => '新增裝置 / 掃碼配對';
  @override
  String get tabGroupInviteQr => '共享組邀請碼';
  @override
  String get tabDevicePairingQr => '本機配對碼';
  @override
  String get tabScanOrPaste => '掃碼 / 貼上加入';
  @override
  String get desktopQrImageUnsupported => '目前桌面端暫不支援圖片 QR Code 辨識，請直接貼上憑證 JSON';
  @override
  String get noQrDetectedInImage => '所選圖片中未辨識到 QR Code，請換一張清晰的圖片重試';
  @override
  String galleryQrScanFailed(Object error) => '辨識相簿 QR Code 失敗: $error';
  @override
  String generateQrFailed(Object error) => '產生 QR Code 憑證失敗: $error';
  @override
  String get joinOrPairFailedHint => '解析或入群失敗，請檢查邀請碼內容是否完整';
  @override
  String groupInviteDesc(String roomName) =>
      '共享組邀請憑證：對方掃碼後將直接加入「$roomName」並同步組內端到端金鑰。';
  @override
  String get devicePairingDesc => '本機配對碼：對方掃碼後將互相關聯為可信裝置，並自動建立點對點加密傳輸通道。';
  @override
  String get toastCopiedQrJson => '已複製配對碼 / 邀請憑證 JSON';
  @override
  String get btnCopyTextTicket => '複製文字憑證';
  @override
  String get btnRetryGenerateQr => '重試產生 QR Code';
  @override
  String get scannerPermDenied => '未取得相機權限，請允許相機權限後重試，或直接從相簿選圖辨識';
  @override
  String get scannerUnsupported => '目前裝置不支援相機掃碼，請從相簿選圖辨識或貼上憑證';
  @override
  String get scannerReinitializing => '相機通道正在切換，請點擊重試開啟相機';
  @override
  String scannerGenericErrorWithDetails(String details) => '相機暫時無法開啟（$details）';
  @override
  String get scannerGenericError => '相機暫時無法開啟，請點擊重試或從相簿選擇 QR Code';
  @override
  String get startingCamera => '正在啟動相機...';
  @override
  String get btnPickQrFromGallery => '從相簿選 QR Code';
  @override
  String get btnRetryCamera => '重試開啟相機';
  @override
  String get pasteTicketDialogTitle => '貼上憑證加入';
  @override
  String get pasteTicketFieldHint => '貼上房間邀請憑證或裝置配對 JSON';
  @override
  String get btnJoinOrRegister => '加入 / 註冊';
  @override
  String get cameraNotSupportedPlatform => '目前平台不支援相機掃碼，請點擊下方「貼上憑證」或從相簿選圖';
  @override
  String get qrViewfinderHint => '將 QR Code 放入框內，即可自動配對或入群';
  @override
  String get analyzingImageQr => '正在辨識圖片 QR Code...';
  @override
  String get verifyingHandshake => '正在驗證交握入群...';
  @override
  String get actionGallery => '相簿';
  @override
  String get actionPasteTicket => '貼上憑證';
  @override
  String get actionTorchOff => '關閉照明';
  @override
  String get actionTorchOn => '手電筒';
  @override
  String get windowsPasteTicketHint =>
      'Windows 端可直接貼上「房間邀請憑證」，掃碼或貼上後即可與同一房間內的裝置直接加密傳輸。';
  @override
  String get btnAnalyzingQr => '正在辨識 QR Code...';
  @override
  String get btnRestartCamera => '重啟相機';
  @override
  String get pasteTicketFieldLabel => '貼上房間邀請憑證或裝置配對 JSON';
  @override
  String get btnJoinToThisDevice => '加入 / 註冊至本機';

  @override
  String get allFilesTitle => '全部檔案';
  @override
  String get roomFilesTitle => '房間檔案';
  @override
  String get tooltipOpenMainReceiveFolder => '開啟總接收資料夾';
  @override
  String get searchFileNameHint => '搜尋檔案名稱...';
  @override
  String get allRoomsOption => '全部房間';
  @override
  String tabImagesCount(int count) => '圖片 ($count)';
  @override
  String tabFilesCount(int count) => '檔案 ($count)';
  @override
  String loadFilesFailed(String error) => '載入檔案列表失敗: $error';
  @override
  String get emptyImagesNone => '暫無收發過的圖片';
  @override
  String get emptyImagesSearch => '沒有符合的圖片';
  @override
  String get emptyFilesNone => '暫無收發過的檔案';
  @override
  String get emptyFilesSearch => '沒有符合的檔案';
  @override
  String get badgeLocallyRemoved => '本機已移除';
  @override
  String get unnamedFile => '未命名檔案';
  @override
  String get toastLocalFileMissing => '本機檔案不存在或已被移動';
  @override
  String get actionOpenShort => '開啟';

  @override
  String get sectionGeneral => '一般';
  @override
  String get sectionReceiveStorage => '接收與儲存';
  @override
  String get sectionResidencyNetwork => '常駐與網路';
  @override
  String get sectionAbout => '關於';
  @override
  String deviceModelLabel(String model) => '裝置型號：$model';
  @override
  String get toastCopiedFullDeviceId => '已複製本機完整 Device ID';
  @override
  String get tooltipEditNameAvatar => '編輯名稱與頭像';
  @override
  String get toastThumbCacheCleared => '已清理縮圖快取';
  @override
  String toastSaveDirUpdated(String dir) => '接收儲存目錄已更新：$dir';
  @override
  String saveDirNotWritable(Object error) => '此目錄無法寫入，請檢查權限或路徑 ($error)';
  @override
  String get needAllFilesPermTitle => '需要檔案存取權限';
  @override
  String get needAllFilesPermBody =>
      '將檔案儲存至你指定的自訂資料夾，需要開啟「所有檔案存取權限」。\n\n開啟後返回本頁面，即可自由選擇手機裡的任意資料夾。';
  @override
  String get btnGoGrant => '前往開啟';
  @override
  String get pickReceiveFolderDialogTitle => '選擇接收檔案儲存資料夾';
  @override
  String storageSizeSuffix(String size, int count) => ' · 已佔 $size ($count 個檔案)';
  @override
  String get storageModeDownloads => '手機「下載」資料夾';
  @override
  String get storageModeDocuments => '手機「文件」資料夾';
  @override
  String get storageModeCustomTitle => '自訂資料夾';
  @override
  String storageModeCustom(String compactPath) => '自訂 ($compactPath)';
  @override
  String get storageModeAppPrivate => '僅儲存在本應用程式內';
  @override
  String get receiveLocationTitle => '接收檔案儲存位置';
  @override
  String get storageDownloadsDesc =>
      'Download/P2PChat · 按月整理，其他應用程式與檔案管理可直接找到，解除安裝不遺失';
  @override
  String get storageDocumentsDesc =>
      'Documents/P2PChat · 單獨歸檔傳輸檔案，不與瀏覽器下載混在一起';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      '已選：$compactPath · 點擊可更換';
  @override
  String get storageCustomUnselectedDesc => '自選手機裡的任意目錄儲存（需開啟檔案存取權限）';
  @override
  String get btnChange => '更換';
  @override
  String get storageAppPrivateTitle => '僅儲存在本應用程式內（私密）';
  @override
  String get storageAppPrivateDesc => '不出現在手機相簿與檔案管理中；注意解除安裝軟體時會一併清除';
  @override
  String get legacyStoragePermNotice => 'Android 9 及以下儲存至系統公共目錄需授予儲存權限';
  @override
  String get btnAuthorize => '前往授權';
  @override
  String get btnChangeFolder => '更換目錄';
  @override
  String get pickReceiveDirDialogTitle => '選擇接收檔案儲存目錄';
  @override
  String get windowsResidencyTitle => 'Windows 桌面無感常駐';
  @override
  String get windowsCloseToTrayTitle => '關閉視窗時最小化至系統匣';
  @override
  String get windowsCloseToTraySubtitle => '點擊右上角 × 後在背景靜默收檔，不結束服務';
  @override
  String get windowsAutoStartTitle => '開機自動背景靜默啟動';
  @override
  String get windowsAutoStartSubtitle => '隨 Windows 登入自動啟動並常駐系統匣，手機隨時傳檔直達';
  @override
  String get btnHideToTrayNow => '立即隱藏至系統匣';
  @override
  String get btnQuitBackgroundService => '徹底結束背景服務';
  @override
  String get themeDialogTitle => '介面外觀主題';
  @override
  String get themeSystemTitle => '跟隨系統';
  @override
  String get themeSystemSubtitle => '自動匹配手機或電腦系統的淺色/深色外觀';
  @override
  String get themeLightTitle => '淺色模式';
  @override
  String get themeLightSubtitle => '始終保持明亮清爽的淺色介面';
  @override
  String get themeDarkTitle => '深色模式';
  @override
  String get themeDarkSubtitle => '夜間更護眼的深色介面';
  @override
  String get themeSystemShort => '跟隨系統';
  @override
  String get themeLightShort => '淺色';
  @override
  String get themeDarkShort => '深色';
  @override
  String get languageDialogTitle => '應用程式語言 (Language)';
  @override
  String get languageSettingTitle => '應用程式語言';
  @override
  String get languageSystemTitle => '跟隨系統';
  @override
  String get languageSystemSubtitle => '自動跟隨裝置的系統語言設定';
  @override
  String toastLanguageUpdated(String langName) => '已切換語言為 $langName';
  @override
  String get storageManagerTitle => '儲存空間與快取管理';
  @override
  String storageRecvStats(String size, int count) => '$size（$count 個檔案）';
  @override
  String get countingStats => '統計中...';
  @override
  String get storageRecvUsedTitle => '接收資料夾已佔空間';
  @override
  String get thumbCacheTitle => '圖片縮圖快取';
  @override
  String thumbCacheDesc(String size) => '$size · 清理不影響已收原圖與檔案';
  @override
  String get btnClearThumbCache => '清理縮圖快取';
  @override
  String get mobileStorageTitle => '儲存空間與快取';
  @override
  String legendReceivedFiles(String size) => '已接收檔案 $size';
  @override
  String legendThumbCache(String size) => '縮圖快取 $size';
  @override
  String receivedFilesCountTitle(int count) => '已接收檔案 ($count 個)';
  @override
  String thumbCacheTitleWithSize(String size) => '圖片縮圖快取 ($size)';
  @override
  String get thumbCacheNoTouchNotice => '清理不影響已收原圖與檔案';
  @override
  String get noCacheToClear => '暫無可清理快取';
  @override
  String btnClearThumbCacheWithSize(String size) => '清理縮圖快取 ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      '接收檔案 $recvSize · 快取 $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => '縮圖快取 $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      '總計 $totalSize · 快取 $cacheSize';
  @override
  String get storageAndCacheTitle => '儲存空間與快取清理';
  @override
  String get aboutTitle => '關於 P2P 私人快傳';
  @override
  String aboutVersion(String version) => '版本：$version';
  @override
  String get aboutBody =>
      '• 端到端加密（E2EE）：每間聊天室獨立金鑰，無中心伺服器儲存或解密你的檔案。\n'
      '• 極速直連：優先區網 / USB 專線直連，自動繞過代理虛擬網卡；跨網時自動點對點穿透或加密中繼。';
  @override
  String get aboutSubtitle => '去中心化 · 端到端加密傳輸';
  @override
  String get networkDiagTitle => '進階網路與連線排錯';
  @override
  String get networkDiagLoading => '正在偵測本機網卡...';
  @override
  String networkDiagDesktopReady(int count) =>
      '已就緒 · 已辨識 $count 張區網/USB 直連網卡（日常無需修改）';
  @override
  String get networkDiagDesktopWanOnly => '目前未連 Wi-Fi / USB，將自動使用外網加密傳輸（日常無需修改）';
  @override
  String networkDiagMobileReady(int count) => '區網 / USB 就緒 · 已辨識 $count 張網卡';
  @override
  String get networkDiagMobileWanOnly => '目前：外網加密通道';
  @override
  String get nicDetectionTitle => '連線重新整理與區網網卡偵測';
  @override
  String get nicDetectionDesc =>
      '兩台裝置同連一個 Wi-Fi 或 USB 共用網路時，即使開啟 VPN/代理，軟體也會繞過虛擬網卡走下方實體網卡直連。剛切換網路後仍顯示離線，可點擊立即探測重連。';
  @override
  String get nicReading => '正在讀取本機網卡...';
  @override
  String get nicNoneConnected => '目前未連接 Wi-Fi 或 USB 共用網路，僅使用行動數據/外網傳輸';
  @override
  String get btnRefreshNics => '重新整理網卡';
  @override
  String get usbProtectionTitle => 'USB 傳輸線高速直連保護';
  @override
  String get usbProtectionDesc =>
      '手機插傳輸線並開啟「USB 網路共用」時可獲得更穩定的高速直連；系統會自動將 USB 網卡設為低上網優先順序（Metric=5000），只傳檔案、不偷跑手機流量。';
  @override
  String get usbProtectionReady => 'USB 專線防搶網已就緒 (Metric=5000 隔離保護中)';
  @override
  String usbProtectionNeedsFix(String detail) => 'USB 共用網卡尚未隔離路由: $detail';
  @override
  String get usbProtectionNotPlugged => '目前未插 USB 共用網線（插入後將自動直連）';
  @override
  String get btnFixMetric => '修復躍點數';
  @override
  String get customRelayTitle => '自訂異地中繼伺服器（Relay · 進階）';
  @override
  String get customRelayDesc =>
      '不在同一區網且外網點對點直連失敗時，檔案會經中繼伺服器加密轉發（端到端加密，伺服器無法查看內容）。一般使用者請留空（預設使用免費公共中繼）；進階使用者可填寫自建 iroh-relay 位址提升異地速度。';
  @override
  String get customRelayLabel => 'Relay 伺服器位址（留空使用預設公共中繼）';
  @override
  String get toastRelaySaved => '已儲存中繼位址設定';
  @override
  String get btnSaveRelay => '儲存中繼位址';
  @override
  String get deviceIdLabel => '裝置 ID';
  @override
  String get btnCopyDeviceId => '複製完整裝置 ID';
  @override
  String get deviceIdCopiedBadge => '已複製';

  @override
  String toastEventStreamError(Object error) => '事件串流異常: $error';
  @override
  String toastCreatedRoom(String name) => '已建立隔離加密房間「$name」';
  @override
  String toastCreateRoomFailed(Object error) => '建立房間失敗: $error';
  @override
  String toastOpenChatFailed(Object error) => '開啟傳輸對話失敗: $error';
  @override
  String toastCreatedGroup(String name) => '已新建共享組「$name」';
  @override
  String toastCreateGroupFailed(Object error) => '新建共享組失敗: $error';
  @override
  String toastJoinedRoom(String name) => '已加入加密房間「$name」';
  @override
  String toastAddedDevice(String name) => '已新增裝置「$name」並建立直連';
  @override
  String toastPairFailed(Object error) => '掃碼/口令解析綁定失敗: $error';
  @override
  String toastSendTextFailed(Object error) => '傳送文字失敗: $error';
  @override
  String get toastSelectRoomFirst => '請先選擇房間並至少綁定一台接收裝置';
  @override
  String toastSendFileFailed(String path, Object error) => '傳送檔案失敗 ($path): $error';
  @override
  String get toastForwardFileMissing => '本機檔案不存在，無法轉寄';
  @override
  String get toastForwardEmptyText => '空訊息無法轉寄';
  @override
  String get fallbackTargetRoom => '目標對話';
  @override
  String toastForwardedTo(String targetName) => '已轉寄至「$targetName」';
  @override
  String toastForwardFailed(Object error) => '轉寄失敗: $error';
  @override
  String get fallbackBigFile => '大檔案';
  @override
  String toastConfirmedSend(String fileName) => '已確認傳送「$fileName」';
  @override
  String toastConfirmSendFailed(Object error) => '確認傳送失敗: $error';
  @override
  String get fallbackFile => '檔案';
  @override
  String toastPullingFile(String fileName) => '正在向傳送方請求拉取「$fileName」...';
  @override
  String toastPullFileFailed(Object error) => '請求下載失敗: $error';
  @override
  String get toastPeerDeleted => '已移除該裝置及其傳輸紀錄';
  @override
  String toastDeletePeerFailed(Object error) => '移除裝置失敗: $error';
  @override
  String get toastRoomDeleted => '已刪除該對話';
  @override
  String toastDeleteRoomFailed(Object error) => '刪除對話失敗: $error';
  @override
  String get toastDeletedRecordAndFile => '已刪除紀錄與本機儲存的檔案';
  @override
  String get toastRemovedLocalRecord => '已從本機傳輸紀錄中移除';
  @override
  String toastDeleteMsgFailed(Object error) => '刪除訊息失敗: $error';
  @override
  String get toastOnlyRevokeOwn => '只能收回自己傳送的訊息';
  @override
  String get toastRevokedForAll => '已收回並通知對方裝置移除';
  @override
  String toastRevokeFailed(Object error) => '收回失敗: $error';
  @override
  String toastInvitedMembers(int count) => '已邀請 $count 台裝置加入共享組';
  @override
  String toastAddMembersFailed(Object error) => '新增共享組成員失敗: $error';
  @override
  String get toastRemovedMember => '已將該裝置移出共享組';
  @override
  String toastRemoveMemberFailed(Object error) => '移出共享組成員失敗: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => '修復 USB 躍點數失敗: $error';
  @override
  String toastReceiveDirFallback(String dir) => '檔案接收目錄：$dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => '自動儲存目錄已更新: $dir';
  @override
  String get toastClearedCustomSaveDir => '已清除自訂儲存目錄設定，重啟或重設後使用預設目錄';
  @override
  String toastSetDirFailed(Object error) => '設定目錄失敗: $error';
  @override
  String toastSyncAvatarFailed(Object error) => '同步本機頭像失敗: $error';
  @override
  String get toastSelfProfileUpdated => '已更新本機資料並同步至線上裝置';
  @override
  String get toastPeerRemarkUpdated => '已更新裝置備註名稱';
  @override
  String get toastRestoredGroupName => '已恢復預設共享組名稱';
  @override
  String get toastUpdatedGroupName => '已更新共享組本機備註名';
  @override
  String get toastAutoStartEnabled => '已開啟開機自動靜默啟動';
  @override
  String get toastAutoStartDisabled => '已關閉開機自啟';
  @override
  String get toastCloseToTrayEnabled => '點擊關閉按鈕將最小化至系統匣';
  @override
  String get toastCloseToTrayDisabled => '點擊關閉按鈕將直接結束程式';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      '收到來自 $sender 的檔案：$fileName';
  @override
  String get notifyFileFallbackBody => '新檔案已自動儲存';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      '$fileLabel 等共 $totalCount 個檔案正在接收';
  @override
  String notifyNewFileTitle(String sender) => '收到新檔案 · $sender';
  @override
  String notifyNewTextTitle(String sender) => '收到新訊息 · $sender';
  @override
  String get notifyNewEncryptedText => '新加密文字訊息';
  @override
  String get errorEmptyImageFile => '選擇的圖片檔案為空';
  @override
  String get errorCompressAvatarFailed => '無法壓縮頭像圖片';
  @override
  String get errorPngEncodeFailed => 'PNG 編碼失敗';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return '未偵測到 USB 共用網卡';
    if (metricProtected) return '已將 USB 網卡躍點數設為 5000，確保不劫持電腦寬頻流量';
    if (needsElevation) return '需要系統管理員權限將 USB 網卡躍點數設為 5000';
    return '偵測到 USB 共用網卡，等待調整路由躍點數';
  }

  @override
  String get winTrayTooltip => 'P2P 私人快傳 · 背景常駐快傳服務';
  @override
  String get winTrayOpenWindow => '開啟主視窗';
  @override
  String get winTrayAutoStart => '開機自動靜默啟動';
  @override
  String get winTrayCloseToTray => '關閉時最小化至系統匣';
  @override
  String get winTrayExitApp => '徹底結束程式';
}
