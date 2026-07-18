import 'dart:async';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView>
    with PageMixin {
  final _connectionsStateNotifier = ValueNotifier<ConnectionsState>(
    const ConnectionsState(),
  );
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  Timer? timer;
  bool _isClosingAll = false;
  final Set<String> _closingConnectionIds = <String>{};

  Future<void> _handleCloseAllConnections() async {
    if (_isClosingAll) return;
    setState(() => _isClosingAll = true);
    try {
      await clashCore.closeConnections();
      _connectionsStateNotifier.value =
          _connectionsStateNotifier.value.copyWith(
        connections: await clashCore.getConnections(),
      );
    } finally {
      if (mounted) setState(() => _isClosingAll = false);
    }
  }

  @override
  List<Widget> get actions => [
        IconButton(
          onPressed: _isClosingAll ? null : _handleCloseAllConnections,
          icon: _isClosingAll
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep_outlined),
        ),
      ];

  @override
  get onSearch => (value) {
        _connectionsStateNotifier.value =
            _connectionsStateNotifier.value.copyWith(
          query: value,
        );
      };

  @override
  get onKeywordsUpdate => (keywords) {
        _connectionsStateNotifier.value =
            _connectionsStateNotifier.value.copyWith(keywords: keywords);
      };

  _updateConnections() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _connectionsStateNotifier.value =
            _connectionsStateNotifier.value.copyWith(
          connections: await clashCore.getConnections(),
        );
        timer = Timer(Duration(seconds: 1), () async {
          _updateConnections();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      isCurrentPageProvider(
        PageLabel.connections,
        handler: (pageLabel, viewMode) =>
            pageLabel == PageLabel.tools && viewMode == ViewMode.mobile,
      ),
      (prev, next) {
        if (prev != next && next == true) {
          initPageState();
        }
      },
      fireImmediately: true,
    );
    _updateConnections();
  }

  Future<void> _handleBlockConnection(String id) async {
    if (_closingConnectionIds.contains(id) || _isClosingAll) return;
    setState(() => _closingConnectionIds.add(id));
    try {
      await clashCore.closeConnection(id);
      _connectionsStateNotifier.value =
          _connectionsStateNotifier.value.copyWith(
        connections: await clashCore.getConnections(),
      );
    } finally {
      if (mounted) setState(() => _closingConnectionIds.remove(id));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _connectionsStateNotifier.dispose();
    _scrollController.dispose();
    timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectionsState>(
      valueListenable: _connectionsStateNotifier,
      builder: (_, state, __) {
        final connections = state.list;
        if (connections.isEmpty) {
          return NullStatus(
            label: appLocalizations.nullTip(appLocalizations.connections),
          );
        }
        return CommonScrollBar(
          controller: _scrollController,
          child: ListView.separated(
            controller: _scrollController,
            itemBuilder: (_, index) {
              final connection = connections[index];
              return ConnectionItem(
                key: Key(connection.id),
                connection: connection,
                onClickKeyword: (value) {
                  context.commonScaffoldState?.addKeyword(value);
                },
                trailing: IconButton(
                  icon: _closingConnectionIds.contains(connection.id)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.block),
                  onPressed: _isClosingAll ||
                          _closingConnectionIds.contains(connection.id)
                      ? null
                      : () => _handleBlockConnection(connection.id),
                ),
              );
            },
            separatorBuilder: (BuildContext context, int index) {
              return const Divider(
                height: 0,
              );
            },
            itemCount: connections.length,
          ),
        );
      },
    );
  }
}
