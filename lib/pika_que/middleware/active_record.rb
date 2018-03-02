module PikaQue
  module Middleware
    class ActiveRecord

      def call(*args)
        yield
      ensure
        ::ActiveRecord::Base.clear_active_connections!
      end
      
    end
  end
end
