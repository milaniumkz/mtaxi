import '/design/mtaxi_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

import '/index.dart';
import 'package:flutter/material.dart';

import 'set_role_model.dart';
export 'set_role_model.dart';

const _mtaxiOrange = Color(0xFFE6BD63);
const _mtaxiMint = Color(0xFF126E68);
const _mtaxiText = Color(0xFF1B242B);
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
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    return Scaffold(
        appBar: AppBar(
            title: Text(tr('Как будете пользоваться?', 'Қалай пайдаланасыз?'))),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(22), children: [
          const MTaxiBrand(),
          const SizedBox(height: 32),
          Text(tr('Куда отправимся?', 'Қайда барамыз?'),
              style:
                  const TextStyle(fontSize: 31, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(tr('Выберите роль. Её можно изменить в профиле.',
              'Рөлді таңдаңыз. Оны профильде өзгертуге болады.')),
          const SizedBox(height: 28),
          _RoleCard(
              title: tr('Пассажир', 'Жолаушы'),
              subtitle: tr('Заказывать такси и доставку',
                  'Такси мен жеткізуге тапсырыс беру'),
              selected: _selectedRole == 'passenger',
              onTap: () => setState(() => _selectedRole = 'passenger')),
          const SizedBox(height: 16),
          _RoleCard(
              title: tr('Водитель', 'Жүргізуші'),
              subtitle: tr('Принимать заказы и управлять счётом',
                  'Тапсырыстарды қабылдау және шотты басқару'),
              selected: _selectedRole == 'driver',
              onTap: () => setState(() => _selectedRole = 'driver')),
          const SizedBox(height: 32),
          FilledButton(
              onPressed: () => _selectRole(_selectedRole),
              child: Text(tr('Продолжить', 'Жалғастыру'))),
        ])));
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
      borderRadius: BorderRadius.circular(20.0),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 110.0),
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 18.0, 20.0),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20.0),
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
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      color: textColor,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
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
