import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/supabase_config.dart';
import 'firebase_options.dart';
import 'models/note.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/edit_note_screen.dart';
import 'screens/main_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/notes_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(NoteAdapter());
  }
  await Hive.openBox<Note>('notes');
  runApp(const ProviderScope(child: SparkApp()));
}

class SparkApp extends ConsumerWidget {
  const SparkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themeProvider);
    return MaterialApp(
      title: 'Spark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themePreference.themeMode,
      onGenerateRoute: (settings) {
        if (settings.name == '/edit') {
          final note = settings.arguments as Note;
          return MaterialPageRoute(
            builder: (_) => EditNoteScreen(note: note),
          );
        }
        return null;
      },
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final PageController _controller = PageController(initialPage: 1);
  int _pageIndex = 1;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      try {
        await ref.read(authControllerProvider).ensureGuest();
      } catch (error) {
        debugPrint('Guest sign-in failed: $error');
      }
    });
  }

  void _openMain() {
    _controller.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _pageIndex == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _pageIndex != 1) {
          _openMain();
        }
      },
      child: GestureDetector(
        onPanDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: PageView(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _pageIndex = index);
            },
            children: [
              MenuScreen(onBack: _openMain),
              const MainScreen(),
              const NotesScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
