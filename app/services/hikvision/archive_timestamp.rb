# frozen_string_literal: true

module Hikvision
  class ArchiveTimestamp
    ZONE = "Vladivostok"
    FORMAT = "%Y%m%dT%H%M%SZ"

    def self.call(time)
      raise ArgumentError, "time is required" if time.blank?

      time.in_time_zone(ZONE).strftime(FORMAT)
    end
  end
end
