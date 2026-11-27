import 'package:flutter/widgets.dart';

/// 根导航器 key：供无 context 场景（分享回调跳转、全局提示）使用。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
