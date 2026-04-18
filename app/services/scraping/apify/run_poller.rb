module Scraping
  module Apify
    class RunPoller
      DEFAULT_POLL_INTERVAL_SECONDS = 5
      DEFAULT_MAX_DURATION_SECONDS  = 240

      TERMINAL_SUCCESS_STATUSES = %w[SUCCEEDED].freeze
      TERMINAL_FAILURE_STATUSES = %w[FAILED TIMED-OUT ABORTED].freeze

      def initialize(client:, run_id:,
                     poll_interval: DEFAULT_POLL_INTERVAL_SECONDS,
                     max_duration: DEFAULT_MAX_DURATION_SECONDS,
                     sleeper: ->(s) { sleep s })
        @client = client
        @run_id = run_id
        @poll_interval = poll_interval
        @max_duration = max_duration
        @sleeper = sleeper
      end

      def wait_for_completion!
        started_at = monotonic_now
        loop do
          run = client.get_run(run_id)
          status = run["status"]

          return run if TERMINAL_SUCCESS_STATUSES.include?(status)

          if TERMINAL_FAILURE_STATUSES.include?(status)
            raise Scraping::RunFailedError,
                  "apify run #{run_id} ended with status=#{status}"
          end

          if monotonic_now - started_at > max_duration
            client.abort_run(run_id)
            raise Scraping::TimeoutError,
                  "apify run #{run_id} exceeded #{max_duration}s (still #{status})"
          end

          sleeper.call(poll_interval)
        end
      end

      private

      attr_reader :client, :run_id, :poll_interval, :max_duration, :sleeper

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
