import '../models/video.dart';
import '../models/channel.dart';
import '../models/comment.dart';
import '../core/capabilities/platform_capabilities.dart';

abstract class VideoPlatformService {
  PlatformCapabilities get capabilities;

  Future<List<Video>> getHomeFeed({String? pageToken});
  Future<List<Video>> getTrending({String? regionCode, String? pageToken});
  Future<List<Video>> searchVideos(
    String query, {
    String? order,
    String? pageToken,
  });
  Future<Video> getVideoDetails(String videoId);
  Future<List<Video>> getRelatedVideos(String videoId);
  Future<Channel> getChannel(String channelId);
  Future<List<Video>> getChannelVideos(String channelId, {String? pageToken});
  Future<List<Channel>> getSubscriptions({String? accessToken});
  Future<List<Comment>> getComments(String videoId, {String? pageToken});
  Future<bool> postComment(String videoId, String text, {required String accessToken});
  Future<bool> likeVideo(String videoId, {required String accessToken});
  Future<bool> subscribeChannel(String channelId, {required String accessToken});
  Future<bool> unsubscribeChannel(String channelId, {required String accessToken});
}
