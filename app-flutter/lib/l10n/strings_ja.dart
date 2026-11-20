import 'package:intl/intl.dart';

import 'app_strings.dart';

class StringsJa extends AppStrings {
  const StringsJa();

  @override
  String get localeCode => 'ja';

  @override
  String get appTitle => 'P2Pfiledrop';
  @override
  String get appSubtitle => 'エンドツーエンド暗号化転送';
  @override
  String get startingEngine => 'P2P 暗号化転送エンジンを起動しています...';
  @override
  String engineInitFailed(Object error) => 'エンジンの初期化に失敗しました:\n$error';
  @override
  String get retry => '再試行';
  @override
  String get cancel => 'キャンセル';
  @override
  String get confirm => 'OK';
  @override
  String get close => '閉じる';
  @override
  String get save => '保存';
  @override
  String get delete => '削除';
  @override
  String get remove => '削除';
  @override
  String get open => '開く';
  @override
  String get refresh => '更新';
  @override
  String get clear => 'クリア';
  @override
  String get resetDefault => 'デフォルトに戻す';
  @override
  String get recommendedBadge => '推奨';
  @override
  String get defaultAvatarFallback => '端';

  @override
  String formatFullDate(DateTime dt) => DateFormat('yyyy年M月d日').format(dt);
  @override
  String formatMonthDay(DateTime dt) => DateFormat('M月d日').format(dt);
  @override
  String get todayLabel => '今日';
  @override
  String get yesterdayLabel => '昨日';
  @override
  String formatRemainingSeconds(int seconds) => '残り $seconds秒';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      '残り $minutes分$seconds秒';

  @override
  String get navTransfers => '転送';
  @override
  String get navDevices => 'デバイス';
  @override
  String get navThisDevice => 'この端末';
  @override
  String get navAdd => '追加';
  @override
  String get navFiles => 'ファイル';
  @override
  String get navFolder => 'フォルダ';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName（タップして設定を開く）';
  @override
  String get tooltipScanPair => 'QR スキャンでデバイス追加 / グループ参加';
  @override
  String get tooltipAllFiles => 'すべての転送ファイル・写真を表示';
  @override
  String tooltipOpenReceiveFolder(String dir) => '受信フォルダを開く ($dir)';

  @override
  String get transportUsbTether => 'USB 直結';
  @override
  String get transportLanDirect => 'LAN 直結';
  @override
  String get transportWanP2p => 'WAN P2P';
  @override
  String get transportWanRelay => 'リレー経由';
  @override
  String get transportOffline => 'オフライン';
  @override
  String get usbTetherTag => 'USB直結';

  @override
  String get msgStatusQueuedOffline => '相手のオンライン待機中';
  @override
  String get msgStatusHandshaking => '安全ハンドシェイク中';
  @override
  String get msgStatusTransferring => '高速転送中';
  @override
  String get msgStatusPausedReconnecting => 'レジューム再接続中';
  @override
  String get msgStatusAwaitingDownload => 'タップして端末へ保存';
  @override
  String get msgStatusDelivered => '配信済み';
  @override
  String get msgStatusFailedSourceMissing => '元ファイルが見つかりません';

  @override
  String deviceWithTag(String tag) => '$tag 端末';
  @override
  String deviceShortIdLabel(String shortId) => 'デバイス · $shortId';
  @override
  String get peerDeviceFallback => '相手デバイス';
  @override
  String get defaultPersonalRoomName => '個人デバイスグループ (Personal)';
  @override
  String get defaultEncryptedGroupName => '新規暗号化グループ';
  @override
  String get defaultPrivateRoomName => '新規プライベート暗号化ルーム';
  @override
  String encryptedRoomWithId(String shortId) => '暗号化ルーム ($shortId)';
  @override
  String get homeNodeDefaultName => 'ホーム常駐ノード';

  @override
  String get chatListTitle => 'チャット';
  @override
  String get chatListNewActionTooltip => 'QR スキャン / グループ作成';
  @override
  String get menuScanPairOrJoin => 'QR スキャンでペアリング / 参加';
  @override
  String get menuCreateGroup => '共有グループを作成';
  @override
  String get menuMyPairingQr => 'マイ QR コード';
  @override
  String get menuOpenReceiveFolder => '受信フォルダを開く';
  @override
  String get menuProbeReconnect => '再接続 / 相手を探索';
  @override
  String get searchChatsHint => 'チャットまたはデバイスを検索...';
  @override
  String groupOnlineCount(int online, int total) =>
      '共有グループ ($online/$total オンライン)';
  @override
  String groupOfflineCount(int total) => '共有グループ ($total 台 · オフライン)';
  @override
  String get emptyChatsSearch => '一致するチャットがありません';
  @override
  String get emptyChatsNoRooms => 'アクティブなチャットはありません';
  @override
  String get btnScanPairDevice => 'QR でデバイスをペアリング';
  @override
  String get btnGoToDevices => '「デバイス」タブへ移動';

  @override
  String get devicesListTitle => 'デバイス';
  @override
  String get searchPairedDevicesHint => 'ペアリング済みデバイスを検索...';
  @override
  String get btnAddNewDevice => '新しいデバイスを追加 / QR ペアリング';
  @override
  String get btnNewSharedGroup => '共有グループを新規作成';
  @override
  String get btnAddDeviceShort => 'デバイス追加';
  @override
  String get btnNewGroupShort => 'グループ作成';
  @override
  String pairedDevicesCount(int count) => 'ペアリング済み ($count)';
  @override
  String get emptyDevicesSearch => '一致するデバイスがありません';
  @override
  String get emptyDevicesNone =>
      'ペアリング済みデバイスはありません\n上の「新しいデバイスを追加 / QR ペアリング」から接続できます';
  @override
  String get selectDevicePrompt => '詳細を表示するデバイスを左から選択してください';
  @override
  String get btnScanFirstDevice => '最初のデバイスをペアリング';
  @override
  String originalNameLabel(String name) => '元の端末名: $name';
  @override
  String get deviceNodeIdLabel => 'デバイスノード ID (Endpoint ID)';
  @override
  String get tooltipCopyDeviceId => 'デバイス ID をコピー';
  @override
  String get toastCopiedDeviceId => 'デバイス ID をコピーしました';
  @override
  String get btnSendMessageOrFile => 'メッセージ / ファイルを送信';
  @override
  String get btnEditRemark => '表示名を変更';
  @override
  String get btnDeleteDevice => 'このデバイスを削除';
  @override
  String get deletePeerDialogTitle => 'ペアリング済みデバイスを削除';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      '信頼済みデバイスから「$resolvedName」を削除し、ダイレクト履歴も消去しますか？（ローカルに保存された受信ファイルは削除されません）';
  @override
  String get btnConfirmDelete => '削除する';

  @override
  String get desktopWorkspaceTitle => '転送ワークスペース';
  @override
  String get btnOpenFolder => 'フォルダを開く';
  @override
  String get tooltipRoomFiles => 'ルームのファイル・写真履歴';
  @override
  String get tooltipInviteOrScan => 'QR 招待 / スキャンで参加';
  @override
  String get tooltipRoomMembers => 'デバイス詳細 / グループ管理';
  @override
  String get desktopEmptyTitle => '左からチャットまたはデバイスを選択してください';
  @override
  String get desktopEmptySubtitle =>
      'LAN 直結・USB ケーブル優先・外回り暗号化転送に対応し、ファイルをそのままドラッグ＆ドロップで送信できます';
  @override
  String get moreActionsTooltip => 'その他の操作';
  @override
  String get moreTooltip => 'その他';
  @override
  String get emptyRoomNoSession => 'アクティブなチャットはありません。まずは QR コードでデバイスをペアリングしてください';
  @override
  String get emptyRoomE2eeNotice => 'このルームはエンドツーエンド暗号化で保護されており、メッセージとファイルは端末間でのみ復号されます';
  @override
  String get emptyRoomWindowsHint => 'ファイルや写真をここにドラッグ＆ドロップして送信するか、テキストを入力してください';
  @override
  String get emptyRoomMobileHint => '下の + ボタンから写真やファイルを選ぶか、そのままメッセージを入力してください';
  @override
  String dropZonePrompt(String roomTitle) => '離すと「$roomTitle」へ暗号化送信します';
  @override
  String get menuAddPairedToGroup => 'ペアリング済みデバイスをグループに追加';
  @override
  String get menuDeviceDetailsAndRemark => 'デバイス詳細と表示名';
  @override
  String get menuGroupMembersAndManage => 'グループメンバーと管理';
  @override
  String get noShareTargetsToast => '送信可能なデバイスまたはチャットがありません。先にペアリングしてください';
  @override
  String get fallbackShortTitle => 'プライベート転送';

  @override
  String get tooltipGalleryImages => 'アルバムから写真を選択';
  @override
  String get tooltipSendFile => 'ファイルを選択して送信';
  @override
  String get tooltipSendImageOrFile => '写真またはファイルを送信';
  @override
  String get tooltipPasteClipboard => 'クリップボードの写真・テキストを貼り付け';
  @override
  String get inputHintWindows => 'メッセージを入力、または写真・ファイルを貼り付け / ドロップ...';
  @override
  String get inputHintMobile => 'メッセージを入力...';
  @override
  String get inputHintNoRoom => '先に左上の + からデバイスを追加してください...';
  @override
  String get tooltipSendMessage => '送信';

  @override
  String get newMessagesBelowSuffix => '件の新着';
  @override
  String albumFailedCount(int failedCount) => '$failedCount 枚で元ファイルが見つかりません';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      '送信完了（うち $missingCount 枚の元画像は削除済み）';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      '受信完了（うち $missingCount 枚のローカル画像は削除済み）';
  @override
  String get albumAllDelivered => 'すべて配信済み';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      '$delivered / $total 枚を転送中';
  @override
  String albumImageCount(int count) => '写真 $count 枚';
  @override
  String get btnExpand => '展開';
  @override
  String collapseImagesCount(int count) => '画像を折りたたむ ($count)';

  @override
  String get statusLargeFileAwaitConfirm => '送信確認待ち';
  @override
  String get statusGroupFileAwaitDownload => 'グループ受信待機中';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      'ファイル通知送信済み ($acked/$total)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      '送信確認待ち ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      '全員に配信済み ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) => '配信済み ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => '元ファイル削除済み';
  @override
  String get statusLocalFileDeleted => 'ローカルファイル削除済み';
  @override
  String get revokedByMe => '送信を取り消しました';
  @override
  String get revokedByPeer => '相手が送信を取り消しました';
  @override
  String get tooltipEditPeerRemark => '表示名を変更';
  @override
  String get tooltipPeerAvatar => '相手デバイス';
  @override
  String get toastCopiedText => 'テキストをコピーしました';
  @override
  String toastCopiedPath(String path) => 'パスをコピーしました: $path';
  @override
  String get imageDeletedLocally => 'この画像は端末から削除されました';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · 元の画像は端末から削除済み';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · 画像は端末から削除済み（タップで詳細）';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · 元ファイルが見つかりません';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · 端末から削除済み';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · 大容量ファイル送信確認待ち';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · グループファイル受信待機中';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · 相手のオンライン取得待ち';
  @override
  String btnDownloadToDevice(String sizeLabel) => '端末に保存 ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => 'すぐ送信 ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => 'オンライン後自動送信を確定';
  @override
  String get actionCopyText => 'テキストをコピー';
  @override
  String get actionForward => '転送';
  @override
  String get actionOpenFile => 'ファイルを開く';
  @override
  String get actionRevealInFolder => 'フォルダで表示';
  @override
  String get actionCopyFilePath => 'ファイルパスをコピー';

  @override
  String get createGroupTitle => '暗号化共有グループを作成';
  @override
  String get createGroupDesc =>
      'ペアリング済みのデバイスを選ぶだけでグループを作成でき（再スキャン不要）、専用のエンドツーエンド暗号鍵を共有します。';
  @override
  String get groupNameOptionalLabel => 'グループ名（任意）';
  @override
  String get groupNameAutoHint => '空欄の場合は選択したデバイスから自動生成';
  @override
  String get createGroupNoPeersNotice =>
      'ペアリング済みデバイスがありません。先にグループを作成し、右上の QR アイコンからメンバーを追加できます。';
  @override
  String selectGroupDevicesCount(int count) => '参加デバイスを選択（$count 台選択中）:';
  @override
  String get btnCreateGroup => 'グループを作成';
  @override
  String get defaultGroupNameFallback => '暗号化共有グループ';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => '$joinedNames グループ';
  @override
  String get nameSeparator => '・';
  @override
  String get addMembersToGroupTitle => 'ペアリング済みデバイスを追加';
  @override
  String get btnConfirmInvite => '招待を確定';
  @override
  String get allPeersAlreadyInGroupToast => 'ペアリング済みデバイスはすべて既に参加しています';
  @override
  String get subtitleDmE2ee => 'P2P ダイレクト · エンドツーエンド暗号化';
  @override
  String subtitleGroupE2ee(int count) => '共有グループ ($count 台) · E2EE 鍵分離';
  @override
  String get tooltipEditGroupName => 'グループ名を編集';
  @override
  String get badgeThisTerminal => 'この端末';
  @override
  String get roleThisDevice => 'このデバイス（変更可能）';
  @override
  String get rolePeerDevice => '相手デバイス';
  @override
  String get roleGroupMember => 'グループメンバー';
  @override
  String get tooltipEditSelfProfile => '端末名とアイコンを編集';
  @override
  String get tooltipRemoveFromGroup => 'グループから外す';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      '「$roomTitle」とのペアリングを解除して削除しますか？（保存済みのファイルは端末に残ります）';
  @override
  String get deleteGroupTitle => '共有グループを削除';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      '共有グループ「$roomTitle」とこの端末上の会話履歴を削除しますか？（保存済みのファイルは削除されません）';
  @override
  String get btnDeleteAndLeave => '削除して退出';
  @override
  String get btnInviteNewDevice => '新しいデバイスを招待 / スキャン';
  @override
  String get editGroupNameTitle => '共有グループ名を変更';
  @override
  String get localDisplayNameLabel => 'この端末での表示名';
  @override
  String editGroupNameHint(String defaultName) => '空欄で「$defaultName」に戻す';
  @override
  String get editProfileSelfTitle => '端末名とアイコンを編集';
  @override
  String get editProfilePeerTitle => '相手デバイスの表示名を編集';
  @override
  String processImageFailed(Object error) => '画像の処理に失敗しました: $error';
  @override
  String get btnChangeAvatar => 'アイコンを変更';
  @override
  String get btnUploadAvatar => 'アイコンをアップロード';
  @override
  String get btnRemoveImage => '画像を削除';
  @override
  String get avatarSyncNoticeSelf => 'アップロードした画像はペアリング済みデバイスへ自動的に暗号化同期されます';
  @override
  String get avatarSyncNoticePeer => '表示名はこの端末内でのみ変更できます。アイコンは相手が設定したものが表示されます';
  @override
  String get selfDisplayNameLabel => 'この端末の表示名';
  @override
  String get peerRemarkNameLabel => '相手デバイスの表示名';
  @override
  String get customDeviceNameHint => '表示名を入力';
  @override
  String defaultNameDisplay(String fallbackModel) => 'デフォルト: $fallbackModel';
  @override
  String get shareToTitle => '送信先を選択...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "写真" : "ファイル"}: $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '${allImages ? "写真" : "ファイル"} $count 件 · $size';
  @override
  String shareSummaryText(String text) => 'テキスト: $text';
  @override
  String get sendToTitle => '送信先';
  @override
  String get targetTypeDm => 'ダイレクト端末';
  @override
  String targetTypeGroup(int memberCount) => '共有グループ · $memberCount 台';
  @override
  String get targetTypePairedPeer => 'ペアリング済みデバイス (P2P)';
  @override
  String get btnReselect => '選び直す';
  @override
  String btnSendCount(int count) => '送信 ($count)';
  @override
  String get btnSend => '送信';
  @override
  String shareFileListMore(int count, String size) =>
      'など 計 $count ファイル · $size';
  @override
  String shareFileListExact(int count, String size) => '計 $count ファイル · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      '${isImage ? "写真" : "ファイル"}を転送: $fileName';
  @override
  String forwardSummaryText(String text) => 'メッセージを転送: $text';
  @override
  String get forwardToTitle => '転送先を選択...';
  @override
  String get searchRoomOrDeviceHint => 'チャットまたはデバイスを検索...';
  @override
  String get noAvailableTargets => '送信可能なチャットまたはデバイスがありません';
  @override
  String get noMatchingTargets => '一致するチャットまたはデバイスがありません';
  @override
  String get currentConversationLabel => '現在のチャット';
  @override
  String get tooltipOpenWithDefaultApp => '既定のアプリで開く';
  @override
  String get tooltipDeleteMessage => 'メッセージを削除';
  @override
  String get tooltipClosePreview => 'プレビューを閉じる';
  @override
  String get deletedImagePreviewTitle => '画像は端末から削除済み';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '「$fileName」は端末から削除されているため、元のプレビューを読み込めません。';
  @override
  String get btnDeleteThisRecord => 'このメッセージ履歴を削除';
  @override
  String get removeRevokeNoticeTitle => '削除時の注意';
  @override
  String get removeRevokeNoticeBody =>
      'このメッセージの元ファイルが端末から削除された後も、自分のチャット欄からのみ安全に消去でき、相手側には影響しません。';
  @override
  String get deleteOutgoingFileTitle => '送信済みファイルを削除';
  @override
  String get deleteOutgoingTextTitle => '送信済みメッセージを削除';
  @override
  String get chooseDeleteMethod => '削除方法を選択してください:';
  @override
  String get deleteOutgoingFileDetail =>
      '・相手端末からも取り消す：相手デバイスやリレー保管庫へ取り消し通知を送り、相手側の自動保存コピーも削除します。\n・この端末からのみ削除：自分の履歴だけを消去し、相手のファイルや履歴は残します。\n\n※ 送信元のオリジナルファイル自体が削除・変更されることはありません。';
  @override
  String get deleteOutgoingTextDetail =>
      '・相手端末からも取り消す：メンバーおよびリレーノードへ削除通知を送り、両側から消去します。\n・この端末からのみ削除：自分の画面からのみ履歴を消去します。';
  @override
  String get btnRemoveLocalOnly => 'この端末からのみ削除';
  @override
  String get btnRevokeForAll => '相手端末からも取り消す';
  @override
  String get deleteIncomingFileTitle => '受信ファイルを削除';
  @override
  String get deleteIncomingTextTitle => '受信メッセージを削除';
  @override
  String get deleteIncomingNote => 'この端末の履歴のみを削除し、相手側には影響しません。';
  @override
  String get checkboxDeleteLocalFile => '端末に保存されたファイルも同時に削除する';
  @override
  String get incomingFileAlreadyMissing => 'ローカルファイルは既に存在しないため、履歴のみを削除します。';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      '画像プレビュー ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => '送信確認 ($count 件)';
  @override
  String get btnAddMore => 'さらに追加';
  @override
  String batchLimitNotice(int maxFiles) =>
      '1 回あたり最大 $maxFiles 件まで送信できます（先頭 $maxFiles 件のみ保持しました）';
  @override
  String get tooltipPrevImage => '前の画像';
  @override
  String get tooltipNextImage => '次の画像';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '合計 $count 件 · $size${showEnterHint ? '（Enter で送信）' : ''}';

  @override
  String inviteGroupTitle(String roomName) => '「$roomName」メンバー招待';
  @override
  String get inviteDeviceTitle => 'デバイス追加 / QR ペアリング';
  @override
  String get tabGroupInviteQr => 'グループ招待 QR';
  @override
  String get tabDevicePairingQr => 'マイ QR コード';
  @override
  String get tabScanOrPaste => 'スキャン / 貼り付け';
  @override
  String get desktopQrImageUnsupported =>
      'デスクトップ版では画像からの QR 解析に対応していません。チケット JSON を直接貼り付けてください';
  @override
  String get noQrDetectedInImage => '選択した画像から QR コードを検出できませんでした。別の鮮明な画像をお試しください';
  @override
  String galleryQrScanFailed(Object error) => 'アルバム QR 解析失敗: $error';
  @override
  String generateQrFailed(Object error) => 'QR チケット生成失敗: $error';
  @override
  String get joinOrPairFailedHint => '参加またはペアリングに失敗しました。チケットが完全か確認してください';
  @override
  String groupInviteDesc(String roomName) =>
      'グループ招待 QR：相手がスキャンすると「$roomName」に直接参加し、E2EE 鍵を同期します。';
  @override
  String get devicePairingDesc =>
      'マイ QR コード：相手がスキャンすると信頼済みデバイスとして相互登録され、P2P 暗号化チャネルを自動確立します。';
  @override
  String get toastCopiedQrJson => 'ペアリング / 招待チケット JSON をコピーしました';
  @override
  String get btnCopyTextTicket => 'テキストチケットをコピー';
  @override
  String get btnRetryGenerateQr => 'QR を再生成';
  @override
  String get scannerPermDenied => 'カメラ権限がありません。カメラを許可するか、アルバムから QR 画像を選択してください';
  @override
  String get scannerUnsupported =>
      'この端末はカメラでの QR 読み取りに対応していません。アルバムから画像を選ぶか、チケットを貼り付けてください';
  @override
  String get scannerReinitializing => 'カメラチャンネルをリセット中です。しばらくしてから「再試行」を押してください';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      'カメラを起動できません ($details)';
  @override
  String get scannerGenericError => 'カメラを起動できません。「再試行」またはアルバムから QR 画像を選んでください';
  @override
  String get startingCamera => 'カメラを起動しています...';
  @override
  String get btnPickQrFromGallery => 'アルバムから QR を選択';
  @override
  String get btnRetryCamera => '再試行';
  @override
  String get pasteTicketDialogTitle => 'チケットを貼り付けて参加';
  @override
  String get pasteTicketFieldHint => 'ルーム招待またはデバイスペアリング JSON を貼り付け';
  @override
  String get btnJoinOrRegister => '参加 / 登録';
  @override
  String get cameraNotSupportedPlatform =>
      'このプラットフォームはカメラ読み取りに未対応です。「チケット貼付」またはアルバムから画像を選択してください';
  @override
  String get qrViewfinderHint => '枠内に QR コードを収めると自動でペアリング / 参加します';
  @override
  String get analyzingImageQr => '画像内の QR コードを解析中...';
  @override
  String get verifyingHandshake => '暗号化ハンドシェイク検証中...';
  @override
  String get actionGallery => 'アルバム';
  @override
  String get actionPasteTicket => 'チケット貼付';
  @override
  String get actionTorchOff => 'ライト消灯';
  @override
  String get actionTorchOn => 'ライト点灯';
  @override
  String get windowsPasteTicketHint =>
      'Windows 版では「ルーム招待チケット」を直接貼り付けて同じ暗号化グループへ接続できます。';
  @override
  String get btnAnalyzingQr => 'QR コードを解析中...';
  @override
  String get btnRestartCamera => 'カメラを再起動';
  @override
  String get pasteTicketFieldLabel => 'ルーム招待またはペアリングチケット JSON を貼り付け';
  @override
  String get btnJoinToThisDevice => 'この端末へ参加 / 登録';

  @override
  String get allFilesTitle => 'すべての転送ファイル';
  @override
  String get roomFilesTitle => 'チャットのファイル履歴';
  @override
  String get tooltipOpenMainReceiveFolder => 'メイン受信フォルダを開く';
  @override
  String get searchFileNameHint => 'ファイル名を検索...';
  @override
  String get allRoomsOption => 'すべてのチャット';
  @override
  String tabImagesCount(int count) => '写真 ($count)';
  @override
  String tabFilesCount(int count) => 'ファイル ($count)';
  @override
  String loadFilesFailed(String error) => '読み込み失敗: $error';
  @override
  String get emptyImagesNone => 'このチャットにはまだ画像がありません';
  @override
  String get emptyImagesSearch => '一致する写真がありません';
  @override
  String get emptyFilesNone => 'このチャットにはまだ一般ファイルがありません';
  @override
  String get emptyFilesSearch => '一致するファイルがありません';
  @override
  String get badgeLocallyRemoved => 'ローカル削除済み';
  @override
  String get unnamedFile => '名称未設定ファイル';
  @override
  String get toastLocalFileMissing => 'ローカルファイルは移動または削除されています';
  @override
  String get actionOpenShort => '開く';

  @override
  String get sectionGeneral => '一般';
  @override
  String get sectionReceiveStorage => '受信とストレージ';
  @override
  String get sectionResidencyNetwork => '常駐とネットワーク';
  @override
  String get sectionAbout => 'アプリについて';
  @override
  String deviceModelLabel(String model) => '端末モデル: $model';
  @override
  String get toastCopiedFullDeviceId => '完全なデバイス ID をコピーしました';
  @override
  String get tooltipEditNameAvatar => '名前とアイコンを変更';
  @override
  String get toastThumbCacheCleared => 'サムネイルキャッシュをクリアしました（元の写真・ファイルは保持）';
  @override
  String toastSaveDirUpdated(String dir) => '保存先を変更しました: $dir';
  @override
  String saveDirNotWritable(Object error) => 'このフォルダへの書き込みに失敗しました: $error';
  @override
  String get needAllFilesPermTitle => '「すべてのファイルへのアクセス」権限が必要です';
  @override
  String get needAllFilesPermBody =>
      'Android システムの公開「ダウンロード」フォルダに受信ファイルを直接書き込むため、権限の許可が必要です。';
  @override
  String get btnGoGrant => '許可設定へ';
  @override
  String get pickReceiveFolderDialogTitle => '受信ファイルの保存先フォルダを選択';
  @override
  String storageSizeSuffix(String size, int count) => '（$size · $count 件）';
  @override
  String get storageModeDownloads => '公開「ダウンロード (Downloads)」フォルダ';
  @override
  String get storageModeDocuments => '公開「ドキュメント (Documents)」フォルダ';
  @override
  String get storageModeCustomTitle => 'カスタムフォルダ';
  @override
  String storageModeCustom(String compactPath) => 'カスタム保存先 ($compactPath)';
  @override
  String get storageModeAppPrivate => 'アプリ専用領域 (Android/data)';
  @override
  String get receiveLocationTitle => '受信ファイルの保存先';
  @override
  String get storageDownloadsDesc => '端末のファイルマネージャーや他アプリからすぐ開けます';
  @override
  String get storageDocumentsDesc => '書類・PDF などの長期整理に適したフォルダです';
  @override
  String storageCustomSelectedDesc(String compactPath) => '現在のパス: $compactPath';
  @override
  String get storageCustomUnselectedDesc => 'SD カードや任意の独自フォルダを選択できます';
  @override
  String get btnChange => '変更';
  @override
  String get storageAppPrivateTitle => 'アプリ専用領域（アンインストール時に消去）';
  @override
  String get storageAppPrivateDesc => 'アルバムや通常のファイル管理には表示されません（アンインストール時に同時削除）';
  @override
  String get legacyStoragePermNotice =>
      '共有「ダウンロード」フォルダへ書き込むため、ストレージ書き込み権限が必要です';
  @override
  String get btnAuthorize => '許可';
  @override
  String get btnChangeFolder => 'フォルダを変更';
  @override
  String get pickReceiveDirDialogTitle => '自動保存先フォルダを選択';
  @override
  String get windowsResidencyTitle => 'Windows トレイ常駐と自動起動';
  @override
  String get windowsCloseToTrayTitle => '閉じるボタンでシステムトレイへ最小化';
  @override
  String get windowsCloseToTraySubtitle =>
      '右上の × でトレイへ格納し、常時受信・デスクトップ通知を待機します';
  @override
  String get windowsAutoStartTitle => 'Windows 起動時にバックグラウンド自動起動';
  @override
  String get windowsAutoStartSubtitle => 'OS ログイン時に最小化でトレイ常駐します（--minimized）';
  @override
  String get btnHideToTrayNow => '今すぐトレイへ格納';
  @override
  String get btnQuitBackgroundService => 'バックグラウンド常駐を含め完全終了';
  @override
  String get themeDialogTitle => '外観テーマを選択';
  @override
  String get themeSystemTitle => 'システム設定に従う';
  @override
  String get themeSystemSubtitle => 'Windows / Android のライト・ダーク設定に自動連動';
  @override
  String get themeLightTitle => 'ライトモード';
  @override
  String get themeLightSubtitle => '明るい紙面とミント系トーン';
  @override
  String get themeDarkTitle => 'ダークモード';
  @override
  String get themeDarkSubtitle => '夜間でも目に優しい落ち着いた配色';
  @override
  String get themeSystemShort => 'システム';
  @override
  String get themeLightShort => 'ライト';
  @override
  String get themeDarkShort => 'ダーク';
  @override
  String get languageDialogTitle => 'アプリ言語';
  @override
  String get languageSettingTitle => 'アプリ言語';
  @override
  String get languageSystemTitle => 'システム言語に従う';
  @override
  String get languageSystemSubtitle => 'OS の言語設定に応じて自動で切り替わります';
  @override
  String toastLanguageUpdated(String langName) => '言語を「$langName」に変更しました';
  @override
  String get storageManagerTitle => 'ストレージ管理とキャッシュ整理';
  @override
  String storageRecvStats(String size, int count) => '使用容量: $size（計 $count 件）';
  @override
  String get countingStats => '集計中...';
  @override
  String get storageRecvUsedTitle => '受信済みファイル容量';
  @override
  String get thumbCacheTitle => 'サムネイルプレビューキャッシュ';
  @override
  String thumbCacheDesc(String size) =>
      '現在 $size 使用中 · クリアしても保存済みの原本ファイルは削除されません';
  @override
  String get btnClearThumbCache => 'キャッシュを削除';
  @override
  String get mobileStorageTitle => 'ストレージとキャッシュ';
  @override
  String legendReceivedFiles(String size) => '受信済み $size';
  @override
  String legendThumbCache(String size) => 'キャッシュ $size';
  @override
  String receivedFilesCountTitle(int count) => '受信済みファイル ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => 'サムネイルキャッシュ ($size)';
  @override
  String get thumbCacheNoTouchNotice => '削除しても元の写真やファイルには影響しません';
  @override
  String get noCacheToClear => '削除するキャッシュはありません';
  @override
  String btnClearThumbCacheWithSize(String size) => 'サムネイルキャッシュを削除 ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      '受信 $recvSize · キャッシュ $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => 'キャッシュ $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      '合計 $totalSize · キャッシュ $cacheSize';
  @override
  String get storageAndCacheTitle => 'ストレージとキャッシュ整理';
  @override
  String get aboutTitle => 'P2P プライベート転送について';
  @override
  String aboutVersion(String version) => 'バージョン：$version';
  @override
  String get aboutBody =>
      'クラウドサーバーやサイズ制限のない、クロスプラットフォームのエンドツーエンド暗号化 P2P 転送ツールです。\n\n・物理 NIC バインディング：VPN/TUN を迂回して高速直結\n・マルチ ルーム鍵分離：ホーム常駐リレーも暗号文のみを保管\n・USB 専用ルート自動優先：Windows 側のルーティング乗っ取りを自動防止';
  @override
  String get aboutSubtitle => 'エンドツーエンド暗号化クロスプラットフォーム転送 · サーバーレス';
  @override
  String get networkDiagTitle => '高度なネットワークと接続診断';
  @override
  String get networkDiagLoading => 'ローカルネットワークを診断中...';
  @override
  String networkDiagDesktopReady(int count) =>
      '準備完了 · LAN/USB 直結インターフェース $count 件を検出（通常は変更不要）';
  @override
  String get networkDiagDesktopWanOnly => '外回り P2P 暗号化チャネル（LAN 直結未検出）';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB 準備完了 · インターフェース $count 件を検出';
  @override
  String get networkDiagMobileWanOnly => '現在：WAN 暗号化チャネル';
  @override
  String get nicDetectionTitle => '物理 LAN / USB ネットワークインターフェース（VPN 迂回）';
  @override
  String get nicDetectionDesc =>
      'システム内の Clash / Mihomo / WireGuard などの仮想 TUN アダプタを自動除外し、実 NIC のみにバインドします。';
  @override
  String get nicReading => 'インターフェース情報を取得中...';
  @override
  String get nicNoneConnected => '接続済みの物理 LAN / USB インターフェースが見つかりません';
  @override
  String get btnRefreshNics => 'NIC 状態を更新';
  @override
  String get usbProtectionTitle => 'USB テザリング高速直結ルート保護 (Windows)';
  @override
  String get usbProtectionDesc =>
      'Android 端末の「USB テザリング」を有効化すると、自動でメトリックを 5000 に分離し、PC の既定インターネット回線を奪わずに 42420 ポート経由の高速転送を実現します。';
  @override
  String get usbProtectionReady => '準備完了：USB ルート乗っ取り防止済み (Metric=5000)';
  @override
  String usbProtectionNeedsFix(String detail) => '自動修正が必要: $detail';
  @override
  String get usbProtectionNotPlugged =>
      '未接続：スマホ側で USB テザリングが有効になると自動で検出・保護します';
  @override
  String get btnFixMetric => 'メトリックを修正';
  @override
  String get customRelayTitle => 'カスタムリレーサーバー（Relay · 上級者向け）';
  @override
  String get customRelayDesc =>
      '同一 LAN になく外回り P2P 直結もできない場合、リレー経由で暗号化中継されます（E2EE によりリレーは中身を閲覧不可）。通常は空欄（無料パブリックリレー使用）で問題ありません。';
  @override
  String get customRelayLabel => 'Relay サーバー URL（空欄で既定パブリックリレー）';
  @override
  String get toastRelaySaved => 'リレー設定を保存しました';
  @override
  String get btnSaveRelay => 'リレー設定を保存';
  @override
  String get deviceIdLabel => 'デバイス ID';
  @override
  String get btnCopyDeviceId => '完全なデバイス ID をコピー';
  @override
  String get deviceIdCopiedBadge => 'コピー済み';

  @override
  String toastEventStreamError(Object error) => 'イベントストリームエラー: $error';
  @override
  String toastCreatedRoom(String name) => '暗号化ルーム「$name」を作成しました';
  @override
  String toastCreateRoomFailed(Object error) => 'ルーム作成に失敗しました: $error';
  @override
  String toastOpenChatFailed(Object error) => 'チャットを開けませんでした: $error';
  @override
  String toastCreatedGroup(String name) => '共有グループ「$name」を作成しました';
  @override
  String toastCreateGroupFailed(Object error) => 'グループ作成に失敗しました: $error';
  @override
  String toastJoinedRoom(String name) => '暗号化ルーム「$name」に参加しました';
  @override
  String toastAddedDevice(String name) => 'デバイス「$name」を追加しました';
  @override
  String toastPairFailed(Object error) => 'ペアリングまたは参加に失敗しました: $error';
  @override
  String toastSendTextFailed(Object error) => 'メッセージ送信に失敗しました: $error';
  @override
  String get toastSelectRoomFirst => '先に送信先のチャットまたはデバイスを選択してください';
  @override
  String toastSendFileFailed(String path, Object error) =>
      'ファイル送信に失敗しました ($path): $error';
  @override
  String get toastForwardFileMissing => 'ローカルファイルが見つからないため転送できません';
  @override
  String get toastForwardEmptyText => 'テキスト内容が空のため転送できません';
  @override
  String get fallbackTargetRoom => '指定されたチャット';
  @override
  String toastForwardedTo(String targetName) => '「$targetName」へ転送しました';
  @override
  String toastForwardFailed(Object error) => '転送に失敗しました: $error';
  @override
  String get fallbackBigFile => '大容量ファイル';
  @override
  String toastConfirmedSend(String fileName) => '「$fileName」の送信を確定しました';
  @override
  String toastConfirmSendFailed(Object error) => '送信確定に失敗しました: $error';
  @override
  String get fallbackFile => 'ファイル';
  @override
  String toastPullingFile(String fileName) => '「$fileName」の受信を開始しました';
  @override
  String toastPullFileFailed(Object error) => 'ファイル受信に失敗しました: $error';
  @override
  String get toastPeerDeleted => 'ペアリング済みデバイスを削除しました';
  @override
  String toastDeletePeerFailed(Object error) => 'デバイスの削除に失敗しました: $error';
  @override
  String get toastRoomDeleted => 'チャットを削除しました';
  @override
  String toastDeleteRoomFailed(Object error) => 'チャットの削除に失敗しました: $error';
  @override
  String get toastDeletedRecordAndFile => '履歴とローカル保存ファイルを削除しました';
  @override
  String get toastRemovedLocalRecord => 'この端末の履歴から削除しました';
  @override
  String toastDeleteMsgFailed(Object error) => 'メッセージ削除に失敗しました: $error';
  @override
  String get toastOnlyRevokeOwn => '自分が送信したメッセージのみ取り消せます';
  @override
  String get toastRevokedForAll => '送信を取り消し、相手端末へ削除通知を送りました';
  @override
  String toastRevokeFailed(Object error) => '取り消しに失敗しました: $error';
  @override
  String toastInvitedMembers(int count) => '$count 台のデバイスをグループへ招待しました';
  @override
  String toastAddMembersFailed(Object error) => 'メンバー追加に失敗しました: $error';
  @override
  String get toastRemovedMember => 'デバイスをグループから外しました';
  @override
  String toastRemoveMemberFailed(Object error) => 'メンバー削除に失敗しました: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => 'USB メトリック修正に失敗しました: $error';
  @override
  String toastReceiveDirFallback(String dir) => 'ファイル保存先：$dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => '自動保存先を更新しました: $dir';
  @override
  String get toastClearedCustomSaveDir =>
      'カスタム保存先設定をクリアしました。既定フォルダが使用されます';
  @override
  String toastSetDirFailed(Object error) => 'フォルダ設定に失敗しました: $error';
  @override
  String toastSyncAvatarFailed(Object error) => 'アイコン同期に失敗しました: $error';
  @override
  String get toastSelfProfileUpdated => 'プロフィールを更新しオンライン端末へ同期しました';
  @override
  String get toastPeerRemarkUpdated => 'デバイスの表示名を更新しました';
  @override
  String get toastRestoredGroupName => 'デフォルトのグループ名に戻しました';
  @override
  String get toastUpdatedGroupName => 'ローカルのグループ表示名を更新しました';
  @override
  String get toastAutoStartEnabled => 'Windows 起動時のサイレント自動起動を有効にしました';
  @override
  String get toastAutoStartDisabled => 'OS 起動時の自動起動を無効にしました';
  @override
  String get toastCloseToTrayEnabled => '閉じるボタンでシステムトレイへ最小化します';
  @override
  String get toastCloseToTrayDisabled => '閉じるボタンでアプリを終了します';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      '$sender からファイルを受信: $fileName';
  @override
  String get notifyFileFallbackBody => '新しいファイルを自動保存しました';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      '$fileLabel など計 $totalCount 件を受信中';
  @override
  String notifyNewFileTitle(String sender) => '新しいファイル · $sender';
  @override
  String notifyNewTextTitle(String sender) => '新しいメッセージ · $sender';
  @override
  String get notifyNewEncryptedText => '新しい暗号化テキストメッセージ';
  @override
  String get errorEmptyImageFile => '選択した画像ファイルが空です';
  @override
  String get errorCompressAvatarFailed => 'アイコン画像を圧縮できませんでした';
  @override
  String get errorPngEncodeFailed => 'PNG エンコードに失敗しました';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'USB テザリングアダプタは未検出です';
    if (metricProtected) {
      return 'USB アダプタのメトリックを 5000 に設定済み（PC の通信回線は奪われません）';
    }
    if (needsElevation) {
      return 'USB アダプタのメトリックを 5000 に設定するには管理者権限が必要です';
    }
    return 'USB テザリングを検出しました。ルートメトリック調整待機中';
  }

  @override
  String get winTrayTooltip => 'P2P プライベート転送 · バックグラウンド待機サービス';
  @override
  String get winTrayOpenWindow => 'メインウィンドウを開く';
  @override
  String get winTrayAutoStart => '起動時に最小化して自動開始';
  @override
  String get winTrayCloseToTray => '閉じる時にトレイへ最小化';
  @override
  String get winTrayExitApp => 'アプリを完全に終了';
}
