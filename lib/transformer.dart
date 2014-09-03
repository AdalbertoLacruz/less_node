/*
 * Copyright (c) 2014, adalberto.lacruz@gmail.com
 * Thanks to juha.komulainen@evident.fi for inspiration and some code
 * (Copyright (c) 2013 Evident Solutions Oy) from package http://pub.dartlang.org/packages/sass
 *
 * v 0.1.3  20140903 build_mode, run_in_shell, options, time
 * v 0.1.2  20140527 use stdout instead of '>'; beatgammit@gmail.com
 * v 0.1.1  20140521 compatibility with barback (0.13.0) and lessc (1.7.0);
 * v 0.1.0  20140218
 */
library less.transformer;

import 'dart:async';
import 'dart:io';
import 'package:barback/barback.dart';
import 'package:barback/src/utils.dart' as utils;
import 'package:utf/utf.dart';

const String INFO_TEXT = '[Info from less-node]';
const String BUILD_MODE_LESS = 'less';
const String BUILD_MODE_DART = 'dart';
const String BUILD_MODE_MIXED = 'mixed';

/*
 * Transformer used by 'pub build' & 'pub serve' to convert .less files to .css
 * Based on lessc over nodejs executing a process like
 * CMD> lessc --flags input.less > output.css
 * It Use only one file as entry point and produces only one css file
 * To mix several .less files, the input contents could be "@import 'filexx.less'; ..." directives
 * See http://lesscss.org/ for more information
 */
class LessTransformer extends Transformer {
  final BarbackSettings settings;
  final TransformerOptions options;

  bool get isBuildModeLess => options.build_mode == BUILD_MODE_LESS;   //input file, output file
  bool get isBuildModeDart => options.build_mode == BUILD_MODE_DART;   //input stdin, output stdout
  bool get isBuildModeMixed => options.build_mode == BUILD_MODE_MIXED; //input file, output stdout

  LessTransformer(BarbackSettings settings):
    settings = settings,
    options = new TransformerOptions.parse(settings.configuration) {
      if(options.entry_point == '') print('$INFO_TEXT No entry_point supplied!');
  }

  LessTransformer.asPlugin(BarbackSettings settings):
    this(settings);

  Future<bool> isPrimary (AssetId id) {
    return new Future.value(_isEntryPoint(id));
  }

  Future apply(Transform transform) {
    List<String> flags = _createFlags();  //to build process arguments
    var id = transform.primaryInput.id;
    String inputFile = id.path;
    String outputFile = options.output == '' ? id.changeExtension('.css').path : options.output;

    switch (options.build_mode) {
      case BUILD_MODE_DART:
        flags.add('-');
        break;
      case BUILD_MODE_MIXED:
        flags.add(inputFile);
        break;
      case BUILD_MODE_LESS:
      default:
        flags.add(inputFile);
        flags.add('>');
        flags.add(outputFile);
    }
    print('$INFO_TEXT command: ${options.executable} ${flags.join(' ')}');
    if (isBuildModeDart) print('$INFO_TEXT input File: $inputFile');
    if (isBuildModeMixed || isBuildModeDart) print('$INFO_TEXT outputFile: $outputFile');
    
    return transform.primaryInput.readAsString().then((content){
      transform.consumePrimary();
      return executeProcess(options.executable, flags, content).then((output) {
        if (isBuildModeMixed || isBuildModeDart){
          transform.addOutput(new Asset.fromString(new AssetId(id.package, outputFile), output));
        }
      });
    });
  }

  /*
   * only returns true in entry_point file
   */
  bool _isEntryPoint(AssetId id) {
    if (id.extension != '.less') return false;
    return options.entry_point == id.path;
  }
  
  List<String> _createFlags(){
    List<String> flags = [];
    
    flags.add('--no-color');
    if (options.cleancss) flags.add('--clean-css');
    if (options.compress) flags.add('--compress');
    if (options.include_path != '') flags.add('--include-path=${options.include_path}');
    
    return flags;
  }

  /*
   * lessc process wrapper
   */
  Future executeProcess(String executable, List<String> flags, String content) {
    final _timeInProcess = new Stopwatch();

    return Process.start(executable, flags, runInShell: options.run_in_shell).then((Process process) {
      _timeInProcess.start();

      StringBuffer output = new StringBuffer();
      process.stdout.transform(new Utf8DecoderTransformer()).listen((str) => output.write(str));
      stderr.addStream(process.stderr);

      if (isBuildModeDart) {
        process.stdin.write(content);
        process.stdin.close();
      }

      return process.exitCode.then((exitCode) {
        _timeInProcess.stop();
        if (exitCode == 0) {
          print ('$INFO_TEXT $executable process completed in ${utils.niceDuration(_timeInProcess.elapsed)}');
          return output.toString();
        } else {
          throw new LessException(stderr.toString());
        }
      });

    }).catchError((ProcessException e) {
      throw new LessException(e.toString());
    }, test: (e) => e is ProcessException);
  }
}

class TransformerOptions {
  final String entry_point;  // entry_point: web/builder.less - main file to build
  final String include_path; // include_path: /lib/lessIncludes - variable and mixims files
  final String output;       // output: web/output.css - result file. If '' same as web/input.css
  final bool cleancss;       // cleancss: true - compress output by using clean-css
  final bool compress;       // compress: true - compress output by removing some whitespaces

  final String executable;   // executable: lessc - command to execute lessc
  final String build_mode;   // build_mode: less - io managed by lessc compiler (less) by (dart) or (mixed)
  final bool run_in_shell;   // run_in_shell: true - in windows less.cmd needs a shell to run

  TransformerOptions({String this.entry_point, String this.include_path, String this.output, bool this.cleancss, bool this.compress,
    String this.executable, String this.build_mode, bool this.run_in_shell});

  factory TransformerOptions.parse(Map configuration){

    config(key, defaultValue) {
      var value = configuration[key];
      return value != null ? value : defaultValue;
    }

    return new TransformerOptions (
        entry_point: config('entry_point', ''),
        include_path: config('include_path', ''),
        output: config('output', ''),
        cleancss: config('cleancss', false),
        compress: config('compress', false),

        executable: config('executable', 'lessc'),
        build_mode: config('build_mode', BUILD_MODE_LESS),
        run_in_shell: config('run_in_shell', Platform.isWindows)
    );
  }
}

/* ************************************** */
/*
 * process error management
 */
class LessException implements Exception {
  final String message;

  LessException(this.message);

  String toString() => '\n$message';
}