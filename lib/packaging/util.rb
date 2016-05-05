require 'fileutils'
require 'json'
require 'semantic'
require 'yaml'

module Packaging
  module Util

    ##
    # make directory only if it does not exists

    def self.mkdir_p *dirs
      dirs.each do |dir|
        FileUtils.mkdir_p dir unless File.directory? dir
      end
    end

    ##
    # safer symlink that creates the parent directory with support for force option

    def self.ln_s link, target, options = { :force => false }
      return if valid_symlink? link, target
      FileUtils.mkdir_p Pathname.new(link).parent
      FileUtils.ln_s target, link, options
    end

    ##
    # verify symlink, we are not concerned about non existing target files

    def self.valid_symlink? source, target
      File.symlink?(source) && File.readlink(source) == target
    end

    ##
    # load json configuration file

    def self.load_json file
      file = File.expand_path file
      raise ArgumentError, "Invalid json file path: #{file}" unless File.exist? file
      JSON.parse File.read file
    end

    ##
    # load yaml configuration file

    def self.load_yaml file
      file = File.expand_path file
      raise ArgumentError, "Invalid yaml file path: #{file}" unless File.exist? file
      YAML.load_file file
    end

    ##
    # return current system osfamily

    def self.os_family
      output = %x{uname -a}
      case output
      when /^Darwin/
        family = "MacOS"
      when /^Linux/
        if File.exists? "/etc/redhat-release"
          family = "RedHat"
        elsif File.exists? "/etc/lsb-release"
          family = File.read("/etc/lsb-release").match(/^DISTRIB_ID=(.*)/)[1]
        end
      end

      family ||= "Unknown"
    end

    ##
    # return semver from malform git tags (e.g. v0.13.0-beta) so they can be sorted.

    def self.semver version
      ::Semantic::Version.new version
    rescue ArgumentError
      clean_version = version.match(/(\d*\.\d*\.\d*)/)[0]
      ::Semantic::Version.new clean_version
    end

    ##
    # cd into working directory temporarily

    def self.working_dir path = Dir.getwd
      raise ArgumentError, "invalid working directory: #{path}" unless File.directory? path

      current_path = Dir.getwd
      Dir.chdir path
      Bundler.with_clean_env do
        yield
      end
    ensure
      Dir.chdir current_path
    end

    ##
    # cd into working directory with go environment

    def self.go_build path = Dir.getwd
      go_path = Packaging.config.artifacts_path
      working_dir path do
        ENV["GOPATH"] = go_path
        ENV["PATH"] += ":#{File.join go_path, 'bin'}"
        # NOTE: hide source file path on panic along with -trimpath
        # https://github.com/golang/go/issues/13809
        ENV["GOROOT_FINAL"] = "/usr/local/go"

        yield
      end
    end

  end
end
