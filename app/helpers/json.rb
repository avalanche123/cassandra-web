# encoding: utf-8

class App
  module Helpers
    module JSON
      def json_dump(object)
        ::JSON.dump(object_hash(object))
      end

      private

      def object_hash(object)
        case object
        when ::Cassandra::Host
          host_hash(object)
        when ::Cassandra::Keyspace
          keyspace_hash(object)
        when ::Cassandra::Result
          result_hash(object)
        when ::Exception
          exception_hash(object)
        when ::Hash
          hash = ::Hash.new
          object.each do |key, value|
            hash[key] = object_hash(value)
          end
          hash
        when ::Enumerable
          object.map(&method(:object_hash))
        when ::String
          begin
            object.encode('utf-8')
          rescue Encoding::UndefinedConversionError
            '0x' + object.unpack('H*').first
          end
        when nil
          'null'
        else
          object.to_s
        end
      end

      def object_key(object)
        case object
        when ::Cassandra::Host
          object.ip
        when ::Cassandra::Keyspace
          object.name
        else
          raise "unsupported object #{object.inspect}"
        end
      end

      def host_hash(host)
        {
          :ip              => host.ip,
          :id              => host.id,
          :datacenter      => host.datacenter,
          :rack            => host.rack,
          :release_version => host.release_version,
          :status          => host.status
        }
      end

      def keyspace_hash(keyspace)
        {
          :name   => keyspace.name,
          :cql    => keyspace.to_cql,
          :tables => keyspace.tables.map do |table|
            {
              :name    => table.name,
              :cql     => table.to_cql,
              :columns => table.columns.map do |column|
                {
                  :name  => column.name,
                  :type  => column_type_hash(column.type),
                  :order => column.order
                }
              end
            }
          end
        }
      end

      def column_type_hash(column_type)
        case column_type
        when Array
          column_type.first.to_s + '<' + column_type.slice(1..-1).join(', ') + '>'
        else
          column_type
        end
      end

      def result_hash(result)
        {
          :rows    => result.map(&method(:object_hash)),
          :columns => columns_hash(result),
          :info    => execution_info_hash(result.execution_info),
        }
      end

      def columns_hash(rows)
        return [] if rows.empty?
        rows.first.keys
      end

      def execution_info_hash(execution_info)
        {
          :keyspace    => execution_info.keyspace,
          :statement   => statement_hash(execution_info.statement),
          :options     => execution_options_hash(execution_info.options),
          :hosts       => execution_info.hosts.map(&method(:host_hash)),
          :consistency => execution_info.consistency,
          :retries     => execution_info.retries,
          :trace       => execution_info.trace && execution_trace_hash(execution_info.trace)
        }
      end

      def statement_hash(statement)
        {
          :cql => statement.cql
        }
      end

      def execution_options_hash(execution_options)
        {
          :consistency        => execution_options.consistency,
          :serial_consistency => execution_options.serial_consistency,
          :page_size          => execution_options.page_size,
          :timeout            => execution_options.timeout,
          :trace              => execution_options.trace?
        }
      end

      def execution_trace_hash(execution_trace)
        {
          :id          => execution_trace.id,
          :coordinator => execution_trace.coordinator,
          :duration    => execution_trace.duration,
          :parameters  => execution_trace.parameters,
          :request     => execution_trace.request,
          :started_at  => execution_trace.started_at,
          :events      => execution_trace.events.map(&method(:execution_trace_event_hash))
        }
      end

      def execution_trace_event_hash(execution_trace_event)
        {
          :id             => execution_trace_event.id,
          :activity       => execution_trace_event.activity,
          :source         => execution_trace_event.source,
          :source_elapsed => execution_trace_event.source_elapsed,
          :thread         => execution_trace_event.thread
        }
      end

      def error_hash(error)
        case error
        when ::Cassandra::Errors::NoHostsAvailable
          no_hosts_available_error_hash(error)
        when ::Cassandra::Errors::ReadTimeoutError
          read_timeout_error_hash(error)
        when ::Cassandra::Errors::WriteTimeoutError
          write_timeout_error_hash(error)
        when ::Cassandra::Errors::UnavailableError
          unavailable_error_hash(error)
        when ::Cassandra::Errors::UnpreparedError
          unprepared_error_hash(error)
        when ::Cassandra::Errors::AlreadyExistsError
          already_exists_error_hash(error)
        when ::Cassandra::Errors::ExecutionError, ::Cassandra::Errors::ValidationError
          execution_error_hash(error)
        else
          exception_hash(error)
        end
      end

      def exception_hash(error)
        {
          :class   => error.class.name,
          :message => error.message,
          :trace   => error.backtrace
        }
      end

      def execution_error_hash(error)
        hash = exception_hash(error)
        hash[:statement] = statement_hash(error.statement)
        hash
      end

      def already_exists_error_hash(error)
        hash = execution_error_hash(error)
        hash[:keyspace] = error.keyspace
        hash[:table]    = error.table
        hash
      end

      def unprepared_error_hash(error)
        hash = execution_error_hash(error)
        hash[:id] = error.id
        hash
      end

      def read_timeout_error_hash(error)
        hash = execution_error_hash(error)
        hash[:retrieved]   = error.retrieved?
        hash[:consistency] = error.consistency
        hash[:required]    = error.required
        hash[:received]    = error.received
        hash
      end

      def write_timeout_error_hash(error)
        hash = execution_error_hash(error)
        hash[:type]        = error.type
        hash[:consistency] = error.consistency
        hash[:required]    = error.required
        hash[:received]    = error.received
        hash
      end

      def unavailable_error_hash(error)
        hash = execution_error_hash(error)
        hash[:consistency] = error.consistency
        hash[:required]    = error.required
        hash[:alive]       = error.alive
        hash
      end

      def no_hosts_available_error_hash(error)
        hash = exception_hash(error)
        errors = []

        error.errors.each do |host, e|
          errors << {
            :host  => host_hash(host),
            :error => error_hash(e)
          }
        end

        hash[:errors] = errors
        hash
      end
    end
  end
end
