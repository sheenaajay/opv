# frozen_string_literal: true

require 'spec_helper'
require 'pry'

ensure_module_defined('Puppet::Provider::CheckHttp')
require 'puppet/provider/check_http/check_http'

RSpec.describe Puppet::Provider::CheckHttp::CheckHttp do
  subject(:provider) { described_class.new }
  subject(:retriable) { described_class.new }

  let(:context) { instance_double('Puppet::ResourceApi::BaseContext', 'context') }

  let(:should_uri) { 'abc.test.net' }
  let(:uri) { instance_double('URI', 'uri') }
  let(:should_hash) { { name: 'foo', url: should_uri, ensure: 'present',expected_statuses: [200], body_matcher: /Google/, request_timeout: 30, retries: 3, backoff: 1, exponential_backoff_base:2, max_backoff:40, timeout:60 } }
  let(:is_hash) { { name: 'foos', url: should_uri, ensure: 'present',expected_statuses: [200], body_matcher: /Google/, request_timeout: 30, retries: 3, backoff: 1, exponential_backoff_base:2, max_backoff:40, timeout:60 } }
  let(:base_interval) {}
  let(:proc) { instance_double('Proc', 'proc') }
  let(:do_this_on_each_retry) { instance_double('Proc', 'do_this_on_each_retry') }
  let(:exception) {}
  let(:try) {}
  let(:elapsed_time) {}
  let(:next_interval) {}
  let(:response) {}
  let(:retriable) { instance_double('Retriable', 'retriable') }
  let(:net_http) { instance_double('Net::HTTP', 'net_http') }

  describe 'get(context)' do
    it 'processes resources' do
      expect(provider.get(context)).to eq []
    end
  end

  describe 'insync?(context, name, attribute_name, is_hash, should_hash) without Retry' do
    it 'processes resources' do
      allow(context).to receive(:debug)
      allow(URI).to receive(should_uri).and_return uri
      expect(context).to receive(:debug).with('Checking whether foo is up-to-date')
      expect(context).to receive(:processing).with("abc.test.net", {}, {}, {:message=>"checking http"})
      expect(provider.insync?(context, 'foo', 'foo', is_hash, should_hash)).to be(nil)
    end
  end
end
