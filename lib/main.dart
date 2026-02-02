import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/note.dart';
import 'screens/edit_note_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/main_screen.dart';
import 'screens/notes_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final PageController _controller = PageController(initialPage: 1);
  int _pageIndex = 1;

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
