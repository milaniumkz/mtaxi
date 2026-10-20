import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'set_role_model.dart';
export 'set_role_model.dart';

const _mtaxiOrange = Color(0xFFFF6B00);
const _mtaxiMint = Color(0xFF28D8C6);
const _mtaxiText = Color(0xFF171D22);
const _mtaxiMuted = Color(0xFF5B6670);

class SetRoleWidget extends StatefulWidget {
  const SetRoleWidget({super.key});

  @override
  State<SetRoleWidget> createState() => _SetRoleWidgetState();
}

class _SetRoleWidgetState extends State<SetRoleWidget> {
  late SetRoleModel _model;
  String _selectedRole = 'passenger';

  Future<void> _selectRole(String role) async {
    FFAppState().pendingRegistrationRole = role;
    FFAppState().update(() {});
    if (Navigator.canPop(context)) {
      Navigator.pop(context, role);
      return;
    }

    final targetRoute = role == 'driver'
        ? SetProfileDriverWidget.routeName
        : SetProfileWidget.routeName;
    context.goNamedAuth(
      targetRoute,
      context.mounted,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.scale,
          alignment: Alignment.bottomCenter,
        ),
      },
    );
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SetRoleModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final appBarBg = isDark ? _mtaxiMint : const Color(0xFFFFFFFF);
    final appBarText = isDark ? Colors.white : _mtaxiText;
    final ctaColor = isDark ? _mtaxiMint : _mtaxiOrange;
    final ctaTextColor = isDark ? const Color(0xFF071718) : Colors.white;
    final textColor = isDark ? Colors.white : _mtaxiText;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0.0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Выбор роли',
          style: GoogleFonts.readexPro(
            color: appBarText,
            fontSize: 21.0,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 46.0, 24.0, 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Кем будете пользоваться?',
                style: GoogleFonts.readexPro(
                  color: textColor,
                  fontSize: 23.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 38.0),
              _RoleCard(
                title: FFLocalizations.of(context).getText(
                  'clmphjaf' /* Пассажир */,
                ),
                subtitle: 'Заказать такси, доставку или межгород',
                selected: _selectedRole == 'passenger',
                onTap: () => setState(() => _selectedRole = 'passenger'),
              ),
              const SizedBox(height: 24.0),
              _RoleCard(
                title: FFLocalizations.of(context).getText(
                  '4ibkabcs' /* Водитель */,
                ),
                subtitle: 'Принимать заказы и управлять балансом',
                selected: _selectedRole == 'driver',
                onTap: () => setState(() => _selectedRole = 'driver'),
              ),
              const Spacer(),
              FFButtonWidget(
                onPressed: () async => _selectRole(_selectedRole),
                text: 'Продолжить',
                options: FFButtonOptions(
                  width: double.infinity,
                  height: 54.0,
                  padding: EdgeInsets.zero,
                  iconPadding: EdgeInsets.zero,
                  color: ctaColor,
                  textStyle: GoogleFonts.readexPro(
                    color: ctaTextColor,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w800,
                  ),
                  elevation: 0.0,
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final selectedColor = isDark ? _mtaxiMint : _mtaxiOrange;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFD8DEE6);
    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 110.0),
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 18.0, 20.0),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: selected ? selectedColor : borderColor,
            width: 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10.0,
              height: 10.0,
              margin: const EdgeInsets.only(top: 6.0),
              decoration: BoxDecoration(
                color: selected ? selectedColor : borderColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 28.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.readexPro(
                      color: textColor,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    subtitle,
                    style: GoogleFonts.readexPro(
                      color: mutedColor,
                      fontSize: 13.0,
                      height: 1.25,
                      fontWeight: FontWeight.w400,
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
}
