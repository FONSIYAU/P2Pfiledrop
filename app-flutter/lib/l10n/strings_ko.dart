import 'package:intl/intl.dart';

import 'app_strings.dart';

class StringsKo extends AppStrings {
  const StringsKo();

  @override
  String get localeCode => 'ko';

  @override
  String get appTitle => 'BubbleDrop';
  @override
  String get appSubtitle => '종단간 암호화 전송';
  @override
  String get startingEngine => 'P2P 암호화 전송 엔진을 시작하는 중...';
  @override
  String engineInitFailed(Object error) => '엔진 초기화 실패:\n$error';
  @override
  String get retry => '다시 시도';
  @override
  String get cancel => '취소';
  @override
  String get confirm => '확인';
  @override
  String get close => '닫기';
  @override
  String get save => '저장';
  @override
  String get delete => '삭제';
  @override
  String get remove => '제거';
  @override
  String get open => '열기';
  @override
  String get refresh => '새로고침';
  @override
  String get clear => '지우기';
  @override
  String get resetDefault => '기본값 복원';
  @override
  String get recommendedBadge => '추천';
  @override
  String get defaultAvatarFallback => '기';

  @override
  String formatFullDate(DateTime dt) => DateFormat('yyyy년 M월 d일').format(dt);
  @override
  String formatMonthDay(DateTime dt) => DateFormat('M월 d일').format(dt);
  @override
  String get todayLabel => '오늘';
  @override
  String get yesterdayLabel => '어제';
  @override
  String formatRemainingSeconds(int seconds) => '$seconds초 남음';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      '$minutes분 $seconds초 남음';

  @override
  String get navTransfers => '전송';
  @override
  String get navDevices => '기기';
  @override
  String get navThisDevice => '내 기기';
  @override
  String get navAdd => '추가';
  @override
  String get navFiles => '파일';
  @override
  String get navFolder => '폴더';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName (탭하여 설정 열기)';
  @override
  String get tooltipScanPair => 'QR 스캔으로 기기 페어링 / 그룹 참여';
  @override
  String get tooltipAllFiles => '전체 전송 파일 및 사진 보기';
  @override
  String tooltipOpenReceiveFolder(String dir) => '수신 폴더 열기 ($dir)';

  @override
  String get transportUsbTether => 'USB 직통';
  @override
  String get transportLanDirect => 'LAN 직통';
  @override
  String get transportWanP2p => '외부 P2P';
  @override
  String get transportWanRelay => '릴레이 경유';
  @override
  String get transportOffline => '오프라인 대기';
  @override
  String get usbTetherTag => 'USB직통';

  @override
  String get msgStatusQueuedOffline => '상대 기기 온라인 대기 중';
  @override
  String get msgStatusHandshaking => '보안 핸드셰이크 중';
  @override
  String get msgStatusTransferring => '고속 전송 중';
  @override
  String get msgStatusPausedReconnecting => '이어받기 재연결 중';
  @override
  String get msgStatusAwaitingDownload => '탭하여 기기에 저장';
  @override
  String get msgStatusDelivered => '전송 완료';
  @override
  String get msgStatusFailedSourceMissing => '원본 파일 없음';

  @override
  String deviceWithTag(String tag) => '$tag 기기';
  @override
  String deviceShortIdLabel(String shortId) => '기기 · $shortId';
  @override
  String get peerDeviceFallback => '상대 기기';
  @override
  String get defaultPersonalRoomName => '개인 기기 그룹 (Personal)';
  @override
  String get defaultEncryptedGroupName => '새 암호화 그룹';
  @override
  String get defaultPrivateRoomName => '새 비밀 암호화 방';
  @override
  String encryptedRoomWithId(String shortId) => '암호화 방 ($shortId)';
  @override
  String get homeNodeDefaultName => '상시 홈 노드';

  @override
  String get chatListTitle => '대화';
  @override
  String get chatListNewActionTooltip => 'QR 스캔 / 그룹 만들기';
  @override
  String get menuScanPairOrJoin => 'QR 스캔으로 페어링 / 방 참여';
  @override
  String get menuCreateGroup => '공유 그룹 만들기';
  @override
  String get menuMyPairingQr => '내 페어링 QR';
  @override
  String get menuOpenReceiveFolder => '수신 폴더 열기';
  @override
  String get menuProbeReconnect => '연결 확인 / 재연결';
  @override
  String get searchChatsHint => '대화 또는 기기 검색...';
  @override
  String groupOnlineCount(int online, int total) =>
      '공유 그룹 ($online/$total 온라인)';
  @override
  String groupOfflineCount(int total) => '공유 그룹 ($total대 · 오프라인)';
  @override
  String get emptyChatsSearch => '일치하는 대화가 없습니다';
  @override
  String get emptyChatsNoRooms => '활성화된 대화가 없습니다';
  @override
  String get btnScanPairDevice => 'QR로 기기 페어링';
  @override
  String get btnGoToDevices => '「기기」 탭으로 이동';

  @override
  String get devicesListTitle => '기기';
  @override
  String get searchPairedDevicesHint => '페어링된 기기 검색...';
  @override
  String get btnAddNewDevice => '새 기기 추가 / QR 페어링';
  @override
  String get btnNewSharedGroup => '새 공유 그룹 만들기';
  @override
  String get btnAddDeviceShort => '기기 추가';
  @override
  String get btnNewGroupShort => '그룹 생성';
  @override
  String pairedDevicesCount(int count) => '페어링된 기기 ($count)';
  @override
  String get emptyDevicesSearch => '일치하는 기기가 없습니다';
  @override
  String get emptyDevicesNone =>
      '페어링된 기기가 없습니다\n위의 「새 기기 추가 / QR 페어링」을 눌러 연결하세요';
  @override
  String get selectDevicePrompt => '왼쪽에서 세부 정보를 확인할 기기를 선택하세요';
  @override
  String get btnScanFirstDevice => '첫 기기 페어링하기';
  @override
  String originalNameLabel(String name) => '원본 기기명: $name';
  @override
  String get deviceNodeIdLabel => '기기 노드 ID (Endpoint ID)';
  @override
  String get tooltipCopyDeviceId => '기기 ID 복사';
  @override
  String get toastCopiedDeviceId => '기기 ID가 복사되었습니다';
  @override
  String get btnSendMessageOrFile => '메시지 / 파일 보내기';
  @override
  String get btnEditRemark => '별칭 수정';
  @override
  String get btnDeleteDevice => '이 기기 삭제';
  @override
  String get deletePeerDialogTitle => '페어링된 기기 삭제';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      '신뢰된 기기에서 "$resolvedName"을(를) 제거하고 1:1 대화 기록도 지우시겠습니까? (기기에 저장된 수신 파일은 삭제되지 않습니다)';
  @override
  String get btnConfirmDelete => '삭제';

  @override
  String get desktopWorkspaceTitle => '전송 작업 공간';
  @override
  String get btnOpenFolder => '폴더 열기';
  @override
  String get tooltipRoomFiles => '대화방 파일 / 사진 기록';
  @override
  String get tooltipInviteOrScan => 'QR 초대 / 스캔 참여';
  @override
  String get tooltipRoomMembers => '기기 정보 / 그룹 관리';
  @override
  String get desktopEmptyTitle => '왼쪽에서 대화방이나 기기를 선택하세요';
  @override
  String get desktopEmptySubtitle =>
      'LAN 직통 · USB 케이블 우선 · 외부 암호화 전송을 지원하며, 파일을 드래그 앤 드롭하여 바로 보낼 수 있습니다';
  @override
  String get moreActionsTooltip => '더 보기';
  @override
  String get moreTooltip => '더 보기';
  @override
  String get emptyRoomNoSession => '활성 대화가 없습니다. 먼저 QR 스캔으로 기기를 페어링하세요';
  @override
  String get emptyRoomE2eeNotice => '이 방은 종단간 암호화되어 있으며, 메시지와 파일은 기기 간에만 복호화됩니다';
  @override
  String get emptyRoomWindowsHint => '파일이나 사진을 여기로 드래그하여 보내거나 텍스트를 입력하세요';
  @override
  String get emptyRoomMobileHint => '아래 + 버튼을 눌러 사진/파일을 선택하거나 메시지를 입력하세요';
  @override
  String dropZonePrompt(String roomTitle) => '놓으면 "$roomTitle"(으)로 암호화 전송됩니다';
  @override
  String get menuAddPairedToGroup => '페어링된 기기를 그룹에 추가';
  @override
  String get menuDeviceDetailsAndRemark => '기기 정보 및 별칭';
  @override
  String get menuGroupMembersAndManage => '그룹 멤버 및 관리';
  @override
  String get noShareTargetsToast => '보낼 수 있는 기기나 대화방이 없습니다. 먼저 페어링하세요';
  @override
  String get fallbackShortTitle => '프라이빗 전송';

  @override
  String get tooltipGalleryImages => '앨범 사진';
  @override
  String get tooltipSendFile => '파일 선택';
  @override
  String get tooltipSendImageOrFile => '사진 또는 파일 보내기';
  @override
  String get tooltipPasteClipboard => '클립보드 사진/텍스트 붙여넣기';
  @override
  String get inputHintWindows => '메시지를 입력하거나 사진·파일을 붙여넣기 / 드롭하세요...';
  @override
  String get inputHintMobile => '메시지 입력...';
  @override
  String get inputHintNoRoom => '먼저 왼쪽 상단 + 에서 기기를 추가하세요...';
  @override
  String get tooltipSendMessage => '보내기';

  @override
  String get newMessagesBelowSuffix => '개 새 메시지';
  @override
  String albumFailedCount(int failedCount) => '$failedCount장의 원본 파일을 찾을 수 없음';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      '전송 완료 (원본 사진 $missingCount장 로컬 삭제됨)';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      '수신 완료 (로컬 사진 $missingCount장 삭제됨)';
  @override
  String get albumAllDelivered => '모두 전송 완료';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      '$delivered / $total장 전송 중';
  @override
  String albumImageCount(int count) => '사진 총 $count장';
  @override
  String get btnExpand => '펼치기';
  @override
  String collapseImagesCount(int count) => '사진 접기 ($count)';

  @override
  String get statusLargeFileAwaitConfirm => '전송 확인 대기 중';
  @override
  String get statusGroupFileAwaitDownload => '그룹 파일 다운로드 대기';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      '파일 알림 전송됨 ($acked/$total)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      '전송 확인 대기 ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      '전체 전달 완료 ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) => '전달됨 ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => '원본 파일 제거됨';
  @override
  String get statusLocalFileDeleted => '로컬 파일 삭제됨';
  @override
  String get revokedByMe => '메시지 전송을 취소했습니다';
  @override
  String get revokedByPeer => '상대방이 메시지 전송을 취소했습니다';
  @override
  String get tooltipEditPeerRemark => '별칭 수정';
  @override
  String get tooltipPeerAvatar => '상대 기기';
  @override
  String get toastCopiedText => '텍스트가 복사되었습니다';
  @override
  String toastCopiedPath(String path) => '파일 경로 복사됨: $path';
  @override
  String get imageDeletedLocally => '로컬에서 삭제된 이미지';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · 원본 사진이 기기에서 제거됨';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · 사진이 기기에서 삭제됨 (탭하여 보기)';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · 원본 파일을 찾을 수 없음';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · 로컬에서 삭제됨';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · 대용량 파일 전송 확인 대기';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · 그룹 파일 수신 대기';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · 상대방의 수신 수락 대기 중';
  @override
  String btnDownloadToDevice(String sizeLabel) => '기기에 다운로드 ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => '지금 보내기 ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => '온라인 전환 시 자동 전송 예약';
  @override
  String get actionCopyText => '텍스트 복사';
  @override
  String get actionForward => '전달';
  @override
  String get actionOpenFile => '파일 열기';
  @override
  String get actionRevealInFolder => '폴더에서 보기';
  @override
  String get actionCopyFilePath => '파일 경로 복사';

  @override
  String get createGroupTitle => '암호화 공유 그룹 만들기';
  @override
  String get createGroupDesc =>
      '페어링된 기기를 선택해 바로 그룹을 만들 수 있으며(재스캔 불필요), 그룹 전용 종단간 암호화 키를 공유합니다.';
  @override
  String get groupNameOptionalLabel => '그룹 이름 (선택)';
  @override
  String get groupNameAutoHint => '비워 두면 선택한 기기 이름으로 자동 생성';
  @override
  String get createGroupNoPeersNotice =>
      '페어링된 기기가 없습니다. 먼저 그룹을 만든 뒤 오른쪽 위 QR 스캔으로 기기를 초대할 수 있습니다.';
  @override
  String selectGroupDevicesCount(int count) => '추가할 기기 선택 ($count대 선택됨):';
  @override
  String get btnCreateGroup => '그룹 만들기';
  @override
  String get defaultGroupNameFallback => '암호화 공유 그룹';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => '$joinedNames 그룹';
  @override
  String get nameSeparator => '·';
  @override
  String get addMembersToGroupTitle => '페어링된 기기를 그룹에 추가';
  @override
  String get btnConfirmInvite => '초대하기';
  @override
  String get allPeersAlreadyInGroupToast => '페어링된 모든 기기가 이미 그룹에 있습니다';
  @override
  String get subtitleDmE2ee => 'P2P 직통 · 종단간 암호화';
  @override
  String subtitleGroupE2ee(int count) => '공유 그룹 ($count대) · E2EE 키 격리';
  @override
  String get tooltipEditGroupName => '그룹 이름 수정';
  @override
  String get badgeThisTerminal => '내 기기';
  @override
  String get roleThisDevice => '내 기기 (변경 가능)';
  @override
  String get rolePeerDevice => '상대 기기';
  @override
  String get roleGroupMember => '그룹 멤버';
  @override
  String get tooltipEditSelfProfile => '기기 이름 및 프로필 사진 수정';
  @override
  String get tooltipRemoveFromGroup => '그룹에서 내보내기';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      '"$roomTitle"의 페어링을 해제하고 삭제할까요? (로컬에 저장된 파일은 유지됩니다)';
  @override
  String get deleteGroupTitle => '공유 그룹 삭제';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      '공유 그룹 "$roomTitle"과(와) 이 기기의 대화 기록을 삭제하시겠습니까? (저장된 파일은 삭제되지 않습니다)';
  @override
  String get btnDeleteAndLeave => '삭제 후 나가기';
  @override
  String get btnInviteNewDevice => '새 기기 초대 / 스캔';
  @override
  String get editGroupNameTitle => '공유 그룹 이름 수정';
  @override
  String get localDisplayNameLabel => '이 기기에서의 표시 이름';
  @override
  String editGroupNameHint(String defaultName) => '비워 두면 "$defaultName"(으)로 복원';
  @override
  String get editProfileSelfTitle => '내 기기 이름 및 아바타 변경';
  @override
  String get editProfilePeerTitle => '상대 기기 별칭 수정';
  @override
  String processImageFailed(Object error) => '이미지 처리 실패: $error';
  @override
  String get btnChangeAvatar => '아바타 변경';
  @override
  String get btnUploadAvatar => '아바타 업로드';
  @override
  String get btnRemoveImage => '이미지 제거';
  @override
  String get avatarSyncNoticeSelf => '업로드한 사진은 페어링된 기기에 암호화되어 자동 동기화됩니다';
  @override
  String get avatarSyncNoticePeer => '상대 기기 별칭만 이 기기에 저장되며, 아바타는 상대가 설정한 사진이 표시됩니다';
  @override
  String get selfDisplayNameLabel => '내 기기 표시 이름';
  @override
  String get peerRemarkNameLabel => '상대 기기 별칭';
  @override
  String get customDeviceNameHint => '사용자 지정 기기 이름 입력';
  @override
  String defaultNameDisplay(String fallbackModel) => '기본값: $fallbackModel';
  @override
  String get shareToTitle => '공유 대상...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "사진" : "파일"}: $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '${allImages ? "사진" : "파일"} $count개 · $size';
  @override
  String shareSummaryText(String text) => '텍스트: $text';
  @override
  String get sendToTitle => '받는 대상';
  @override
  String get targetTypeDm => '1:1 기기';
  @override
  String targetTypeGroup(int memberCount) => '공유 그룹 · $memberCount대';
  @override
  String get targetTypePairedPeer => '페어링된 기기 (P2P)';
  @override
  String get btnReselect => '다시 선택';
  @override
  String btnSendCount(int count) => '보내기 ($count)';
  @override
  String get btnSend => '보내기';
  @override
  String shareFileListMore(int count, String size) =>
      '등 총 $count개 파일 · $size';
  @override
  String shareFileListExact(int count, String size) => '총 $count개 파일 · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      '${isImage ? "사진" : "파일"} 전달: $fileName';
  @override
  String forwardSummaryText(String text) => '메시지 전달: $text';
  @override
  String get forwardToTitle => '전달 대상...';
  @override
  String get searchRoomOrDeviceHint => '대화방 또는 기기 검색...';
  @override
  String get noAvailableTargets => '선택 가능한 대화방이나 페어링된 기기가 없습니다';
  @override
  String get noMatchingTargets => '일치하는 대화방이나 기기가 없습니다';
  @override
  String get currentConversationLabel => '현재 대화';
  @override
  String get tooltipOpenWithDefaultApp => '기본 앱으로 열기';
  @override
  String get tooltipDeleteMessage => '메시지 삭제';
  @override
  String get tooltipClosePreview => '미리보기 닫기';
  @override
  String get deletedImagePreviewTitle => '로컬에서 삭제된 이미지';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '"$fileName"이(가) 로컬에서 삭제되어 원본 미리보기를 불러올 수 없습니다.';
  @override
  String get btnDeleteThisRecord => '이 메시지 기록 삭제';
  @override
  String get removeRevokeNoticeTitle => '삭제 안내';
  @override
  String get removeRevokeNoticeBody =>
      '원본 파일이 기기에서 제거된 뒤에도 내 화면의 메시지 기록만 안전하게 삭제할 수 있으며, 상대 기기에는 영향을 주지 않습니다.';
  @override
  String get deleteOutgoingFileTitle => '보낸 파일 삭제';
  @override
  String get deleteOutgoingTextTitle => '보낸 메시지 삭제';
  @override
  String get chooseDeleteMethod => '삭제 방식을 선택하세요:';
  @override
  String get deleteOutgoingFileDetail =>
      '• 모든 기기에서 전송 취소: 상대 기기와 릴레이 노드에 알림을 보내 상대 측 자동 저장 사본도 함께 삭제합니다.\n• 내 기기에서만 제거: 내 기록만 지우며 상대 기기의 파일과 기록은 유지됩니다.\n\n※ 내 기기의 원본 소스 파일은 절대 삭제되거나 수정되지 않습니다.';
  @override
  String get deleteOutgoingTextDetail =>
      '• 모든 기기에서 전송 취소: 멤버와 릴레이 노드에 삭제 알림을 보내 양쪽에서 모두 지웁니다.\n• 내 기기에서만 제거: 내 기기 기록에서만 제거합니다.';
  @override
  String get btnRemoveLocalOnly => '내 기기에서만 제거';
  @override
  String get btnRevokeForAll => '모두에게서 전송 취소';
  @override
  String get deleteIncomingFileTitle => '받은 파일 삭제';
  @override
  String get deleteIncomingTextTitle => '받은 메시지 삭제';
  @override
  String get deleteIncomingNote => '이 기기에서만 삭제되며 보낸 기기에는 영향을 주지 않습니다.';
  @override
  String get checkboxDeleteLocalFile => '기기에 저장된 파일도 함께 삭제';
  @override
  String get incomingFileAlreadyMissing => '로컬 파일이 이미 존재하지 않아 기록만 제거됩니다.';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      '이미지 미리보기 ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => '전송 확인 ($count개 파일)';
  @override
  String get btnAddMore => '더 추가';
  @override
  String batchLimitNotice(int maxFiles) =>
      '한 번에 최대 $maxFiles개까지 보낼 수 있어 앞 $maxFiles개만 유지되었습니다';
  @override
  String get tooltipPrevImage => '이전 이미지';
  @override
  String get tooltipNextImage => '다음 이미지';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '총 $count개 · $size${showEnterHint ? ' (Enter로 전송)' : ''}';

  @override
  String inviteGroupTitle(String roomName) => '"$roomName" 멤버 초대';
  @override
  String get inviteDeviceTitle => '기기 추가 / QR 페어링';
  @override
  String get tabGroupInviteQr => '그룹 초대 QR';
  @override
  String get tabDevicePairingQr => '내 페어링 QR';
  @override
  String get tabScanOrPaste => '스캔 / 붙여넣기';
  @override
  String get desktopQrImageUnsupported =>
      '데스크톱에서는 이미지 QR 인식을 지원하지 않습니다. 티켓 JSON을 직접 붙여넣어 주세요';
  @override
  String get noQrDetectedInImage => '선택한 이미지에서 QR 코드를 찾지 못했습니다. 더 선명한 이미지를 선택하세요';
  @override
  String galleryQrScanFailed(Object error) => '앨범 QR 스캔 실패: $error';
  @override
  String generateQrFailed(Object error) => 'QR 티켓 생성 실패: $error';
  @override
  String get joinOrPairFailedHint => '참여 또는 페어링에 실패했습니다. 티켓 내용이 올바른지 확인하세요';
  @override
  String groupInviteDesc(String roomName) =>
      '그룹 초대 QR: 상대가 스캔하면 "$roomName"에 바로 참여하고 E2EE 키를 동기화합니다.';
  @override
  String get devicePairingDesc =>
      '내 페어링 QR: 상대가 스캔하면 신뢰된 기기로 상호 연결되어 P2P 암호화 채널을 자동 구성합니다.';
  @override
  String get toastCopiedQrJson => '페어링 / 초대 티켓 JSON이 복사되었습니다';
  @override
  String get btnCopyTextTicket => '텍스트 티켓 복사';
  @override
  String get btnRetryGenerateQr => 'QR 다시 생성';
  @override
  String get scannerPermDenied => '카메라 권한이 없습니다. 권한을 허용하거나 앨범에서 QR 이미지를 선택하세요';
  @override
  String get scannerUnsupported =>
      '이 기기에서는 카메라 스캔을 사용할 수 없습니다. 앨범에서 이미지를 고르거나 티켓을 붙여넣으세요';
  @override
  String get scannerReinitializing => '카메라 채널을 재설정하는 중입니다. 잠시 후 다시 시도를 누르세요';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      '카메라를 열 수 없습니다 ($details)';
  @override
  String get scannerGenericError => '카메라를 시작할 수 없습니다. 다시 시도하거나 앨범에서 QR을 선택하세요';
  @override
  String get startingCamera => '카메라를 시작하는 중...';
  @override
  String get btnPickQrFromGallery => '앨범에서 QR 선택';
  @override
  String get btnRetryCamera => '다시 시도';
  @override
  String get pasteTicketDialogTitle => '티켓 붙여넣기로 참여';
  @override
  String get pasteTicketFieldHint => '방 초대 티켓 또는 기기 페어링 JSON 붙여넣기';
  @override
  String get btnJoinOrRegister => '참여 / 등록';
  @override
  String get cameraNotSupportedPlatform =>
      '이 플랫폼에서는 카메라 스캔이 지원되지 않습니다. 아래「티켓 붙여넣기」나 앨범을 이용하세요';
  @override
  String get qrViewfinderHint => '사각형 안에 QR 코드를 맞추면 자동으로 페어링 / 참여합니다';
  @override
  String get analyzingImageQr => '이미지의 QR 코드 분석 중...';
  @override
  String get verifyingHandshake => '암호화 핸드셰이크 확인 중...';
  @override
  String get actionGallery => '앨범';
  @override
  String get actionPasteTicket => '티켓 붙여넣기';
  @override
  String get actionTorchOff => '플래시 끄기';
  @override
  String get actionTorchOn => '플래시 켜기';
  @override
  String get windowsPasteTicketHint =>
      'Windows에서는「방 초대 티켓」을 직접 붙여넣어 같은 암호화 그룹에 연결할 수 있습니다.';
  @override
  String get btnAnalyzingQr => 'QR 코드 분석 중...';
  @override
  String get btnRestartCamera => '카메라 다시 시작';
  @override
  String get pasteTicketFieldLabel => '방 초대 티켓 또는 페어링 JSON 붙여넣기';
  @override
  String get btnJoinToThisDevice => '이 기기에 참여 / 등록';

  @override
  String get allFilesTitle => '모든 전송 파일';
  @override
  String get roomFilesTitle => '대화방 파일 기록';
  @override
  String get tooltipOpenMainReceiveFolder => '기본 수신 폴더 열기';
  @override
  String get searchFileNameHint => '파일 이름 검색...';
  @override
  String get allRoomsOption => '전체 대화방';
  @override
  String tabImagesCount(int count) => '사진 ($count)';
  @override
  String tabFilesCount(int count) => '파일 ($count)';
  @override
  String loadFilesFailed(String error) => '불러오기 실패: $error';
  @override
  String get emptyImagesNone => '이 대화방에는 아직 이미지가 없습니다';
  @override
  String get emptyImagesSearch => '일치하는 사진이 없습니다';
  @override
  String get emptyFilesNone => '이 대화방에는 아직 일반 파일이 없습니다';
  @override
  String get emptyFilesSearch => '일치하는 파일이 없습니다';
  @override
  String get badgeLocallyRemoved => '로컬 제거됨';
  @override
  String get unnamedFile => '이름 없는 파일';
  @override
  String get toastLocalFileMissing => '로컬 파일이 이동되었거나 삭제되었습니다';
  @override
  String get actionOpenShort => '열기';

  @override
  String get sectionGeneral => '일반';
  @override
  String get sectionReceiveStorage => '수신 및 저장소';
  @override
  String get sectionResidencyNetwork => '상시 실행 및 네트워크';
  @override
  String get sectionAbout => '정보';
  @override
  String deviceModelLabel(String model) => '기기 모델: $model';
  @override
  String get toastCopiedFullDeviceId => '전체 기기 ID가 복사되었습니다';
  @override
  String get tooltipEditNameAvatar => '이름 및 아바타 변경';
  @override
  String get toastThumbCacheCleared => '썸네일 캐시를 비웠습니다 (원본 사진 및 파일 유지)';
  @override
  String toastSaveDirUpdated(String dir) => '저장 폴더 변경됨: $dir';
  @override
  String saveDirNotWritable(Object error) => '선택한 폴더에 쓸 수 없습니다: $error';
  @override
  String get needAllFilesPermTitle => '「모든 파일 액세스」 권한 필요';
  @override
  String get needAllFilesPermBody =>
      'Android 공용「다운로드」폴더에 수신 파일을 직접 저장하려면 접근 권한을 허용해야 합니다.';
  @override
  String get btnGoGrant => '권한 설정';
  @override
  String get pickReceiveFolderDialogTitle => '수신 파일 저장 폴더 선택';
  @override
  String storageSizeSuffix(String size, int count) => ' ($size · $count개)';
  @override
  String get storageModeDownloads => '공용「다운로드 (Downloads)」폴더';
  @override
  String get storageModeDocuments => '공용「문서 (Documents)」폴더';
  @override
  String get storageModeCustomTitle => '사용자 지정 폴더';
  @override
  String storageModeCustom(String compactPath) => '사용자 지정 위치 ($compactPath)';
  @override
  String get storageModeAppPrivate => '앱 전용 공간 (Android/data)';
  @override
  String get receiveLocationTitle => '수신 파일 저장 위치';
  @override
  String get storageDownloadsDesc => '휴대폰 파일 앱이나 다른 앱에서 바로 찾을 수 있습니다';
  @override
  String get storageDocumentsDesc => '문서·자료 등 장기 보관 정리에 적합합니다';
  @override
  String storageCustomSelectedDesc(String compactPath) => '현재 경로: $compactPath';
  @override
  String get storageCustomUnselectedDesc => 'SD 카드 등 원하는 경로를 직접 지정할 수 있습니다';
  @override
  String get btnChange => '변경';
  @override
  String get storageAppPrivateTitle => '앱 전용 공간 (앱 제거 시 함께 삭제)';
  @override
  String get storageAppPrivateDesc => '갤러리나 일반 파일 탐색기에 표시되지 않으며 앱 삭제 시 함께 지워집니다';
  @override
  String get legacyStoragePermNotice =>
      '공용「다운로드」폴더에 저장하려면 저장소 쓰기 권한이 필요합니다';
  @override
  String get btnAuthorize => '권한 허용';
  @override
  String get btnChangeFolder => '폴더 변경';
  @override
  String get pickReceiveDirDialogTitle => '자동 수신 폴더 선택';
  @override
  String get windowsResidencyTitle => 'Windows 트레이 상시 실행 및 시작 프로그램';
  @override
  String get windowsCloseToTrayTitle => '닫기 버튼 클릭 시 시스템 트레이로 최소화';
  @override
  String get windowsCloseToTraySubtitle =>
      '오른쪽 위 × 를 누르면 트레이에 대기하며 파일 수신과 알림을 유지합니다';
  @override
  String get windowsAutoStartTitle => 'Windows 시작 시 백그라운드 자동 실행';
  @override
  String get windowsAutoStartSubtitle => '로그인 시 트레이로 조용히 시작됩니다 (--minimized)';
  @override
  String get btnHideToTrayNow => '지금 트레이로 숨기기';
  @override
  String get btnQuitBackgroundService => '백그라운드 서비스까지 완전히 종료';
  @override
  String get themeDialogTitle => '화면 테마 선택';
  @override
  String get themeSystemTitle => '시스템 설정 따름';
  @override
  String get themeSystemSubtitle => 'Windows / Android 라이트·다크 모드 자동 연동';
  @override
  String get themeLightTitle => '라이트 모드';
  @override
  String get themeLightSubtitle => '밝은 배경과 산뜻한 민트 톤';
  @override
  String get themeDarkTitle => '다크 모드';
  @override
  String get themeDarkSubtitle => '야간 사용 시 눈의 피로를 줄이는 어두운 테마';
  @override
  String get themeSystemShort => '시스템';
  @override
  String get themeLightShort => '라이트';
  @override
  String get themeDarkShort => '다크';
  @override
  String get languageDialogTitle => '앱 언어';
  @override
  String get languageSettingTitle => '앱 언어';
  @override
  String get languageSystemTitle => '시스템 언어 따름';
  @override
  String get languageSystemSubtitle => 'OS 언어 설정에 맞춰 자동으로 전환됩니다';
  @override
  String toastLanguageUpdated(String langName) => '언어가 "$langName"(으)로 변경되었습니다';
  @override
  String get storageManagerTitle => '저장소 및 캐시 관리';
  @override
  String storageRecvStats(String size, int count) => '사용 중 $size (총 $count개)';
  @override
  String get countingStats => '계산 중...';
  @override
  String get storageRecvUsedTitle => '받은 파일 저장 용량';
  @override
  String get thumbCacheTitle => '썸네일 미리보기 캐시';
  @override
  String thumbCacheDesc(String size) =>
      '현재 $size 사용 중 · 정리해도 저장된 원본 파일은 삭제되지 않습니다';
  @override
  String get btnClearThumbCache => '캐시 비우기';
  @override
  String get mobileStorageTitle => '저장소 및 캐시';
  @override
  String legendReceivedFiles(String size) => '수신 파일 $size';
  @override
  String legendThumbCache(String size) => '캐시 $size';
  @override
  String receivedFilesCountTitle(int count) => '받은 파일 ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => '썸네일 캐시 ($size)';
  @override
  String get thumbCacheNoTouchNotice => '삭제해도 원본 사진과 파일에는 영향이 없습니다';
  @override
  String get noCacheToClear => '지울 캐시가 없습니다';
  @override
  String btnClearThumbCacheWithSize(String size) => '썸네일 캐시 삭제 ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      '수신 $recvSize · 캐시 $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => '캐시 $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      '전체 $totalSize · 캐시 $cacheSize';
  @override
  String get storageAndCacheTitle => '저장소 및 캐시 관리';
  @override
  String get aboutTitle => 'P2P 프라이빗 전송 정보';
  @override
  String aboutVersion(String version) => '버전: $version';
  @override
  String get aboutBody =>
      '클라우드 서버나 용량 제한 없이 기기 간 직접 연결하는 종단간 암호화 P2P 전송 앱입니다.\n\n• 물리 NIC 고정: VPN/TUN 어댑터를 우회해 빠른 직통 연결\n• 다중 방 키 격리: 상시 홈 노드도 암호문만 보관하며 내용 열람 불가\n• USB 테더링 우선 경로: PC 인터넷 회선을 가로채지 않고 고속 전송 지원';
  @override
  String get aboutSubtitle => '종단간 암호화 크로스 플랫폼 전송 · 서버 없음';
  @override
  String get networkDiagTitle => '고급 네트워크 및 연결 진단';
  @override
  String get networkDiagLoading => '로컬 네트워크 환경 진단 중...';
  @override
  String networkDiagDesktopReady(int count) =>
      '준비됨 · LAN/USB 직통 어댑터 $count개 감지 (일반 사용 시 설정 불필요)';
  @override
  String get networkDiagDesktopWanOnly => '외부 P2P 암호화 채널 (LAN 직통 미감지)';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB 준비됨 · 어댑터 $count개 감지';
  @override
  String get networkDiagMobileWanOnly => '현재: 외부 암호화 채널';
  @override
  String get nicDetectionTitle => '물리 LAN / USB 네트워크 어댑터 (VPN 우회)';
  @override
  String get nicDetectionDesc =>
      'Clash · Mihomo · WireGuard 등 가상 TUN 어댑터를 자동 제외하고 실제 물리 NIC에만 바인딩합니다.';
  @override
  String get nicReading => '네트워크 어댑터 확인 중...';
  @override
  String get nicNoneConnected => '연결된 물리 LAN / USB 어댑터가 없습니다';
  @override
  String get btnRefreshNics => 'NIC 상태 새로고침';
  @override
  String get usbProtectionTitle => 'USB 테더링 고속 직통 라우팅 보호 (Windows)';
  @override
  String get usbProtectionDesc =>
      'Android 기기에서「USB 테더링」을 켜면 메트릭을 자동으로 5000으로 격리하여 PC의 기본 인터넷을 유지하면서 42420 포트 고속 직통 전송을 지원합니다.';
  @override
  String get usbProtectionReady => '준비됨: USB 라우팅 하이재킹 방지됨 (Metric=5000)';
  @override
  String usbProtectionNeedsFix(String detail) => '자동 수정 필요: $detail';
  @override
  String get usbProtectionNotPlugged =>
      '미연결: 스마트폰에서 USB 테더링이 켜지면 자동으로 감지해 보호합니다';
  @override
  String get btnFixMetric => '메트릭 수정';
  @override
  String get customRelayTitle => '사용자 지정 릴레이 서버 (Relay · 고급)';
  @override
  String get customRelayDesc =>
      '동일 LAN이 아니고 외부 P2P 직통이 실패할 때 릴레이 서버가 암호화된 패킷만 중계합니다(E2EE 적용으로 내용 열람 불가). 일반 사용자는 비워 두시면 기본 무료 릴레이가 사용됩니다.';
  @override
  String get customRelayLabel => 'Relay 서버 URL (비워 두면 기본 공용 릴레이 사용)';
  @override
  String get toastRelaySaved => '릴레이 주소 설정이 저장되었습니다';
  @override
  String get btnSaveRelay => '릴레이 설정 저장';
  @override
  String get deviceIdLabel => '기기 ID';
  @override
  String get btnCopyDeviceId => '전체 기기 ID 복사';
  @override
  String get deviceIdCopiedBadge => '복사됨';

  @override
  String toastEventStreamError(Object error) => '이벤트 스트림 오류: $error';
  @override
  String toastCreatedRoom(String name) => '암호화 방 "$name"이(가) 생성되었습니다';
  @override
  String toastCreateRoomFailed(Object error) => '방 생성 실패: $error';
  @override
  String toastOpenChatFailed(Object error) => '대화방 열기 실패: $error';
  @override
  String toastCreatedGroup(String name) => '새 공유 그룹 "$name"이(가) 생성되었습니다';
  @override
  String toastCreateGroupFailed(Object error) => '그룹 생성 실패: $error';
  @override
  String toastJoinedRoom(String name) => '암호화 방 "$name"에 참여했습니다';
  @override
  String toastAddedDevice(String name) => '기기 "$name"이(가) 추가되었습니다';
  @override
  String toastPairFailed(Object error) => '페어링 또는 참여 실패: $error';
  @override
  String toastSendTextFailed(Object error) => '메시지 전송 실패: $error';
  @override
  String get toastSelectRoomFirst => '먼저 보낼 대화방이나 기기를 선택하세요';
  @override
  String toastSendFileFailed(String path, Object error) =>
      '파일 전송 실패 ($path): $error';
  @override
  String get toastForwardFileMissing => '로컬 파일이 없어 전달할 수 없습니다';
  @override
  String get toastForwardEmptyText => '내용이 비어 있어 전달할 수 없습니다';
  @override
  String get fallbackTargetRoom => '대상 대화방';
  @override
  String toastForwardedTo(String targetName) => '"$targetName"(으)로 전달됨';
  @override
  String toastForwardFailed(Object error) => '전달 실패: $error';
  @override
  String get fallbackBigFile => '대용량 파일';
  @override
  String toastConfirmedSend(String fileName) => '"$fileName" 전송을 확정했습니다';
  @override
  String toastConfirmSendFailed(Object error) => '전송 확정 실패: $error';
  @override
  String get fallbackFile => '파일';
  @override
  String toastPullingFile(String fileName) => '"$fileName" 수신을 시작했습니다';
  @override
  String toastPullFileFailed(Object error) => '파일 수신 실패: $error';
  @override
  String get toastPeerDeleted => '페어링된 기기가 삭제되었습니다';
  @override
  String toastDeletePeerFailed(Object error) => '기기 삭제 실패: $error';
  @override
  String get toastRoomDeleted => '대화방이 삭제되었습니다';
  @override
  String toastDeleteRoomFailed(Object error) => '대화방 삭제 실패: $error';
  @override
  String get toastDeletedRecordAndFile => '기록과 로컬 저장 파일을 삭제했습니다';
  @override
  String get toastRemovedLocalRecord => '이 기기의 기록에서 제거되었습니다';
  @override
  String toastDeleteMsgFailed(Object error) => '메시지 삭제 실패: $error';
  @override
  String get toastOnlyRevokeOwn => '본인이 보낸 메시지만 전송 취소할 수 있습니다';
  @override
  String get toastRevokedForAll => '전송이 취소되어 상대 기기에도 삭제를 알렸습니다';
  @override
  String toastRevokeFailed(Object error) => '전송 취소 실패: $error';
  @override
  String toastInvitedMembers(int count) => '$count대의 기기를 그룹에 초대했습니다';
  @override
  String toastAddMembersFailed(Object error) => '그룹 멤버 추가 실패: $error';
  @override
  String get toastRemovedMember => '해당 기기를 그룹에서 내보냈습니다';
  @override
  String toastRemoveMemberFailed(Object error) => '멤버 내보내기 실패: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => 'USB 메트릭 수정 실패: $error';
  @override
  String toastReceiveDirFallback(String dir) => '파일 수신 폴더: $dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => '자동 저장 폴더 변경됨: $dir';
  @override
  String get toastClearedCustomSaveDir =>
      '사용자 지정 저장 폴더 설정을 지웠습니다. 기본 폴더가 사용됩니다';
  @override
  String toastSetDirFailed(Object error) => '폴더 설정 실패: $error';
  @override
  String toastSyncAvatarFailed(Object error) => '아바타 동기화 실패: $error';
  @override
  String get toastSelfProfileUpdated => '내 프로필을 업데이트하고 온라인 기기에 동기화했습니다';
  @override
  String get toastPeerRemarkUpdated => '기기 별칭이 업데이트되었습니다';
  @override
  String get toastRestoredGroupName => '기본 그룹 이름으로 복원했습니다';
  @override
  String get toastUpdatedGroupName => '로컬 그룹 이름을 업데이트했습니다';
  @override
  String get toastAutoStartEnabled => '부팅 시 조용한 자동 실행이 켜졌습니다';
  @override
  String get toastAutoStartDisabled => '부팅 시 자동 실행이 꺼졌습니다';
  @override
  String get toastCloseToTrayEnabled => '창 닫기 시 시스템 트레이로 최소화합니다';
  @override
  String get toastCloseToTrayDisabled => '창 닫기 시 프로그램이 종료됩니다';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      '$sender에게서 파일 수신: $fileName';
  @override
  String get notifyFileFallbackBody => '새 파일이 자동 저장되었습니다';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      '$fileLabel 등 총 $totalCount개 파일 수신 중';
  @override
  String notifyNewFileTitle(String sender) => '새 파일 · $sender';
  @override
  String notifyNewTextTitle(String sender) => '새 메시지 · $sender';
  @override
  String get notifyNewEncryptedText => '새 암호화 텍스트 메시지';
  @override
  String get errorEmptyImageFile => '선택한 이미지 파일이 비어 있습니다';
  @override
  String get errorCompressAvatarFailed => '아바타 이미지를 압축할 수 없습니다';
  @override
  String get errorPngEncodeFailed => 'PNG 인코딩 실패';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'USB 테더링 어댑터가 감지되지 않았습니다';
    if (metricProtected) {
      return 'USB 어댑터 메트릭이 5000으로 보호되어 PC 인터넷 회선에 영향을 주지 않습니다';
    }
    if (needsElevation) {
      return 'USB 어댑터 메트릭을 5000으로 설정하려면 관리자 권한이 필요합니다';
    }
    return 'USB 테더링이 감지되어 라우팅 메트릭 격리 대기 중입니다';
  }

  @override
  String get winTrayTooltip => 'P2P 프라이빗 전송 · 상시 백그라운드 서비스';
  @override
  String get winTrayOpenWindow => '기본 창 열기';
  @override
  String get winTrayAutoStart => '부팅 시 최소화로 자동 실행';
  @override
  String get winTrayCloseToTray => '닫을 때 트레이로 최소화';
  @override
  String get winTrayExitApp => '프로그램 완전히 종료';
}
