require_relative 'test_helper'

class ClientTest < Test::Unit::TestCase
  def setup
    @client = Wasd::Client.new(
      domain: "example.com",
      resolver_config: {nameserver_port: [["127.0.0.1", 53534]]}
    )
    @service = Wasd::Service.new("test", "tcp", "example.com")
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
      instance, [Wasd::Endpoint.new("woop.example.com", 49153, 0)],
      {1 => {"hello" => "there", "this" => "is=fun"},
       2 => {"second" => "version", "gosh" => "wow"}})

    with_test_dns_server do
      assert_equal expected, instance.resolve(@client)
    end
  end

  def test_service_resolution
    expected = Wasd::ResolvedService.new(@service, [
      Wasd::Endpoint.new("onlyone.example.com", 8001, 0)
    ])

    with_test_dns_server do
      assert_equal expected, @service.resolve(@client)
    end
  end
end
