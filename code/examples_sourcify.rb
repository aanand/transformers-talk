require 'bundler'
Bundler.setup

require File.expand_path('../transformer_sourcify', __FILE__)
require File.expand_path('../transformers', __FILE__)
require 'pp'

def pp(obj)
  puts PP.pp(obj, "").gsub(/\bs\b|,/, "").gsub(/^(\s+)/, '\1\1')
end

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

  define_method :block_to_sexp do
    PP.pp proc { x + y }.to_sexp; nil
  end

  define_method :block_to_sexp_lisp_style do
    pp proc { x + y }.to_sexp
  end

  block = proc do
    x <- 1
    y <- 2

    x + y
  end

  define_method :our_code_to_sexp do
    pp block.to_sexp
  end

  define_method :our_code_transformed_to_sexp do
    pp Rewriter.new.process(block.to_sexp)
  end

  define_method :ruby2ruby_example do
    Ruby2Ruby.new.process s(:call, nil, :puts, s(:arglist, s(:lit, "Hello World")))
  end

  define_method :ruby2ruby_on_our_transformed_block do
    puts Ruby2Ruby.new.process(Rewriter.new.process(block.to_sexp))
  end

  define_method :pretend_ruby_for_command do
    puts Sequence.ruby_for(block)
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
        person      <- Person.find_by_id(person_id)
        parent      <- person.parent
        grandparent <- parent.parent

        grandparent.name
      end
    end

    alice   = Person.create(name: "Alice")
    bob     = Person.create(name: "Bob",     parent: alice)
    charles = Person.create(name: "Charles", parent: bob)

    grandparent_name(999)        #=> nil
    grandparent_name(alice.id)   #=> nil
    grandparent_name(bob.id)     #=> nil
    grandparent_name(charles.id) #=> "Alice"
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
end

