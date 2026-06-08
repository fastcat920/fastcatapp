#!/usr/bin/env ruby
# setup_ios.rb — Configures the Xcode project for building.
#
# The ios/ directory is already committed with all source files.
# This script only needs to:
#   1. Replace placeholder variables (APP_GROUP_ID, PRODUCT_BUNDLE_IDENTIFIER)
#   2. Add the PacketTunnel Network Extension target to the Xcode project
#   3. Add libclash.xcframework to the PacketTunnel target
#   4. Update Runner/Info.plist with Background Modes (if not already present)
#
# Usage (called by build.yaml):
#   gem install xcodeproj
#   ruby scripts/setup_ios.rb <bundle_id> <app_group_id>
#
# Example:
#   ruby scripts/setup_ios.rb com.fastcat.app group.com.fastcat.app

require 'xcodeproj'
require 'fileutils'

bundle_id   = ARGV[0] || 'com.fastcat.app'
app_group   = ARGV[1] || "group.#{bundle_id}"
tunnel_id   = "#{bundle_id}.PacketTunnel"
project_path = 'ios/Runner.xcodeproj'

puts "[setup_ios] bundle_id=#{bundle_id}  app_group=#{app_group}"

# ── 1. Replace placeholders in source files ──────────────────────────────────

[
  'ios/Runner/Runner.entitlements',
  'ios/Runner/VPNManager.swift',
  'ios/PacketTunnel/PacketTunnel.entitlements',
  'ios/PacketTunnel/PacketTunnelProvider.swift',
  'ios/PacketTunnel/Info.plist',
].each do |f|
  next unless File.exist?(f)
  content = File.read(f)
    .gsub('$(APP_GROUP_ID)', app_group)
    .gsub('group.$(PRODUCT_BUNDLE_IDENTIFIER_PREFIX)', app_group)
    .gsub('group.$(PRODUCT_BUNDLE_IDENTIFIER)', app_group)
    .gsub('$(PRODUCT_BUNDLE_IDENTIFIER_PREFIX)', bundle_id)
  File.write(f, content)
  puts "[setup_ios] patched placeholders in #{f}"
end

# ── 2. Patch Runner/Info.plist — ensure Background Modes ────────────────────

info_plist = 'ios/Runner/Info.plist'
content = File.read(info_plist)
unless content.include?('UIBackgroundModes')
  content.sub!(
    '</dict>',
    <<~XML
      \t<key>UIBackgroundModes</key>
      \t<array>
      \t\t<string>network-authentication</string>
      \t\t<string>voip</string>
      \t</array>
      </dict>
    XML
  )
  File.write(info_plist, content)
  puts "[setup_ios] patched Runner/Info.plist — added UIBackgroundModes"
end

# ── 3. Open Xcode project and add PacketTunnel target ────────────────────────

project = Xcodeproj::Project.open(project_path)

# Check if PacketTunnel target already exists
existing = project.targets.find { |t| t.name == 'PacketTunnel' }
if existing
  puts "[setup_ios] PacketTunnel target already exists — skipping creation"
  # Still update bundle IDs
  runner = project.targets.find { |t| t.name == 'Runner' }
  runner&.build_configurations&.each do |c|
    c.build_settings['CODE_SIGN_ENTITLEMENTS']    = 'Runner/Runner.entitlements'
    c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  end
  existing.build_configurations.each do |c|
    c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = tunnel_id
  end
  project.save
  exit 0
end

# Create the extension target
tunnel_target = project.new_target(
  :app_extension,
  'PacketTunnel',
  :ios,
  '14.0'
)
# Ensure product reference has the correct name
tunnel_target.product_reference.path = 'PacketTunnel.appex'
tunnel_target.product_reference.name = 'PacketTunnel.appex'

# ── 4. Add source files to PacketTunnel target ───────────────────────────────

tunnel_group = project.main_group.new_group('PacketTunnel', 'PacketTunnel')

['PacketTunnelProvider.swift'].each do |fname|
  file_ref = tunnel_group.new_file(fname)
  tunnel_target.source_build_phase.add_file_reference(file_ref)
end

# Bridging header (not added to build phase, just the group)
tunnel_group.new_file('PacketTunnel-Bridging-Header.h')

# Info.plist
info_ref = tunnel_group.new_file('Info.plist')

# ── 4b. Add libclash.xcframework to PacketTunnel target ──────────────────────

frameworks_group = project.main_group.find_subpath('Frameworks') || project.main_group.new_group('Frameworks', 'Frameworks')
xcframework_ref = frameworks_group.new_file('Frameworks/libclash.xcframework')
tunnel_target.frameworks_build_phase.add_file_reference(xcframework_ref)
puts "[setup_ios] added libclash.xcframework to PacketTunnel target"

# ── 5. Configure build settings ──────────────────────────────────────────────

tunnel_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME']                      = 'PacketTunnel'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']         = tunnel_id
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER']        = 'PacketTunnel/PacketTunnel-Bridging-Header.h'
  config.build_settings['INFOPLIST_FILE']                    = 'PacketTunnel/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS']            = 'PacketTunnel/PacketTunnel.entitlements'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS']           = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  config.build_settings['SWIFT_VERSION']                     = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']        = '14.0'
  config.build_settings['CODE_SIGNING_REQUIRED']             = 'NO'
  config.build_settings['CODE_SIGNING_ALLOWED']              = 'NO'
  config.build_settings['SKIP_INSTALL']                      = 'YES'
  config.build_settings['OTHER_LDFLAGS']                     = ['$(inherited)', '-lclash', '-lresolv']
  config.build_settings['LIBRARY_SEARCH_PATHS']              = ['$(inherited)', '$(PROJECT_DIR)/Frameworks']
  config.build_settings['FRAMEWORK_SEARCH_PATHS']            = ['$(inherited)', '$(PROJECT_DIR)/Frameworks']
end

# Runner entitlements + bundle ID
runner = project.targets.find { |t| t.name == 'Runner' }
runner&.build_configurations&.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS']  = 'Runner/Runner.entitlements'
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
end

# ── 6. Embed PacketTunnel extension in Runner ─────────────────────────────────
#
# Do NOT create an "Embed App Extensions" copy-files phase here.
# Xcode's implicit embed (from the target dependency) conflicts with a manual
# copy-files phase, causing "Cycle inside Runner" build errors.
# Instead, build.yaml will manually copy PacketTunnel.appex into PlugIns/
# after the archive step if Xcode didn't embed it automatically.

if runner
  # Remove any leftover embed phases from previous runs (safety net)
  runner.build_phases.select do |p|
    p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
      p.dst_subfolder_spec.to_s == '13'
  end.each do |p|
    p.remove_from_project
  end

  runner.add_dependency(tunnel_target)
end

project.save
puts "[setup_ios] ✅ Xcode project updated — PacketTunnel target added"
