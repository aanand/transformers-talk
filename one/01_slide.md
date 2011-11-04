!SLIDE
.notes What does this code return?
    @@@ ruby
    x = 1
    y = 2

    x + y

    # => ?

!SLIDE
.notes It returns 3.
    @@@ ruby
    x = 1
    y = 2

    x + y

    # => 3

!SLIDE
.notes What does this code return?
    @@@ ruby
    x <- 1
    y <- 2

    x + y

    # => ?

!SLIDE
.notes Well actually, I mean THIS code. What does this code return? Is it even valid?
    @@@ ruby
    Sequence.run do
      x <- 1
      y <- 2

      x + y
    end

    # => ?

!SLIDE
.notes It returns 3. How does it do that?
    @@@ ruby
    Sequence.run do
      x <- 1
      y <- 2

      x + y
    end

    # => 3

!SLIDE
.notes This is a magic trick in three parts.

!SLIDE
.notes First, let's pretend we wrote it like this.
    @@@ ruby
    Sequence.instance_eval do
      bind 1 do |x|
        bind 2 do |y|
          x + y
        end
      end
    end

!SLIDE
.notes Second, let's implement that mysterious 'bind' method. As you can see, it just calls the block you give it with the object you give it as an argument.
    @@@ ruby
    module Sequence
      class << self
        def bind(obj, &fn)
          fn.call(obj)
        end
      end
    end

!SLIDE
.notes Now the imaginary, not-the-actual-code code does what we want.
    @@@ ruby
    Sequence.instance_eval do
      bind 1 do |x|
        bind 2 do |y|
          x + y
        end
      end
    end

    # => 3

!SLIDE
.notes So how do we get the original code to work? We need to turn this into this.
    @@@ ruby
    Sequence.run do
      x <- 1
      y <- 2

      x + y
    end

    Sequence.instance_eval do
      bind 1 do |x|
        bind 2 do |y|
          x + y
        end
      end
    end

!SLIDE
.notes First, let's cleanly separate concerns and do it in a separate module. Transformer needs to implement the 'run' method, which will somehow turn the first block of code into the second.
    @@@ ruby
    module Sequence
      class << self
        include Transformer

        def bind(obj, &fn)
          fn.call(obj)
        end
      end
    end

!SLIDE
.notes The 'run' method calls a method to transform the block and then instance_evals it in the original block's lexical scope (that's what the second argument to eval does). Alright, but where's the definition of 'transform'?
    @@@ ruby
    module Transformer
      def run(&block)
        eval(ruby_for(block),
          block.binding).call
      end

      def ruby_for(block)
        %{
          #{self.name}.instance_eval {
            #{transform(block)}
          }
        }
      end
    end

!SLIDE
.notes Here it is. Wait, what? Ruby2Ruby? Rewriter?? block.to_sexp???????
    @@@ ruby
    def transform(block)
      Ruby2Ruby.new.process(
        Rewriter.new.process(block.to_sexp))
    end

!SLIDE
.notes Let me introduce my friends.

!SLIDE
.notes First up, Sourcify.

# gem install sourcify #

!SLIDE
.notes Sourcify provides many useful methods, but the one we're interested in is block.to_sexp. It parses a block's source and returns an abstract syntax tree.
    @@@ ruby
    proc { x + y }.to_sexp

!SLIDE
.notes That line returns this, which is called an S-expression.
    @@@ ruby
    proc { x + y }.to_sexp

    s(:iter,
      s(:call, nil, :proc, s(:arglist)),
      nil,
      s(:call,
        s(:call, nil, :x, s(:arglist)),
        :+,
        s(:arglist,
          s(:call, nil, :y, s(:arglist)))))

!SLIDE
.notes Let's remove the s-es and commas though. Anyway, now that we have a way of getting at the syntax of a block, we can transform it.
    @@@ ruby
    proc { x + y }.to_sexp

    (:iter
      (:call nil :proc (:arglist))
      nil
      (:call
        (:call nil :x (:arglist))
        :+
        (:arglist
          (:call nil :y (:arglist)))))

!SLIDE
.notes Here's what you get when you call .to_sexp on our code block.
    @@@ ruby
    (:block
      (:call
        (:call nil :x (:arglist))
        :<
        (:arglist
          (:call (:lit 1) :-@ (:arglist))))
      (:call
        (:call nil :y (:arglist))
        :<
        (:arglist
          (:call (:lit 2) :-@ (:arglist))))
      (:call
        (:call nil :x (:arglist))
        :+
        (:arglist
          (:call nil :y (:arglist)))))

!SLIDE
.notes And now you can see my trick. `x <- 1` is actually `x < (-1)`.
    @@@ ruby
    x <- 1
    # is actually
    x < (-1)

    (:call nil :x (:arglist))
    :<
    (:arglist
      (:call (:lit 1) :-@ (:arglist))))

!SLIDE
.notes So. In order to transform this into this...
    @@@ ruby
    Sequence.run do
      x <- 1
      y <- 2

      x + y
    end

    Sequence.instance_eval do
      bind 1 do |x|
        bind 2 do |y|
          x + y
        end
      end
    end

!SLIDE tiny-code
.notes ...we do this.
    @@@ ruby
    class Rewriter
      def process(exp)
        if exp[3].is_a?(Sexp) and exp[3][0] == :block
          iter, call, nil_val, block = exp.shift, exp.shift, exp.shift, exp.shift
          s(iter, call, nil_val, *rewrite_assignments(block[1..-1]))
        else
          exp
        end
      end

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

!SLIDE small-code
.notes Ha ha ha. No, seriously. Here's the output. OK, but how do we turn it back into Ruby?
    @@@ ruby
    Rewriter.new.process(block.to_sexp)

    (:iter
      (:call nil :proc (:arglist))
      nil
      (:iter
        (:call nil :bind (:arglist (:lit 1)))
        (:lasgn :x)
        (:iter
          (:call nil :bind (:arglist (:lit 2)))
          (:lasgn :y)
          (:call
            (:call nil :x (:arglist))
            :+
            (:arglist
              (:call nil :y (:arglist)))))))

!SLIDE
.notes If you install sourcify, you get Ruby2Ruby for free. (It's a dependency.)
# Ruby2Ruby #

!SLIDE
.notes Ruby2Ruby converts S-expressions into strings of code.
    @@@ ruby
    Ruby2Ruby.new.process(
      s(:call, nil, :puts,
        s(:arglist, s(:lit, "Hello World"))))

    # => 'puts("Hello World")'

!SLIDE small-code
.notes If we run Ruby2Ruby on that S-expression we got just now, we get this.
    @@@ ruby
    Ruby2Ruby.new.process(
      DoNotation::Rewriter.new.process( block.to_sexp))

    "proc { bind(1) { |x| bind(2) { |y| (x + y) } } }"

!SLIDE small-code
.notes So if we run 'ruby_for' on our block, we get exactly what we wanted.
    @@@ ruby
    Sequence.ruby_for(proc do
      x <- 1
      y <- 2

      x + y
    end)

    Sequence.instance_eval {
      proc {
        bind(1) { |x|
          bind(2) { |y|
            (x + y)
          }
        }
      }
    }

!SLIDE
.notes And we're there.
    @@@ ruby
    Sequence.run do
      x <- 1
      y <- 2

      x + y
    end

    # => 3

!SLIDE
.notes So what have we achieved? Well, we've managed to implement something Ruby gives us out of the box - variable assignment - in the most complex, bizarre way possible. Why on earth would you want to do that?
# What is this? #

!SLIDE
.notes Let's revisit the definition of 'bind'. It's pretty simple. It just calls the function with the object as its argument.
    @@@ ruby
    module Sequence
      class << self
        include Transformer

        def bind(obj, &fn)
          fn.call(obj)
        end
      end
    end

!SLIDE
.notes Actually, I'm a bit worried about this code. What if obj is nil? Let's add a check for that.
    @@@ ruby
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

!SLIDE
.notes Normal behaviour is preserved, of course.
    @@@ ruby
    NilCheck.run do
      x <- 1
      y <- 2

      x + y
    end

    # => 3

!SLIDE
.notes What if we set y to nil?
    @@@ ruby
    NilCheck.run do
      x <- 1
      y <- nil

      x + y
    end

    # => ?

!SLIDE
.notes We get nil. 'x + y' is never called.
    @@@ ruby
    NilCheck.run do
      x <- 1
      y <- nil

      x + y
    end

    # => nil

!SLIDE
.notes Even if the code keeps going, execution stops.
    @@@ ruby
    NilCheck.run do
      x <- 1
      y <- nil
      z <- x + y

      raise "I MUST NEVER RUN"
    end

    # => nil

!SLIDE
.notes If you don't see how this might be useful, here's a simple example.
    @@@ ruby
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

!SLIDE
.notes Let's go further. What do you think this returns?
    @@@ ruby
    Search.run do
      x <- ["first", "second"]
      y <- ["once", "twice"]

      ["#{x} cousin #{y} removed"]
    end

!SLIDE
.notes That's right.
    @@@ ruby
    ["first cousin once removed",
     "first cousin twice removed",
     "second cousin once removed",
     "second cousin twice removed"]

!SLIDE
.notes Here's how.
    @@@ ruby
    module Search
      class << self
        include Transformer

        def bind(array, &fn)
          array.map(&fn).inject([], :+)
        end
      end
    end

!SLIDE
.notes Let's add some numbers.
    @@@ ruby
    Search.run do
      x <- [1, 2, 3]
      y <- [10, 20, 30]

      [x+y]
    end

    [11, 21, 31,
     12, 22, 32,
     13, 23, 33]

!SLIDE
.notes Now let's define a strange-looking method on Search. What does it do?
    @@@ ruby
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

!SLIDE
.notes It prunes the search tree. How on earth did that work? I'll leave that as an exercise for the reader. I barely understand it myself.
    @@@ ruby
    require 'prime'

    Search.run do
      x <- [1, 2, 3]
      y <- [10, 20, 30]

      make_sure (x+y).prime?

      [x+y]
    end

    # => [11, 31, 13, 23]

!SLIDE
.notes I'm going to speed up now. What do you think this does?
    @@@ ruby
    Distribution.run do
      x <- rand(6)

      result(x+1)
    end.play

!SLIDE
.notes It enumerates the possible outcomes of a die roll and their probabilities.
    @@@ ruby
    [[1, 0.16666666666666666],
     [2, 0.16666666666666666],
     [3, 0.16666666666666666],
     [4, 0.16666666666666666],
     [5, 0.16666666666666666],
     [6, 0.16666666666666666]]

!SLIDE
.notes Let's roll two dice and add the numbers.
    @@@ ruby
    Distribution.run do
      x <- rand(6)
      y <- rand(6)

      result(x+1 + y+1)
    end.play

!SLIDE
.notes Get it? The most likely outcome is 7.
    @@@ ruby
    [[2, 0.027777777777777776],
     [3, 0.05555555555555555],
     [4, 0.08333333333333333],
     [5, 0.1111111111111111],
     [6, 0.1388888888888889],
     [7, 0.16666666666666669],
     [8, 0.1388888888888889],
     [9, 0.1111111111111111],
     [10, 0.08333333333333333],
     [11, 0.05555555555555555],
     [12, 0.027777777777777776]]

!SLIDE small-code
.notes One more. Do you like this code?
    @@@ ruby
    DB.connect('localhost', 'root', 'secret') do |db|
      db.table('people') do |table|
        table.insert(name: "Alice") do |row|
          row.id
        end
      end
    end

!SLIDE small-code
.notes How about this?
    @@@ ruby
    Callback.run do
      db    <- wrap(DB).connect('localhost', 'root', 'secret')
      table <- db.table('people')
      row   <- table.insert(name: 'Alice')

      row.id
    end

!SLIDE
# What is this? #

!SLIDE
# A generalised framework for composing operations. #

!SLIDE
.notes We have all these different ways of composing operations. All these different definitions of a left-pointing arrow. And really, a better name for Sequence would be...

<ul>
  <li>Sequence</li>
  <li>NilCheck</li>
  <li>Search</li>
  <li>Distribution</li>
  <li>Callback</li>
  <li>...</li>
</ul>

!SLIDE
<ul class="faded">
  <li class="highlight">All the code you’ve ever written</li>
  <li>NilCheck</li>
  <li>Search</li>
  <li>Distribution</li>
  <li>Callback</li>
  <li>...</li>
</ul>

!SLIDE
# What’s imperative programming? #

!SLIDE
# A special case. #

!SLIDE
# A pattern. #

!SLIDE
# Thanks. #

!SLIDE
# Oh, wait. #

!SLIDE small-code
.notes We just turned some nested callbacks into flat, sequential code.
    @@@ ruby
    DB.connect('localhost', 'root', 'secret') do |db|
      db.table('people') do |table|
        table.insert(name: "Alice") do |row|
          row.id
        end
      end
    end

    Callback.run do
      db    <- wrap(DB).connect('localhost', 'root', 'secret')
      table <- db.table('people')
      row   <- table.insert(name: 'Alice')

      row.id
    end

!SLIDE small-code
.notes Isn't that what that Goliath thing does?
    @@@ ruby
    class GoogleProxy < Goliath::API
      def response(env)
        http = EM::HttpRequest.new("http://google.com").get

        [200,
         {'X-Goliath' => 'Proxy','Content-Type' => 'text/html'},
         http.response]
      end
    end

!SLIDE small-code
.notes And that Cramp whatsit?
    @@@ ruby
    class SynchronyController < Cramp::Action
      use_fiber_pool

      def start
        page = EventMachine::HttpRequest.new("http://m.onkey.org").get
        render page.response
        finish
      end
    end

!SLIDE
.notes These frameworks use a feature of Ruby 1.9 called Fibers to make callback-driven code look sequential.
# Fibers #

!SLIDE small-code
.notes This style of code is called "continuation-passing style", or "CPS".
# Continuation-Passing Style #

    @@@ ruby
    DB.connect('localhost', 'root', 'secret') do |db|
      db.table('people') do |table|
        table.insert(name: "Alice") do |row|
          row.id
        end
      end
    end

!SLIDE incremental
# Fibers #

- Jump to another bit of code and back
- Actually just a restricted form of...

!SLIDE incremental
# callcc #

- “CALL with Current Continuation"
- Like Fibers, but more powerful
- Save the entire call stack and resume it any time, as many times as you like
- Will do your fucking head in

!SLIDE
.notes Here's our original Sequence code, one more time.
    @@@ ruby
    Sequence.run do
      x <- 1
      y <- 2

      x + y
    end

!SLIDE
.notes We need to change a couple of things. First, the block takes a single argument, 'o'. Second, we need a new operator. Let's call it the 'bellows'. Can you see what it is, really?
    @@@ ruby
    Sequence.run do |o|
      x =o< 1
      y =o< 2

      x + y
    end

!SLIDE
.notes It's assigning the variables, like in normal Ruby code. But it's assigning them to 'o < 1', 'o < 2' etc.
    @@@ ruby
    Sequence.run do |o|
      x = (o < 1)
      y = (o < 2)

      x + y
    end

!SLIDE
.notes In fact, 'o' is a Proc, and the less-than operator is just an alias of 'call'.
    @@@ ruby
    Sequence.run do |o|
      x = o.call(1)
      y = o.call(2)

      x + y
    end

!SLIDE tiny-code
.notes Next, we need to redefine Transformer#run. We can do away with Ruby2Ruby, block.to_sexp et al. This is all we need.
    @@@ ruby
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

!SLIDE
.notes Sequence now works as before.
    @@@ ruby
    Sequence.run do |o|
      x =o< 1
      y =o< 2

      x + y
    end

    # => 3

!SLIDE
.notes As does NilCheck.
    @@@ ruby
    NilCheck.run do |o|
      x =o< 1
      y =o< nil

      x + y
    end

    # => nil

!SLIDE
.notes As does Search. You get the idea.
    @@@ ruby
    Search.run do |o|
      x =o< ["first", "second"]
      y =o< ["once", "twice"]

      ["#{x} cousin #{y} removed"]
    end

    ["first cousin once removed",
     "first cousin twice removed",
     "second cousin once removed",
     "second cousin twice removed"]

!SLIDE
# You can implement Transformer by rewriting syntax. #

!SLIDE
# You can implement Transformer by messing with control flow. #

!SLIDE
# The result is the same. #

