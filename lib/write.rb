# frozen_string_literal: true

require 'zlib'

def self.extract_quoted_strings(string)
    # Hash of string-index key-value pairs
    result = {}

    skip_block = false
    in_quotes = false
    quote_type = nil
    buffer = []

    current_string_index = 0
    string.each_line do |line|
        stripped = line.strip

        if stripped[0] == '#' || stripped.start_with?(/(Win|Lose)|_Fanfare/)
            next
        end

        skip_block = true if stripped.start_with?('=begin')
        skip_block = false if stripped.start_with?('=end')

        next if skip_block

        buffer.push('\#') if in_quotes

        line.each_char.each_with_index do |char, index|
            if %w[' "].include?(char)
                unless quote_type.nil? || char == quote_type
                    buffer.push(char)
                    next
                end

                quote_type = char
                in_quotes = !in_quotes
                result[buffer.join] = current_string_index + index
                buffer.clear
                next
            end

            if in_quotes
                buffer.push(char)
            end
        end

        current_string_index += line.length
    end

    result
end

def shuffle_words_in_array(array)
    array.map do |string|
        string.split.shuffle.join(' ')
    end
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

def self.get_parameter_translated(code, parameter, hashmap, game_type)
    lisa_start = nil

    case code
        when 401, 356, 405
            case game_type
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

    case game_type
        when 'lisa'
            gotten = lisa_start + gotten unless lisa_start.nil?
        else
            nil
    end

    gotten
end

def self.get_variable_translated(variable, hashmap, _game_type)
    hashmap[variable]
end

def self.write_map(original_files, maps_path, output_path, shuffle_level, logging, game_type)
    maps_object_map = Hash[original_files.map do |filename|
        [File.basename(filename), merge_map(Marshal.load(File.binread(filename)))]
    end]

    maps_original_text = (File.readlines("#{maps_path}/maps.txt", encoding: 'UTF-8', chomp: true).map do |line|
        line.gsub('\#', "\n")
    end).freeze

    names_original_text = (File.readlines("#{maps_path}/names.txt", encoding: 'UTF-8', chomp: true).map do |line|
        line.gsub('\#', "\n")
    end).freeze

    maps_translated_text = File.readlines("#{maps_path}/maps_trans.txt", encoding: 'UTF-8', chomp: true).map do |line|
        line.gsub('\#', "\n")
    end

    names_translated_text = File.readlines("#{maps_path}/names_trans.txt", encoding: 'UTF-8', chomp: true).map do |line|
        line.gsub('\#', "\n")
    end

    if shuffle_level.positive?
        maps_translated_text.shuffle!
        names_translated_text.shuffle!

        if shuffle_level == 2
            maps_translated_text = shuffle_words(maps_translated_text)
            names_translated_text = shuffle_words(names_translated_text)
        end
    end

    maps_translation_map = Hash[maps_original_text.zip(maps_translated_text)].freeze
    names_translation_map = Hash[names_original_text.zip(names_translated_text)].freeze

    allowed_codes = [401, 402, 356, 102].freeze

    maps_object_map.each do |filename, object|
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
                                translated = get_parameter_translated(code, parameter, maps_translation_map, game_type)
                                parameters[i] = translated unless translated.nil?
                            end
                        elsif parameter.is_a?(Array)
                            parameter.each_with_index do |subparameter, j|
                                if subparameter.is_a?(String) && !subparameter.empty?
                                    translated = get_parameter_translated(code, subparameter, maps_translation_map, game_type)
                                    parameters[i][j] = translated unless translated.nil?
                                end
                            end
                        end
                    end

                    item.instance_variable_set(:@parameters, parameters)
                end
            end
        end

        puts "Written #{filename}" if logging

        File.binwrite(File.join(output_path, filename), Marshal.dump(object))
    end
end

def self.write_other(original_files, other_path, output_path, shuffle_level, logging, game_type)
    other_object_array_map = Hash[original_files.map do |filename|
        basename = File.basename(filename)
        object = Marshal.load(File.binread(filename))
        object = merge_other(object).slice(1..) if basename.start_with?(/Common|Troops/)

        [basename, object]
    end]

    allowed_codes = [401, 402, 405, 356, 102].freeze

    other_object_array_map.each do |filename, other_object_array|
        other_filename = File.basename(filename, '.*').downcase

        other_original_text = File.readlines("#{File.join(other_path, other_filename)}.txt", encoding: 'UTF-8', chomp: true)
                                  .map { |line| line.gsub('\#', "\n") }

        other_translated_text = File.readlines("#{File.join(other_path, other_filename)}_trans.txt", encoding: 'UTF-8', chomp: true)
                                    .map { |line| line.gsub('\#', "\n") }

        if shuffle_level.positive?
            other_translated_text.shuffle!
            other_translated_text = shuffle_words(other_translated_text) if shuffle_level == 2
        end

        other_translation_map = Hash[other_original_text.zip(other_translated_text)].freeze

        if !filename.start_with?(/Common|Troops/)
            other_object_array.each do |object|
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
                        translated = get_variable_translated(variable, other_translation_map, game_type)
                        object.instance_variable_set(symbol, variable) unless translated.nil?
                    end
                end
            end
        else
            other_object_array.each do |object|
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
                                    translated = get_parameter_translated(code, parameter, other_translation_map, game_type)
                                    parameters[i] = translated unless translated.nil?
                                end
                            elsif parameter.is_a?(Array)
                                parameter.each_with_index do |subparameter, j|
                                    if subparameter.is_a?(String) && !subparameter.empty?
                                        translated = get_parameter_translated(code, subparameter, other_translation_map, game_type)
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

        puts "Written #{filename}" if logging

        File.binwrite(File.join(output_path, filename), Marshal.dump(other_object_array))
    end
end

def self.write_system(system_file_path, ini_file_path, other_path, output_path, shuffle_level, logging)
    def self.write_ini_title(ini_file_path, translated)
        file_lines = File.readlines(ini_file_path, chomp: true)
        title_line_index = file_lines.each_with_index do |line, i|
            break i if line.start_with?('title')
        end

        file_lines[title_line_index] = translated
        File.binwrite(ini_file_path, file_lines.join)
    end

    system_basename = File.basename(system_file_path)
    system_object = Marshal.load(File.binread(system_file_path))

    system_original_text = File.readlines("#{other_path}/system.txt", encoding: 'UTF-8', chomp: true)
                               .freeze

    system_translated_text = File.readlines("#{other_path}/system_trans.txt", encoding: 'UTF-8', chomp: true)

    if shuffle_level.positive?
        system_translated_text.shuffle!
        system_translated_text = shuffle_words(system_translated_text) if shuffle_level == 2
    end

    system_translation_map = Hash[system_original_text.zip(system_translated_text)].freeze

    system_symbols = %i[@elements @skill_types @weapon_types @armor_types @currency_unit @terms @words @game_title].freeze

    elements = system_object.instance_variable_get(system_symbols[0])
    skill_types = system_object.instance_variable_get(system_symbols[1])
    weapon_types = system_object.instance_variable_get(system_symbols[2])
    armor_types = system_object.instance_variable_get(system_symbols[3])
    currency_unit = system_object.instance_variable_get(system_symbols[4])
    terms = system_object.instance_variable_get(system_symbols[5]) || system_object.instance_variable_get(system_symbols[6])

    [elements, skill_types, weapon_types, armor_types].each_with_index.each do |array, i|
        next unless array.is_a?(Array)

        array.map! { |string| system_translation_map[string] || string }
        system_object.instance_variable_set(system_symbols[i], array)
    end

    currency_unit_translated = system_translation_map[currency_unit]
    system_object.instance_variable_set(system_symbols[4], currency_unit_translated) if currency_unit.is_a?(String) &&
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

    system_object.instance_variable_defined?(system_symbols[5]) ?
        system_object.instance_variable_set(system_symbols[5], terms) :
        system_object.instance_variable_set(system_symbols[6], terms)

    game_title_translated = system_translated_text[-1]
    system_object.instance_variable_set(system_symbols[7], game_title_translated) if currency_unit.is_a?(String) && !game_title_translated.nil?

    write_ini_title(ini_file_path, game_title_translated)

    puts "Written #{system_basename}" if logging

    File.binwrite("#{output_path}/#{system_basename}", Marshal.dump(system_object))
end

def self.write_scripts(scripts_file_path, other_path, output_path, logging)
    scripts_basename = File.basename(scripts_file_path)
    script_entries = Marshal.load(File.binread(scripts_file_path))

    scripts_translated_text = File.readlines("#{other_path}/scripts_trans.txt", encoding: 'UTF-8', chomp: true)
                                  .map { |line| line.gsub('\#', "\r\n") }

    # Shuffle can possibly break the game in scripts, so no shuffling

    script_entries.each do |script|
        code = Zlib::Inflate.inflate(script[2]).force_encoding('UTF-8')

        (extract_quoted_strings(code)).each_with_index do |string_data, i|
            string, string_index = string_data

            string.strip!

            # Removes the U+3000 Japanese typographical space to check if string, when stripped, is truly empty
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

            code[string_index, string.length] = scripts_translated_text[i]
        end

        script[2] = Zlib::Deflate.deflate(code, Zlib::BEST_COMPRESSION)
    end

    puts "Written #{scripts_basename}" if logging

    File.binwrite("#{output_path}/#{scripts_basename}", Marshal.dump(script_entries))
end
