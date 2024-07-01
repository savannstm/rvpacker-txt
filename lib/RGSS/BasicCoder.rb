module RGSS
    module BasicCoder
        def encode_with(coder)
            ivars.each do |var|
                name = var.to_s.sub(/^@/, '')
                value = instance_variable_get(var)
                coder[name] = encode(name, value)
            end
        end

        def encode(name, value)
            return value
        end

        def init_with(coder)
            coder.map.each do |key, value|
                sym = "@#{key}".to_sym
                instance_variable_set(sym, decode(key, value))
            end
        end

        def decode(name, value)
            return value
        end

        def ivars
            return instance_variables
        end

        INCLUDED_CLASSES = []

        def self.included(mod)
            INCLUDED_CLASSES.push(mod)
        end

        def self.set_ivars_methods(version)
            INCLUDED_CLASSES.each do |c|
                if version == :ace
                    RGSS.reset_method(
                        c,
                        :ivars,
                        -> { return instance_variables }
                    )
                else
                    RGSS.reset_method(
                        c,
                        :ivars,
                        -> { return instance_variables.sort }
                    )
                end
            end
        end
    end
end
