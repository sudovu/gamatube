import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/cache_manager.dart';
import 'api/video_platform_service.dart';
import 'api/youtube_v3_service.dart';
import 'auth/auth_service.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/app_logger.dart';
import 'core/network/network_info.dart';
import 'core/storage/local_store.dart';
import 'home/home_screen.dart';
import 'playlists/library_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/library_provider.dart';
import 'providers/network_provider.dart';
import 'providers/playback_provider.dart';
import 'providers/search_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/history_repository.dart';
import 'repositories/playlist_repository.dart';
import 'repositories/search_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/watch_later_repository.dart';
import 'search/search_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/setup_wizard_dialog.dart';
import 'subscriptions/subscriptions_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/responsive_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  final localStore = SharedPreferencesLocalStore();
  await localStore.init();

  // Initialize network monitoring
  final networkInfo = NetworkInfoImpl();

  // Initialize caching
  final cacheManager = CacheManager();

  // Initialize auth
  final authService = GoogleOAuthAuthService(localStore: localStore);

  // Initialize repositories
  final settingsRepository = SettingsRepositoryImpl(localStore: localStore);
  final historyRepository = HistoryRepositoryImpl(localStore: localStore);
  final watchLaterRepository = WatchLaterRepositoryImpl(localStore: localStore);
  final playlistRepository = PlaylistRepositoryImpl(localStore: localStore);
  final searchRepository = SearchRepositoryImpl(localStore: localStore);

  final initialSettings = await settingsRepository.getSettings();

  // Initialize API service
  final platformService = YouTubeV3Service(
    cacheManager: cacheManager,
    apiKey: initialSettings.customApiKey,
  );

  AppLogger.info('Starting ${AppConstants.appName} v${AppConstants.appVersion}');

  runApp(
    GamatubeApp(
      localStore: localStore,
      networkInfo: networkInfo,
      cacheManager: cacheManager,
      authService: authService,
      platformService: platformService,
      settingsRepository: settingsRepository,
      historyRepository: historyRepository,
      watchLaterRepository: watchLaterRepository,
      playlistRepository: playlistRepository,
      searchRepository: searchRepository,
    ),
  );
}

class GamatubeApp extends StatelessWidget {
  final LocalStore localStore;
  final NetworkInfo networkInfo;
  final CacheManager cacheManager;
  final AuthService authService;
  final VideoPlatformService platformService;
  final SettingsRepository settingsRepository;
  final HistoryRepository historyRepository;
  final WatchLaterRepository watchLaterRepository;
  final PlaylistRepository playlistRepository;
  final SearchRepository searchRepository;

  const GamatubeApp({
    super.key,
    required this.localStore,
    required this.networkInfo,
    required this.cacheManager,
    required this.authService,
    required this.platformService,
    required this.settingsRepository,
    required this.historyRepository,
    required this.watchLaterRepository,
    required this.playlistRepository,
    required this.searchRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStore>.value(value: localStore),
        Provider<VideoPlatformService>.value(value: platformService),
        ChangeNotifierProvider(
          create: (_) => NetworkProvider(networkInfo: networkInfo),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            settingsRepository: settingsRepository,
            cacheManager: cacheManager,
            localStore: localStore,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService: authService),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeProvider(platformService: platformService),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(
            platformService: platformService,
            searchRepository: searchRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PlaybackProvider(
            historyRepository: historyRepository,
            settingsRepository: settingsRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(
            historyRepository: historyRepository,
            watchLaterRepository: watchLaterRepository,
            playlistRepository: playlistRepository,
          ),
        ),
      ],
      child: const GamatubeRoot(),
    );
  }
}

class GamatubeRoot extends StatelessWidget {
  const GamatubeRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: settings.flutterThemeMode,
      theme: AppTheme.getTheme(
        mode: settings.themeMode,
        highContrast: settings.highContrast,
      ),
      darkTheme: AppTheme.getTheme(
        mode: settings.themeMode,
        highContrast: settings.highContrast,
      ),
      builder: (context, child) {
        // Global Error Boundary
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('An unexpected UI error occurred.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        // Re-trigger build
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return child ?? const SizedBox.shrink();
      },
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    final store = context.read<LocalStore>();
    final completed = await store.getString(AppConstants.keyFirstRun);
    if (completed != 'true') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SetupWizardDialog(),
        );
        await store.setString(AppConstants.keyFirstRun, 'true');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onSearchTap: () => setState(() => _currentIndex = 1),
      ),
      const SearchScreen(),
      const SubscriptionsScreen(),
      const LibraryScreen(),
      const SettingsScreen(),
    ];

    return ResponsiveScaffold(
      currentIndex: _currentIndex,
      onNavigationChanged: (index) {
        setState(() => _currentIndex = index);
      },
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
    );
  }
}
