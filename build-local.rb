#!/usr/bin/env ruby

require 'thread'
require 'os'
require 'tty-spinner'
require 'yaml'

BANNER = <<ENDBANNER
    ____        _ __    ___                ___
   / __ )__  __(_) /___/ (_)___  ____ _   /   |  ____  ____  _____
  / __  / / / / / / __  / / __ \/ __ `/  / /| | / __ \/ __ \/ ___/
 / /_/ / /_/ / / / /_/ / / / / / /_/ /  / ___ |/ /_/ / /_/ (__  )
/_____/\__,_/_/_/\__,_/_/_/ /_/\__, /  /_/  |_/ .___/ .___/____/
                              /____/         /_/   /_/👉 😎 👉 Zoop!

 Building Apps using Docker, this could take a few minutes...
 
ENDBANNER

USAGE = <<ENDUSAGE
Usage:
    build-local -y yaml-file [-t count] [-r retires] [-h]
ENDUSAGE

HELP = <<ENDHELP
    -y, --yaml-file         Yaml file with a List of repos to build
    -t, --threads           Specifies the number of threads to use to do the
                            the build.  If no number given will generate as many
                            threads as repos.  Suggested 4 threads
    -r, --retry-build       Sometimes the build can fail due to a resourcing issue
                            by default we'll always retry once.  If you want to
                            retry more times set a number here or set it to 0 to
                            not retry.
    -h, --help              Show's this help message
ENDHELP

# This is our worker thread which builds our docker images
class ImageBuilder
  attr_accessor :image_var, :messages

  def initialize(repo_name:, config:, spinner:, images:, script_dir:, retires:, write_success_log: false)
    @repo_name = repo_name
    @config = config
    @spinner = spinner
    @image_var = ""
    @script_dir = script_dir
    @success = false
    @release = "verify-local-startup dev"
    @retries = retires
    @output = "Starting build of #{repo_name}...\n"
  end

  def build_image()
    image_name = "#{@repo_name}:local"
    build_args = @config.fetch('build-args', []).map { |ba| "--build-arg #{ba.keys[0]}=#{ba.values[0]}" }.join " "
    cmd = "docker build #{build_args}\
        --build-arg release=#{@release}\
        ../#{@config['context']}\
        -f ../#{@config['context']}/#{@config.fetch('dockerfile', 'Dockerfile')}\
        -t #{image_name}\
        2>&1"
    output = `#{cmd}`
    if $?.success?
      @spinner.success(" - see #{@script_dir}/logs/#{@repo_name}_build.log")
      @putput = @output + output + "\nBuild failed... Unable to retry.\n" 
      File.write("#{@script_dir}/logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
      @image_var = "#{@config['image_env_var']}=#{image_name}\n"
      @success = true
    elsif @retries > 0
        @output = @output + output + "\nBuild failed... Retrying...\n"
        @retries = @retries - 1
        build_image()
    else
      @putput = @output + output + "\nBuild failed... Unable to retry.\n" 
      File.write("#{@script_dir}/logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
      @spinner.error(" - see #{@script_dir}/logs/#{@repo_name}_build.log")
      @success = false
    end
  end

  def get_repo()
    cmd = "git clone https://github.com/alphagov/#{@config['context']}.git ../#{@config['context']} 2>&1"
    output = `#{cmd}`
    unless $?.success?
      File.write("#{@script_dir}/logs/#{@repo_name}_build.log", output, mode: "w")
      @spinner.error(" failed to clone repository - see #{@script_dir}/logs/#{@repo_name}_build.log")
      @success = false
      false
    end
    true
  end

  def get_release()
    cmd = "git -C ../#{@config['context']} rev-parse --short HEAD"
    output = `#{cmd}`
    @release = output.strip
  end

  def run()
    have_repo = true
    unless File.exists?("../#{@config['context']}")
      have_repo = get_repo
    end
    if have_repo
      get_release
      build_image
    end
  end

  def success?
    return @success
  end
end

def create_docker_images(thread_count, repos, retires)
  thread_success_marks = ["✅","🎉","🎆"]
  success_marks = "🎆 🎉 ✅ 🎉 🎆"
  error_mark = "❌ 😡 ❌ 😡 ❌"
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Building apps", format: :arrow_pulse, success_mark: success_marks, error_mark: error_mark)

  images = ""
  script_dir = File.expand_path(File.dirname(__FILE__))
  Thread.abort_on_exception = true

  # Create queue and populate it
  queue = Queue.new
  repos.each do |repo_name, config|
    spinner = loading_spinners.register("[:spinner] #{repo_name}", format: :dots, success_mark: "#{thread_success_marks.sample}", error_mark: "😡")
    spinner.auto_spin
    buildImage = ImageBuilder.new(
        repo_name: repo_name,
        config: config,
        spinner: spinner,
        images: images,
        script_dir: script_dir,
        retires: retires,
        write_success_log: true)
    queue << buildImage
  end

  # Create Threads
  threads = []
  thread_failed = false
  thread_count.times do
    threads << Thread.new do
      until queue.empty?
        work_unit = queue.pop(true) rescue nil
        if work_unit
          work_unit.run
          if work_unit.success?
            images << work_unit.image_var
          else
            thread_failed = true
          end
        end
      end
    end
  end
  threads.each { |t| t.join }
  if thread_failed
    print "Something went wrong while building the images.  Exiting..."
    exit 1
  end
  puts "Build completed successully."
  images
end

def generate_env(images)
  print "Generating .env file..."
  urls = File.read('config/urls.env')
  ports = File.read('config/ports.env')
  File.write(".env", "#{urls}\n#{ports}\n\n# Docker images for docker-compose\n#{images}", mode: 'w')
  print "     Done\n"
end

def main()
  args = { :yaml=>'repos.yml', :thread_count=>0, :retries=>1 }
  unflagged_args = []
  next_arg = unflagged_args.first

  ARGV.each do |arg|
    case arg
      when '-h', '--help'         then args[:help] = true
      when '-y', '--yaml-file'    then next_arg = :yaml
      when '-t', '--threads'      then next_arg = :threads
      when '-r', '--retry-build'  then next_arg = :retires
      else
        if next_arg
          args[next_arg] = arg
          unflagged_args.delete( next_arg )
        end
        next_arg = unflagged_args.first
    end
  end
  if args[:help]
    puts USAGE
    puts HELP if args[:help]
    exit
  end
  if ! File.file?(args[:yaml])
    puts "Yaml file does not exist.  Exiting..."
    puts USAGE
    exit 1
  end

  puts BANNER

  # Load repos yaml
  repos = YAML.load(File.read(args[:yaml]))
  
  # Setup thread count
  thread_count = args[:threads].to_i
  # Setup retries
  retries = args[:retris].to_i

  if OS.mac? && thread_count == 0
    thread_count = 2
    puts "For your safety we are using #{thread_count} threads to do the build."
    puts "You can override this using the -t option."
  elsif thread_count == 0
    puts "WARNING: No thread count set... using #{repos.size} threads to do the build."
    puts "         If the build should fail you might want to try setting a thread count."
    thread_count = repos.size
  else
    puts "As you asked us we are using #{thread_count} threads to do the build."
  end
  puts ""
  images = create_docker_images(thread_count, repos, retries)
  generate_env(images)
end

main