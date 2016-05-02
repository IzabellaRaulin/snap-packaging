module Packaging
  class Platform

    attr_accessor :os_name
    attr_accessor :os_codename
    attr_accessor :os_version
    attr_accessor :os_family
    attr_accessor :osarch
    attr_accessor :bin
    attr_accessor :etc
    attr_accessor :log
    attr_accessor :opt
    attr_accessor :man
    attr_accessor :service
    attr_accessor :service_dir
    attr_accessor :service_file
    attr_accessor :build_vm
    attr_accessor :package_format
    attr_accessor :package_iteration
    attr_accessor :fpm_options

    def initialize name, project_name
      @name = name
      @project = Packaging.get project_name ||
        fail("the project #{project_name} does not exist.")
      @config = Packaging.config

      @bin = '/usr/bin'
      @etc = '/etc'
      @log = '/var/log'
      @opt = '/opt'
      @man = File.join @opt, @project.name, 'share/man'
    end

    def prep_package
      create_skeleton
      package_binary
      create_symlink
      package_config
      package_example
      package_service
      generate_man
    end

    ##
    # directories to be created, can omit parent directories because of mkdir_p

    def skel_directories
      name = @project.name
      [
        @bin,
        File.join(@etc, name),
        File.join(@etc, name, 'keyrings'),
        @service_dir,
        File.join(@log, name),
        File.join(@opt, name, '/bin'),
        File.join(@opt, name, '/plugins'),
        File.join(@man, 'man1'),
        File.join(@man, 'man5'),
        File.join(@man, 'man8'),
      ].uniq.compact
    end

    def create_skeleton
      dirs = skel_directories.collect { |path| File.join tmp_path, path }
      FileUtils.mkdir_p dirs
    end

    def package_binary
      opt_bin = File.join tmp_path, @opt, @project.name, 'bin'
      go_binary_files.each do |file|
        FileUtils.cp file, opt_bin
      end
    end

    def package_config
      config_file = File.join @config.support_path, "snapd.conf.yaml"
      staging_file = File.join tmp_path, @etc, @project.name, "snapd.conf.yaml"

      FileUtils.cp config_file, staging_file
    end

    def package_example
      example_path = File.join @project.repo.dir.path, 'examples'
      staging_path = File.join tmp_path, @opt, @project.name

      FileUtils.cp_r example_path, staging_path
    end

    def generate_man
      # TODO:
    end

    def package_service
      #files = if @service_file.is_a? ::Array
      #          @service_file
      #        elsif @service_file.is_a? ::String
      #          [ @service_file ]
      #        else
      #          fail "please provide valid service files."
      #        end

      #binding.pry
      #files.each do |file|
      #end
    end

    def create_symlink
      go_binary_files.each do |file|
        filename = Pathname.new(file).basename
        link = File.join tmp_path, @bin, filename
        target = File.join @opt, @project.name, 'bin', filename
        Packaging::Util.ln_s link, target
      end
    end

    def fpm
      fpm_command = %(
fpm \
  -t #{@package_format} -s dir -f\
  -C #{fpm_tmp_path} \
  -p #{fpm_output_path} \
  -n "#{@project.name}" -v "0.13.0" \
  --iteration "#{@package_iteration}" \
  -m "#{@project.maintainer}" \
  --license "#{@project.license}" \
  --vendor "#{@project.vendor}" \
  --url "#{@project.url}" \
  --description "#{@project.description}" \
  #{@fpm_options} \
  ./
  )
      Packaging::Util.mkdir_p out_path
      Packaging::Util.working_dir do
        if @build_vm
          puts `
vagrant ssh #{@build_vm} -c \
  '#{fpm_command}'`
        else
          puts `#{fpm_command}`
        end
      end
    end


    ##
    # internal output path

    def tmp_path
      File.join @config.tmp_path, @os_name, @os_version
    end

    def fpm_tmp_path
      if @build_vm
        tmp_path.sub @config.project_path, ''
      else
        tmp_path
      end
    end

    def out_path
      File.join @config.pkg_path, 'os', @os_name, @os_version
    end

    def fpm_output_path
      if @build_vm
        out_path.sub @config.project_path, ''
      else
        out_path
      end
    end

    def go_binary_path
      File.join @config.pkg_path, @osarch
    end

    def go_binary_files
      Dir.glob("#{go_binary_path}/*")
    end
  end
end