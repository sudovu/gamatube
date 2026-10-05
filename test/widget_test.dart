import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamatube/widgets/gamatube_logo.dart';
import 'package:gamatube/widgets/empty_state_view.dart';
import 'package:gamatube/widgets/network_status_banner.dart';
import 'package:gamatube/core/network/network_info.dart';
import 'package:gamatube/providers/network_provider.dart';
import 'package:provider/provider.dart';

class MockNetworkInfo implements NetworkInfo {
  @override
  NetworkStatus get currentStatus => NetworkStatus.online;

  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<NetworkStatus> get statusStream => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  testWidgets('GamatubeLogo renders correctly with brand text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GamatubeLogo(size: 32, showText: true),
        ),
      ),
    );

    expect(find.text('G'), findsOneWidget);
    expect(find.byType(GamatubeLogo), findsOneWidget);
  });

  testWidgets('EmptyStateView renders title, message, and action button', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateView(
            icon: Icons.history,
            title: 'No History',
            message: 'Start watching videos to populate history',
            action: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('Explore'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('No History'), findsOneWidget);
    expect(find.text('Start watching videos to populate history'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    expect(tapped, true);
  });

  testWidgets('NetworkStatusBanner hides when status is online', (WidgetTester tester) async {
    final mockNet = MockNetworkInfo();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NetworkProvider(networkInfo: mockNet),
        child: const MaterialApp(
          home: Scaffold(
            body: NetworkStatusBanner(),
          ),
        ),
      ),
    );

    expect(find.text('Offline Mode • Browsing saved library and cache'), findsNothing);
  });
}
