# frozen_string_literal: true

require 'zlib'
require_relative 'extensions'

STRING_IS_ONLY_SYMBOLS_RE = /^[.()+\-:;\[\]^~%&!№$@`*\/→×？?ｘ％▼|♥♪！：〜『』「」〽。…‥＝゠、，【】［］｛｝（）〔〕｟｠〘〙〈〉《》・\\#'"<>=_ー※▶ⅠⅰⅡⅱⅢⅲⅣⅳⅤⅴⅥⅵⅦⅶⅧⅷⅨⅸⅩⅹⅪⅺⅫⅻⅬⅼⅭⅽⅮⅾⅯⅿ\s0-9]+$/
APPEND_FLAG_OMIT_MSG = "Files aren't already parsed. Continuing as if --append flag was omitted."

# @param [Integer] code
# @param [String] parameter
# @param [String] game_type
# @return [String]
def self.parse_parameter(code, parameter, game_type)
    return nil if parameter.match?(STRING_IS_ONLY_SYMBOLS_RE)

    ends_with_if = parameter[/ if\(.*\)$/]
    parameter = parameter.chomp(ends_with_if) if ends_with_if

    unless game_type.nil?
        case game_type
            when 'lisa'
                case code
                    when 401, 405
                        prefix = parameter[/^(\\et\[[0-9]+\]|\\nbt)/]
                        parameter = parameter.sub(prefix, '') if prefix
                    when 102
                        # Implement some custom parsing
                    when 356
                        # Implement some custom parsing
                    else
                        return nil
                end
                # Implement cases for other games
            else
                nil
        end

    end

    parameter
end

# @param [String] variable
# @param [Integer] type
# @param [String] _game_type
# @return [String]
def self.parse_variable(variable, type, _game_type)
    variable = variable.gsub(/\r?\n/, "\n")
    # for some reason it returns true if multi-line string contains carriage returns (wtf?)
    return nil if variable.match?(STRING_IS_ONLY_SYMBOLS_RE)

    if variable.split("\n").all? do |line|
        line.empty? ||
            line.match?(/^#? ?<.*>.?$/) ||
            line.match?(/^[a-z][0-9]$/)
    end
        return nil
    end

    return nil if variable.match?(/^[+-]?[0-9]+$/) ||
        variable.match?(/---/) ||
        variable.match?(/restrict eval/)

    case type
        when 0 # name
        when 1 # nickname
        when 2 # description
        when 3 # note
        else
            nil
    end

    variable
end

# @param [Array<String>] maps_files_paths Array of paths to original maps files
# @param [String] output_path Path to output directory
# @param [Boolean] romanize Whether to romanize text
# @param [Boolean] logging Whether to log
# @param [String] game_type Game type for custom processing
# @param [String] processing_mode Whether to read in default mode, force rewrite or append new text to existing files
def self.read_map(maps_files_paths, output_path, romanize, logging, game_type, processing_mode)
    maps_output_path = File.join(output_path, 'maps.txt')
    names_output_path = File.join(output_path, 'names.txt')
    maps_trans_output_path = File.join(output_path, 'maps_trans.txt')
    names_trans_output_path = File.join(output_path, 'names_trans.txt')

    if processing_mode == :default && (File.exist?(maps_trans_output_path) || File.exist?(names_trans_output_path))
        puts 'maps_trans.txt or names_trans.txt file already exists. If you want to forcefully re-read all files, use --force flag, or --append if you want append new text to already existing files.'
        return
    end

    maps_object_map = Hash[maps_files_paths.map { |f| [File.basename(f), Marshal.load(File.binread(f))] }]

    maps_lines = Set.new
    names_lines = Set.new

    maps_translation_map = nil
    names_translation_map = nil

    if processing_mode == :append
        if File.exist?(maps_trans_output_path)
            maps_translation_map = Hash[File.readlines(maps_output_path, chomp: true)
                                            .zip(File.readlines(maps_trans_output_path, chomp: true))]
            names_translation_map = Hash[File.readlines(names_output_path, chomp: true)
                                             .zip(File.readlines(names_trans_output_path, chomp: true))]
        else
            puts APPEND_FLAG_OMIT_MSG
            processing_mode = :default
        end
    end

    # 401 - dialogue lines
    # 102 - dialogue choices array
    # 356 - system lines/special texts (do they even exist before mv?)
    allowed_codes = [401, 102, 356].freeze

    maps_object_map.each do |filename, object|
        display_name = object.display_name

        if display_name.is_a?(String)
            display_name = display_name.strip

            unless display_name.empty?
                display_name = romanize_string(display_name) if romanize

                names_translation_map.insert_at_index(names_lines.length, display_name, '') if processing_mode == :append &&
                    !names_translation_map.include?(display_name)

                names_lines.add(display_name)
            end
        end

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

                list.each do |item|
                    code = item.code

                    if in_sequence && code != 401
                        unless line.empty?
                            joined = line.join("\n").strip.gsub("\n", '\#')
                            parsed = parse_parameter(401, joined, game_type)

                            unless parsed.nil?
                                parsed = romanize_string(parsed) if romanize

                                maps_translation_map.insert_at_index(maps_lines.length, parsed, '') if processing_mode == :append &&
                                    !maps_translation_map.include?(parsed)

                                maps_lines.add(parsed)
                            end

                            line.clear
                        end

                        in_sequence = false
                    end

                    next unless allowed_codes.include?(code)

                    parameters = item.parameters

                    if code == 401
                        next unless parameters[0].is_a?(String) && !parameters[0].empty?

                        in_sequence = true
                        line.push(parameters[0].gsub('　', ' ').strip)
                    elsif parameters[0].is_a?(Array)
                        parameters[0].each do |subparameter|
                            next unless subparameter.is_a?(String)

                            subparameter = subparameter.strip
                            next if subparameter.empty?

                            parsed = parse_parameter(code, subparameter, game_type)
                            next if parsed.nil?

                            parsed = romanize_string(parsed) if romanize

                            maps_translation_map.insert_at_index(maps_lines.length, parsed, '') if processing_mode == :append &&
                                !maps_translation_map.include?(parsed)

                            maps_lines.add(parsed)
                        end
                    elsif parameters[0].is_a?(String)
                        parameter = parameters[0].strip
                        next if parameter.empty?

                        parsed = parse_parameter(code, parameter, game_type)
                        next if parsed.nil?

                        parsed = romanize_string(parsed) if romanize

                        maps_translation_map.insert_at_index(maps_lines.length, parsed, '') if processing_mode == :append &&
                            !maps_translation_map.include?(parsed)

                        maps_lines.add(parsed)
                    end
                end
            end
        end

        puts "Parsed #{filename}" if logging
    end

    maps_original_content,
        maps_translated_content,
        names_original_content,
        names_translated_content = if processing_mode == :append
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

# @param [Array<String>] other_files_paths
# @param [String] output_path
# @param [Boolean] romanize Whether to romanize text
# @param [Boolean] logging Whether to log
# @param [String] game_type Game type for custom processing
# @param [String] processing_mode Whether to read in default mode, force rewrite or append new text to existing files
def self.read_other(other_files_paths, output_path, romanize, logging, game_type, processing_mode)
    other_object_array_map = Hash[other_files_paths.map { |f| [File.basename(f), Marshal.load(File.binread(f))] }]

    inner_processing_type = processing_mode
    # 401 - dialogue lines
    # 405 - credits lines
    # 102 - dialogue choices array
    # 356 - system lines/special texts (do they even exist before mv?)
    allowed_codes = [401, 405, 102, 356].freeze

    other_object_array_map.each do |filename, other_object_array|
        processed_filename = File.basename(filename, '.*').downcase

        other_output_path = File.join(output_path, "#{processed_filename}.txt")
        other_trans_output_path = File.join(output_path, "#{processed_filename}_trans.txt")

        if processing_mode == :default && File.exist?(other_trans_output_path)
            puts "#{processed_filename}_trans.txt file already exists. If you want to forcefully re-read all files, use --force flag, or --append if you want append new text to already existing files."
            next
        end

        other_lines = Set.new
        other_translation_map = nil

        if processing_mode == :append
            if File.exist?(other_trans_output_path)
                inner_processing_type == :append
                other_translation_map = Hash[File.readlines(other_output_path, chomp: true)
                                                 .zip(File.readlines(other_trans_output_path, chomp: true))]
            else
                puts APPEND_FLAG_OMIT_MSG
                inner_processing_type = :default
            end
        end

        if !filename.start_with?(/Common|Troops/)
            other_object_array.each do |object|
                next if object.nil?

                name = object.name
                nickname = object.nickname if object.is_a?(RPG::Actor)
                description = object.description
                note = object.note

                catch :next_object do
                    [name, nickname, description, note].each_with_index do |variable, type|
                        next unless variable.is_a?(String)

                        variable = variable.strip
                        next if variable.empty?

                        parsed = parse_variable(variable, type, game_type)

                        if !parsed.nil?
                            parsed = romanize_string(parsed) if romanize

                            parsed = parsed.split("\n").map(&:strip).join('\#')

                            other_translation_map.insert_at_index(other_lines.length, parsed, '') if inner_processing_type == :append &&
                                !other_translation_map.include?(parsed)

                            other_lines.add(parsed)
                        elsif type.zero?
                            throw :next_object
                        end
                    end
                end
            end
        else
            other_object_array.each do |object|
                next if object.nil?

                pages = object.pages
                pages_length = pages.nil? ? 1 : pages.length

                (0..pages_length).each do |i|
                    list = pages.nil? ? object.list : pages[i].instance_variable_get(:@list)
                    next if list.nil?

                    in_sequence = false
                    line = []

                    list.each do |item|
                        code = item.code

                        if in_sequence && ![401, 405].include?(code)
                            unless line.empty?
                                joined = line.join("\n").strip.gsub("\n", '\#')
                                parsed = parse_parameter(401, joined, game_type)

                                unless parsed.nil?
                                    parsed = romanize_string(parsed) if romanize

                                    other_translation_map.insert_at_index(other_lines.length, parsed, '') if inner_processing_type == :append &&
                                        !other_translation_map.include?(parsed)

                                    other_lines.add(parsed)
                                end

                                line.clear
                            end

                            in_sequence = false
                        end

                        next unless allowed_codes.include?(code)

                        parameters = item.parameters

                        if [401, 405].include?(code)
                            next unless parameters[0].is_a?(String) && !parameters[0].empty?

                            in_sequence = true
                            line.push(parameters[0].gsub('　', ' ').strip)
                        elsif parameters[0].is_a?(Array)
                            parameters[0].each do |subparameter|
                                next unless subparameter.is_a?(String)

                                subparameter = subparameter.strip
                                next if subparameter.empty?

                                parsed = parse_parameter(code, subparameter, game_type)
                                next if parsed.nil?

                                parsed = romanize_string(parsed) if romanize

                                other_translation_map.insert_at_index(other_lines.length, parsed, '') if inner_processing_type == :append &&
                                    !other_translation_map.include?(parsed)

                                other_lines.add(parsed)
                            end
                        elsif parameters[0].is_a?(String)
                            parameter = parameters[0].strip
                            next if parameter.empty?

                            parsed = parse_parameter(code, parameter, game_type)
                            next if parsed.nil?

                            parsed = romanize_string(parsed) if romanize

                            other_translation_map.insert_at_index(other_lines.length, parsed, '') if inner_processing_type == :append &&
                                !other_translation_map.include?(parsed)

                            other_lines.add(parsed)
                        elsif parameters[1].is_a?(String)
                            parameter = parameters[1].strip
                            next if parameter.empty?

                            parsed = parse_parameter(code, parameter, game_type)
                            next if parsed.nil?

                            parsed = romanize_string(parsed) if romanize

                            other_translation_map.insert_at_index(other_lines.length, parsed, '') if inner_processing_type == :append &&
                                !other_translation_map.include?(parsed)

                            other_lines.add(parsed)
                        end
                    end
                end
            end
        end

        puts "Parsed #{filename}" if logging

        original_content, translated_content = if processing_mode == :append
                                                   [other_translation_map.keys.join("\n"),
                                                    other_translation_map.values.join("\n")]
                                               else
                                                   [other_lines.join("\n"),
                                                    "\n" * (other_lines.empty? ? 0 : other_lines.length - 1)]
                                               end

        File.binwrite(other_output_path, original_content)
        File.binwrite(other_trans_output_path, translated_content)
    end
end

# @param [String] ini_file_path
def self.read_ini_title(ini_file_path)
    file_lines = File.readlines(ini_file_path, chomp: true)
    file_lines.each do |line|
        if line.downcase.start_with?('title')
            parts = line.partition('=')
            break parts[2].strip
        end
    end
end

# @param [String] system_file_path
# @param [String] ini_file_path
# @param [String] output_path
# @param [Boolean] romanize Whether to romanize text
# @param [Boolean] logging Whether to log
# @param [String] processing_mode Whether to read in default mode, force rewrite or append new text to existing files
def self.read_system(system_file_path, ini_file_path, output_path, romanize, logging, processing_mode)
    system_filename = File.basename(system_file_path)
    system_basename = File.basename(system_file_path, '.*').downcase

    system_output_path = File.join(output_path, "#{system_basename}.txt")
    system_trans_output_path = File.join(output_path, "#{system_basename}_trans.txt")

    if processing_mode == :default && File.exist?(system_trans_output_path)
        puts 'system_trans.txt file already exists. If you want to forcefully re-read all files, use --force flag, or --append if you want append new text to already existing files.'
        return
    end

    system_object = Marshal.load(File.binread(system_file_path))

    system_lines = Set.new
    system_translation_map = nil

    if processing_mode == :append
        if File.exist?(system_trans_output_path)
            system_translation_map = Hash[File.readlines(system_output_path, chomp: true)
                                              .zip(File.readlines(system_trans_output_path, chomp: true))]
        else
            puts APPEND_FLAG_OMIT_MSG
            processing_mode = :default
        end
    end

    elements = system_object.elements
    skill_types = system_object.skill_types
    weapon_types = system_object.weapon_types
    armor_types = system_object.armor_types
    currency_unit = system_object.currency_unit
    terms = system_object.terms || system_object.words

    [elements, skill_types, weapon_types, armor_types].each do |array|
        next if array.nil?

        array.each do |string|
            next unless string.is_a?(String)

            string = string.strip
            next if string.empty?

            string = romanize_string(string) if romanize

            system_translation_map.insert_at_index(system_lines.length, string, '') if processing_mode == :append &&
                !system_translation_map.include?(string)

            system_lines.add(string)
        end
    end

    if currency_unit.is_a?(String)
        currency_unit = currency_unit.strip

        unless currency_unit.empty?
            currency_unit = romanize_string(currency_unit) if romanize

            system_translation_map.insert_at_index(system_lines.length, currency_unit, '') if processing_mode == :append &&
                !system_translation_map.include?(currency_unit)

            system_lines.add(currency_unit)
        end
    end

    terms.instance_variables.each do |variable|
        value = terms.instance_variable_get(variable)

        if value.is_a?(String)
            value = value.strip

            unless value.empty?
                value = romanize_string(string) if romanize

                system_translation_map.insert_at_index(system_lines.length, value, '') if processing_mode == :append &&
                    !system_translation_map.include?(value)

                system_lines.add(value)
            end
        elsif value.is_a?(Array)
            value.each do |string|
                next unless string.is_a?(String)

                string = string.strip
                next if string.empty?

                string = romanize_string(string) if romanize

                system_translation_map.insert_at_index(system_lines.length, string, '') if processing_mode == :append &&
                    !system_translation_map.include?(string)

                system_lines.add(string)
            end
        end
    end

    # Game title from System file and ini file may differ, but requesting user request to determine which line do they want is LAME
    # So just throw that ini ass and continue
    ini_game_title = read_ini_title(ini_file_path).strip
    ini_game_title = romanize_string(ini_game_title) if romanize

    system_translation_map.insert_at_index(system_lines.length, ini_game_title, '') if processing_mode == :append &&
        !system_translation_map.include?(ini_game_title)

    system_lines.add(ini_game_title)

    puts "Parsed #{system_filename}" if logging

    original_content, translated_content = if processing_mode == :append
                                               [system_translation_map.keys.join("\n"),
                                                system_translation_map.values.join("\n")]
                                           else
                                               [system_lines.join("\n"),
                                                "\n" * (system_lines.empty? ? 0 : system_lines.length - 1)]
                                           end

    File.binwrite(system_output_path, original_content)
    File.binwrite(system_trans_output_path, translated_content)
end

# @param [String] scripts_file_path
# @param [String] output_path
# @param [Boolean] romanize Whether to romanize text
# @param [Boolean] logging Whether to log
# @param [String] processing_mode Whether to read in default mode, force rewrite or append new text to existing files
def self.read_scripts(scripts_file_path, output_path, romanize, logging, processing_mode)
    scripts_filename = File.basename(scripts_file_path)
    scripts_basename = File.basename(scripts_file_path, '.*').downcase

    scripts_plain_output_path = File.join(output_path, "#{scripts_basename}_plain.txt")
    scripts_output_path = File.join(output_path, "#{scripts_basename}.txt")
    scripts_trans_output_path = File.join(output_path, "#{scripts_basename}_trans.txt")

    if processing_mode == :default && File.exist?(scripts_trans_output_path)
        puts 'scripts_trans.txt file already exists. If you want to forcefully re-read all files, use --force flag, or --append if you want append new text to already existing files.'
        return
    end

    script_entries = Marshal.load(File.binread(scripts_file_path))

    scripts_lines = Set.new
    scripts_translation_map = nil

    if processing_mode == :append
        if File.exist?(scripts_trans_output_path)
            scripts_translation_map = Hash[File.readlines(scripts_output_path, chomp: true)
                                               .zip(File.readlines(scripts_trans_output_path, chomp: true))]
        else
            puts APPEND_FLAG_OMIT_MSG
            processing_mode = :default
        end
    end

    codes_content = []

    # This code was fun before `that` game used Windows-1252 degree symbol
    script_entries.each do |script|
        code = Zlib::Inflate.inflate(script[2]).force_encoding('UTF-8')

        # I figured how String#encode works - now everything is good
        unless code.valid_encoding?
            [Encoding::UTF_8, Encoding::WINDOWS_1252, Encoding::SHIFT_JIS].each do |encoding|
                encoded = code.encode(code.encoding, encoding)

                if encoded.valid_encoding?
                    code.force_encoding(encoding)
                    break
                end
            rescue Encoding::InvalidByteSequenceError
                next
            end
        end

        codes_content.push(code)
    end

    extracted = extract_strings(codes_content.join)

    extracted.each do |string|
        # Removes the U+3000 Japanese typographical space to check if string, when stripped, is truly empty
        string = string.gsub('　', ' ').strip

        next if string.empty?

        next if string.match?(/(Graphics|Data|Audio|Movies|System)\/.*\/?/) ||
            string.match?(/r[xv]data2?$/) ||
            string.match?(STRING_IS_ONLY_SYMBOLS_RE) ||
            string.match?(/@window/) ||
            string.match?(/\$game/) ||
            string.match?(/_/) ||
            string.match?(/^\\e/) ||
            string.match?(/.*\(/) ||
            string.match?(/^([d\d\p{P}+-]*|[d\p{P}+-]*)$/) ||
            string.match?(/ALPHAC/) ||
            string.match?(/^(Actor<id>|ExtraDropItem|EquipLearnSkill|GameOver|Iconset|Window|true|false|MActor%d|w[rb]|\\f|\\n|\[[A-Z]*\])$/)

        string = romanize_string(string) if romanize

        scripts_translation_map.insert_at_index(scripts_lines.length, string, '') if processing_mode == :append &&
            !scripts_translation_map.include?(string)

        scripts_lines.add(string)
    end

    puts "Parsed #{scripts_filename}" if logging

    File.binwrite(scripts_plain_output_path, codes_content.join("\n"))

    original_content, translated_content = if processing_mode == :append
                                               [scripts_translation_map.keys.join("\n"),
                                                scripts_translation_map.values.join("\n")]
                                           else
                                               [scripts_lines.join("\n"),
                                                "\n" * (scripts_lines.empty? ? 0 : scripts_lines.length - 1)]
                                           end

    File.binwrite(scripts_output_path, original_content)
    File.binwrite(scripts_trans_output_path, translated_content)
end
