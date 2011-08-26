require 'bfire/api/base'
require 'restfully/addons/bonfire'
require 'uuidtools'

module Bfire
  module API
    class Bonfire < Base

      attr_reader :session

      def initialize(campaign, opts = {})
        super(campaign, opts)
        @session = Restfully::Session.new(
          {
            :logger => Bfire.logger,
            :uri => "https://api.bonfire-project.eu:444"
          }.merge(config)
        )
        @locations ||= {}
      end

      def find_location(id)
        synchronize {
          id = id.to_sym

          if id == :any
            choices = locations
            id = choices[rand(choices.length)]['name'].to_sym unless choices.length == 0
          end

          @locations[id] ||= begin
            resource = locations.find{|l| l['name'] == id.to_s }
            if resource
              Bfire::Location.new(id, resource, self)
            else
              nil
            end
          end
        }
      end

      def find_network(id, location)
        resource = location.resource.networks.find{|n|
          n['name'] == id.to_s
        }
        if resource
          Bfire::Network.new(id, resource, self)
        else
          nil
        end
      end

      def find_storage(id, location)
        resource = location.resource.storages.find{|n|
          n['name'] == id.to_s
        }
        if resource
          Bfire::Storage.new(id, resource, self)
        else
          nil
        end
      end

      def create_network(template, location)
        synchronize {
          address, size = template.config[:cidr].split("/")
          # FIXME
          case size.to_i
          when 24 then "C"
          else nil
          end
          resource = @container.networks.submit({
            :name => template.id,
            :address => address,
            :size => size
          })
          if resource
            Bfire::Network.new(template.id, resource, self)
          else
            nil
          end
        }
      end

      def create_storage(template, location)
        synchronize {
          payload = {
            :name => template.id,
            :public => (template.config[:visibility] == :public ? "YES" : "NO"),
            :size => template.config[:size],
            :fstype => template.config[:fstype],
            :persistent => (template.config[:persistent] ? "YES" : "NO"),
          }
          resource = @container.storages.submit(payload)
          if resource
            Bfire::Storage.new(template.id, resource, self)
          else
            nil
          end
        }
      end

      def create_compute(template, location)
        payload = compute_payload_for(template)
        resource = @container.computes.submit(payload)
        if resource
          Bfire::Compute.new(resource['name'], resource, self)
        else
          nil
        end
      end

      def validate(template)
        errors = super(template)
        errors.push("You must specify a type") unless template.config[:type]
        if image = template.config[:deploy]
          errors.push("Can't find image #{image[:name]} at #{template.location.id}") unless find_storage(image[:name], template.location)
        else
          errors.push("You must specify an image to deploy")
        end
        if template.config[:nics].empty?
          errors.push("You must specify at least one network attachment")
        end
        errors
      end

      # Creates the experiment container
      def setup!
        @container = root.experiments.submit({
          :name => campaign.config[:name],
          :description => [campaign.id, campaign.config[:description]].compact.join(" --- "),
          :walltime => campaign.config[:walltime],
          :status => :waiting
        })
        raise Error, "Can't setup campaign on #{self.class.name}" if @container.nil?
      end

      private

      def compute_payload_for(template)
        h = {
          :name => "#{template.group.id}--#{template.location.id}--#{SecureRandom.hex(4)}",
          :nics => [],
          :disks => [],
          :instance_type => template.config[:type],
          :context => template.config[:context],
          :location => template.location.resource
        }
        template.config[:nics].each do |nic|
          h[:nics].push({
            :network => nic[:network].resource,
            :device => nic[:device],
            :ip => nic[:ip]
          })
        end
        # Set image as first disk
        h[:disks].push({
          :storage => find_storage(
            template.config[:deploy][:name],
            template.location
          ).resource,
          :type => "OS"
        })
        template.config[:disks].each do |disk|
          h[:disks].push({
            :storage => disk[:storage].resource,
            :size => disk[:size],
            :fstype => disk[:fstype],
            :type => disk[:type]
          })
        end
        # TODO
        # h['name'] << "-#{group.tag}" if group.tag
        # h['context']['metrics'] = XML::Node.new_cdata(metrics.map{|m|
        #   "<metric>"+[m[:name], m[:command]].join(",")+"</metric>"
        # }.join("")) unless metrics.empty?
        template.group.dependencies.each{|group_name,block|
          h[:context].merge!(block.call(group.campaign.groups[group_name]))
        }
        h
      end

      def locations
        root.locations
      end

      def root
        session.root
      end

      # def find_network(name, location)
      #   Bfire.logger.debug "Looking for network #{name.inspect} at #{location}..."
      #   locations[location.id.to_sym].networks.find{|n|
      #     if name.kind_of?(Regexp)
      #       n['name'] =~ name
      #     else
      #       n['name'] == name.to_s
      #     end
      #   }
      # end
      #
      # def find_storage(name, location)
      #   Bfire.logger.debug "Looking for storage #{name.inspect} at #{location}..."
      #   locations[location.id.to_sym].storages.find{|n|
      #     if name.kind_of?(Regexp)
      #       n['name'] =~ name
      #     else
      #       n['name'] == name.to_s
      #     end
      #   }
      # end
      #
      # def fetch_storage(name, location)
      #
      #
      #   sname = name.to_s
      #   key = [location['name'], sname].join(".")
      #   logger.debug "#{banner}Looking for storage #{name.inspect} at #{location['name'].inspect}. key=#{key.inspect}"
      #   exp = experiment
      #   synchronize {
      #     # Duplicate general storages if present
      #     @storages[key] = @storages[sname].clone if @storages[sname]
      #
      #     @storages[key] = case @storages[key]
      #     when Restfully::Resource
      #       @storages[key]
      #     when Proc
      #       @storages[key].call(name, location, exp)
      #     else
      #       location.storages.find{|n|
      #         if name.kind_of?(Regexp)
      #           n['name'] =~ name
      #         else
      #           n['name'] == sname
      #         end
      #       }
      #     end
      #   }
      #   @storages[key]
      # end
      #
      # def fetch_location(name)
      #   name = name.to_sym
      #   location = if (name == :any)
      #      choices = session.root.locations
      #      return nil if choices.length == 0
      #      choices[rand(choices.length)]
      #   else
      #     @locations[name] || session.root.locations[name]
      #   end
      #   raise Error, "#{banner}Can't find #{name.inspect} location" if location.nil?
      #   synchronize {
      #     @locations[location['name'].to_sym] ||= location
      #   }
      #   location
      # end

    end
  end
end