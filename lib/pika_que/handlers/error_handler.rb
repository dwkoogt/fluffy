module PikaQue
  module Handlers
    class ErrorHandler

      DEFAULT_ERROR_OPTS = {
        :error_prefix => 'pika-que'
      }.freeze
     
      def initialize(opts = {})
        @opts = PikaQue.config.merge(DEFAULT_ERROR_OPTS).merge(opts)
        @connection = @opts[:connection] || PikaQue.connection
        @channel = @connection.create_channel
        error_ex_name = error_q_name = "#{@opts[:error_prefix]}-error"
        if @opts[:queue]
          # handle deprecated options
          error_ex_name = @opts[:exchange]
          error_q_name = @opts[:queue]
        end
        @exchange = @channel.exchange(error_ex_name, type: :topic, durable: exchange_durable?)
        @queue = @channel.queue(error_q_name, durable: queue_durable?)
        @queue.bind(@exchange, routing_key: '#')
        @monitor = Monitor.new
      end

      def bind_queue(queue, routing_key)
      end

      def handle(response_code, channel, delivery_info, metadata, msg, error = nil)
        case response_code
        when :ack
          PikaQue.logger.debug "ErrorHandler acknowledge <#{msg}>"
          channel.acknowledge(delivery_info.delivery_tag, false)
        when :reject
          PikaQue.logger.debug "ErrorHandler reject <#{msg}>"
          channel.reject(delivery_info.delivery_tag, false)
        when :requeue
          PikaQue.logger.debug "ErrorHandler requeue <#{msg}>"
          channel.reject(delivery_info.delivery_tag, true)
        else
          PikaQue.logger.debug "ErrorHandler publishing <#{msg}> to [#{@queue.name}]"
          publish(delivery_info, msg)
          channel.acknowledge(delivery_info.delivery_tag, false)
        end
      end

      def close
        @channel.close unless @channel.closed?
      end

      private

      def queue_durable?
        @opts.fetch(:queue_options, {}).fetch(:durable, false)
      end

      def exchange_durable?
        @opts.fetch(:exchange_options, {}).fetch(:durable, false)
      end

      def publish(delivery_info, msg)
        @monitor.synchronize do
          @exchange.publish(msg, routing_key: delivery_info.routing_key)
        end
      end

    end    
  end
end
