# frozen_string_literal: true

require 'open3'
require 'timeout'

class OneCArticleSearch
  class Unavailable < StandardError; end
  class InvalidArguments < StandardError; end

  def self.call(article)
    raise InvalidArguments, 'Введите артикул длиной от 1 до 128 символов.' if article.blank? || article.length > 128 || article.match?(/[[:cntrl:]]/)

    Open3.popen3(ENV.fetch('AIS_ONE_C_PYTHON', 'python3'), Rails.root.join('script/one_c/article_search.py').to_s,
                 pgroup: true) do |stdin, stdout, _stderr, process|
      begin
        Timeout.timeout(45) do
          stdin.write({ article: article }.to_json)
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
            # The process already exited.
          end
          process.join
        end
      end
    end
  rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError, Timeout::Error
    raise Unavailable
  end
end
