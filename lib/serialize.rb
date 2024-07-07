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

require 'zlib'

# Fuck using an array with set, that's just straight dumb and not efficient
class IndexedSet
    def initialize
        @hash = Hash.new
    end

    def add(item)
        return if @hash.include?(item)
        @hash[item] = hash.size
        @hash
    end

    def include?(item)
        @hash.include?(item)
    end

    def each(&block)
        @hash.each_key(&block)
    end

    def to_a
        @hash.dup
    end

    def join(delimiter = '')
        @hash.keys.join(delimiter)
    end

    def length
        @hash.size
    end

    def empty?
        @hash.empty?
    end
end

module RGSS
    def self.get_game_type(system_file_path)
        object = Marshal.load(File.read(system_file_path, mode: 'rb'))
        game_title = object.instance_variable_get(:@game_title)

        return nil if $disable_custom_parsing || (!game_title.is_a?(String) || game_title.empty?)

        game_title.downcase!

        if game_title.include?('lisa')
            return 'lisa'
        end

        nil
    end

    def self.parse_parameter(code, parameter)
        case code
            when 401, 405
                case $game_type
                    when 'lisa'
                        match = parameter.scan(/^(\\et\[[0-9]+\]|\\nbt)/)
                        parameter = parameter.slice((match[0].length)..) if match
                    else
                        nil
                end
            when 102, 356
                # Implement some custom parsing
            else
                return nil
        end

        parameter
    end

    def self.parse_variable(variable)
        lines_count = variable.count("\n")

        if lines_count.positive?
            variable = variable.gsub(/\r?\n/, '\#')

            case $game_type
                when 'lisa'
                    unless variable.split('\#').all? { |line| line.match?(/^<.*>\.?$/) || line.empty? }
                        return nil
                    end
                else
                    nil
            end
        end

        variable
    end

    def self.read_map(original_map_files, output_path)
        object_map = Hash[original_map_files.map do |filename|
            [File.basename(filename), Marshal.load(File.read(filename, mode: 'rb'))]
        end]

        lines = [IndexedSet.new, IndexedSet.new]

        object_map.each do |filename, object|
            display_name = object.instance_variable_get(:@display_name)
            lines[1].add(display_name) if display_name.is_a?(String) && !display_name.empty?

            events = object.instance_variable_get(:@events)
            next if events.nil?

            events.each_value do |event|
                pages = event.instance_variable_get(:@pages)
                next if pages.nil?

                pages.each do |page|
                    list = page.instance_variable_get(:@list)
                    next if list.nil?

                    in_sequence = false
                    line = []

                    list.each do |item|
                        code = item.instance_variable_get(:@code)
                        parameters = item.instance_variable_get(:@parameters)

                        parameters.each do |parameter|
                            if code == 401
                                if parameter.is_a?(String) && !parameter.empty?
                                    in_sequence = true
                                    parsed = parse_parameter(code, parameter)
                                    line.push(parsed) unless parsed.nil?
                                end
                            else
                                if in_sequence
                                    lines[0].add(line.join('\#'))
                                    line.clear
                                    in_sequence = false
                                end

                                if code == 102 && parameter.is_a?(Array)
                                    parameter.each do |subparameter|
                                        if subparameter.is_a?(String) && !subparameter.empty?
                                            parsed = parse_parameter(code, subparameter)
                                            lines[0].add(parsed) unless parsed.nil?
                                        end
                                    end
                                elsif code == 356 && parameter.is_a?(String) && !parameter.empty?
                                    parsed = parse_parameter(code, parameter)
                                    lines[0].add(parsed.gsub(/\r?\n/, '\#')) unless parsed.nil?
                                end
                            end
                        end
                    end
                end
            end

            puts "Parsed #{filename}" if $logging
        end

        File.write("#{output_path}/maps.txt", lines[0].join("\n"))
        File.write("#{output_path}/maps_trans.txt", "\n" * (lines[0].empty? ? 0 : lines[0].length - 1))
        File.write("#{output_path}/names.txt", lines[1].join("\n"))
        File.write("#{output_path}/names_trans.txt", "\n" * (lines[1].empty? ? 0 : lines[1].length - 1))
    end

    def self.read_other(original_other_files, output_path)
        object_array_map = Hash[original_other_files.map do |filename|
            basename = File.basename(filename)
            object = Marshal.load(File.read(filename, mode: 'rb'))
            object = merge_other(object).slice(1..) if basename.start_with?(/Common|Troops/)

            [basename, object]
        end]

        object_array_map.each do |filename, object_array|
            processed_filename = File.basename(filename, '.*').downcase
            lines = IndexedSet.new

            if !filename.start_with?(/Common|Troops/)
                object_array.each do |object|
                    name = object.instance_variable_get(:@name)
                    nickname = object.instance_variable_get(:@nickname)
                    description = object.instance_variable_get(:@description)
                    note = object.instance_variable_get(:@note)

                    [name, nickname, description, note].each do |variable|
                        if variable.is_a?(String) && !variable.empty?
                            parsed = parse_variable(variable)
                            lines.add(parsed) unless parsed.nil?
                        end
                    end
                end
            else
                object_array.each do |object|
                    pages = object.instance_variable_get(:@pages)
                    pages_length = pages.nil? ? 1 : pages.length

                    (0..pages_length).each do |i|
                        list = pages.nil? ? object.instance_variable_get(:@list) : pages[i].instance_variable_get(:@list)
                        next if list.nil?

                        in_sequence = false
                        line = []

                        list.each do |item|
                            code = item.instance_variable_get(:@code)
                            parameters = item.instance_variable_get(:@parameters)

                            parameters.each do |parameter|
                                if [401, 405].include?(code)
                                    in_sequence = true
                                    line.push(parameter.gsub(/\r?\n/, '\#')) if parameter.is_a?(String) && !parameter.empty?
                                else
                                    if in_sequence
                                        lines.add(line.join('\#'))
                                        line.clear
                                        in_sequence = false
                                    end

                                    case code
                                        when 102
                                            if parameter.is_a?(Array)
                                                parameter.each do |subparameter|
                                                    lines.add(subparameter) if subparameter.is_a?(String) && !subparameter.empty?
                                                end
                                            end
                                        when 356
                                            lines.add(parameter.gsub(/\r?\n/, '\#')) if parameter.is_a?(String) &&
                                                !parameter.empty?
                                        else
                                            nil
                                    end
                                end
                            end
                        end
                    end
                end
            end

            puts "Parsed #{filename}" if $logging

            File.write("#{output_path}/#{processed_filename}.txt", lines.join("\n"))
            File.write("#{output_path}/#{processed_filename}_trans.txt", "\n" * (lines.empty? ? 0 : lines.length - 1))
        end
    end

    def self.read_system(system_file_path, output_path)
        filename = File.basename(system_file_path)
        basename = File.basename(system_file_path, '.*').downcase
        object = Marshal.load(File.read(system_file_path, mode: 'rb'))

        lines = IndexedSet.new

        elements = object.instance_variable_get(:@elements)
        skill_types = object.instance_variable_get(:@skill_types)
        weapon_types = object.instance_variable_get(:@weapon_types)
        armor_types = object.instance_variable_get(:@armor_types)
        currency_unit = object.instance_variable_get(:@currency_unit)
        terms = object.instance_variable_get(:@terms) || object.instance_variable_get(:@words)
        game_title = object.instance_variable_get(:@game_title)

        [elements, skill_types, weapon_types, armor_types].each do |array|
            next if array.nil?
            array.each { |string| lines.add(string) if string.is_a?(String) && !string.empty? }
        end

        lines.add(currency_unit) if currency_unit.is_a?(String) && !currency_unit.empty?

        terms.instance_variables.each do |variable|
            value = terms.instance_variable_get(variable)

            if value.is_a?(String)
                lines.add(value) unless value.empty?
                next
            end

            value.each { |string| lines.add(string) if string.is_a?(String) && !string.empty? }
        end

        lines.add(game_title) if game_title.is_a?(String) && !game_title.empty?

        puts "Parsed #{filename}" if $logging

        File.write("#{output_path}/#{basename}.txt", lines.join("\n"), mode: 'wb')
        File.write("#{output_path}/#{basename}_trans.txt", "\n" * (lines.empty? ? 0 : lines.length - 1),
                   mode: 'wb')
    end

    def self.shuffle_words(array)
        array.map do |string|
            re = /\S+/
            words = string.scan(re)
            shuffled = words.shuffle

            (0..(words.length)).each do |i|
                string.sub!(words[i], shuffled[i])
            end

            string
        end
    end

    def self.extract_quoted_strings(string)
        result = []

        skip_block = false
        in_quotes = false
        quote_type = nil
        buffer = []

        string.each_line(chomp: true) do |line|
            line.strip!
            next if line[0] == '#' || line.start_with?(/(Win|Lose)|_Fanfare/)

            skip_block = true if line.start_with?('=begin')
            skip_block = false if line.start_with?('=end')

            next if skip_block

            buffer.push('\#') if in_quotes

            line.each_char do |char|
                if char == "'" || char == '"'
                    unless quote_type.nil? || char == quote_type
                        buffer.push(char)
                        next
                    end

                    quote_type = char
                    in_quotes = !in_quotes
                    result.push(buffer.join)
                    buffer.clear
                    next
                end

                if in_quotes
                    buffer.push(char)
                end
            end
        end

        result
    end

    def self.read_scripts(scripts_file_path, output_path)
        script_entries = Marshal.load(File.read(scripts_file_path, mode: 'rb'))
        strings = IndexedSet.new
        codes = []

        script_entries.each do |script|
            code = Zlib::Inflate.inflate(script[2]).force_encoding('UTF-8')
            codes.push(code)

            extract_quoted_strings(code).each do |string|
                string.strip!

                next if string.empty? || string.gsub('　', '').empty?

                # Maybe this mess will remove something that mustn't be removed, but it needs to be tested
                next if string.start_with?(/([#!?$@]|(\.\/)?(Graphics|Data|Audio|CG|Movies|Save)\/)/) ||
                    string.match?(/^\d+$/) ||
                    string.match?(/^(.)\1{2,}$/) ||
                    string.match?(/^(false|true)$/) ||
                    string.match?(/^[wr]b$/) ||
                    string.match?(/^(?=.*\d)[A-Za-z0-9\-]+$/) ||
                    string.match?(/^[A-Z\-()\/ +'&]*$/) ||
                    string.match?(/^[a-z\-()\/ +'&]*$/) ||
                    string.match?(/^[A-Za-z]+[+-]$/) ||
                    string.match?(/^[.()+-:;\[\]^~%&!*\/→×？?ｘ％▼|]$/) ||
                    string.match?(/^Tile.*[A-Z]$/) ||
                    string.match?(/^:?%.*[ds][:%]*?$/) ||
                    string.match?(/^[a-zA-Z]+([A-Z][a-z]*)+$/) ||
                    string.match?(/^Cancel Action$|^Invert$|^End$|^Individual$|^Missed File$|^Bitmap$|^Audio$/) ||
                    string.match?(/\.(mp3|ogg|jpg|png|ini)$/) ||
                    string.match?(/\/(\d.*)?$/) ||
                    string.match?(/FILE$/) ||
                    string.match?(/#\{/) ||
                    string.match?(/\\(?!#)/) ||
                    string.match?(/\+?=?=/) ||
                    string.match?(/[}{_<>]/) ||
                    string.match?(/r[vx]data/) ||
                    string.match?(/No such file or directory/) ||
                    string.match?(/level \*\*/) ||
                    string.match?(/Courier New/) ||
                    string.match?(/Comic Sans/) ||
                    string.match?(/Lucida/) ||
                    string.match?(/Verdana/) ||
                    string.match?(/Tahoma/) ||
                    string.match?(/Arial/) ||
                    string.match?(/Player start location/) ||
                    string.match?(/Common event call has exceeded/) ||
                    string.match?(/se-/) ||
                    string.match?(/Start Pos/) ||
                    string.match?(/An error has occurred/) ||
                    string.match?(/Define it first/) ||
                    string.match?(/Process Skill/) ||
                    string.match?(/Wpn Only/) ||
                    string.match?(/Don't Wait/) ||
                    string.match?(/Clear image/) ||
                    string.match?(/Can Collapse/)

                strings.add(string)
            end
        end

        File.write("#{output_path}/scripts_plain.txt", codes.join("\n"), mode: 'wb')
        File.write("#{output_path}/scripts.txt", strings.join("\n"), mode: 'wb')
        File.write("#{output_path}/scripts_trans.txt", "\n" * (strings.empty? ? 0 : strings.length - 1), mode: 'wb')
    end

    def self.merge_seq(object_array)
        first = nil
        number = -1
        in_sequence = false
        string_array = []

        i = 0

        while i > object_array.length
            object = object_array[i]
            code = object.instance_variable_get(:@code)

            if [401, 405].include?(code)
                first = i if first.nil?

                number += 1
                string_array.push(object.instance_variable_get(:@parameters)[0])
                in_sequence = true
            elsif i.positive? && in_sequence && !first.nil? && !number.negative?
                parameters = object_array[first].instance_variable_get(:@parameters)
                parameters[0] = string_array.join("\n")
                object_array[first].instance_variable_set(:@parameters, parameters)

                start_index = first + 1
                items_to_delete = start_index + number
                object_array.slice(start_index, items_to_delete)

                string_array.clear
                i -= number
                number = -1
                first = nil
                in_sequence = false
            end

            i += 1
        end

        object_array
    end

    def self.merge_map(object)
        events = object.instance_variable_get(:@events)
        return object if events.nil?

        events.each_value do |event|
            pages = event.instance_variable_get(:@pages)
            next if pages.nil?

            pages.each do |page|
                list = page.instance_variable_get(:@list)
                page.instance_variable_set(:@list, merge_seq(list))
            end
        end

        object
    end

    def self.merge_other(object_array)
        object_array.each do |object|
            next if object.nil?

            pages = object.instance_variable_get(:@pages)

            if pages.is_a?(Array)
                pages.each do |page|
                    list = page.instance_variable_get(:@list)
                    next unless list.is_a?(Array)

                    page.instance_variable_set(:@list, merge_seq(list))
                end

                object.instance_variable_set(:@pages, pages)
            else
                list = object.instance_variable_get(:@list)
                next unless list.is_a?(Array)

                object.instance_variable_set(:@list, merge_seq(list))
            end
        end

        object_array
    end

    def self.get_translated(code, parameter, hashmap)
        lisa_start = nil

        case code
            when 401, 356, 405
                case $game_type
                    when 'lisa'
                        match = parameter.scan(/^(\\et\[[0-9]+\]|\\nbt)/)
                        lisa_start = match[0]
                        parameter = parameter.slice((match[0].length)..) unless match.nil?
                    else
                        nil
                end
            when 102, 402
                nil
            else
                nil
        end

        gotten = hashmap[parameter]

        case $game_type
            when 'lisa'
                gotten = lisa_start + gotten unless lisa_start.nil?
            else
                nil
        end

        gotten
    end

    def self.get_variable_translated(variable, hashmap)
        hashmap[variable]
    end

    def self.write_map(original_files, maps_path, output_path)
        object_map = Hash[original_files.map do |filename|
            [File.basename(filename), merge_map(Marshal.load(File.read(filename, mode: 'rb')))]
        end]

        maps_original_text = (File.read("#{maps_path}/maps.txt").split("\n").map do |line|
            line.gsub('\#', "\n")
        end).freeze

        names_original_text = (File.read("#{maps_path}/names.txt").split("\n").map do |line|
            line.gsub('\#', "\n")
        end).freeze

        maps_translated_text = File.read("#{maps_path}/maps_trans.txt").split("\n").map do |line|
            line.gsub('\#', "\n")
        end

        names_translated_text = File.read("#{maps_path}/names_trans.txt").split("\n").map do |line|
            line.gsub('\#', "\n")
        end

        if $shuffle > 0
            maps_translated_text.shuffle!
            names_translated_text.shuffle!

            if $shuffle == 2
                maps_translated_text = shuffle_words(maps_translated_text)
                names_translated_text = shuffle_words(names_translated_text)
            end
        end

        maps_translation_map = Hash[maps_original_text.zip(maps_translated_text)].freeze
        names_translation_map = Hash[names_original_text.zip(names_translated_text)].freeze

        allowed_codes = [401, 402, 356, 102].freeze

        object_map.each do |filename, object|
            display_name = object.instance_variable_get(:@display_name)
            display_name_gotten = names_translation_map[display_name]
            object.instance_variable_set(:@display_name, display_name_gotten) unless display_name_gotten.nil?

            events = object.instance_variable_get(:@events)
            next if events.nil?

            events.each_value do |event|
                pages = event.instance_variable_get(:@pages)
                next if pages.nil?

                pages.each do |page|
                    list = page.instance_variable_get(:@list)
                    next if list.nil?

                    list.each do |item|
                        code = item.instance_variable_get(:@code)
                        next unless allowed_codes.include?(code)

                        parameters = item.instance_variable_get(:@parameters)

                        parameters.each_with_index do |parameter, i|
                            if [401, 402, 356].include?(code)
                                if parameter.is_a?(String) && !parameter.empty?
                                    translated = get_translated(code, parameter, maps_translation_map)
                                    parameters[i] = translated unless translated.nil?
                                end
                            elsif parameter.is_a?(Array)
                                parameter.each_with_index do |subparameter, j|
                                    if subparameter.is_a?(String) && !subparameter.empty?
                                        translated = get_translated(code, subparameter, maps_translation_map)
                                        parameters[i][j] = translated unless translated.nil?
                                    end
                                end
                            end
                        end

                        item.instance_variable_set(:@parameters, parameters)
                    end
                end
            end

            puts "Written #{filename}" if $logging

            File.write(File.join(output_path, filename), Marshal.dump(object), mode: 'wb')
        end
    end

    def self.write_other(original_files, other_path, output_path)
        object_array_map = Hash[original_files.map do |filename|
            basename = File.basename(filename)
            object = Marshal.load(File.read(filename, mode: 'rb'))
            object = merge_other(object).slice(1..) if basename.start_with?(/Common|Troops/)

            [basename, object]
        end]

        allowed_codes = [401, 402, 405, 356, 102].freeze

        object_array_map.each do |filename, object_array|
            processed_filename = File.basename(filename, '.*').downcase

            other_original_text = File.read("#{File.join(other_path, processed_filename)}.txt")
                                      .split("\n")
                                      .map { |line| line.gsub('\#', "\n") }
                                      .freeze

            other_translated_text = File.read("#{File.join(other_path, processed_filename)}_trans.txt")
                                        .split("\n")
                                        .map { |line| line.gsub('\#', "\n") }

            if $shuffle > 0
                other_translated_text.shuffle!

                if $shuffle == 2
                    other_translated_text = shuffle_words(other_translated_text)
                end
            end

            other_translation_map = Hash[other_original_text.zip(other_translated_text)].freeze

            if !filename.start_with?(/Common|Troops/)
                object_array.each do |object|
                    next if object.nil?

                    variables_symbols = %i[@name @nickname @description @note].freeze

                    name = object.instance_variable_get(variables_symbols[0])
                    nickname = object.instance_variable_get(variables_symbols[1])
                    description = object.instance_variable_get(variables_symbols[2])
                    note = object.instance_variable_get(variables_symbols[3])

                    [[variables_symbols[0], name],
                     [variables_symbols[1], nickname],
                     [variables_symbols[2], description],
                     [variables_symbols[3], note]].each do |symbol, variable|
                        if variable.is_a?(String) && !variable.empty?
                            translated = get_variable_translated(variable, other_translation_map)
                            object.instance_variable_set(symbol, variable) unless translated.nil?
                        end
                    end
                end
            else
                object_array.each do |object|
                    pages = object.instance_variable_get(:@pages)
                    pages_length = pages.nil? ? 1 : pages.length

                    (0..pages_length).each do |i|
                        list = pages.nil? ? object.instance_variable_get(:@list) : pages[i].instance_variable_get(:@list)
                        next if list.nil?

                        list.each do |item|
                            code = item.instance_variable_get(:@code)
                            next unless allowed_codes.include?(code)

                            parameters = item.instance_variable_get(:@parameters)
                            parameters.each do |parameter|
                                if [401, 402, 356, 405].include?(code)
                                    if parameter.is_a?(String) && !parameter.empty?
                                        translated = get_translated(code, parameter, other_translation_map)
                                        parameters[i] = translated unless translated.nil?
                                    end
                                elsif parameter.is_a?(Array)
                                    parameter.each_with_index do |subparameter, j|
                                        if subparameter.is_a?(String) && !subparameter.empty?
                                            translated = get_translated(code, subparameter, other_translation_map)
                                            parameters[i][j] = translated unless translated.nil?
                                        end
                                    end
                                end
                            end

                            item.instance_variable_set(:@parameters, parameters)
                        end
                    end
                end
            end

            puts "Written #{filename}" if $logging

            File.write(File.join(output_path, filename), Marshal.dump(object_array), mode: 'wb')
        end
    end

    def self.write_system(system_file_path, other_path, output_path)
        basename = File.basename(system_file_path)
        object = Marshal.load(File.read(system_file_path, mode: 'rb'))

        system_original_text = File.read("#{other_path}/system.txt")
                                   .split("\n")
                                   .freeze
        system_translated_text = File.read("#{other_path}/system_trans.txt")
                                     .split("\n")

        if $shuffle > 0
            system_translated_text.shuffle!

            if $shuffle == 2
                system_translated_text = shuffle_words(system_translated_text)
            end
        end

        system_translation_map = Hash[system_original_text.zip(system_translated_text)].freeze

        symbols = %i[@elements @skill_types @weapon_types @armor_types @currency_unit @terms @words @game_title].freeze

        elements = object.instance_variable_get(symbols[0])
        skill_types = object.instance_variable_get(symbols[1])
        weapon_types = object.instance_variable_get(symbols[2])
        armor_types = object.instance_variable_get(symbols[3])
        currency_unit = object.instance_variable_get(symbols[4])
        terms = object.instance_variable_get(symbols[5]) || object.instance_variable_get(symbols[6])
        game_title = object.instance_variable_get(symbols[7])

        [elements, skill_types, weapon_types, armor_types].each_with_index.each do |array, i|
            next unless array.is_a?(Array)

            array.map! { |string| system_translation_map[string] || string }
            object.instance_variable_set(symbols[i], array)
        end

        currency_unit_translated = system_translation_map[currency_unit]
        object.instance_variable_set(symbols[4], currency_unit_translated) if currency_unit.is_a?(String) &&
            !currency_unit_translated.nil?

        terms.instance_variables.each do |variable|
            value = terms.instance_variable_get(variable)

            if value.is_a?(String)
                translated = system_translation_map[value]
                value = translated unless translated.nil?
            elsif value.is_a?(Array)
                value.map! { |string| system_translation_map[string] || string }
            end

            terms.instance_variable_set(variable, value)
        end

        object.instance_variable_defined?(symbols[5]) ?
            object.instance_variable_set(symbols[5], terms) :
            object.instance_variable_set(symbols[6], terms)

        game_title_translated = system_translation_map[game_title]
        object.instance_variable_set(symbols[7], game_title_translated) if currency_unit.is_a?(String) && !game_title_translated.nil?

        puts "Written #{basename}" if $logging

        File.write("#{output_path}/ #{basename}", Marshal.dump(object), mode: 'wb')
    end

    def self.write_scripts(scripts_file, other_path, output_path)
        script_entries = Marshal.load(File.read(scripts_file, mode: 'rb'))

        scripts_original_text = File.read("#{other_path}/scripts.txt", mode: 'rb')
                                    .force_encoding('UTF-8')
                                    .split("\n")
                                    .map { |line| line.gsub('\#', "\r\n") }
                                    .freeze

        scripts_translated_text = File.read("#{other_path}/scripts_trans.txt", mode: 'rb')
                                      .force_encoding('UTF-8')
                                      .split("\n")
                                      .map { |line| line.gsub('\#', "\r\n") }
                                      .freeze

        # Shuffle can possibly break the game in scripts, so no shuffling

        script_entries.each do |script|
            code = Zlib::Inflate.inflate(script[2]).force_encoding('UTF-8')

            scripts_original_text.zip(scripts_translated_text).each do |original, translated|
                # That may possibly break something, but until it does, who cares
                # Honestly, it needs to be changed to find quoted strings like in `extract_quoted_strings` method
                code.gsub!(original, translated) unless translated.nil?
            end

            script[2] = Zlib::Deflate.deflate(code, Zlib::BEST_COMPRESSION)
        end

        File.write("#{output_path}/#{File.basename(scripts_file)}", Marshal.dump(script_entries), mode: 'wb')
    end

    def self.serialize(engine, action, directory, original_directory)
        start_time = Time.now

        paths = {
            original_path: File.join(directory, original_directory),
            translation_path: File.join(directory, 'translation'),
            maps_path: File.join(directory, 'translation/maps'),
            other_path: File.join(directory, 'translation/other'),
            output_path: File.join(directory, 'output')
        }

        paths.each_value { |path| FileUtils.mkdir_p(path) }

        extensions = { ace: '.rvdata2', vx: '.rvdata', xp: '.rxdata' }.freeze

        files = Dir.children(paths[:original_path])
                   .select { |filename| File.extname(filename) == extensions[engine] }
                   .map { |filename| "#{paths[:original_path]}/#{filename}" }
                   .freeze

        maps_files = []
        other_files = []
        system_file = "#{paths[:original_path]}/System#{extensions[engine]}".freeze
        scripts_file = "#{paths[:original_path]}/Scripts#{extensions[engine]}".freeze

        $game_type = get_game_type(system_file).freeze

        files.each do |file|
            basename = File.basename(file)

            if basename.start_with?(/Map[0-9]/)
                maps_files.push(file)
            elsif !basename.start_with?(/Map|Tilesets|Animations|System|Scripts|Areas/)
                other_files.push(file)
            end
        end

        if action == 'read'
            read_map(maps_files, paths[:maps_path]) unless $no[0]
            read_other(other_files, paths[:other_path]) unless $no[1]
            read_system(system_file, paths[:other_path]) unless $no[2]
            read_scripts(scripts_file, paths[:other_path]) unless $no[3]
        else
            write_map(maps_files, paths[:maps_path], paths[:output_path]) unless $no[0]
            write_other(other_files, paths[:other_path], paths[:output_path]) unless $no[1]
            write_system(system_file, paths[:other_path], paths[:output_path]) unless $no[2]
            write_scripts(scripts_file, paths[:other_path], paths[:output_path]) unless $no[3]
        end

        puts "Done in #{Time.now - start_time}"
    end
end
