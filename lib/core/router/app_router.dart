import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/recent_activity_screen.dart';
import '../../features/appointments/presentation/appointments_list_screen.dart';
import '../../features/appointments/presentation/my_appointments_list_screen.dart';
import '../../features/consultations/presentation/consultations_list_screen.dart';
import '../../features/consultations/presentation/consultation_detail_screen.dart';
import '../../features/consultations/presentation/my_consultations_list_screen.dart';
import '../../features/tickets/presentation/tickets_list_screen.dart';
import '../../features/tickets/presentation/ticket_detail_screen.dart';
import '../../features/tickets/presentation/my_tickets_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/calls/presentation/calls_screen.dart';
import '../../features/calls/presentation/call_view_screen.dart';
import '../../features/accounts/presentation/accounts_list_screen.dart';
import '../../features/accounts/presentation/account_detail_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/account_screen.dart';
import '../../features/client_home/presentation/client_home_screen.dart';
import '../../features/ai_intake/presentation/ai_intake_screen.dart';
import '../../models/profile.dart';
import '../widgets/main_shell.dart';
import '../widgets/client_shell.dart';

const _staffPaths = ['/dashboard', '/appointments', '/consultations', '/tickets', '/analytics', '/calls', '/accounts', '/settings', '/activity'];
const _clientPaths = ['/client/home', '/client/consultations', '/client/ai-intake', '/client/appointments', '/client/tickets', '/client/settings', '/client/activity'];

/// مفتاح تنقّل جذري — يُستخدم من خارج شجرة الواجهات (مثل معالج الضغط على
/// إشعار Push وقت إغلاق التطبيق) للوصول إلى GoRouter دون الحاجة لـ context.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<bool?>(null);
  ref.listen(currentProfileProvider, (prev, next) {
    authNotifier.value = next.valueOrNull != null;
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final profileState = ref.read(currentProfileProvider);
      if (profileState.isLoading) return null;
      final profile = profileState.valueOrNull;
      final loc = state.matchedLocation;
      final isPublic = loc == '/login' || loc == '/register';

      if (profile == null) {
        return isPublic ? null : '/login';
      }
      if (isPublic) {
        return profile.role == StaffRole.client ? '/client/home' : '/dashboard';
      }
      // مطابقة تامة فقط (وليس startsWith) لأن مسارات مشتركة مثل
      // /consultations/:id أو /tickets/:id تبدأ بنفس بادئة مسارات الموظف
      // الحصرية (/consultations، /tickets) رغم أنها متاحة للطرفين فعليًا.
      final isClient = profile.role == StaffRole.client;
      if (isClient && _staffPaths.contains(loc)) return '/client/home';
      if (!isClient && _clientPaths.contains(loc)) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),

      // مسار الموظف (المشرف)
      ShellRoute(
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/appointments', builder: (context, state) => const AppointmentsListScreen()),
          GoRoute(path: '/consultations', builder: (context, state) => const ConsultationsListScreen()),
          GoRoute(path: '/tickets', builder: (context, state) => const TicketsListScreen()),
          GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
          GoRoute(path: '/calls', builder: (context, state) => const CallsScreen()),
          GoRoute(path: '/accounts', builder: (context, state) => const AccountsListScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),

      // مسار العميل
      ShellRoute(
        builder: (context, state, child) => ClientShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/client/home', builder: (context, state) => const ClientHomeScreen()),
          GoRoute(path: '/client/consultations', builder: (context, state) => const MyConsultationsListScreen()),
          GoRoute(path: '/client/ai-intake', builder: (context, state) => const AiIntakeScreen()),
          GoRoute(path: '/client/appointments', builder: (context, state) => const MyAppointmentsListScreen()),
          GoRoute(path: '/client/tickets', builder: (context, state) => const MyTicketsListScreen()),
          GoRoute(path: '/client/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),

      // شاشات مشتركة بين الدورين (تفتح فوق أي من القشرتين)
      GoRoute(
        path: '/consultations/:id',
        builder: (context, state) => ConsultationDetailScreen(consultationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tickets/:id',
        builder: (context, state) => TicketDetailScreen(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:kind/:id',
        builder: (context, state) => ChatScreen(
          kind: state.pathParameters['kind']!,
          parentId: state.pathParameters['id']!,
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (context, state) => AccountDetailScreen(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => const RecentActivityScreen(),
      ),
      GoRoute(
        path: '/client/activity',
        builder: (context, state) => const RecentActivityScreen(mine: true),
      ),
      GoRoute(
        path: '/my-account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/call',
        builder: (context, state) => CallViewScreen(
          roomId: state.uri.queryParameters['room'] ?? '',
          peerName: state.uri.queryParameters['name'] ?? '',
          isHost: state.uri.queryParameters['mode'] != 'guest',
          calleeId: state.uri.queryParameters['calleeId'],
        ),
      ),
    ],
  );
});
