# rvpacker-txt

A tool to read RPG Maker data files to .txt files and write them back to the initial form. It's a port of Darkness9724's
port of Ruby 1.9.x's rvpacker to Ruby 3.x to use .txt files instead of YAML, and overall improve the code quality.

rvpacker consists of 3 parts:

* classes.rb library - all necessary classes to properly load and dump RPG Maker files
* read.rb library - all necessary functions for reading and parsing RPG Maker files to text
* write.rb library - all necessary functions for writing parsed RPG Maker files back to their initial form.

# Installation

```
$ gem install rvpacker-txt
```

# Usage

You can get a help message on usage using `rvpacker-txt -h`.

```
$ rvpacker-txt -h
This tool allows to parse RPG Maker games to .txt files and write them back to their initial form.

Usage: rvpacker-txt COMMAND [OPTIONS]

COMMANDS:
    read - Parses files from "original" or "data" folders of input directory to "translation" folder of output directory.
    write - Writes translated files using original files from "original" or "data" folder of input directory and writes results to "output" folder of output directory.
OPTIONS:
    -i, --input-dir PATH             When reading: Input directory, containing folders "original" or "data" with original game files.
                                     When writing: Input directory, containing folders "original" or "data" and "translation" with original game files and .txt files with translation respectively.
    -o, --output-dir PATH            When reading: Output directory, where a "translation" folder will be created, containing parsed .txt files with the text from the game.
                                     When writing: Output directory, where an "output" folder will be created, containing compiled RPG Maker files with your translation.
        --disable-processing FILES   Skips processing specified files.
                                     Example: --disable-processing=maps,other,system.
                                     [Allowed values: maps, other, system, scripts]
        --disable-custom-processing  Disables built-in custom parsing/writing for some games.
                                     This flag will automatically be used when writing if you parsed game text with it.
    -l, --log                        Enables logging.
    -h, --help                       Prints the program's help message or for the entered subcommand.
```

For example, to read a RPG Maker VX Ace project in E:/Documents/RPGMakerGame to .txt files:

```
$ rvpacker-txt read --input-dir E:/Documents/RPGMakerGame
```

Program determines game engine automatically.

This will parse all text from Data/* files into translation/maps and translation/other directories as files without
_trans postfix that contain original text and files with _trans postfix that contain empty lines for translation.
Lines from Scripts file will be parsed into translation/other/scripts.txt file as plain text, and
also into a scripts_plain.txt file that contains scripts contents as a whole - that's just for convenience.

To write previously parsed project back to its initial form:

```
$ rvpacker-txt write --input-dir E:/Documents/RPGMakerGame
```

This will take all of translation lines from _trans files from the translation subdirectories and repack all of them
to their initial form in output directory.

## General

This is great for collaborating on translations and have clean version control.
You can easily push .txt files and easily merge them.

Now your translation can be forked/merged in an extremely easy way.

## Credit to previous authors

The RPG and RGSS libraries were originally taken from SiCrane's YAML importer/exporter on the gamedev forums.

http://www.gamedev.net/topic/646333-rpg-maker-vx-ace-data-conversion-utility/

akesterson, ymaxkrapzv and BigBlueHat created an original rvpacker repository with the initial frontend for SiCrane's
YAML importer/exporter.

https://github.com/ymaxkrapzv/rvpacker

Darkness9724 forked rvpacker to rvpacker-ng, ported it to Ruby 3.x and updated dependencies.

https://gitlab.com/Darkness9724/rvpacker-ng
