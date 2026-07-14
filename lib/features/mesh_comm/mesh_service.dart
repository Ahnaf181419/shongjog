import 'dart:async';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

class MeshService {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  final String userName;
  
  final _peersController = StreamController<List<String>>.broadcast();
  final _messagesController = StreamController<MeshMessage>.broadcast();
  
  final List<String> _connectedPeers = [];
  
  MeshService({required this.userName});

  Stream<List<String>> get peers => _peersController.stream;
  Stream<MeshMessage> get messages => _messagesController.stream;

  Future<bool> requestPermissions() async {
    final b = await Nearby().checkBluetoothPermission();
    if (!b) {
      Nearby().askBluetoothPermission();
    }
    final l = await Nearby().checkLocationPermission();
    if (!l) {
      Nearby().askLocationPermission();
    }
    return await Nearby().checkBluetoothPermission() && await Nearby().checkLocationPermission();
  }

  Future<void> start() async {
    await requestPermissions();
    
    // Start advertising
    await Nearby().startAdvertising(
      userName,
      strategy,
      onConnectionInitiated: (id, info) {
        Nearby().acceptConnection(
          id,
          onPayLoadRecieved: (endid, payload) {
            if (payload.type == PayloadType.BYTES) {
              final str = String.fromCharCodes(payload.bytes!);
              _messagesController.add(MeshMessage(senderId: endid, text: str));
            }
          },
        );
      },
      onConnectionResult: (id, status) {
        if (status == Status.CONNECTED) {
          if (!_connectedPeers.contains(id)) {
            _connectedPeers.add(id);
            _peersController.add(_connectedPeers);
          }
        }
      },
      onDisconnected: (id) {
        _connectedPeers.remove(id);
        _peersController.add(_connectedPeers);
      },
    );

    // Start discovery
    await Nearby().startDiscovery(
      userName,
      strategy,
      onEndpointFound: (id, name, serviceId) {
        // Automatically request connection
        Nearby().requestConnection(
          userName,
          id,
          onConnectionInitiated: (id, info) {
            Nearby().acceptConnection(
              id,
              onPayLoadRecieved: (endid, payload) {
                if (payload.type == PayloadType.BYTES) {
                  final str = String.fromCharCodes(payload.bytes!);
                  _messagesController.add(MeshMessage(senderId: endid, text: str));
                }
              },
            );
          },
          onConnectionResult: (id, status) {
            if (status == Status.CONNECTED) {
              if (!_connectedPeers.contains(id)) {
                _connectedPeers.add(id);
                _peersController.add(_connectedPeers);
              }
            }
          },
          onDisconnected: (id) {
            _connectedPeers.remove(id);
            _peersController.add(_connectedPeers);
          },
        );
      },
      onEndpointLost: (id) {
        _connectedPeers.remove(id);
        _peersController.add(_connectedPeers);
      },
    );
  }

  Future<void> stop() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _connectedPeers.clear();
    _peersController.add(_connectedPeers);
  }

  void sendMessage(String text) {
    if (_connectedPeers.isEmpty) return;
    for (final peer in _connectedPeers) {
      Nearby().sendBytesPayload(peer, Uint8List.fromList(text.codeUnits));
    }
  }
}

class MeshMessage {
  final String senderId;
  final String text;
  MeshMessage({required this.senderId, required this.text});
}
