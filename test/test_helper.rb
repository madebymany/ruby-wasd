require 'test/unit'

require 'wasd'

class Test::Unit::TestCase
  def with_test_dns_server
    cmd = File.expand_path("../bin/dnsmasq-#{RUBY_PLATFORM}", __FILE__)
    unless File.exist?(cmd)
      puts "warning: trying to find dnsmasq in PATH as it isn't in here for your platform, '#{RUBY_PLATFORM}"
      cmd = "dnsmasq"
    end
    pid = Process.spawn(
      cmd, "-d", "-p", "53534", "-C",
      File.expand_path("../etc/test_dnsmasq.conf", __FILE__),
      {err: :close})
    sleep 0.1

    begin
      yield
    ensure
      Process.kill Signal.list["INT"], pid
      Process.wait pid
    end
  end
end
