# frozen_string_literal: true

# @param [String] string
# @return [String]
def self.romanize_string(string)
    string.each_char.each_with_index do |char, i|
        case char
            when '。'
                string[i] = '.'
            when '、'
                string[i] = ','
            when '・'
                string[i] = '·'
            when '゠'
                string[i] = '–'
            when '＝'
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
            else
                nil
        end
    end

    string
end
