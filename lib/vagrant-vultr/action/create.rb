require 'vagrant-vultr/helpers/client'
require 'securerandom'

module VagrantPlugins
  module Vultr
    module Action
      class Create
        include Helpers::Client

        def initialize(app, env)

          # Create a vaguely reasonable random name for this machine.
          # code borrowed from vagrant-parallels

          prefix = "#{env[:root_path].basename.to_s}-#{env[:machine].name}"
          prefix.gsub!(/[^_a-z0-9-]/i, '')
          if prefix.match?('^[0-9]') then
            prefix = "x" + prefix
          end

          # milliseconds + random number suffix to allow for simultaneous `vagrant up` of the same box in different dirs
          # suffix = "-#{(Time.now.to_f * 1000.0).to_i}-#{rand(100000)}"

          suffix = SecureRandom.hex(8)
          @default_name = prefix+"-"+suffix

          @app = app
          @machine = env[:machine]
          @machine.provider_config.default_name = @default_name
          @client = client
          @logger = Log4r::Logger.new('vagrant::vultr::create')
        end

        def call(env)
          region   = env[:machine].provider_config.region
          plan     = env[:machine].provider_config.plan
          os       = env[:machine].provider_config.os
          snapshot = env[:machine].provider_config.snapshot
	  enable_ipv6 = env[:machine].provider_config.enable_ipv6
	  enable_private_network = env[:machine].provider_config.enable_private_network
          label    = env[:machine].provider_config.label
          tag      = env[:machine].provider_config.tag
          hostname = env[:machine].provider_config.hostname

          if label == nil then
            label = env[:machine].provider_config.default_name
          end

          using_default_name = false
          if hostname == nil then
            using_default_name = true
            hostname = env[:machine].provider_config.default_name
          end

          @logger.info "Creating server with:"
          @logger.info "  -- Region: #{region}"
          @logger.info "  -- OS: #{os}"
          @logger.info "  -- Plan: #{plan}"
          @logger.info "  -- Snapshot: #{snapshot}"
          @logger.info "  -- Enable IPv6: #{enable_ipv6}"
          @logger.info "  -- Enable Private Network: #{enable_private_network}"
          @logger.info "  -- Label: #{label}"
          @logger.info "  -- Tag: #{tag}"
          @logger.info "  -- Hostname: #{hostname}"
          @logger.info "  -- Using default name: #{using_default_name}"

          attributes = {
            region: region,
            os: os,
            plan: plan,
            snapshot: snapshot,
            enable_ipv6: enable_ipv6,
            enable_private_network: enable_private_network,
            label: label,
            tag: tag,
            hostname: hostname,
            ssh_key_name: Action::SetupSSHKey::NAME
          }
          $stdout.printf("Final attributes for create_server: %s\n", attributes)

          @machine.id = @client.create_server(attributes)

          env[:ui].info 'Waiting for subcription to become active...'
          @client.wait_to_activate(@machine.id)

          env[:ui].info 'Waiting for server to start...'
          @client.wait_to_power_on(@machine.id)

          env[:ui].info 'Waiting for SSH to become active...'
          @client.wait_for_ssh(@machine)

          env[:ui].info 'Machine is booted and ready to use!'

          @app.call(env)
        end
      end
    end
  end
end
