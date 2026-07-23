import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum CampaignType {
  foodDonation('খাদ্য দান'),
  rescueOperation('উদ্ধার আপারেশন'),
  medicalCamp('চিকিৎসা শিবির'),
  shelterSupport('আশ্রয় সহায়তা'),
  clothingDonation('পোশাক দান'),
  waterSupply('পানি সরবরাহ');

  final String labelBn;
  const CampaignType(this.labelBn);
}

enum CampaignStatus {
  pending('অপেক্ষমান'),
  approved('অনুমোদিত'),
  rejected('প্রত্যাখ্যাত');

  final String labelBn;
  const CampaignStatus(this.labelBn);
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
  static const _fileName = 'campaign_requests.json';

  @visibleForTesting
  static String? debugFilesDirOverride;

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
  }

  Future<void> submitRequest(CampaignRequest request) async {
    await initialize();
    _requests.insert(0, request);
    await _save();
    notifyListeners();
  }

  Future<void> updateRequestStatus(
    String requestId,
    CampaignStatus status, {
    String? adminNotes,
  }) async {
    await initialize();
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    _requests[index] = _requests[index].copyWith(
      status: status,
      adminNotes: adminNotes,
      reviewedAt: DateTime.now(),
    );
    await _save();
    notifyListeners();
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
}

final campaignRequestService = CampaignRequestService();