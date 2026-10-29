/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/remote/atv_certificate.dart';
import 'package:xiaomi_remote/core/remote/atv_remote.dart';
import 'package:xiaomi_remote/core/remote/proto/remotemessage.pb.dart';

void main() {
  late List<RemoteMessage> sent;
  late AtvRemoteClient client;
  setUp(() {
    sent = [];
    client = AtvRemoteClient(
      host: 'unused',
      certificate: const AtvCertificate(certPem: '', privateKeyPem: ''),
      sendSink: sent.add,
    );
  });
  void receive(RemoteMessage message) =>
      client.handleMessage(RemoteMessage.fromBuffer(message.writeToBuffer()));

  test('ping echoes val1', () {
    receive(RemoteMessage(remotePingRequest: RemotePingRequest(val1: 42)));
    expect(sent.single.remotePingResponse.val1, 42);
  });
  test('IME uses key inject field counter and preserves Bangla', () {
    receive(
      RemoteMessage(
        remoteImeKeyInject: RemoteImeKeyInject(
          appInfo: RemoteAppInfo(
            counter: 7,
            label: 'Search',
            appPackage: 'app',
          ),
          textFieldStatus: RemoteTextFieldStatus(counterField: 13),
        ),
      ),
    );
    receive(
      RemoteMessage(
        remoteImeBatchEdit: RemoteImeBatchEdit(imeCounter: 1, fieldCounter: 0),
      ),
    );
    client.insertText('সংবাদ');
    final edit = RemoteMessage.fromBuffer(sent.single.writeToBuffer())
        .remoteImeBatchEdit;
    expect(edit.imeCounter, 7);
    expect(edit.fieldCounter, 13);
    expect(edit.editInfo.single.textFieldStatus.value, 'সংবাদ');
    expect(edit.editInfo.single.textFieldStatus.start, 'সংবাদ'.length - 1);
    expect(client.state.imeActive, isTrue);
    expect(client.state.currentApp, 'app');
  });
  test(
    'replaceText sends deletes for the changed tail, then the new tail',
    () async {
      receive(
        RemoteMessage(
          remoteImeKeyInject: RemoteImeKeyInject(
            appInfo: RemoteAppInfo(counter: 5),
            textFieldStatus: RemoteTextFieldStatus(
              counterField: 3,
              value: 'hello সংবাদ',
            ),
          ),
        ),
      );
      await client.replaceText('hello world');
      final deletes = sent.where((m) => m.hasRemoteKeyInject()).toList();
      expect(deletes, hasLength('সংবাদ'.runes.length));
      expect(
        deletes.every(
          (m) => m.remoteKeyInject.keyCode == RemoteKeyCode.KEYCODE_DEL,
        ),
        isTrue,
      );
      final edit = sent.last.remoteImeBatchEdit;
      expect(edit.imeCounter, 5);
      expect(edit.editInfo.single.textFieldStatus.value, 'world');
      expect(client.state.imeValue, 'hello world');
      sent.clear();
      await client.replaceText('hello world');
      expect(sent, isEmpty);
    },
  );
  test('rapid edits skip stale text and settle on the latest', () async {
    client.replaceText('h');
    client.replaceText('he');
    client.replaceText('hey');
    await client.textSettled;
    final edits = sent.where((m) => m.hasRemoteImeBatchEdit()).toList();
    expect(edits, hasLength(1));
    expect(
      edits.single.remoteImeBatchEdit.editInfo.single.textFieldStatus.value,
      'hey',
    );
    expect(client.state.imeValue, 'hey');
  });
  test('show request updates the field counter and value', () {
    receive(
      RemoteMessage(
        remoteImeShowRequest: RemoteImeShowRequest(
          remoteTextFieldStatus: RemoteTextFieldStatus(
            counterField: 16,
            value: 'try 5',
          ),
        ),
      ),
    );
    expect(client.state.imeValue, 'try 5');
    client.insertText('!');
    expect(sent.last.remoteImeBatchEdit.fieldCounter, 16);
  });
  test('IME positions count UTF-16 code units', () {
    client.insertText('a😀');
    final status =
        sent.single.remoteImeBatchEdit.editInfo.single.textFieldStatus;
    expect(status.start, 2);
    expect(status.end, 2);
  });
  test('volume updates state', () {
    receive(
      RemoteMessage(
        remoteSetVolumeLevel: RemoteSetVolumeLevel(
          volumeLevel: 8,
          volumeMax: 20,
          volumeMuted: true,
        ),
      ),
    );
    expect(client.state.volumeLevel, 8);
    expect(client.state.volumeMax, 20);
    expect(client.state.muted, isTrue);
  });
  test('configure intersects features', () {
    receive(
      RemoteMessage(remoteConfigure: RemoteConfigure(code1: 1 | 2 | 16 | 512)),
    );
    expect(sent.single.remoteConfigure.code1, 1 | 2 | 512);
    expect(sent.single.remoteConfigure.deviceInfo.packageName, 'xiaomi_remote');
    expect(client.state.supportedFeatures, 1 | 2 | 512);
  });
  test('voice handshake and chunk boundaries', () async {
    final future = client.startVoice();
    expect(sent.single.remoteKeyInject.keyCode, RemoteKeyCode.KEYCODE_SEARCH);
    receive(RemoteMessage(remoteVoiceBegin: RemoteVoiceBegin(sessionId: 7)));
    expect(await future, 7);
    expect(sent.last.remoteVoiceBegin.sessionId, 7);
    client.sendVoiceChunk(7, Uint8List(20 * 1024 + 1));
    expect(sent[sent.length - 2].remoteVoicePayload.samples.length, 20 * 1024);
    expect(sent.last.remoteVoicePayload.samples.length, 8 * 1024);
    client.endVoice(7);
    expect(sent.last.remoteVoiceEnd.sessionId, 7);
  });
}
