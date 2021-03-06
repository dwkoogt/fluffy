# > bundle exec ruby examples/demo_oneoff.rb
$: << File.expand_path('../examples', File.dirname(__FILE__))
require 'pika_que'

require 'dev_worker'

PikaQue.logger.level = ::Logger::DEBUG

begin
  pro = DevWorker.new(concurrency: 2)
  pro.start
rescue => e
  puts e
  puts e.backtrace.join("\n")
end

sleep 3

300.times do |i|
  DevWorker.enqueue({ msg: "hello world #{i}" })
end

sleep 3

pro.stop

puts "bye"

exit 1
