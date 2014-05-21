library less.transformer.test;

import 'dart:async';
import 'package:unittest/unittest.dart';
import 'package:less_node/transformer.dart';
import 'package:barback/barback.dart';

main() {
  Future<bool> isPrimary(String path) {
    var asset = new Asset.fromString(new AssetId('test_package', path), 'test_contents');
    var settings = new BarbackSettings({'entry_point': 'foo.less'}, BarbackMode.DEBUG);
    return new LessTransformer.asPlugin(settings).isPrimary(asset.id);
  }

  group('entry_point', () {
    test('detecting foo.less', () {
        expect(isPrimary('foo.less'), completion(isTrue));
    });

    test('no detecting nofoo.less', () {
            expect(isPrimary('nofoo.less'), completion(isFalse));
    });
  });
}