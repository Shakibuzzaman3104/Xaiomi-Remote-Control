/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery/tv_discovery.dart';
import '../storage/paired_tv_store.dart';
import 'pairing_flow.dart';
import 'tv_session.dart';

final pairedTvStoreProvider = Provider<PairedTvStore>(
  (ref) => PairedTvStore(SecureKeyValueStore()),
);

final tvDiscoveryProvider = Provider<TvDiscovery>((ref) {
  final discovery = TvDiscovery();
  ref.onDispose(() => unawaited(discovery.stop()));
  return discovery;
});

final discoveredTvsProvider = StreamProvider<List<DiscoveredTv>>((ref) {
  final discovery = ref.watch(tvDiscoveryProvider);
  return Stream.multi((controller) {
    final subscription = discovery.devices.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
    unawaited(
      discovery.start().catchError((Object error, StackTrace stack) {
        controller.addError(error, stack);
      }),
    );
  });
});

class PairedTvsState {
  const PairedTvsState({required this.tvs, this.lastUsedId});
  final List<PairedTv> tvs;
  final String? lastUsedId;
}

class PairedTvs extends AsyncNotifier<PairedTvsState> {
  @override
  Future<PairedTvsState> build() async {
    final store = ref.watch(pairedTvStoreProvider);
    final tvs = await store.loadAll();
    final lastUsedId = await store.loadLastUsedId();
    return PairedTvsState(tvs: tvs, lastUsedId: lastUsedId);
  }

  Future<void> add(PairedTv tv) async {
    final store = ref.read(pairedTvStoreProvider);
    await store.save(tv);
    await select(tv.id);
  }

  Future<void> updatePairedTv(PairedTv tv) async {
    await ref.read(pairedTvStoreProvider).save(tv);
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      PairedTvsState(
        tvs: [
          for (final saved in current.tvs)
            if (saved.id == tv.id) tv else saved,
        ],
        lastUsedId: current.lastUsedId,
      ),
    );
  }

  Future<void> remove(String id) async {
    final store = ref.read(pairedTvStoreProvider);
    await store.remove(id);
    final tvs = await store.loadAll();
    final selected = await store.loadLastUsedId();
    if (selected == id) await store.saveLastUsedId('');
    state = AsyncData(
      PairedTvsState(tvs: tvs, lastUsedId: selected == id ? null : selected),
    );
  }

  Future<void> select(String id) async {
    final store = ref.read(pairedTvStoreProvider);
    await store.saveLastUsedId(id);
    state = AsyncData(
      PairedTvsState(tvs: await store.loadAll(), lastUsedId: id),
    );
  }
}

final pairedTvsProvider = AsyncNotifierProvider<PairedTvs, PairedTvsState>(
  PairedTvs.new,
);

final activeTvProvider = Provider<PairedTv?>((ref) {
  final paired = ref.watch(pairedTvsProvider).asData?.value;
  if (paired == null) return null;
  for (final tv in paired.tvs) {
    if (tv.id == paired.lastUsedId) return tv;
  }
  return null;
});

final tvSessionProvider = Provider<TvSession?>((ref) {
  ref.watch(
    activeTvProvider.select((tv) => tv == null ? null : (tv.id, tv.certPem)),
  );
  final tv = ref.read(activeTvProvider);
  if (tv == null) return null;
  final session = TvSession(
    tv: tv,
    onTvUpdated: (updated) =>
        ref.read(pairedTvsProvider.notifier).updatePairedTv(updated),
    resolveHost: (tv) async {
      final discovery = ref.read(tvDiscoveryProvider);
      try {
        await discovery.start();
        final name = tv.serviceName ?? tv.name;
        final devices = await discovery.devices
            .firstWhere(
              (devices) => devices.any(
                (device) =>
                    device.host != tv.host &&
                    (device.name == name || device.friendlyName == name),
              ),
            )
            .timeout(const Duration(seconds: 4), onTimeout: () => []);
        for (final device in devices) {
          if (device.host != tv.host &&
              (device.name == name || device.friendlyName == name)) {
            return device.host;
          }
        }
      } catch (_) {
        return null;
      }
      return null;
    },
  );
  ref.onDispose(() => unawaited(session.dispose()));
  unawaited(session.start());
  return session;
});

final tvSessionStateProvider = StreamProvider<TvSessionState>((ref) {
  final session = ref.watch(tvSessionProvider);
  if (session == null) return const Stream.empty();
  return Stream.multi((controller) {
    final subscription = session.states.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(session.state);
    controller.onCancel = subscription.cancel;
  });
});

final pairingFlowProvider = Provider<PairingFlow>((ref) {
  final flow = PairingFlow(store: ref.watch(pairedTvStoreProvider));
  ref.onDispose(() => unawaited(flow.cancel()));
  return flow;
});
