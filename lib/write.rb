# frozen_string_literal: true

require 'zlib'
require_relative 'extensions'

# @param [Integer] code
# @param [String] parameter
# @param [Hash{String => String}] hashmap Translation hashmap (as everything in Ruby passed by reference, this pass is free!)
# @param [String] game_type
def self.get_parameter_translated(code, parameter, hashmap, game_type)
    # @type [Array<String>]
    remaining_strings = []
    # @type [Array<Boolean>]
    # true - insert at end
    # false - insert at start
    insert_positions = []

    ends_with_if = parameter[/ if\(.*\)$/]

    if ends_with_if
        parameter = parameter.chomp(ends_with_if)
        remaining_strings.push(ends_with_if)
        insert_positions.push(true)
    end

    if game_type
        case game_type
        when 'lisa'
            case code
            when 401, 405
                prefix = parameter[/^(\\et\[[0-9]+\]|\\nbt)/]
                parameter = parameter.sub(prefix, '') if prefix

                remaining_strings.push(prefix)
                insert_positions.push(false)
            else
                nil
            end
            # Implement cases for other games
        else
            nil
        end
    end

    translated = hashmap[parameter]
    return nil if !translated || translated.empty?

    remaining_strings
        .zip(insert_positions)
        .each do |string, position|
            if !position
                translated = string + translated
            else
                translated += string
            end
        end

    translated
end

# @param [String] variable
# @param [Integer] type
# @param [String] filename
# @param [Hash{String => String}] hashmap Translation hashmap (as everything in Ruby passed by reference, this pass is
#                                 free!)
# @param [String] _game_type
# @return [String]
def self.get_variable_translated(variable, type, _filename, hashmap, _game_type)
    variable = variable.gsub(/\r?\n/, "\n")

    case type
    when 0 # name
    when 1 # nickname
    when 2 # description
    when 3 # note
    else
        nil
    end

    hashmap[variable]
end

# @param [Array<String>] original_files_paths Array of paths to original files
# @param [String] maps_path Path to directory containing .txt maps files
# @param [String] output_path Path to output directory
# @param [Integer] shuffle_level Level of shuffle
# @param [Boolean] romanize If files were read with romanize, this option will romanize original game text to compare with parsed
# @param [Boolean] logging Whether to log
# @param [String] game_type Game type for custom parsing
def self.write_map(original_files_paths, maps_path, output_path, shuffle_level, romanize, logging, game_type)
    maps_object_map = Hash[original_files_paths.map { |f| [File.basename(f), Marshal.load(File.binread(f))] }]

    # @type [Array<String>]
    maps_original_text =
        File
            .readlines(File.join(maps_path, 'maps.txt'), encoding: 'UTF-8', chomp: true)
            .map { |line| line.gsub('\#', "\n").strip }
            .freeze

    # @type [Array<String>]
    names_original_text =
        File
            .readlines(File.join(maps_path, 'names.txt'), encoding: 'UTF-8', chomp: true)
            .map { |line| line.gsub('\#', "\n").strip }
            .freeze

    # @type [Array<String>]
    maps_translated_text =
        File
            .readlines(File.join(maps_path, 'maps_trans.txt'), encoding: 'UTF-8', chomp: true)
            .map { |line| line.gsub('\#', "\n").strip }

    # @type [Array<String>]
    names_translated_text =
        File
            .readlines(File.join(maps_path, 'names_trans.txt'), encoding: 'UTF-8', chomp: true)
            .map { |line| line.gsub('\#', "\n").strip }

    if shuffle_level.positive?
        maps_translated_text.shuffle!
        names_translated_text.shuffle!

        if shuffle_level == 2
            maps_translated_text = shuffle_words(maps_translated_text)
            names_translated_text = shuffle_words(names_translated_text)
        end
    end

    # @type [Hash{String => String}]
    maps_translation_map = Hash[maps_original_text.zip(maps_translated_text)].freeze
    # @type [Hash{String => String}]
    names_translation_map = Hash[names_original_text.zip(names_translated_text)].freeze

    # @type [Array<Integer>]
    # 401 - dialogue lines
    # 102 - dialogue choices array
    # 402 - one of the dialogue choices from the array
    # 356 - system lines/special texts (do they even exist before mv?)
    allowed_codes = [102, 320, 324, 356, 401, 402].freeze

    maps_object_map.each do |filename, object|
        # @type [String]
        display_name = object.display_name
        display_name_translated = names_translation_map[display_name]
        object.display_name = display_name_translated if display_name_translated

        events = object.events
        next unless events

        events.each do |ev, event|
            pages = event.pages
            next unless pages

            pages.each_with_index do |page, pg|
                list = page.list
                next unless list

                in_sequence = false
                # @type [Array<String>]
                line = []
                # @type [Array<Integer>]
                item_indices = []

                list.each_with_index do |item, it|
                    # @type [Integer]
                    code = item.code

                    if in_sequence && code != 401
                        unless line.empty?
                            joined = line.join("\n").strip
                            joined = romanize_string(joined) if romanize

                            translated = get_parameter_translated(401, joined, maps_translation_map, game_type)

                            if translated && !translated.empty?
                                split = translated.split('\#')

                                split_length = split.length
                                line_length = line.length

                                item_indices.each_with_index { |index, i| list[index].parameters[0] = i < split_length ? split[i] : '' }

                                if split_length > line_length
                                    list[item_indices.last].parameters[0] = split[line_length - 1..].join("\n")
                                end
                            end

                            line.clear
                        end

                        in_sequence = false
                    end

                    next unless allowed_codes.include?(code)

                    # @type [Array<String>]
                    parameters = item.parameters

                    case code
                    when 401
                        # @type [String]
                        parameter = parameters[0]
                        next unless parameter.is_a?(String)

                        parameter = convert_to_utf8(parameter)

                        in_sequence = true
                        line.push(parameter.gsub('　', ' ').strip)
                        item_indices.push(it)
                    when 102
                        parameters[0].each_with_index do |subparameter, sp|
                            next unless subparameter.is_a?(String)

                            subparameter = subparameter.strip
                            next if subparameter.empty?

                            subparameter = convert_to_utf8(subparameter)
                            subparameter = romanize_string(subparameter.strip) if romanize

                            translated = get_parameter_translated(code, subparameter, maps_translation_map, game_type)
                            parameters[0][sp] = translated if translated && !translated.empty?
                        end
                    when 356
                        # @type [String]
                        parameter = parameters[0]
                        next unless parameter.is_a?(String)

                        parameter = parameter.strip
                        next if parameter.empty?

                        parameter = convert_to_utf8(parameter)
                        parameter = romanize_string(parameter) if romanize

                        translated = get_parameter_translated(code, parameter, maps_translation_map, game_type)
                        parameters[0] = translated if translated && !translated.empty?
                    when 320, 324, 402
                        # @type [String]
                        parameter = parameters[1]
                        next unless parameter.is_a?(String)

                        parameter = parameter.strip
                        next if parameter.empty?

                        parameter = convert_to_utf8(parameter)
                        parameter = romanize_string(parameters[1].strip) if romanize

                        translated = get_parameter_translated(code, parameter, maps_translation_map, game_type)
                        parameters[1] = translated if translated && !translated.empty?
                    end

                    item.parameters = parameters
                    list[it] = item
                end

                page.list = list
                pages[pg] = page
            end

            event.pages = pages
            events[ev] = event
        end

        object.events = events

        File.binwrite(File.join(output_path, filename), Marshal.dump(object))
        puts "Written #{filename}" if logging
    end
end

# @param [Array<String>] original_files
# @param [String] other_path
# @param [String] output_path
# @param [Integer] shuffle_level Level of shuffle
# @param [Boolean] romanize If files were read with romanize, this option will romanize original game text to compare with parsed
# @param [Boolean] logging Whether to log
# @param [String] game_type Game type for custom parsing
def self.write_other(original_files_paths, other_path, output_path, shuffle_level, romanize, logging, game_type)
    other_object_array_map = Hash[original_files_paths.map { |f| [File.basename(f), Marshal.load(File.binread(f))] }]

    # @type [Array<String>]
    # 401 - dialogue lines
    # 405 - credits lines
    # 102 - dialogue choices array
    # 402 - one of the dialogue choices from the array
    # 356 - system lines/special texts (do they even exist before mv?)
    allowed_codes = [102, 320, 324, 356, 401, 402, 405].freeze

    other_object_array_map.each do |filename, other_object_array|
        other_filename = File.basename(filename, '.*').downcase

        # @type [Array<String>]
        other_original_text =
            File
                .readlines(File.join(other_path, "#{other_filename}.txt"), encoding: 'UTF-8', chomp: true)
                .map { |line| line.gsub('\#', "\n").strip }

        # @type [Array<String>]
        other_translated_text =
            File
                .readlines(File.join(other_path, "#{other_filename}_trans.txt"), encoding: 'UTF-8', chomp: true)
                .map { |line| line.gsub('\#', "\n").strip }

        if shuffle_level.positive?
            other_translated_text.shuffle!
            other_translated_text = shuffle_words(other_translated_text) if shuffle_level == 2
        end

        # @type [Hash{String => String}]
        other_translation_map = Hash[other_original_text.zip(other_translated_text)].freeze

        if !filename.start_with?(/Common|Troops/)
            other_object_array.each do |object|
                next unless object

                variables = [
                    object.name,
                    object.is_a?(RPG::Actor) ? object.nickname : nil,
                    object.description,
                    object.note,
                    object.is_a?(RPG::Skill) || object.is_a?(RPG::State) ? object.message1 : nil,
                    object.is_a?(RPG::Skill) || object.is_a?(RPG::State) ? object.message2 : nil,
                    object.is_a?(RPG::State) ? object.message3 : nil,
                    object.is_a?(RPG::State) ? object.message4 : nil,
                ]

                attributes = %i[name nickname description note message1 message2 message3 message4]

                variables.each_with_index do |var, type|
                    next unless var.is_a?(String)

                    var = var.strip
                    next if var.empty?

                    var = convert_to_utf8(var)
                    var = romanize_string(var) if romanize
                    var = var.split("\n").map(&:strip).join("\n")

                    translated = get_variable_translated(var, type, filename, other_translation_map, game_type)

                    object.send("#{attributes[type]}=", translated) if translated && !translated.empty?
                end
            end
        else
            other_object_array.each_with_index do |object, obj|
                next unless object

                pages = object.pages
                pages_length = !pages ? 1 : pages.length

                (0..pages_length).each do |pg|
                    list = !pages ? object.list : pages[pg].instance_variable_get(:@list) # for some reason .list access doesn't work (wtf?)
                    next unless list

                    in_sequence = false
                    # @type [Array<String>]
                    line = []
                    # @type [Array<Integer>]
                    item_indices = []

                    list.each_with_index do |item, it|
                        # @type [Integer]
                        code = item.code

                        if in_sequence && ![401, 405].include?(code)
                            unless line.empty?
                                joined = line.join("\n").strip
                                joined = romanize_string(joined) if romanize

                                translated = get_parameter_translated(401, joined, other_translation_map, game_type)

                                if translated && !translated.empty?
                                    split = translated.split('\#')

                                    split_length = split.length
                                    line_length = line.length

                                    item_indices.each_with_index do |index, i|
                                        list[index].parameters[0] = i < split_length ? split[i] : ''
                                    end

                                    if split_length > line_length
                                        list[item_indices.last].parameters[0] = split[line_length - 1..].join("\n")
                                    end
                                end

                                line.clear
                            end

                            in_sequence = false
                        end

                        next unless allowed_codes.include?(code)

                        # @type [Array<String>]
                        parameters = item.parameters

                        case code
                        when 401, 405
                            # @type [String]
                            parameter = parameters[0]
                            next unless parameter.is_a?(String)

                            parameter = convert_to_utf8(parameter)

                            in_sequence = true
                            line.push(parameter.gsub('　', ' ').strip)
                            item_indices.push(it)
                        when 102
                            parameters[0].each_with_index do |subparameter, sp|
                                next unless subparameter.is_a?(String)

                                subparameter = subparameter.strip
                                next if subparameter.empty?

                                subparameter = convert_to_utf8(subparameter)
                                subparameter = romanize_string(subparameter) if romanize

                                translated = get_parameter_translated(code, subparameter, other_translation_map, game_type)
                                parameters[0][sp] = translated if translated && !translated.empty?
                            end
                        when 356
                            # @type [String]
                            parameter = parameters[0]
                            next unless parameter.is_a?(String)

                            parameter = parameter.strip
                            next if parameter.empty?

                            parameter = convert_to_utf8(parameter)
                            parameter = romanize_string(parameter) if romanize

                            translated = get_parameter_translated(code, parameter, other_translation_map, game_type)
                            parameters[0] = translated if translated && !translated.empty?
                        when 320, 324, 402
                            # @type [String]
                            parameter = parameters[1]
                            next unless parameter.is_a?(String)

                            parameter = parameter.strip
                            next if parameter.empty?

                            parameter = convert_to_utf8(parameter)
                            parameter = romanize_string(parameter) if romanize

                            translated = get_parameter_translated(code, parameter, other_translation_map, game_type)
                            parameters[1] = translated if translated && !translated.empty?
                        end

                        item.parameters = parameters
                        list[it] = item
                    end

                    if !pages
                        object.list = list
                    else
                        pages[pg].instance_variable_set(:@list, list)
                        object.pages = pages
                    end
                end

                other_object_array[obj] = object
            end
        end

        File.binwrite(File.join(output_path, filename), Marshal.dump(other_object_array))
        puts "Written #{filename}" if logging
    end
end

# @param [String] ini_file_path
# @param [String] translated
def self.write_ini_title(ini_file_path, translated)
    file_lines = File.readlines(ini_file_path, chomp: true)
    title_line_index = file_lines.each_with_index { |line, i| break i if line.downcase.start_with?('title') }
    return if title_line_index.is_a?(Array)

    file_lines[title_line_index] = "title =#{translated}"
    File.binwrite(ini_file_path, file_lines.join("\n"))
end

# @param [String] system_file_path
# @param [String] ini_file_path
# @param [String] other_path
# @param [String] output_path
# @param [Integer] shuffle_level Level of shuffle
# @param [Boolean] romanize If files were read with romanize, this option will romanize original game text to compare
#                           with parsed
# @param [Boolean] logging Whether to log
def self.write_system(system_file_path, ini_file_path, other_path, output_path, shuffle_level, romanize, logging)
    system_basename = File.basename(system_file_path)

    # @type [System]
    system_object = Marshal.load(File.binread(system_file_path))

    # @type [Array<String>]
    system_original_text =
        File.readlines(File.join(other_path, 'system.txt'), encoding: 'UTF-8', chomp: true).map(&:strip).freeze

    # @type [Array<String>]
    system_translated_text =
        File.readlines(File.join(other_path, 'system_trans.txt'), encoding: 'UTF-8', chomp: true).map(&:strip)

    if shuffle_level.positive?
        system_translated_text.shuffle!
        system_translated_text = shuffle_words(system_translated_text) if shuffle_level == 2
    end

    # @type [Hash{String => String}]
    system_translation_map = Hash[system_original_text.zip(system_translated_text)].freeze

    elements = system_object.elements
    skill_types = system_object.skill_types
    weapon_types = system_object.weapon_types
    armor_types = system_object.armor_types
    currency_unit = system_object.currency_unit
    terms_vocabulary = system_object.terms || system_object.words

    arrays = [elements, skill_types, weapon_types, armor_types]
    attributes = %i[elements skill_types weapon_types armor_types]

    arrays
        .zip(attributes)
        .each do |array, attr|
            next unless array.is_a?(Array)

            array.each_with_index do |string, i|
                string = string.strip
                next if string.empty?

                string = convert_to_utf8(string)
                string = romanize_string(string) if romanize

                translated = system_translation_map[string]
                array[i] = translated if translated && !translated.empty?
            end

            system_object.send("#{attr}=", array)
        end

    if currency_unit
        currency_unit = romanize_string(currency_unit) if romanize
        currency_unit_translated = system_translation_map[currency_unit]
        system_object.currency_unit = currency_unit_translated if currency_unit.is_a?(String) && currency_unit_translated &&
            !currency_unit_translated.empty?
    end

    terms_vocabulary.instance_variables.each do |variable|
        # @type [String | Array<String>]
        value = terms_vocabulary.instance_variable_get(variable)

        if value.is_a?(String)
            value = value.strip
            next if value.empty?

            value = convert_to_utf8(value)
            value = romanize_string(value) if romanize

            translated = system_translation_map[value]
            value = translated if translated && !translated.empty?
        elsif value.is_a?(Array)
            value.each_with_index do |string, i|
                string = string.strip
                next if string.empty?

                string = convert_to_utf8(string)
                string = romanize_string(string) if romanize

                translated = system_translation_map[string]
                value[i] = translated if translated && !translated.empty?
            end
        end

        terms_vocabulary.instance_variable_set(variable, value)
    end

    if !system_object.terms
        system_object.words = terms_vocabulary
    else
        system_object.terms = terms_vocabulary
    end

    game_title_translated = system_translated_text.last

    if game_title_translated && !game_title_translated.empty?
        system_object.game_title = game_title_translated
        write_ini_title(ini_file_path, game_title_translated)
    end

    File.binwrite(File.join(output_path, system_basename), Marshal.dump(system_object))
    puts "Written #{system_basename}" if logging
end

# @param [String] scripts_file_path Path to Scripts.*data file
# @param [String] other_path Path to translation/other directory containing .txt files
# @param [String] output_path Path to the output directory
# @param [Boolean] romanize If files were read with romanize, this option will romanize original game text to compare
#                  with parsed
# @param [Boolean] logging Whether to log
def self.write_scripts(scripts_file_path, other_path, output_path, romanize, logging)
    scripts_basename = File.basename(scripts_file_path)
    script_entries = Marshal.load(File.binread(scripts_file_path))

    # @type [Array<String>]
    scripts_original_text =
        File
            .readlines(File.join(other_path, 'scripts.txt'), encoding: 'UTF-8', chomp: true)
            .map { |line| line.gsub('\#', "\r\n") }
    # @type [Array<String>]
    scripts_translated_text =
        File
            .readlines(File.join(other_path, 'scripts_trans.txt'), encoding: 'UTF-8', chomp: true)
            .map { |line| line.gsub('\#', "\r\n") }

    # @type [Hash{String => String}]
    scripts_translation_map = Hash[scripts_original_text.zip(scripts_translated_text)]

    script_entries.each do |script|
        # @type [String]
        code = Zlib::Inflate.inflate(script[2])
        code = convert_to_utf8(code)

        string_array, index_array = extract_strings(code, mode: true)

        string_array
            .zip(index_array)
            .reverse_each do |string, index|
                string = string.gsub('　', '').strip
                next if string.empty? || !scripts_translation_map.include?(string)

                string = romanize_string(string) if romanize

                translated = scripts_translation_map[string]
                code[index, string.length] = translated if translated && !translated.empty?
            end

        script[2] = Zlib::Deflate.deflate(code, Zlib::BEST_COMPRESSION)
    end

    File.binwrite(File.join(output_path, scripts_basename), Marshal.dump(script_entries))
    puts "Written #{scripts_basename}" if logging
end
