abstract class Failure {
  final String message;
  final String? actionHint;
  final int? statusCode;

  const Failure({
    required this.message,
    this.actionHint,
    this.statusCode,
  });

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. GAMATUBE is operating in offline mode.',
    super.actionHint = 'Check your connection or browse saved offline library.',
  });
}

class AuthExpiredFailure extends Failure {
  const AuthExpiredFailure({
    super.message = 'Your Google session has expired. Please sign in again.',
    super.actionHint = 'Sign In',
    super.statusCode = 401,
  });
}

class RateLimitFailure extends Failure {
  final Duration? retryAfter;

  const RateLimitFailure({
    super.message = 'Too many requests. Please wait a moment and try again.',
    super.actionHint = 'Retry shortly',
    super.statusCode = 429,
    this.retryAfter,
  });
}

class ApiUnavailableFailure extends Failure {
  const ApiUnavailableFailure({
    super.message = 'The video service is temporarily unreachable.',
    super.actionHint = 'Try again later',
    super.statusCode = 503,
  });
}

class VideoUnavailableFailure extends Failure {
  const VideoUnavailableFailure({
    super.message = 'This video is unavailable or has been removed.',
    super.actionHint = 'Browse other videos',
    super.statusCode = 404,
  });
}

class RegionUnavailableFailure extends Failure {
  const RegionUnavailableFailure({
    super.message = 'This video is not available in your region due to provider restrictions.',
    super.actionHint = 'Try another video',
    super.statusCode = 403,
  });
}

class FeatureUnsupportedFailure extends Failure {
  final String featureName;

  const FeatureUnsupportedFailure({
    required this.featureName,
    super.message = 'This feature is currently not supported by official platform APIs.',
    super.actionHint = 'Learn more in documentation',
  });
}

class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'An unexpected server error occurred.',
    super.actionHint = 'Retry',
    super.statusCode,
  });
}

class StorageFailure extends Failure {
  const StorageFailure({
    super.message = 'Local storage operation failed.',
    super.actionHint = 'Check available device storage',
  });
}
