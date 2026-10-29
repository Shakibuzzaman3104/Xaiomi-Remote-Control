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
  final tv = ref.watch(activeTvProvider);
  if (tv == null) return null;
  final session = TvSession(tv: tv);
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

final pairingFlowProvider = Provider<PairingFlow>(
  (ref) => PairingFlow(store: ref.watch(pairedTvStoreProvider)),
);
