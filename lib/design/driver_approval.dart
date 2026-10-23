import 'package:flutter/material.dart';
import '/flutter_flow/internationalization.dart';
import 'mtaxi_theme.dart';

class DriverApproval extends StatelessWidget {
  const DriverApproval(
      {super.key, required this.onProfile, required this.onSupport});
  final VoidCallback onProfile, onSupport;
  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    return Scaffold(
        appBar:
            AppBar(title: Text(tr('Анкета отправлена', 'Сауалнама жіберілді'))),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(22), children: [
          const SizedBox(height: 32),
          Center(
              child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: MTaxiDesign.gold.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(24)),
                  child: const Icon(Icons.verified_user_outlined, size: 40))),
          const SizedBox(height: 28),
          Text(tr('Всё получили!', 'Барлығын алдық!'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 31, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text(
              tr('Администратор проверит анкету и документы. Принимать заказы можно после подтверждения.',
                  'Әкімші сауалнама мен құжаттарды тексереді. Растаудан кейін тапсырыстарды қабылдай аласыз.'),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          MTaxiCard(
              child: Text(tr(
                  '1 000 бонусных ₸ — один раз после первого подтверждения. Бонусами можно оплачивать комиссию сервиса, вывести их нельзя.',
                  '1 000 бонус ₸ — алғаш расталғаннан кейін бір рет. Бонустармен сервис комиссиясын төлеуге болады, шығаруға болмайды.'))),
          const SizedBox(height: 32),
          FilledButton(
              onPressed: onProfile,
              child: Text(tr('Вернуться в профиль', 'Профильге оралу'))),
          TextButton(
              onPressed: onSupport,
              child: Text(tr('Написать в поддержку', 'Қолдауға жазу'))),
        ])));
  }
}
