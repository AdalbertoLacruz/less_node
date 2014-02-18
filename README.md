## Less integration for pub

[Less](http://lesscss.org/)-transformer for [pub-build](http://pub.dartlang.org/doc/pub-build.html).

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
          executable: /path/to/lessc
          entry_point: path/to/builder.less
          output: /path/to/builded.css
          include_path: /path/to/directory/for/less/includes
          cleancss: true or false
          compress: true or false

