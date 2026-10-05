# API Integration & Capabilities

GAMATUBE interfaces with video platforms through official, documented APIs without reverse engineering or bypassing access restrictions.

---

## Service Abstraction: `VideoPlatformService`

The core contract lives in `lib/api/video_platform_service.dart`:

```dart
abstract class VideoPlatformService {
  PlatformCapabilities get capabilities;

  Future<List<Video>> getHomeFeed({String? pageToken});
  Future<List<Video>> getTrending({String? regionCode, String? pageToken});
  Future<List<Video>> searchVideos(String query, {String? order, String? pageToken});
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
```

---

## Official YouTube Data API v3 Endpoints Used

| Endpoint | Method | Scope / Requirement | Purpose |
| -------- | ------ | ------------------- | ------- |
| `/videos` | GET | API Key or Bearer Token | Fetch popular videos, video metadata, and duration |
| `/search` | GET | API Key or Bearer Token | Query video catalog with relevance, date, rating filters |
| `/channels` | GET | API Key or Bearer Token | Retrieve channel avatar, banners, subscriber statistics |
| `/commentThreads` | GET | API Key or Bearer Token | Read top comments on videos |
| `/subscriptions` | GET | `youtube.readonly` OAuth | Retrieve subscribed channels for signed-in Google account |

---

## Capability Statuses

To ensure a smooth user experience, features declare their support level:
- **`supported`**: Operates without prerequisites.
- **`authRequired`**: Requires user to connect their Google Account via "Continue with Google".
- **`unsupported`**: Official API does not offer access (e.g. unauthorized video stream downloading). The UI explains the reason clearly.
- **`temporarilyUnavailable`**: Provider quota exhaustion or server rate limit.
