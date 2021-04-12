#!/usr/bin/env ruby

require 'thread'
require 'os'
require 'tty-spinner'
require 'yaml'
require 'json'
require 'pry'

BANNER = '
    ____        _ __    ___                ___
   / __ )__  __(_) /___/ (_)___  ____ _   /   |  ____  ____  _____
  / __  / / / / / / __  / / __ \/ __ `/  / /| | / __ \/ __ \/ ___/
 / /_/ / /_/ / / / /_/ / / / / / /_/ /  / ___ |/ /_/ / /_/ (__  )
/_____/\__,_/_/_/\__,_/_/_/ /_/\__, /  /_/  |_/ .___/ .___/____/
                              /____/         /_/   /_/👉 😎 👉 Zoop!

 Building Apps using Docker, this could take a few minutes...

'

USAGE = <<ENDUSAGE
Usage:
    build-local -y yaml-file [-t count] [-r retries] [-h]
    build-local -l
    build-local -c compoent
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
    -w, --write-build-log   Writes the build log even for successful builds

    -l, --list              List compoents by name
    -c, --component         Specify a compent to rebuild and restart

    -h, --help              Show's this help message
ENDHELP

THREAD_SUCCESS_MARKS = ["✅","🎉","🎆"]
SUCCESS_MARK = "🎆 🎉 ✅ 🎉 🎆"
ERROR_MARK = "❌ 😡 ❌ 😡 ❌"

class Repository
  def initialize(repo_name:, spinners:)
    @repo_name = repo_name
    @spinners = spinners
    @success = false
    @spinner = nil
  end

  def get_repo
    cmd = "git clone https://github.com/alphagov/#{@repo_name}.git ../#{@repo_name} 2>&1"
    output = `#{cmd}`
    unless $?.success?
      File.write("#{@script_dir}/logs/#{@repo_name}_fetch.log", output, mode: "w")
      @spinner.error(" failed to clone repository - see #{@script_dir}/logs/#{@repo_name}_fetch.log")
      @success = false
      false
    end
    @spinner.success
    true
  end

  def run
    have_repo = true
    unless File.exists?("../#{@repo_name}")
      @spinner = @spinners.register("[:spinner] Fetching #{@repo_name} from GitHub", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
      @spinner.auto_spin
      @success = get_repo
    else
      @success = true
    end
  end

  def success?
    return @success
  end
end

# This is our worker thread which builds our docker images
class ImageBuilder
  attr_accessor :image_var, :messages

  def initialize(repo_name:, config:, spinner:, images:, script_dir:, retries:, write_success_log: false)
    @repo_name = repo_name
    @config = config
    @spinner = spinner
    @image_var = ""
    @script_dir = script_dir
    @success = false
    @release = "verify-local-startup dev"
    @retries = retries
    @write_success_log = write_success_log
    @output = "Starting build of #{repo_name}...\n"
  end

  def build_image
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
      if @write_success_log
        @spinner.success(" - see #{@script_dir}/logs/#{@repo_name}_build.log")
        @output = @output + output + "\nBuild failed... Unable to retry.\n" 
        File.write("#{@script_dir}/logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
      else
        @spinner.success
      end
      @image_var = "#{@config['image_env_var']}=#{image_name}\n"
      @success = true
    elsif @retries > 0
      @output = @output + output + "\nBuild failed... Retrying...\n"
      @retries = @retries - 1
      build_image
    else
      @output = @output + output + "\nBuild failed... Unable to retry.\n" 
      File.write("#{@script_dir}/logs/#{@repo_name}_build.log", "log from command=#{cmd}\n#{output}", mode: "w")
      @spinner.error(" - see #{@script_dir}/logs/#{@repo_name}_build.log")
      @success = false
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
end

def fetch_git_repos(thread_count, repos, write_success_log)
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Fetching Repos", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
  script_dir = File.expand_path(File.dirname(__FILE__))
  
  r = []
  repos.each do | repo_name, config|
    r.append(config['context'])
  end
  git_queue = Queue.new
  r.to_set.each do | repo |
    r_thread = Repository.new(repo_name: repo, spinners: loading_spinners)
    git_queue << r_thread
  end

  # Create Threads
  threads = []
  thread_failed = false
  thread_count.times do
    threads << Thread.new do
      until git_queue.empty?
        work_unit = git_queue.pop(true) rescue nil
        if work_unit
          work_unit.run
          unless work_unit.success?
            thread_failed = true
          end
        end
      end
    end
  end
  threads.each { |t| t.join }
  if thread_failed
    print "Something went wrong while trying to fetch git repositories  Exiting..."
    exit 1
  end
  puts "Successfully fetched all git repositories"
end

def create_docker_images(thread_count, repos, retries, write_success_log)
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Building apps", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)

  images = ""
  script_dir = File.expand_path(File.dirname(__FILE__))
  Thread.abort_on_exception = true

  # Create queue and populate it
  queue = Queue.new
  repos.each do |repo_name, config|
    spinner = loading_spinners.register("[:spinner] #{repo_name}", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
    spinner.auto_spin
    buildImage = ImageBuilder.new(
        repo_name: repo_name,
        config: config,
        spinner: spinner,
        images: images,
        script_dir: script_dir,
        retries: retries,
        write_success_log: write_success_log)
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

def docker_ps
  output = `docker ps --format '"{{$v1 := split .Image ":"}}{{$shortName := index $v1 0}}{{$shortName}}": { "name": "{{.Names}}", "image": "{{.Image}}", "container": "{{.ID}}" },'`
  JSON.parse("{ #{output[0..-3]} }")
end

def list_compoents(repos)
  puts "Listing compoents:"
  repos.each do |repo_name, config|
    if docker_ps[repo_name].nil?
      running = "[ Stopped ]"
    else
      running = "[ Running ]"
    end
    puts "#{repo_name.ljust(20)} #{running}"
  end
end

def stop_compoent(component_name, spinner)
  component = docker_ps[component_name]
  spinner.auto_spin
  if component.nil?
    spinner.success("Component not running.")
  else
    output = `docker stop #{component["name"]} 2>&1`
    if $?.success?
      spinner.success("Service #{component_name} has been stopped.")
    else
      spinner.error("Could not stop service #{component_name}")
      puts "Debug information:\n\tComponent_name = #{component_name}\n\tComponent = #{component}"
    end
  end
end

def build_component(component_name, repos, spinner)
  images = ""
  build_image = ImageBuilder.new(
      repo_name: component_name,
      config: repos[component_name],
      spinner: spinner,
      images: images,
      script_dir: File.expand_path(File.dirname(__FILE__)),
      retries: 2,
      write_success_log: false)
  build_image.run
end

def start_component(component_name, spinner)
  spinner.auto_spin
  output = `docker-compose --env-file .env up -d #{component_name} 2>&1`
  if $?.success?
    spinner.success(" - Service #{component_name} has been started.")
  else
    spinner.error(" - Could not start service #{component_name}")
    puts "Debug information:\n\tComponent_name = #{component_name}\n\tDocker Output = #{output}"
  end
end

def role_component(repos, component_name, skip_build = false)
  loading_spinners = TTY::Spinner::Multi.new("[:spinner] Rolling component #{component_name}", format: :arrow_pulse, success_mark: SUCCESS_MARK, error_mark: ERROR_MARK)
  stop_spinner = loading_spinners.register("[:spinner] Stopping Component", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  build_spinner = loading_spinners.register("[:spinner] Building Component", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  start_spinner = loading_spinners.register("[:spinner] Starting Component", format: :dots, success_mark: "#{THREAD_SUCCESS_MARKS.sample}", error_mark: "😡")
  stop_compoent(component_name, stop_spinner)
  build_component(component_name, repos, build_spinner) unless skip_build
  start_component(component_name, start_spinner)
end

def main()
  args = { :yaml=>'repos.yml', :thread_count=>0, :retries=>1, :write_success_log=>false, :list=>false, :component=>nil }
  unflagged_args = []
  next_arg = unflagged_args.first

  ARGV.each do |arg|
    case arg
      when '-h', '--help'               then args[:help] = true
      when '-w', '--write-build-log'    then args[:write_success_log] = true
      when '-y', '--yaml-file'          then next_arg = :yaml
      when '-t', '--threads'            then next_arg = :threads
      when '-l', '--list'               then args[:list] = true
      when '-c', '--component'          then next_arg = :component
      when '-r', '--retry-build'        then next_arg = :retries
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
  unless File.file?(args[:yaml])
    puts "Yaml file does not exist.  Exiting..."
    puts USAGE
    exit 1
  end

  # Load repos yaml
  repos = YAML.load(File.read(args[:yaml]))
  
  # Setup thread count
  thread_count = args[:threads].to_i
  # Setup retries
  retries = args[:retries].to_i

  write_success_log = args[:write_success_log]

  if args[:list] == true
    list_compoents(repos)
  elsif !args[:component].nil?
    role_component(repos, args[:component])
  else
    puts "#{BANNER}"

    if OS.mac? && thread_count.zero?
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

    fetch_git_repos(thread_count, repos, write_success_log)
    images = create_docker_images(thread_count, repos, retries, write_success_log)
    generate_env(images)
  end
end

main
