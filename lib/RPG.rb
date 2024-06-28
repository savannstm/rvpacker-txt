require 'RGSS'
module RPG
    class System
        include RGSS::BasicCoder
        HASHED_VARS = %w[variables switches].freeze
    end

    def self.array_to_hash(arr, &block)
        hash = {}

        arr.each_with_index do |val, index|
            r = block_given? ? block.call(val) : val
            hash[index] = r unless r.nil?
        end

        hash[-1] = nil if !arr.empty? && !hash.key?(last)

        hash
    end

    def encode(name, value)
        if HASHED_VARS.include?(name)
            array_to_hash(value) { |val| reduce_string(val) }
        elsif name == 'version_id'
            map_version(value)
        else
            value
        end
    end

    def decode(name, value)
        return hash_to_array(value) if HASHED_VARS.include?(name)

        value
    end

    class EventCommand
        def encode_with(coder)
            coder.style = case @code
                          when MOVE_LIST_CODE
                              # move list
                              Psych::Nodes::Mapping::BLOCK
                          else
                              Psych::Nodes::Mapping::FLOW
                          end
            coder['i'] = @indent
            coder['c'] = @code
            coder['p'] = @parameters
        end

        def init_with(coder)
            @indent = coder['i']
            @code = coder['c']
            @parameters = coder['p']
        end
    end
end
