module Sequence
  class << self
    include Transformer

    def bind(obj, &fn)
      fn.call(obj)
    end
  end
end

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

module Search
  class << self
    include Transformer

    def bind(array, &fn)
      array.map(&fn).inject([], :+)
    end
  end
end

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

