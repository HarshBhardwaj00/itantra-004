import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/radio_packet_bus.dart';
import 'data/datasources/virtual_lora_datasource.dart';
import 'data/datasources/wifi_udp_datasource.dart';
import 'data/models/device_node.dart';
import 'presentation/blocs/alert/alert_bloc.dart';
import 'presentation/blocs/comms/comms_log_bloc.dart';
import 'presentation/blocs/language/language_bloc.dart';
import 'presentation/blocs/language/language_event.dart';
import 'presentation/blocs/radar/radar_bloc.dart';
import 'presentation/blocs/radio/radio_bloc.dart';
import 'presentation/blocs/receiver/receiver_bloc.dart';
import 'presentation/blocs/receiver/receiver_event.dart';
import 'presentation/blocs/talk/talk_bloc.dart';
import 'services/audio/audio_player_service.dart';
import 'services/model/model_path_resolver.dart';
import 'services/speech/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DeviceNode.init();

  // The app boots straight into the home dashboard, so the device profile is
  // provisioned here. The call-sign it writes is the identity the sender and
  // the receiver use on the wire.
  await DeviceNode.ensureProfile();

  final savedLang = DeviceNode.loadActiveLanguage();
  if (savedLang != null) {
    AppConstants.activeLanguageCode = savedLang.$1;
    AppConstants.activeLanguageName = savedLang.$2;
  }

  runApp(const ITantraApp());
}

class ITantraApp extends StatefulWidget {
  final String? initialRoute;
  const ITantraApp({super.key, this.initialRoute});

  @override
  State<ITantraApp> createState() => _ITantraAppState();
}

class _ITantraAppState extends State<ITantraApp> {
  late final WifiUdpDataSource _wifiSource;
  late final VirtualLoRaDataSource _loraSource;
  late final AudioPlayerService _audioPlayer;
  late final TtsService _ttsService;
  late final AlertBloc _alertBloc;

  @override
  void initState() {
    super.initState();
    _wifiSource = WifiUdpDataSource();
    _loraSource = VirtualLoRaDataSource();
    _audioPlayer = AudioPlayerService();
    _ttsService = TtsService();

    _alertBloc = AlertBloc(
      wifiSource: _wifiSource,
      loraSource: _loraSource,
      audioPlayer: _audioPlayer,
      ttsService: _ttsService,
    );

    // Initialize data sources and model resolver
    ModelPathResolver.ensureInitialized().then((_) {
      _ttsService.init(languageCode: AppConstants.activeLanguageCode);
    });
    _wifiSource.initialize();
    _loraSource.activate();
    _loraSource.attachWifi(_wifiSource);

    // Funnel every radio frame (WiFi UDP + LoRa) into the shared bus so the
    // radar screen can plot live peers regardless of which screen is open.
    RadioPacketBus.instance
      ..attach(_wifiSource.incomingFrames)
      ..attach(_loraSource.incomingFrames);
  }

  @override
  void dispose() {
    _alertBloc.close();
    _wifiSource.close();
    _loraSource.dispose();
    _audioPlayer.dispose();
    _ttsService.free();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TalkBloc>(
          create: (_) => TalkBloc(
            wifiSource: _wifiSource,
            loraSource: _loraSource,
          ),
        ),
        BlocProvider<RadarBloc>(create: (_) => RadarBloc()),
        BlocProvider<CommsLogBloc>(create: (_) => CommsLogBloc()),
        BlocProvider<RadioBloc>(
          create: (_) => RadioBloc(wifiSource: _wifiSource),
        ),
        BlocProvider<LanguageBloc>(
          // The pack list and the active language are shared app wide, so
          // the hub header, the language picker and the pack manager all
          // read the very same state.
          create: (_) => LanguageBloc()..add(const LanguageInitialize()),
        ),
        BlocProvider<ReceiverBloc>(
          create: (_) => ReceiverBloc(
            wifiSource: _wifiSource,
            ttsService: _ttsService,
            audioPlayer: _audioPlayer,
          )..add(const ReceiverStarted()),
        ),
        BlocProvider<AlertBloc>.value(value: _alertBloc),
      ],
      child: Builder(
        builder: (context) {
          // Provide root navigator context to AlertBloc for global dialog.
          _alertBloc.setDialogContext(context);

          return MaterialApp(
            title: 'iTantra',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            // iTantra v2.0 ships the Light Neural system (design.md); the
            // legacy dark tactical palette stays available in
            // `design_v1_dark.md` for a future theme toggle.
            themeMode: ThemeMode.light,
            initialRoute: widget.initialRoute ?? AppRouter.home,
            onGenerateRoute: AppRouter.generateRoute,
            // A single entry route keeps the stack flat: MaterialApp would
            // otherwise push a hidden "/" route under every other start
            // route, which would boot the dashboard twice.
            onGenerateInitialRoutes: (initialRouteName) => <Route<dynamic>>[
              AppRouter.generateRoute(
                RouteSettings(
                  name: initialRouteName,
                  arguments: initialRouteName,
                ),
              ),
            ],
            navigatorObservers: [],
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}