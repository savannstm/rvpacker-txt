=begin
Copyright (c) 2013 Howard Jeng

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
=end

class Table
    def initialize(bytes)
        @dim, @x, @y, @z, items, *@data = bytes.unpack('L5 S*')

        unless items == @data.length && @x * @y * @z == items
            raise 'Size mismatch loading Table from data'
        end
    end

    def _dump(*_ignored)
        [@dim, @x, @y, @z, @x * @y * @z, *@data].pack('L5 S*')
    end

    def self._load(bytes)
        Table.new(bytes)
    end
end

class Color
    def initialize(bytes)
        @r, @g, @b, @a = *bytes.unpack('D4')
    end

    def _dump(*_ignored)
        [@r, @g, @b, @a].pack('D4')
    end

    def self._load(bytes)
        Color.new(bytes)
    end
end

class Tone
    def initialize(bytes)
        @r, @g, @b, @a = *bytes.unpack('D4')
    end

    def _dump(*_ignored)
        [@r, @g, @b, @a].pack('D4')
    end

    def self._load(bytes)
        Tone.new(bytes)
    end
end

class Rect
    def initialize(bytes)
        @x, @y, @width, @height = *bytes.unpack('i4')
    end

    def _dump(*_ignored)
        [@x, @y, @width, @height].pack('i4')
    end

    def self._load(bytes)
        Rect.new(bytes)
    end
end

module RGSS
    def self.remove_defined_method(scope, name)
        if scope.instance_methods(false).include?(name)
            scope.send(:remove_method, name)
        end
    end

    def self.reset_method(scope, name, method)
        remove_defined_method(scope, name)
        scope.send(:define_method, name, method)
    end

    def self.reset_const(scope, symbol, value)
        scope.send(:remove_const, symbol) if scope.const_defined?(symbol)
        scope.send(:const_set, symbol, value)
    end

    def self.array_to_hash(array, &block)
        hash = {}

        array.each_with_index do |value, index|
            r = block_given? ? block.call(value) : value
            hash[index] = r unless r.nil?
        end

        unless array.empty?
            last = array.length - 1
            hash[last] = nil unless hash.has_key?(last)
        end

        hash
    end

    def self.hash_to_array(hash)
        array = []
        hash.each { |key, value| array[key] = value }
        array
    end

    require 'RGSS/BasicCoder'
    require 'RPG'

    # creates an empty class in a potentially nested scope
    def self.process(root, name, *args)
        if !args.empty?
            process(root.const_get(name), *args)
        else
            unless root.const_defined?(name, false)
                root.const_set(name, Class.new)
            end
        end
    end

    # other classes that don't need definitions
    [
        # RGSS data structures
        %i[RPG Actor],
        %i[RPG Animation],
        %i[RPG Animation Frame],
        %i[RPG Animation Timing],
        %i[RPG Area],
        %i[RPG Armor],
        %i[RPG AudioFile],
        %i[RPG BaseItem],
        %i[RPG BaseItem Feature],
        %i[RPG BGM],
        %i[RPG BGS],
        %i[RPG Class],
        %i[RPG Class Learning],
        %i[RPG CommonEvent],
        %i[RPG Enemy],
        %i[RPG Enemy Action],
        %i[RPG Enemy DropItem],
        %i[RPG EquipItem],
        %i[RPG Event],
        %i[RPG Event Page],
        %i[RPG Event Page Condition],
        %i[RPG Event Page Graphic],
        %i[RPG Item],
        %i[RPG Map],
        %i[RPG Map Encounter],
        %i[RPG MapInfo],
        %i[RPG ME],
        %i[RPG MoveCommand],
        %i[RPG MoveRoute],
        %i[RPG SE],
        %i[RPG Skill],
        %i[RPG State],
        %i[RPG System Terms],
        %i[RPG System TestBattler],
        %i[RPG System Vehicle],
        %i[RPG System Words],
        %i[RPG Tileset],
        %i[RPG Troop],
        %i[RPG Troop Member],
        %i[RPG Troop Page],
        %i[RPG Troop Page Condition],
        %i[RPG UsableItem],
        %i[RPG UsableItem Damage],
        %i[RPG UsableItem Effect],
        %i[RPG Weapon],
        # Script classes serialized in save game files
        [:Game_ActionResult],
        [:Game_Actor],
        [:Game_Actors],
        [:Game_BaseItem],
        [:Game_BattleAction],
        [:Game_CommonEvent],
        [:Game_Enemy],
        [:Game_Event],
        [:Game_Follower],
        [:Game_Followers],
        [:Game_Interpreter],
        [:Game_Map],
        [:Game_Message],
        [:Game_Party],
        [:Game_Picture],
        [:Game_Pictures],
        [:Game_Player],
        [:Game_System],
        [:Game_Timer],
        [:Game_Troop],
        [:Game_Screen],
        [:Game_Vehicle],
        [:Interpreter]
    ].each { |symbol_array| process(Object, *symbol_array) }

    def self.setup_classes(version)
        # change version_id to fixed number
        reset_method(
            RPG::System,
            :reduce_string,
            ->(string) do
                return nil if string.nil?

                stripped = string.strip
                stripped.empty? ? nil : stripped
            end
        )

        # These magic numbers should be different. If they are the same, the saved version
        # of the map in save files will be used instead of any updated version of the map
        reset_method(
            RPG::System,
            :map_version,
            ->(_ignored) { 12_345_678 }
        )

        reset_method(
            Game_System,
            :map_version,
            ->(_ignored) { 87_654_321 }
        )

        # Game_Interpreter is marshalled differently in VX Ace
        if version == :ace
            reset_method(Game_Interpreter, :marshal_dump, -> { @data })
            reset_method(
                Game_Interpreter,
                :marshal_load,
                ->(obj) { @data = obj }
            )
        else
            remove_defined_method(Game_Interpreter, :marshal_dump)
            remove_defined_method(Game_Interpreter, :marshal_load)
        end

        reset_method(
            RPG::EventCommand,
            :clean,
            -> { @parameters[0].rstrip! if @code == 401 }
        )

        reset_const(
            RPG::EventCommand,
            :MOVE_LIST_CODE,
            version == :xp ? 209 : 205
        )

        BasicCoder.ivars_methods_set(version)
    end

    class Game_Switches
        include RGSS::BasicCoder
    end

    class Game_Variables
        include RGSS::BasicCoder
    end

    class Game_SelfSwitches
        include RGSS::BasicCoder
    end

    class Game_System
        include RGSS::BasicCoder
    end

    require 'RGSS/serialize'
end
