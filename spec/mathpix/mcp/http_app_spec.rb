# frozen_string_literal: true

require 'mathpix/mcp/http_app'

RSpec.describe Mathpix::MCP::HttpApp do
  describe '.build' do
    it 'raises when no bearer token is configured' do
      expect { described_class.build(token: nil) }.to raise_error(/MATHPIX_MCP_TOKEN/)
    end
  end

  describe Mathpix::MCP::HttpApp::BearerAuth do
    subject(:app) { described_class.new(downstream, token: 'secret') }

    let(:downstream) { ->(_env) { [200, { 'content-type' => 'text/plain' }, ['ok']] } }

    it 'passes the request through with a valid bearer token' do
      status, _headers, body = app.call('HTTP_AUTHORIZATION' => 'Bearer secret')

      expect(status).to eq(200)
      expect(body).to eq(['ok'])
    end

    it 'returns 401 when the Authorization header is missing' do
      status, = app.call({})

      expect(status).to eq(401)
    end

    it 'returns 401 for an incorrect token' do
      status, = app.call('HTTP_AUTHORIZATION' => 'Bearer wrong')

      expect(status).to eq(401)
    end
  end
end
