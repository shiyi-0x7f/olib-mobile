/// 微信读书 API — Barrel Export
///
/// ```dart
/// import 'package:olib_mobile/services/weread/weread.dart';
///
/// final api = WereadApi(apiKey: 'wrk-xxxxxxxx');
/// final result = await api.search(keyword: '三体');
/// ```
library;

export 'weread_api.dart';
export 'weread_client.dart';
export 'weread_errors.dart';
export 'weread_models.dart';
