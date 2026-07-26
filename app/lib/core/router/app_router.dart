import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_landing_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/deck/deck_filters_screen.dart';
import '../../features/deck/deck_screen.dart';
import '../../features/deck/match_celebration_screen.dart';
import '../../features/items/add_item_flow.dart';
import '../../features/items/item_detail_screen.dart';
import '../../features/items/my_items_screen.dart';
import '../../features/items/wishlist_screen.dart';
import '../../features/market/all_categories_screen.dart';
import '../../features/market/category_screen.dart';
import '../../features/market/market_screen.dart';
import '../../features/market/search_screen.dart';
import '../../features/matches/complete_trade_screen.dart';
import '../../features/matches/create_offer_screen.dart';
import '../../features/matches/dispute_screen.dart';
import '../../features/matches/matches_screen.dart';
import '../../features/matches/meeting_screen.dart';
import '../../features/matches/rate_trade_screen.dart';
import '../../features/matches/trade_room_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/intro_screen.dart';
import '../../features/onboarding/language_screen.dart';
import '../../features/onboarding/location_setup_screen.dart';
import '../../features/onboarding/profile_setup_screen.dart';
import '../../features/onboarding/wishlist_builder_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/public_profile_screen.dart';
import '../../features/profile/reviews_screen.dart';
import '../../features/profile/trade_history_screen.dart';
import '../../features/safety/report_screen.dart';
import '../../features/safety/safety_center_screen.dart';
import '../../features/settings/emergency_contact_screen.dart';
import '../../features/settings/notification_settings_screen.dart';
import '../../features/settings/security_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';

/// أسماء المسارات — ممنوع كتابة نص المسار مباشرة في الشاشات.
class R {
  const R._();

  static const splash = '/';

  // الترحيب
  static const onbIntro = '/onboarding/intro';
  static const onbLanguage = '/onboarding/language';
  static const onbProfile = '/onboarding/profile';
  static const onbLocation = '/onboarding/location';
  static const onbWishlist = '/onboarding/wishlist';

  // الحساب
  static const auth = '/auth';
  static const signUp = '/auth/signup';
  static const signIn = '/auth/signin';
  static const otp = '/auth/otp';
  static const forgot = '/auth/forgot';

  // التبويبات
  static const market = '/market';
  static const deck = '/deck';
  static const matches = '/matches';
  static const items = '/items';
  static const profile = '/profile';

  // السوق
  static const allCategories = '/market/categories';
  static const search = '/market/search';
  static String category(String id) => '/market/category/$id';

  // السحب
  static const deckFilters = '/deck/filters';
  static String matchCelebrate(String id) => '/match/$id/celebrate';

  // المقايضة
  static String room(String id) => '/matches/$id';
  static String offerNew(String id) => '/matches/$id/offer/new';
  static String meeting(String id) => '/matches/$id/meeting';
  static String complete(String id) => '/matches/$id/complete';
  static String rate(String id) => '/matches/$id/rate';
  static String dispute(String id) => '/matches/$id/dispute';

  // المنتجات
  static const addItem = '/items/new';
  static const wishlist = '/wishlist';
  static String item(String id) => '/items/$id';

  // الحساب الشخصي
  static const editProfile = '/profile/edit';
  static const reviews = '/profile/reviews';
  static const tradeHistory = '/profile/trades';
  static String publicProfile(String username) => '/u/$username';

  // الإعدادات
  static const settings = '/settings';
  static const settingsNotifications = '/settings/notifications';
  static const settingsSecurity = '/settings/security';
  static const settingsEmergency = '/settings/emergency';

  // عرضية
  static const notifications = '/notifications';
  static const safety = '/safety';
  static String report(String type, String id) => '/report/$type/$id';
}

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: R.splash,
    routes: [
      GoRoute(path: R.splash, builder: (_, __) => const SplashScreen()),

      // ------------------------------------------------------------ الترحيب
      GoRoute(path: R.onbIntro, builder: (_, __) => const IntroScreen()),
      GoRoute(path: R.onbLanguage, builder: (_, __) => const LanguageScreen()),
      GoRoute(path: R.onbProfile, builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: R.onbLocation, builder: (_, __) => const LocationSetupScreen()),
      GoRoute(
        path: R.onbWishlist,
        builder: (_, __) => const WishlistBuilderScreen(),
      ),

      // ------------------------------------------------------------ الحساب
      GoRoute(path: R.auth, builder: (_, __) => const AuthLandingScreen()),
      GoRoute(path: R.signUp, builder: (_, __) => const SignUpScreen()),
      GoRoute(path: R.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: R.forgot, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: R.otp,
        builder: (context, state) => OtpScreen(
          target: state.uri.queryParameters['target'] ?? '',
          isEmail: state.uri.queryParameters['type'] == 'email',
        ),
      ),

      // ------------------------------------------------------------ التبويبات
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: R.market, builder: (_, __) => const MarketScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: R.deck, builder: (_, __) => const DeckScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: R.matches,
                builder: (_, __) => const MatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: R.items, builder: (_, __) => const MyItemsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: R.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ------------------------------------------------------------ السوق
      GoRoute(
        path: R.allCategories,
        builder: (_, __) => const AllCategoriesScreen(),
      ),
      GoRoute(path: R.search, builder: (_, __) => const SearchScreen()),
      GoRoute(
        path: '/market/category/:id',
        builder: (context, state) =>
            CategoryScreen(categoryId: state.pathParameters['id']!),
      ),

      // ------------------------------------------------------------ السحب
      GoRoute(
        path: R.deckFilters,
        builder: (_, __) => const DeckFiltersScreen(),
      ),
      GoRoute(
        path: '/match/:id/celebrate',
        builder: (context, state) =>
            MatchCelebrationScreen(matchId: state.pathParameters['id']!),
      ),

      // ------------------------------------------------------------ المقايضة
      GoRoute(
        path: '/matches/:id',
        builder: (context, state) =>
            TradeRoomScreen(matchId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'offer/new',
            builder: (context, state) =>
                CreateOfferScreen(matchId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'meeting',
            builder: (context, state) =>
                MeetingScreen(matchId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'complete',
            builder: (context, state) =>
                CompleteTradeScreen(matchId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'rate',
            builder: (context, state) =>
                RateTradeScreen(matchId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'dispute',
            builder: (context, state) =>
                DisputeScreen(matchId: state.pathParameters['id']!),
          ),
        ],
      ),

      // ------------------------------------------------------------ المنتجات
      GoRoute(path: R.addItem, builder: (_, __) => const AddItemFlowScreen()),
      GoRoute(path: R.wishlist, builder: (_, __) => const WishlistScreen()),
      GoRoute(
        path: '/items/:id',
        builder: (context, state) =>
            ItemDetailScreen(itemId: state.pathParameters['id']!),
      ),

      // ------------------------------------------------------------ الملف
      GoRoute(path: R.editProfile, builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: R.reviews, builder: (_, __) => const ReviewsScreen()),
      GoRoute(
        path: R.tradeHistory,
        builder: (_, __) => const TradeHistoryScreen(),
      ),
      GoRoute(
        path: '/u/:username',
        builder: (context, state) =>
            PublicProfileScreen(username: state.pathParameters['username']!),
      ),

      // ------------------------------------------------------------ الإعدادات
      GoRoute(path: R.settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: R.settingsNotifications,
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: R.settingsSecurity,
        builder: (_, __) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: R.settingsEmergency,
        builder: (_, __) => const EmergencyContactScreen(),
      ),

      // ------------------------------------------------------------ عرضية
      GoRoute(
        path: R.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(path: R.safety, builder: (_, __) => const SafetyCenterScreen()),
      GoRoute(
        path: '/report/:type/:id',
        builder: (context, state) => ReportScreen(
          targetType: state.pathParameters['type']!,
          targetId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}
