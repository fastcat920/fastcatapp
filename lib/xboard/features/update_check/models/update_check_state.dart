import 'update_artifact.dart';

class UpdateCheckState {
  final UpdateArtifact? artifact;
  final int? build;
  final bool trusted;
  final bool isChecking;
  final bool hasUpdate;
  final String? currentVersion;
  final String? latestVersion;
  final String? updateUrl;
  final String? releaseNotes;
  final bool forceUpdate;
  final String? error;
  const UpdateCheckState({
    this.artifact,
    this.build,
    this.trusted = false,
    this.isChecking = false,
    this.hasUpdate = false,
    this.currentVersion,
    this.latestVersion,
    this.updateUrl,
    this.releaseNotes,
    this.forceUpdate = false,
    this.error,
  });
  static const _unset = Object();
  String get releaseIdentity => '${latestVersion ?? ""}+${build ?? ""}';
  UpdateCheckState copyWith({
    Object? artifact = _unset,
    Object? build = _unset,
    bool? trusted,
    bool? isChecking,
    bool? hasUpdate,
    String? currentVersion,
    String? latestVersion,
    String? updateUrl,
    String? releaseNotes,
    bool? forceUpdate,
    String? error,
  }) {
    return UpdateCheckState(
      artifact: identical(artifact, _unset)
          ? this.artifact
          : artifact as UpdateArtifact?,
      build: identical(build, _unset) ? this.build : build as int?,
      trusted: trusted ?? this.trusted,
      isChecking: isChecking ?? this.isChecking,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      updateUrl: updateUrl ?? this.updateUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      error: error,
    );
  }
}
