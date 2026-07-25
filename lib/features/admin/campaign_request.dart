import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shongjog/l10n/app_localizations.dart';

enum CampaignType {
  foodDonation,
  rescueOperation,
  medicalCamp,
  shelterSupport,
  clothingDonation,
  waterSupply;

  String label(BuildContext context) => switch (this) {
    CampaignType.foodDonation => AppLocalizations.of(context).campaignTypeFoodDonation,
    CampaignType.rescueOperation => AppLocalizations.of(context).campaignTypeRescue,
    CampaignType.medicalCamp => AppLocalizations.of(context).campaignTypeMedical,
    CampaignType.shelterSupport => AppLocalizations.of(context).campaignTypeShelter,
    CampaignType.clothingDonation => AppLocalizations.of(context).campaignTypeClothing,
    CampaignType.waterSupply => AppLocalizations.of(context).campaignTypeWater,
  };
}

enum CampaignStatus {
  pending,
  approved,
  rejected;

  String label(BuildContext context) => switch (this) {
    CampaignStatus.pending => AppLocalizations.of(context).campaignStatusPending,
    CampaignStatus.approved => AppLocalizations.of(context).campaignStatusApproved,
    CampaignStatus.rejected => AppLocalizations.of(context).campaignStatusRejected,
  };
}

class CampaignRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final CampaignType type;
  final double latitude;
  final double longitude;
  final String address;
  final String landmark;
  final String description;
  final DateTime timestamp;
  CampaignStatus status;
  String? adminNotes;
  DateTime? reviewedAt;

  CampaignRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.landmark = '',
    required this.description,
    required this.timestamp,
    this.status = CampaignStatus.pending,
    this.adminNotes,
    this.reviewedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'type': type.index,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'landmark': landmark,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'status': status.index,
        'adminNotes': adminNotes,
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  factory CampaignRequest.fromJson(Map<String, dynamic> json) => CampaignRequest(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        userPhone: json['userPhone'] as String? ?? '',
        type: CampaignType.values[json['type'] as int? ?? 0],
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        address: json['address'] as String? ?? '',
        landmark: json['landmark'] as String? ?? '',
        description: json['description'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        status: CampaignStatus.values[json['status'] as int? ?? 0],
        adminNotes: json['adminNotes'] as String?,
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.tryParse(json['reviewedAt'] as String)
            : null,
      );

  CampaignRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhone,
    CampaignType? type,
    double? latitude,
    double? longitude,
    String? address,
    String? landmark,
    String? description,
    DateTime? timestamp,
    CampaignStatus? status,
    String? adminNotes,
    DateTime? reviewedAt,
  }) =>
      CampaignRequest(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        userPhone: userPhone ?? this.userPhone,
        type: type ?? this.type,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        address: address ?? this.address,
        landmark: landmark ?? this.landmark,
        description: description ?? this.description,
        timestamp: timestamp ?? this.timestamp,
        status: status ?? this.status,
        adminNotes: adminNotes ?? this.adminNotes,
        reviewedAt: reviewedAt ?? this.reviewedAt,
      );
}

class CampaignRequestService extends ChangeNotifier {
  CampaignRequestService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  static const _fileName = 'campaign_requests.json';
  static const _collection = 'campaigns';

  @visibleForTesting
  static String? debugFilesDirOverride;

  // Resolved lazily via [_firestore] below, NOT eagerly in the constructor.
  // This service is a top-level global singleton constructed at library
  // load time, before `Firebase.initializeApp()` runs in `main()` —
  // eagerly touching `FirebaseFirestore.instance` here would throw
  // synchronously (no Firebase app yet) and crash app boot.
  final FirebaseFirestore? _injectedFirestore;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;

  List<CampaignRequest> _requests = [];
  List<CampaignRequest> get requests => List.unmodifiable(_requests);

  List<CampaignRequest> get pendingRequests =>
      _requests.where((r) => r.status == CampaignStatus.pending).toList();

  List<CampaignRequest> get approvedRequests =>
      _requests.where((r) => r.status == CampaignStatus.approved).toList();

  int get pendingCount => pendingRequests.length;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<File> _file() async {
    final dir = debugFilesDirOverride ??
        (await getApplicationDocumentsDirectory()).path;
    return File('$dir/$_fileName');
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        final raw = await f.readAsString();
        final list = jsonDecode(raw) as List;
        _requests = list
            .map((e) => CampaignRequest.fromJson(e as Map<String, dynamic>))
            .toList();
        _requests.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      debugPrint('CampaignRequestService init failed: $e');
    }
    _initialized = true;
    notifyListeners();
    _subscribeFirestore();
  }

  /// Listen for cross-device campaign requests. The local JSON cache
  /// (loaded above) paints instantly on cold start; this stream keeps it
  /// live and in sync with what other devices submitted or an admin
  /// approved elsewhere. Best-effort — a failure here (offline, no
  /// Firebase project reachable) leaves the app on local-only data.
  void _subscribeFirestore() {
    try {
      _firestoreSub = _firestore
          .collection(_collection)
          .snapshots()
          .listen(_mergeFirestoreSnapshot, onError: (e) {
        debugPrint('CampaignRequestService Firestore stream failed: $e');
      });
    } catch (e) {
      debugPrint('CampaignRequestService Firestore subscribe failed: $e');
    }
  }

  void _mergeFirestoreSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final doc in snap.docs) {
      final incoming = CampaignRequest.fromJson(doc.data());
      final index = _requests.indexWhere((r) => r.id == incoming.id);
      if (index == -1) {
        _requests.add(incoming);
      } else {
        _requests[index] = incoming;
      }
    }
    _requests.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    unawaited(_save());
    notifyListeners();
  }

  Future<void> submitRequest(CampaignRequest request) async {
    await initialize();
    _requests.insert(0, request);
    await _save();
    notifyListeners();
    try {
      await _firestore
          .collection(_collection)
          .doc(request.id)
          .set(request.toJson());
    } catch (e) {
      debugPrint('CampaignRequestService: Firestore submit failed: $e');
    }
  }

  Future<void> updateRequestStatus(
    String requestId,
    CampaignStatus status, {
    String? adminNotes,
  }) async {
    await initialize();
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    final updated = _requests[index].copyWith(
      status: status,
      adminNotes: adminNotes,
      reviewedAt: DateTime.now(),
    );
    _requests[index] = updated;
    await _save();
    notifyListeners();
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'status': updated.status.index,
        'adminNotes': updated.adminNotes,
        'reviewedAt': updated.reviewedAt?.toIso8601String(),
      });
    } catch (e) {
      debugPrint('CampaignRequestService: Firestore status update failed: $e');
    }
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      final raw = jsonEncode(_requests.map((r) => r.toJson()).toList());
      await f.writeAsString(raw);
    } catch (e) {
      debugPrint('CampaignRequestService save failed: $e');
    }
  }

  Future<void> clear() async {
    _requests.clear();
    try {
      final f = await _file();
      if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('CampaignRequestService clear failed: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }
}

final campaignRequestService = CampaignRequestService();