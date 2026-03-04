enum DictionaryBootstrapStatus {
  idle,
  inProgress,
  ready,
  failed,
}

class DictionaryBootstrapState {
  const DictionaryBootstrapState({
    required this.status,
    required this.datasetVersion,
    required this.batchId,
    required this.rowCount,
    required this.downloadedCount,
    required this.lastSeqId,
    required this.updatedAt,
    this.errorMessage,
  });

  final DictionaryBootstrapStatus status;
  final String datasetVersion;
  final String? batchId;
  final int rowCount;
  final int downloadedCount;
  final int lastSeqId;
  final DateTime? updatedAt;
  final String? errorMessage;

  bool get isReady => status == DictionaryBootstrapStatus.ready;

  double get progress {
    if (rowCount <= 0) {
      return 0;
    }
    final int value = downloadedCount > rowCount ? rowCount : downloadedCount;
    return value / rowCount;
  }

  DictionaryBootstrapState copyWith({
    DictionaryBootstrapStatus? status,
    String? datasetVersion,
    String? batchId,
    int? rowCount,
    int? downloadedCount,
    int? lastSeqId,
    DateTime? updatedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DictionaryBootstrapState(
      status: status ?? this.status,
      datasetVersion: datasetVersion ?? this.datasetVersion,
      batchId: batchId ?? this.batchId,
      rowCount: rowCount ?? this.rowCount,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      lastSeqId: lastSeqId ?? this.lastSeqId,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  factory DictionaryBootstrapState.initial() {
    return const DictionaryBootstrapState(
      status: DictionaryBootstrapStatus.idle,
      datasetVersion: '',
      batchId: null,
      rowCount: 0,
      downloadedCount: 0,
      lastSeqId: 0,
      updatedAt: null,
      errorMessage: null,
    );
  }
}
