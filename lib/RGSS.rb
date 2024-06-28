# Copyright (c) 2013 Howard Jeng
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

require 'scanf'

class Table
    def initialize(bytes)
        @dim, @x, @y, @z, items, *@data = bytes.unpack('L5 S*')
        raise 'Size mismatch loading Table from data' unless items == @data.length
        return if @x * @y * @z == items

        raise 'Size mismatch loading Table from data'
    end

    MAX_ROW_LENGTH = 20

    def encode_with(coder)
        coder.style = Psych::Nodes::Mapping::BLOCK

        coder['dim'] = @dim
        coder['x'] = @x
        coder['y'] = @y
        coder['z'] = @z

        if (@x * @y * @z).positive?
            stride = if @x < 2
                         @y < 2 ? @z : @y
                     else
                         @x
                     end
            rows = @data.each_slice(stride).to_a
            if MAX_ROW_LENGTH != -1 && stride > MAX_ROW_LENGTH
                block_length = (stride + MAX_ROW_LENGTH - 1) / MAX_ROW_LENGTH
                row_length = (stride + block_length - 1) / block_length
                rows =
                    rows
                    .collect { |x| x.each_slice(row_length).to_a }
                    .flatten(1)
            end
            rows = rows.collect { |x| x.collect { |y| '%04x' % y }.join(' ') }
            coder['data'] = rows
        else
            coder['data'] = []
        end
    end

    def init_with(coder)
        @dim = coder['dim']
        @x = coder['x']
        @y = coder['y']
        @z = coder['z']
        @data =
            coder['data'].collect { |x| x.split(' ').collect(&:hex) }.flatten
        items = @x * @y * @z
        return if items == @data.length

        raise 'Size mismatch loading Table from YAML'
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
        return unless scope.instance_methods(false).include?(name)

        scope.send(:remove_method, name)
    end

    def self.reset_method(scope, name, method)
        remove_defined_method(scope, name)
        scope.send(:define_method, name, method)
    end

    def self.reset_const(scope, sym, value)
        scope.send(:remove_const, sym) if scope.const_defined?(sym)
        scope.send(:const_set, sym, value)
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

    def self.hash_to_array(hash)
        arr = []

        hash.each { |k, v| arr[k] = v }

        arr
    end

    require 'RGSS/BasicCoder'
    require 'RPG'

    # creates an empty class in a potentially nested scope
    def self.process(root, name, *args)
        if !args.empty?
            process(root.const_get(name), *args)
        else
            root.const_set(name, Class.new) unless root.const_defined?(name, false)
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
    ].each { |x| process(Object, *x) }

    def self.setup_system(_version, options)
        # convert variable and switch name arrays to a hash when serialized
        # if round_trip isn't set change version_id to fixed number
        if options[:round_trip]
            iso = ->(val) { val }
            reset_method(RPG::System, :reduce_string, iso)
            reset_method(RPG::System, :map_version, iso)
            reset_method(Game_System, :map_version, iso)
        else
            reset_method(
                RPG::System,
                :reduce_string,
                lambda do |str|
                    return nil if str.nil?

                    stripped = str.strip
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
        end
    end

    def self.setup_interpreter(version)
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
    end

    def self.setup_event_command(version, options)
        # format event commands to flow style for the event codes that aren't move commands
        if options[:round_trip]
            reset_method(RPG::EventCommand, :clean, -> {})
        else
            reset_method(
                RPG::EventCommand,
                :clean,
                -> { @parameters[0].rstrip! if @code == 401 }
            )
        end
        reset_const(
            RPG::EventCommand,
            :MOVE_LIST_CODE,
            version == :xp ? 209 : 205
        )
    end

    def self.setup_classes(version, options)
        setup_system(version, options)
        setup_interpreter(version)
        setup_event_command(version, options)
        BasicCoder.set_ivars_methods(version)
    end

    class Game_Switches
        include RGSS::BasicCoder

        def encode(_name, value)
            array_to_hash(value)
        end

        def decode(_name, value)
            hash_to_array(value)
        end
    end

    class Game_Variables
        include RGSS::BasicCoder

        def encode(_name, value)
            array_to_hash(value)
        end

        def decode(_name, value)
            hash_to_array(value)
        end
    end

    class Game_SelfSwitches
        include RGSS::BasicCoder

        def encode(_name, value)
            (
                Hash[
                    value.collect do |pair|
                        key, value = pair
                        next ['%03d %03d %s' % key, value]
                    end
                ]
            )
        end

        def decode(_name, value)
            (
                Hash[
                    value.collect do |pair|
                        key, value = pair
                        next [key.scanf('%d %d %s'), value]
                    end
                ]
            )
        end
    end

    class Game_System
        include RGSS::BasicCoder

        def encode(name, value)
            return map_version(value) if name == 'version_id'

            value
        end
    end

    require 'RGSS/serialize'
end
