/*
 * Copyright (c) 2014, adalberto.lacruz@gmail.com
 * Thanks to juha.komulainen@evident.fi for inspiration and some code
 * (Copyright (c) 2013 Evident Solutions Oy) from package http://pub.dartlang.org/packages/sass
 *
 * v 0.1.1  20140521 compatibility with barback (0.13.0) and lessc (1.7.0)
 * v 0.1.0  20140218
 */
library less.transformer;

import 'dart:async';
import 'dart:io';
import 'package:barback/barback.dart';

/*
 * Transformer used by 'pub build' to convert .less files to .css
 * Based on lessc over nodejs executing a process like
 * CMD> lessc --flags input.less > output.css
 * Uses only one file as entry point and produces only one css file
 * To mix several .less files, the input contents could have "@import 'filexx.less'; ..." directives
 * See http://lesscss.org/ for more information
 */
class LessTransformer extends Transformer {
  final BarbackSettings settings;
  bool cleancss = false;  // cleancss: true - compress output by using clean-css
  bool compress = false;  // compress: true - compress output by removing some whitespaces
  String entry_point = ''; // entry_point: web/builder.less - main file to build
  String executable = 'lessc'; //executable: lessc - command to execute lessc
  String include_path = ''; // include_path: /lib/lessIncludes - variable and mixims files
  String output = ''; //output: web/output.css - result file. If '' same as web/input.css

  List<String> flags = [];  //to build process arguments

  LessTransformer.asPlugin(this.settings) {
    var args = settings.configuration;

    if(args['cleancss'] != null) cleancss = args['cleancss'];
    if(args['compress'] != null) compress = args['compress'];
    if(args['entry_point'] != null) entry_point = args['entry_point'];
    if(args['executable'] != null) executable = args['executable'];
    if(args['include_path'] != null) include_path = args['include_path'];
    if(args['output'] != null) output = args['output'];

    //print('\n[Info from less_node transformer]:');
    if(entry_point == '') print('\nless_node> No entry_point supplied!');
  }

  Future<bool> isPrimary (AssetId id) {
    return new Future.value(_isEntryPoint(id));
  }

  Future apply(Transform transform) {
    var input = transform.primaryInput;
    String inputFile = input.id.path;
    String outputFile = output == '' ? input.id.changeExtension('.css').path : output;
    flags = [];
    flags.add('--no-color');
    if (cleancss) flags.add('--clean-css');
    if (compress) flags.add('--compress');
    if (include_path != '') flags.add('--include-path=' + include_path);
    flags.add(inputFile);
    flags.add('>');
    flags.add(outputFile);

    return executeProcess(executable, flags);
  }

  /*
   * only returns true in entry_point file
   */
  bool _isEntryPoint(AssetId id) {
    if (id.extension != '.less') return false;
    return entry_point == id.path;
  }

  /*
   * lessc process wrapper
   */
  Future executeProcess(String executable, List<String>Flags) {
    print('\nless_node> command: $executable ${Flags.join(' ')}');

    return Process.start(executable, flags, runInShell: true).then((process) {
      stdout.addStream(process.stdout);
      stderr.addStream(process.stderr);

      return process.exitCode.then((exitCode) {
        if (exitCode == 0) {
          print ('less_node> $executable process completed');
          return;
        } else {
          throw new LessException(stderr.toString());
        }
      });

    }).catchError((ProcessException e) {
      throw new LessException(e.toString());
    }, test: (e) => e is ProcessException);
  }
}
/* ************************************** */
/*
 * process error management
 */
class LessException implements Exception {
  final String message;

  LessException(this.message);

  String toString() => '\n' + message;
}