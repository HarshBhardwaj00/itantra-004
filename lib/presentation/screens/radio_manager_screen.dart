import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import '../../presentation/blocs/radio/radio_bloc.dart';
import '../../presentation/blocs/radio/radio_event.dart';
import '../../presentation/blocs/radio/radio_state.dart';

class RadioManagerScreen extends StatefulWidget {
  const RadioManagerScreen({super.key});

  @override
  State<RadioManagerScreen> createState() => _RadioManagerScreenState();
}

class _RadioManagerScreenState extends State<RadioManagerScreen> {
  /// Reuses the app-wide RadioBloc so only one UDP listener exists; only when
  /// no ancestor provider exists (e.g. isolated tests) do we own one locally.
  RadioBloc? _bloc;
  RadioBloc? _localBloc;
  bool _initDispatched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initDispatched) return;
    _initDispatched = true;

    final hasRoot =
        context.findAncestorWidgetOfExactType<BlocProvider<RadioBloc>>() != null;
    if (hasRoot) {
      _bloc = context.read<RadioBloc>();
    } else {
      _localBloc = RadioBloc();
      _bloc = _localBloc;
    }

    if (_bloc != null && _bloc!.state is RadioInitial) {
      _bloc!.add(const RadioInitializeEvent());
    }
  }

  @override
  void dispose() {
    _localBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RadioBloc>.value(
      value: _bloc!,
      child: const _RadioManagerView(),
    );
  }
}

class _RadioManagerView extends StatelessWidget {
  const _RadioManagerView();

  Color _withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final hPad = clampDouble(screenWidth * 0.045, 14.0, 20.0);
    final vPad = clampDouble(screenHeight * 0.018, 12.0, 18.0);
    final cardRadius = clampDouble(screenWidth * 0.055, 20.0, 28.0);
    final cardPadding = clampDouble(screenWidth * 0.045, 16.0, 22.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom == 0 ? 16.0 : MediaQuery.paddingOf(context).bottom,
            top: vPad,
            left: hPad,
            right: hPad,
          ),
          child: BlocBuilder<RadioBloc, RadioState>(
            builder: (context, state) {
              if (state is RadioLoading) {
                return _buildLoadingState(context, screenWidth);
              } else if (state is RadioError) {
                return _buildErrorState(context, screenWidth, state.message);
              } else if (state is RadioLoaded) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, screenWidth),
                    SizedBox(height: vPad),
                    _buildInterfaceHUD(context, screenWidth, cardRadius, cardPadding, state),
                    SizedBox(height: vPad),
                    _buildPeerDiscoverySection(context, screenWidth, cardRadius, cardPadding, state),
                    SizedBox(height: vPad),
                    _buildManualConnectSection(context, screenWidth, cardRadius, cardPadding, state),
                    SizedBox(height: vPad),
                    _buildDemoSimulatorsSection(context, screenWidth, cardRadius, cardPadding, state),
                    SizedBox(height: vPad),
                    _buildActionLogSection(context, screenWidth, cardRadius, cardPadding, state),
                  ],
                );
              }
              return _buildInitialState(context, screenWidth);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double screenWidth) {
    final headerSize = clampDouble(screenWidth * 0.052, 18.0, 22.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            padding: EdgeInsets.all(clampDouble(screenWidth * 0.025, 8.0, 12.0)),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Icon(
              LucideIcons.chevronLeft,
              color: AppColors.textPrimary,
              size: clampDouble(screenWidth * 0.06, 24.0, 28.0),
            ),
          ),
        ),
        SizedBox(width: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Radio Manager',
                style: TextStyle(
                  fontSize: headerSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
                softWrap: true,
              ),
              SizedBox(height: clampDouble(screenWidth * 0.008, 3.0, 5.0)),
              Text(
                'Links, peers and simulators',
                style: TextStyle(
                  fontSize: metaSize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                  height: 1.25,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInterfaceHUD(
    BuildContext context,
    double screenWidth,
    double cardRadius,
    double cardPadding,
    RadioLoaded state,
  ) {
    final isFailover = state.connectionState == RadioConnectionState.failoverActive;
    final isConnecting = state.connectionState == RadioConnectionState.connecting;
    final statusText = isFailover ? 'FAILOVER' : (isConnecting ? 'CONNECTING' : 'ACTIVE');

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(
            color: isFailover
                ? AppColors.alertRed
                : (isConnecting ? AppColors.primaryEmeraldVibrant : AppColors.surfaceBorder),
            width: isFailover || isConnecting ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              runSpacing: clampDouble(screenWidth * 0.01, 4.0, 6.0),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: clampDouble(screenWidth * 0.025, 8.0, 12.0),
                    vertical: clampDouble(screenWidth * 0.01, 4.0, 6.0),
                  ),
                  decoration: BoxDecoration(
                    color: isFailover
                        ? AppColors.alertRedBg
                        : (isConnecting ? _withOpacity(AppColors.primaryEmerald, 0.12) : _withOpacity(AppColors.primaryEmerald, 0.12)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: clampDouble(screenWidth * 0.030, 11.0, 13.0),
                      fontWeight: FontWeight.w700,
                      color: isFailover
                          ? AppColors.alertRed
                          : (isConnecting ? AppColors.primaryEmeraldVibrant : AppColors.primaryEmerald),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.wifi,
                      color: isFailover ? AppColors.textMuted : AppColors.primaryEmerald,
                      size: clampDouble(screenWidth * 0.045, 18.0, 22.0),
                    ),
                    SizedBox(width: clampDouble(screenWidth * 0.015, 6.0, 8.0)),
                    Flexible(
                      child: Text(
                        state.activeLinkType,
                        style: TextStyle(
                          fontSize: clampDouble(screenWidth * 0.035, 13.0, 15.0),
                          fontWeight: FontWeight.w600,
                          color: isFailover ? AppColors.alertRed : AppColors.textPrimary,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: cardPadding * 0.6),
            _buildInfoRow(
              context,
              screenWidth,
              LucideIcons.cpu,
              'Interface',
              state.interfaceName,
            ),
            SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
            _buildInfoRow(
              context,
              screenWidth,
              LucideIcons.server,
              'IP Address',
              state.ipAddress,
              mono: true,
            ),
            SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
            _buildInfoRow(
              context,
              screenWidth,
              LucideIcons.link,
              'Port',
              state.port.toString(),
              mono: true,
            ),
            SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
            _buildInfoRow(
              context,
              screenWidth,
              LucideIcons.activity,
              'Link Type',
              state.activeLinkType,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    double screenWidth,
    IconData icon,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(clampDouble(screenWidth * 0.02, 8.0, 10.0)),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Icon(
            icon,
            color: AppColors.textSecondary,
            size: clampDouble(screenWidth * 0.045, 16.0, 20.0),
          ),
        ),
        SizedBox(width: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: clampDouble(screenWidth * 0.028, 10.0, 12.0),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: clampDouble(screenWidth * 0.035, 13.0, 15.0),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: mono ? 'monospace' : null,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeerDiscoverySection(
    BuildContext context,
    double screenWidth,
    double cardRadius,
    double cardPadding,
    RadioLoaded state,
  ) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
children: [
                Wrap(
                  spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
                  runSpacing: clampDouble(screenWidth * 0.01, 4.0, 6.0),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.radar,
                      color: AppColors.primaryEmerald,
                      size: clampDouble(screenWidth * 0.045, 18.0, 22.0),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: screenWidth),
                      child: Text(
                        'Discovered Peers',
                        style: TextStyle(
                          fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: clampDouble(screenWidth * 0.025, 10.0, 14.0),
                    vertical: clampDouble(screenWidth * 0.01, 4.0, 6.0),
                  ),
                  decoration: BoxDecoration(
                    color: _withOpacity(AppColors.primaryEmerald, 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${state.discoveredPeers.length}',
                    style: TextStyle(
                      fontSize: clampDouble(screenWidth * 0.03, 11.0, 13.0),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryEmerald,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: cardPadding * 0.6),
            if (state.discoveredPeers.isEmpty)
              _buildEmptyPeers(context, screenWidth)
            else
              Column(
                children: state.discoveredPeers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final peer = entry.value;
                  return _buildPeerCard(context, screenWidth, peer, index == state.discoveredPeers.length - 1);
                }).toList(),
              ),
            SizedBox(height: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.read<RadioBloc>().add(const RadioScanPeersEvent());
                },
                icon: Icon(
                  LucideIcons.refreshCw,
                  size: clampDouble(screenWidth * 0.045, 18.0, 20.0),
                ),
                label: Text(
                  'Scan Peers',
                  style: TextStyle(
                    fontSize: clampDouble(screenWidth * 0.038, 14.0, 16.0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: clampDouble(screenWidth * 0.035, 14.0, 18.0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPeers(BuildContext context, double screenWidth) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: clampDouble(screenWidth * 0.06, 24.0, 32.0)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(clampDouble(screenWidth * 0.05, 18.0, 24.0)),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Icon(
                LucideIcons.search,
                color: AppColors.textMuted,
                size: clampDouble(screenWidth * 0.07, 28.0, 36.0),
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
            Text(
              'No Peers Yet',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.038, 14.0, 16.0),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.015, 6.0, 8.0)),
            Text(
              'Tap Scan to find nearby nodes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.033, 12.0, 14.0),
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerCard(
    BuildContext context,
    double screenWidth,
    DiscoveredPeer peer,
    bool isLast,
  ) {
    final signalColor = _getSignalColor(peer.signalStrength);
    final signalBars = _getSignalBars(peer.signalStrength);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : clampDouble(screenWidth * 0.025, 10.0, 14.0)),
      padding: EdgeInsets.all(clampDouble(screenWidth * 0.03, 12.0, 16.0)),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(clampDouble(screenWidth * 0.025, 10.0, 14.0)),
                decoration: BoxDecoration(
                  color: _withOpacity(signalColor, 0.15),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: signalColor, width: 1.5),
                ),
                child: Icon(
                  LucideIcons.zap,
                  color: signalColor,
                  size: clampDouble(screenWidth * 0.045, 18.0, 22.0),
                ),
              ),
              SizedBox(width: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
              Expanded(
                child: Text(
                  peer.callSign,
                  style: TextStyle(
                    fontSize: clampDouble(screenWidth * 0.038, 14.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: clampDouble(screenWidth * 0.015, 6.0, 8.0)),
          Wrap(
            spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
            runSpacing: clampDouble(screenWidth * 0.01, 4.0, 6.0),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.wifi,
                    color: AppColors.textMuted,
                    size: clampDouble(screenWidth * 0.03, 11.0, 13.0),
                  ),
                  SizedBox(width: clampDouble(screenWidth * 0.01, 4.0, 5.0)),
                  Flexible(
                    child: Text(
                      peer.ipAddress,
                      style: TextStyle(
                        fontSize: clampDouble(screenWidth * 0.03, 11.0, 13.0),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: clampDouble(screenWidth * 0.02, 8.0, 10.0),
                  vertical: clampDouble(screenWidth * 0.005, 2.0, 4.0),
                ),
                decoration: BoxDecoration(
                  color: _withOpacity(signalColor, 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: signalColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...signalBars.map((isActive) => Container(
                            width: clampDouble(screenWidth * 0.008, 3.0, 4.0),
                            height: clampDouble(screenWidth * 0.018, 6.0, 10.0),
                            margin: EdgeInsets.symmetric(horizontal: 1.0),
                            decoration: BoxDecoration(
                              color: isActive ? signalColor : AppColors.surfaceBorder,
                              borderRadius: BorderRadius.circular(1.0),
                            ),
                          )),
                          SizedBox(width: clampDouble(screenWidth * 0.01, 4.0, 6.0)),
                          Flexible(
                            child: Text(
                              peer.status,
                              style: TextStyle(
                                fontSize: clampDouble(screenWidth * 0.030, 11.0, 13.0),
                                fontWeight: FontWeight.w600,
                                color: signalColor,
                              ),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSignalColor(int strength) {
    if (strength >= 80) return AppColors.primaryEmerald;
    if (strength >= 60) return AppColors.primaryEmeraldVibrant;
    if (strength >= 40) return Colors.orange;
    return AppColors.alertRed;
  }

  List<bool> _getSignalBars(int strength) {
    if (strength >= 80) return [true, true, true, true];
    if (strength >= 60) return [true, true, true, false];
    if (strength >= 40) return [true, true, false, false];
    return [true, false, false, false];
  }

  Widget _buildManualConnectSection(
    BuildContext context,
    double screenWidth,
    double cardRadius,
    double cardPadding,
    RadioLoaded state,
  ) {
    final isConnecting = state.connectionState == RadioConnectionState.connecting;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              runSpacing: clampDouble(screenWidth * 0.01, 4.0, 6.0),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  LucideIcons.link,
                  color: AppColors.primaryEmerald,
                  size: clampDouble(screenWidth * 0.045, 18.0, 22.0),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth),
                  child: Text(
                    'Manual Connect',
                    style: TextStyle(
                      fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: cardPadding * 0.6),
            Text(
              'Enter peer IP for direct link',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.033, 12.0, 14.0),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
            _ManualConnectForm(
              isConnecting: isConnecting,
              onConnect: (ip) {
                HapticFeedback.lightImpact();
                context.read<RadioBloc>().add(RadioConnectManualEvent(ip));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoSimulatorsSection(
    BuildContext context,
    double screenWidth,
    double cardRadius,
    double cardPadding,
    RadioLoaded state,
  ) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              runSpacing: clampDouble(screenWidth * 0.01, 4.0, 6.0),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(clampDouble(screenWidth * 0.02, 8.0, 10.0)),
                  decoration: BoxDecoration(
                    color: AppColors.alertRedBg,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Icon(
                    LucideIcons.zap,
                    color: AppColors.alertRed,
                    size: clampDouble(screenWidth * 0.045, 18.0, 22.0),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth),
                  child: Text(
                    'Demo Simulators',
                    style: TextStyle(
                      fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: clampDouble(screenWidth * 0.015, 6.0, 8.0)),
            Text(
              'Failure injection for judge demos',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.033, 12.0, 14.0),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: cardPadding * 0.6),
            _DemoToggleCard(
              screenWidth: screenWidth,
              icon: LucideIcons.wifiOff,
              title: 'Simulate Bad WiFi',
              subtitle: 'Drop link \u2192 LoRa 600 bps',
              value: state.isBadWifiSimulated,
              glowColor: AppColors.alertRed,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                context.read<RadioBloc>().add(RadioToggleBadWifiEvent(val));
              },
            ),
            SizedBox(height: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
            _DemoToggleCard(
              screenWidth: screenWidth,
              icon: LucideIcons.gauge,
              title: 'Throttle Bandwidth',
              subtitle: '600 bps (75 B/s) token bucket',
              value: state.isThrottled,
              glowColor: AppColors.primaryEmerald,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                context.read<RadioBloc>().add(RadioToggleThrottleEvent(val));
              },
            ),
            SizedBox(height: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
            _DemoToggleCard(
              screenWidth: screenWidth,
              icon: LucideIcons.alertTriangle,
              title: 'Simulate Jamming',
              subtitle: '50% ACK drop \u2192 Retry Queue',
              value: state.isJammingSimulated,
              glowColor: AppColors.alertRed,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                context.read<RadioBloc>().add(RadioToggleJammingEvent(val));
              },
            ),
            if (state.isJammingSimulated) ...[
              SizedBox(height: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
              Container(
                padding: EdgeInsets.all(clampDouble(screenWidth * 0.03, 12.0, 16.0)),
                decoration: BoxDecoration(
                  color: AppColors.alertRedBg,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: _withOpacity(AppColors.alertRed, 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.xCircle,
                      color: AppColors.alertRed,
                      size: clampDouble(screenWidth * 0.045, 18.0, 22.0),
                    ),
                    SizedBox(width: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
                    Expanded(
                      child: Text(
                        '${state.packetsDropped} dropped → auto-queued to Logs',
                        style: TextStyle(
                          fontSize: clampDouble(screenWidth * 0.033, 12.0, 14.0),
                          fontWeight: FontWeight.w500,
                          color: AppColors.alertRed,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionLogSection(
    BuildContext context,
    double screenWidth,
    double cardRadius,
    double cardPadding,
    RadioLoaded state,
  ) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              runSpacing: clampDouble(screenWidth * 0.01, 4.0, 6.0),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  LucideIcons.activity,
                  color: AppColors.primaryEmerald,
                  size: clampDouble(screenWidth * 0.045, 18.0, 22.0),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth),
                  child: Text(
                    'Action Log',
                    style: TextStyle(
                      fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: cardPadding * 0.6),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(clampDouble(screenWidth * 0.03, 12.0, 16.0)),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(clampDouble(screenWidth * 0.015, 6.0, 8.0)),
                    decoration: BoxDecoration(
                      color: _withOpacity(AppColors.primaryEmerald, 0.12),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(
                      LucideIcons.info,
                      color: AppColors.primaryEmerald,
                      size: clampDouble(screenWidth * 0.04, 16.0, 20.0),
                    ),
                  ),
                  SizedBox(width: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
                  Expanded(
                    child: Text(
                      state.lastAction,
                      style: TextStyle(
                        fontSize: clampDouble(screenWidth * 0.033, 12.0, 14.0),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, double screenWidth) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(clampDouble(screenWidth * 0.1, 40.0, 60.0)),
        child: Column(
          children: [
            SizedBox(
              width: clampDouble(screenWidth * 0.15, 50.0, 70.0),
              height: clampDouble(screenWidth * 0.15, 50.0, 70.0),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.04, 16.0, 24.0)),
            Text(
              'Initializing Radio...',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, double screenWidth, String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(clampDouble(screenWidth * 0.1, 40.0, 60.0)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(clampDouble(screenWidth * 0.05, 18.0, 24.0)),
              decoration: BoxDecoration(
                color: AppColors.alertRedBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.alertCircle,
                color: AppColors.alertRed,
                size: clampDouble(screenWidth * 0.07, 28.0, 36.0),
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
            Text(
              'Initialization Failed',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.015, 6.0, 8.0)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.03, 11.0, 13.0),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.04, 16.0, 24.0)),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<RadioBloc>().add(const RadioInitializeEvent());
              },
              icon: Icon(LucideIcons.refreshCw, size: clampDouble(screenWidth * 0.045, 18.0, 20.0)),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: clampDouble(screenWidth * 0.08, 32.0, 48.0),
                  vertical: clampDouble(screenWidth * 0.035, 14.0, 18.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState(BuildContext context, double screenWidth) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.radio,
            color: AppColors.textMuted,
            size: clampDouble(screenWidth * 0.18, 64.0, 96.0),
          ),
          SizedBox(height: clampDouble(screenWidth * 0.04, 16.0, 20.0)),
          Text(
            'Radio Manager',
            style: TextStyle(
              fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: clampDouble(screenWidth * 0.015, 6.0, 8.0)),
          Text(
            'Initializing...',
            style: TextStyle(
              fontSize: clampDouble(screenWidth * 0.033, 12.0, 14.0),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualConnectForm extends StatefulWidget {
  final bool isConnecting;
  final Function(String) onConnect;

  const _ManualConnectForm({
    required this.isConnecting,
    required this.onConnect,
  });

  @override
  State<_ManualConnectForm> createState() => _ManualConnectFormState();
}

class _ManualConnectFormState extends State<_ManualConnectForm> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !widget.isConnecting,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^(\d{1,3}\.){0,3}\d{0,3}$')),
          ],
          style: TextStyle(
            fontSize: clampDouble(screenWidth * 0.04, 14.0, 16.0),
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: '192.168.43.xxx',
            hintStyle: TextStyle(
              fontSize: clampDouble(screenWidth * 0.04, 14.0, 16.0),
              color: AppColors.textMuted,
              fontFamily: 'monospace',
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(clampDouble(screenWidth * 0.035, 14.0, 18.0)),
              child: Icon(
                LucideIcons.server,
                color: AppColors.textMuted,
                size: clampDouble(screenWidth * 0.05, 20.0, 24.0),
              ),
            ),
            filled: true,
            fillColor: AppColors.surfaceSecondary,
            contentPadding: EdgeInsets.symmetric(
              horizontal: clampDouble(screenWidth * 0.045, 16.0, 22.0),
              vertical: clampDouble(screenWidth * 0.04, 16.0, 20.0),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(color: AppColors.surfaceBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(color: AppColors.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(color: AppColors.primaryEmerald, width: 1.5),
            ),
          ),
        ),
        SizedBox(height: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.isConnecting
                ? null
                : () {
                    final ip = _controller.text.trim();
                    if (ip.isNotEmpty) {
                      widget.onConnect(ip);
                    }
                  },
            icon: widget.isConnecting
                ? SizedBox(
                    width: clampDouble(screenWidth * 0.045, 18.0, 20.0),
                    height: clampDouble(screenWidth * 0.045, 18.0, 20.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.textWhite),
                    ),
                  )
                : Icon(
                    LucideIcons.link,
                    size: clampDouble(screenWidth * 0.045, 18.0, 20.0),
                  ),
            label: Text(
              widget.isConnecting ? 'Connecting...' : 'Connect',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.038, 14.0, 16.0),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: clampDouble(screenWidth * 0.035, 14.0, 18.0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoToggleCard extends StatefulWidget {
  final double screenWidth;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color glowColor;
  final Function(bool) onChanged;

  const _DemoToggleCard({
    required this.screenWidth,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.glowColor,
    required this.onChanged,
  });

  @override
  State<_DemoToggleCard> createState() => _DemoToggleCardState();
}

class _DemoToggleCardState extends State<_DemoToggleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.value) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_DemoToggleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value && !oldWidget.value) {
      _glowController.repeat(reverse: true);
    } else if (!widget.value && oldWidget.value) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color _withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = widget.screenWidth < 360;
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowOpacity = widget.value ? _glowAnimation.value : 0.0;
        return Container(
          padding: EdgeInsets.all(clampDouble(widget.screenWidth * 0.035, 14.0, 18.0)),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: widget.value
                  ? widget.glowColor.withValues(alpha: 0.6 + glowOpacity * 0.4)
                  : AppColors.surfaceBorder,
              width: widget.value ? 2.0 : 1.0,
            ),
            boxShadow: widget.value
                ? [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.15 * glowOpacity),
                      blurRadius: 12 * glowOpacity,
                      spreadRadius: 2 * glowOpacity,
                    ),
                  ]
                : null,
          ),
          child: isSmallScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(clampDouble(widget.screenWidth * 0.025, 10.0, 12.0)),
                          decoration: BoxDecoration(
                            color: _withOpacity(widget.glowColor, 0.15),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.glowColor,
                            size: clampDouble(widget.screenWidth * 0.05, 20.0, 24.0),
                          ),
                        ),
                        SizedBox(width: clampDouble(widget.screenWidth * 0.03, 12.0, 16.0)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: clampDouble(widget.screenWidth * 0.038, 14.0, 16.0),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                softWrap: true,
                              ),
                              SizedBox(height: clampDouble(widget.screenWidth * 0.005, 2.0, 4.0)),
                              Text(
                                widget.subtitle,
                                style: TextStyle(
                                  fontSize: clampDouble(widget.screenWidth * 0.030, 11.0, 13.0),
                                  color: AppColors.textSecondary,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: clampDouble(widget.screenWidth * 0.02, 8.0, 10.0)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: widget.value,
                        onChanged: widget.onChanged,
                        activeThumbColor: AppColors.textWhite,
                        activeTrackColor: widget.glowColor,
                        inactiveThumbColor: AppColors.textMuted,
                        inactiveTrackColor: AppColors.surfaceBorder,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(clampDouble(widget.screenWidth * 0.025, 10.0, 12.0)),
                      decoration: BoxDecoration(
                        color: _withOpacity(widget.glowColor, 0.15),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.glowColor,
                        size: clampDouble(widget.screenWidth * 0.05, 20.0, 24.0),
                      ),
                    ),
                    SizedBox(width: clampDouble(widget.screenWidth * 0.03, 12.0, 16.0)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: clampDouble(widget.screenWidth * 0.038, 14.0, 16.0),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            softWrap: true,
                          ),
                          SizedBox(height: clampDouble(widget.screenWidth * 0.005, 2.0, 4.0)),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: clampDouble(widget.screenWidth * 0.028, 10.0, 12.0),
                              color: AppColors.textSecondary,
                            ),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.value,
                      onChanged: widget.onChanged,
                      activeThumbColor: AppColors.textWhite,
                      activeTrackColor: widget.glowColor,
                      inactiveThumbColor: AppColors.textMuted,
                      inactiveTrackColor: AppColors.surfaceBorder,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
        );
      },
    );
  }
}