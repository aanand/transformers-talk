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

