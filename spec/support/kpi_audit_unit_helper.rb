# frozen_string_literal: true

# rubocop:disable Naming/VariableNumber

require 'spec_helper'
require 'active_support/all'
Time.zone = 'Asia/Vladivostok'
$LOAD_PATH.unshift(File.expand_path('../../app/services', __dir__))
require_relative '../../app/services/kpi_audit/configuration'
require_relative '../../app/services/kpi_audit/visit_reconstructor'
require_relative '../../app/services/kpi_audit/scorecard'
require_relative '../../app/services/kpi_audit/detector'

KPI_AUDIT_TEST_CONFIG = KpiAudit::Configuration.new(
  rules_version: 2,
  visit: { medium_gap_minutes: 30 }, burst: { window_minutes: 10, minimum_count: 5 },
  repeated_client: { minimum_visits: 4 }, repeated_device: { minimum_visits: 2 },
  output_threshold: 25, strict_output_threshold: 1,
  scoring: { visit_multiple_kpi: 12, visit_many_kpi: 20, confirmed_ticket: 13,
             burst_5: 15, burst_10: 25, burst_20: 35, short_intervals: 10,
             identical_operations: 10, repeated_client: 10, repeated_device: 22,
             end_of_period: 25, no_monetary_result: 15,
             unusual_time: 5, user_mismatch: 0 },
  family_caps: { visit: 28, burst: 45, repetition: 30, period: 25, economics: 20, diagnostics: 0 },
  combinations: { end_period_without_result: 17, burst_repeated_entity: 8 },
  confidence: {
    weights: { shared_ticket: 35, singleton_ticket: 15, waiting_client: 10, historical_called: 10,
               service_job_relation: 20, item: 20, serial: 15, imei: 15, audit_metadata: 15,
               request_uuid: 10, employee: 5, client: 3, time_proximity: 5 },
    family_caps: { queue_identity: 50, device_identity: 30, audit_identity: 20, context: 10 }
  }, video: { pre_roll_seconds: 15, post_roll_seconds: 15, max_preview_duration_seconds: 1800,
              clip_ttl_seconds: 3600, link_ttl_seconds: 604_800 }
)
# rubocop:enable Naming/VariableNumber
