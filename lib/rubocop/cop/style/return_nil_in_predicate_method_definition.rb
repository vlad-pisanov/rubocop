# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # Checks if `return` or `return nil` is used in predicate method definitions,
      # or if `nil` is implicitly returned from a predicate.
      #
      # @safety
      #   Autocorrection is marked as unsafe because the change of the return value
      #   from `nil` to `false` could potentially lead to incompatibility issues.
      #
      # @example
      #   # bad
      #   def foo?
      #     return if condition
      #
      #     do_something?
      #   end
      #
      #   # bad
      #   def foo?
      #     return nil if condition
      #
      #     do_something?
      #   end
      #
      #   # good
      #   def foo?
      #     return false if condition
      #
      #     do_something?
      #   end
      #
      # @example
      #   # bad
      #   def foo?
      #     nil
      #   end
      #
      #   # good
      #   def foo?
      #     false
      #   end
      #
      # @example
      #   # bad
      #   def foo?
      #     bar?
      #   rescue
      #     nil
      #   end
      #
      #   # good
      #   def foo?
      #     bar?
      #   rescue
      #     false
      #   end
      #
      # @example AllowedMethods: ['foo?']
      #   # good
      #   def foo?
      #     return if condition
      #
      #     do_something?
      #   end
      #
      # @example AllowedPatterns: [/foo/]
      #   # good
      #   def foo?
      #     return if condition
      #
      #     do_something?
      #   end
      #
      class ReturnNilInPredicateMethodDefinition < Base
        extend AutoCorrector
        include AllowedMethods
        include AllowedPattern

        MSG = 'Return `false` instead of `nil` in predicate methods.'

        # @!method return_nil?(node)
        def_node_matcher :return_nil?, <<~PATTERN
          {(return) (return (nil))}
        PATTERN

        def on_def(node)
          return unless node.predicate_method?
          return if allowed_method?(node.method_name) || matches_allowed_pattern?(node.method_name)
          return unless (body = node.body)

          body.each_descendant(:return) do |return_node|
            register_offense(return_node, 'return false') if return_nil?(return_node)
          end

          terminal_nil_nodes(body).each do |nil_node|
            register_offense(nil_node, 'false')
          end
        end
        alias on_defs on_def

        private

        def terminal_nil_nodes_in_begin(node)
          terminal_nil_nodes(node.children.last)
        end

        def terminal_nil_nodes_in_ensure(node)
          terminal_nil_nodes(node.node_parts[0])
        end

        def terminal_nil_nodes_in_rescue(node)
          terminal_nil_nodes(node.body) + node.branches.flat_map { |body| terminal_nil_nodes(body) }
        end

        def terminal_nil_nodes(node)
          return [] unless node

          case node.type
          when :nil then [node]
          when :begin then terminal_nil_nodes_in_begin(node)
          when :ensure then terminal_nil_nodes_in_ensure(node)
          when :rescue then terminal_nil_nodes_in_rescue(node)
          else []
          end
        end

        def register_offense(offense_node, replacement)
          add_offense(offense_node) do |corrector|
            corrector.replace(offense_node, replacement)
          end
        end
      end
    end
  end
end
