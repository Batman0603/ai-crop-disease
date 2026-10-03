import 'package:flutter/material.dart';

class ChatMessage {
  const ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [
    const ChatMessage(
      text: 'Hello! I am the CropCare Assistant. I can help you understand crop diseases, symptoms, and basic treatment information.',
      isUser: false,
    ),
    const ChatMessage(
      text: 'I am currently a demo assistant. AI-powered conversations will be added in a future version.',
      isUser: false,
    ),
  ];

  final List<String> _suggestedQuestions = const [
    'What is early blight?',
    'How can I prevent crop diseases?',
    'What are common tomato diseases?',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? suggestedMessage]) {
    final message = suggestedMessage?.trim() ?? _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));

      _messages.add(
        ChatMessage(text: _placeholderResponse(message), isUser: false),
      );
    });

    _scrollToBottom();
  }

  String _placeholderResponse(String message) {
    final query = message.toLowerCase();

    if (query.contains('early blight')) {
      return 'Early blight is a fungal disease that can affect crops such as tomato and potato. Common symptoms include dark spots on leaves and progressive leaf damage. For a specific diagnosis, use the Detect feature with a clear image of the affected leaf.';
    }

    if (query.contains('prevent') ||
        query.contains('prevention') ||
        query.contains('preventing')) {
      return 'Basic disease-prevention practices include maintaining good field hygiene, removing severely affected plant material, avoiding unnecessary leaf wetness, and monitoring crops regularly. For crop-specific advice, check the Disease Library.';
    }

    if (query.contains('tomato')) {
      return 'CropCare currently includes several tomato diseases, including bacterial spot, early blight, late blight, leaf mold, Septoria leaf spot, spider mites, target spot, tomato yellow leaf curl virus, and tomato mosaic virus.';
    }

    if (query.contains('potato')) {
      return 'CropCare currently includes potato early blight and late blight. You can use the Detect feature to analyze a potato leaf image and check the Disease Library for additional information.';
    }

    if (query.contains('apple')) {
      return 'CropCare currently includes apple scab, black rot, cedar apple rust, and healthy apple leaves.';
    }

    if (query.contains('grape')) {
      return 'CropCare currently includes grape black rot, Esca (Black Measles), leaf blight, and healthy grape leaves.';
    }

    if (query.contains('corn') || query.contains('maize')) {
      return 'CropCare currently includes corn common rust, Northern Leaf Blight, Cercospora leaf spot/Gray leaf spot, and healthy corn leaves.';
    }

    if (query.contains('disease') || query.contains('symptom')) {
      return 'For an image-based disease check, open Detect and select a clear crop-leaf image. You can also browse the Disease Library for the diseases currently supported by CropCare.';
    }

    if (query.contains('treatment') || query.contains('treat')) {
      return 'Treatment depends on the crop and disease. Use Detect to identify a suspected disease, then review the treatment and management information shown on the result screen.';
    }

    return 'I am currently a placeholder assistant, so my knowledge is limited. Try asking about crop diseases, symptoms, prevention, or treatment. You can also use Detect for image-based analysis.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];

                      return _ChatBubble(message: message);
                    },
                  ),
          ),
          _buildSuggestedQuestions(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'CropCare Assistant',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask about crop diseases, symptoms, prevention, and treatment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedQuestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final question = _suggestedQuestions[index];

          return ActionChip(
            avatar: const Icon(Icons.chat_bubble_outline, size: 16),
            label: Text(question),
            onPressed: () => _sendMessage(question),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask about your crop...',
                prefixIcon: const Icon(Icons.chat_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
            tooltip: 'Send message',
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CropCare Assistant',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
