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

  it 'uses a unique temporary mp4 beside the final path' do
    cache = described_class.new(root: @cache_root, validator: ->(_path) { true })
    observed = nil
    final_path = @cache_root.join("#{Digest::SHA256.hexdigest('clip')}.mp4")

    cache.fetch('clip') do |path|
      observed = path
      path.write('valid')
    end

    expect(observed.extname).to eq('.mp4')
    expect(observed.basename.to_s).to include('.part-')
    expect(observed).not_to eq(final_path)
    expect(observed.dirname).to eq(final_path.dirname)
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
