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

def escaped?(line, index)
    backslash_count = 0

    (0..index).reverse_each do |i|
        break if line[i] != '\\'
        backslash_count += 1
    end

    backslash_count.even?
end

# @param [String] ruby_code
def extract_strings(ruby_code, mode = false)
    strings = mode ? [] : Set.new
    indices = []
    inside_string = false
    inside_multiline_comment = false
    string_start_index = 0
    current_quote_type = ''

    global_index = 0
    ruby_code.each_line do |line|
        stripped = line.strip

        unless inside_string
            if stripped[0] == '#'
                global_index += line.length
                next
            end

            if stripped.start_with?('=begin')
                inside_multiline_comment = true
            elsif stripped.start_with?('=end')
                inside_multiline_comment = false
            end
        end

        if inside_multiline_comment
            global_index += line.length
            next
        end

        i = 0
        while i < line.length
            char = line[i]

            if !inside_string && char == '#'
                break
            end

            if !inside_string && ['"', "'"].include?(char)
                inside_string = true
                string_start_index = global_index + i
                current_quote_type = char
            elsif inside_string && char == current_quote_type && escaped?(line, i - 1)
                extracted_string = ruby_code[string_start_index + 1...global_index + i].gsub(/\r?\n/, '\#')

                if mode
                    strings << extracted_string
                    indices << string_start_index + 1
                else
                    strings.add(extracted_string)
                end

                inside_string = false
                current_quote_type = ''
            end

            i += 1
        end

        global_index += line.length
    end

    mode ? [strings, indices] : strings.to_a
end
