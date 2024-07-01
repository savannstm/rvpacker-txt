# rvpacker-txt

A tool to read RPG Maker data files to .txt files and write them back to the initial form. It's a port of Darkness9724's
port of Ruby 1.9.x's rvpacker to Ruby 3.x to use .txt files instead of YAML, and overall improve the code quality.

rvpacker consists of 3 parts:

* RPG library (stub classes for serialization of RPGMaker game data)
* RGSS library (some more classes for RPGMaker serialization)
* rvpacker-txt (the script you call on the frontend)

# Installation

```
$ gem install rvpacker-txt
```

Usage
=====

```
$ rvpacker-txt -h
Usage: rvpacker-txt COMMAND [options]

COMMANDS:
    read - Parses RPG Maker game files to .txt
    write - Writes parsed files back to their initial form
OPTIONS:
    -d, --input-dir DIRECTORY        Input directory of RPG Maker project.
                                     Must contain "Data" or "original" folder to read,
                                     and additionally "translation" with "maps" and  "other" subdirectories to write.
    -l, --log                        Log information while processing.
    -s, --shuffle NUMBER             At value 1: Shuffles all lines in strings, at value 2: shuffles all lines and words in strings.
    -h, --help                       Show help message.
```

For example, to read a RPG Maker VX Ace project in E:/Documents/RPGMakerGame to .txt files:

```
$ rvpacker read --input-dir E:/Documents/RPGMakerGame
```

Program determines game engine automatically.

This will parse all text from Data/* files into translation/maps and translation/other directories as files without
_trans postfix that contain original text and files with _trans postfix that contain empty lines for translation.
Lines from Scripts file will be parsed into translation/other/scripts.txt file as plain text.

To write previously parsed project back to its initial form:

```
$ rvpacker write --input-dir E:/Documents/RPGMakerGame
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