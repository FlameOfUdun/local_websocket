import 'package:local_websocket/local_websocket.dart';

void main(List<String> args) async {
  final server = Server(
    echo: false,
    details: {
      'name': 'Test Server',
    },
  );
  server.messageStream.listen((message) {
    print('Server received message: $message');
  });

  print('Starting server...');
  await server.start('127.0.0.1');
  print('Server started');

  print('Scanning for servers...');
  final result = await Scanner.scan("127.0.0.1").first;
  final path = result.firstOrNull?.path;
  if (path == null) {
    print('No servers found');
    return;
  }
  print('Found server at $path');

  final client1 = Client(
    details: {
      'name': 'Client 1',
    },
  );
  client1.messageStream.listen((message) {
    print('Client 1 received message: $message');
  });
  await client1.connect(path);
  print('Client 1 connected to server');

  final client2 = Client(
    details: {
      'name': 'Client 2',
    },
  );
  client2.messageStream.listen((message) {
    print('Client 2 received message: $message');
  });
  await client2.connect(path);
  print('Client 2 connected to server');

  await Future.delayed(Duration(seconds: 3));

  server.send('Hello from Server');
  await Future.delayed(Duration(seconds: 1));
  client1.send('Hello from Client 1');
  await Future.delayed(Duration(seconds: 1));
  client2.send('Hello from Client 2');
}
