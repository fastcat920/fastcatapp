#!/usr/bin/env ruby
require 'yaml'

# pubspec.yaml is the sole version source for both Flutter and native tvOS.
# Xcode consumes the generated file before compiling either target.
def sync_tvos_version(root, check: false)
  version = YAML.safe_load(File.read(File.join(root, 'pubspec.yaml')))['version']
  match = /\A(\d+\.\d+\.\d+)\+(\d+)\z/.match(version.to_s)
  abort 'pubspec.yaml version must have the form major.minor.patch+build' unless match
  contents = "// Generated from pubspec.yaml by scripts/sync_tvos_version.rb.\n" \
    "FASTCAT_APP_VERSION = #{match[1]}\nFASTCAT_BUILD_NUMBER = #{match[2]}\n"
  path = File.join(root, 'tvos', 'Version.xcconfig')
  if check
    abort 'tvOS version is stale; run ruby scripts/sync_tvos_version.rb' unless File.exist?(path) && File.read(path) == contents
  else
    File.write(path, contents) unless File.exist?(path) && File.read(path) == contents
  end
end

sync_tvos_version(File.expand_path('..', __dir__), check: ARGV.include?('--check')) if $PROGRAM_NAME == __FILE__
