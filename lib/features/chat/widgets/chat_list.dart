import 'package:chat_module/features/chat/widgets/date_divider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chat_module/common/enums/message_enum.dart';
import 'package:chat_module/common/providers/message_reply_provider.dart';
import 'package:chat_module/common/widgets/loader.dart';

import 'package:chat_module/features/chat/controller/chat_controller.dart';
import 'package:chat_module/features/chat/widgets/my_message_card.dart';
import 'package:chat_module/features/chat/widgets/sender_message_card.dart';
import 'package:chat_module/models/message.dart';

class ChatList extends ConsumerStatefulWidget {
  final String recieverUserId;
  final bool isGroupChat;
  const ChatList({
    Key? key,
    required this.recieverUserId,
    required this.isGroupChat,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> {
  final ScrollController messageController = ScrollController();

  bool isScrolling = false; // 스크롤 중인지 여부
  DateTime? currentMessageDate; // 현재 메시지의 날짜

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    messageController.dispose();
  }

  void onMessageSwipe(
    String message,
    bool isMe,
    MessageEnum messageEnum,
  ) {
    ref.read(messageReplyProvider.notifier).update(
          (state) => MessageReply(
            message,
            isMe,
            messageEnum,
          ),
        );
  }

  void handleScroll() {
    if (messageController.offset == messageController.position.maxScrollExtent &&
        !messageController.position.outOfRange) {
      print('스크롤이 맨 바닥에 위치해 있습니다');
    } else if (messageController.offset == messageController.position.minScrollExtent &&
        !messageController.position.outOfRange) {
      print('스크롤이 맨 위에 위치해 있습니다');
    }

    print('offset = ${messageController.offset}');
  }

  bool _isDifferentDate(DateTime currentDate, DateTime previousDate) {
    return currentDate.year != previousDate.year ||
        currentDate.month != previousDate.month ||
        currentDate.day != previousDate.day;
  }

  Widget _buildMessageCard(Message messageData, String timeSent) {
    if (messageData.senderId == FirebaseAuth.instance.currentUser!.uid) {
      return MyMessageCard(
        message: messageData.text,
        date: timeSent,
        type: messageData.type,
        repliedText: messageData.repliedMessage,
        username: messageData.repliedTo,
        repliedMessageType: messageData.repliedMessageType,
        onLeftSwipe: () => onMessageSwipe(
          messageData.text,
          true,
          messageData.type,
        ),
        isSeen: messageData.isSeen,
      );
    } else {
      return SenderMessageCard(
        message: messageData.text,
        date: timeSent,
        type: messageData.type,
        username: messageData.repliedTo,
        repliedMessageType: messageData.repliedMessageType,
        onRightSwipe: () => onMessageSwipe(
          messageData.text,
          false,
          messageData.type,
        ),
        repliedText: messageData.repliedMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<Message>>(
            stream: widget.isGroupChat
                ? ref.read(chatControllerProvider).groupChatStream(widget.recieverUserId)
                : ref.read(chatControllerProvider).chatStream(widget.recieverUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Loader();
              }

              /**
               * 위젯 빌드 완료 시 화면 제일 아래로 이동
               */
              SchedulerBinding.instance.addPostFrameCallback((_) {
                messageController.jumpTo(messageController.position.maxScrollExtent);
              });

              return ListView.builder(
                controller: messageController,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final messageData = snapshot.data![index];
                  var timeSent = DateFormat.Hm().format(messageData.timeSent);

                  // 읽음 확인
                  if (!messageData.isSeen && messageData.recieverid == FirebaseAuth.instance.currentUser!.uid) {
                    ref.read(chatControllerProvider).setChatMessageSeen(
                          context,
                          widget.recieverUserId,
                          messageData.messageId,
                        );
                  }

                  // 날짜가 변경되었을 때, DateDivider 위젯을 생성하여 표시합니다.
                  if (index == 0 || _isDifferentDate(messageData.timeSent, snapshot.data![index - 1].timeSent)) {
                    return Column(
                      children: [
                        DateDivider(date: messageData.timeSent),
                        _buildMessageCard(messageData, timeSent),
                      ],
                    );
                  }

                  // 이전 메시지와 날짜가 같을 경우에는 DateDivider 없이 메시지 카드만 생성합니다.
                  return _buildMessageCard(messageData, timeSent);
                },
              );
            }),
        if (isScrolling)
          Container(
            child: Text('하이'),
          ),
      ],
    );
  }
}
