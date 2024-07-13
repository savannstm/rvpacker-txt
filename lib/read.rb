# frozen_string_literal: true

require 'zlib'

def self.insert_at_index(hash, index, key, value)
    return hash[key] = value if index >= hash.size

    temp_hash = hash.to_a
    temp_hash.insert(index, [key, value])
    hash.clear
    hash.merge!(temp_hash.to_h)
end

def self.extract_quoted_strings(string)
    # Hash of string-index key-value pairs
    result = {}

    skip_block = false
    in_quotes = false
    quote_type = nil
    buffer = []

    # I hope this calculates index correctly
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

def self.parse_parameter(code, parameter, game_type)
    case code
        when 401, 405
            case game_type
                when 'lisa'
                    match = parameter.scan(/^(\\et\[[0-9]+\]|\\nbt)/)
                    parameter = parameter.slice((match[0].length)..) if match
                else
                    nil
            end
        when 102
            # Implement some custom parsing
        when 356
            # Implement some custom parsing
        else
            return nil
    end

    parameter
end

def self.parse_variable(variable, game_type)
    lines_count = variable.count("\n")

    if lines_count.positive?
        variable = variable.gsub(/\r?\n/, '\#')

        case game_type
            when 'lisa'
                return nil unless variable.split('\#').all? { |line| line.match?(/^<.*>\.?$/) || line.empty? }
            else
                nil
        end
    end

    variable
end

def self.read_map(maps_files, output_path, logging, game_type, processing_type)
    maps_output_path = File.join(output_path, 'maps.txt')
    names_output_path = File.join(output_path, 'names.txt')
    maps_trans_output_path = File.join(output_path, 'maps_trans.txt')
    names_trans_output_path = File.join(output_path, 'names_trans.txt')

    if processing_type == 'default' && (File.exist?(maps_trans_output_path) || File.exist?(names_trans_output_path))
        puts 'maps_trans.txt or names_trans.txt file already exists. If you want to forcefully re-read all files, use --force flag, or --append if you want append new text to already existing files.'
        return
    end

    maps_object_map = Hash[maps_files.map do |filename|
        [File.basename(filename), Marshal.load(File.binread(filename))]
    end]

    maps_lines = IndexSet.new
    names_lines = IndexSet.new

    maps_translation_map = nil
    names_translation_map = nil

    if processing_type == 'append'
        if File.exist?(maps_trans_output_path)
            maps_translation_map = Hash[File.readlines(maps_output_path, chomp: true).zip(File.readlines(maps_trans_output_path, chomp: true))]
            names_translation_map = Hash[File.readlines(names_output_path, chomp: true).zip(File.readlines(names_trans_output_path, chomp: true))]
        else
            puts "Files aren't already parsed. Continuing as if --append flag was omitted."
            processing_type = 'default'
        end
    end

    maps_object_map.each do |filename, object|
        display_name = object.instance_variable_get(:@display_name)

        if display_name.is_a?(String) && !display_name.empty?
            if processing_type == 'append' && !names_translation_map.include?(display_name)
                insert_at_index(names_translation_map, names_lines.length, display_name, '')
            end

            names_lines.add(display_name)
        end

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

                                parsed = parse_parameter(code, parameter, game_type)
                                line.push(parsed) unless parsed.nil?
                            end
                        else
                            if in_sequence
                                joined = line.join('\#')

                                if processing_type == 'append' && !maps_translation_map.include?(joined)
                                    insert_at_index(maps_translation_map, maps_lines.length, joined, '')
                                end

                                maps_lines.add(joined)

                                line.clear
                                in_sequence = false
                            end

                            if code == 102 && parameter.is_a?(Array)
                                parameter.each do |subparameter|
                                    if subparameter.is_a?(String) && !subparameter.empty?
                                        parsed = parse_parameter(code, subparameter, game_type)

                                        unless parsed.nil?
                                            if processing_type == 'append' && !maps_translation_map.include?(parsed)
                                                insert_at_index(maps_translation_map, maps_lines.length, parsed, '')
                                            end

                                            maps_lines.add(parsed)
                                        end
                                    end
                                end
                            elsif code == 356 && parameter.is_a?(String) && !parameter.empty?
                                parsed = parse_parameter(code, parameter, game_type)

                                unless parsed.nil?
                                    subbed = parsed.gsub(/\r?\n/, '\#')

                                    if processing_type == 'append' && !maps_translation_map.include?(parsed)
                                        insert_at_index(maps_translation_map, maps_lines.length, parsed, '')
                                    end

                                    maps_lines.add(subbed)
                                end
                            end
                        end
                    end
                end
            end
        end

        puts "Parsed #{filename}" if logging
    end

    maps_original_content,
        maps_translated_content,
        names_original_content,
        names_translated_content = if processing_type == 'append'
                                       [maps_translation_map.keys.join("\n"),
                                        maps_translation_map.values.join("\n"),
                                        names_translation_map.keys.join("\n"),
                                        names_translation_map.values.join("\n")]
                                   else
                                       [maps_lines.join("\n"),
                                        "\n" * (maps_lines.empty? ? 0 : maps_lines.length - 1),
                                        names_lines.join("\n"),
                                        "\n" * (names_lines.empty? ? 0 : names_lines.length - 1)]
                                   end

    File.binwrite(maps_output_path, maps_original_content)
    File.binwrite(maps_trans_output_path, maps_translated_content)
    File.binwrite(names_output_path, names_original_content)
    File.binwrite(names_trans_output_path, names_translated_content)
end

def self.read_other(other_files, output_path, logging, game_type, processing_type)
    other_object_array_map = Hash[other_files.map do |filename|
        basename = File.basename(filename)
        object = Marshal.load(File.binread(filename))
        object = merge_other(object).slice(1..) if basename.start_with?(/Common|Troops/)

        [basename, object]
    end]

    internal_processing_type = processing_type

    other_object_array_map.each do |filename, other_object_array|
        processed_filename = File.basename(filename, '.*').downcase

        other_output_path = File.join(output_path, "#{processed_filename}.txt")
        other_trans_output_path = File.join(output_path, "#{processed_filename}_trans.txt")

        if processing_type == 'default' && File.exist?(other_trans_output_path)
            puts "#{processed_filename}_trans.txt file already exists. If you want to forcefully re-read all files, use --force flag, or --append if you want append new text to already existing files."
            next
        end

        other_lines = IndexSet.new
        other_translation_map = nil

        if processing_type == 'append'
            if File.exist?(other_trans_output_path)
                internal_processing_type == 'append'
                other_translation_map = Hash[File.readlines(other_output_path, chomp: true).zip(File.readlines(other_trans_output_path, chomp: true))]
            else
                puts "Files aren't already parsed. Continuing as if --append flag was omitted."
                internal_processing_type = 'default'
            end
        end

        if !filename.start_with?(/Common|Troops/)
            other_object_array.each do |object|
                name = object.instance_variable_get(:@name)
                nickname = object.instance_variable_get(:@nickname)
                description = object.instance_variable_get(:@description)
                note = object.instance_variable_get(:@note)

                [name, nickname, description, note].each do |variable|
                    if variable.is_a?(String) && !variable.empty?
                        parsed = parse_variable(variable, game_type)

                        unless parsed.nil?
                            if internal_processing_type == 'append' && !other_translation_map.include?(parsed)
                                insert_at_index(other_translation_map, other_lines.length, parsed, '')
                            end

                            other_lines.add(parsed)
                        end
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
                                    joined = line.join('\#')

                                    if internal_processing_type == 'append' && !other_translation_map.include?(joined)
                                        insert_at_index(other_translation_map, other_lines.length, joined, '')
                                    end

                                    other_lines.add(joined)

                                    line.clear
                                    in_sequence = false
                                end

                                case code
                                    when 102
                                        if parameter.is_a?(Array)
                                            parameter.each do |subparameter|
                                                if subparameter.is_a?(String) && !subparameter.empty?
                                                    if internal_processing_type == 'append' && !other_translation_map.include?(subparameter)
                                                        insert_at_index(other_translation_map, other_lines.length, subparameter, '')
                                                    end

                                                    other_lines.add(subparameter)
                                                end
                                            end
                                        end
                                    when 356
                                        if parameter.is_a?(String) && !parameter.empty?
                                            subbed = parameter.gsub(/\r?\n/, '\#')

                                            if internal_processing_type == 'append'
                                                insert_at_index(other_translation_map, other_lines.length, subbed, '')
                                            end

                                            other_lines.add(subbed)
                                        end
                                    else
                                        nil
                                end
                            end
                        end
                    end
                end
            end
        end

        puts "Parsed #{filename}" if logging

        original_content, translated_content = if processing_type == 'append'
                                                   [other_translation_map.keys.join("\n"), other_translation_map.values.join("\n")]
                                               else
                                                   [other_lines.join("\n"), "\n" * (other_lines.empty? ? 0 : other_lines.length - 1)]
                                               end

        File.binwrite(other_output_path, original_content)
        File.binwrite(other_trans_output_path, translated_content)
    end
end

def self.read_system(system_file_path, ini_file_path, output_path, logging, processing_type)
    def self.read_ini_title(ini_file_path)
        file_lines = File.readlines(ini_file_path, chomp: true)
        file_lines.each do |line|
            if line.start_with?('title')
                parts = line.partition('=')
                break parts[2].strip
            end
        end
    end

    system_filename = File.basename(system_file_path)
    system_basename = File.basename(system_file_path, '.*').downcase

    system_output_path = File.join(output_path, "#{system_basename}.txt")
    system_trans_output_path = File.join(output_path, "#{system_basename}_trans.txt")

    if processing_type == 'default' && File.exist?(system_trans_output_path)
        puts "system_trans.txt file already exists. If you want to forcefully re-read all files, use --force flag, or --append if you want append new text to already existing files."
        return
    end

    system_object = Marshal.load(File.binread(system_file_path))

    system_lines = IndexSet.new
    system_translation_map = nil

    if processing_type == 'append'
        if File.exist?(system_trans_output_path)
            system_translation_map = Hash[File.readlines(system_output_path, chomp: true).zip(File.readlines(system_trans_output_path, chomp: true))]
        else
            puts "Files aren't already parsed. Continuing as if --append flag was omitted."
            processing_type = 'default'
        end
    end

    elements = system_object.instance_variable_get(:@elements)
    skill_types = system_object.instance_variable_get(:@skill_types)
    weapon_types = system_object.instance_variable_get(:@weapon_types)
    armor_types = system_object.instance_variable_get(:@armor_types)
    currency_unit = system_object.instance_variable_get(:@currency_unit)
    terms = system_object.instance_variable_get(:@terms) || system_object.instance_variable_get(:@words)
    game_title = system_object.instance_variable_get(:@game_title)

    [elements, skill_types, weapon_types, armor_types].each do |array|
        next if array.nil?

        array.each do |string|
            if string.is_a?(String) && !string.empty?
                if processing_type == 'append' && !system_translation_map.include?(string)
                    insert_at_index(system_translation_map, system_lines.length, string, '')
                end

                system_lines.add(string)
            end
        end
    end

    if currency_unit.is_a?(String) && !currency_unit.empty?
        if processing_type == 'append' && !system_translation_map.include?(currency_unit)
            insert_at_index(system_translation_map, system_lines.length, currency_unit, '')
        end

        system_lines.add(currency_unit)
    end

    terms.instance_variables.each do |variable|
        value = terms.instance_variable_get(variable)

        if value.is_a?(String)
            unless value.empty?
                if processing_type == 'append' && !system_translation_map.include?(value)
                    insert_at_index(system_translation_map, system_lines.length, value, '')
                end

                system_lines.add(value)
            end

            next
        end

        value.each do |string|
            if string.is_a?(String) && !string.empty?
                if processing_type == 'append' && !system_translation_map.include?(string)
                    insert_at_index(system_translation_map, system_lines.length, string, '')
                end

                system_lines.add(string)
            end
        end
    end

    ini_game_title = read_ini_title(ini_file_path)

    $wait_time = 0

    if ini_game_title != game_title
        if game_title.is_a?(String) && !game_title.empty?
            wait_time_start = Time.now

            puts "Game title from the Game.ini file and game title from the System file are different.\nWhich game title would you like to parse?\n(That doesn't affect anything major, just when you'll write the game back, translated game title will be applied both to the .ini and System file.)\n0, System title - #{game_title}\n1, Game.ini title - #{ini_game_title}"
            choice = gets.chomp.to_i

            $wait_time = Time.now - wait_time_start

            if choice == 0
                if processing_type == 'append' && !system_translation_map.include?(game_title)
                    insert_at_index(system_translation_map, system_lines.length, game_title, '')
                end

                system_lines.add(game_title)
            else
                if processing_type == 'append' && !system_translation_map.include?(ini_game_title)
                    insert_at_index(system_translation_map, system_lines.length, ini_game_title, '')
                end

                system_lines.add(ini_game_title)
            end
        else
            if processing_type == 'append' && !system_translation_map.include?(ini_game_title)
                insert_at_index(system_translation_map, system_lines.length, ini_game_title, '')
            end

            system_lines.add(ini_game_title)
        end
    end

    puts "Parsed #{system_filename}" if logging

    original_content, translated_content = if processing_type == 'append'
                                               [system_translation_map.keys.join("\n"), system_translation_map.values.join("\n")]
                                           else
                                               [system_lines.join("\n"), "\n" * (system_lines.empty? ? 0 : system_lines.length - 1)]
                                           end

    File.binwrite(system_output_path, original_content)
    File.binwrite(system_trans_output_path, translated_content)
end

def self.read_scripts(scripts_file_path, output_path, logging, processing_type)
    scripts_filename = File.basename(scripts_file_path)
    scripts_basename = File.basename(scripts_file_path, '.*').downcase

    scripts_plain_output_path = File.join(output_path, "#{scripts_basename}_plain.txt")
    scripts_output_path = File.join(output_path, "#{scripts_basename}.txt")
    scripts_trans_output_path = File.join(output_path, "#{scripts_basename}_trans.txt")

    if processing_type == 'default' && File.exist?(scripts_trans_output_path)
        puts "scripts_trans.txt file already exists. If you want to forcefully re-read all files, use --force flag, or --append if you want append new text to already existing files."
        return
    end

    script_entries = Marshal.load(File.binread(scripts_file_path))

    scripts_lines = IndexSet.new
    scripts_translation_map = nil

    if processing_type == 'append'
        if File.exist?(scripts_trans_output_path)
            scripts_translation_map = Hash[File.readlines(scripts_output_path, chomp: true).zip(File.readlines(scripts_trans_output_path, chomp: true))]
        else
            puts "Files aren't already parsed. Continuing as if --append flag was omitted."
            processing_type = 'default'
        end
    end

    codes_content = []

    script_entries.each do |script|
        code = Zlib::Inflate.inflate(script[2]).force_encoding('UTF-8')
        codes_content.push(code)

        extract_quoted_strings(code).keys.each do |string|
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

            if processing_type == 'append' && !scripts_translation_map.include?(string)
                insert_at_index(scripts_translation_map, scripts_lines.length, string, '')
            end

            scripts_lines.add(string)
        end
    end

    puts "Parsed #{scripts_filename}" if logging

    File.binwrite(scripts_plain_output_path, codes_content.join("\n"))

    original_content, translated_content = if processing_type == 'append'
                                               [scripts_translation_map.keys.join("\n"), scripts_translation_map.values.join("\n")]
                                           else
                                               [scripts_lines.join("\n"), "\n" * (scripts_lines.empty? ? 0 : scripts_lines.length - 1)]
                                           end

    File.binwrite(scripts_output_path, original_content)
    File.binwrite(scripts_trans_output_path, translated_content)
end
