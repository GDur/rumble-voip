import 'package:flutter/widgets.dart';

class LayoutConstants {
  static const double slimBreakpoint = 450.0;

  static bool isSlim(BuildContext context) {
    return MediaQuery.of(context).size.width < slimBreakpoint;
  }
}
