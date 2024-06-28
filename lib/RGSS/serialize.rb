# frozen_string_literal: true

# Copyright (c) 2013 Howard Jeng
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

require 'psych'
require 'fileutils'
require 'zlib'
require 'pp'
require 'formatador'
require 'set'

class IndexedSet
    def initialize
        @set = Set.new
        @index = []
    end

    def add(item)
        return if @set.include?(item)

        @set.add(item)
        @index << item
    end

    def include?(item)
        @set.include?(item)
    end

    def each(&block)
        @index.each(&block)
    end

    def to_a
        @index.dup
    end

    def join(delimiter = '')
        @index.join(delimiter)
    end
end

module RGSS
    def self.sanitize_filename(filename)
        filename.gsub(/[^0-9A-Za-z]+/, '_')
    end

    def self.files_with_extension(directory, extension)
        (
            Dir
                .entries(directory)
                .select { |file| File.extname(file) == extension }
        )
    end

    def self.inflate(str)
        Zlib::Inflate.inflate(str).force_encoding('UTF-8')
    end

    def self.deflate(str)
        Zlib::Deflate.deflate(str, Zlib::BEST_COMPRESSION)
    end

    def self.dump_data_file(file, data, _options)
        File.open(file, 'wb') { |f| Marshal.dump(data, f) }
    end

    def self.dump_txt_file(file, data, _options)
        basename = File.basename(file, '.*')
        open_options = basename.start_with?('Map') ? 'a' : 'wb'
        output_path = (basename.start_with?('Map') ? 'map.txt' : "#{basename}.txt").downcase

        File.open(output_path, open_options) do |f|
            lines = IndexedSet.new

            if !basename.start_with?('Map') && !basename.start_with?('System')
                if !basename.start_with?('Common') && !basename.start_with?('Troops')
                    data.each do |obj|
                        next if obj.nil?

                        name = obj.instance_variable_get('@name')
                        nickname = obj.instance_variable_get('@nickname')
                        description = obj.instance_variable_get('@description')
                        note = obj.instance_variable_get('@note')

                        lines.add(name) unless name.nil? || name.empty?
                        lines.add(nickname) unless nickname.nil? || nickname.empty?
                        unless description.nil? || description.empty?
                            lines.add(description.gsub(/\r?\n/,
                                                        '\#'))
                        end
                        unless note.nil? || note.empty?
                            lines.add(note.gsub(/\r?\n/,
                                                '\#'))
                        end
                    end
                elsif basename.start_with?('Common')
                    data.each do |obj|
                        list = obj.instance_variable_get('@pages').instance_variable_get('@list')

                        in_seq = false
                        line = []

                        next unless list.is_a?(Array)

                        list.each do |item|
                            code = item.instance_variable_get('@code')
                            parameters = item.instance_variable_get('@parameters')

                            parameters.each do |parameter|
                                if [401, 405].include?(code)
                                    in_seq = true
                                    line.push(parameter) if parameter.is_a?(String) && !parameter.empty?
                                else
                                    if in_seq
                                        lines.add(line.join('\#'))
                                        line.clear
                                        in_seq = false
                                    end

                                    case code
                                    when 102
                                        if parameter.is_a?(Array)
                                            parameter.each do |param|
                                                lines.add(param) if param.is_a?(String) && !parameter.empty?
                                            end
                                        end
                                    when 356
                                        lines.add(parameter) if parameter.is_a?(String) && !parameter.empty?
                                    end
                                end
                            end
                        end
                    end
                else
                    p data
                end
            elsif basename.start_with?(/Map[0-9].+/)
                events = data.instance_variable_get('@events')

                events.each_value do |event|
                    pages = event.instance_variable_get('@pages')
                    next unless pages.is_a?(Array)

                    pages.each do |page|
                        in_seq = false
                        line = []

                        list = page.instance_variable_get('@list')

                        list.each do |item|
                            code = item.instance_variable_get('@code')
                            parameters = item.instance_variable_get('@parameters')

                            parameters.each do |parameter|
                                if [401, 405].include?(code)
                                    in_seq = true

                                    line.push(parameter) if parameter.is_a?(String) && !parameter.empty?
                                else
                                    if in_seq
                                        lines.add(line.join('\#'))
                                        line.clear
                                        in_seq = false
                                    end

                                    case code
                                    when 102
                                        if parameter.is_a?(Array)
                                            parameter.each do |param|
                                                lines.add(param) if param.is_a?(String) && !parameter.empty?
                                            end
                                        end
                                    when 356
                                        lines.add(parameter) if parameter.is_a?(String) && !parameter.empty?
                                    end
                                end
                            end
                        end
                    end
                end
            elsif basename.start_with?('System')
                elements = data.instance_variable_get('@elements')
                skill_types = data.instance_variable_get('@skill_types')
                weapon_types = data.instance_variable_get('@weapon_types')
                armor_types = data.instance_variable_get('@armor_types')
                currency_unit = data.instance_variable_get('@currency_unit')
                terms = data.instance_variable_get('@terms') || data.instance_variable_get('@words')
                game_title = data.instance_variable_get('@game_title')

                [elements, skill_types, weapon_types, armor_types].each do |arr|
                    next if arr.nil?

                    arr.each { |string| lines.add(string) if string.is_a?(String) && !string.empty? }
                end

                lines.add(currency_unit) if currency_unit.is_a?(String) && !currency_unit.empty?

                terms.instance_variables.each do |var|
                    value = terms.instance_variable_get(var)
                    value.each { |string| lines.add(string) if string.is_a?(String) && !string.empty? }
                end

                lines.add(game_title) if game_title.is_a?(String) && !game_title.empty?
            end

            f.write(lines.join("\n"))
        end
    end

    def self.dump_save(file, data, _options)
        File.open(file, 'wb') do |f|
            data.each { |chunk| Marshal.dump(chunk, f) }
        end
    end

    def self.dump_raw_file(file, data, _options)
        File.open(file, 'wb') { |f| f.write(data) }
    end

    def self.dump(dumper, file, data, options)
        method(dumper).call(file, data, options)
    rescue StandardError
        warn "Exception dumping #{file}"
        raise
    end

    def self.load_data_file(file)
        File.open(file, 'rb') { |f| return Marshal.load(f) }
    end

    def self.load_txt_file(file)
        formatador = Formatador.new
        obj = nil
        File.open(file, 'rb') { |f| obj = Psych.load(f) }
        max = 0
        return obj unless obj.is_a?(Array)

        seen = {}
        obj.each do |elem|
            next if elem.nil?

            if elem.instance_variable_defined?('@id')
                id = elem.instance_variable_get('@id')
            else
                id = nil
                elem.instance_variable_set('@id', nil)
            end
            next if id.nil?

            if seen.key?(id)
                formatador.display_line(
                    "[red]#{file}: Duplicate ID #{id}[/]"
                )
                formatador.indent do
                    formatador.indent do
                        elem
                            .pretty_inspect
                            .split(/\n/)
                            .each do |line|
                                formatador.display_line("[red]#{line}[/]")
                            end
                    end
                    formatador.display_line
                    formatador.display_line("[red]Last seen at:\n[/]")
                    formatador.indent do
                        elem
                            .pretty_inspect
                            .split(/\n/)
                            .each do |line|
                                formatador.display_line("[red]#{line}[/]")
                            end
                    end
                end
                exit
            end
            seen[id] = elem
            max = ((id + 1) unless id < max)
        end

        obj.each do |elem|
            next if elem.nil?

            id = elem.instance_variable_get('@id')
            if id.nil?
                elem.instance_variable_set('@id', max)
                max += 1
            end
        end
        obj
    end

    def self.load_raw_file(file)
        File.open(file, 'rb') { |f| return f.read }
    end

    def self.load_save(file)
        File.open(file, 'rb') do |f|
            data = []

            until f.eof?
                o = Marshal.load(f)
                data.push(o)
            end

            return data
        end
    end

    def self.load(loader, file)
        method(loader).call(file)
    rescue StandardError
        warn "Exception loading #{file}"
        raise
    end

    def self.scripts_to_text(dirs, src, dest, options)
        formatador = Formatador.new
        src_file = File.join(dirs[:data], src)
        dest_file = File.join(dirs[:txt], dest)
        raise "Missing #{src}" unless File.exist?(src_file)

        script_entries = load(:load_data_file, src_file)
        check_time = !options[:force] && File.exist?(dest_file)
        oldest_time = File.mtime(dest_file) if check_time

        file_map = Hash.new(-1)
        script_index = []
        script_code = {}

        idx = 0
        script_entries.each do |script|
            idx += 1
            magic_number = idx
            script_name = script[1]
            code = inflate(script[2])
            script_name.force_encoding('UTF-8')

            if !code.empty?
                filename =
                    if script_name.empty?
                        'blank'
                    else
                        sanitize_filename(script_name)
                    end
                key = filename.upcase
                value = (file_map[key] += 1)
                actual_filename =
                    "#{filename}#{value.zero? ? '' : ".#{value}"}.rb"
                script_index.push([magic_number, script_name, actual_filename])
                full_filename = File.join(dirs[:script], actual_filename)
                script_code[full_filename] = code
                check_time = false unless File.exist?(full_filename)
                if check_time
                    oldest_time = [
                        File.mtime(full_filename),
                        oldest_time
                    ].min
                end
            else
                script_index.push([magic_number, script_name, nil])
            end
        end

        formatador.display_line('[green]Converting scripts to text[/]') if $VERBOSE
        dump_txt_file(dest_file, script_index, options)

        script_code.each do |file, code|
            dump_raw_file(file, code, options)
        end
    end

    def self.scripts_to_binary(dirs, src, dest, options)
        formatador = Formatador.new
        src_file = File.join(dirs[:txt], src)
        dest_file = File.join(dirs[:data], dest)
        raise "Missing #{src}" unless File.exist?(src_file)

        check_time = !options[:force] && File.exist?(dest_file)
        newest_time = File.mtime(src_file) if check_time

        index = load(:load_txt_file, src_file)
        script_entries = []
        index.each do |entry|
            magic_number, script_name, filename = entry
            code = ''
            if filename
                full_filename = File.join(dirs[:script], filename)
                raise "Missing script file #{filename}" unless File.exist?(full_filename)

                if check_time
                    newest_time = [
                        File.mtime(full_filename),
                        newest_time
                    ].max
                end
                code = load(:load_raw_file, full_filename)
            end
            script_entries.push([magic_number, script_name, deflate(code)])
        end
        if check_time && (newest_time - 1) < File.mtime(dest_file)
            formatador.display_line('[yellow]Skipping scripts to binary[/]') if $VERBOSE
        else
            if $VERBOSE
                formatador.display_line(
                    '[green]Converting scripts to binary[/]'
                )
            end
            dump_data_file(
                dest_file,
                script_entries,
                newest_time,
                options
            )
        end
    end

    def self.process_file(
        file,
        src_file,
        dest_file,
        dest_ext,
        loader,
        dumper,
        options
    )
        formatador = Formatador.new
        fbase = File.basename(file, '.*')

        if !options[:database].nil? &&
            (options[:database].downcase != fbase.downcase)
            return
        end

        if $VERBOSE
            formatador.display_line(
                "[green]Converting #{file} to #{dest_ext}[/]"
            )
        end

        data = load(loader, src_file)
        dump(dumper, dest_file, data, options)
    end

    def self.convert(src, dest, options)
        files = files_with_extension(src[:directory], src[:ext])
        files -= src[:exclude]

        files.each do |file|
            src_file = File.join(src[:directory], file)
            dest_file =
                File.join(dest[:directory], File.basename(file, '.*') + dest[:ext])

            process_file(
                file,
                src_file,
                dest_file,
                dest[:ext],
                src[:load_file],
                dest[:dump_file],
                options
            )
        end
    end

    def self.convert_saves(base, src, dest, options)
        save_files = files_with_extension(base, src[:ext])
        save_files.each do |file|
            src_file = File.join(base, file)
            dest_file = File.join(base, File.basename(file, '.*') + dest[:ext])

            process_file(
                file,
                src_file,
                dest_file,
                dest[:ext],
                src[:load_save],
                dest[:dump_save],
                options
            )
        end
    end

    # [version] one of :ace, :vx, :xp
    # [direction] one of :data_bin_to_text, :data_text_to_bin, :save_bin_to_text,
    #             :save_text_to_bin, :scripts_bin_to_text, :scripts_text_to_bin,
    #             :all_text_to_bin, :all_bin_to_text
    # [directory] directory that project file is in
    # [options] :force - ignores file dates when converting (default false)
    #           :round_trip - create yaml data that matches original marshalled data skips
    #                         data cleanup operations (default false)
    #           :line_width - line width form YAML files, -1 for no line width limit
    #                         (default 130)
    #           :table_width - maximum number of entries per row for table data, -1 for no
    #                          table row limit (default 20)
    def self.serialize(version, direction, directory, options = {})
        setup_classes(version, options)
        options = options.clone
        options[:sort] = true if %i[vx xp].include?(version)
        options[:flow_classes] = [Color, Tone, RPG::BGM, RPG::BGS, RPG::MoveCommand, RPG::SE].freeze
        options[:line_width] ||= 130

        table_width = options[:table_width]
        RGSS.reset_const(Table, :MAX_ROW_LENGTH, table_width || 20)

        base = File.realpath(directory)

        dirs = {
            base: base,
            data: File.join(base, 'Data'),
            txt: File.join(base, 'txt'),
            script: File.join(base, 'Scripts')
        }

        dirs.each_value { |obj| FileUtils.mkdir(obj) unless File.exist?(obj) }

        exts = { ace: '.rvdata2', vx: '.rvdata', xp: '.rxdata' }

        txt_scripts = 'Scripts.txt'
        txt = {
            directory: dirs[:txt],
            exclude: [txt_scripts],
            ext: '.txt',
            load_file: :load_txt_file,
            dump_file: :dump_txt_file,
            load_save: :load_txt_file,
            dump_save: :dump_txt_file
        }

        scripts = "Scripts#{exts[version]}"
        data = {
            directory: dirs[:data],
            exclude: [scripts],
            ext: exts[version],
            load_file: :load_data_file,
            dump_file: :dump_data_file,
            load_save: :load_save,
            dump_save: :dump_save
        }

        convert_scripts = if options[:database].nil? || (options[:database].downcase == 'scripts')
                              true
                          else
                              false
                          end
        convert_saves = if options[:database].nil? || (options[:database].downcase == 'saves')
                            true
                        else
                            false
                        end

        case direction
        when :data_bin_to_text
            convert(data, txt, options)
            scripts_to_text(dirs, scripts, txt_scripts, options) if convert_scripts
        when :data_text_to_bin
            convert(txt, data, options)
            scripts_to_binary(dirs, txt_scripts, scripts, options) if convert_scripts
        when :save_bin_to_text
            convert_saves(base, data, txt, options) if convert_saves
        when :save_text_to_bin
            convert_saves(base, txt, data, options) if convert_saves
        when :scripts_bin_to_text
            scripts_to_text(dirs, scripts, txt_scripts, options) if convert_scripts
        when :scripts_text_to_bin
            scripts_to_binary(dirs, txt_scripts, scripts, options) if convert_scripts
        when :all_bin_to_text
            convert(data, txt, options)
            scripts_to_text(dirs, scripts, txt_scripts, options) if convert_scripts
            convert_saves(base, data, txt, options) if convert_saves
        when :all_text_to_bin
            convert(txt, data, options)
            scripts_to_binary(dirs, txt_scripts, scripts, options) if convert_scripts
            convert_saves(base, txt, data, options) if convert_saves
        else
            raise "Unrecognized direction :#{direction}"
        end
    end
end
