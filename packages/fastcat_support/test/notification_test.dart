import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fastcat_support/fastcat_support.dart';
void main() {
 test('server unread snapshot restores own receipts and rejects stale responses', () async {
  var snapshot=<String,dynamic>{'unreadCount':8,'ownReadSeq':18,'unreadLastSeq':26};
  final client=FastCatClient(baseUrl:Uri.parse('https://support.example.com'),appKey:'sdk',client:MockClient((request) async {
   if(request.url.path.endsWith('/start')) return http.Response('{"id":"c","token":"t"}',201);
   if(request.url.path.endsWith('/status')) return http.Response(jsonEncode(snapshot),200);
   if(request.url.path.endsWith('/receipts')) return http.Response(jsonEncode({'unreadCount':0,'ownReadSeq':26,'unreadLastSeq':26}),200);
   return http.Response(jsonEncode({'messages':[
    for(var i=1;i<=26;i++) {'id':'m$i','seq':i,'role':'agent','source':'manual'},
    {'id':'welcome','seq':27,'role':'agent','source':'welcome'},
    {'id':'note','seq':28,'role':'note'},
   ],'receipts':{'unreadCount':8,'ownReadSeq':18,'unreadLastSeq':28},'hasMore':false,'nextCursor':28}),200);
  }));
  await client.start(email:'user@example.com');
  await client.pushStatus();
  expect(client.unreadCount,8);
  expect(client.readCursor,18);
  await client.watch().take(1).drain<void>();
  expect(client.unreadCount,8);
  await client.acknowledge(deliveredSeq:26,readSeq:26);
  expect(client.unreadCount,0);
  await client.pushStatus(); // A delayed pre-read status must not restore 8.
  expect(client.unreadCount,0);
  snapshot={'unreadCount':1,'ownReadSeq':26,'unreadLastSeq':29};
  await client.pushStatus();
  expect(client.unreadCount,1);
  snapshot={'unreadCount':8,'ownReadSeq':18,'unreadLastSeq':28};
  await client.pushStatus();
  expect(client.unreadCount,1);
  client.close();
 });
 test('history is silent, new messages deduplicate and read cursor clears unread', () async {
  var pages=0;
  final client=FastCatClient(baseUrl:Uri.parse('https://support.example.com'),appKey:'sdk',client:MockClient((request) async {
   if(request.url.path.endsWith('/start')) return http.Response('{"id":"c","token":"t"}',201);
   if(request.url.path.endsWith('/receipts')) return http.Response('{}',200);
   pages++;
   final messages=[{'id':'one','seq':1,'role':'agent','source':'staff'},if(pages>1){'id':'two','seq':2,'role':'agent','source':'ai'}];
   return http.Response(jsonEncode({'messages':messages,'nextCursor':pages,'hasMore':false}),200);
  }));
  await client.start(email:'user@example.com');
  final incoming=<Map<String,dynamic>>[];
  final subscription=client.incomingMessageStream.listen(incoming.add);
  await client.watch(interval:Duration.zero).take(3).drain<void>();
  await Future<void>.delayed(Duration.zero);
  expect(client.unreadCount,2);
  expect(incoming.map((m)=>m['seq']),[2]);
  await client.acknowledge(deliveredSeq:2,readSeq:2);
  expect(client.unreadCount,0);
  await subscription.cancel(); client.close();
 });
}
