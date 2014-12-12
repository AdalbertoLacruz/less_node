## Less integration for pub

[Less](http://lesscss.org/)-transformer for [pub-serve](http://pub.dartlang.org/doc/pub-serve.html) and 
[pub-build](http://pub.dartlang.org/doc/pub-build.html).

## Usage

Simply add the following lines to your `pubspec.yaml`:

    dependencies:
      less_node: any
    transformers:
      - less_node:
      		entry_point: web/builder.less

After adding the transformer your entry_point `.less` file will be automatically transformed to
corresponding `.css` file.

You need to have [Less](http://lesscss.org/) installed and available on the path, as a nodejs npm module.

## Configuration

You can also pass options to Lessc if necessary:

    transformers:
      - less_node:
          entry_points: 
          	- path/to/builder.less
          	- or/other.less
          output: /path/to/builded.css
          include_path: /path/to/directory/for/less/includes
          cleancss: true or false
          compress: true or false
          executable: /path/to/lessc
          build_mode: less, dart or mixed
          run_in_shell: true or false
          other_flags:
            - to include in the lessc command line
          
- entry_point - Is the ONLY option required. Normally is a builder file with "@import 'filexx.less'; ..." directives.
- entry_points - Alternative to entry_point. Let process several .less input files.
- output - Only works with one entry_point file. Is the .css file generated. 
		If not supplied (or several entry_points) then input .less with .css extension changed is used.
- include_path - see [Less Documentation include_path](http://lesscss.org/usage/#command-line-usage-include-paths).
- cleancss - see [Less Documentation clean-css](http://lesscss.org/usage/#command-line-usage-clean-css).
- compress - see [Less Documentation compress](http://lesscss.org/usage/#command-line-usage-compress).
- executable - by default 'lessc' as node npm work result.
- build_mode -
	- less - command 'CMD> lessc --flags input.less > output.css' is used.
	- dart - command 'CMD> lessc --flags -' with stdin and stdout piped in the dart transformer process. See build folder.
	- mixed - command 'CMD> lessc --flags input.less' with stdout managed by the dart transformer process. See build folder.
- run_in_shell - in windows lessc.cmd needs a shell, so run_in_shell default is true for this platform.
- other_flags - Let add other flags such as (-line-numbers=comments, ...) in the lessc command line.
