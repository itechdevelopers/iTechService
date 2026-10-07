# frozen_string_literal: true

require 'open3'
require 'timeout'

# Fixed read-only operation; the installed OData connector owns credentials and HTTP.
class OneCProductCost
  class Unavailable < StandardError; end
  class InvalidArguments < StandardError; end

  def self.call(arguments)
    Open3.popen3(ENV.fetch('AIS_MCP_PYTHON', 'python3'),
                 Rails.root.join('script/mcp/product_cost.py').to_s, pgroup: true) do |stdin, stdout, _stderr, process|
      execute(stdin, stdout, process, arguments)
    end
  rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError, KeyError, Timeout::Error
    raise Unavailable
  end

  # Keep timeout, bounded output and process cleanup together at the resource boundary.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.execute(stdin, stdout, process, arguments)
    Timeout.timeout(45) do
      stdin.write(arguments.to_json)
      stdin.close
      output = stdout.read(1_000_001)
      raise Unavailable if output.bytesize > 1_000_000

      result = JSON.parse(output)
      status = process.value.exitstatus
      raise InvalidArguments, result['error'] if status == 2
      raise Unavailable unless status&.zero?

      result
    end
  ensure
    unless process.join(0)
      begin
        Process.kill('KILL', -process.pid)
      rescue Errno::ESRCH
        # The process exited between the status check and kill.
      end
      process.join
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  private_class_method :execute
end
