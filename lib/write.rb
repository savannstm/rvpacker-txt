# frozen_string_literal: true

require 'zlib'

# @param [String] string A parsed scripts code string, containing raw Ruby code
# @return [[Array<String>, Array<Integer>]] Hash of parsed from code strings and their start indices
def self.extract_quoted_strings(string)
    # Hash of string-index key-value pairs
    strings_array = []
    indices_array = []

    skip_block = false
    in_quotes = false
    quote_type = nil
    buffer = []

    current_string_index = 0
    string.each_line do |line|
        stripped = line.strip

        if stripped[0] == '#' || stripped.start_with?(/(Win|Lose)|_Fanfare/)
            current_string_index += line.length
            next
        end

        skip_block = true if stripped.start_with?('=begin')
        skip_block = false if stripped.start_with?('=end')

        if skip_block
            current_string_index += line.length
            next
        end

        buffer.push('\#') if in_quotes

        line.each_char.each_with_index do |char, index|
            if %w[' "].include?(char)
                unless quote_type.nil? || char == quote_type
                    buffer.push(char)
                    next
                end

                quote_type = char
                in_quotes = !in_quotes

                strings_array.push(buffer.join)
                indices_array.push(current_string_index + index)

                buffer.clear
                next
            end

            buffer.push(char) if in_quotes
        end

        current_string_index += line.length
    end

    [strings_array, indices_array]
end

# @param [Array<String>] array
# @return [Array<String>]
def self.shuffle_words(array)
    array.each do |string|
        select_words_re = /\S+/
        words = string.scan(select_words_re).shuffle
        string.gsub(select_words_re) { words.pop || '' }
    end
end

# @param [Integer] code
# @param [String] parameter
# @param [Hash{String => String}] hashmap
# @param [String] game_type
def self.get_parameter_translated(code, parameter, hashmap, game_type)
    unless game_type.nil?
        lisa_start = nil

        case code
            when 401, 405
                case game_type
                    when 'lisa'
                        match = parameter.scan(/^(\\et\[[0-9]+\]|\\nbt)/)

                        unless match.empty?
                            lisa_start = match[0]
                            parameter = parameter.slice((match[0].length)..)
                        end
                    else
                        nil
                end
            when 102, 402
                # Implement some custom parsing
            when 356
                # Implement some custom parsing
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

        return gotten
    end

    hashmap[parameter]
end

# @param [String] variable
# @param [Hash{String => String}] hashmap
# @param [String] _game_type
# @return [String]
def self.get_variable_translated(variable, hashmap, _game_type)
    hashmap[variable]
end

# @param [Array<String>] original_files_paths
# @param [String] maps_path
# @param [String] output_path
# @param [Integer] shuffle_level
# @param [Boolean] logging
# @param [String] game_type
def self.write_map(original_files_paths, maps_path, output_path, shuffle_level, logging, game_type)
    maps_object_map = Hash[original_files_paths.map do |filename|
        [File.basename(filename), Marshal.load(File.binread(filename))]
    end]

    maps_original_text = File.readlines(File.join(maps_path, 'maps.txt'), encoding: 'UTF-8', chomp: true).map do |line|
        line.gsub('\#', "\n").strip
    end.freeze

    names_original_text = File.readlines(File.join(maps_path, 'names.txt'), encoding: 'UTF-8', chomp: true).map do |line|
        line.gsub('\#', "\n").strip
    end.freeze

    maps_translated_text = File.readlines(File.join(maps_path, 'maps.txt'), encoding: 'UTF-8', chomp: true).map do |line|
        line.gsub('\#', "\n").strip
    end

    names_translated_text = File.readlines(File.join(maps_path, 'names_trans.txt'), encoding: 'UTF-8', chomp: true).map do |line|
        line.gsub('\#', "\n").strip
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

    # 401 - dialogue lines
    # 102 - dialogue choices array
    # 402 - one of the dialogue choices from the array
    # 356 - system lines/special texts (do they even exist before mv?)
    allowed_codes = [401, 102, 402, 356].freeze

    maps_object_map.each do |filename, object|
        display_name = object.display_name
        display_name_gotten = names_translation_map[display_name]
        object.display_name = display_name_gotten unless display_name_gotten.nil?

        events = object.events
        next if events.nil?

        events.each_value do |event|
            pages = event.pages
            next if pages.nil?

            pages.each do |page|
                list = page.list
                next if list.nil?

                in_sequence = false
                line = []
                item_indices = []

                list.each_with_index do |item, it|
                    code = item.code

                    unless allowed_codes.include?(code)
                        if in_sequence
                            joined = line.join('\#').strip
                            translated = get_parameter_translated(401, joined, maps_translation_map, game_type)

                            unless translated.nil? || translated.empty?
                                split = translated.split('\#')

                                split_length = split.length
                                line_length = line.length

                                item_indices.each_with_index do |index, i|
                                    list[index].parameters[0] = i < split_length ? split[i] : ''
                                end

                                list[item_indices.last].parameters[0] = split[line_length..].join("\n") if split_length > line_length
                            end
                        end
                        next
                    end

                    parameters = item.parameters

                    if code == 401
                        next unless parameters[0].is_a?(String) && !parameters[0].empty?

                        in_sequence = true
                        line.push(parameters[0])
                        item_indices.push(it)
                    elsif code == 356
                        parameter = parameters[0]
                        next unless parameter.is_a?(String)

                        parameter = parameter.strip
                        next if parameter.empty?

                        translated = get_parameter_translated(code, parameter, maps_translation_map, game_type)
                        parameters[0] = translated unless translated.nil? || translated.empty?
                    elsif code == 402
                        parameter = parameters[1]
                        next unless parameter.is_a?(String)

                        parameter = parameter.strip
                        next if parameter.empty?

                        translated = get_parameter_translated(code, parameter, maps_translation_map, game_type)
                        parameters[1] = translated unless translated.nil? || translated.empty?
                    elsif code == 102 && parameters[0].is_a?(Array)
                        parameters[0].each_with_index do |subparameter, sp|
                            next unless subparameter.is_a?(String)

                            subparameter = subparameter.strip
                            next if subparameter.empty?

                            translated = get_parameter_translated(code, subparameter, maps_translation_map, game_type)
                            parameters[0][sp] = translated unless translated.nil? || translated.empty?
                        end
                    end

                    item.parameters = parameters
                end
            end
        end

        puts "Written #{filename}" if logging

        File.binwrite(File.join(output_path, filename), Marshal.dump(object))
    end
end

# @param [Array<String>] original_files
# @param [String] other_path
# @param [String] output_path
# @param [Integer] shuffle_level
# @param [Boolean] logging
# @param [String] game_type
def self.write_other(original_files_paths, other_path, output_path, shuffle_level, logging, game_type)
    other_object_array_map = Hash[original_files_paths.map do |filename|
        basename = File.basename(filename)
        object = Marshal.load(File.binread(filename))

        [basename, object]
    end]

    # 401 - dialogue lines
    # 405 - credits lines
    # 102 - dialogue choices array
    # 402 - one of the dialogue choices from the array
    # 356 - system lines/special texts (do they even exist before mv?)
    allowed_codes = [401, 405, 102, 402, 356].freeze

    other_object_array_map.each do |filename, other_object_array|
        other_filename = File.basename(filename, '.*').downcase

        other_original_text = File.readlines(File.join(other_path, "#{other_filename}.txt"), encoding: 'UTF-8', chomp: true)
                                  .map { |line| line.gsub('\#', "\n").strip }

        other_translated_text = File.readlines(File.join(other_path, "#{other_filename}_trans.txt"), encoding: 'UTF-8', chomp: true)
                                    .map { |line| line.gsub('\#', "\n").strip }

        if shuffle_level.positive?
            other_translated_text.shuffle!
            other_translated_text = shuffle_words(other_translated_text) if shuffle_level == 2
        end

        other_translation_map = Hash[other_original_text.zip(other_translated_text)].freeze

        if !filename.start_with?(/Common|Troops/)
            other_object_array.each do |object|
                next if object.nil?

                name = object.name
                nickname = object.nickname
                description = object.description
                note = object.note

                [name, nickname, description, note].each_with_index do |variable, i|
                    next unless variable.is_a?(String)

                    variable = variable.strip
                    next if variable.empty?

                    variable = variable.gsub(/\r\n/, "\n")

                    translated = get_variable_translated(variable, other_translation_map, game_type)

                    if i.zero?
                        object.name = translated unless translated.nil? || translated.empty?
                    elsif i == 1
                        object.nickname = translated unless translated.nil? || translated.empty?
                    elsif i == 2
                        object.description = translated unless translated.nil? || translated.empty?
                    else
                        object.note = translated unless translated.nil? || translated.empty?
                    end
                end
            end
        else
            other_object_array.each do |object|
                next if object.nil?

                pages = object.pages
                pages_length = pages.nil? ? 1 : pages.length

                (0..pages_length).each do |pg|
                    list = pages.nil? ? object.list : pages[pg].instance_variable_get(:@list) # for some reason .list access doesn't work (wtf?)
                    next if list.nil?

                    in_sequence = false
                    line = []
                    item_indices = []

                    list.each_with_index do |item, it|
                        code = item.code

                        unless allowed_codes.include?(code)
                            if in_sequence
                                joined = line.join('\#').strip
                                translated = get_parameter_translated(401, joined, other_translation_map, game_type)

                                unless translated.nil? || translated.empty?
                                    split = translated.split('\#')

                                    split_length = split.length
                                    line_length = line.length

                                    item_indices.each_with_index do |index, i|
                                        list[index].parameters[0] = i < split_length ? split[i] : ''
                                    end

                                    list[item_indices.last].parameters[0] = split[line_length..].join("\n") if split_length > line_length
                                end
                            end
                            next
                        end

                        parameters = item.parameters

                        if [401, 405].include?(code)
                            next unless parameters[0].is_a?(String) && !parameters[0].empty?

                            in_sequence = true
                            line.push(parameters[0])
                            item_indices.push(it)
                        elsif code == 356
                            parameter = parameters[0]
                            next unless parameter.is_a?(String)

                            parameter = parameter.strip
                            next if parameter.empty?

                            translated = get_parameter_translated(code, parameter, other_translation_map, game_type)
                            parameters[0] = translated unless translated.nil? || translated.empty?
                        elsif code == 402
                            parameter = parameters[1]
                            next unless parameter.is_a?(String)

                            parameter = parameter.strip
                            next if parameter.empty?

                            translated = get_parameter_translated(code, parameter, other_translation_map, game_type)
                            parameters[1] = translated unless translated.nil? || translated.empty?
                        elsif code == 102 && parameters[0].is_a?(Array)
                            parameters[0].each_with_index do |subparameter, sp|
                                next unless subparameter.is_a?(String)

                                subparameter = subparameter.strip
                                next if subparameter.empty?

                                translated = get_parameter_translated(code, subparameter, other_translation_map, game_type)
                                parameters[0][sp] = translated unless translated.nil? || translated.empty?
                            end
                        end

                        item.parameters = parameters
                    end
                end
            end
        end

        puts "Written #{filename}" if logging

        File.binwrite(File.join(output_path, filename), Marshal.dump(other_object_array))
    end
end

# @param [String] ini_file_path
# @param [String] translated
def self.write_ini_title(ini_file_path, translated)
    file_lines = File.readlines(ini_file_path, chomp: true)
    title_line_index = file_lines.each_with_index do |line, i|
        break i if line.downcase.start_with?('title')
    end

    file_lines[title_line_index] = translated
    File.binwrite(ini_file_path, file_lines.join("\n"))
end

# @param [String] system_file_path
# @param [String] ini_file_path
# @param [String] other_path
# @param [String] output_path
# @param [Integer] shuffle_level
# @param [Boolean] logging
def self.write_system(system_file_path, ini_file_path, other_path, output_path, shuffle_level, logging)
    system_basename = File.basename(system_file_path)
    system_object = Marshal.load(File.binread(system_file_path))

    system_original_text = File.readlines(File.join(other_path, 'system.txt'), encoding: 'UTF-8', chomp: true)
                               .map(&:strip)
                               .freeze

    system_translated_text = File.readlines(File.join(other_path, 'system_trans.txt'), encoding: 'UTF-8', chomp: true)
                                 .map(&:strip)

    if shuffle_level.positive?
        system_translated_text.shuffle!
        system_translated_text = shuffle_words(system_translated_text) if shuffle_level == 2
    end

    system_translation_map = Hash[system_original_text.zip(system_translated_text)].freeze

    elements = system_object.elements
    skill_types = system_object.skill_types
    weapon_types = system_object.weapon_types
    armor_types = system_object.armor_types
    currency_unit = system_object.currency_unit
    terms = system_object.terms || system_object.words

    [elements, skill_types, weapon_types, armor_types].each_with_index.each do |array, i|
        next unless array.is_a?(Array)

        array.map! do |string|
            stripped = string.strip
            return string if stripped.empty?

            translated = system_translation_map[stripped]
            !translated.nil? && !translated.empty? ? translated : stripped
        end

        if i.zero?
            system_object.elements = array
        elsif i == 1
            system_object.skill_types = array
        elsif i == 2
            system_object.weapon_types = array
        else
            system_object.armor_types = array
        end
    end

    currency_unit_translated = system_translation_map[currency_unit]
    system_object.currency_unit = currency_unit_translated if currency_unit.is_a?(String) &&
        (!currency_unit_translated.nil? && !currency_unit_translated.empty?)

    terms.instance_variables.each do |variable|
        value = terms.instance_variable_get(variable)

        if value.is_a?(String)
            stripped = value.strip
            next if value.empty?

            translated = system_translation_map[stripped]
            value = !translated.nil? && !translated.empty? ? translated : value
        elsif value.is_a?(Array)
            value.map! do |string|
                stripped = string.strip
                return string if stripped.empty?

                translated = system_translation_map[stripped]
                value = !translated.nil? && !translated.empty? ? translated : value
            end
        end

        terms.instance_variable_set(variable, value)
    end

    system_object.terms.nil? ?
        system_object.words = terms :
        system_object.terms = terms

    game_title_translated = system_translated_text[-1]
    system_object.game_title = game_title_translated
    write_ini_title(ini_file_path, game_title_translated)

    puts "Written #{system_basename}" if logging

    File.binwrite(File.join(output_path, system_basename), Marshal.dump(system_object))
end

# @param [String] scripts_file_path Path to Scripts.*data file
# @param [String] other_path Path to translation/other directory containing .txt files
# @param [String] output_path Path to the output directory
# @param [Boolean] logging Whether to log
def self.write_scripts(scripts_file_path, other_path, output_path, logging)
    scripts_basename = File.basename(scripts_file_path)
    script_entries = Marshal.load(File.binread(scripts_file_path))

    scripts_original_text = File.readlines(File.join(other_path, 'scripts.txt'), encoding: 'UTF-8', chomp: true)
                                .map { |line| line.gsub('\#', "\r\n") }
    scripts_translated_text = File.readlines(File.join(other_path, 'scripts_trans.txt'), encoding: 'UTF-8', chomp: true)
                                  .map { |line| line.gsub('\#', "\r\n") }

    scripts_translation_map = Hash[scripts_original_text.zip(scripts_translated_text)]

    # Shuffle can possibly break the game in scripts, so no shuffling
    codes = []

    # This code was fun before `that` game used Windows-1252 degree symbol
    script_entries.each do |script|
        code = Zlib::Inflate.inflate(script[2]).force_encoding('UTF-8')

        unless code.valid_encoding?
            # who the fuck uses the degree symbol from FUCKING WINDOWS-1252 and NOT UTF-8
            # also, String#encode does NOT FUCKING WORK and for some reason raises on the
            # fucking degree symbol from windows-1252 when trying to encode
            code.force_encoding('Windows-1252')
        end

        # this shit finally works and requires NO further changes
        string_array, index_array = extract_quoted_strings(code)

        string_array.zip(index_array).reverse_each do |string, index|
            string = string.strip.delete('　')
            next if string.empty? || !scripts_translation_map.include?(string)

            gotten = scripts_translation_map[string]
            code[index - string.length, string.length] = gotten unless gotten.nil? || gotten.empty?
        end

        codes.push(code)
        script[2] = Zlib::Deflate.deflate(code, Zlib::BEST_COMPRESSION)
    end

    puts "Written #{scripts_basename}" if logging

    # File.binwrite(File.join(output_path, 'scripts_plain.txt'), codes.join("\n")) - debug line
    File.binwrite(File.join(output_path, scripts_basename), Marshal.dump(script_entries))
end
