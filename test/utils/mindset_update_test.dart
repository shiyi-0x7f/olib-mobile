import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:olib_mobile/services/update/mindset_update.dart';

Map<String, dynamic> _j(String s) => jsonDecode(s) as Map<String, dynamic>;

void main() {
  test('maps force, latest and merges notes newest first', () {
    final u = MindsetUpdate.fromJson(
      _j(
        '{"current_version":"1.4.0","latest_version":"1.6.0","min_version":"1.6.0",'
        '"has_update":true,"force":true,"releases":['
        '{"id":6,"version":"1.6.0","notes":"- 新功能 A","is_critical":true},'
        '{"id":5,"version":"1.5.0","notes":"- 修复 B","is_critical":false}],'
        '"page_url":"https://www.11xy.cn/projects/olib-mobile"}',
      ),
      '1.4.0',
    );
    expect(u.hasUpdate, isTrue);
    expect(u.force, isTrue);
    expect(u.latestVersion, '1.6.0');
    expect(u.notes, 'v1.6.0\n- 新功能 A\n\nv1.5.0\n- 修复 B');
    expect(u.pageUrl, 'https://www.11xy.cn/projects/olib-mobile');
  });

  test('single release without heading, skips empty notes', () {
    final u = MindsetUpdate.fromJson(
      _j(
        '{"latest_version":"1.6.0","has_update":true,"force":false,"releases":['
        '{"version":"1.6.0","notes":null},{"version":"1.5.1","notes":"  只有这条  "}]}',
      ),
      '1.5.0',
    );
    expect(u.force, isFalse);
    expect(u.notes, '只有这条');
    expect(u.pageUrl, mindsetProjectPageUrl);
  });

  test('up to date with relative page url', () {
    final u = MindsetUpdate.fromJson(
      _j(
        '{"latest_version":null,"has_update":false,"force":false,"releases":[],'
        '"page_url":"/projects/olib-mobile"}',
      ),
      '1.6.1',
    );
    expect(u.hasUpdate, isFalse);
    expect(u.latestVersion, '1.6.1');
    expect(u.notes, '');
    expect(u.pageUrl, mindsetProjectPageUrl);
  });

  test('keeps public pan links in fixed order', () {
    final links = parseSourceLinks(
      jsonDecode('''[
        {"source_type":"xunlei_pan","url":"https://pan.xunlei.com/s/x?pwd=1","locked":false},
        {"source_type":"quark_pan","url":"https://pan.quark.cn/s/q?pwd=2"},
        {"source_type":"object_storage","url":null,"locked":true,"files":["a.apk"]},
        {"source_type":"baidu_pan","url":"https://pan.baidu.com/s/b?pwd=3","locked":false},
        {"source_type":"baidu_pan","url":"https://pan.baidu.com/s/vip","locked":true},
        {"source_type":"direct","url":"https://example.com/a.apk"},
        {"source_type":"quark_pan","url":""}
      ]''')
          as List,
    );
    expect(links.map((l) => l.name), ['百度网盘', '夸克网盘', '迅雷网盘']);
    expect(links.first.url, 'https://pan.baidu.com/s/b?pwd=3');
  });
}
