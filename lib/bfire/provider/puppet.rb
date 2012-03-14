module Bfire
  module Provider
    class Puppet
      CONTEXT_FILE = "/etc/default/bonfire"

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

      def install(ssh_session, context = {})
        contextualisation = context.map{|(k,v)| "#{k.upcase}=\"#{v}\""}.join("\n")
        ssh_session.scp.upload!(StringIO.new(contextualisation), CONTEXT_FILE)        
        ssh_session.scp.upload!(StringIO.new(sources), "/etc/apt/sources.list")
        if context[:authorized_keys]
          p [:auth, context[:authorized_keys]]
          ssh_session.scp.upload!(StringIO.new(context[:authorized_keys]), "/root/.ssh/authorized_keys2")
        end
        cmd = "#{exports(context)}source #{CONTEXT_FILE} && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install curl puppet -y"
        p [:cmd, cmd]
        res = ssh_session.exec!(cmd)
        res = ssh_session.exec!("which puppet")
        !res.nil? && !res.empty?
      end
      
      def run(ssh_session, context = {})
        ssh_session.exec!("rm -rf /tmp/puppet && mkdir -p /tmp/puppet")
        ssh_session.scp.upload!(
          StringIO.new(manifest("vm")),
          "/tmp/puppet/manifest.pp"
        )
        ssh_session.sftp.upload!(modules, "/tmp/puppet/modules")
        ssh_session.exec!(
          "#{exports(context)}source #{CONTEXT_FILE} && puppet --modulepath /tmp/puppet/modules /tmp/puppet/manifest.pp"
        ) do |ch, stream, data|
          yield "[#{stream.to_s.upcase}] #{data.chomp}"
        end
        true
      end
      
      def exports(ctx)
        ctx.reject{|k,v| k.to_s !~ /^http/}.map{|k,v| "export #{k}=\"#{v}\" && "}.join("")
      end

      def sources
        result = <<SOURCES
# deb http://ftp.us.debian.org/debian/ squeeze main


deb http://ftp.us.debian.org/debian/ stable main contrib non-free
deb-src http://ftp.us.debian.org/debian/ stable main contrib non-free
SOURCES
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