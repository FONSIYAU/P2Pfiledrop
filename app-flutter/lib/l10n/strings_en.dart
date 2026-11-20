import 'app_strings.dart';

class StringsEn extends AppStrings {
  const StringsEn();

  static const _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  String get localeCode => 'en';

  @override
  String get appTitle => 'P2Pfiledrop';
  @override
  String get appSubtitle => 'End-to-End Encrypted Transfer';
  @override
  String get startingEngine => 'Starting P2P encrypted transfer engine...';
  @override
  String engineInitFailed(Object error) => 'Engine initialization failed:\n$error';
  @override
  String get retry => 'Retry';
  @override
  String get cancel => 'Cancel';
  @override
  String get confirm => 'OK';
  @override
  String get close => 'Close';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get remove => 'Remove';
  @override
  String get open => 'Open';
  @override
  String get refresh => 'Refresh';
  @override
  String get clear => 'Clear';
  @override
  String get resetDefault => 'Reset Default';
  @override
  String get recommendedBadge => 'Recommended';
  @override
  String get defaultAvatarFallback => 'D';

  @override
  String formatFullDate(DateTime dt) =>
      '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  @override
  String formatMonthDay(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}';
  @override
  String get todayLabel => 'Today';
  @override
  String get yesterdayLabel => 'Yesterday';
  @override
  String formatRemainingSeconds(int seconds) => '${seconds}s left';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      '${minutes}m ${seconds}s left';

  @override
  String get navTransfers => 'Transfers';
  @override
  String get navDevices => 'Devices';
  @override
  String get navThisDevice => 'Me';
  @override
  String get navAdd => 'Add';
  @override
  String get navFiles => 'Files';
  @override
  String get navFolder => 'Folder';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName (Tap to open Settings)';
  @override
  String get tooltipScanPair => 'Scan QR to pair device / join group';
  @override
  String get tooltipAllFiles => 'Browse all transferred files & photos';
  @override
  String tooltipOpenReceiveFolder(String dir) => 'Open receive folder ($dir)';

  @override
  String get transportUsbTether => 'USB Tether';
  @override
  String get transportLanDirect => 'LAN Direct';
  @override
  String get transportWanP2p => 'WAN P2P';
  @override
  String get transportWanRelay => 'Relay';
  @override
  String get transportOffline => 'Offline';
  @override
  String get usbTetherTag => 'USB Tether';

  @override
  String get msgStatusQueuedOffline => 'Waiting for peer';
  @override
  String get msgStatusHandshaking => 'Handshaking';
  @override
  String get msgStatusTransferring => 'Transferring';
  @override
  String get msgStatusPausedReconnecting => 'Resuming';
  @override
  String get msgStatusAwaitingDownload => 'Tap to download';
  @override
  String get msgStatusDelivered => 'Delivered';
  @override
  String get msgStatusFailedSourceMissing => 'Source file missing';

  @override
  String deviceWithTag(String tag) => '$tag Device';
  @override
  String deviceShortIdLabel(String shortId) => 'Device · $shortId';
  @override
  String get peerDeviceFallback => 'Peer Device';
  @override
  String get defaultPersonalRoomName => 'Personal Devices';
  @override
  String get defaultEncryptedGroupName => 'Encrypted Group';
  @override
  String get defaultPrivateRoomName => 'Private Encrypted Room';
  @override
  String encryptedRoomWithId(String shortId) => 'Encrypted Room $shortId';
  @override
  String get homeNodeDefaultName => 'Home Blind-Locker Node';

  @override
  String get chatListTitle => 'Transfers';
  @override
  String get chatListNewActionTooltip => 'New Group / Pair Device';
  @override
  String get menuScanPairOrJoin => 'Scan QR to Pair / Join';
  @override
  String get menuCreateGroup => 'New Multi-Device Group';
  @override
  String get menuMyPairingQr => 'My Pairing QR Code';
  @override
  String get menuOpenReceiveFolder => 'Open Receive Folder';
  @override
  String get menuProbeReconnect => 'Probe & Reconnect Now';
  @override
  String get searchChatsHint => 'Search chats or devices...';
  @override
  String groupOnlineCount(int online, int total) => '$online/$total online';
  @override
  String groupOfflineCount(int total) => 'Offline · $total devices';
  @override
  String get emptyChatsSearch => 'No matching chats or devices';
  @override
  String get emptyChatsNoRooms =>
      'No transfers yet\nPair a device to send encrypted files and messages directly';
  @override
  String get btnScanPairDevice => 'Scan to Pair Device';
  @override
  String get btnGoToDevices => 'Go to Devices';

  @override
  String get devicesListTitle => 'Devices';
  @override
  String get searchPairedDevicesHint => 'Search paired devices...';
  @override
  String get btnAddNewDevice => 'Add Device';
  @override
  String get btnNewSharedGroup => 'New Group';
  @override
  String get btnAddDeviceShort => 'Add Device';
  @override
  String get btnNewGroupShort => 'New Group';
  @override
  String pairedDevicesCount(int count) => 'Paired Devices ($count)';
  @override
  String get emptyDevicesSearch => 'No matching devices found';
  @override
  String get emptyDevicesNone =>
      'No paired devices yet\nTap "Add Device / Scan QR" above to connect';
  @override
  String get selectDevicePrompt =>
      'Select a device on the left to view details or start transferring';
  @override
  String get btnScanFirstDevice => 'Scan to Add First Device';
  @override
  String originalNameLabel(String name) => 'Original name: $name';
  @override
  String get deviceNodeIdLabel => 'Device Node ID';
  @override
  String get tooltipCopyDeviceId => 'Copy Device ID';
  @override
  String get toastCopiedDeviceId => 'Device ID copied';
  @override
  String get btnSendMessageOrFile => 'Send Message / File';
  @override
  String get btnEditRemark => 'Edit Alias';
  @override
  String get btnDeleteDevice => 'Remove Device';
  @override
  String get deletePeerDialogTitle => 'Remove Paired Device';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      'Remove "$resolvedName"?\n\nThis will unpair the device and clear its 1-on-1 chat history. Files already saved on this device will not be deleted.';
  @override
  String get btnConfirmDelete => 'Remove';

  @override
  String get desktopWorkspaceTitle => 'P2P Encrypted Transfer Workspace';
  @override
  String get btnOpenFolder => 'Open Folder';
  @override
  String get tooltipRoomFiles => 'Shared Files & Photos';
  @override
  String get tooltipInviteOrScan => 'Invite Device / Scan QR';
  @override
  String get tooltipRoomMembers => 'Room Members & Settings';
  @override
  String get desktopEmptyTitle => 'Select a conversation to start transferring';
  @override
  String get desktopEmptySubtitle =>
      'Drag & drop files, Ctrl+V to paste screenshots or files, direct LAN/USB transfer';
  @override
  String get moreActionsTooltip => 'More Actions';
  @override
  String get moreTooltip => 'More';
  @override
  String get emptyRoomNoSession => 'No active session. Pair a device to begin.';
  @override
  String get emptyRoomE2eeNotice =>
      'All messages and files are end-to-end encrypted with this room\'s isolated key';
  @override
  String get emptyRoomWindowsHint =>
      'Drop files here or press Ctrl+V to paste · Gigabit LAN & USB Tether ready';
  @override
  String get emptyRoomMobileHint =>
      'Tap + below to send files, or Share directly from other apps';
  @override
  String dropZonePrompt(String roomTitle) =>
      'Drop files to send encrypted to "$roomTitle"';
  @override
  String get menuAddPairedToGroup => 'Add Paired Devices to Group';
  @override
  String get menuDeviceDetailsAndRemark => 'Device Details & Alias';
  @override
  String get menuGroupMembersAndManage => 'Group Members & Settings';
  @override
  String get noShareTargetsToast =>
      'No paired devices or rooms available. Please pair a device first.';
  @override
  String get fallbackShortTitle => 'P2P Transfer';

  @override
  String get tooltipGalleryImages => 'Gallery Photos';
  @override
  String get tooltipSendFile => 'Send File';
  @override
  String get tooltipSendImageOrFile => 'Send Original Photos or Files';
  @override
  String get tooltipPasteClipboard => 'Paste Image or File (Ctrl+V)';
  @override
  String get inputHintWindows => 'Type a message, paste, or drop files...';
  @override
  String get inputHintMobile => 'Type a message or paste...';
  @override
  String get inputHintNoRoom => 'Create or join a room first';
  @override
  String get tooltipSendMessage => 'Send Message';

  @override
  String get newMessagesBelowSuffix => ' new';
  @override
  String albumFailedCount(int failedCount) => '$failedCount failed';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      'All delivered · $missingCount source files missing';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      'All delivered · $missingCount removed locally';
  @override
  String get albumAllDelivered => 'All delivered';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      'Transferring $delivered/$total';
  @override
  String albumImageCount(int count) => '$count photos';
  @override
  String get btnExpand => 'Expand';
  @override
  String collapseImagesCount(int count) => 'Collapse $count photos';

  @override
  String get statusLargeFileAwaitConfirm => 'Awaiting send confirmation';
  @override
  String get statusGroupFileAwaitDownload => 'Group file · Tap to download';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      'Offer sent ($acked/$total downloaded)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      'Confirm needed ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      'Delivered to all ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) => 'Delivered ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => 'Source file removed';
  @override
  String get statusLocalFileDeleted => 'Removed locally';
  @override
  String get revokedByMe => 'You unsent this message';
  @override
  String get revokedByPeer => 'Peer unsent this message';
  @override
  String get tooltipEditPeerRemark => 'Tap to edit device alias';
  @override
  String get tooltipPeerAvatar => 'Peer device avatar';
  @override
  String get toastCopiedText => 'Text copied';
  @override
  String toastCopiedPath(String path) => 'Path copied: $path';
  @override
  String get imageDeletedLocally => 'Photo removed from this device';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · Original source file removed';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · Photo deleted locally (tap to view)';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · Source file no longer at original path';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · File deleted locally';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · Tap below to confirm sending';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · Shared group file, tap to download';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · Card sent, waiting for members to download';
  @override
  String btnDownloadToDevice(String sizeLabel) => 'Download ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) =>
      'Peer Online · Send Now ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => 'Queue Send (Auto-send when online)';
  @override
  String get actionCopyText => 'Copy Text';
  @override
  String get actionForward => 'Forward';
  @override
  String get actionOpenFile => 'Open File';
  @override
  String get actionRevealInFolder => 'Reveal in Folder';
  @override
  String get actionCopyFilePath => 'Copy File Path';

  @override
  String get createGroupTitle => 'New Multi-Device Group';
  @override
  String get createGroupDesc =>
      'Select paired devices to create a group without re-scanning. Members share an isolated E2EE key.';
  @override
  String get groupNameOptionalLabel => 'Group Name (Optional)';
  @override
  String get groupNameAutoHint => 'Leave blank to auto-name from selected devices';
  @override
  String get createGroupNoPeersNotice =>
      'No paired devices yet. You can create the group now and invite devices via QR code later.';
  @override
  String selectGroupDevicesCount(int count) =>
      'Select devices ($count selected):';
  @override
  String get btnCreateGroup => 'Create Group';
  @override
  String get defaultGroupNameFallback => 'Encrypted Group';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => '$joinedNames Group';
  @override
  String get nameSeparator => ', ';
  @override
  String get addMembersToGroupTitle => 'Add Paired Devices to Group';
  @override
  String get btnConfirmInvite => 'Invite';
  @override
  String get allPeersAlreadyInGroupToast =>
      'All paired devices are already in this group';
  @override
  String get subtitleDmE2ee => 'Direct P2P · End-to-End Encrypted';
  @override
  String subtitleGroupE2ee(int count) =>
      'Group ($count devices) · Isolated E2EE Key';
  @override
  String get tooltipEditGroupName => 'Edit Group Name';
  @override
  String get badgeThisTerminal => 'This Device';
  @override
  String get roleThisDevice => 'This Device';
  @override
  String get rolePeerDevice => 'Peer Device';
  @override
  String get roleGroupMember => 'Member';
  @override
  String get tooltipEditSelfProfile => 'Edit Name & Avatar';
  @override
  String get tooltipRemoveFromGroup => 'Remove from Group';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      'Remove "$roomTitle" and clear 1-on-1 chat history?';
  @override
  String get deleteGroupTitle => 'Delete Group';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      'Delete group "$roomTitle" and clear local transfer history?';
  @override
  String get btnDeleteAndLeave => 'Delete & Leave';
  @override
  String get btnInviteNewDevice => 'Invite Device';
  @override
  String get editGroupNameTitle => 'Edit Group Name';
  @override
  String get localDisplayNameLabel => 'Local Display Name';
  @override
  String editGroupNameHint(String defaultName) =>
      'Applies to this device only. Leave blank to restore "$defaultName".';
  @override
  String get editProfileSelfTitle => 'Edit Device Name & Avatar';
  @override
  String get editProfilePeerTitle => 'Edit Device Alias';
  @override
  String processImageFailed(Object error) => 'Failed to process image: $error';
  @override
  String get btnChangeAvatar => 'Change Avatar';
  @override
  String get btnUploadAvatar => 'Upload Avatar';
  @override
  String get btnRemoveImage => 'Remove Image';
  @override
  String get avatarSyncNoticeSelf =>
      'Uploaded avatars sync automatically over E2EE to paired devices';
  @override
  String get avatarSyncNoticePeer =>
      'Avatars are synced from the peer device; customize its local alias below';
  @override
  String get selfDisplayNameLabel => 'Device Display Name';
  @override
  String get peerRemarkNameLabel => 'Device Alias';
  @override
  String get customDeviceNameHint => 'Enter custom device name';
  @override
  String defaultNameDisplay(String fallbackModel) => 'Default: $fallbackModel';
  @override
  String get shareToTitle => 'Share to...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "Photo" : "File"}: $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '$count ${allImages ? "photos" : "files"} · $size';
  @override
  String shareSummaryText(String text) => 'Text: $text';
  @override
  String get sendToTitle => 'Send to';
  @override
  String get targetTypeDm => 'Direct Device';
  @override
  String targetTypeGroup(int memberCount) => 'Group · $memberCount devices';
  @override
  String get targetTypePairedPeer => 'Paired Device (Direct P2P)';
  @override
  String get btnReselect => 'Reselect';
  @override
  String btnSendCount(int count) => 'Send ($count)';
  @override
  String get btnSend => 'Send';
  @override
  String shareFileListMore(int count, String size) =>
      'and more ($count files total) · $size';
  @override
  String shareFileListExact(int count, String size) => '$count files · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      'Forward ${isImage ? "photo" : "file"}: $fileName';
  @override
  String forwardSummaryText(String text) => 'Forward message: $text';
  @override
  String get forwardToTitle => 'Forward to...';
  @override
  String get searchRoomOrDeviceHint => 'Search devices or groups...';
  @override
  String get noAvailableTargets => 'No rooms or paired devices available';
  @override
  String get noMatchingTargets => 'No matching rooms or devices';
  @override
  String get currentConversationLabel => 'Current chat';
  @override
  String get tooltipOpenWithDefaultApp => 'Open with Default App';
  @override
  String get tooltipDeleteMessage => 'Delete Message';
  @override
  String get tooltipClosePreview => 'Close Preview';
  @override
  String get deletedImagePreviewTitle => 'Photo Removed Locally';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '"$fileName" is no longer on this device, so the preview cannot be loaded.';
  @override
  String get btnDeleteThisRecord => 'Delete This Record';
  @override
  String get removeRevokeNoticeTitle => 'Remove Notice';
  @override
  String get removeRevokeNoticeBody =>
      'Remove this unsent notice from your local history?';
  @override
  String get deleteOutgoingFileTitle => 'Delete Sent File/Photo';
  @override
  String get deleteOutgoingTextTitle => 'Delete Sent Message';
  @override
  String get chooseDeleteMethod => 'Choose how to delete:';
  @override
  String get deleteOutgoingFileDetail =>
      '• Unsend for Everyone: Notify peers & relay nodes to delete this message and auto-saved copies.\n• Remove Locally Only: Clear this record only on your device; peers keep their copy.\n\nYour original source file will never be deleted or modified.';
  @override
  String get deleteOutgoingTextDetail =>
      '• Unsend for Everyone: Notify all members & relay nodes to remove this message.\n• Remove Locally Only: Clear this record only on your device.';
  @override
  String get btnRemoveLocalOnly => 'Remove Locally';
  @override
  String get btnRevokeForAll => 'Unsend for Everyone';
  @override
  String get deleteIncomingFileTitle => 'Delete Received File';
  @override
  String get deleteIncomingTextTitle => 'Delete Received Message';
  @override
  String get deleteIncomingNote =>
      'Deletes only on this device without affecting the sender.';
  @override
  String get checkboxDeleteLocalFile => 'Also delete locally saved file';
  @override
  String get incomingFileAlreadyMissing =>
      'Local file no longer exists; only this record will be removed.';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      'Preview ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => 'Confirm Send ($count files)';
  @override
  String get btnAddMore => 'Add More';
  @override
  String batchLimitNotice(int maxFiles) =>
      'Up to $maxFiles files per batch; kept the first $maxFiles.';
  @override
  String get tooltipPrevImage => 'Previous';
  @override
  String get tooltipNextImage => 'Next';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '$count items · $size${showEnterHint ? ' (Enter to send)' : ''}';

  @override
  String inviteGroupTitle(String roomName) => 'Invite to Group · $roomName';
  @override
  String get inviteDeviceTitle => 'Pair Device / Scan QR';
  @override
  String get tabGroupInviteQr => 'Group Invite QR';
  @override
  String get tabDevicePairingQr => 'My Pairing QR';
  @override
  String get tabScanOrPaste => 'Scan / Paste';
  @override
  String get desktopQrImageUnsupported =>
      'Image QR decoding is not supported on desktop yet. Please paste the ticket JSON directly.';
  @override
  String get noQrDetectedInImage =>
      'No QR code found in the selected image. Try a clearer image.';
  @override
  String galleryQrScanFailed(Object error) => 'Failed to scan QR image: $error';
  @override
  String generateQrFailed(Object error) => 'Failed to generate QR code: $error';
  @override
  String get joinOrPairFailedHint =>
      'Failed to parse or join. Please verify the ticket is complete.';
  @override
  String groupInviteDesc(String roomName) =>
      'Group Invite: Scanning this joins "$roomName" and syncs its E2EE key.';
  @override
  String get devicePairingDesc =>
      'Device Pairing QR: Scanning this pairs as trusted devices and sets up a direct E2EE channel.';
  @override
  String get toastCopiedQrJson => 'Copied pairing / invite ticket JSON';
  @override
  String get btnCopyTextTicket => 'Copy Ticket Text';
  @override
  String get btnRetryGenerateQr => 'Retry QR';
  @override
  String get scannerPermDenied =>
      'Camera permission denied. Allow camera access or pick a QR image from Gallery.';
  @override
  String get scannerUnsupported =>
      'Camera scanning unavailable on this device. Pick a QR image or paste a ticket.';
  @override
  String get scannerReinitializing =>
      'Camera channel is resetting. Tap Retry to open the camera.';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      'Unable to start camera ($details)';
  @override
  String get scannerGenericError =>
      'Unable to start camera. Tap Retry or pick a QR image from Gallery.';
  @override
  String get startingCamera => 'Starting camera...';
  @override
  String get btnPickQrFromGallery => 'Pick QR from Gallery';
  @override
  String get btnRetryCamera => 'Retry Camera';
  @override
  String get pasteTicketDialogTitle => 'Paste Ticket to Join';
  @override
  String get pasteTicketFieldHint => 'Paste room invite or device pairing JSON';
  @override
  String get btnJoinOrRegister => 'Join / Pair';
  @override
  String get cameraNotSupportedPlatform =>
      'Camera scanning is not supported on this platform. Use "Paste Ticket" or pick an image.';
  @override
  String get qrViewfinderHint =>
      'Align the QR code inside the frame to pair or join automatically';
  @override
  String get analyzingImageQr => 'Scanning QR from image...';
  @override
  String get verifyingHandshake => 'Verifying handshake...';
  @override
  String get actionGallery => 'Gallery';
  @override
  String get actionPasteTicket => 'Paste';
  @override
  String get actionTorchOff => 'Torch Off';
  @override
  String get actionTorchOn => 'Torch';
  @override
  String get windowsPasteTicketHint =>
      'Paste a room invite or device pairing ticket below to pair and transfer directly over E2EE.';
  @override
  String get btnAnalyzingQr => 'Scanning QR...';
  @override
  String get btnRestartCamera => 'Restart Camera';
  @override
  String get pasteTicketFieldLabel => 'Paste room invite or device pairing JSON';
  @override
  String get btnJoinToThisDevice => 'Join / Pair to This Device';

  @override
  String get allFilesTitle => 'All Files';
  @override
  String get roomFilesTitle => 'Room Files';
  @override
  String get tooltipOpenMainReceiveFolder => 'Open Main Receive Folder';
  @override
  String get searchFileNameHint => 'Search file names...';
  @override
  String get allRoomsOption => 'All Rooms';
  @override
  String tabImagesCount(int count) => 'Photos ($count)';
  @override
  String tabFilesCount(int count) => 'Files ($count)';
  @override
  String loadFilesFailed(String error) => 'Failed to load files: $error';
  @override
  String get emptyImagesNone => 'No photos transferred yet';
  @override
  String get emptyImagesSearch => 'No matching photos';
  @override
  String get emptyFilesNone => 'No files transferred yet';
  @override
  String get emptyFilesSearch => 'No matching files';
  @override
  String get badgeLocallyRemoved => 'Removed locally';
  @override
  String get unnamedFile => 'Unnamed file';
  @override
  String get toastLocalFileMissing => 'Local file does not exist or was moved';
  @override
  String get actionOpenShort => 'Open';

  @override
  String get sectionGeneral => 'General';
  @override
  String get sectionReceiveStorage => 'Storage & Receiving';
  @override
  String get sectionResidencyNetwork => 'Background & Network';
  @override
  String get sectionAbout => 'About';
  @override
  String deviceModelLabel(String model) => 'Model: $model';
  @override
  String get toastCopiedFullDeviceId => 'Full Device ID copied';
  @override
  String get tooltipEditNameAvatar => 'Edit Name & Avatar';
  @override
  String get toastThumbCacheCleared => 'Thumbnail cache cleared';
  @override
  String toastSaveDirUpdated(String dir) => 'Receive folder updated: $dir';
  @override
  String saveDirNotWritable(Object error) =>
      'Folder is not writable. Check permissions or path ($error)';
  @override
  String get needAllFilesPermTitle => 'All Files Access Required';
  @override
  String get needAllFilesPermBody =>
      'Saving to a custom folder requires "All files access" permission.\n\nGrant it in system settings and return here to choose any folder.';
  @override
  String get btnGoGrant => 'Grant Access';
  @override
  String get pickReceiveFolderDialogTitle => 'Choose Receive Folder';
  @override
  String storageSizeSuffix(String size, int count) => ' · $size ($count files)';
  @override
  String get storageModeDownloads => 'Downloads Folder';
  @override
  String get storageModeDocuments => 'Documents Folder';
  @override
  String get storageModeCustomTitle => 'Custom folder';
  @override
  String storageModeCustom(String compactPath) => 'Custom ($compactPath)';
  @override
  String get storageModeAppPrivate => 'App-Private Storage';
  @override
  String get receiveLocationTitle => 'Receive Save Location';
  @override
  String get storageDownloadsDesc =>
      'Download/P2PChat · Organized by month, visible to Files & kept after uninstall';
  @override
  String get storageDocumentsDesc =>
      'Documents/P2PChat · Separate from browser downloads';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      'Selected: $compactPath · Tap to change';
  @override
  String get storageCustomUnselectedDesc =>
      'Pick any folder on device (requires All Files Access)';
  @override
  String get btnChange => 'Change';
  @override
  String get storageAppPrivateTitle => 'App-Private Only (Hidden)';
  @override
  String get storageAppPrivateDesc =>
      'Hidden from Gallery & Files; removed if app is uninstalled';
  @override
  String get legacyStoragePermNotice =>
      'Android 9 and below require storage permission for public folders';
  @override
  String get btnAuthorize => 'Authorize';
  @override
  String get btnChangeFolder => 'Change Folder';
  @override
  String get pickReceiveDirDialogTitle => 'Choose Receive Directory';
  @override
  String get windowsResidencyTitle => 'Windows Background Residency';
  @override
  String get windowsCloseToTrayTitle => 'Minimize to tray when closing window';
  @override
  String get windowsCloseToTraySubtitle =>
      'Clicking × hides to tray and keeps receiving files silently';
  @override
  String get windowsAutoStartTitle => 'Launch silently on Windows startup';
  @override
  String get windowsAutoStartSubtitle =>
      'Auto-start in tray on sign-in so devices can send files anytime';
  @override
  String get btnHideToTrayNow => 'Hide to Tray Now';
  @override
  String get btnQuitBackgroundService => 'Quit Background Service';
  @override
  String get themeDialogTitle => 'Appearance Theme';
  @override
  String get themeSystemTitle => 'Follow System';
  @override
  String get themeSystemSubtitle => 'Automatically match system light/dark mode';
  @override
  String get themeLightTitle => 'Light';
  @override
  String get themeLightSubtitle => 'Always use bright light theme';
  @override
  String get themeDarkTitle => 'Dark';
  @override
  String get themeDarkSubtitle => 'Eye-friendly dark interface';
  @override
  String get themeSystemShort => 'System';
  @override
  String get themeLightShort => 'Light';
  @override
  String get themeDarkShort => 'Dark';
  @override
  String get languageDialogTitle => 'Language';
  @override
  String get languageSettingTitle => 'Language';
  @override
  String get languageSystemTitle => 'Follow System';
  @override
  String get languageSystemSubtitle =>
      'Automatically match your device language';
  @override
  String toastLanguageUpdated(String langName) => 'Language set to $langName';
  @override
  String get storageManagerTitle => 'Storage & Cache Manager';
  @override
  String storageRecvStats(String size, int count) => '$size ($count files)';
  @override
  String get countingStats => 'Calculating...';
  @override
  String get storageRecvUsedTitle => 'Received Files Usage';
  @override
  String get thumbCacheTitle => 'Thumbnail Cache';
  @override
  String thumbCacheDesc(String size) =>
      '$size · Clearing does not touch received photos or files';
  @override
  String get btnClearThumbCache => 'Clear Thumbnail Cache';
  @override
  String get mobileStorageTitle => 'Storage & Cache';
  @override
  String legendReceivedFiles(String size) => 'Received $size';
  @override
  String legendThumbCache(String size) => 'Cache $size';
  @override
  String receivedFilesCountTitle(int count) => 'Received Files ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => 'Thumbnail Cache ($size)';
  @override
  String get thumbCacheNoTouchNotice =>
      'Won\'t delete original photos or files';
  @override
  String get noCacheToClear => 'No Cache to Clear';
  @override
  String btnClearThumbCacheWithSize(String size) =>
      'Clear Thumbnail Cache ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      'Received $recvSize · Cache $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => 'Thumbnail cache $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      'Total $totalSize · Cache $cacheSize';
  @override
  String get storageAndCacheTitle => 'Storage & Cache';
  @override
  String get aboutTitle => 'About P2P Private Transfer';
  @override
  String aboutVersion(String version) => 'Version: $version';
  @override
  String get aboutBody =>
      '• End-to-End Encryption (E2EE): Isolated keys per room; no central server ever stores or decrypts your files.\n'
      '• High-Speed Direct Links: Prefers LAN & USB Tether while bypassing VPN virtual adapters; falls back to WAN P2P or encrypted relay across networks.';
  @override
  String get aboutSubtitle => 'Decentralized · E2EE Transfer';
  @override
  String get networkDiagTitle => 'Network Diagnostics & Advanced';
  @override
  String get networkDiagLoading => 'Scanning local network interfaces...';
  @override
  String networkDiagDesktopReady(int count) =>
      'Ready · $count LAN/USB direct adapters detected';
  @override
  String get networkDiagDesktopWanOnly =>
      'No Wi-Fi/USB detected · Using encrypted WAN transport';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB ready · $count adapters';
  @override
  String get networkDiagMobileWanOnly => 'Active: Encrypted WAN Channel';
  @override
  String get nicDetectionTitle => 'Connection Refresh & Physical NICs';
  @override
  String get nicDetectionDesc =>
      'When two devices share Wi-Fi or USB tethering, transfers bypass VPN/TUN virtual adapters and bind directly to the physical interfaces below. Tap Probe & Reconnect after switching networks.';
  @override
  String get nicReading => 'Reading local interfaces...';
  @override
  String get nicNoneConnected =>
      'No Wi-Fi or USB tethering detected; using cellular/WAN transport';
  @override
  String get btnRefreshNics => 'Refresh NICs';
  @override
  String get usbProtectionTitle => 'USB Tether Route Protection';
  @override
  String get usbProtectionDesc =>
      'USB tethering provides stable high-speed direct transfers. Windows sets the USB adapter metric to 5000 so file transfers stay fast without hijacking PC internet traffic.';
  @override
  String get usbProtectionReady =>
      'USB route isolation active (Metric=5000 protected)';
  @override
  String usbProtectionNeedsFix(String detail) =>
      'USB adapter route not isolated: $detail';
  @override
  String get usbProtectionNotPlugged =>
      'No USB tether adapter detected (plug in to auto-connect)';
  @override
  String get btnFixMetric => 'Fix Metric';
  @override
  String get customRelayTitle => 'Custom Relay Server (Advanced)';
  @override
  String get customRelayDesc =>
      'When LAN and direct WAN P2P cannot connect, encrypted packets route via a relay (E2EE—relays cannot read content). Leave blank for the default public relay, or enter a self-hosted iroh-relay URL.';
  @override
  String get customRelayLabel => 'Relay URL (leave blank for default)';
  @override
  String get toastRelaySaved => 'Relay URL saved';
  @override
  String get btnSaveRelay => 'Save Relay URL';
  @override
  String get deviceIdLabel => 'Device ID';
  @override
  String get btnCopyDeviceId => 'Copy Full Device ID';
  @override
  String get deviceIdCopiedBadge => 'Copied';

  @override
  String toastEventStreamError(Object error) => 'Event stream error: $error';
  @override
  String toastCreatedRoom(String name) => 'Created encrypted room "$name"';
  @override
  String toastCreateRoomFailed(Object error) => 'Failed to create room: $error';
  @override
  String toastOpenChatFailed(Object error) => 'Failed to open chat: $error';
  @override
  String toastCreatedGroup(String name) => 'Created group "$name"';
  @override
  String toastCreateGroupFailed(Object error) => 'Failed to create group: $error';
  @override
  String toastJoinedRoom(String name) => 'Joined encrypted room "$name"';
  @override
  String toastAddedDevice(String name) => 'Paired "$name" and connected';
  @override
  String toastPairFailed(Object error) => 'Failed to pair/join: $error';
  @override
  String toastSendTextFailed(Object error) => 'Failed to send message: $error';
  @override
  String get toastSelectRoomFirst => 'Select a room and pair at least one device first';
  @override
  String toastSendFileFailed(String path, Object error) =>
      'Failed to send file ($path): $error';
  @override
  String get toastForwardFileMissing => 'Local file missing; cannot forward';
  @override
  String get toastForwardEmptyText => 'Cannot forward an empty message';
  @override
  String get fallbackTargetRoom => 'Target Chat';
  @override
  String toastForwardedTo(String targetName) => 'Forwarded to "$targetName"';
  @override
  String toastForwardFailed(Object error) => 'Forward failed: $error';
  @override
  String get fallbackBigFile => 'Large File';
  @override
  String toastConfirmedSend(String fileName) => 'Confirmed sending "$fileName"';
  @override
  String toastConfirmSendFailed(Object error) => 'Failed to confirm send: $error';
  @override
  String get fallbackFile => 'File';
  @override
  String toastPullingFile(String fileName) =>
      'Requesting "$fileName" from sender...';
  @override
  String toastPullFileFailed(Object error) => 'Download request failed: $error';
  @override
  String get toastPeerDeleted => 'Device and chat history removed';
  @override
  String toastDeletePeerFailed(Object error) => 'Failed to remove device: $error';
  @override
  String get toastRoomDeleted => 'Conversation deleted';
  @override
  String toastDeleteRoomFailed(Object error) => 'Failed to delete room: $error';
  @override
  String get toastDeletedRecordAndFile => 'Deleted record and local file';
  @override
  String get toastRemovedLocalRecord => 'Removed from local history';
  @override
  String toastDeleteMsgFailed(Object error) => 'Failed to delete message: $error';
  @override
  String get toastOnlyRevokeOwn => 'You can only unsend your own messages';
  @override
  String get toastRevokedForAll => 'Message unsent for all devices';
  @override
  String toastRevokeFailed(Object error) => 'Failed to unsend: $error';
  @override
  String toastInvitedMembers(int count) => 'Invited $count devices to group';
  @override
  String toastAddMembersFailed(Object error) => 'Failed to add members: $error';
  @override
  String get toastRemovedMember => 'Removed device from group';
  @override
  String toastRemoveMemberFailed(Object error) =>
      'Failed to remove member: $error';
  @override
  String toastFixUsbMetricFailed(Object error) =>
      'Failed to fix USB metric: $error';
  @override
  String toastReceiveDirFallback(String dir) => 'Receive folder: $dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => 'Save folder updated: $dir';
  @override
  String get toastClearedCustomSaveDir =>
      'Cleared custom folder; default folder will be used';
  @override
  String toastSetDirFailed(Object error) => 'Failed to set folder: $error';
  @override
  String toastSyncAvatarFailed(Object error) => 'Failed to sync avatar: $error';
  @override
  String get toastSelfProfileUpdated =>
      'Profile updated and synced to online peers';
  @override
  String get toastPeerRemarkUpdated => 'Device alias updated';
  @override
  String get toastRestoredGroupName => 'Restored default group name';
  @override
  String get toastUpdatedGroupName => 'Updated local group name';
  @override
  String get toastAutoStartEnabled => 'Silent startup on boot enabled';
  @override
  String get toastAutoStartDisabled => 'Startup on boot disabled';
  @override
  String get toastCloseToTrayEnabled => 'Closing window will minimize to tray';
  @override
  String get toastCloseToTrayDisabled => 'Closing window will quit the app';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      'Received from $sender: $fileName';
  @override
  String get notifyFileFallbackBody => 'New file saved automatically';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      '$fileLabel and $totalCount files receiving';
  @override
  String notifyNewFileTitle(String sender) => 'New File · $sender';
  @override
  String notifyNewTextTitle(String sender) => 'New Message · $sender';
  @override
  String get notifyNewEncryptedText => 'New encrypted text message';
  @override
  String get errorEmptyImageFile => 'Selected image file is empty';
  @override
  String get errorCompressAvatarFailed => 'Unable to compress avatar image';
  @override
  String get errorPngEncodeFailed => 'PNG encoding failed';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'No USB tethering adapter detected';
    if (metricProtected) {
      return 'USB adapter metric set to 5000 so PC internet traffic stays unaffected';
    }
    if (needsElevation) {
      return 'Administrator permission required to set USB adapter metric to 5000';
    }
    return 'USB tethering detected, awaiting metric isolation';
  }

  @override
  String get winTrayTooltip => 'P2P Private Transfer · Background Service';
  @override
  String get winTrayOpenWindow => 'Open Main Window';
  @override
  String get winTrayAutoStart => 'Start Minimized on Boot';
  @override
  String get winTrayCloseToTray => 'Minimize to Tray on Close';
  @override
  String get winTrayExitApp => 'Exit Application';
}
