import 'app_strings.dart';

class StringsPt extends AppStrings {
  const StringsPt();

  static const _months = <String>[
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  @override
  String get localeCode => 'pt';

  @override
  String get appTitle => 'P2Pfiledrop';
  @override
  String get appSubtitle => 'Transferência criptografada de ponta a ponta';
  @override
  String get startingEngine => 'Iniciando motor criptografado P2P...';
  @override
  String engineInitFailed(Object error) => 'Falha ao iniciar o motor:\n$error';
  @override
  String get retry => 'Tentar';
  @override
  String get cancel => 'Cancelar';
  @override
  String get confirm => 'OK';
  @override
  String get close => 'Fechar';
  @override
  String get save => 'Salvar';
  @override
  String get delete => 'Excluir';
  @override
  String get remove => 'Remover';
  @override
  String get open => 'Abrir';
  @override
  String get refresh => 'Atualizar';
  @override
  String get clear => 'Limpar';
  @override
  String get resetDefault => 'Restaurar';
  @override
  String get recommendedBadge => 'Recomendado';
  @override
  String get defaultAvatarFallback => 'D';

  @override
  String formatFullDate(DateTime dt) =>
      '${dt.day} de ${_months[dt.month - 1]} de ${dt.year}';
  @override
  String formatMonthDay(DateTime dt) => '${dt.day} de ${_months[dt.month - 1]}';
  @override
  String get todayLabel => 'Hoje';
  @override
  String get yesterdayLabel => 'Ontem';
  @override
  String formatRemainingSeconds(int seconds) => 'Restam ${seconds}s';
  @override
  String formatRemainingMinutesSeconds(int minutes, int seconds) =>
      'Restam ${minutes}m ${seconds}s';

  @override
  String get navTransfers => 'Chats';
  @override
  String get navDevices => 'Dispositivos';
  @override
  String get navThisDevice => 'Eu';
  @override
  String get navAdd => 'Adicionar';
  @override
  String get navFiles => 'Arquivos';
  @override
  String get navFolder => 'Pasta';
  @override
  String tooltipSelfProfile(String deviceName) => '$deviceName (Toque para ajustes)';
  @override
  String get tooltipScanPair => 'Ler QR para parear ou entrar';
  @override
  String get tooltipAllFiles => 'Ver todos os arquivos e fotos';
  @override
  String tooltipOpenReceiveFolder(String dir) => 'Abrir pasta recebida ($dir)';

  @override
  String get transportUsbTether => 'USB direto';
  @override
  String get transportLanDirect => 'LAN direta';
  @override
  String get transportWanP2p => 'P2P externo';
  @override
  String get transportWanRelay => 'Relay';
  @override
  String get transportOffline => 'Offline';
  @override
  String get usbTetherTag => 'USB direto';

  @override
  String get msgStatusQueuedOffline => 'Aguardando dispositivo';
  @override
  String get msgStatusHandshaking => 'Autenticando';
  @override
  String get msgStatusTransferring => 'Transferindo';
  @override
  String get msgStatusPausedReconnecting => 'Retomando';
  @override
  String get msgStatusAwaitingDownload => 'Toque para baixar';
  @override
  String get msgStatusDelivered => 'Entregue';
  @override
  String get msgStatusFailedSourceMissing => 'Origem ausente';

  @override
  String deviceWithTag(String tag) => 'Dispositivo $tag';
  @override
  String deviceShortIdLabel(String shortId) => 'Dispositivo · $shortId';
  @override
  String get peerDeviceFallback => 'Dispositivo remoto';
  @override
  String get defaultPersonalRoomName => 'Meus dispositivos (Personal)';
  @override
  String get defaultEncryptedGroupName => 'Novo grupo criptografado';
  @override
  String get defaultPrivateRoomName => 'Nova sala privada criptografada';
  @override
  String encryptedRoomWithId(String shortId) => 'Sala criptografada ($shortId)';
  @override
  String get homeNodeDefaultName => 'Nó doméstico 24h';

  @override
  String get chatListTitle => 'Conversas';
  @override
  String get chatListNewActionTooltip => 'Ler QR / Criar grupo';
  @override
  String get menuScanPairOrJoin => 'Ler QR para parear / entrar';
  @override
  String get menuCreateGroup => 'Criar grupo compartilhado';
  @override
  String get menuMyPairingQr => 'Meu código QR';
  @override
  String get menuOpenReceiveFolder => 'Abrir pasta de recebimento';
  @override
  String get menuProbeReconnect => 'Verificar / Reconectar';
  @override
  String get searchChatsHint => 'Buscar conversas ou dispositivos...';
  @override
  String groupOnlineCount(int online, int total) =>
      'Grupo ($online/$total online)';
  @override
  String groupOfflineCount(int total) => 'Grupo ($total dispositivos · offline)';
  @override
  String get emptyChatsSearch => 'Nenhuma conversa encontrada';
  @override
  String get emptyChatsNoRooms => 'Nenhuma conversa ativa ainda';
  @override
  String get btnScanPairDevice => 'Ler QR para parear';
  @override
  String get btnGoToDevices => 'Ir para Dispositivos';

  @override
  String get devicesListTitle => 'Dispositivos';
  @override
  String get searchPairedDevicesHint => 'Buscar dispositivos pareados...';
  @override
  String get btnAddNewDevice => 'Adicionar dispositivo / QR';
  @override
  String get btnNewSharedGroup => 'Novo grupo compartilhado';
  @override
  String get btnAddDeviceShort => 'Adicionar';
  @override
  String get btnNewGroupShort => 'Novo grupo';
  @override
  String pairedDevicesCount(int count) => 'Pareados ($count)';
  @override
  String get emptyDevicesSearch => 'Nenhum dispositivo encontrado';
  @override
  String get emptyDevicesNone =>
      'Nenhum dispositivo pareado ainda\nToque em "Adicionar dispositivo / QR" acima para conectar';
  @override
  String get selectDevicePrompt => 'Selecione um dispositivo à esquerda para ver detalhes';
  @override
  String get btnScanFirstDevice => 'Parear primeiro dispositivo';
  @override
  String originalNameLabel(String name) => 'Nome original: $name';
  @override
  String get deviceNodeIdLabel => 'ID do nó (Endpoint ID)';
  @override
  String get tooltipCopyDeviceId => 'Copiar ID';
  @override
  String get toastCopiedDeviceId => 'ID do dispositivo copiado';
  @override
  String get btnSendMessageOrFile => 'Enviar mensagem / arquivo';
  @override
  String get btnEditRemark => 'Editar apelido';
  @override
  String get btnDeleteDevice => 'Remover este dispositivo';
  @override
  String get deletePeerDialogTitle => 'Remover dispositivo pareado';
  @override
  String deletePeerDialogBody(String resolvedName) =>
      'Remover "$resolvedName" dos confiáveis e limpar o chat direto? (Arquivos já salvos serão mantidos).';
  @override
  String get btnConfirmDelete => 'Remover';

  @override
  String get desktopWorkspaceTitle => 'Área de transferência';
  @override
  String get btnOpenFolder => 'Abrir pasta';
  @override
  String get tooltipRoomFiles => 'Arquivos e fotos da sala';
  @override
  String get tooltipInviteOrScan => 'Convidar por QR / Ler QR';
  @override
  String get tooltipRoomMembers => 'Detalhes / Membros do grupo';
  @override
  String get desktopEmptyTitle => 'Escolha uma conversa ou dispositivo à esquerda';
  @override
  String get desktopEmptySubtitle =>
      'Suporta LAN direta, cabo USB prioritário e criptografia externa. Arraste arquivos aqui para enviar.';
  @override
  String get moreActionsTooltip => 'Mais ações';
  @override
  String get moreTooltip => 'Mais';
  @override
  String get emptyRoomNoSession => 'Sem conversa ativa. Pareie um dispositivo via QR primeiro.';
  @override
  String get emptyRoomE2eeNotice =>
      'Esta sala usa criptografia de ponta a ponta; só os membros conseguem decifrar o conteúdo.';
  @override
  String get emptyRoomWindowsHint =>
      'Arraste arquivos ou fotos para enviar, ou digite uma mensagem abaixo.';
  @override
  String get emptyRoomMobileHint =>
      'Toque em + abaixo para enviar fotos/arquivos ou digite uma mensagem.';
  @override
  String dropZonePrompt(String roomTitle) =>
      'Solte para enviar criptografado para "$roomTitle"';
  @override
  String get menuAddPairedToGroup => 'Adicionar pareados ao grupo';
  @override
  String get menuDeviceDetailsAndRemark => 'Detalhes e apelido';
  @override
  String get menuGroupMembersAndManage => 'Membros e gerenciamento';
  @override
  String get noShareTargetsToast => 'Nenhum dispositivo ou sala disponível ainda';
  @override
  String get fallbackShortTitle => 'Privado P2P';

  @override
  String get tooltipGalleryImages => 'Fotos da galeria';
  @override
  String get tooltipSendFile => 'Escolher arquivo';
  @override
  String get tooltipSendImageOrFile => 'Enviar foto ou arquivo';
  @override
  String get tooltipPasteClipboard => 'Colar imagem ou texto';
  @override
  String get inputHintWindows =>
      'Digite uma mensagem, cole ou arraste arquivos...';
  @override
  String get inputHintMobile => 'Digite uma mensagem...';
  @override
  String get inputHintNoRoom => 'Adicione um dispositivo acima (+)...';
  @override
  String get tooltipSendMessage => 'Enviar';

  @override
  String get newMessagesBelowSuffix => 'novas mensagens';
  @override
  String albumFailedCount(int failedCount) =>
      'Origem ausente em $failedCount fotos';
  @override
  String albumDeliveredSourceMissing(int missingCount) =>
      'Enviado ($missingCount origens removidas)';
  @override
  String albumDeliveredLocalDeleted(int missingCount) =>
      'Recebido ($missingCount apagadas localmente)';
  @override
  String get albumAllDelivered => 'Tudo entregue';
  @override
  String albumTransferringProgress(int delivered, int total) =>
      'Enviando $delivered/$total';
  @override
  String albumImageCount(int count) => '$count fotos';
  @override
  String get btnExpand => 'Abrir';
  @override
  String collapseImagesCount(int count) => 'Recolher ($count)';

  @override
  String get statusLargeFileAwaitConfirm => 'Aguardando confirmação';
  @override
  String get statusGroupFileAwaitDownload => 'Pronto para baixar';
  @override
  String groupOfferCardsSent(int acked, int total) =>
      'Oferta enviada ($acked/$total)';
  @override
  String statusLargeFileAwaitConfirmCount(int acks, int total) =>
      'Confirmar ($acks/$total)';
  @override
  String statusAllDeliveredCount(int acks, int total) =>
      'Entregue a todos ($acks/$total)';
  @override
  String statusDeliveredCount(int acks, int total) =>
      'Entregue ($acks/$total)';
  @override
  String get statusLocalSourceRemoved => 'Origem removida';
  @override
  String get statusLocalFileDeleted => 'Arquivo local excluído';
  @override
  String get revokedByMe => 'Você cancelou esta mensagem';
  @override
  String get revokedByPeer => 'O remetente cancelou esta mensagem';
  @override
  String get tooltipEditPeerRemark => 'Editar apelido';
  @override
  String get tooltipPeerAvatar => 'Dispositivo remoto';
  @override
  String get toastCopiedText => 'Texto copiado';
  @override
  String toastCopiedPath(String path) => 'Caminho copiado: $path';
  @override
  String get imageDeletedLocally => 'Foto excluída localmente';
  @override
  String fileSizeSourceImageRemoved(String sizeLabel) =>
      '$sizeLabel · Foto original removida';
  @override
  String fileSizeImageDeletedTap(String sizeLabel) =>
      '$sizeLabel · Foto excluída (toque para detalhes)';
  @override
  String fileSizeSourceMissing(String sizeLabel) =>
      '$sizeLabel · Origem ausente';
  @override
  String fileSizeFileDeleted(String sizeLabel) =>
      '$sizeLabel · Excluído localmente';
  @override
  String fileSizeAwaitConfirm(String sizeLabel) =>
      '$sizeLabel · Arquivo grande aguardando confirmação';
  @override
  String fileSizeGroupAwaitDownload(String sizeLabel) =>
      '$sizeLabel · Arquivo de grupo disponível';
  @override
  String fileSizeGroupOfferWaiting(String sizeLabel) =>
      '$sizeLabel · Aguardando download';
  @override
  String btnDownloadToDevice(String sizeLabel) => 'Baixar ($sizeLabel)';
  @override
  String btnConfirmSendNow(String sizeLabel) => 'Enviar agora ($sizeLabel)';
  @override
  String get btnConfirmQueueOffline => 'Enviar quando online';
  @override
  String get actionCopyText => 'Copiar texto';
  @override
  String get actionForward => 'Encaminhar';
  @override
  String get actionOpenFile => 'Abrir arquivo';
  @override
  String get actionRevealInFolder => 'Mostrar na pasta';
  @override
  String get actionCopyFilePath => 'Copiar caminho';

  @override
  String get createGroupTitle => 'Criar grupo criptografado';
  @override
  String get createGroupDesc =>
      'Selecione dispositivos pareados para criar um grupo com chave E2EE própria (sem novo escaneamento QR).';
  @override
  String get groupNameOptionalLabel => 'Nome do grupo (opcional)';
  @override
  String get groupNameAutoHint => 'Deixe em branco para gerar automaticamente';
  @override
  String get createGroupNoPeersNotice =>
      'Nenhum dispositivo pareado ainda. Crie o grupo agora e convide depois via QR.';
  @override
  String selectGroupDevicesCount(int count) =>
      'Selecionar dispositivos ($count):';
  @override
  String get btnCreateGroup => 'Criar grupo';
  @override
  String get defaultGroupNameFallback => 'Grupo criptografado';
  @override
  String defaultGroupNameFromPeers(String joinedNames) => 'Grupo $joinedNames';
  @override
  String get nameSeparator => ', ';
  @override
  String get addMembersToGroupTitle => 'Adicionar ao grupo';
  @override
  String get btnConfirmInvite => 'Convidar';
  @override
  String get allPeersAlreadyInGroupToast =>
      'Todos os dispositivos pareados já estão neste grupo';
  @override
  String get subtitleDmE2ee => 'P2P direto · Criptografia E2E';
  @override
  String subtitleGroupE2ee(int count) => 'Grupo ($count disp.) · Chave isolada';
  @override
  String get tooltipEditGroupName => 'Renomear grupo';
  @override
  String get badgeThisTerminal => 'Este disp.';
  @override
  String get roleThisDevice => 'Este dispositivo (editável)';
  @override
  String get rolePeerDevice => 'Dispositivo remoto';
  @override
  String get roleGroupMember => 'Membro do grupo';
  @override
  String get tooltipEditSelfProfile => 'Editar nome e avatar';
  @override
  String get tooltipRemoveFromGroup => 'Remover do grupo';
  @override
  String deletePeerQuickConfirm(String roomTitle) =>
      'Desparear e excluir "$roomTitle"? (Os arquivos já salvos permanecerão).';
  @override
  String get deleteGroupTitle => 'Excluir grupo';
  @override
  String deleteGroupConfirm(String roomTitle) =>
      'Excluir "$roomTitle" e seu histórico local? (Arquivos recebidos serão mantidos).';
  @override
  String get btnDeleteAndLeave => 'Excluir e sair';
  @override
  String get btnInviteNewDevice => 'Convidar / Ler QR';
  @override
  String get editGroupNameTitle => 'Renomear grupo';
  @override
  String get localDisplayNameLabel => 'Nome local';
  @override
  String editGroupNameHint(String defaultName) =>
      'Em branco usa "$defaultName"';
  @override
  String get editProfileSelfTitle => 'Editar nome e avatar';
  @override
  String get editProfilePeerTitle => 'Editar apelido do dispositivo';
  @override
  String processImageFailed(Object error) => 'Falha ao processar imagem: $error';
  @override
  String get btnChangeAvatar => 'Trocar avatar';
  @override
  String get btnUploadAvatar => 'Enviar avatar';
  @override
  String get btnRemoveImage => 'Remover foto';
  @override
  String get avatarSyncNoticeSelf =>
      'A foto é sincronizada de forma criptografada com seus dispositivos';
  @override
  String get avatarSyncNoticePeer =>
      'O apelido é apenas local; o avatar mostra a foto definida pelo outro dispositivo';
  @override
  String get selfDisplayNameLabel => 'Nome deste dispositivo';
  @override
  String get peerRemarkNameLabel => 'Apelido do dispositivo';
  @override
  String get customDeviceNameHint => 'Digite um nome personalizado';
  @override
  String defaultNameDisplay(String fallbackModel) => 'Padrão: $fallbackModel';
  @override
  String get shareToTitle => 'Compartilhar em...';
  @override
  String shareSummarySingle(bool isImage, String name, String size) =>
      '${isImage ? "Foto" : "Arquivo"}: $name ($size)';
  @override
  String shareSummaryMulti(int count, bool allImages, String size) =>
      '$count ${allImages ? "fotos" : "arquivos"} · $size';
  @override
  String shareSummaryText(String text) => 'Texto: $text';
  @override
  String get sendToTitle => 'Enviar para';
  @override
  String get targetTypeDm => 'Dispositivo direto';
  @override
  String targetTypeGroup(int memberCount) => 'Grupo · $memberCount disp.';
  @override
  String get targetTypePairedPeer => 'Pareado (P2P direto)';
  @override
  String get btnReselect => 'Alterar';
  @override
  String btnSendCount(int count) => 'Enviar ($count)';
  @override
  String get btnSend => 'Enviar';
  @override
  String shareFileListMore(int count, String size) =>
      'e mais ($count arquivos) · $size';
  @override
  String shareFileListExact(int count, String size) => '$count arquivos · $size';
  @override
  String forwardSummaryFile(bool isImage, String fileName) =>
      'Encaminhar ${isImage ? "foto" : "arquivo"}: $fileName';
  @override
  String forwardSummaryText(String text) => 'Encaminhar mensagem: $text';
  @override
  String get forwardToTitle => 'Encaminhar para...';
  @override
  String get searchRoomOrDeviceHint => 'Buscar conversas ou dispositivos...';
  @override
  String get noAvailableTargets => 'Nenhuma conversa ou dispositivo disponível';
  @override
  String get noMatchingTargets => 'Nenhum resultado';
  @override
  String get currentConversationLabel => 'Chat atual';
  @override
  String get tooltipOpenWithDefaultApp => 'Abrir no app padrão';
  @override
  String get tooltipDeleteMessage => 'Excluir mensagem';
  @override
  String get tooltipClosePreview => 'Fechar visualização';
  @override
  String get deletedImagePreviewTitle => 'Foto excluída localmente';
  @override
  String deletedImagePreviewBody(String fileName) =>
      '"$fileName" não existe mais neste dispositivo.';
  @override
  String get btnDeleteThisRecord => 'Excluir este registro';
  @override
  String get removeRevokeNoticeTitle => 'Aviso';
  @override
  String get removeRevokeNoticeBody =>
      'Mesmo sem o arquivo local, você pode limpar o registro só no seu histórico.';
  @override
  String get deleteOutgoingFileTitle => 'Excluir arquivo enviado';
  @override
  String get deleteOutgoingTextTitle => 'Excluir mensagem enviada';
  @override
  String get chooseDeleteMethod => 'Escolha como excluir:';
  @override
  String get deleteOutgoingFileDetail =>
      '• Cancelar para todos: Notifica membros e nós relay para apagar também as cópias salvas.\n• Remover só aqui: Limpa apenas o seu histórico.\n\nSeu arquivo original nunca será alterado ou excluído.';
  @override
  String get deleteOutgoingTextDetail =>
      '• Cancelar para todos: Apaga em todos os dispositivos e relays.\n• Remover só aqui: Remove apenas deste dispositivo.';
  @override
  String get btnRemoveLocalOnly => 'Remover só aqui';
  @override
  String get btnRevokeForAll => 'Cancelar para todos';
  @override
  String get deleteIncomingFileTitle => 'Excluir arquivo recebido';
  @override
  String get deleteIncomingTextTitle => 'Excluir mensagem recebida';
  @override
  String get deleteIncomingNote =>
      'Exclui apenas neste dispositivo sem afetar o remetente.';
  @override
  String get checkboxDeleteLocalFile => 'Excluir também o arquivo salvo aqui';
  @override
  String get incomingFileAlreadyMissing =>
      'O arquivo local não existe mais; apenas o registro será removido.';

  @override
  String sendPreviewImageTitle(int current, int total) =>
      'Prévia ($current/$total)';
  @override
  String sendPreviewFileTitle(int count) => 'Confirmar envio ($count itens)';
  @override
  String get btnAddMore => 'Adicionar';
  @override
  String batchLimitNotice(int maxFiles) =>
      'Máximo de $maxFiles arquivos por vez; mantidos os primeiros $maxFiles.';
  @override
  String get tooltipPrevImage => 'Anterior';
  @override
  String get tooltipNextImage => 'Próxima';
  @override
  String sendPreviewFooter(int count, String size, bool showEnterHint) =>
      '$count itens · $size${showEnterHint ? ' (Enter para enviar)' : ''}';

  @override
  String inviteGroupTitle(String roomName) => 'Convidar para "$roomName"';
  @override
  String get inviteDeviceTitle => 'Adicionar / Ler QR';
  @override
  String get tabGroupInviteQr => 'QR do grupo';
  @override
  String get tabDevicePairingQr => 'Meu código QR';
  @override
  String get tabScanOrPaste => 'Ler / Colar';
  @override
  String get desktopQrImageUnsupported =>
      'Leitura de QR por imagem indisponível no PC. Cole o ticket JSON diretamente.';
  @override
  String get noQrDetectedInImage =>
      'Nenhum QR encontrado na imagem. Tente uma foto mais nítida.';
  @override
  String galleryQrScanFailed(Object error) => 'Falha ao ler QR: $error';
  @override
  String generateQrFailed(Object error) => 'Falha ao gerar QR: $error';
  @override
  String get joinOrPairFailedHint =>
      'Falha ao validar ticket. Verifique se o JSON está completo.';
  @override
  String groupInviteDesc(String roomName) =>
      'QR do grupo: ao ler, entra direto em "$roomName" e sincroniza a chave E2EE.';
  @override
  String get devicePairingDesc =>
      'Meu QR: pareia como dispositivos confiáveis e cria canal P2P criptografado.';
  @override
  String get toastCopiedQrJson => 'Ticket JSON copiado';
  @override
  String get btnCopyTextTicket => 'Copiar ticket texto';
  @override
  String get btnRetryGenerateQr => 'Gerar QR de novo';
  @override
  String get scannerPermDenied =>
      'Permissão da câmera negada. Permita o acesso ou escolha um QR da galeria.';
  @override
  String get scannerUnsupported =>
      'Câmera indisponível aqui. Escolha imagem na galeria ou cole o ticket.';
  @override
  String get scannerReinitializing =>
      'Reiniciando câmera. Toque em Tentar em instantes.';
  @override
  String scannerGenericErrorWithDetails(String details) =>
      'Erro na câmera ($details)';
  @override
  String get scannerGenericError =>
      'Não foi possível iniciar a câmera. Tente de novo ou use a galeria.';
  @override
  String get startingCamera => 'Iniciando câmera...';
  @override
  String get btnPickQrFromGallery => 'Escolher QR da galeria';
  @override
  String get btnRetryCamera => 'Tentar';
  @override
  String get pasteTicketDialogTitle => 'Colar ticket para entrar';
  @override
  String get pasteTicketFieldHint => 'Cole o JSON do convite ou pareamento';
  @override
  String get btnJoinOrRegister => 'Entrar / Registrar';
  @override
  String get cameraNotSupportedPlatform =>
      'Câmera não compatível aqui. Use "Colar ticket" ou a galeria.';
  @override
  String get qrViewfinderHint => 'Alinhe o código QR dentro da moldura';
  @override
  String get analyzingImageQr => 'Lendo QR da imagem...';
  @override
  String get verifyingHandshake => 'Verificando conexão criptografada...';
  @override
  String get actionGallery => 'Galeria';
  @override
  String get actionPasteTicket => 'Colar ticket';
  @override
  String get actionTorchOff => 'Desligar flash';
  @override
  String get actionTorchOn => 'Ligar flash';
  @override
  String get windowsPasteTicketHint =>
      'No Windows, cole o "Ticket de convite" diretamente para entrar no mesmo grupo criptografado.';
  @override
  String get btnAnalyzingQr => 'Analisando QR...';
  @override
  String get btnRestartCamera => 'Reiniciar câmera';
  @override
  String get pasteTicketFieldLabel => 'Cole o JSON do convite ou pareamento';
  @override
  String get btnJoinToThisDevice => 'Entrar / Registrar aqui';

  @override
  String get allFilesTitle => 'Todos os arquivos';
  @override
  String get roomFilesTitle => 'Arquivos da sala';
  @override
  String get tooltipOpenMainReceiveFolder => 'Abrir pasta principal de recebimento';
  @override
  String get searchFileNameHint => 'Buscar nome do arquivo...';
  @override
  String get allRoomsOption => 'Todas as salas';
  @override
  String tabImagesCount(int count) => 'Fotos ($count)';
  @override
  String tabFilesCount(int count) => 'Arquivos ($count)';
  @override
  String loadFilesFailed(String error) => 'Falha ao carregar: $error';
  @override
  String get emptyImagesNone => 'Sem fotos nesta sala ainda';
  @override
  String get emptyImagesSearch => 'Nenhuma foto encontrada';
  @override
  String get emptyFilesNone => 'Sem arquivos nesta sala ainda';
  @override
  String get emptyFilesSearch => 'Nenhum arquivo encontrado';
  @override
  String get badgeLocallyRemoved => 'Removido localmente';
  @override
  String get unnamedFile => 'Arquivo sem nome';
  @override
  String get toastLocalFileMissing => 'Arquivo movido ou excluído localmente';
  @override
  String get actionOpenShort => 'Abrir';

  @override
  String get sectionGeneral => 'Geral';
  @override
  String get sectionReceiveStorage => 'Recebimento e armazenamento';
  @override
  String get sectionResidencyNetwork => 'Segundo plano e rede';
  @override
  String get sectionAbout => 'Sobre';
  @override
  String deviceModelLabel(String model) => 'Modelo: $model';
  @override
  String get toastCopiedFullDeviceId => 'ID completo copiado';
  @override
  String get tooltipEditNameAvatar => 'Editar nome e avatar';
  @override
  String get toastThumbCacheCleared =>
      'Cache de miniaturas limpo (arquivos originais mantidos)';
  @override
  String toastSaveDirUpdated(String dir) => 'Pasta atualizada: $dir';
  @override
  String saveDirNotWritable(Object error) => 'Sem permissão de escrita: $error';
  @override
  String get needAllFilesPermTitle => 'Acesso a todos os arquivos necessário';
  @override
  String get needAllFilesPermBody =>
      'O Android exige permissão para gravar diretamente na pasta pública "Downloads".';
  @override
  String get btnGoGrant => 'Permitir';
  @override
  String get pickReceiveFolderDialogTitle => 'Escolher pasta de recebimento';
  @override
  String storageSizeSuffix(String size, int count) =>
      ' ($size · $count arquivos)';
  @override
  String get storageModeDownloads => 'Pasta pública "Downloads"';
  @override
  String get storageModeDocuments => 'Pasta pública "Documentos" (Documents)';
  @override
  String get storageModeCustomTitle => 'Pasta personalizada';
  @override
  String storageModeCustom(String compactPath) => 'Personalizada ($compactPath)';
  @override
  String get storageModeAppPrivate => 'Privada do app (Android/data)';
  @override
  String get receiveLocationTitle => 'Local de arquivos recebidos';
  @override
  String get storageDownloadsDesc =>
      'Fácil de acessar pelo app Arquivos ou outros apps';
  @override
  String get storageDocumentsDesc =>
      'Ideal para organizar documentos e PDFs';
  @override
  String storageCustomSelectedDesc(String compactPath) =>
      'Pasta atual: $compactPath';
  @override
  String get storageCustomUnselectedDesc =>
      'Escolha um cartão SD ou pasta personalizada';
  @override
  String get btnChange => 'Alterar';
  @override
  String get storageAppPrivateTitle => 'Pasta privada (apagada ao desinstalar)';
  @override
  String get storageAppPrivateDesc =>
      'Oculta da galeria e Arquivos; removida ao desinstalar';
  @override
  String get legacyStoragePermNotice =>
      'Permissão de armazenamento necessária para salvar em Downloads';
  @override
  String get btnAuthorize => 'Autorizar';
  @override
  String get btnChangeFolder => 'Alterar pasta';
  @override
  String get pickReceiveDirDialogTitle => 'Escolher pasta automática';
  @override
  String get windowsResidencyTitle => 'Bandeja do Windows e inicialização';
  @override
  String get windowsCloseToTrayTitle => 'Minimizar para a bandeja ao fechar';
  @override
  String get windowsCloseToTraySubtitle =>
      'Clicar em × mantém o app ativo na bandeja para receber arquivos';
  @override
  String get windowsAutoStartTitle => 'Iniciar em segundo plano com o Windows';
  @override
  String get windowsAutoStartSubtitle =>
      'Inicia minimizado na bandeja ao entrar no sistema (--minimized)';
  @override
  String get btnHideToTrayNow => 'Ocultar na bandeja agora';
  @override
  String get btnQuitBackgroundService => 'Sair completamente (incl. serviço)';
  @override
  String get themeDialogTitle => 'Escolher tema';
  @override
  String get themeSystemTitle => 'Seguir o sistema';
  @override
  String get themeSystemSubtitle => 'Alterna conforme modo claro/escuro do SO';
  @override
  String get themeLightTitle => 'Modo claro';
  @override
  String get themeLightSubtitle => 'Fundo claro com tons menta suaves';
  @override
  String get themeDarkTitle => 'Modo escuro';
  @override
  String get themeDarkSubtitle => 'Confortável para uso noturno';
  @override
  String get themeSystemShort => 'Sistema';
  @override
  String get themeLightShort => 'Claro';
  @override
  String get themeDarkShort => 'Escuro';
  @override
  String get languageDialogTitle => 'Idioma';
  @override
  String get languageSettingTitle => 'Idioma';
  @override
  String get languageSystemTitle => 'Seguir idioma do sistema';
  @override
  String get languageSystemSubtitle =>
      'Ajusta automaticamente ao idioma do sistema';
  @override
  String toastLanguageUpdated(String langName) =>
      'Idioma alterado para $langName';
  @override
  String get storageManagerTitle => 'Armazenamento e cache';
  @override
  String storageRecvStats(String size, int count) =>
      'Usando $size · $count arquivos';
  @override
  String get countingStats => 'Calculando...';
  @override
  String get storageRecvUsedTitle => 'Espaço de recebidos';
  @override
  String get thumbCacheTitle => 'Cache de miniaturas';
  @override
  String thumbCacheDesc(String size) =>
      'Em uso: $size · Limpar não apaga os arquivos salvos';
  @override
  String get btnClearThumbCache => 'Limpar cache';
  @override
  String get mobileStorageTitle => 'Armazenamento e cache';
  @override
  String legendReceivedFiles(String size) => 'Recebidos $size';
  @override
  String legendThumbCache(String size) => 'Cache $size';
  @override
  String receivedFilesCountTitle(int count) => 'Arquivos recebidos ($count)';
  @override
  String thumbCacheTitleWithSize(String size) => 'Cache miniaturas ($size)';
  @override
  String get thumbCacheNoTouchNotice =>
      'Não apaga suas fotos nem arquivos originais';
  @override
  String get noCacheToClear => 'Sem cache para limpar';
  @override
  String btnClearThumbCacheWithSize(String size) => 'Limpar cache ($size)';
  @override
  String cacheCardSummary(String recvSize, String cacheSize) =>
      'Recebidos $recvSize · Cache $cacheSize';
  @override
  String cacheCardSummaryOnly(String cacheSize) => 'Cache $cacheSize';
  @override
  String mobileCacheSummary(String totalSize, String cacheSize) =>
      'Total $totalSize · Cache $cacheSize';
  @override
  String get storageAndCacheTitle => 'Armazenamento e cache';
  @override
  String get aboutTitle => 'Sobre Transferência P2P';
  @override
  String aboutVersion(String version) => 'Versão: $version';
  @override
  String get aboutBody =>
      'Transferência P2P multiplataforma criptografada de ponta a ponta, sem nuvem nem limites.\n\n• Fixação em NIC física: ignora VPN/TUN na rede local\n• Chaves isoladas por sala: nós domésticos guardam apenas dados cifrados\n• Proteção de rota USB: evita sequestro de rota no Windows';
  @override
  String get aboutSubtitle => 'Transferência criptografada sem servidores';
  @override
  String get networkDiagTitle => 'Rede avançada e diagnóstico';
  @override
  String get networkDiagLoading => 'Verificando interfaces de rede...';
  @override
  String networkDiagDesktopReady(int count) =>
      'Pronto · $count adaptadores LAN/USB diretos detectados';
  @override
  String get networkDiagDesktopWanOnly => 'Canal P2P externo cifrado (sem LAN direta)';
  @override
  String networkDiagMobileReady(int count) =>
      'LAN / USB pronto · $count adaptadores detectados';
  @override
  String get networkDiagMobileWanOnly => 'Atual: Canal cifrado externo (WAN)';
  @override
  String get nicDetectionTitle => 'Adaptadores físicos LAN / USB (ignora VPN)';
  @override
  String get nicDetectionDesc =>
      'Ignora interfaces TUN virtuais (Clash, Mihomo, WireGuard) e usa apenas adaptadores físicos reais.';
  @override
  String get nicReading => 'Lendo adaptadores...';
  @override
  String get nicNoneConnected => 'Nenhum adaptador físico conectado';
  @override
  String get btnRefreshNics => 'Atualizar NICs';
  @override
  String get usbProtectionTitle => 'Proteção de rota USB Tether (Windows)';
  @override
  String get usbProtectionDesc =>
      'Ao ativar "Ancoragem USB" no Android, isola a métrica em 5000 para transferências rápidas pela porta 42420 sem afetar a internet do PC.';
  @override
  String get usbProtectionReady =>
      'Pronto: Rota USB isolada com sucesso (Metric=5000)';
  @override
  String usbProtectionNeedsFix(String detail) => 'Ajuste necessário: $detail';
  @override
  String get usbProtectionNotPlugged =>
      'USB não conectado; a proteção ativa automaticamente ao conectar';
  @override
  String get btnFixMetric => 'Corrigir métrica';
  @override
  String get customRelayTitle => 'Servidor Relay personalizado (Avançado)';
  @override
  String get customRelayDesc =>
      'Quando LAN e P2P direto falham, pacotes cifrados passam pelo relay sem revelar conteúdo. Deixe em branco para usar o relay público.';
  @override
  String get customRelayLabel => 'URL do Relay (vazio = padrão público)';
  @override
  String get toastRelaySaved => 'URL do Relay salva';
  @override
  String get btnSaveRelay => 'Salvar URL Relay';
  @override
  String get deviceIdLabel => 'ID do dispositivo';
  @override
  String get btnCopyDeviceId => 'Copiar ID completo';
  @override
  String get deviceIdCopiedBadge => 'Copiado';

  @override
  String toastEventStreamError(Object error) => 'Erro no fluxo de eventos: $error';
  @override
  String toastCreatedRoom(String name) => 'Sala criptografada "$name" criada';
  @override
  String toastCreateRoomFailed(Object error) => 'Falha ao criar sala: $error';
  @override
  String toastOpenChatFailed(Object error) => 'Falha ao abrir chat: $error';
  @override
  String toastCreatedGroup(String name) => 'Grupo "$name" criado';
  @override
  String toastCreateGroupFailed(Object error) => 'Falha ao criar grupo: $error';
  @override
  String toastJoinedRoom(String name) => 'Entrou na sala "$name"';
  @override
  String toastAddedDevice(String name) => 'Dispositivo "$name" adicionado';
  @override
  String toastPairFailed(Object error) => 'Falha ao parear ou entrar: $error';
  @override
  String toastSendTextFailed(Object error) => 'Falha ao enviar texto: $error';
  @override
  String get toastSelectRoomFirst => 'Selecione uma conversa ou dispositivo primeiro';
  @override
  String toastSendFileFailed(String path, Object error) =>
      'Falha ao enviar ($path): $error';
  @override
  String get toastForwardFileMissing =>
      'Não foi possível encaminhar: arquivo ausente';
  @override
  String get toastForwardEmptyText =>
      'Não foi possível encaminhar: texto vazio';
  @override
  String get fallbackTargetRoom => 'Sala destino';
  @override
  String toastForwardedTo(String targetName) => 'Encaminhado para "$targetName"';
  @override
  String toastForwardFailed(Object error) => 'Falha ao encaminhar: $error';
  @override
  String get fallbackBigFile => 'Arquivo grande';
  @override
  String toastConfirmedSend(String fileName) => 'Envio confirmado: "$fileName"';
  @override
  String toastConfirmSendFailed(Object error) => 'Falha ao confirmar: $error';
  @override
  String get fallbackFile => 'Arquivo';
  @override
  String toastPullingFile(String fileName) => 'Baixando "$fileName"';
  @override
  String toastPullFileFailed(Object error) => 'Falha ao baixar: $error';
  @override
  String get toastPeerDeleted => 'Dispositivo pareado removido';
  @override
  String toastDeletePeerFailed(Object error) => 'Falha ao remover: $error';
  @override
  String get toastRoomDeleted => 'Conversa excluída';
  @override
  String toastDeleteRoomFailed(Object error) => 'Falha ao excluir conversa: $error';
  @override
  String get toastDeletedRecordAndFile => 'Registro e arquivo local excluídos';
  @override
  String get toastRemovedLocalRecord => 'Removido do histórico local';
  @override
  String toastDeleteMsgFailed(Object error) => 'Falha ao excluir mensagem: $error';
  @override
  String get toastOnlyRevokeOwn => 'Você só pode cancelar suas próprias mensagens';
  @override
  String get toastRevokedForAll => 'Mensagem cancelada para todos os dispositivos';
  @override
  String toastRevokeFailed(Object error) => 'Falha ao cancelar: $error';
  @override
  String toastInvitedMembers(int count) => '$count dispositivos convidados';
  @override
  String toastAddMembersFailed(Object error) => 'Falha ao convidar: $error';
  @override
  String get toastRemovedMember => 'Dispositivo removido do grupo';
  @override
  String toastRemoveMemberFailed(Object error) => 'Falha ao remover: $error';
  @override
  String toastFixUsbMetricFailed(Object error) => 'Falha na métrica USB: $error';
  @override
  String toastReceiveDirFallback(String dir) => 'Pasta de recebimento: $dir';
  @override
  String toastAutoSaveDirUpdated(String dir) => 'Pasta atualizada: $dir';
  @override
  String get toastClearedCustomSaveDir =>
      'Pasta personalizada limpa; usando pasta padrão';
  @override
  String toastSetDirFailed(Object error) => 'Falha ao definir pasta: $error';
  @override
  String toastSyncAvatarFailed(Object error) => 'Falha ao sincronizar avatar: $error';
  @override
  String get toastSelfProfileUpdated =>
      'Perfil atualizado e sincronizado';
  @override
  String get toastPeerRemarkUpdated => 'Apelido atualizado';
  @override
  String get toastRestoredGroupName => 'Nome padrão do grupo restaurado';
  @override
  String get toastUpdatedGroupName => 'Nome local do grupo atualizado';
  @override
  String get toastAutoStartEnabled => 'Inicialização silenciosa ativada';
  @override
  String get toastAutoStartDisabled => 'Inicialização automática desativada';
  @override
  String get toastCloseToTrayEnabled => 'Fechar minimizará para a bandeja';
  @override
  String get toastCloseToTrayDisabled => 'Fechar encerrará o aplicativo';
  @override
  String toastAndroidIncomingFile(String sender, String fileName) =>
      'Recebido de $sender: $fileName';
  @override
  String get notifyFileFallbackBody => 'Novo arquivo salvo automaticamente';
  @override
  String notifyBatchFilesReceiving(String fileLabel, int totalCount) =>
      'Recebendo $fileLabel e mais ($totalCount no total)';
  @override
  String notifyNewFileTitle(String sender) => 'Novo arquivo · $sender';
  @override
  String notifyNewTextTitle(String sender) => 'Nova mensagem · $sender';
  @override
  String get notifyNewEncryptedText => 'Nova mensagem criptografada';
  @override
  String get errorEmptyImageFile => 'O arquivo de imagem está vazio';
  @override
  String get errorCompressAvatarFailed => 'Falha ao comprimir avatar';
  @override
  String get errorPngEncodeFailed => 'Falha ao codificar PNG';
  @override
  String formatUsbRouteMessage({
    required bool usbTetherDetected,
    required bool metricProtected,
    required bool needsElevation,
    String? usbIfName,
  }) {
    if (!usbTetherDetected) return 'Nenhum adaptador USB tethering detectado';
    if (metricProtected) {
      return 'Métrica USB definida em 5000 sem afetar a internet do PC';
    }
    if (needsElevation) {
      return 'Permissão de administrador necessária para definir métrica USB em 5000';
    }
    return 'Ancoragem USB detectada, aguardando ajuste de métrica';
  }

  @override
  String get winTrayTooltip => 'Transferência Privada P2P · Serviço ativo';
  @override
  String get winTrayOpenWindow => 'Abrir janela principal';
  @override
  String get winTrayAutoStart => 'Iniciar minimizado com o Windows';
  @override
  String get winTrayCloseToTray => 'Minimizar para bandeja ao fechar';
  @override
  String get winTrayExitApp => 'Sair do aplicativo';
}
