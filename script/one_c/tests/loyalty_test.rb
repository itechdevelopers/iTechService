require 'bundler/setup'
require 'active_support/all'
require 'action_view'
require 'hamlit'
require 'hamlit/rails_template'
require 'pundit'
require 'minitest/autorun'
require_relative '../../../app/policies/application_policy'
require_relative '../../../app/policies/one_c_function_policy'
require_relative '../../../app/services/one_c_glass_loyalty'
I18n.enforce_available_locales = false

module Rails
  def self.root; Pathname.new(File.expand_path('../../..', __dir__)); end
  def self.application; OpenStruct.new(secrets: OpenStruct.new(secret_key_base: 'test-secret')); end
end
class MemoryRedis
  attr_accessor :data
  def initialize; @data = {}; end
  def get(k); @data[k]; end
  def set(k,v, nx: false, ex: nil); return false if nx && @data.key?(k); @data[k]=v; 'OK'; end
  def del(*keys); keys.each { |k| @data.delete(k) }; end
  def incr(k); @data[k]=@data.fetch(k,0).to_i+1; end
  def expire(*); true; end
  def exists?(k); @data.key?(k); end
end
module Sidekiq
  class << self; attr_accessor :store; end
  def self.redis; yield store; end
end
class OneCGlassLoyaltyJob
  class << self; attr_accessor :calls; end
  def self.perform_later(key); self.calls << key; end
end
class GlassView < ActionView::Base
  def one_c_functions_path; '/one_c_functions'; end
  def glass_search_one_c_functions_path; '/one_c_functions/glass_search'; end
  def glass_one_c_functions_path; '/one_c_functions/glass'; end
  def protect_against_forgery?; false; end
  def policy(*); OpenStruct.new(article?: false); end
end
class LoyaltyTest < Minitest::Test
  def setup
    Sidekiq.store = MemoryRedis.new; OneCGlassLoyaltyJob.calls = []
  end
  def test_all_authenticated_roles_can_read_glass_but_article_permissions_stay
    user=Object.new
    def user.superadmin?; false; end
    def user.able_to?(*); false; end
    policy=OneCFunctionPolicy.new(user,:one_c_function)
    assert policy.index?
    assert policy.glass?
    assert policy.glass_search?
    refute policy.article?
    assert_raises(Pundit::NotAuthorizedError) { OneCFunctionPolicy.new(nil,:one_c_function) }
  end
  def test_shared_cache_and_no_phone_in_job_arguments
    key=OneCGlassLoyalty.start('+7 (999) 123-45-67',1)
    assert_match(/\A[0-9a-f]{64}\z/,key)
    assert_equal key,OneCGlassLoyalty.start('89991234567',2)
    assert_equal [key],OneCGlassLoyaltyJob.calls
    prefix=OneCGlassLoyalty::PREFIX
    Sidekiq.store.del("#{prefix}:pending:#{key}")
    Sidekiq.store.set("#{prefix}:result:#{key}",{cached_at:Time.now.to_i,data:{complete:true}}.to_json)
    OneCGlassLoyalty.start('79991234567',3)
    assert_equal 1,OneCGlassLoyaltyJob.calls.size
    refute OneCGlassLoyalty.read(key)[:stale]
  end
  def test_stale_result_is_preserved_with_failure
    key='a'*64;prefix=OneCGlassLoyalty::PREFIX
    Sidekiq.store.set("#{prefix}:result:#{key}",{cached_at:Time.now.to_i-100,data:{complete:true}}.to_json)
    Sidekiq.store.set("#{prefix}:error:#{key}",'Ошибка обновления')
    result=OneCGlassLoyalty.read(key)
    assert result[:stale];assert result[:result];assert_equal 'Ошибка обновления',result[:error]
  end
  def test_throttle_and_invalid_input
    10.times { OneCGlassLoyalty.start('79991234567',1) }
    assert_raises(OneCGlassLoyalty::InvalidPhone) { OneCGlassLoyalty.start('79991234567',1) }
    assert_raises(OneCGlassLoyalty::InvalidPhone) { OneCGlassLoyalty.start("79991234567'",2) }
  end
  def test_view_escapes_names_and_renders_progress_and_pending
    data={'program'=>'Каждое 5-е стекло','gift_price'=>'1','threshold'=>5,'read_at'=>'2026-10-15T12:00:00+10:00','cards'=>[
      {'name'=>'<script>alert(1)</script>','status'=>'Действует','warnings'=>[],'reconciled'=>true,'progress'=>4,'until_gift'=>1,
       'receipt_quantity'=>'4','net_quantity'=>'4','promotional_quantity'=>'0','history'=>[],'resets'=>[],'raw_balance'=>'-1'}]}
    view=GlassView.new([File.expand_path('../../../app/views',__dir__)],{lookup:{result:data,pending:true}})
    html=view.render(template:'one_c_functions/glass')
    assert_includes html,'Следующее стекло'
    assert_includes html,'&lt;script&gt;'
    refute_includes html,'<script>alert(1)</script>'
    assert_includes html,'window.location.reload'
    File.write(ENV['GLASS_PREVIEW_OUTPUT'],html) if ENV['GLASS_PREVIEW_OUTPUT']
    html=GlassView.new([File.expand_path('../../../app/views',__dir__)],{}).render(template:'one_c_functions/index')
    assert_includes html,'Каждое 5-е стекло'
    refute_includes html,'Артикул или код товара'
  end
end
