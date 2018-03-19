$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
end

require 'pika_que'

# autoload
PikaQue::Handlers::RetryHandler
