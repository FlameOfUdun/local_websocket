import 'dart:io';

import 'package:flutter_local_websocket/flutter_local_websocket.dart';

Future<String?> getLocalIpAddress() async {
  for (var interface in await NetworkInterface.list()) {
    for (var item in interface.addresses) {
      if (item.type == InternetAddressType.IPv4 && !item.isLoopback) {
        return item.host;
      }
    }
  }
  return null;
}

void main(List<String> args) async {
  final host = await getLocalIpAddress();
  if (host == null) {
    print('No local IP address found.');
    return;
  }

  final server = WebSocketServer(
    port: 8080,
    host: host,
  );
  await server.initialize();

  final client1 = WebsocketClient(server.address);
  await client1.initialize();
  client1.onMessage((message) {
    print('Client 1 received: $message');
  });

  final client2 = WebsocketClient(server.address);
  await client2.initialize();
  client2.onMessage((message) {
    print('Client 2 received: $message');
  });

  client1.send('Hello from Client 1!');
  client2.send('Hello from Client 2!');
}
