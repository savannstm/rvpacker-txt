# frozen_string_literal: true

# @param [String] string
# @return [String]
def self.romanize_string(string)
    string.each_char.each_with_index do |char, i|
        case char
            when '。'
                string[i] = '.'
            when '、', '，'
                string[i] = ','
            when '・'
                string[i] = '·'
            when '゠'
                string[i] = '–'
            when '＝', 'ー'
                string[i] = '—'
            when '…', '‥'
                string[i, 3] = '...'
            when '「', '」', '〈', '〉'
                string[i] = "'"
            when '『', '』', '《', '》'
                string[i] = '"'
            when '（', '〔', '｟', '〘'
                string[i] = '('
            when '）', '〕', '｠', '〙'
                string[i] = ')'
            when '｛'
                string[i] = '{'
            when '｝'
                string[i] = '}'
            when '［', '【', '〖', '〚'
                string[i] = '['
            when '］', '】', '〗', '〛'
                string[i] = ']'
            when '〜'
                string[i] = '~'
            when '？'
                string[i] = '?'
            when '：'
                string[i] = ':'
            when '！'
                string[i] = '!'
            when '※'
                string[i] = '*'
            when '　'
                string[i] = ' '
            when 'Ⅰ'
                string[i] = 'I'
            when 'ⅰ'
                string[i] = 'i'
            when 'Ⅱ'
                string[i, 2] = 'II'
            when 'ⅱ'
                string[i, 2] = 'ii'
            when 'Ⅲ'
                string[i, 3] = 'III'
            when 'ⅲ'
                string[i, 3] = 'iii'
            when 'Ⅳ'
                string[i, 2] = 'IV'
            when 'ⅳ'
                string[i, 2] = 'iv'
            when 'Ⅴ'
                string[i] = 'V'
            when 'ⅴ'
                string[i] = 'v'
            when 'Ⅵ'
                string[i, 2] = 'VI'
            when 'ⅵ'
                string[i, 2] = 'vi'
            when 'Ⅶ'
                string[i, 3] = 'VII'
            when 'ⅶ'
                string[i, 3] = 'vii'
            when 'Ⅷ'
                string[i, 4] = 'VIII'
            when 'ⅷ'
                string[i, 4] = 'viii'
            when 'Ⅸ'
                string[i, 2] = 'IX'
            when 'ⅸ'
                string[i, 2] = 'ix'
            when 'Ⅹ'
                string[i] = 'X'
            when 'ⅹ'
                string[i] = 'x'
            when 'Ⅺ'
                string[i, 2] = 'XI'
            when 'ⅺ'
                string[i, 2] = 'xi'
            when 'Ⅻ'
                string[i, 3] = 'XII'
            when 'ⅻ'
                string[i, 3] = 'xii'
            when 'Ⅼ'
                string[i] = 'L'
            when 'ⅼ'
                string[i] = 'l'
            when 'Ⅽ'
                string[i] = 'C'
            when 'ⅽ'
                string[i] = 'c'
            when 'Ⅾ'
                string[i] = 'D'
            when 'ⅾ'
                string[i] = 'd'
            when 'Ⅿ'
                string[i] = 'M'
            when 'ⅿ'
                string[i] = 'm'
            else
                nil
        end
    end

    string
end

# @param [Array<String>] array Array of strings
# @return [Array<String>] Array of shuffled strings
def self.shuffle_words(array)
    array.each do |string|
        select_words_re = /\S+/
        words = string.scan(select_words_re).shuffle
        string.gsub(select_words_re) { words.pop || '' }
    end
end

# @param [String] string A parsed scripts code string, containing raw Ruby code
# @param [Symbol] mode Mode to extract quoted strings
# @return [IndexSet<String>] Set of extracted strings
def extract_quoted_strings(string, mode)
    if mode == :read
        result = IndexSet.new

        skip_block = false
        in_quotes = false
        quote_type = nil
        buffer = []

        string.each_line do |line|
            stripped = line.strip

            next if stripped[0] == '#' ||
                (!in_quotes && !stripped.match?(/["']/)) ||
                stripped.start_with?(/(Win|Lose)|_Fanfare/) ||
                stripped.match?(/eval\(/)

            skip_block = true if stripped.start_with?('=begin')
            skip_block = false if stripped.start_with?('=end')

            next if skip_block

            line.each_char do |char|
                if %w[' "].include?(char)
                    unless quote_type.nil? || char == quote_type
                        buffer.push(char)
                        next
                    end

                    quote_type = char
                    in_quotes = !in_quotes
                    result.add(buffer.join)
                    buffer.clear
                    next
                end

                next unless in_quotes

                if char == "\r"
                    next
                elsif char == "\n"
                    buffer.push('\#')
                    next
                end

                buffer.push(char)
            end
        end

        result
    else
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
end