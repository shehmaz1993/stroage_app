class TransferCancelledException implements Exception {
  final String message;
  TransferCancelledException([this.message = "Transfer was deliberately cancelled."]);
}