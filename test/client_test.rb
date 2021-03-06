require_relative 'test_helper'

class ClientTest < Test::Unit::TestCase
  def setup
    @client = Wasd::Client.new(
      domain: "wasd.test",
      resolver_config: {nameserver_port: [["127.0.0.1", 53534]]}
    )
    @service = @client.service(name: "test")
  end

  def test_service_instances
    expected = [
      Wasd::Instance.new(@service, "Woop"),
      Wasd::Instance.new(@service, "Hello There"),
    ]
    with_test_dns_server do
      assert_equal expected, @client.service_instances(name: 'test')
    end
  end

  def test_instance_resolution
    instance = Wasd::Instance.new(@service, "Woop")
    expected = Wasd::ResolvedInstance.new(
      instance, [Wasd::Endpoint.new("woop.wasd.test", 49153, 0)],
      {1 => {"hello" => "there", "this" => "is=fun"},
       2 => {"second" => "version", "gosh" => "wow"}})

    with_test_dns_server do
      assert_equal expected, instance.resolve(@client)
    end
  end

  def test_service_resolution
    expected = Wasd::ResolvedService.new(@service, [
      Wasd::Endpoint.new("onlyone.wasd.test", 8001, 0)
    ])

    with_test_dns_server do
      assert_equal expected, @service.resolve(@client)
    end
  end

  def test_service_subtype_resolution
    expected = [
      Wasd::Instance.new(@service.with(subtype: 'cheese'), "Woop"),
    ]

    with_test_dns_server do
      instances = @client.service_instances(name: 'test', subtype: 'cheese')
      assert_equal expected, instances

      endpoints = instances.first.resolve.endpoints
      assert_equal 1, endpoints.size
      assert_equal "woop.wasd.test", endpoints.first.host
    end
  end

  def test_instance_resolution_failure
    with_test_dns_server do
      assert_raises Wasd::NoEndpointsFound do
        @client.service_instance(description: "asdf", name: "qwer").resolve
      end
    end
  end

  def test_service_resolution_failure
    with_test_dns_server do
      assert_raises Wasd::NoEndpointsFound do
        @client.service(name: "qwer").resolve
      end
    end
  end

  def test_endpoint_http_uri
    tests = [
      [Wasd::Endpoint.new('wasd.test', 443), URI("https://wasd.test")],
      [Wasd::Endpoint.new('wasd.test', 80), URI("http://wasd.test")],
      [Wasd::Endpoint.new('wasd.test', 3000), URI("http://wasd.test:3000")],
    ]

    tests.each do |endpoint, uri|
      assert_equal endpoint.to_http_uri, uri
    end

    tests = [
      [Wasd::Endpoint.new('wasd.test', 443), URI("https://wasd.test")],
      [Wasd::Endpoint.new('wasd.test', 80), URI("http://wasd.test")],
      [Wasd::Endpoint.new('wasd.test', 3000), URI("https://wasd.test:3000")],
    ]

    tests.each do |endpoint, uri|
      assert_equal endpoint.to_http_uri(default_to_https: true), uri
    end

  end
end
