import 'package:flutter/material.dart';

class FixedHeaderController extends ChangeNotifier {
  GlobalKey<State<StatefulWidget>>? groupHeaderKey;
  int currentIndex = 0;

  void updateGroupHeaderKey(GlobalKey<State<StatefulWidget>> key) {
    groupHeaderKey = key;
  }

  void updateCurrentIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }
}
