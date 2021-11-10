#!/usr/bin/env ruby
require 'os'
require 'tty-spinner'
require 'colorize'
require 'fileutils'
require 'tempfile'
require 'securerandom'
require_relative "logger"

# This is our worker thread which builds our docker images
class ImageBuilder
    attr_accessor :image_var, :messages
  
    def initialize(repo_name:, config:, spinner:, images:, script_dir:, retries:, logger:, write_success_log: false, include_maven_local:)
      @repo_name = repo_name
      @config = config
      @spinner = spinner
      @image_var = ""
      @script_dir = script_dir
      @success = false
      @release = "verify-local-startup dev"
      @retries = retries
      @write_success_log = write_success_log
      @include_maven_local = include_maven_local
      @output = "Starting build of #{@repo_name}...\n"
      @logger = logger
      @thread_message = " Thread: #{@repo_name} : "
    end

    def build_image
      image_name = "#{@repo_name}:local"
      build_args = @config.fetch('build-args', []).map { |ba| "--build-arg #{ba.keys[0]}=#{ba.values[0]}" }.join " "
      file_paths = handle_maven_local
      # Made this one line to make it easier to see the command used in the logs
      cmd = "docker build #{build_args} --build-arg release=#{@release} ../#{@config['context']} -f #{file_paths[:dockerfile]} -t #{image_name} 2>&1"
      @logger.info "#{@thread_message} Running command: #{cmd}"
      output = `#{cmd}`
      @success = $?.success?
      @logger.debug "#{@thread_message} Success = #{@success}"
      tear_down_maven_local_temp_files file_paths

      if @success
        @logger.info "#{@thread_message} Successfully built #{@repo_name}"
        if @write_success_log
          @spinner.success(" - see #{@script_dir}/../logs/#{@repo_name}_build.log")
          @output = @output + output + "\nBuild failed... Unable to retry.\n" 
          @logger.info "#{@thread_message} Writing Log to: #{@script_dir}/../logs/#{@repo_name}_build.log"
          File.write("#{@script_dir}/../logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
        else
          @logger.info "#{@thread_message} No build log file created."
          @spinner.success
        end
        @image_var = "#{@config['image_env_var']}=#{image_name}\n"
      elsif @retries > 0
        @retries = @retries - 1
        @logger.info "#{@thread_message} Failed to build #{@repo_name}... Retrying... Retries left: #{@retries}"
        @output = @output + output + "\nBuild failed... Retrying...\n"
        build_image
      else
        @logger.error "#{@thread_message} Build process for #{@repo_name} failed and no retries left."
        @output = @output + output + "\nBuild failed... Unable to retry.\n" 
        File.write("#{@script_dir}/../logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
        @spinner.error(" - see #{@script_dir}/../logs/#{@repo_name}_build.log")
      end
    end
  
    def get_release
      cmd = "git -C ../#{@config['context']} rev-parse --short HEAD"
      output = `#{cmd}`
      @release = output.strip
    end
  
    def run
      get_release
      build_image
    end
  
    def success?
      return @success
    end

    def handle_maven_local
      return {dockerfile: "../#{@config['context']}/#{@config.fetch('dockerfile', 'Dockerfile')}"} unless @include_maven_local
      maven_local_dir = "#{`realpath ~`.strip}/.m2/repository/uk/gov/ida"
      unless File.exists?(maven_local_dir)
        puts "You've told the build to include your Maven local repo with the '-i/--include-maven-local' flag."
        puts "The directory #{maven_local_dir} doesn't appear to exist though."
        puts "Please either publish your libs locally (publishToMavenLocal Gradle task) or drop the '-i' flag."
        exit 1
      end

      random_namespace = SecureRandom.hex # To prevent race conditions with separate threads
      temp_m2_dirname = "m2_#{random_namespace}"
      temp_dockerfile = "Dockerfile_#{random_namespace}"
      dockerfile_content = insert_maven_local_copy_in_dockerfile(
        "../#{@config['context']}/#{@config.fetch('dockerfile', 'Dockerfile')}",
        temp_m2_dirname
      )

      File.open("../#{@config['context']}/#{temp_dockerfile}", 'w') { |f| f.write dockerfile_content }
      FileUtils.cp_r "#{`realpath ~`.strip}/.m2/repository/uk/gov/ida/.", "../#{@config['context']}/#{temp_m2_dirname}"

      {dockerfile: "../#{@config['context']}/#{temp_dockerfile}", m2: "../#{@config['context']}/#{temp_m2_dirname}"}
    end

    def tear_down_maven_local_temp_files(file_paths)
      return unless @include_maven_local

      FileUtils.rm_rf(file_paths[:dockerfile])
      FileUtils.rm_rf(file_paths[:m2])
    end

    def insert_maven_local_copy_in_dockerfile(dockerfile_path, m2_dir)
      output = ""
      dockerfile = File.new(dockerfile_path)
      dockerfile.each do |line|
        if line.start_with? 'WORKDIR' # We need the maven local repo available in each stage of the build
          output << line
          output << "COPY #{m2_dir}/ /root/.m2/repository/uk/gov/ida/\n"
        else
          output << line
        end
      end
      output
    end
  end
  
