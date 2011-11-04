# setup

require 'bundler'
Bundler.setup
require 'do_notation'

module Examples
  module_function

  def assignment
    x = 1
    y = 2

    x + y
  end

  def sequence
    Sequence.run do
      x <- 1
      y <- 2

      x + y
    end
  end

  def sequence_transformed
    Sequence.instance_eval do
      bind 1 do |x|
        bind 2 do |y|
          x + y
        end
      end
    end
  end

  def sequence_definition_bind
    module Sequence
      class << self
        def bind(obj, &fn)
          fn.call(obj)
        end
      end
    end
  end

  def sequence_definition_full
    module Sequence
      class << self
        include Transformer

        def bind(obj, &fn)
          fn.call(obj)
        end
      end
    end
  end

  def transformer_definition_run
    module Transformer
      def run(&block)
        eval(ruby_for(block), block.binding).call
      end

      def ruby_for(block)
        "#{self.name}.instance_eval { #{transform(block)} }"
      end
    end
  end

  def transformer_definition_transform
    module Transformer
      def transform(block)
        Ruby2Ruby.new.process(Rewriter.new.process(block.to_sexp))
      end
    end
  end

  def block_to_sexp
    pp proc { x + y }.to_sexp; nil
  end

  def block_to_sexp_lisp_style
    puts DoNotation.pp(proc { x + y }.to_sexp)
  end

  def our_code_to_sexp
    block = proc do
      x <- 1
      y <- 2

      x + y
    end

    puts DoNotation.pp(block.to_sexp.last)
  end

  def our_code_transformed_to_sexp
    block = proc do
      x <- 1
      y <- 2

      x + y
    end

    puts DoNotation.pp(DoNotation::Rewriter.new.process(block.to_sexp))
  end

  def rewriter_definition_process
    class Rewriter
      def process(exp)
        if exp[3].is_a?(Sexp) and exp[3][0] == :block
          iter, call, nil_val, block = exp.shift, exp.shift, exp.shift, exp.shift
          s(iter, call, nil_val, *rewrite_assignments(block[1..-1]))
        else
          exp
        end
      end
    end
  end

  def rewriter_definition_rewrite_assignments
    class Rewriter
      def rewrite_assignments exp
        return [] if exp.empty?

        head = exp.shift


        if head[0] == :call and head[1] and head[1][0] == :call and head[2] == :< and head[3][0] == :arglist and head[3][1][2] == :-@
          var_name = head[1][2]
          expression = head[3][1][1]

          body = rewrite_assignments(exp)

          if body.first.is_a? Symbol
            body = [s(*body)]
          end

          [s(:iter,
            s(:call, nil, :bind, s(:arglist, expression)),
            s(:lasgn, var_name),
            *body)]
        elsif exp.empty?
          [head]
        else
          [s(:iter,
            s(:call, nil, :bind_const, s(:arglist, head)),
            nil,
            *rewrite_assignments(exp))]
        end
      end
    end
  end

  def ruby2ruby_on_our_transformed_block
    block = proc do
      x <- 1
      y <- 2

      x + y
    end

    Ruby2Ruby.new.process(DoNotation::Rewriter.new.process(block.to_sexp))
  end

  def pretend_ruby_for_command
    Sequence.ruby_for(proc do
      x <- 1
      y <- 2

      x + y
    end)
  end
end

