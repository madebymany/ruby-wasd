require 'resolv'

module Wasd
  class Client
    attr_reader :resolver

    def initialize(domain: nil, resolver_config: nil)
      @domain = domain
      @resolver = Resolv::DNS.new(resolver_config)
    end

    def service_instances(name: nil, protocol: "tcp", domain: nil)
      domain ||= @domain or raise "no domain given"
      raise "no service name given" unless name
      raise "nil protocol given" unless protocol

      service = Service.new(name, protocol, domain)
      @resolver.getresources(service.dns_name,
                             Resolv::DNS::Resource::IN::PTR).map do |ptr|
        Instance.from_ptr service, ptr, @resolver
      end
    end

    def service_instance(description: nil, name: nil, protocol: "tcp", domain: nil)
      domain ||= @domain or raise "no domain given"
      raise "no description given" unless description
      raise "no service name given" unless name
      raise "nil protocol given" unless protocol

      Instance.new Service.new(name, protocol, domain), description, @resolver
    end
  end

  class Service
    attr_reader :name, :protocol, :domain

    def initialize(name, protocol, domain)
      @name, @protocol, @domain = name, protocol, domain
    end

    def ==(other)
      name == other.name && protocol == other.protocol && \
        domain == other.domain
    end

    def dns_name
      "_#{name}._#{protocol}.#{domain}"
    end

  end

  class Instance
    DefaultPropertiesVersion = 1

    attr_reader :service, :description, :full_name
    attr_accessor :resolver

    def self.from_ptr(service, ptr, resolver = nil)
      full_name = ptr.name.to_s
      description = full_name[/\A.+?(?<!\\)\./].chop.gsub(/\\(.)/, '\1')
      new service, description, resolver
    end

    def initialize(service, description, resolver = nil)
      @service, @description, @resolver = service, description, resolver
    end

    def ==(other)
      service == other.service && description == other.description
    end

    def resolve(given_resolver = nil)
      if given_resolver && given_resolver.respond_to?(:resolver)
        given_resolver = given_resolver.resolver
      end
      r = resolver || given_resolver or
        raise "no resolver given"

      properties = {}
      r.getresources(self.dns_name, Resolv::DNS::Resource::IN::TXT).each do |rr|
        version = DefaultPropertiesVersion

        rr.strings.each_with_index do |str, i|
          k, v = str.split('=', 2)
          next if k.nil? || k.empty?

          if i == 0 && k == "txtvers"
            version = v.to_i
            next
          end

          properties[version] ||= {}
          properties[version][k] = v
        end
      end

      endpoints = r.getresources(self.dns_name, Resolv::DNS::Resource::IN::SRV).map do |rr|
        Endpoint.new(rr.target.to_s, rr.port, rr.priority)
      end.sort_by(&:priority).reverse

      ResolvedInstance.new(self, endpoints, properties)
    end

    def dns_name
      "#{escaped_description}.#{service.dns_name}"
    end

  protected

    def escaped_description
      description.gsub(/([ \.])/, "\\\\\\1")
    end
  end

  ResolvedInstance = Struct.new("ResolvedInstance", :instance, :endpoints, :properties)
  Endpoint = Struct.new("Endpoint", :host, :port, :priority)
end
