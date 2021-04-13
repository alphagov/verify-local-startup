#!/usr/bin/env ruby

require 'thread'
require 'os'
require 'tty-spinner'
require 'yaml'
require 'json'
require 'colorize'

require_relative 'image_builder'
require_relative 'repository'

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
    build-local -y yaml-file [-t count] [-R retries] [-h]

ENDUSAGE

HELP = <<ENDHELP
  Build Process:
    -y, --yaml-file         Yaml file with a List of repos to build
    -t, --threads           Specifies the number of threads to use to do the
                            the build.  If no number given will generate as many
                            threads as repos.  Suggested 4 threads
    -R, --retry-build       Sometimes the build can fail due to a resourcing issue
                            by default we'll always retry once.  If you want to
                            retry more times set a number here or set it to 0 to
                            not retry.
    -w, --write-build-log   Writes the build log even for successful builds

  Help:
    -h, --help              Show's this help message
ENDHELP

THREAD_SUCCESS_MARKS = ["✅","🎉","🎆"]
SUCCESS_MARK = "🎆 🎉 ✅ 🎉 🎆"
ERROR_MARK = "❌ 😡 ❌ 😡 ❌"

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

def main()
  args = { :yaml=>'repos.yml', :thread_count=>0, :retries=>1, :write_success_log=>false }
  unflagged_args = []
  next_arg = unflagged_args.first

  ARGV.each do |arg|
    case arg
      when '-h', '--help'               then args[:help] = true
      when '-w', '--write-build-log'    then args[:write_success_log] = true
      when '-y', '--yaml-file'          then next_arg = :yaml
      when '-t', '--threads'            then next_arg = :threads
      when '-R', '--retry-build'        then next_arg = :retries
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

main
