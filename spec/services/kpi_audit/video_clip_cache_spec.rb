# frozen_string_literal: true

require_relative '../../rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe KpiAudit::VideoClipCache do
  around do |example|
    Dir.mktmpdir('kpi-video-cache') do |dir|
      @cache_root = Pathname(dir)
      example.run
    end
  end

  it 'publishes only after validation and removes temporary files' do
    cache = described_class.new(root: @cache_root, validator: ->(path) { path.read == 'valid' })
    result = cache.fetch('clip') { |path| path.write('valid') }

    expect(result).to exist
    expect(@cache_root.glob('*.part-*')).to be_empty
  end

  it 'cleans up after failed generation' do
    cache = described_class.new(root: @cache_root, validator: ->(_path) { true })
    expect do
      cache.fetch('clip') do |path|
        path.write('partial')
        raise 'download failed'
      end
    end.to raise_error('download failed')

    expect(@cache_root.glob('*.mp4')).to be_empty
    expect(@cache_root.glob('*.part-*')).to be_empty
  end

  it 'does not publish invalid artifacts' do
    cache = described_class.new(root: @cache_root, validator: ->(_path) { false })
    expect { cache.fetch('clip') { |path| path.write('truncated') } }
      .to raise_error('invalid video cache artifact')

    expect(@cache_root.glob('*.mp4')).to be_empty
  end

  it 'reuses a published artifact without generating again' do
    cache = described_class.new(root: @cache_root, validator: ->(_path) { true })
    cache.fetch('clip') { |path| path.write('valid') }

    expect { |block| cache.fetch('clip', &block) }.not_to yield_control
  end

  it 'never treats a part file as a cache hit' do
    cache = described_class.new(root: @cache_root, validator: ->(_path) { true })
    FileUtils.mkdir_p(@cache_root)
    partial = @cache_root.join('orphan.part-123')
    partial.write('partial')

    expect(cache.fetch('clip') { |path| path.write('valid') }).to exist
    expect(@cache_root.glob('*.part-*')).to include(partial)
  end
end
# rubocop:enable Metrics/BlockLength
