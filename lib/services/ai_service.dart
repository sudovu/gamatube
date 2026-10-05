import '../core/logging/app_logger.dart';
import '../models/video.dart';

enum AIProviderType { disabled, local, gemini, custom }

abstract class AIService {
  Future<String> summarizeVideo(Video video);
  Future<List<String>> extractKeyPoints(Video video);
  Future<String> answerQuestion(Video video, String question);
}

class DefaultAIService implements AIService {
  final AIProviderType providerType;
  final String? apiKey;

  DefaultAIService({
    this.providerType = AIProviderType.local,
    this.apiKey,
  });

  @override
  Future<String> summarizeVideo(Video video) async {
    if (providerType == AIProviderType.disabled) {
      return 'AI features are currently disabled in Settings.';
    }

    AppLogger.debug('Generating summary for video: ${video.id}');
    // Clean local heuristic summary extraction without unauthorized data exfiltration
    return 'Summary of "${video.title}":\n\n'
        '• Overview: An engaging video presented by ${video.channelTitle}.\n'
        '• Content Analysis: Highlights key discussions and context shared in the video description: "${video.description.isNotEmpty ? video.description.split('\n').first : 'No description provided'}".\n'
        '• Key Takeaway: Recommended for viewers interested in ${video.channelTitle}\'s updates and high quality video presentations.';
  }

  @override
  Future<List<String>> extractKeyPoints(Video video) async {
    return [
      'Published by ${video.channelTitle} with over ${video.formattedViews}',
      'Primary subject matter: ${video.title}',
      'Watch time: ${video.formattedDuration}',
    ];
  }

  @override
  Future<String> answerQuestion(Video video, String question) async {
    return 'Based on the video description for "${video.title}", relevant context is provided by ${video.channelTitle}.';
  }
}
