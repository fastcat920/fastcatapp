#!/usr/bin/env ruby
# Generates the native tvOS project. It is intentionally separate from the
# Flutter iOS project because Flutter does not ship a tvOS application target.
require 'fileutils'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
Dir.chdir(root)
project_path = 'tvos/FastCatTV.xcodeproj'
FileUtils.rm_rf(project_path)
FileUtils.mkdir_p('tvos/Frameworks')
FileUtils.cp('tvos/Config.xcconfig.example', 'tvos/Config.xcconfig') unless File.exist?('tvos/Config.xcconfig')

project = Xcodeproj::Project.new(project_path)
main = project.main_group
app_group = main.new_group('FastCatTV', 'FastCatTV')
tunnel_group = main.new_group('PacketTunnel', 'PacketTunnel')
framework_group = main.new_group('Frameworks', 'Frameworks')

app = project.new_target(:application, 'FastCatTV', :tvos, '17.0')
tunnel = project.new_target(:app_extension, 'PacketTunnel', :tvos, '17.0')
tunnel.product_reference.path = 'PacketTunnel.appex'
tunnel.product_reference.name = 'PacketTunnel.appex'

%w[FastCatTVApp.swift SessionStore.swift KeychainStore.swift TVBuildConfiguration.swift TVRemoteConfigManager.swift FastCatSubscriptionDecoder.swift TVDesignSystem.swift TVNodeSelection.swift GatewayClient.swift TVLoginView.swift TVHomeView.swift VPNManager.swift].each do |name|
  app.source_build_phase.add_file_reference(app_group.new_file(name))
end
app_group.new_file('Info.plist')
app_group.new_file('FastCatTV.entitlements')

# Share the exact same client bootstrap configuration with Flutter. Xcode
# copies the file as config.yaml at the root of the tvOS application bundle.
shared_config = main.new_file('../assets/config/config.yaml')
app.resources_build_phase.add_file_reference(shared_config)
brand_icon = main.new_file('../assets/images/icon.png')
app.resources_build_phase.add_file_reference(brand_icon)
%w[Roboto-Regular.ttf Roboto-Medium.ttf MaterialIcons-Regular.otf].each do |name|
  font = app_group.new_file("Fonts/#{name}")
  app.resources_build_phase.add_file_reference(font)
end

%w[PacketTunnelProvider.swift].each { |name| tunnel.source_build_phase.add_file_reference(tunnel_group.new_file(name)) }
tunnel_group.new_file('PacketTunnel-Bridging-Header.h')
tunnel_group.new_file('Info.plist')
tunnel_group.new_file('PacketTunnel.entitlements')

framework = framework_group.new_file('libclash.xcframework')
tunnel.frameworks_build_phase.add_file_reference(framework)

embed = app.new_copy_files_build_phase('Embed App Extensions')
embed.dst_subfolder_spec = '13'
build_file = embed.add_file_reference(tunnel.product_reference)
build_file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy CodeSignOnCopy] }
app.add_dependency(tunnel)

config_ref = main.new_file('Config.xcconfig')
project.build_configurations.each { |config| config.base_configuration_reference = config_ref }

common = {
  'SWIFT_VERSION' => '5.0',
  'MARKETING_VERSION' => '3.6.0',
  'CURRENT_PROJECT_VERSION' => '1',
  'CODE_SIGN_STYLE' => 'Automatic',
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'TARGETED_DEVICE_FAMILY' => '3',
  'TVOS_DEPLOYMENT_TARGET' => '17.0',
}
app.build_configurations.each do |config|
  config.build_settings.merge!(common).merge!(
    'INFOPLIST_FILE' => 'FastCatTV/Info.plist',
    'CODE_SIGN_ENTITLEMENTS' => 'FastCatTV/FastCatTV.entitlements',
    'PRODUCT_BUNDLE_IDENTIFIER' => '$(FASTCAT_TV_BUNDLE_IDENTIFIER)',
    'PRODUCT_NAME' => 'FastCat',
  )
  if config.name == 'Debug'
    config.build_settings['EXCLUDED_EXPLICIT_TARGET_DEPENDENCIES[sdk=appletvsimulator*]'] = 'PacketTunnel'
    config.build_settings['EXCLUDED_SOURCE_FILE_NAMES[sdk=appletvsimulator*]'] = 'PacketTunnel.appex'
  end
end
tunnel.build_configurations.each do |config|
  config.build_settings.merge!(common).merge!(
    'INFOPLIST_FILE' => 'PacketTunnel/Info.plist',
    'CODE_SIGN_ENTITLEMENTS' => 'PacketTunnel/PacketTunnel.entitlements',
    'PRODUCT_BUNDLE_IDENTIFIER' => '$(FASTCAT_TV_BUNDLE_IDENTIFIER).PacketTunnel',
    'PRODUCT_NAME' => 'PacketTunnel',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_OBJC_BRIDGING_HEADER' => 'PacketTunnel/PacketTunnel-Bridging-Header.h',
    'FRAMEWORK_SEARCH_PATHS' => ['$(inherited)', '$(PROJECT_DIR)/Frameworks'],
    'OTHER_LDFLAGS' => ['$(inherited)', '-lclash', '-lresolv'],
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
  )
end

project.recreate_user_schemes
project.save
puts "✓ Generated #{project_path}"
