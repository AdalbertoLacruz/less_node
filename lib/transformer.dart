/*
 * Copyright (c) 2014, adalberto.lacruz@gmail.com
 * Thanks to juha.komulainen@evident.fi for inspiration and some code
 * (Copyright (c) 2013 Evident Solutions Oy) from package http://pub.dartlang.org/packages/sass
 *
 * v 0.2.1  20141212 niceDuration, other_flags argument
 * v 0.2.0  20140905 entry_point(s) multifile
 * v 0.1.3  20140903 build_mode, run_in_shell, options, time
 * v 0.1.2  20140527 use stdout instead of '>'; beatgammit@gmail.com
 * v 0.1.1  20140521 compatibility with barback (0.13.0) and lessc (1.7.0);
 * v 0.1.0  20140218
 */
library less.transformer;

import 'dart:async';
import 'dart:io';
import 'package:barback/barback.dart';
//import 'package:barback/src/utils.dart' as utils;
import 'package:utf/utf.dart';

const String INFO_TEXT = '[Info from less-node]';
const String BUILD_MODE_LESS = 'less';
const String BUILD_MODE_DART = 'dart';
const String BUILD_MODE_MIXED = 'mixed';

/*
 * Transformer used by 'pub build' & 'pub serve' to convert .less files to .css
 * Based on lessc over nodejs executing a process like
 * CMD> lessc --flags input.less > output.css
 * It use one or various files as entry point and produces the css files
 * To mix several .less files in one, the input contents could be "@import 'filexx.less'; ..." directives
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
    options = new TransformerOptions.parse(settings.configuration);

  LessTransformer.asPlugin(BarbackSettings settings):
    this(settings);

  Future<bool> isPrimary (AssetId id) {
    return new Future.value(_isEntryPoint(id));
  }

  Future apply(Transform transform) {
    List<String> flags = _createFlags();  //to build process arguments
    var id = transform.primaryInput.id;
    String inputFile = id.path;
    String outputFile = getOutputFileName(id);

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

    ProcessInfo processInfo = new ProcessInfo(options.executable, flags);
    if (isBuildModeDart) processInfo.inputFile = inputFile;
    if (isBuildModeMixed || isBuildModeDart) processInfo.outputFile = outputFile;

    return transform.primaryInput.readAsString().then((content){
      transform.consumePrimary();
      return executeProcess(options.executable, flags, content, processInfo).then((output) {

        if (isBuildModeMixed || isBuildModeDart){
          transform.addOutput(new Asset.fromString(new AssetId(id.package, outputFile), output));
        }
      });
    });
  }

  /*
   * only returns true in entry_point(s) file
   */
  bool _isEntryPoint(AssetId id) {
    if (id.extension != '.less') return false;
    return (options.entry_points.contains(id.path));
  }

  List<String> _createFlags(){
    List<String> flags = [];

    flags.add('--no-color');
    if (options.cleancss) flags.add('--clean-css');
    if (options.compress) flags.add('--compress');
    if (options.include_path != '') flags.add('--include-path=${options.include_path}');
    if (options.other_flags != null) flags.addAll(options.other_flags);

    return flags;
  }

  String getOutputFileName(id) {
    if(options.entry_points.length > 1 || options.output == '') {
      return id.changeExtension('.css').path;
    }
    return options.output;
  }

  /*
   * lessc process wrapper
   */
  Future executeProcess(String executable, List<String> flags, String content, ProcessInfo processInfo) {
    final _timeInProcess = new Stopwatch();

    return Process.start(executable, flags, runInShell: options.run_in_shell).then((Process process) {
      _timeInProcess.start();

      StringBuffer output = new StringBuffer();
      StringBuffer errors = new StringBuffer();
      process.stdout.transform(new Utf8DecoderTransformer()).listen((str) => output.write(str));
      process.stderr.transform(new Utf8DecoderTransformer()).listen((str) => errors.write(str));

      if (isBuildModeDart) {
        process.stdin.write(content);
        process.stdin.close();
      }

      return process.exitCode.then((exitCode) {
        _timeInProcess.stop();
        if (exitCode == 0) {
          processInfo.nicePrint(_timeInProcess.elapsed);
          return output.toString();
        } else {
          throw new LessException(errors.toString());
        }
      });

    }).catchError((ProcessException e) {
      throw new LessException(e.toString());
    }, test: (e) => e is ProcessException);
  }
}
/* ************************************** */
class TransformerOptions {
  final List<String> entry_points;  // entry_point: web/builder.less - main file to build or [file1.less, ...,fileN.less]
  final String include_path; // include_path: /lib/lessIncludes - variable and mixims files
  final String output;       // output: web/output.css - result file. If '' same as web/input.css
  final bool cleancss;       // cleancss: true - compress output by using clean-css
  final bool compress;       // compress: true - compress output by removing some whitespaces

  final String executable;   // executable: lessc - command to execute lessc
  final String build_mode;   // build_mode: less - io managed by lessc compiler (less) by (dart) or (mixed)
  final bool run_in_shell;   // run_in_shell: true - in windows less.cmd needs a shell to run
  final List other_flags;    // other options in the command line

  TransformerOptions({List<String> this.entry_points, String this.include_path, String this.output, bool this.cleancss, bool this.compress,
    String this.executable, String this.build_mode, bool this.run_in_shell, List this.other_flags});

  factory TransformerOptions.parse(Map configuration){

    config(key, defaultValue) {
      var value = configuration[key];
      return value != null ? value : defaultValue;
    }

    List<String> readStringList(value) {
      if (value is List<String>) return value;
      if (value is String) return [value];
      return null;
    }

    List<String> readEntryPoints(entryPoint, entryPoints) {
      List<String> result = [];
      List<String> value;

      value = readStringList(entryPoint);
      if (value != null) result.addAll(value);

      value = readStringList(entryPoints);
      if (value != null) result.addAll(value);

      if (result.length < 1) print('$INFO_TEXT No entry_point supplied!');
      return result;
    }

    return new TransformerOptions (
        entry_points: readEntryPoints(configuration['entry_point'], configuration['entry_points']),
        include_path: config('include_path', ''),
        output: config('output', ''),
        cleancss: config('cleancss', false),
        compress: config('compress', false),

        executable: config('executable', 'lessc'),
        build_mode: config('build_mode', BUILD_MODE_LESS),
        run_in_shell: config('run_in_shell', Platform.isWindows),
        other_flags: readStringList(configuration['other_flags'])
    );
  }
}
/* ************************************** */
class ProcessInfo {
  String executable;
  List<String> flags;
  String inputFile = '';
  String outputFile = '';

  ProcessInfo(this.executable, this.flags);

  nicePrint(Duration elapsed){
    print('$INFO_TEXT command: $executable ${flags.join(' ')}');
    if (inputFile  != '') print('$INFO_TEXT input File: $inputFile');
    if (outputFile != '') print('$INFO_TEXT outputFile: $outputFile');
    print ('$INFO_TEXT $executable process completed in ${niceDuration(elapsed)}');
  }

  /// Returns a human-friendly representation of [duration].
  //from barback - Copyright (c) 2013, the Dart project authors
  String niceDuration(Duration duration) {
  var result = duration.inMinutes > 0 ? "${duration.inMinutes}:" : "";

  var s = duration.inSeconds % 59;
  var ms = (duration.inMilliseconds % 1000) ~/ 100;
  return result + "$s.${ms}s";
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