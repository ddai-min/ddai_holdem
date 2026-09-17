import 'package:flutter/material.dart';

import 'data/profile_store.dart';
import 'ui/game_theme.dart';
import 'ui/screens/home_screen.dart';

class HoldemApp extends StatelessWidget {
  const HoldemApp({required this.profile, super.key});

  final ProfileStore profile;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DDAI 홀덤',
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      home: HomeScreen(profile: profile),
    );
  }
}
