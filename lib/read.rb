# frozen_string_literal: true

require 'zlib'

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
            if %w[' "].include?(char)
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
        when 102, 356
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

def self.read_map(original_map_files, output_path, logging, game_type)
    maps_object_map = Hash[original_map_files.map do |filename|
        [File.basename(filename), Marshal.load(File.binread(filename))]
    end]

    maps_lines = [IndexedSet.new, IndexedSet.new]

    maps_object_map.each do |filename, object|
        display_name = object.instance_variable_get(:@display_name)
        maps_lines[1].add(display_name) if display_name.is_a?(String) && !display_name.empty?

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
                                maps_lines[0].add(line.join('\#'))
                                line.clear
                                in_sequence = false
                            end

                            if code == 102 && parameter.is_a?(Array)
                                parameter.each do |subparameter|
                                    if subparameter.is_a?(String) && !subparameter.empty?
                                        parsed = parse_parameter(code, subparameter, game_type)
                                        maps_lines[0].add(parsed) unless parsed.nil?
                                    end
                                end
                            elsif code == 356 && parameter.is_a?(String) && !parameter.empty?
                                parsed = parse_parameter(code, parameter, game_type)
                                maps_lines[0].add(parsed.gsub(/\r?\n/, '\#')) unless parsed.nil?
                            end
                        end
                    end
                end
            end
        end

        puts "Parsed #{filename}" if logging
    end

    File.binwrite("#{output_path}/maps.txt", maps_lines[0].join("\n"))
    File.binwrite("#{output_path}/maps_trans.txt", "\n" * (maps_lines[0].empty? ? 0 : maps_lines[0].length - 1))
    File.binwrite("#{output_path}/names.txt", maps_lines[1].join("\n"))
    File.binwrite("#{output_path}/names_trans.txt", "\n" * (maps_lines[1].empty? ? 0 : maps_lines[1].length - 1))
end

def self.read_other(original_other_files, output_path, logging, game_type)
    other_object_array_map = Hash[original_other_files.map do |filename|
        basename = File.basename(filename)
        object = Marshal.load(File.binread(filename))
        object = merge_other(object).slice(1..) if basename.start_with?(/Common|Troops/)

        [basename, object]
    end]

    other_object_array_map.each do |filename, other_object_array|
        processed_filename = File.basename(filename, '.*').downcase
        other_lines = IndexedSet.new

        if !filename.start_with?(/Common|Troops/)
            other_object_array.each do |object|
                name = object.instance_variable_get(:@name)
                nickname = object.instance_variable_get(:@nickname)
                description = object.instance_variable_get(:@description)
                note = object.instance_variable_get(:@note)

                [name, nickname, description, note].each do |variable|
                    if variable.is_a?(String) && !variable.empty?
                        parsed = parse_variable(variable, game_type)
                        other_lines.add(parsed) unless parsed.nil?
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
                                    other_lines.add(line.join('\#'))
                                    line.clear
                                    in_sequence = false
                                end

                                case code
                                    when 102
                                        if parameter.is_a?(Array)
                                            parameter.each do |subparameter|
                                                other_lines.add(subparameter) if subparameter.is_a?(String) && !subparameter.empty?
                                            end
                                        end
                                    when 356
                                        other_lines.add(parameter.gsub(/\r?\n/, '\#')) if parameter.is_a?(String) &&
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

        puts "Parsed #{filename}" if logging

        File.binwrite("#{output_path}/#{processed_filename}.txt", other_lines.join("\n"))
        File.binwrite("#{output_path}/#{processed_filename}_trans.txt", "\n" * (other_lines.empty? ? 0 : other_lines.length - 1))
    end
end

def self.read_system(system_file_path, output_path, logging)
    system_filename = File.basename(system_file_path)
    system_basename = File.basename(system_file_path, '.*').downcase
    system_object = Marshal.load(File.binread(system_file_path))

    system_lines = IndexedSet.new

    elements = system_object.instance_variable_get(:@elements)
    skill_types = system_object.instance_variable_get(:@skill_types)
    weapon_types = system_object.instance_variable_get(:@weapon_types)
    armor_types = system_object.instance_variable_get(:@armor_types)
    currency_unit = system_object.instance_variable_get(:@currency_unit)
    terms = system_object.instance_variable_get(:@terms) || system_object.instance_variable_get(:@words)
    game_title = system_object.instance_variable_get(:@game_title)

    [elements, skill_types, weapon_types, armor_types].each do |array|
        next if array.nil?
        array.each { |string| system_lines.add(string) if string.is_a?(String) && !string.empty? }
    end

    system_lines.add(currency_unit) if currency_unit.is_a?(String) && !currency_unit.empty?

    terms.instance_variables.each do |variable|
        value = terms.instance_variable_get(variable)

        if value.is_a?(String)
            system_lines.add(value) unless value.empty?
            next
        end

        value.each { |string| system_lines.add(string) if string.is_a?(String) && !string.empty? }
    end

    system_lines.add(game_title) if game_title.is_a?(String) && !game_title.empty?

    puts "Parsed #{system_filename}" if logging

    File.binwrite("#{output_path}/#{system_basename}.txt", system_lines.join("\n"))
    File.binwrite("#{output_path}/#{system_basename}_trans.txt", "\n" * (system_lines.empty? ? 0 : system_lines.length - 1))
end

def self.read_scripts(scripts_file_path, output_path, logging)
    script_entries = Marshal.load(File.binread(scripts_file_path))
    scripts_lines = IndexedSet.new
    codes_content = []

    script_entries.each do |script|
        code = Zlib::Inflate.inflate(script[2]).force_encoding('UTF-8')
        codes_content.push(code)

        extract_quoted_strings(code).each do |string|
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

            scripts_lines.add(string)
        end
    end

    puts "Parsed #{File.basename(scripts_file_path)}" if logging

    File.binwrite("#{output_path}/scripts_plain.txt", codes_content.join("\n"))
    File.binwrite("#{output_path}/scripts.txt", scripts_lines.join("\n"))
    File.binwrite("#{output_path}/scripts_trans.txt", "\n" * (scripts_lines.empty? ? 0 : scripts_lines.length - 1))
end