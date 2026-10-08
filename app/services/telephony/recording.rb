# frozen_string_literal: true
require 'net/sftp'
module Telephony
  class Recording
    class Unavailable < StandardError; end
    def initialize(path)
      @path = path
    end
    def send_to(controller)
      root = ENV.fetch('TELEPHONY_RECORDING_ROOT', '/var/spool/asterisk/monitor')
      raise Unavailable unless @path.present? && @path.match?(%r{\A/[A-Za-z0-9_./-]+\.wav\z}) && !@path.split('/').include?('..') && File.expand_path(@path).start_with?(root.chomp('/') + '/')
      cache = Rails.root.join('tmp', 'audio_cache', Digest::SHA256.hexdigest(@path) + '.wav')
      unless File.exist?(cache)
        FileUtils.mkdir_p(cache.dirname)
        # Atomic cache write; only allow files from the known recording root.
        data = nil
        Net::SFTP.start(ENV.fetch('SFTP_HOST'), ENV.fetch('SFTP_USER'), password: ENV.fetch('SFTP_PASSWORD'), port: ENV.fetch('SFTP_PORT', '22').to_i, timeout: 10, non_interactive: true, host_key: %w[ssh-rsa], append_all_supported_algorithms: true) { |sftp| data = sftp.download!(@path) }
        require 'tempfile'
        Tempfile.create(['phone-call', '.wav'], cache.dirname.to_s) do |temp|
          temp.binmode; temp.write(data); temp.flush
          File.rename(temp.path, cache)
        end
      end
      size = File.size(cache)
      controller.response.headers['Accept-Ranges'] = 'bytes'
      range = controller.request.headers['Range']
      if range.present?
        match = /\Abytes=(\d+)-(\d*)\z/.match(range)
        return controller.head(:range_not_satisfiable) unless match
        first = match[1].to_i
        last = match[2].present? ? [match[2].to_i, size - 1].min : size - 1
        return controller.head(:range_not_satisfiable) if first > last || first >= size
        controller.response.headers['Content-Range'] = "bytes #{first}-#{last}/#{size}"
        controller.send_data IO.binread(cache, last - first + 1, first), type: 'audio/wav', status: 206, disposition: 'inline'
      else
        controller.send_file cache, type: 'audio/wav', disposition: 'inline'
      end
    rescue Net::SSH::Exception, Net::SFTP::StatusException, IOError, SystemCallError, KeyError
      raise Unavailable
    end
  end
end
