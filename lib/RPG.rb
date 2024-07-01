require 'RGSS'
module RPG
    class System
        include RGSS::BasicCoder
        HASHED_VARS = %w[variables switches]
    end

    def self.array_to_hash(arr, &block)
        h = {}
        arr.each_with_index do |val, index|
            r = block_given? ? block.call(val) : val
            h[index] = r unless r.nil?
        end
        if arr.length > 0
            last = arr.length - 1
            h[last] = nil unless h.has_key?(last)
        end
        return h
    end

    def encode(name, value)
        if HASHED_VARS.include?(name)
            return array_to_hash(value) { |val| reduce_string(val) }
        elsif name == 'version_id'
            return map_version(value)
        else
            return value
        end
    end

    def decode(name, value)
        if HASHED_VARS.include?(name)
            return hash_to_array(value)
        else
            return value
        end
    end

    class EventCommand
        def encode_with(coder)
            case @code
                when MOVE_LIST_CODE
                    # move list
                    coder.style = Psych::Nodes::Mapping::BLOCK
                else
                    coder.style = Psych::Nodes::Mapping::FLOW
            end
            coder['i'], coder['c'], coder['p'] = @indent, @code, @parameters
        end

        def init_with(coder)
            @indent, @code, @parameters = coder['i'], coder['c'], coder['p']
        end
    end
end
