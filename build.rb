#!/usr/bin/env ruby

require 'tty-spinner'

puts <<-'BANNER'
    ____        _ __    ___                ___
   / __ )__  __(_) /___/ (_)___  ____ _   /   |  ____  ____  _____
  / __  / / / / / / __  / / __ \/ __ `/  / /| | / __ \/ __ \/ ___/
 / /_/ / /_/ / / / /_/ / / / / / /_/ /  / ___ |/ /_/ / /_/ (__  )
/_____/\__,_/_/_/\__,_/_/_/ /_/\__, /  /_/  |_/ .___/ .___/____/
                              /____/         /_/   /_/👉 😎 👉 Zoop!
BANNER

script_dir = File.expand_path(File.dirname(__FILE__))

success_marks = ["✊","🙌","🙇","👌","👍","👏"]
error_mark = "❌ 😤 ❌ 😤 ❌ "
loading_spinners = TTY::Spinner::Multi.new("[:spinner] Building apps", format: :arrow_pulse, success_mark: "#{success_marks.join(" ")} ", error_mark: error_mark)

apps = {
  "stub-idp" => { :folder => "../ida-stub-idp", :build => "./gradlew clean distZip -Pversion=local -x test", :zip => "/build/distributions/ida-stub-idp-local.zip" },
  "test-rp" => { :folder => "../ida-sample-rp", :build => "./gradlew clean distZip -Pversion=local -x test", :zip => "/build/distributions/ida-sample-rp-0.1.local.zip" },
  "msa" => { :folder => "../verify-matching-service-adapter", :build => "./gradlew clean distZip -Pversion=local -x test", :zip => "/build/distributions/verify-matching-service-adapter-local.zip" },
  "config" => { :folder => "../verify-hub", :build => "./gradlew :hub:config:clean :hub:config:distZip -Pversion=local -x test", :zip => "/hub/config/build/distributions/config-0.1.local.zip" },
  "policy" => { :folder => "../verify-hub", :build => "./gradlew :hub:policy:clean :hub:policy:distZip -Pversion=local -x test", :zip => "/hub/policy/build/distributions/policy-0.1.local.zip" },
  "saml-proxy" => { :folder => "../verify-hub", :build => "./gradlew :hub:saml-proxy:clean :hub:saml-proxy:distZip -Pversion=local -x test", :zip => "/hub/saml-proxy/build/distributions/saml-proxy-0.1.local.zip" },
  "saml-soap-proxy" => { :folder => "../verify-hub", :build => "./gradlew :hub:saml-soap-proxy:clean :hub:saml-soap-proxy:distZip -Pversion=local -x test", :zip => "/hub/saml-soap-proxy/build/distributions/saml-soap-proxy-0.1.local.zip" },
  "saml-engine" => { :folder => "../verify-hub", :build => "./gradlew :hub:saml-engine:clean :hub:saml-engine:distZip -Pversion=local -x test", :zip => "/hub/saml-engine/build/distributions/saml-engine-0.1.local.zip" },
  "stub-event-sink" => { :folder => "../verify-hub", :build => "./gradlew :hub:stub-event-sink:clean :hub:stub-event-sink:distZip -Pversion=local -x test", :zip => "/hub/stub-event-sink/build/distributions/stub-event-sink-0.1.local.zip" }
  }

def build_thread(app, details, spinners, script_dir)
  success_marks = ["✊","🙌","🙇","👌","👍","👏"]
  spinner = spinners.register("[:spinner] #{app}", format: :dots, success_mark: "#{success_marks.sample} ", error_mark: "😡 ")
  spinner.auto_spin
  thread = Thread.new{
    Dir.chdir details[:folder]
    output = `#{details[:build]} 2>&1`
    result = $?.success?
    Dir.chdir script_dir
    output += "\n" + `ln -f #{details[:folder]}#{details[:zip]} #{app}.zip 2>&1`
    result = result && $?.success?
    if result
      spinner.success
    else
      File.write("#{script_dir}/logs/#{app}_build.log", output, mode: "w")
      spinner.error(" - see logs/#{app}_build.log")
    end
  }
end

threads = []
apps.each do |app, details|
  thread = build_thread(app, details, loading_spinners, script_dir)
  threads.push thread
end

threads.each do |thread| thread.join end

