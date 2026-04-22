class TaskModel {
  const TaskModel({
    this.id,
    this.cloudId,
    this.userId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  final int? id;
  final String? cloudId;
  final String? userId;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;

  TaskModel copyWith({
    int? id,
    String? cloudId,
    String? userId,
    String? title,
    String? description,
    String? status,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return <String, dynamic>{
      'id': id,
      'cloudId': cloudId,
      'userId': userId,
      'title': title,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreMap(String userId) {
    return <String, dynamic>{
      'id': id,
      'cloudId': cloudId,
      'userId': userId,
      'title': title,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskModel.fromSqliteMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as int?,
      cloudId: map['cloudId'] as String?,
      userId: map['userId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory TaskModel.fromFirestoreMap(Map<String, dynamic> map, String docId) {
    return TaskModel(
      id: map['id'] as int?,
      cloudId: (map['cloudId'] as String?) ?? docId,
      userId: map['userId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
