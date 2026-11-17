import '/backend/app_content/app_content.dart';
import '/flutter_flow/internationalization.dart';
import '/passenger/politika/politika_widget.dart';
import 'package:flutter/material.dart';

export 'about_model.dart';

class AboutWidget extends StatefulWidget {
  const AboutWidget({super.key});
  static String routeName = 'about';
  static String routePath = '/about';
  @override
  State<AboutWidget> createState() => _AboutWidgetState();
}

class _AboutWidgetState extends State<AboutWidget> {
  late final Future<Map<String, dynamic>> _operatorNote =
      getBackendContentDocument('about');

  String tr(String ru, String kk) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);

  Widget section(String title, String body, {String? number}) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (number != null) ...[
              Text(number,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
            ],
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.5)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(tr('Как работает MTaxi', 'MTaxi қалай жұмыс істейді'))),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('MTaxi',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              tr('Поездки и доставка в вашем посёлке. Вы согласуете цену до начала поездки.',
                  'Ауылыңыздағы сапарлар мен жеткізу. Сапар басталғанға дейін бағаны келісесіз.'),
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
            const SizedBox(height: 24),
            section(
              tr('Укажите маршрут и свою цену',
                  'Бағыт пен өз бағаңызды көрсетіңіз'),
              tr('Выберите такси или доставку, заполните «Откуда» и «Куда». Минимальная цена местного заказа — 500 ₸. Перед отправкой проверьте сумму и способ оплаты.',
                  'Такси немесе жеткізуді таңдап, «Қайдан» және «Қайда» өрістерін толтырыңыз. Жергілікті тапсырыстың ең төменгі бағасы — 500 ₸. Жіберер алдында сома мен төлем тәсілін тексеріңіз.'),
              number: '01',
            ),
            section(
              tr('Сравните предложения водителей',
                  'Жүргізушілердің ұсыныстарын салыстырыңыз'),
              tr('Водитель может принять вашу цену или предложить свою. Предложение действует 30 секунд: проверьте цену, данные водителя и расчётное время подачи, затем примите или отклоните его.',
                  'Жүргізуші сіздің бағаңызды қабылдай алады немесе өз бағасын ұсынады. Ұсыныс 30 секунд жарамды: бағаны, жүргізуші туралы мәліметтерді және болжалды келу уақытын тексеріп, қабылдаңыз не бас тартыңыз.'),
              number: '02',
            ),
            section(
              tr('Следите за подачей и поездкой',
                  'Көліктің келуін және сапарды бақылаңыз'),
              tr('После назначения водителя маршрут и движение показываются на карте. Время подачи зависит от дороги, связи и точности геолокации. При спорном статусе или оплате обратитесь в поддержку.',
                  'Жүргізуші тағайындалғаннан кейін бағыт пен қозғалыс картада көрсетіледі. Келу уақыты жолға, байланысқа және геолокация дәлдігіне байланысты. Мәртебе не төлем бойынша дау болса, қолдау қызметіне жүгініңіз.'),
              number: '03',
            ),
            section(
              tr('Деньги и бонусы — отдельно',
                  'Ақша мен бонустар бөлек есептеледі'),
              tr('Пассажир может оплатить поездку доступным денежным балансом и бонусами. Бонусами можно покрыть часть или всю стоимость в пределах доступного остатка. Бонусы водителя расходуются только на комиссию и не выводятся. Актуальные начисления и условия смотрите в кошельке.',
                  'Жолаушы сапарды қолжетімді ақшалай теңгеріммен және бонустармен төлей алады. Қолжетімді қалдық шегінде құнның бір бөлігін не толық құнын бонустармен жабуға болады. Жүргізушінің бонустары тек комиссияға жұмсалады және шығарылмайды. Өзекті есептеулер мен шарттарды әмияннан қараңыз.'),
            ),
            section(
              tr('Как проходит пополнение Kaspi',
                  'Kaspi арқылы толықтыру тәртібі'),
              tr('Укажите номер и сумму пополнения. Оператор выставит счёт и после проверки оплаты подтвердит зачисление. Созданная заявка ещё не означает оплату. MTaxi не запрашивает банковские пароли и коды.',
                  'Толықтыру нөмірі мен сомасын көрсетіңіз. Оператор шот ұсынып, төлемді тексергеннен кейін ақшаның түсуін растайды. Өтінім жасау төлем жасалды дегенді білдірмейді. MTaxi банк құпиясөздері мен кодтарын сұрамайды.'),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _operatorNote,
              builder: (context, snapshot) {
                final text = (snapshot.data?['title'] ?? '').toString().trim();
                if (text.isEmpty) return const SizedBox.shrink();
                return section(tr('От оператора', 'Оператордан'), text);
              },
            ),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const PolitikaWidget(),
              )),
              child: Text(tr('Документы и контакты оператора',
                  'Құжаттар мен оператордың байланыс деректері')),
            ),
            const SizedBox(height: 12),
            Text(tr(
                'В профиле доступны поддержка и настройки. Удаление аккаунта — в настройках профиля.',
                'Профильде қолдау қызметі мен баптаулар бар. Есептік жазбаны профиль баптауларында жоюға болады.')),
          ]),
        ),
      );
}
