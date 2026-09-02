# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/hikvision/runtime_environment'

# rubocop:disable Metrics/BlockLength
RSpec.describe Hikvision::RuntimeEnvironment do
  let(:env) { {} }
  let(:runner) { instance_double('ShellRunner') }
  let(:status) { instance_double(Process::Status, success?: true) }
  let(:output) do
    "#{[
      'HIKVISION_HOST', 'host.example',
      'HIKVISION_USER', 'reader',
      'HIKVISION_PASSWORD', 'secret-value',
      'HIKVISION_RTSP_PORT', '17512',
      'UNRELATED', 'ignored'
    ].join("\0")}\0"
  end

  before do
    allow(runner).to receive(:call).and_return([output, '', status])
  end

  it 'imports only the whitelisted variables from a static login shell command' do
    described_class.new(env: env, runner: runner).import!

    expect(env).to include(
      'HIKVISION_HOST' => 'host.example',
      'HIKVISION_USER' => 'reader',
      'HIKVISION_PASSWORD' => 'secret-value',
      'HIKVISION_RTSP_PORT' => '17512'
    )
    expect(env).not_to have_key('UNRELATED')
    expect(runner).to have_received(:call).with('/bin/bash', '-lc', described_class::SHELL_COMMAND)
  end

  it 'does not overwrite variables already present' do
    env['HIKVISION_HOST'] = 'existing-host'

    described_class.new(env: env, runner: runner).import!

    expect(env['HIKVISION_HOST']).to eq('existing-host')
  end

  it 'does not invoke the shell when all variables are already present' do
    env.merge!('HIKVISION_HOST' => 'h', 'HIKVISION_USER' => 'u',
               'HIKVISION_PASSWORD' => 'p', 'HIKVISION_RTSP_PORT' => 'r')

    described_class.new(env: env, runner: runner).import!

    expect(runner).not_to have_received(:call)
  end

  it 'raises a safe error when a required variable is missing' do
    allow(runner).to receive(:call).and_return([
                                                 "HIKVISION_HOST\0host.example\0", '', status
                                               ])

    expect do
      described_class.new(env: env, runner: runner).import!
    end.to raise_error(Hikvision::Configuration::Error, /HIKVISION_USER/)
  end

  it 'does not expose a secret in command failure errors' do
    allow(runner).to receive(:call).and_return(['', 'secret-value', instance_double(Process::Status, success?: false)])

    expect do
      described_class.new(env: env, runner: runner).import!
    end.to raise_error(Hikvision::Configuration::Error, 'Unable to load Hikvision runtime environment')
  end
end
# rubocop:enable Metrics/BlockLength
