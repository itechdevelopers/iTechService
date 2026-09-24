require 'bundler/setup'
require 'active_support/all'
require 'action_view'
require 'hamlit'
require 'hamlit/rails_template'
require 'minitest/autorun'
require 'pundit'
require_relative '../../app/services/activity_counts/period_counts'
require_relative '../../app/helpers/weekly_markup_dashboards_helper'
require_relative '../../app/policies/application_policy'
require_relative '../../app/policies/weekly_markup_dashboard_policy'
I18n.enforce_available_locales = false
I18n.backend.store_translations(:ru, date: {formats: {default: '%d.%m.%Y'}})
I18n.locale = :ru

class CountPreviewView < ActionView::Base
  include WeeklyMarkupDashboardsHelper
  def weekly_markup_dashboard_path; '/weekly_markup_dashboard'; end
  def activity_counts_weekly_markup_dashboard_path(**params)
    '/weekly_markup_dashboard/activity_counts?' + params.to_query
  end
  def protect_against_forgery?; false; end
end

class ActivityCountsViewTest < Minitest::Test
  def data
    days=(Date.new(2020,1,1)..Date.new(2026,9,23)).map do |day|
      quantity = day.year >= 2026 ? 120 : 100
      {date:day.iso8601,quantity:quantity,branches:[{id:'shop',name:'Магазин <script>alert(1)</script>',quantity:quantity}]}
    end
    ActivityCounts::PeriodCounts.new(days:days,today:Date.new(2026,9,24)).result.merge(
      metric:'receipts',title:'Продажи',years:(2021..2026).to_a,
      branch_names:{'shop'=>'Магазин <script>alert(1)</script>'},updated_at:Time.now,stale:false)
  end

  def test_real_haml_templates_render_counts_comparisons_and_escaped_labels
    payload=data
    view=CountPreviewView.new([File.expand_path('../../app/views',__dir__)], {activity_counts:payload})
    html=view.render(template:'weekly_markup_dashboards/activity_counts')
    assert_includes html,'Последние пять лет'
    assert_includes html,'+20,0%'
    assert_includes html,'&lt;script&gt;'
    refute_includes html,'<script>alert'
    tile=view.render(partial:'weekly_markup_dashboards/activity_tile',locals:{data:payload})
    assert_includes tile,'Пробитых чеков'
    assert_includes tile,'+20,0%'
    if ENV['ACTIVITY_PREVIEW_OUTPUT']
      css=File.read(File.expand_path('../../app/assets/stylesheets/weekly_markup_dashboard.scss',__dir__))
      require 'sass'
      compiled=Sass::Engine.new(css,syntax: :scss).render
      base='body{font-family:Arial,sans-serif;margin:30px;color:#263445;background:#f7f8fa}table{border-collapse:collapse;width:100%;background:white}th,td{padding:10px;border-bottom:1px solid #ddd;text-align:left}a{color:#2868a6}select,input{margin:8px;padding:7px}h3{margin-top:30px}.well{background:#e9eef4;padding:16px;margin-top:24px}.muted,small{color:#64748b}.weekly-markup-dashboard{max-width:1200px;margin:auto}'
      File.write(ENV['ACTIVITY_PREVIEW_OUTPUT'],"<!doctype html><meta charset='utf-8'><style>#{base}#{compiled}</style><p>Локальная проверка интерфейса · синтетические данные</p><div class='weekly-markup-widgets'>#{tile}</div>#{html}")
    end
  end

  def test_new_route_obeys_existing_superadmin_policy
    user=Struct.new(:allowed) { def superadmin?; allowed; end }
    assert WeeklyMarkupDashboardPolicy.new(user.new(true),:dashboard).activity_counts?
    refute WeeklyMarkupDashboardPolicy.new(user.new(false),:dashboard).activity_counts?
    assert_raises(Pundit::NotAuthorizedError) { WeeklyMarkupDashboardPolicy.new(nil,:dashboard) }
  end
end
