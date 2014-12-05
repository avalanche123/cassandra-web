# encoding: utf-8

class App
  module Helpers
    module SSE
      class Streamer
        include Helpers::JSON

        def initialize(out)
          @out = out
        end

        def host_found(host)
          @out << "event: host_found\ndata: #{json_dump(host)}\n\n"
        end

        def host_up(host)
          @out << "event: host_up\ndata: #{json_dump(host)}\n\n"
        end

        def host_down(host)
          @out << "event: host_down\ndata: #{json_dump(host)}\n\n"
        end

        def host_lost(host)
          @out << "event: host_lost\ndata: #{json_dump(host)}\n\n"
        end

        def keyspace_created(keyspace)
          @out << "event: keyspace_created\ndata: #{json_dump(keyspace)}\n\n"
        end

        def keyspace_changed(keyspace)
          @out << "event: keyspace_changed\ndata: #{json_dump(keyspace)}\n\n"
        end

        def keyspace_dropped(keyspace)
          @out << "event: keyspace_dropped\ndata: #{json_dump(keyspace)}\n\n"
        end
      end

      def stream_events(out)
        listener  = Streamer.new(out)
        heartbeat = EM.add_periodic_timer(2) { out << "\n" }

        cluster.register(listener)

        out.callback do
          heartbeat.cancel
          cluster.unregister(listener)
        end

        out.errback do |error|
          heartbeat.cancel
          cluster.unregister(listener)
        end
      end
    end
  end
end
