require 'fluffy/worker'
require 'fluffy/codecs/rails'

module Fluffy
  class Rails < ::Rails::Engine

    config.before_configuration do
      if ::Rails::VERSION::MAJOR < 5 && defined?(::ActiveRecord)
        Fluffy.middleware do |chain|
          require 'fluffy/middleware/active_record'
          chain.add Fluffy::Middleware::ActiveRecord
        end
      end
    end

    config.before_initialize do
      require 'active_job/queue_adapters/fluffy_adapter'
    end

    config.after_initialize do
      config_file = Rails.root.join('config').join('fluffy.yml')
      if File.exist? config_file
        FLUFFY_CONFIG = YAML.load_file(config_file)
      else
        FLUFFY_CONFIG = { "processors" => [{ "workers" => [{ "queue" => ActiveJob::Base.queue_name }, { "queue" => ActionMailer::DeliveryJob.queue_name}] }] }
      end

      workers_dir = Rails.root.join('app').join('workers')
      if Dir.exist? workers_dir
        worker_files = Dir.glob(workers_dir.join('*.rb'))
      else
        worker_files = []
      end

      # TODO options, etc

      FLUFFY_CONFIG['processors'].each do |processor|
        workers = []
        processor['workers'].each do |worker|
          queue = worker['queue']
          worker_name = worker['worker'] || "#{queue.classify}Worker"
          Object.const_set(worker_name, Class.new do
              include Fluffy::Worker
              from_queue queue
              config codec: Fluffy::Codecs::RAILS

              def perform(msg)
                ActiveJob::Base.execute msg
                ack!
              end
            end
          ) unless worker_files.detect{ |w| w =~ /#{worker_name.snakecase}/ }
          workers << worker_name
        end
        proc_args = { workers: workers }
        proc_args[:processor] = processor['processor'] if processor['processor']
        Fluffy.config.add_processor(proc_args)
      end
    end

  end
end
