require 'resolv'

module Wasd
  class Client
    attr_reader :resolver

    def initialize(domain: nil, resolver_config: nil)
      @domain = domain
      @resolver = Resolv::DNS.new(resolver_config)
    end

    def service(name: nil, protocol: "tcp", domain: nil)
      domain ||= @domain or raise "no domain given"
      raise "no service name given" unless name
      raise "nil protocol given" unless protocol

      Service.new name, protocol, domain, @resolver
    end

    def service_instances(**opts)
      s = service(**opts)
      @resolver.getresources(s.dns_name,
                             Resolv::DNS::Resource::IN::PTR).map do |ptr|
        Instance.from_ptr s, ptr, @resolver
      end
    end

    def service_instance(description: nil, name: nil, protocol: "tcp", domain: nil)
      raise "no description given" unless description

      Instance.new service(name: name, protocol: protocol, domain: domain), description, @resolver
    end
  end

  class Service
    attr_reader :name, :protocol, :domain, :resolver

    def initialize(name, protocol, domain, resolver = nil)
      @name, @protocol, @domain, @resolver = name, protocol, domain, resolver
    end

    def ==(other)
      name == other.name && protocol == other.protocol && \
        domain == other.domain
    end

    def dns_name
      "_#{name}._#{protocol}.#{domain}"
    end

    def to_h
      {
        name: name,
        protocol: protocol,
        domain: domain,
      }
    end

    def resolve(given_resolver = nil)
      if given_resolver && given_resolver.respond_to?(:resolver)
        given_resolver = given_resolver.resolver
      end
      r = resolver || given_resolver or
        raise "no resolver given"

      endpoints = EndpointsArray.from_srvs(
        r.getresources(self.dns_name, Resolv::DNS::Resource::IN::SRV))

      ResolvedService.new(self, endpoints)
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

      endpoints = EndpointsArray.from_srvs(
        r.getresources(self.dns_name, Resolv::DNS::Resource::IN::SRV))

      ResolvedInstance.new(self, endpoints, properties)
    end

    def dns_name
      "#{escaped_description}.#{service.dns_name}"
    end

    def to_h
      {
        description: description,
      }.merge(service.to_h)
    end

  protected

    def escaped_description
      description.gsub(/([ \.])/, "\\\\\\1")
    end
  end

  ResolvedService = Struct.new("ResolvedService", :service, :endpoints)

  ResolvedInstance = Struct.new("ResolvedInstance", :instance, :endpoints, :properties)

  class ResolvedInstance
    def service
      instance.service
    end

    def to_h
      {
        endpoints: endpoints.map(&:to_h),
        properties: properties,
      }.merge(instance.to_h)
    end
  end

  Endpoint = Struct.new("Endpoint", :host, :port, :priority)

  class Endpoint
    def self.from_srv(rr)
      new rr.target.to_s, rr.port, rr.priority
    end
  end

  class EndpointsArray < Array
    def self.from_srvs(rrs)
      new.tap do |out|
        rrs.each do |rr|
          out << Endpoint.from_srv(rr)
        end
      end.priority_sort
    end

    def priority_sort
      sort_by(&:priority).reverse
    end
  end
end
