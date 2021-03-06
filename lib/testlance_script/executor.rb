require 'timeout'
require 'rufus-lua'
require_relative 'lua_initializer'
require_relative 'lua_helper'
require_relative 'errors'

module Testlance
  module Script
    class Executor
      include LuaHelper

      attr_reader :data

      SCRIPT_SIZE_LIMIT       = 1024.freeze
      SCRIPT_CLEAR_SIZE_LIMIT = 512.freeze
      MEMORY_USAGE_LIMIT      = 100.freeze

      LIBS = %w[base math]

      def initialize(data = {})
        @data = data
        @lua = Rufus::Lua::State.new(LIBS)
        @initializer = LuaInitializer.new(@lua, @data)

        initialize_globals
      end

      def reload(data = {})
        initialize data

        self
      end

      def run!(lua_script)
        safe_run! lua_script
      end

      private

      def safe_run!(lua_script)
        script_size = lua_script.length
        script_clear_size = lua_script.gsub(/\s/, '').length

        if script_size > SCRIPT_SIZE_LIMIT || script_clear_size > SCRIPT_CLEAR_SIZE_LIMIT
          raise ScriptSizeLimitError
        end

        result = @lua.eval lua_script

        if @lua.gc_count > MEMORY_USAGE_LIMIT
          raise MemoryLimitError
        end

        @lua.gc_collect!

        result
      end

      def initialize_globals
        init_constants_protect
      end

      def init_constants_protect
        @lua.eval read_lua_script 'globals_protect'
        @initializer.initialize_global_constants
        @lua.eval @data.map { |var_name, _| "protect(\"#{var_name}\")" }.join("\n")
      end
    end
  end
end