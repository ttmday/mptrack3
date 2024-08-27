extension DurationExtension on Duration {
  String get formatStr {
    return [
      if (inHours > 0) inHours.toString().padLeft(2, '0'),
      inMinutes.remainder(60).toString().padLeft(2, '0'),
      inSeconds.remainder(60).toString().padLeft(2, '0')
    ].join(":");
  }
}
