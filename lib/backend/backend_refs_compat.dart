import 'dart:async';

Never _disabled() => throw UnsupportedError(
      'Direct data runtime is disabled. Use MTaxi backend API instead.',
    );

class BackendRefs {
  BackendRefs._();

  static final BackendRefs instance = BackendRefs._();

  DocumentReference<Map<String, dynamic>> doc(String path) =>
      DocumentReference<Map<String, dynamic>>._(path);

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      CollectionReference<Map<String, dynamic>>._(path);
}

class DocumentReference<T extends Object?> {
  DocumentReference._(this.path);

  final String path;

  String get id {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }

  CollectionReference<Map<String, dynamic>> get parent {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    final parentPath =
        parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : '';
    return CollectionReference<Map<String, dynamic>>._(parentPath);
  }

  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      CollectionReference<Map<String, dynamic>>._('$path/$collectionPath');

  Stream<DocumentSnapshot<T>> snapshots() => _disabled();

  Future<DocumentSnapshot<T>> get() => _disabled();

  Future<void> set(T data, [SetOptions? options]) => _disabled();

  Future<void> update(Map<Object, Object?> data) => _disabled();

  Future<void> delete() => _disabled();

  @override
  String toString() => 'DocumentReference($path)';

  @override
  bool operator ==(Object other) =>
      other is DocumentReference && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class CollectionReference<T extends Object?> extends Query<T> {
  CollectionReference._(super.path) : super._();

  DocumentReference<Map<String, dynamic>>? get parent {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length < 2) {
      return null;
    }
    return DocumentReference<Map<String, dynamic>>._(
      parts.sublist(0, parts.length - 1).join('/'),
    );
  }

  DocumentReference<T> doc([String? documentPath]) {
    final id = documentPath?.trim().isNotEmpty == true
        ? documentPath!.trim()
        : DateTime.now().microsecondsSinceEpoch.toString();
    return DocumentReference<T>._('$path/$id');
  }

  Future<DocumentReference<T>> add(T data) => _disabled();
}

class Query<T extends Object?> {
  Query._(this.path);

  final String path;

  Query<T> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List<Object?>? arrayContainsAny,
    List<Object?>? whereIn,
    List<Object?>? whereNotIn,
    bool? isNull,
  }) =>
      this;

  Query<T> orderBy(Object field, {bool descending = false}) => this;

  Query<T> limit(int limit) => this;

  Query<T> limitToLast(int limit) => this;

  Query<T> startAfterDocument(DocumentSnapshot<Object?> snapshot) => this;

  Query<T> startAtDocument(DocumentSnapshot<Object?> snapshot) => this;

  Query<T> startAfter(List<Object?> values) => this;

  Query<T> startAt(List<Object?> values) => this;

  Query<T> endBefore(List<Object?> values) => this;

  Query<T> endAt(List<Object?> values) => this;

  Stream<QuerySnapshot<T>> snapshots() => _disabled();

  Future<QuerySnapshot<T>> get() => _disabled();

  AggregateQuery count() => AggregateQuery._();

  @override
  String toString() => 'Query($path)';
}

class DocumentSnapshot<T extends Object?> {
  DocumentSnapshot(this.reference, this._data, {this.exists = true});

  final DocumentReference<T> reference;
  final T? _data;
  final bool exists;

  String get id => reference.id;

  T? data() => _data;

  Object? get(Object field) {
    final value = _data;
    if (value is Map) {
      return value[field];
    }
    return null;
  }
}

class QueryDocumentSnapshot<T extends Object?> extends DocumentSnapshot<T> {
  QueryDocumentSnapshot(super.reference, T super.data);

  @override
  T data() => super.data() as T;
}

class QuerySnapshot<T extends Object?> {
  QuerySnapshot(this.docs);

  final List<QueryDocumentSnapshot<T>> docs;
}

class AggregateQuery {
  AggregateQuery._();

  Future<AggregateQuerySnapshot> get() => _disabled();
}

class AggregateQuerySnapshot {
  AggregateQuerySnapshot(this.count);

  final int? count;
}

class Timestamp implements Comparable<Timestamp> {
  Timestamp(this.seconds, this.nanoseconds);

  factory Timestamp.fromDate(DateTime date) {
    final millis = date.millisecondsSinceEpoch;
    return Timestamp(millis ~/ 1000, (millis % 1000) * 1000000);
  }

  final int seconds;
  final int nanoseconds;

  DateTime toDate() => DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + nanoseconds ~/ 1000000,
      );

  @override
  int compareTo(Timestamp other) => toDate().compareTo(other.toDate());
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class FieldValue {
  const FieldValue._(this.operation);

  final String operation;

  static FieldValue delete() => const FieldValue._('delete');
  static FieldValue serverTimestamp() => const FieldValue._('serverTimestamp');
  static FieldValue increment(num value) => const FieldValue._('increment');
  static FieldValue arrayUnion(List<Object?> elements) =>
      const FieldValue._('arrayUnion');
  static FieldValue arrayRemove(List<Object?> elements) =>
      const FieldValue._('arrayRemove');
}

class FieldPath {
  const FieldPath._(this.path);

  static const documentId = FieldPath._('__name__');

  final String path;
}

class Filter {
  const Filter(
    this.field, {
    this.whereIn,
    this.arrayContainsAny,
  });

  final String field;
  final List<Object?>? whereIn;
  final List<Object?>? arrayContainsAny;
}

class SetOptions {
  const SetOptions({this.merge});

  final bool? merge;
}
