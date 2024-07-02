module RGSS
    module BasicCoder
        def ivars
            instance_variables
        end

        INCLUDED_CLASSES = []

        def self.included(module_)
            INCLUDED_CLASSES.push(module_)
        end

        def self.ivars_methods_set(version)
            INCLUDED_CLASSES.each do |class_|
                if version == :ace
                    RGSS.reset_method(
                        class_,
                        :ivars,
                        -> { instance_variables }
                    )
                else
                    RGSS.reset_method(
                        class_,
                        :ivars,
                        -> { instance_variables.sort }
                    )
                end
            end
        end
    end
end
