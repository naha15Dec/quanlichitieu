class ChatMessageModel {
  final String text;
  final bool isUser;
  final DateTime createdAt;

  ChatMessageModel({
    required this.text,
    required this.isUser,
    required this.createdAt,
  });
}
