# setup

require 'bundler'
Bundler.setup

require 'do_notation'

module Examples; end

class << Examples
  define_method :assignment do
    x = 1
    y = 2

    x + y
  end

  define_method :sequence do
    Sequence.run do
      x <- 1
      y <- 2

      x + y
    end
  end

  define_method :sequence_transformed do
    Sequence.instance_eval do
      bind 1 do |x|
        bind 2 do |y|
          x + y
        end
      end
    end
  end

  define_method :sequence_definition_bind do
    module Sequence
      class << self
        def bind(obj, &fn)
          fn.call(obj)
        end
      end
    end
  end

  define_method :sequence_definition_full do
    module Sequence
      class << self
        include Transformer

        def bind(obj, &fn)
          fn.call(obj)
        end
      end
    end
  end

  define_method :transformer_definition_run do
    module Transformer
      def run(&block)
        eval(ruby_for(block), block.binding).call
      end

      def ruby_for(block)
        "#{self.name}.instance_eval { #{transform(block)} }"
      end
    end
  end

  define_method :transformer_definition_transform do
    def transform(block)
      Ruby2Ruby.new.process(
        Rewriter.new.process(block.to_sexp))
    end
  end

  define_method :block_to_sexp do
    pp proc { x + y }.to_sexp; nil
  end

  define_method :block_to_sexp_lisp_style do
    puts DoNotation.pp(proc { x + y }.to_sexp)
  end

  define_method :our_code_to_sexp do
    block = proc do
      x <- 1
      y <- 2

      x + y
    end

    puts DoNotation.pp(block.to_sexp.last)
  end

  define_method :our_code_transformed_to_sexp do
    block = proc do
      x <- 1
      y <- 2

      x + y
    end

    puts DoNotation.pp(DoNotation::Rewriter.new.process(block.to_sexp))
  end

  define_method :rewriter_definition_process do
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

  define_method :rewriter_definition_rewrite_assignments do
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

  define_method :ruby2ruby_example do
    Ruby2Ruby.new.process s(:call, nil, :puts, s(:arglist, s(:lit, "Hello World")))
  end

  define_method :ruby2ruby_on_our_transformed_block do
    block = proc do
      x <- 1
      y <- 2

      x + y
    end

    Ruby2Ruby.new.process(DoNotation::Rewriter.new.process(block.to_sexp))
  end

  define_method :pretend_ruby_for_command do
    Sequence.ruby_for(proc do
      x <- 1
      y <- 2

      x + y
    end)
  end

  define_method :nil_check_definition_full do
    module NilCheck
      class << self
        include Transformer

        def bind(obj, &fn)
          if obj.nil?
            nil
          else
            fn.call(obj)
          end
        end
      end
    end
  end

  define_method :nil_check_example_1 do
    NilCheck.run do
      x <- 1
      y <- 2

      x + y
    end
  end

  define_method :nil_check_example_2 do
    NilCheck.run do
      x <- 1
      y <- nil

      x + y
    end
  end

  define_method :nil_check_example_3 do
    NilCheck.run do
      x <- 1
      y <- nil
      z <- x + y

      raise "I MUST NEVER RUN"
    end
  end

  define_method :nil_check_example_4 do
    def grandparent_name(person_id)
      NilCheck.run do
        person      <- Person.get(person_id)
        parent      <- person.parent
        grandparent <- parent.parent

        grandparent.name
      end
    end

    # Family tree: Alice -> Bob -> Charles

    grandparent_name("Zac")     #=> nil
    grandparent_name("Alice")   #=> nil
    grandparent_name("Bob")     #=> nil
    grandparent_name("Charles") #=> "Alice"
  end

  define_method :search_definition do
    module Search
      class << self
        include Transformer

        def bind(array, &fn)
          array.map(&fn).inject([], :+)
        end
      end
    end
  end

  define_method :array_example_1 do
    Search.run do
      x <- ["first", "second"]
      y <- ["once", "twice"]

      ["#{x} cousin #{y} removed"]
    end
  end

  define_method :array_example_2 do
    Search.run do
      x <- [1, 2, 3]
      y <- [10, 20, 30]

      [x+y]
    end
  end

  define_method :make_sure_definition do
    module Search
      class << self
        def make_sure(condition)
          if condition
            [[]]
          else
            []
          end
        end
      end
    end
  end

  define_method :array_example_3 do
    require 'prime'

    Search.run do
      x <- [1, 2, 3]
      y <- [10, 20, 30]

      make_sure (x+y).prime?

      [x+y]
    end
  end

=begin
  # To make these work, run:
  require 'do_notation/monads/simulations'
  class Distribution
    class << self
      alias_method :result, :unit
    end
  end
=end

  define_method :distribution_example_1 do
    Distribution.run do
      x <- rand(6)

      result(x+1)
    end.play
  end

  define_method :distribution_example_2 do
    Distribution.run do
      x <- rand(6)
      y <- rand(6)

      result(x+1 + y+1)
    end.play
  end

  define_method :callback_definition do
    Object.send(:remove_const, :Callback) rescue nil

    class Callback < Struct.new(:obj, :method, :args)
      class << self
        include Transformer

        def wrap(obj)
          new(obj, nil, nil)
        end

        def bind(wrapper, &fn)
          wrapper.obj.send(wrapper.method, *wrapper.args) do |result|
            fn.call(wrap(result))
          end
        end
      end

      def method_missing(m, *args)
        Callback.new(obj, m, args)
      end
    end
  end

  define_method :db_definition do
    class DB
      def self.connect(*args)
        yield new
      end

      def table(name)
        yield Table.new
      end
    end

    class Table
      def insert(attrs)
        yield Row.new
      end
    end

    class Row
      def id
        1
      end
    end
  end

  define_method :callback_example_before do
    DB.connect('localhost', 'root', 'secret') do |db|
      db.table('people') do |table|
        table.insert(name: "Alice") do |row|
          row.id
        end
      end
    end
  end

  define_method :callback_example_after do
    Callback.run do
      db    <- wrap(DB).connect('localhost', 'root', 'secret')
      table <- db.table('people')
      row   <- table.insert(name: 'Alice')

      row.id
    end
  end

  define_method :goliath_example do
    require 'goliath'
    require 'em-synchrony/em-http'

    class GoogleProxy < Goliath::API
      def response(env)
        http = EM::HttpRequest.new("http://google.com").get
        [200, {'X-Goliath' => 'Proxy','Content-Type' => 'text/html'}, http.response]
      end
    end
  end

  define_method :sequence_example_callcc do
    Sequence.run do |o|
      x =o< 1
      y =o< 2

      x + y
    end
  end

  define_method :callcc_example do
    require 'continuation'

    def get_number
      callcc do |cc|
        cc.call(3)
      end
    end

    get_number
  end

  define_method :nil_check_example_callcc do
    NilCheck.run do |o|
      x =o< 1
      y =o< nil

      x + y
    end
  end

  define_method :search_example_callcc do
    Search.run do |o|
      x =o< ["first", "second"]
      y =o< ["once", "twice"]

      ["#{x} cousin #{y} removed"]
    end
  end

  define_method :transformer_definition_callcc do
    require 'continuation'

    module Transformer
      def run(&fn)
        callcc do |the_end|
          stack = [the_end]

          next_continuation = proc do |arg|
            stack.pop.call(arg)
          end

          o = proc do |mval|
            callcc do |rtn|
              res = bind(mval) do |value|
                callcc do |cc|
                  stack.push(cc)
                  rtn.call(value)
                end
              end

              next_continuation.call(res)
            end
          end

          (class << o; self; end).class_eval { alias_method :<, :call }

          next_continuation.call(instance_exec(o, &fn))
        end
      end
    end
  end
end

