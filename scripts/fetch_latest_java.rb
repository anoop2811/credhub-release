#!/usr/bin/env ruby

require 'yaml'
require 'open-uri'
require 'fileutils'

def latest_for(yaml_url, package_name)
  yaml = YAML.load(open(yaml_url).read)
  yaml = yaml.inject({}) do |memo, (key, value)|
    memo[Gem::Version.new(key.gsub("_", "."))] = value
    memo
  end

  sorted_versions = yaml.keys.sort

  yaml[sorted_versions.last].tap do |latest|
    puts "Guessed latest #{package_name}: #{latest} (please confirm!)"
  end
end

def latest_jre
  latest_for 'http://download.pivotal.io.s3.amazonaws.com/openjdk/trusty/x86_64/index.yml', 'jre'
end

def latest_jdk
  latest_for 'https://java-buildpack.cloudfoundry.org/openjdk-jdk/trusty/x86_64/index.yml', 'jdk'
end

Dir.chdir File.dirname(__FILE__) + "/.."

jre_url = latest_jre
jdk_url = latest_jdk
jre_filename = File.basename(URI(jre_url).path)

# Write JDK URL to the packages/credhub/pre_packaging script. We need the JDK to build our code on CI.
pre_packaging_script_path = 'packages/credhub/pre_packaging'
pre_packaging_script = File.read(pre_packaging_script_path)
File.open(pre_packaging_script_path, 'w') do |f|
  f.print pre_packaging_script.sub(/JDK_URL="[^"]+"/, "JDK_URL=\"#{jdk_url}\"")
end
puts "writing jdk location"
File.open('.jdk-location', 'w') do |f|
  f.print("#{jdk_url}")
end

# Download current JRE
FileUtils.mkdir_p("blobs/openjdk_1.8.0")
puts "Downloading jre to #{jre_filename}"
puts "running: cd blobs/openjdk_1.8.0 && curl \"#{jre_url}\" -o \"#{jre_filename}\""
system "cd blobs/openjdk_1.8.0 && curl \"#{jre_url}\" -o \"#{jre_filename}\""

# Update blobs/openjdk_1.8.0/spec
spec_path = 'packages/openjdk_1.8.0/spec'
spec = YAML.load_file(spec_path)
spec['files'][0] = "openjdk_1.8.0/#{jre_filename}"
File.open(spec_path, 'w') { |f| f.puts YAML.dump(spec) }

puts "\nIf this looks good, do a dev release for testing, and finally \"bosh upload blobs\" and commit when you're happy."
