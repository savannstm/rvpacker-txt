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
