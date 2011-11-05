class << Examples
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

  define_method :cramp_example do
    class SynchronyController < Cramp::Action
      use_fiber_pool

      def start
        page = EventMachine::HttpRequest.new("http://m.onkey.org").get
        render page.response
        finish
      end
    end
  end

  define_method :normal_style_example do
    result = do_some_io
    puts result
  end

  define_method :cps_example do
    do_some_io do |result|
      puts result
    end
  end
end

