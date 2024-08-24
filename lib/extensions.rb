# frozen_string_literal: true

# @param [String] input_string
# @return [String]
def self.romanize_string(input_string)
    # @type [Array<String>]
    result = []

    input_string.each_char do |char|
        result << case char
        when '。'
            '.'
        when '、', '，'
            ','
        when '・'
            '·'
        when '゠'
            '–'
        when '＝', 'ー'
            '—'
        when '…', '‥'
            '...'
        when '「', '」', '〈', '〉'
            "'"
        when '『', '』', '《', '》'
            '"'
        when '（', '〔', '｟', '〘'
            '('
        when '）', '〕', '｠', '〙'
            ')'
        when '｛'
            '{'
        when '｝'
            '}'
        when '［', '【', '〖', '〚'
            '['
        when '］', '】', '〗', '〛'
            ']'
        when '〜'
            '~'
        when '？'
            '?'
        when '：'
            ':'
        when '！'
            '!'
        when '※'
            '*'
        when '　'
            ' '
        when 'Ⅰ'
            'I'
        when 'ⅰ'
            'i'
        when 'Ⅱ'
            'II'
        when 'ⅱ'
            'ii'
        when 'Ⅲ'
            'III'
        when 'ⅲ'
            'iii'
        when 'Ⅳ'
            'IV'
        when 'ⅳ'
            'iv'
        when 'Ⅴ'
            'V'
        when 'ⅴ'
            'v'
        when 'Ⅵ'
            'VI'
        when 'ⅵ'
            'vi'
        when 'Ⅶ'
            'VII'
        when 'ⅶ'
            'vii'
        when 'Ⅷ'
            'VIII'
        when 'ⅷ'
            'viii'
        when 'Ⅸ'
            'IX'
        when 'ⅸ'
            'ix'
        when 'Ⅹ'
            'X'
        when 'ⅹ'
            'x'
        when 'Ⅺ'
            'XI'
        when 'ⅺ'
            'xi'
        when 'Ⅻ'
            'XII'
        when 'ⅻ'
            'xii'
        when 'Ⅼ'
            'L'
        when 'ⅼ'
            'l'
        when 'Ⅽ'
            'C'
        when 'ⅽ'
            'c'
        when 'Ⅾ'
            'D'
        when 'ⅾ'
            'd'
        when 'Ⅿ'
            'M'
        when 'ⅿ'
            'm'
        else
            char
        end
    end

    result.join
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
def extract_strings(ruby_code, mode: false)
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

            break if !inside_string && char == '#'

            if !inside_string && %w[" '].include?(char)
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

ENCODINGS = %w[
    ISO-8859-1
    Windows-1252
    Shift_JIS
    GB18030
    EUC-JP
    ISO-2022-JP
    BIG5
    EUC-KR
    Windows-1251
    KOI8-R
    UTF-8
].freeze

# @param [String] input_string
# @return [String]
def convert_to_utf8(input_string)
    ENCODINGS.each do |encoding|
        return input_string.encode('UTF-8', encoding)
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        next
    end

    raise EncodingError("Cannot convert string #{input_string} to UTF-8")
end
