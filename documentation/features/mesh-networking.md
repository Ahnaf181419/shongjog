# Off-Grid Mesh Networking

## 1. Overview & Strategy

In major disasters (e.g. Cyclone Remal, severe coastal storm surges), terrestrial cell towers and internet services frequently suffer catastrophic collapse. Shongjog incorporates an off-grid peer-to-peer (P2P) mesh networking stack capable of operating without Wi-Fi routers, cellular data, or internet backbones.

- **Primary Transport**: Google Nearby Connections API configured with the `P2P_CLUSTER` strategy (enabling N-to-N dynamic ad-hoc mesh topologies over Bluetooth Low Energy, Bluetooth classic, and Wi-Fi Direct).
- **Fallback Transport**: GMS-free Wi-Fi Direct socket implementation for devices lacking Google Play Services.
- **Service Implementation**: [`lib/features/mesh_comm/`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/mesh_comm).

---

## 2. Supported Mesh Capabilities

| Mode | Format / Protocol | Description |
|---|---|---|
| **Text Messaging** | JSON Encoded Byte Stream | Real-time broadcast and targeted direct messaging between discovered peers. |
| **Media Sharing** | Chunked Stream / File Payload | Transmission of images, short situational videos, and compressed voice notes. |
| **Full-Duplex Voice Calls** | 8 kHz PCM / Opus Stream | Real-time bi-directional voice calling between paired handsets without carrier signal. |
| **Multi-Hop SOS Relay** | Epidemic Gossiping Protocol | Automated forwarding of life-critical distress signals across disconnected nodes. |

---

## 3. Full-Duplex Mesh Voice Calling

Shongjog implements real-time voice calling using a custom audio streaming pipeline ([`lib/core/audio_call_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/core/audio_call_service.dart)):

1. **Audio Sampling**: Audio input is captured via `record` or platform audio streams at **8,000 Hz, 16-bit Mono PCM** (optimized for human voice intelligibility while keeping bandwidth under 16 KB/sec).
2. **Packetization**: Audio frames are chunked into 20ms–40ms buffers with sequence headers to detect packet loss.
3. **Transport**: Streamed via Nearby Connections byte payloads.
4. **Playback**: Decoded and rendered via low-latency audio track buffers.
5. **Call Lifecycle & Dedup**: Inbound call requests pass through an active call state machine to prevent double-stacking call screens on rapid duplicate signals.

---

## 4. Multi-Hop SOS Relay Engine

When an isolated victim has no direct connection to rescue teams or coordinators, their SOS signal hops through intermediate civilian phones until it reaches an active gateway or coordinator.

```
[ Isolated Handset ] ──► [ Civilian Phone 1 ] ──► [ Civilian Phone 2 ] ──► [ Rescue Node / Online ]
   (Origin: Hop 0)             (Hop 1)                  (Hop 2)                 (Hop 3)
```

### Protocol Specifications (`SosPayload`)

Each SOS relay packet contains:
- `id`: Globally unique UUID generated at packet origination.
- `senderName`: User display name.
- `senderPhone`: Emergency contact phone number.
- `latitude` / `longitude`: Exact GPS coordinates with fix accuracy timestamp.
- `message`: Specific distress description (e.g., "Water rising rapidly, elderly family member stranded").
- `timestamp`: Unix millisecond creation timestamp.
- `hopCount`: Integer tracking number of retransmissions.

### Flood Control & Invariants

To avoid flooding the local radio spectrum:
1. **5-Hop Maximum Cap (`MAX_HOPS = 5`)**: Packets are dropped immediately once `hopCount >= 5`.
2. **1-Hour Time-To-Live (`TTL = 3600s`)**: Packets older than 60 minutes are discarded to prevent stale emergency traffic.
3. **256-Entry LRU Deduplication Cache**: The `SosRelayEngine` maintains an in-memory Least Recently Used (LRU) set of the last 256 seen `id`s. Any seen ID is immediately dropped, completely neutralizing broadcast loops.
4. **Autonomous Forwarding**: Devices forward valid packets in the background upon discovering new peers without requiring user interaction.
