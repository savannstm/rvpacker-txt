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
        raise 'Size mismatch loading Table from data' unless items == @data.length && @x * @y * @z == items
    end

    def _dump(*_ignored)
        [@dim, @x, @y, @z, @x * @y * @z, *@data].pack('L5 S*')
    end

    def self._load(bytes)
        new(bytes)
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
        new(bytes)
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
        new(bytes)
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
        new(bytes)
    end
end

# Fuck using an array with set, that's just straight dumb and not efficient
class IndexSet
    def initialize
        @hash = Hash.new
    end

    def add(item)
        return if @hash.include?(item)
        @hash[item] = @hash.size
        @hash
    end

    def include?(item)
        @hash.include?(item)
    end

    def each(&block)
        @hash.each_key(&block)
    end

    def to_a
        @hash.dup
    end

    def join(delimiter = '')
        @hash.keys.join(delimiter)
    end

    def length
        @hash.size
    end

    def empty?
        @hash.empty?
    end
end

module RPG
    class Map
        attr_accessor :display_name, :events
    end

    class Event
        attr_accessor :pages

        class Page
            attr_accessor :list
        end
    end

    class EventCommand
        attr_accessor :code, :parameters
    end

    class Actor
        attr_accessor :name, :nickname, :description, :note
    end

    class Armor
        attr_accessor :name, :description, :note
    end

    class Class
        attr_accessor :name, :description, :note
    end

    class Enemy
        attr_accessor :name, :description, :note
    end

    class Item
        attr_accessor :name, :description, :note
    end

    class Skill
        attr_accessor :name, :description, :note
    end

    class State
        attr_accessor :name, :description, :note
    end

    class Weapon
        attr_accessor :name, :description, :note
    end

    class CommonEvent
        attr_accessor :pages, :list
    end

    class Troop
        attr_accessor :pages

        class Page
            attr_accessor :list
        end
    end

    class System
        attr_accessor :elements, :skill_types, :weapon_types, :armor_types, :currency_unit, :terms, :words, :game_title
    end
end

module RGSS
    # creates an empty class in a potentially nested scope
    def self.process(root, name, *args)
        if args.empty?
            root.const_set(name, Class.new) unless root.const_defined?(name, false)
        else
            process(root.const_get(name), *args)
        end
    end

    classes_nested_array = [
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
        %i[RPG EventCommand],
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
        %i[RPG System],
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
        %i[RPG Weapon]
    ].freeze

    classes_nested_array.each do |symbol_array|
        process(Object, *symbol_array)
    end
end
