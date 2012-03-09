module Puppet::Module::Tool
  module Applications
    class Installer

      class InstallException < Exception
        def add_v(version)
          if version.is_a? String
            version.sub(/^(?=\d)/, 'v')
          else
            version
          end
        end
      end

      class AlreadyInstalledError < InstallException
        attr_accessor :module_name, :installed_version, :requested_version

        def initialize(options)
          @module_name       = options[:module_name      ]
          @installed_version = options[:installed_version].sub(/^(?=\d)/, 'v')
          @requested_version = options[:requested_version]
          @requested_version.sub!(/^(?=\d)/, 'v') if @requested_version.is_a? String
          super "'#{@module_name}' (#{@requested_version}) requested; '#{@module_name}' (#{@installed_version}) already installed"
        end

        def multiline
          <<-MSG.strip
Could not install module '#{@module_name}' (#{@requested_version})
  Module '#{@module_name}' (#{@installed_version}) is already installed
    Use `puppet module upgrade` to install a different version
    Use `puppet module install --force` to re-install only this module
          MSG
        end
      end

      class NoVersionSatisfyError < InstallException
        attr_accessor :requested_module, :requested_version

        def initialize(options)
          @module_name       = options[:module_name]
          @requested_module  = options[:requested_module]
          @requested_version = options[:requested_version]
          @conditions        = options[:conditions]
          @source            = options[:source]
          @requested_version = add_v(@requested_version)
          super "'#{@requested_module}' (#{@requested_version}) requested; No version of '#{@requested_module}' will satisfy dependencies"
        end

        def multiline
          message = ''
          message << "Could not install module '#{@requested_module}' (#{@requested_version})\n"
          message << "  No version of '#{@requested_module}' will satisfy dependencies:\n"
          message << "    You specified '#{@requested_module}' (#{@requested_version})\n" if @source[:name] == :you
          @conditions[@module_name].select  {|cond| cond[:module] != :you} \
                                   .sort_by {|cond| cond[:module]}.each do |cond|
            message << "    '#{cond[:module]}' (#{add_v(cond[:version])}) requires '#{@module_name}' (#{add_v(cond[:dependency])})\n"
          end

          if @source[:name] == :you
            message << "    Use `puppet module install --force` to install this module anyway"
          else
            message << "    Use `puppet module install --ignore-dependencies` to install only this module"
          end

          message
        end
      end

      class InvalidDependencyCycleError < InstallException
        attr_accessor :requested_module, :requested_version

        def initialize(options)
          @requested_module  = options[:requested_module]
          @requested_version = options[:requested_version]
          @requested_version = add_v(@requested_version)
          @conditions        = options[:conditions]
          @source            = options[:source]
          super "'#{@requested_module}' (#{@requested_version}) requested; Invalid dependency cycle"
        end

        def multiline
          message = ''
          message << "Could not install module '#{@requested_module}' (#{@requested_version})\n"
          message << "  No version of '#{@requested_module}' will satisfy dependencies:\n"
          message << "    You specified '#{@requested_module}' (#{@requested_version}),\n"

          broken_tree = @source.reject {|mod| mod[:name] == :you}.reverse
          broken_tree.each do |mod|
            message << "    which depends on '#{mod[:name]}' (#{add_v(mod[:dependency])})"
            message << ',' unless broken_tree.last == mod
            message << "\n"
          end

          message << "    Use `puppet module install --force` to install this module anyway"
          message
        end
      end

      class InstallConflictError < InstallException
        attr_accessor :requested_module, :requested_version
        def initialize(options)
          @requested_module  = options[:requested_module]
          @requested_version = options[:requested_version]
          @requested_version = add_v(@requested_version)
          @dependency        = options[:dependency]
          @directory         = options[:directory]
          @metadata          = options[:metadata]
          super "'#{@requested_module}' (#{@requested_version}) requested; Installation conflict"
        end

        def multiline
          message = ''
          message << "Could not install module '#{@requested_module}' (#{@requested_version})\n"
          if @dependency
            message << "  Dependency '#{@dependency[:name]}' (#{add_v(@dependency[:version])})"
          else
            message << "  Installation"
          end
          message << " would overwrite #{@directory}\n"

          if @metadata
            message << "    Currently, '#{@metadata[:name]}' (#{add_v(@metadata[:version])}) is installed to that directory\n"
          end

          message << "    Use `puppet module install --dir <DIR>` to install modules elsewhere\n"
          if @dependency
            message << "    Use `puppet module install --ignore-dependencies` to install only this module"
          else
            message << "    Use `puppet module install --force` to install this module anyway"
          end

          message
        end
      end
    end
  end
end
