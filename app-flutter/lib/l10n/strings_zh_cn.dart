import 'package:intl/intl.dart';

import 'app_strings.dart';

class StringsZhCn extends AppStrings {
  const StringsZhCn();

  @override
  String get localeCode => 'zh_CN';

  @override
  String get appTitle => '文件随手传';
  @override
  String get appSubtitle => '端到端加密传输';
  @override
  String get startingEngine => '正在启动 P2P 加密传输引擎...';
  @override
  String engineInitFailed(Object error) => '引擎初始化失败:\n$error';
  @override
  String get retry => '重试';
  @override
  String get cancel => '取消';
  @override
  String get confirm => '确定';
  @override
  String get close => '关闭';
  @override
  String get save => '保存';
  @override
  String get delete => '删除';
  @override
  String get remove => '移除';
  @override
  String get open => '打开';
  @override
  String get refresh => '刷新';
  @override
  String get clear => '清空';
  @override
  String get resetDefault => '恢复默认';
  @override
  String get recommendedBadge => '推荐';
  @override
  String get defaultAvatarFallback => '设';

  @override
  String formatFullDate(DateTime dt) => DateFormat('yyyy年M月d日').format(dt);
  @override
  String formatMonthDay(DateTime dt) => DateFormat('MM月dd日').format(dt);
  @override
  String get todayLabel => '今天';
  @override
  String get yesterdayLabel => '昨天';
  @override
  String formatRemainingSeconds(int seconds) => '剩余 ${seconds}s';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      '剩余 ${minutes}m${seconds}s';

  @override
  String get navTransfers => '传输';
  @override
  String get navDevices => '设备';
  @override
  String get navThisDevice => '本机';
  @override
  String get navAdd => '添加';
  @override
  String get navFiles => '文件';
  @override
  String get navFolder => '文件夹';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName（点击进入「我的」）';
  @override
  String get tooltipScanPair => '扫码添加设备 / 入组';
  @override
  String get tooltipAllFiles => '查看全部传输文件与图片';
  @override
  String tooltipOpenReceiveFolder(String dir) => '打开接收文件夹 ($dir)';

  @override
  String get transportUsbTether => 'USB 专线';
  @override
  String get transportLanDirect => '局域网直连';
  @override
  String get transportWanP2p => '外网 P2P';
  @override
  String get transportWanRelay => '中继转发';
  @override
  String get transportOffline => '离线待命';
  @override
  String get usbTetherTag => 'USB专线';

  @override
  String get msgStatusQueuedOffline => '等待对端上线';
  @override
  String get msgStatusHandshaking => '安全握手中';
  @override
  String get msgStatusTransferring => '高速传输中';
  @override
  String get msgStatusPausedReconnecting => '断点续传恢复中';
  @override
  String get msgStatusAwaitingDownload => '待点击下载到本地';
  @override
  String get msgStatusDelivered => '已送达';
  @override
  String get msgStatusFailedSourceMissing => '源文件已移除';

  @override
  String deviceWithTag(String tag) => '$tag 设备';
  @override
  String deviceShortIdLabel(String shortId) => '设备 · $shortId';
  @override
  String get peerDeviceFallback => '对端设备';
  @override
  String get defaultPersonalRoomName => '个人设备群 (Personal)';
  @override
  String get defaultEncryptedGroupName => '新建加密群聊';
  @override
  String get defaultPrivateRoomName => '新建私密加密房间';
  @override
  String encryptedRoomWithId(String shortId) => '加密房间 $shortId';
  @override
  String get homeNodeDefaultName => '家庭常驻盲盒节点';

  @override
  String get chatListTitle => '传输会话';
  @override
  String get chatListNewActionTooltip => '新建共享组 / 添加设备';
  @override
  String get menuScanPairOrJoin => '扫码添加设备 / 入群';
  @override
  String get menuCreateGroup => '新建多设备共享组';
  @override
  String get menuMyPairingQr => '我的配对二维码';
  @override
  String get menuOpenReceiveFolder => '打开接收文件夹';
  @override
  String get menuProbeReconnect => '立即探测重连';
  @override
  String get searchChatsHint => '搜索传输记录或设备...';
  @override
  String groupOnlineCount(int online, int total) => '$online/$total 台在线';
  @override
  String groupOfflineCount(int total) => '离线待命 · $total 台设备';
  @override
  String get emptyChatsSearch => '没有匹配的传输会话或设备';
  @override
  String get emptyChatsNoRooms => '暂无传输会话\n添加设备后即可直接互传文件与消息';
  @override
  String get btnScanPairDevice => '扫码配对设备';
  @override
  String get btnGoToDevices => '去设备页发起传输';

  @override
  String get devicesListTitle => '设备列表';
  @override
  String get searchPairedDevicesHint => '搜索已配对设备...';
  @override
  String get btnAddNewDevice => '添加新设备';
  @override
  String get btnNewSharedGroup => '新建共享组';
  @override
  String get btnAddDeviceShort => '添加设备';
  @override
  String get btnNewGroupShort => '新建群组';
  @override
  String pairedDevicesCount(int count) => '已配对设备 ($count)';
  @override
  String get emptyDevicesSearch => '没有找到匹配的设备';
  @override
  String get emptyDevicesNone => '暂无已配对设备\n点击上方「添加新设备 / 扫码配对」开始互联';
  @override
  String get selectDevicePrompt => '在左侧选择一台设备查看详情或开始传输';
  @override
  String get btnScanFirstDevice => '扫码添加第一台设备';
  @override
  String originalNameLabel(String name) => '原始名称：$name';
  @override
  String get deviceNodeIdLabel => '设备节点 ID';
  @override
  String get tooltipCopyDeviceId => '复制设备 ID';
  @override
  String get toastCopiedDeviceId => '已复制设备 ID';
  @override
  String get btnSendMessageOrFile => '发消息 / 传文件';
  @override
  String get btnEditRemark => '修改备注名称';
  @override
  String get btnDeleteDevice => '删除设备';
  @override
  String get deletePeerDialogTitle => '删除已配对设备';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      '确认移除设备「$resolvedName」？\n\n这会移除该设备并清空与它的一对一传输记录，但不会删除你已经保存到本地的文件。';
  @override
  String get btnConfirmDelete => '确认删除';

  @override
  String get desktopWorkspaceTitle => 'P2P 加密传输工作台';
  @override
  String get btnOpenFolder => '打开文件夹';
  @override
  String get tooltipRoomFiles => '传输文件与图片';
  @override
  String get tooltipInviteOrScan => '邀请设备加入 / 扫码';
  @override
  String get tooltipRoomMembers => '房间成员与管理';
  @override
  String get desktopEmptyTitle => '选择左侧会话开始文字与高速文件互传';
  @override
  String get desktopEmptySubtitle => '支持拖入任意文件、Ctrl+V 直接粘贴截图或文件、LAN/USB 专线直连';
  @override
  String get moreActionsTooltip => '更多操作';
  @override
  String get moreTooltip => '更多';
  @override
  String get emptyRoomNoSession => '暂无会话，先去扫码配对设备吧';
  @override
  String get emptyRoomE2eeNotice => '所有文本和文件均使用当前房间独立密钥端到端加密';
  @override
  String get emptyRoomWindowsHint => '直接拖入文件或 Ctrl+V 粘贴，支持千兆局域网 & USB 专线直连';
  @override
  String get emptyRoomMobileHint => '点击底部 + 发送文件，或从系统其它 App「分享」到本房间';
  @override
  String dropZonePrompt(String roomTitle) => '松开鼠标，加密发送文件到「$roomTitle」';
  @override
  String get menuAddPairedToGroup => '添加已配对设备进组';
  @override
  String get menuDeviceDetailsAndRemark => '设备详情与备注';
  @override
  String get menuGroupMembersAndManage => '共享组成员与管理';
  @override
  String get noShareTargetsToast => '暂无可分享的设备或会话，请先扫码配对设备';
  @override
  String get fallbackShortTitle => 'P2P 快传';

  @override
  String get tooltipGalleryImages => '相册图片';
  @override
  String get tooltipSendFile => '发送文件';
  @override
  String get tooltipSendImageOrFile => '发送原图或文件';
  @override
  String get tooltipPasteClipboard => '粘贴剪贴板图片或文件 (Ctrl+V)';
  @override
  String get inputHintWindows => '输入文字或粘贴，支持拖入文件';
  @override
  String get inputHintMobile => '输入文字或粘贴...';
  @override
  String get inputHintNoRoom => '请先创建或加入房间';
  @override
  String get tooltipSendMessage => '发送消息';

  @override
  String get newMessagesBelowSuffix => '条新消息';
  @override
  String albumFailedCount(int failedCount) => '有 $failedCount 张传输失败';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      '全部已送达 · $missingCount 张源文件已移除';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      '全部已送达 · $missingCount 张本地已删除';
  @override
  String get albumAllDelivered => '全部已送达';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      '正在传输 $delivered/$total';
  @override
  String albumImageCount(int count) => '共 $count 张图片';
  @override
  String get btnExpand => '展开';
  @override
  String collapseImagesCount(int count) => '收起这 $count 张图片';

  @override
  String get statusLargeFileAwaitConfirm => '大文件待确认发送';
  @override
  String get statusGroupFileAwaitDownload => '群大文件 · 待点击下载';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      '已发文件卡片 ($acked/$total 已下载)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      '大文件待确认 ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) => '全员已送达 ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) => '已送达 ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => '本地源文件已移除';
  @override
  String get statusLocalFileDeleted => '本地文件已删除';
  @override
  String get revokedByMe => '你撤回了此消息';
  @override
  String get revokedByPeer => '对方撤回了此消息';
  @override
  String get tooltipEditPeerRemark => '点击修改该设备备注名称';
  @override
  String get tooltipPeerAvatar => '对端设备头像';
  @override
  String get toastCopiedText => '已复制文字内容';
  @override
  String toastCopiedPath(String path) => '已复制路径: $path';
  @override
  String get imageDeletedLocally => '图片已从本地删除';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) => '$sizeLabel · 原图源文件已移除';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · 图片已从本地删除（点击查看）';
  @override
  String fileSizeSourceMissing(String sizeLabel) => '$sizeLabel · 源文件已不在原目录';
  @override
  String fileSizeFileDeleted(String sizeLabel) => '$sizeLabel · 文件已从本地删除';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) => '$sizeLabel · 未当场直传，待点击确认发送';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · 群共享大文件，点击下载';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · 已发文件卡片，等待群成员下载';
  @override
  String btnDownloadToDevice(String sizeLabel) => '点击下载到本地 ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => '对端已在线 · 确认立即发送 ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => '确认排队发送（对端上线后自动传输）';
  @override
  String get actionCopyText => '复制文字内容';
  @override
  String get actionForward => '转发';
  @override
  String get actionOpenFile => '打开文件';
  @override
  String get actionRevealInFolder => '在文件夹中显示';
  @override
  String get actionCopyFilePath => '复制文件路径';

  @override
  String get createGroupTitle => '新建多设备共享组';
  @override
  String get createGroupDesc => '勾选已配对的设备直接建组（无需重新扫码），组内共享专属端到端加密密钥。';
  @override
  String get groupNameOptionalLabel => '共享组名称（可选）';
  @override
  String get groupNameAutoHint => '留空自动按所选设备生成名称';
  @override
  String get createGroupNoPeersNotice =>
      '暂无已配对设备。你可以先创建共享组，稍后再通过右上角二维码扫码添加设备入组。';
  @override
  String selectGroupDevicesCount(int count) => '选择要加入的设备（已选 $count 台）：';
  @override
  String get btnCreateGroup => '创建共享组';
  @override
  String get defaultGroupNameFallback => '加密共享组';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => '$joinedNames 共享组';
  @override
  String get nameSeparator => '、';
  @override
  String get addMembersToGroupTitle => '添加已配对设备进组';
  @override
  String get btnConfirmInvite => '确定邀请';
  @override
  String get allPeersAlreadyInGroupToast => '已配对设备均已在当前共享组中';
  @override
  String get subtitleDmE2ee => '点对点直连 · 端到端加密';
  @override
  String subtitleGroupE2ee(int count) => '共享组 ($count 台设备) · 端到端密钥隔离';
  @override
  String get tooltipEditGroupName => '编辑共享组名称';
  @override
  String get badgeThisTerminal => '本机终端';
  @override
  String get roleThisDevice => '本机设备';
  @override
  String get rolePeerDevice => '对端设备';
  @override
  String get roleGroupMember => '组成员';
  @override
  String get tooltipEditSelfProfile => '修改本机名称与头像';
  @override
  String get tooltipRemoveFromGroup => '移出共享组';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      '确认移除设备「$roomTitle」并清空一对一传输记录？';
  @override
  String get deleteGroupTitle => '删除共享组';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      '确认删除共享组「$roomTitle」并清空本机传输记录？';
  @override
  String get btnDeleteAndLeave => '删除并退出';
  @override
  String get btnInviteNewDevice => '邀请新设备';
  @override
  String get editGroupNameTitle => '编辑共享组名称';
  @override
  String get localDisplayNameLabel => '本机显示名称';
  @override
  String editGroupNameHint(String defaultName) =>
      '仅在本机生效；留空保存可恢复默认名称「$defaultName」。';
  @override
  String get editProfileSelfTitle => '修改本机名称与头像';
  @override
  String get editProfilePeerTitle => '修改设备备注名称';
  @override
  String processImageFailed(Object error) => '处理图片失败: $error';
  @override
  String get btnChangeAvatar => '更换头像图片';
  @override
  String get btnUploadAvatar => '上传头像图片';
  @override
  String get btnRemoveImage => '移除图片';
  @override
  String get avatarSyncNoticeSelf => '上传图片后将自动加密同步给已配对设备';
  @override
  String get avatarSyncNoticePeer => '设备头像由对方上传并自动加密同步；此处可修改你本地看到的备注名称';
  @override
  String get selfDisplayNameLabel => '本机显示名称';
  @override
  String get peerRemarkNameLabel => '设备备注名称';
  @override
  String get customDeviceNameHint => '输入自定义设备名称';
  @override
  String defaultNameDisplay(String fallbackModel) => '默认名称: $fallbackModel';
  @override
  String get shareToTitle => '分享到...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "图片" : "文件"}：$name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '共 $count ${allImages ? "张图片" : "个文件"} · $size';
  @override
  String shareSummaryText(String text) => '文本：$text';
  @override
  String get sendToTitle => '发送给';
  @override
  String get targetTypeDm => '直连设备';
  @override
  String targetTypeGroup(int memberCount) => '共享组 · $memberCount 台设备';
  @override
  String get targetTypePairedPeer => '已配对设备（点对点直连）';
  @override
  String get btnReselect => '重选';
  @override
  String btnSendCount(int count) => '发送 ($count)';
  @override
  String get btnSend => '发送';
  @override
  String shareFileListMore(int count, String size) => '等共 $count 个文件 · $size';
  @override
  String shareFileListExact(int count, String size) => '共 $count 个文件 · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      '${isImage ? "转发图片" : "转发文件"}：$fileName';
  @override
  String forwardSummaryText(String text) => '转发消息：$text';
  @override
  String get forwardToTitle => '转发给...';
  @override
  String get searchRoomOrDeviceHint => '搜索设备或共享组...';
  @override
  String get noAvailableTargets => '暂无可选会话或已配对设备';
  @override
  String get noMatchingTargets => '未找到匹配的会话或设备';
  @override
  String get currentConversationLabel => '当前会话';
  @override
  String get tooltipOpenWithDefaultApp => '使用系统默认应用打开';
  @override
  String get tooltipDeleteMessage => '删除消息';
  @override
  String get tooltipClosePreview => '关闭预览';
  @override
  String get deletedImagePreviewTitle => '该图片已从本地删除';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '文件“$fileName”已不在本机目录中，无法加载原图预览。';
  @override
  String get btnDeleteThisRecord => '删除这条消息记录';
  @override
  String get removeRevokeNoticeTitle => '移除撤回提示';
  @override
  String get removeRevokeNoticeBody => '仅从本机传输记录中移除这条撤回提示？';
  @override
  String get deleteOutgoingFileTitle => '删除已发送的文件/图片';
  @override
  String get deleteOutgoingTextTitle => '删除已发送的消息';
  @override
  String get chooseDeleteMethod => '请选择删除方式：';
  @override
  String get deleteOutgoingFileDetail =>
      '• 从对方设备撤回删除：通知对方设备与家庭中转节点移除，并删除对方自动保存的副本。\n• 仅从本机移除记录：只清除本机传输列表中的记录，对方设备保留内容。\n\n本机发送文件夹里的原始源文件不会被删除或改动。';
  @override
  String get deleteOutgoingTextDetail =>
      '• 从对方设备撤回删除：通知所有成员及家庭中转节点移除该消息。\n• 仅从本机移除记录：只清除本机传输记录，不影响对方设备。';
  @override
  String get btnRemoveLocalOnly => '仅从本机移除';
  @override
  String get btnRevokeForAll => '同时从对方设备撤回删除';
  @override
  String get deleteIncomingFileTitle => '删除收到的文件';
  @override
  String get deleteIncomingTextTitle => '删除收到的消息';
  @override
  String get deleteIncomingNote => '仅从本机删除，不会影响发送方设备上的消息记录。';
  @override
  String get checkboxDeleteLocalFile => '同时删除本地保存的文件';
  @override
  String get incomingFileAlreadyMissing => '本地已不存在该文件本体，将直接移除本条失效记录。';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      '预览发送 ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => '确认发送 ($count 个文件)';
  @override
  String get btnAddMore => '继续添加';
  @override
  String batchLimitNotice(int maxFiles) =>
      '单次最多发送 $maxFiles 个文件，已自动保留前 $maxFiles 个。';
  @override
  String get tooltipPrevImage => '上一张';
  @override
  String get tooltipNextImage => '下一张';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '共 $count 项 · $size${showEnterHint ? '（Enter 发送）' : ''}';

  @override
  String inviteGroupTitle(String roomName) => '邀请设备入组 · $roomName';
  @override
  String get inviteDeviceTitle => '添加设备 / 扫码配对';
  @override
  String get tabGroupInviteQr => '共享组邀请码';
  @override
  String get tabDevicePairingQr => '本机配对码';
  @override
  String get tabScanOrPaste => '扫码 / 粘贴加入';
  @override
  String get desktopQrImageUnsupported => '当前桌面端暂不支持图片二维码识别，请直接粘贴凭证 JSON';
  @override
  String get noQrDetectedInImage => '所选图片中未识别到二维码，请换一张清晰的图片重试';
  @override
  String galleryQrScanFailed(Object error) => '识别相册二维码失败: $error';
  @override
  String generateQrFailed(Object error) => '生成二维码凭证失败: $error';
  @override
  String get joinOrPairFailedHint => '解析或入群失败，请检查邀请码内容是否完整';
  @override
  String groupInviteDesc(String roomName) =>
      '共享组邀请凭证：对方扫码后将直接加入「$roomName」并同步组内端到端密钥。';
  @override
  String get devicePairingDesc => '本机配对码：对方扫码后将互相关联为可信设备，并自动建立点对点加密传输通道。';
  @override
  String get toastCopiedQrJson => '已复制配对码 / 邀请凭证 JSON';
  @override
  String get btnCopyTextTicket => '复制文本凭证';
  @override
  String get btnRetryGenerateQr => '重试生成二维码';
  @override
  String get scannerPermDenied => '未获得相机权限，请允许相机权限后重试，或直接从相册选图识别';
  @override
  String get scannerUnsupported => '当前设备不支持相机扫码，请从相册选图识别或粘贴凭证';
  @override
  String get scannerReinitializing => '相机通道正在切换，请点击重试开启相机';
  @override
  String scannerGenericErrorWithDetails(String details) => '相机暂时无法开启（$details）';
  @override
  String get scannerGenericError => '相机暂时无法开启，请点击重试或从相册选二维码';
  @override
  String get startingCamera => '正在启动相机...';
  @override
  String get btnPickQrFromGallery => '从相册选二维码';
  @override
  String get btnRetryCamera => '重试开启相机';
  @override
  String get pasteTicketDialogTitle => '粘贴凭证加入';
  @override
  String get pasteTicketFieldHint => '粘贴房间邀请凭证或设备配对 JSON';
  @override
  String get btnJoinOrRegister => '加入 / 注册';
  @override
  String get cameraNotSupportedPlatform => '当前平台不支持相机扫码，请点击下方「粘贴凭证」或从相册选图';
  @override
  String get qrViewfinderHint => '将二维码放入框内，即可自动配对或入群';
  @override
  String get analyzingImageQr => '正在识别图片二维码...';
  @override
  String get verifyingHandshake => '正在校验握手入群...';
  @override
  String get actionGallery => '相册';
  @override
  String get actionPasteTicket => '粘贴凭证';
  @override
  String get actionTorchOff => '关闭照明';
  @override
  String get actionTorchOn => '手电筒';
  @override
  String get windowsPasteTicketHint =>
      'Windows 端可直接粘贴「房间邀请凭证」，扫码或粘贴后即可与同一房间内的设备直接加密传输。';
  @override
  String get btnAnalyzingQr => '正在识别二维码...';
  @override
  String get btnRestartCamera => '重启相机';
  @override
  String get pasteTicketFieldLabel => '粘贴房间邀请凭证或设备配对 JSON';
  @override
  String get btnJoinToThisDevice => '加入 / 注册到本机';

  @override
  String get allFilesTitle => '全部文件';
  @override
  String get roomFilesTitle => '房间文件';
  @override
  String get tooltipOpenMainReceiveFolder => '打开总接收文件夹';
  @override
  String get searchFileNameHint => '搜索文件名...';
  @override
  String get allRoomsOption => '全部房间';
  @override
  String tabImagesCount(int count) => '图片 ($count)';
  @override
  String tabFilesCount(int count) => '文件 ($count)';
  @override
  String loadFilesFailed(String error) => '加载文件列表失败: $error';
  @override
  String get emptyImagesNone => '暂无收发过的图片';
  @override
  String get emptyImagesSearch => '没有匹配的图片';
  @override
  String get emptyFilesNone => '暂无收发过的文件';
  @override
  String get emptyFilesSearch => '没有匹配的文件';
  @override
  String get badgeLocallyRemoved => '本地已移除';
  @override
  String get unnamedFile => '未命名文件';
  @override
  String get toastLocalFileMissing => '本地文件不存在或已被移动';
  @override
  String get actionOpenShort => '打开';

  @override
  String get sectionGeneral => '通用';
  @override
  String get sectionReceiveStorage => '接收与存储';
  @override
  String get sectionResidencyNetwork => '常驻与网络';
  @override
  String get sectionAbout => '关于';
  @override
  String deviceModelLabel(String model) => '设备型号：$model';
  @override
  String get toastCopiedFullDeviceId => '已复制本机完整 Device ID';
  @override
  String get tooltipEditNameAvatar => '编辑名称与头像';
  @override
  String get toastThumbCacheCleared => '已清理缩略图缓存';
  @override
  String toastSaveDirUpdated(String dir) => '接收保存目录已更新：$dir';
  @override
  String saveDirNotWritable(Object error) => '该目录不可写入，请检查权限或路径 ($error)';
  @override
  String get needAllFilesPermTitle => '需要文件访问权限';
  @override
  String get needAllFilesPermBody =>
      '将文件保存到你指定的自定义文件夹，需要开启「所有文件访问权限」。\n\n开启后返回本页面，即可自由选择手机里的任意文件夹。';
  @override
  String get btnGoGrant => '去开启';
  @override
  String get pickReceiveFolderDialogTitle => '选择接收文件保存文件夹';
  @override
  String storageSizeSuffix(String size, int count) => ' · 已占 $size ($count 个文件)';
  @override
  String get storageModeDownloads => '手机「下载」文件夹';
  @override
  String get storageModeDocuments => '手机「文档」文件夹';
  @override
  String get storageModeCustomTitle => '自定义文件夹';
  @override
  String storageModeCustom(String compactPath) => '自定义 ($compactPath)';
  @override
  String get storageModeAppPrivate => '仅保存在本应用内';
  @override
  String get receiveLocationTitle => '接收文件保存位置';
  @override
  String get storageDownloadsDesc =>
      'Download/P2PChat · 按月整理，其他应用与文件管理可直接找到，卸载不丢';
  @override
  String get storageDocumentsDesc =>
      'Documents/P2PChat · 单独归档传输文件，不与浏览器下载混在一起';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      '已选：$compactPath · 点击可更换';
  @override
  String get storageCustomUnselectedDesc => '自选手机里的任意目录保存（需开启文件访问权限）';
  @override
  String get btnChange => '更换';
  @override
  String get storageAppPrivateTitle => '仅保存在本应用内（私密）';
  @override
  String get storageAppPrivateDesc => '不出现在手机相册和文件管理中；注意卸载软件时会一并清除';
  @override
  String get legacyStoragePermNotice => 'Android 9 及以下保存到系统公共目录需授予存储权限';
  @override
  String get btnAuthorize => '去授权';
  @override
  String get btnChangeFolder => '更换目录';
  @override
  String get pickReceiveDirDialogTitle => '选择接收文件保存目录';
  @override
  String get windowsResidencyTitle => 'Windows 桌面无感常驻';
  @override
  String get windowsCloseToTrayTitle => '关闭窗口时最小化到系统托盘';
  @override
  String get windowsCloseToTraySubtitle => '点击右上角 × 后在后台静默收文件，不退出服务';
  @override
  String get windowsAutoStartTitle => '开机自动后台静默启动';
  @override
  String get windowsAutoStartSubtitle => '随 Windows 登录自动启动并常驻托盘，手机随时发文件直达';
  @override
  String get btnHideToTrayNow => '立即隐藏到托盘';
  @override
  String get btnQuitBackgroundService => '彻底退出后台服务';
  @override
  String get themeDialogTitle => '界面外观主题';
  @override
  String get themeSystemTitle => '跟随系统';
  @override
  String get themeSystemSubtitle => '自动匹配手机或电脑系统的浅色/深色外观';
  @override
  String get themeLightTitle => '浅色模式';
  @override
  String get themeLightSubtitle => '始终保持明亮清爽的浅色界面';
  @override
  String get themeDarkTitle => '深色模式';
  @override
  String get themeDarkSubtitle => '夜间更护眼的深色界面';
  @override
  String get themeSystemShort => '跟随系统';
  @override
  String get themeLightShort => '浅色';
  @override
  String get themeDarkShort => '深色';
  @override
  String get languageDialogTitle => '应用语言 (Language)';
  @override
  String get languageSettingTitle => '应用语言';
  @override
  String get languageSystemTitle => '跟随系统';
  @override
  String get languageSystemSubtitle => '自动跟随设备的系统语言设置';
  @override
  String toastLanguageUpdated(String langName) => '已切换语言为 $langName';
  @override
  String get storageManagerTitle => '存储空间与缓存管理';
  @override
  String storageRecvStats(String size, int count) => '$size（$count 个文件）';
  @override
  String get countingStats => '统计中...';
  @override
  String get storageRecvUsedTitle => '接收文件夹已占空间';
  @override
  String get thumbCacheTitle => '图片缩略图缓存';
  @override
  String thumbCacheDesc(String size) => '$size · 清理不影响已收原图和文件';
  @override
  String get btnClearThumbCache => '清理缩略图缓存';
  @override
  String get mobileStorageTitle => '存储空间与缓存';
  @override
  String legendReceivedFiles(String size) => '已接收文件 $size';
  @override
  String legendThumbCache(String size) => '缩略图缓存 $size';
  @override
  String receivedFilesCountTitle(int count) => '已接收文件 ($count 个)';
  @override
  String thumbCacheTitleWithSize(String size) => '图片缩略图缓存 ($size)';
  @override
  String get thumbCacheNoTouchNotice => '清理不影响已收原图和文件';
  @override
  String get noCacheToClear => '暂无可清理缓存';
  @override
  String btnClearThumbCacheWithSize(String size) => '清理缩略图缓存 ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      '接收文件 $recvSize · 缓存 $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => '缩略图缓存 $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      '总计 $totalSize · 缓存 $cacheSize';
  @override
  String get storageAndCacheTitle => '存储空间与缓存清理';
  @override
  String get aboutTitle => '关于 P2P 私人快传';
  @override
  String aboutVersion(String version) => '版本：$version';
  @override
  String get aboutBody =>
      '• 端到端加密（E2EE）：每间聊天室独立密钥，无中心服务器存储或解密你的文件。\n'
      '• 极速直连：优先局域网 / USB 专线直连，自动绕过代理虚拟网卡；跨网时自动点对点穿透或加密中继。';
  @override
  String get aboutSubtitle => '去中心化 · 端到端加密传输';
  @override
  String get networkDiagTitle => '高级网络与连接排障';
  @override
  String get networkDiagLoading => '正在检测本地网卡...';
  @override
  String networkDiagDesktopReady(int count) =>
      '已就绪 · 已识别 $count 张局域网/USB 直连网卡（日常无需修改）';
  @override
  String get networkDiagDesktopWanOnly => '当前未连 Wi-Fi / USB，将自动使用外网加密传输（日常无需修改）';
  @override
  String networkDiagMobileReady(int count) => '局域网 / USB 就绪 · 已识别 $count 张网卡';
  @override
  String get networkDiagMobileWanOnly => '当前：外网加密通道';
  @override
  String get nicDetectionTitle => '连接刷新与局域网网卡检测';
  @override
  String get nicDetectionDesc =>
      '两台设备同连一个 Wi-Fi 或 USB 共享时，即使开着 VPN/代理，软件也会绕过虚拟网卡走下方物理网卡直连。刚切换网络后仍显示离线，可点击立即探测重连。';
  @override
  String get nicReading => '正在读取本地网卡...';
  @override
  String get nicNoneConnected => '当前未连接 Wi-Fi 或 USB 共享网络，仅使用移动数据/外网传输';
  @override
  String get btnRefreshNics => '刷新网卡';
  @override
  String get usbProtectionTitle => 'USB 数据线高速直连保护';
  @override
  String get usbProtectionDesc =>
      '手机插数据线并开启「USB 网络共享」时可获得更稳定的高速直连；系统会自动将 USB 网卡设为低上网优先级（Metric=5000），只传文件、不偷跑手机流量。';
  @override
  String get usbProtectionReady => 'USB 专线防抢网已就绪 (Metric=5000 隔离保护中)';
  @override
  String usbProtectionNeedsFix(String detail) => 'USB 共享网卡尚未隔离路由: $detail';
  @override
  String get usbProtectionNotPlugged => '当前未插 USB 共享网线（插入后将自动直连）';
  @override
  String get btnFixMetric => '修复跃点数';
  @override
  String get customRelayTitle => '自定义异地中继服务器（Relay · 进阶）';
  @override
  String get customRelayDesc =>
      '不在同一局域网且外网点对点直连失败时，文件会经中继服务器加密转发（端到端加密，服务器无法查看内容）。普通用户请留空（默认使用免费公共中继）；进阶用户可填写自建 iroh-relay 地址提升异地速度。';
  @override
  String get customRelayLabel => 'Relay 服务器地址（留空使用默认公共中继）';
  @override
  String get toastRelaySaved => '已保存中继地址配置';
  @override
  String get btnSaveRelay => '保存中继地址';
  @override
  String get deviceIdLabel => '设备 ID';
  @override
  String get btnCopyDeviceId => '复制完整设备 ID';
  @override
  String get deviceIdCopiedBadge => '已复制';

  @override
  String toastEventStreamError(Object error) => '事件流异常: $error';
  @override
  String toastCreatedRoom(String name) => '已创建隔离加密房间「$name」';
  @override
  String toastCreateRoomFailed(Object error) => '创建房间失败: $error';
  @override
  String toastOpenChatFailed(Object error) => '打开传输会话失败: $error';
  @override
  String toastCreatedGroup(String name) => '已新建共享组「$name」';
  @override
  String toastCreateGroupFailed(Object error) => '新建共享组失败: $error';
  @override
  String toastJoinedRoom(String name) => '已加入加密房间「$name」';
  @override
  String toastAddedDevice(String name) => '已添加设备「$name」并建立直连';
  @override
  String toastPairFailed(Object error) => '扫码/口令解析绑定失败: $error';
  @override
  String toastSendTextFailed(Object error) => '发送文本失败: $error';
  @override
  String get toastSelectRoomFirst => '请先选择房间并至少绑定一台接收设备';
  @override
  String toastSendFileFailed(String path, Object error) => '发送文件失败 ($path): $error';
  @override
  String get toastForwardFileMissing => '本地文件不存在，无法转发';
  @override
  String get toastForwardEmptyText => '空消息无法转发';
  @override
  String get fallbackTargetRoom => '目标会话';
  @override
  String toastForwardedTo(String targetName) => '已转发到「$targetName」';
  @override
  String toastForwardFailed(Object error) => '转发失败: $error';
  @override
  String get fallbackBigFile => '大文件';
  @override
  String toastConfirmedSend(String fileName) => '已确认发送「$fileName」';
  @override
  String toastConfirmSendFailed(Object error) => '确认发送失败: $error';
  @override
  String get fallbackFile => '文件';
  @override
  String toastPullingFile(String fileName) => '正在向发送方请求拉取「$fileName」...';
  @override
  String toastPullFileFailed(Object error) => '请求下载失败: $error';
  @override
  String get toastPeerDeleted => '已移除该设备及其传输记录';
  @override
  String toastDeletePeerFailed(Object error) => '移除设备失败: $error';
  @override
  String get toastRoomDeleted => '已删除该会话';
  @override
  String toastDeleteRoomFailed(Object error) => '删除会话失败: $error';
  @override
  String get toastDeletedRecordAndFile => '已删除记录和本地保存的文件';
  @override
  String get toastRemovedLocalRecord => '已从本机传输记录中移除';
  @override
  String toastDeleteMsgFailed(Object error) => '删除消息失败: $error';
  @override
  String get toastOnlyRevokeOwn => '只能撤回自己发送的消息';
  @override
  String get toastRevokedForAll => '已撤回并通知对方设备移除';
  @override
  String toastRevokeFailed(Object error) => '撤回失败: $error';
  @override
  String toastInvitedMembers(int count) => '已邀请 $count 台设备加入共享组';
  @override
  String toastAddMembersFailed(Object error) => '添加共享组成员失败: $error';
  @override
  String get toastRemovedMember => '已将该设备移出共享组';
  @override
  String toastRemoveMemberFailed(Object error) => '移出共享组成员失败: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => '修复 USB 跃点数失败: $error';
  @override
  String toastReceiveDirFallback(String dir) => '文件接收目录：$dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => '自动保存目录已更新: $dir';
  @override
  String get toastClearedCustomSaveDir => '已清空自定义保存目录设置，重启或重设后使用默认目录';
  @override
  String toastSetDirFailed(Object error) => '设置目录失败: $error';
  @override
  String toastSyncAvatarFailed(Object error) => '同步本机头像失败: $error';
  @override
  String get toastSelfProfileUpdated => '已更新本机资料并同步到在线设备';
  @override
  String get toastPeerRemarkUpdated => '已更新设备备注名称';
  @override
  String get toastRestoredGroupName => '已恢复默认共享组名称';
  @override
  String get toastUpdatedGroupName => '已更新共享组本机备注名';
  @override
  String get toastAutoStartEnabled => '已开启开机自动静默启动';
  @override
  String get toastAutoStartDisabled => '已关闭开机自启';
  @override
  String get toastCloseToTrayEnabled => '点击关闭按钮将最小化到系统托盘';
  @override
  String get toastCloseToTrayDisabled => '点击关闭按钮将直接退出程序';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      '收到来自 $sender 的文件：$fileName';
  @override
  String get notifyFileFallbackBody => '新文件已自动保存';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      '$fileLabel 等共 $totalCount 个文件正在接收';
  @override
  String notifyNewFileTitle(String sender) => '收到新文件 · $sender';
  @override
  String notifyNewTextTitle(String sender) => '收到新消息 · $sender';
  @override
  String get notifyNewEncryptedText => '新加密文本消息';
  @override
  String get errorEmptyImageFile => '选择的图片文件为空';
  @override
  String get errorCompressAvatarFailed => '无法压缩头像图片';
  @override
  String get errorPngEncodeFailed => 'PNG 编码失败';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return '未检测到 USB 共享网卡';
    if (metricProtected) return '已将 USB 网卡跃点数设为 5000，确保不劫持电脑宽带流量';
    if (needsElevation) return '需要管理员权限将 USB 网卡跃点数设为 5000';
    return '检测到 USB 共享网卡，等待调整路由跃点数';
  }

  @override
  String get winTrayTooltip => 'P2P 私人快传 · 后台常驻快传服务';
  @override
  String get winTrayOpenWindow => '打开主窗口';
  @override
  String get winTrayAutoStart => '开机自动静默启动';
  @override
  String get winTrayCloseToTray => '关闭时最小化到托盘';
  @override
  String get winTrayExitApp => '彻底退出程序';
}
