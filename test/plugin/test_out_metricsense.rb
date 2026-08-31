require 'test-unit'
require 'fluent/test'
require 'fluent/test/driver/output'
require 'fluent/test/helpers'
require 'fluent/plugin/out_metricsense'

class MetricsenseOutputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  class TestBackend < Fluent::MetricSenseOutput::Backend
    Fluent::MetricSenseOutput.register_backend('test', self)

    @@data = []

    def self.data
      @@data
    end

    def self.clear
      @@data = []
    end

    def write(data)
      @@data << data
    end
  end

  CONFIG = %Q[
    backend test
  ]

  def setup
    Fluent::Test.setup
    TestBackend.clear
  end

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::MetricSenseOutput).configure(conf)
  end

  def test_emit
    now = Time.now.to_i
    d = create_driver
    d.run(default_tag: 'test') do
      d.feed(now, {'value' => 1, 'user_id' => 23456, 'path' => '/auth/login'})
    end

    t = now / 60 * 60
    assert_true TestBackend.data.length > 0
    TestBackend.data.each do |written|
      assert_equal ['test', t, 1, 'user_id', 23456, 0], written.shift
      assert_equal ['test', t, 1, 'path', "/auth/login", 0], written.shift
      assert_equal ['test', t, 1, nil, nil, 0], written.shift
    end
  end

  def test_skip_broken_chunk
    d = create_driver

    corrupt_chunk = Object.new
    def corrupt_chunk.msgpack_each
      yield ['test', 'not_a_number', 1, {}, 0]
    end

    assert_nothing_raised do
      d.instance.write(corrupt_chunk)
    end
    assert_equal [[]], TestBackend.data
  end

  def test_reloadable
    d = create_driver
    assert_true d.instance.reloadable_plugin?
  end
end