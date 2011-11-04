require 'bundler'
Bundler.setup

require File.expand_path('../transformer_callcc', __FILE__)
require File.expand_path('../transformers', __FILE__)

module Examples; end

class << Examples
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
end

