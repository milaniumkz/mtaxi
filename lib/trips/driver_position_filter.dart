import 'package:geolocator/geolocator.dart';

class DriverPositionFilter {
  Position? _last, _candidate;
  int _candidateCount = 0;
  DateTime? _candidateSince;
  bool accept(Position position) {
    final now = DateTime.now();
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180 ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > 65 ||
        now.difference(position.timestamp).inSeconds > 30 ||
        position.timestamp.difference(now).inSeconds > 10) return false;
    final previous = _last;
    if (previous != null) {
      if (!position.timestamp.isAfter(previous.timestamp)) return false;
      final seconds =
          position.timestamp.difference(previous.timestamp).inMilliseconds /
              1000;
      final distance = Geolocator.distanceBetween(previous.latitude,
          previous.longitude, position.latitude, position.longitude);
      if (distance > 80 && distance > seconds * 55 + position.accuracy) {
        final candidate = _candidate;
        if (candidate == null ||
            Geolocator.distanceBetween(candidate.latitude, candidate.longitude,
                    position.latitude, position.longitude) >
                50 ||
            now.difference(candidate.timestamp).inSeconds > 20) {
          _candidateCount = 1;
          _candidateSince = now;
        } else {
          _candidateCount++;
        }
        _candidate = position;
        if (_candidateCount < 3 ||
            now.difference(_candidateSince!).inSeconds < 6) return false;
      }
    }
    _last = position;
    _candidate = null;
    _candidateCount = 0;
    return true;
  }
}
