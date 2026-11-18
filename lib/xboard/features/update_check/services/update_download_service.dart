import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/update_artifact.dart';

enum UpdatePhase { idle, downloading, verifying, ready, paused, failed }

class UpdateDownloadState {
  const UpdateDownloadState(
      {this.phase = UpdatePhase.idle,
      this.received = 0,
      this.total,
      this.file,
      this.identity,
      this.error});
  final UpdatePhase phase;
  final int received;
  final int? total;
  final File? file;
  final String? identity, error;
  bool get busy =>
      phase == UpdatePhase.downloading || phase == UpdatePhase.verifying;
}

final updateDownloadProvider =
    StateNotifierProvider<UpdateDownloadService, UpdateDownloadState>((ref) {
  final service = UpdateDownloadService();
  ref.onDispose(service.cancel);
  return service;
});

/// One application-scoped job; .part files survive dialog dismissal/restarts.
/// Only a verified complete file is exposed to the installer.
class UpdateDownloadService extends StateNotifier<UpdateDownloadState> {
  UpdateDownloadService({this.directory, this.allowHttpForTests = false})
      : super(const UpdateDownloadState());
  final Directory? directory;
  final bool allowHttpForTests;
  HttpClientRequest? _request;
  HttpClient? _client;
  int _generation = 0;
  bool _running = false;
  String identity(UpdateArtifact artifact) =>
      '${artifact.sha256}.${artifact.type}';
  void cancel() {
    _generation++;
    _request?.abort();
    _client?.close(force: true);
    if (mounted && state.busy) {
      state = UpdateDownloadState(
          phase: UpdatePhase.paused,
          received: state.received,
          total: state.total,
          identity: state.identity);
    }
  }

  bool _safe(Uri uri) =>
      uri.userInfo.isEmpty &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'https' || (allowHttpForTests && uri.scheme == 'http'));
  Future<HttpClientResponse> _open(Uri url, int offset) async {
    var target = url;
    for (var redirect = 0; redirect <= 5; redirect++) {
      if (!_safe(target)) {
        throw const FormatException('unsafe_url');
      }
      final request =
          await _client!.getUrl(target).timeout(const Duration(seconds: 20));
      _request = request;
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>().timeout(const Duration(seconds: 10));
        if (location == null) {
          throw const FormatException('redirect');
        }
        target = target.resolve(location);
        continue;
      }
      return response;
    }
    throw const FormatException('redirect_limit');
  }

  Future<bool> _verify(File file, UpdateArtifact artifact) async {
    if (artifact.size != null && await file.length() != artifact.size) {
      return false;
    }
    if ((await sha256.bind(file.openRead()).first).toString() !=
        artifact.sha256) {
      return false;
    }
    final reader = await file.open();
    try {
      final bytes = await reader.read(12);
      final prefix = String.fromCharCodes(bytes);
      switch (artifact.type) {
        case 'apk':
          return bytes.length >= 4 &&
              bytes[0] == 0x50 &&
              bytes[1] == 0x4b &&
              bytes[2] == 3 &&
              bytes[3] == 4;
        case 'exe':
          return prefix.startsWith('MZ');
        case 'deb':
          return prefix.startsWith('!<arch>\n');
        case 'rpm':
          return bytes.length >= 4 &&
              bytes[0] == 0xed &&
              bytes[1] == 0xab &&
              bytes[2] == 0xee &&
              bytes[3] == 0xdb;
        case 'appimage':
          return bytes.length >= 11 &&
              prefix.startsWith('\u007fELF') &&
              bytes[8] == 65 &&
              bytes[9] == 73;
        case 'dmg':
          final length = await file.length();
          if (length < 512) {
            return false;
          }
          await reader.setPosition(length - 512);
          return String.fromCharCodes(await reader.read(4)) == 'koly';
        default:
          return false;
      }
    } finally {
      await reader.close();
    }
  }

  Future<File?> start(UpdateArtifact artifact) async {
    if (_running) {
      return null;
    }
    final generation = ++_generation;
    final id = identity(artifact);
    _running = true;
    File? part;
    try {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(artifact.sha256) ||
          !['apk', 'exe', 'dmg', 'deb', 'rpm', 'appimage']
              .contains(artifact.type) ||
          (artifact.size != null &&
              (artifact.size! <= 0 ||
                  artifact.size! > 2 * 1024 * 1024 * 1024))) {
        throw const FormatException('metadata');
      }
      final root = directory ??
          Directory(
              p.join((await getApplicationSupportDirectory()).path, 'updates'));
      await root.create(recursive: true);
      if (generation != _generation) {
        return null;
      }
      final complete = File(p.join(root.path, id));
      part = File('${complete.path}.part');
      state = UpdateDownloadState(phase: UpdatePhase.verifying, identity: id);
      if (await complete.exists()) {
        if (await _verify(complete, artifact)) {
          if (generation != _generation) {
            return null;
          }
          state = UpdateDownloadState(
              phase: UpdatePhase.ready,
              file: complete,
              identity: id,
              received: await complete.length(),
              total: await complete.length());
          return complete;
        }
        await complete.delete();
      }
      Object? lastError;
      for (final address in [artifact.url, ...artifact.mirrors]) {
        if (generation != _generation) {
          return null;
        }
        _client = HttpClient()
          ..autoUncompress = false
          ..connectionTimeout = const Duration(seconds: 20);
        try {
          var offset = await part.exists() ? await part.length() : 0;
          if (artifact.size != null && offset > artifact.size!) {
            await part.delete();
            offset = 0;
          }
          var response = await _open(Uri.parse(address), offset);
          if (generation != _generation) {
            return null;
          }
          if (response.statusCode == 416) {
            await response.drain<void>().timeout(const Duration(seconds: 10));
            if (await part.exists() && await _verify(part, artifact)) {
              if (generation != _generation) {
                return null;
              }
              await part.rename(complete.path);
              if (generation != _generation) return null;
              state = UpdateDownloadState(
                  phase: UpdatePhase.ready,
                  file: complete,
                  identity: id,
                  received: await complete.length(),
                  total: await complete.length());
              return complete;
            }
            if (await part.exists()) {
              await part.delete();
            }
            offset = 0;
            response = await _open(Uri.parse(address), 0);
          }
          if (![200, 206].contains(response.statusCode)) {
            throw HttpException('download_status_${response.statusCode}');
          }
          if (response.headers.contentType?.mimeType == 'text/html') {
            throw const FormatException('not_installer');
          }
          if (response.statusCode == 206) {
            final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
                .firstMatch(response.headers.value('content-range') ?? '');
            if (range == null ||
                int.parse(range[1]!) != offset ||
                (artifact.size != null &&
                    int.parse(range[3]!) != artifact.size)) {
              throw const FormatException('range');
            }
          } else {
            offset = 0;
          }
          final total = artifact.size ??
              (response.contentLength > 0
                  ? offset + response.contentLength
                  : null);
          final sink = await part.open(
              mode: offset > 0 ? FileMode.append : FileMode.write);
          if (generation != _generation) {
            await sink.close();
            return null;
          }
          var received = offset;
          var last = DateTime.fromMillisecondsSinceEpoch(0);
          state = UpdateDownloadState(
              phase: UpdatePhase.downloading,
              received: received,
              total: total,
              identity: id);
          try {
            await for (final chunk
                in response.timeout(const Duration(seconds: 30))) {
              if (generation != _generation) {
                return null;
              }
              received += chunk.length;
              if (total != null && received > total) {
                throw const FormatException('size');
              }
              if (received > 2 * 1024 * 1024 * 1024) {
                throw const FormatException('size');
              }
              await sink.writeFrom(chunk);
              if (DateTime.now().difference(last).inMilliseconds >= 100) {
                last = DateTime.now();
                state = UpdateDownloadState(
                    phase: UpdatePhase.downloading,
                    received: received,
                    total: total,
                    identity: id);
              }
            }
          } finally {
            await sink.flush();
            await sink.close();
          }
          if (generation != _generation) {
            return null;
          }
          state = UpdateDownloadState(
              phase: UpdatePhase.verifying,
              received: received,
              total: total,
              identity: id);
          if (!await _verify(part, artifact)) {
            await part.delete();
            throw const FormatException('integrity');
          }
          if (generation != _generation) {
            return null;
          }
          await part.rename(complete.path);
          if (generation != _generation) return null;
          state = UpdateDownloadState(
              phase: UpdatePhase.ready,
              file: complete,
              identity: id,
              received: received,
              total: received);
          return complete;
        } catch (error) {
          lastError = error;
        } finally {
          _client?.close(force: true);
          _client = null;
        }
      }
      throw lastError ?? const FormatException('download');
    } catch (error) {
      if (mounted && generation == _generation) {
        state = UpdateDownloadState(
            phase: UpdatePhase.failed,
            identity: id,
            error: error is FormatException
                ? error.message
                : error is TimeoutException
                    ? 'timeout'
                    : error is FileSystemException
                        ? 'storage'
                        : 'network',
            received: state.received,
            total: state.total);
      }
      return null;
    } finally {
      _running = false;
      _request = null;
      _client?.close(force: true);
      _client = null;
    }
  }
}
