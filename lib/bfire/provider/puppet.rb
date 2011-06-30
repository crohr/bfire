module Bfire
  module Provider
    class Puppet
      attr_reader :classes
      attr_reader :modules
      attr_reader :options
      attr_reader :errors

      def initialize(opts = {})
        @classes = opts.delete(:classes) || opts.delete("classes")
        @modules = opts.delete(:modules) || opts.delete("modules")
        @options = opts
        @errors = []
      end

      def install(ssh_session)
        res = ssh_session.exec!("apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install curl puppet -y")
        res = ssh_session.exec!("which puppet")
        !res.nil? && !res.empty?
      end
      
      def run(ssh_session)
        ssh_session.exec!("rm -rf /tmp/puppet && mkdir -p /tmp/puppet")
        ssh_session.scp.upload!(
          StringIO.new(manifest("vm")),
          "/tmp/puppet/manifest.pp"
        )
        ssh_session.sftp.upload!(modules, "/tmp/puppet/modules")
        ssh_session.exec!(
          "puppet --modulepath /tmp/puppet/modules /tmp/puppet/manifest.pp"
        ) do |ch, stream, data|
          yield "[#{stream.to_s.upcase}] #{data}"
        end
        true
      end

      def manifest(name)
        content = <<MANIFEST
class #{name} {
  #{classes.map{|klass| "include #{klass}"}.join("\n")}
}

include #{name}
MANIFEST
      end

      def valid?
        @errors = []
        if modules.nil?
          @errors.push("You must pass a :modules option to `provider`")
        elsif !File.directory?(modules)
          @errors.push("#{modules} is not a valid directory")
        end
        @errors.empty?
      end
    end
  end
end