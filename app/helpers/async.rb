# encoding: utf-8

class App
  module Helpers
    module Async
      def defer(future)
        future.on_success do |result|
          env["async.callback"].call([
            200,
            {
              'Content-Type' => 'application/json'
            },
            [json_dump(result)]
          ])
        end

        future.on_failure do |error|
          status = case error
          when Cassandra::Errors::NoHostsAvailable
            503
          when Cassandra::Errors::AuthenticationError
            401
          when Cassandra::Errors::UnauthorizedError
            403
          when Cassandra::Errors::ExecutionError
            504
          when Cassandra::Error
            400
          when
            500
          end

          env["async.callback"].call([
            status,
            {
              'Content-Type' => 'application/json'
            },
            [json_dump(error)]
          ])
        end

        throw :async
      end
    end
  end
end
