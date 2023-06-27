import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:math' as math;

import 'package:chat_module/features/chat/widgets/date_divider.dart';
import 'package:chat_module/features/chat/widgets/fixed_header.dart';
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
  final StreamController<int> _streamController = StreamController<int>();
  final LinkedHashMap<String, GlobalKey> _keys = LinkedHashMap();
  final GlobalKey _key = GlobalKey();
  int _topElementIndex = 0;
  List<String> dateList = [];
  // RenderBox? _listBox;
  RenderBox? _headerBox;
  GlobalKey? _groupHeaderKey;

  @override
  void initState() {
    super.initState();
    messageController.addListener(handleScroll);
  }

  @override
  void dispose() {
    super.dispose();
    _streamController.close();
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
    // _listBox ??= _key.currentContext?.findRenderObject() as RenderBox?;
    // var listPos = _listBox?.localToGlobal(Offset.zero).dy ?? 0;
    _headerBox ??= _groupHeaderKey?.currentContext?.findRenderObject() as RenderBox?;
    var headerHeight = _headerBox?.size.height ?? 0;
    var max = double.negativeInfinity;
    var topItemKey = '${dateList.length - 1}';
    for (var entry in _keys.entries) {
      var key = entry.value;
      if (_isListItemRendered(key)) {
        var itemBox = key.currentContext!.findRenderObject() as RenderBox;
        var y = itemBox.localToGlobal(Offset(0, -headerHeight)).dy;
        if (y <= headerHeight && y > max) {
          topItemKey = entry.key;
          max = y;
        }
      }
    }
    var index = math.max(int.parse(topItemKey), 0);
    if (index != _topElementIndex) {
      var curr = index;
      var prev = _topElementIndex;

      if (prev != curr) {
        _topElementIndex = index;
        _streamController.add(_topElementIndex);
      }
    }
  }

  bool _isListItemRendered(GlobalKey<State<StatefulWidget>> key) {
    return key.currentContext != null && key.currentContext!.findRenderObject() != null;
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
      key: _key,
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
                    final dateFormat =
                        DateFormat.yMEd('ko').format(messageData.timeSent).replaceAll('(', '').replaceAll(')', '');
                    if (!dateList.contains(dateFormat)) {
                      dateList.insert(0, dateFormat);
                    }
                    GlobalKey<State<StatefulWidget>> key;
                    if (dateList.isEmpty) {
                      key = _keys.putIfAbsent('0', () => GlobalKey());
                    } else {
                      /**
                       * 스크롤 할 때 마다 화면 전체를 빌드해버림
                       * 그러면서 _keys에 다시 사용하게 되는게 이전에 있던 key값들은 이미 사용중이기 때문에 다시 빌드 중에 오류 발생
                       * dateList는 초기화 되지 않는 다는 말이지 'key'값이 존재한다면 다른 Globalkey()를 생성해서 만들어줘야함.
                       */
                      if (_keys.containsKey('${dateList.length - 1}')) {
                        _keys['${dateList.length - 1}'] = GlobalKey();
                        key = _keys.putIfAbsent('${dateList.length - 1}', () => GlobalKey());
                      } else {
                        key = _keys.putIfAbsent('${dateList.length - 1}', () => GlobalKey());
                      }
                    }
                    return Column(
                      children: [
                        DateDivider(key: key, date: messageData.timeSent),
                        _buildMessageCard(messageData, timeSent),
                      ],
                    );
                  }

                  // 이전 메시지와 날짜가 같을 경우에는 DateDivider 없이 메시지 카드만 생성합니다.
                  return _buildMessageCard(messageData, timeSent);
                },
              );
            }),
        StreamBuilder(
            stream: _streamController.stream,
            initialData: _topElementIndex,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                _groupHeaderKey = GlobalKey();
                return FixedHeader(
                  groupHeaderKey: _groupHeaderKey,
                  context: context,
                  dateList: dateList,
                  index: snapshot.data!,
                );
              }
              return const SizedBox.shrink();
            }),
      ],
    );
  }
}
