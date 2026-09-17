import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/profile_store.dart';
import '../../engine/table_config.dart';
import '../../net/firebase_gate.dart';
import '../../net/firestore_room_transport.dart';
import '../../net/local_room_transport.dart';
import '../../net/room_session.dart';
import '../../net/room_transport.dart';
import '../game_theme.dart';
import '../widgets/panel.dart';
import 'table_screen.dart';

/// 첫 화면. 닉네임을 정하고 방을 만들거나 코드로 들어간다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.profile, super.key});

  final ProfileStore profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _nickname = TextEditingController(
    text: widget.profile.nickname.isEmpty
        ? randomNickname()
        : widget.profile.nickname,
  );
  final TextEditingController _code = TextEditingController();

  int _smallBlind = 10;
  int _startingChips = 2000;
  int _maxSeats = 6;
  int _actionSeconds = 30;
  int _botCount = 3;

  bool _showSettings = false;
  bool _busy = false;
  String? _error;
  bool _online = FirebaseGate.isReady;

  TableConfig get _config => TableConfig(
    smallBlind: _smallBlind,
    bigBlind: _smallBlind * 2,
    startingChips: _startingChips,
    maxSeats: _maxSeats,
    actionSeconds: _actionSeconds,
  );

  @override
  void dispose() {
    _nickname.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Header(),
                  const SizedBox(height: 26),
                  if (_error != null) ...<Widget>[
                    ErrorNote(_error!),
                    const SizedBox(height: 14),
                  ],
                  if (!_online) ...<Widget>[
                    ErrorNote(
                      FirebaseGate.problem ??
                          '온라인에 연결하지 못했습니다. 연습 모드는 그대로 쓸 수 있습니다.',
                      onRetry: _busy ? null : _retryOnline,
                    ),
                    const SizedBox(height: 14),
                  ],
                  GamePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SectionLabel('닉네임'),
                        TextField(
                          controller: _nickname,
                          textInputAction: TextInputAction.done,
                          maxLength: 12,
                          decoration: const InputDecoration(
                            hintText: '테이블에 표시될 이름',
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _OnlinePanel(
                    enabled: _online && !_busy,
                    codeController: _code,
                    showSettings: _showSettings,
                    onToggleSettings: () =>
                        setState(() => _showSettings = !_showSettings),
                    settings: _buildSettings(),
                    onCreate: _createRoom,
                    onJoin: _joinRoom,
                  ),
                  const SizedBox(height: 14),
                  GamePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SectionLabel('혼자 연습하기'),
                        const Text(
                          '봇을 상대로 규칙과 화면을 먼저 익혀 보세요. '
                          '인터넷도 Firebase 설정도 필요 없습니다.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: GamePalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OptionRow<int>(
                          label: '봇 인원',
                          options: const <int>[1, 2, 3, 5],
                          value: _botCount,
                          labelOf: (count) => '$count명',
                          onChanged: (count) =>
                              setState(() => _botCount = count),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _startPractice,
                          icon: const Icon(Icons.smart_toy_outlined, size: 18),
                          label: const Text('연습 시작'),
                        ),
                      ],
                    ),
                  ),
                  if (_busy) ...<Widget>[
                    const SizedBox(height: 20),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: GamePalette.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      OptionRow<int>(
        label: '블라인드 (SB/BB)',
        options: const <int>[10, 25, 50, 100],
        value: _smallBlind,
        labelOf: (value) => '$value/${value * 2}',
        onChanged: (value) => setState(() {
          _smallBlind = value;
          // 시작 칩이 블라인드에 비해 너무 적으면 판이 바로 끝난다.
          if (_startingChips < value * 20) {
            _startingChips = value * 100;
          }
        }),
      ),
      OptionRow<int>(
        label: '시작 칩',
        options: <int>[
          for (final chips in const <int>[1000, 2000, 5000, 10000])
            if (chips >= _smallBlind * 20) chips,
        ],
        value: _startingChips,
        labelOf: formatChips,
        onChanged: (value) => setState(() => _startingChips = value),
      ),
      OptionRow<int>(
        label: '자리 수',
        options: const <int>[2, 4, 6, 9],
        value: _maxSeats,
        labelOf: (value) => '$value인',
        onChanged: (value) => setState(() => _maxSeats = value),
      ),
      OptionRow<int>(
        label: '생각 시간',
        options: const <int>[15, 30, 60],
        value: _actionSeconds,
        labelOf: (value) => '$value초',
        onChanged: (value) => setState(() => _actionSeconds = value),
      ),
    ],
  );

  // ------------------------------------------------------------------ 동작

  Future<void> _retryOnline() async {
    setState(() => _busy = true);
    final ready = await FirebaseGate.ensureReady();
    if (!mounted) {
      return;
    }
    setState(() {
      _online = ready;
      _busy = false;
    });
  }

  Future<void> _createRoom() => _run(() async {
    final transport = await FirestoreRoomTransport.create(config: _config);
    return (transport, _config);
  });

  Future<void> _joinRoom() => _run(() async {
    final transport = await FirestoreRoomTransport.join(_code.text);
    // 방 설정은 방장이 정한 것을 따른다. 여기 값은 자리를 잡기 전까지의 기본값이다.
    return (transport, _config);
  });

  Future<void> _startPractice() => _run(() async {
    final config = _config.copyWith(maxSeats: _maxSeats);
    return (LocalRoomTransport(botCount: _botCount), config);
  });

  /// 방을 열고 테이블 화면으로 넘어간다. 오류는 화면 위쪽에 띄운다.
  Future<void> _run(
    Future<(RoomTransport, TableConfig)> Function() open,
  ) async {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final name = _nickname.text.trim().isEmpty
        ? randomNickname()
        : _nickname.text.trim();
    await widget.profile.saveNickname(name);

    RoomSession? session;
    try {
      final (transport, config) = await open();
      session = RoomSession(
        transport: transport,
        myName: name,
        config: config,
      );
      await session.start();
    } catch (error) {
      await session?.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '$error';
      });
      return;
    }

    if (!mounted) {
      await session.dispose();
      return;
    }
    setState(() => _busy = false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => TableScreen(session: session!)),
    );
    await session.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: GamePalette.feltCenter,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GamePalette.railHighlight, width: 2),
          ),
          alignment: Alignment.center,
          child: const Text('♠', style: TextStyle(fontSize: 30)),
        ),
        const SizedBox(height: 14),
        const Text(
          'DDAI 홀덤',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '방을 만들고 코드를 알려 주면 바로 시작합니다',
          style: TextStyle(fontSize: 13, color: GamePalette.textSecondary),
        ),
      ],
    );
  }
}

class _OnlinePanel extends StatelessWidget {
  const _OnlinePanel({
    required this.enabled,
    required this.codeController,
    required this.showSettings,
    required this.onToggleSettings,
    required this.settings,
    required this.onCreate,
    required this.onJoin,
  });

  final bool enabled;
  final TextEditingController codeController;
  final bool showSettings;
  final VoidCallback onToggleSettings;
  final Widget settings;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      accent: enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionLabel(
            '친구들과 온라인 대전',
            trailing: TextButton.icon(
              onPressed: enabled ? onToggleSettings : null,
              icon: Icon(
                showSettings
                    ? Icons.expand_less_rounded
                    : Icons.tune_rounded,
                size: 16,
              ),
              label: Text(showSettings ? '접기' : '방 설정'),
            ),
          ),
          if (showSettings) ...<Widget>[settings, const SizedBox(height: 4)],
          FilledButton.icon(
            onPressed: enabled ? onCreate : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('방 만들기'),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: codeController,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 5,
                  inputFormatters: <TextInputFormatter>[
                    UpperCaseFormatter(),
                  ],
                  decoration: const InputDecoration(
                    hintText: '방 코드',
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: enabled ? onJoin : null,
                child: const Text('참가'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 방 코드는 대문자만 쓴다. 소문자로 쳐도 알아서 올려 준다.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
