import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleStorageKey = '__locale_key__';

class FFLocalizations {
  FFLocalizations(this.locale);

  final Locale locale;

  static FFLocalizations of(BuildContext context) =>
      Localizations.of<FFLocalizations>(context, FFLocalizations)!;

  static List<String> languages() => ['ru', 'kk'];

  static late SharedPreferences _prefs;
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();
  static Future storeLocale(String locale) =>
      _prefs.setString(_kLocaleStorageKey, locale);
  static Locale? getStoredLocale() {
    final locale = _prefs.getString(_kLocaleStorageKey);
    return locale != null && locale.isNotEmpty ? createLocale(locale) : null;
  }

  String get languageCode => locale.toString();
  String? get languageShortCode =>
      _languagesWithShortCode.contains(locale.toString())
          ? '${locale.toString()}_short'
          : null;
  int get languageIndex => languages().contains(languageCode)
      ? languages().indexOf(languageCode)
      : 0;

  String getText(String key) =>
      (kTranslationsMap[key] ?? {})[locale.toString()] ?? '';

  String getVariableText({
    String? ruText = '',
    String? kkText = '',
  }) =>
      [ruText, kkText][languageIndex] ?? '';

  static const Set<String> _languagesWithShortCode = {
    'ar',
    'az',
    'ca',
    'cs',
    'da',
    'de',
    'dv',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'gr',
    'he',
    'hi',
    'hu',
    'it',
    'km',
    'ku',
    'mn',
    'ms',
    'no',
    'pt',
    'ro',
    'ru',
    'rw',
    'sv',
    'th',
    'uk',
    'vi',
  };
}

/// Used if the locale is not supported by GlobalMaterialLocalizations.
class FallbackMaterialLocalizationDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(FallbackMaterialLocalizationDelegate old) => false;
}

/// Used if the locale is not supported by GlobalCupertinoLocalizations.
class FallbackCupertinoLocalizationDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}

class FFLocalizationsDelegate extends LocalizationsDelegate<FFLocalizations> {
  const FFLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<FFLocalizations> load(Locale locale) =>
      SynchronousFuture<FFLocalizations>(FFLocalizations(locale));

  @override
  bool shouldReload(FFLocalizationsDelegate old) => false;
}

Locale createLocale(String language) => language.contains('_')
    ? Locale.fromSubtags(
        languageCode: language.split('_').first,
        scriptCode: language.split('_').last,
      )
    : Locale(language);

bool _isSupportedLocale(Locale locale) {
  final language = locale.toString();
  return FFLocalizations.languages().contains(
    language.endsWith('_')
        ? language.substring(0, language.length - 1)
        : language,
  );
}

final kTranslationsMap = <Map<String, Map<String, String>>>[
  // HomePage
  {
    'd7i6okg3': {
      'ru': 'Такси',
      'kk': 'Такси',
    },
    'ctxotw3b': {
      'ru': 'Доставка',
      'kk': 'Доставка',
    },
    'ipvfmv3i': {
      'ru': 'Вы находитесь: ',
      'kk': 'Сіз осындасыз:',
    },
    'tzsfut85': {
      'ru': '',
      'kk': '',
    },
    'gau6r2w1': {
      'ru': 'Куда:',
      'kk': 'Сіз осындасыз:',
    },
    'dezdwdlh': {
      'ru': 'Комментарий водителю',
      'kk': 'Жүргізушіге түсініктеме беріңіз',
    },
    '0kzx86tp': {
      'ru': 'Заказать',
      'kk': 'Тапсырыс беру',
    },
    '3drmi8im': {
      'ru': 'Главная',
      'kk': 'Басты',
    },
  },
  // login
  {
    'mfjd8bcg': {
      'ru': 'Номер телефона',
      'kk': 'Телефон нөмірі',
    },
    'vuy0ty4t': {
      'ru': 'Введите номер телефона',
      'kk': 'Введите номер телефона',
    },
    '85sktxxx': {
      'ru':
          'Cогласие с пользовательским соглашением и политикой конфиденциальности',
      'kk':
          'Cогласие с пользовательским соглашением и политикой конфиденциальности',
    },
    '7nzuoxsh': {
      'ru':
          'Пользователь, принимая условия Политики конфиденциальности, согласен на обработку и хранение персональных данных на серверах оператора. Firebase используется только для push-уведомлений.',
      'kk':
          'Пользователь, принимая условия Политики конфиденциальности, согласен на обработку и хранение персональных данных на серверах оператора. Firebase используется только для push-уведомлений.',
    },
    'd84d0cr0': {
      'ru': 'Продолжить',
      'kk': 'Жалғастыру',
    },
    'wa85e8cz': {
      'ru': 'Темная тема',
      'kk': 'Қараңғы тақырып',
    },
    't1j6apn9': {
      'ru': 'Светлая тема',
      'kk': 'Жеңіл тақырып',
    },
  },
  // smsVirefication
  {
    'ubop26oq': {
      'ru': 'Введите SMS код ',
      'kk': 'Құпия сөзді енгізіңіз',
    },
    'zrzm2hrb': {
      'ru': 'Продолжить',
      'kk': 'Жалғастыру',
    },
  },
  // setProfile
  {
    'ub7rn9v5': {
      'ru': 'Имя и Фамилия',
      'kk': 'Аты',
    },
    '095kee8w': {
      'ru': 'Населенный пункт',
      'kk': 'Сіздің қалаңыз',
    },
    'd7mxm410': {
      'ru': 'Option 1',
      'kk': '1-нұсқа',
    },
    'seq0y5x9': {
      'ru': 'Далее',
      'kk': 'Келесі',
    },
    'f3e3tvnp': {
      'ru': 'Home',
      'kk': 'Үй',
    },
  },
  // cityToCity
  {
    'um7cqc1t': {
      'ru': 'Заявка',
      'kk': 'Баға',
    },
    'qd4bkhxk': {
      'ru': 'Откуда',
      'kk': 'Қайда',
    },
    'srj898il': {
      'ru': 'Откуда',
      'kk': 'Қайда',
    },
    '4agems80': {
      'ru': 'Куда',
      'kk': 'Қайда',
    },
    'dmnv55m2': {
      'ru': 'Куда',
      'kk': 'Қайда',
    },
    'xfmzhxdr': {
      'ru': 'Цена',
      'kk': 'Бағасы',
    },
    '86tekkvp': {
      'ru': 'Цена',
      'kk': 'Бағасы',
    },
    'tpz0l4p2': {
      'ru': 'Подать заявку',
      'kk': 'Өтінім жіберіңіз',
    },
    'xbbxtgzi': {
      'ru': 'Водители',
      'kk': 'Жүргізушілер',
    },
    'pgr6zo7j': {
      'ru': 'Поиск',
      'kk': 'Іздеу',
    },
    '1q13ycvt': {
      'ru': 'Откуда',
      'kk': 'Қайда',
    },
    'qbsccm6a': {
      'ru': 'Откуда',
      'kk': 'Қайда',
    },
    'xiyhvx97': {
      'ru': 'Куда',
      'kk': 'Қайда',
    },
    '6qz8soal': {
      'ru': 'Куда',
      'kk': 'Қайда',
    },
    'p9uah7h0': {
      'ru': 'Найти',
      'kk': 'Табу',
    },
    '7sfu2y19': {
      'ru': 'Мои заявки',
      'kk': 'Менің өтініштерім',
    },
    'kat667nv': {
      'ru': 'Удалить',
      'kk': 'Жою',
    },
    'mvxkgibp': {
      'ru': 'Межгород',
      'kk': 'Қалааралық',
    },
  },
  // profile
  {
    'uhr9e7qc': {
      'ru': 'Баланс:',
      'kk': 'Баланс:',
    },
    'd2utpeg4': {
      'ru': 'Пополнить',
      'kk': 'Толықтыру',
    },
    'syts6p3p': {
      'ru': 'Настройки',
      'kk': 'Параметрлер',
    },
    'k64apm2v': {
      'ru': 'Русский язык',
      'kk': 'Орыс тілі',
    },
    'css1tnhn': {
      'ru': 'Казахский язык',
      'kk': 'Қазақ тілі',
    },
    'dhvbseyf': {
      'ru': 'История заказов',
      'kk': 'Тапсырыс тарихы',
    },
    'ezjs0vym': {
      'ru': 'О нас',
      'kk': 'Біз туралы',
    },
    '5s603yxq': {
      'ru': 'Политика и условия',
      'kk': 'Саясат және шарттар',
    },
    'ek4exelq': {
      'ru': 'Тарифы',
      'kk': 'Тарифтер',
    },
    'ktxcnax7': {
      'ru': 'Выйти с аккаунта',
      'kk': 'Есептік жазбадан шығу',
    },
    'w0ogglqz': {
      'ru': 'Удалить аккаунт',
      'kk': 'Есептік жазбаны жою',
    },
    'jfo9zw67': {
      'ru': 'Профиль',
      'kk': 'Профиль',
    },
  },
  // meOrder
  {
    'ehfg3zec': {
      'ru': 'Мои заказы',
      'kk': 'Менің тапсырыстарым',
    },
    'cblg30k5': {
      'ru': 'Home',
      'kk': 'Үй',
    },
  },
  // about
  {
    'vewtba77': {
      'ru': 'О нас',
      'kk': 'Біз туралы',
    },
    'acr6tf4p': {
      'ru': 'Home',
      'kk': 'Үй',
    },
  },
  // politika
  {
    '4a9cqlwr': {
      'ru': 'Политика и условия',
      'kk': 'Саясат және шарттар',
    },
    'nwb6w1tc': {
      'ru': 'Home',
      'kk': 'Үй',
    },
  },
  // tarif
  {
    'qgzwbsea': {
      'ru': 'Тарифы',
      'kk': 'Тарифтер',
    },
    'l3s1g10r': {
      'ru': 'Home',
      'kk': 'Үй',
    },
  },
  // seachDriver
  {
    'vnzdv00t': {
      'ru': 'Поиск водителя',
      'kk': 'Жүргізушіні іздеу',
    },
    '5b0clgtn': {
      'ru': 'Принять',
      'kk': 'Қабылдау',
    },
    'h8husvgh': {
      'ru': 'Отклонить',
      'kk': 'Қабылдамау',
    },
    'b4fwc6ax': {
      'ru': 'Водитель в пути',
      'kk': 'Жүргізуші жолда',
    },
    'bx5ryu2b': {
      'ru': 'Отменить заказ',
      'kk': 'Тапсырысты болдырмау',
    },
    '11i973ci': {
      'ru': 'Позвонить водителю',
      'kk': 'Жүргізушіге қоңырау шалу',
    },
    '7g7y01mw': {
      'ru': 'Водитель ожидает вас',
      'kk': 'Жүргізуші сізді күтіп тұр',
    },
    'vnsgumdt': {
      'ru': 'Отменить заказ',
      'kk': 'Тапсырысты болдырмау',
    },
    'e757xikk': {
      'ru': 'Позвонить водителю',
      'kk': 'Жүргізушіге қоңырау шалу',
    },
    'oy2x4ci6': {
      'ru': 'Приятной поездки',
      'kk': 'Сапарыңыз сәтті болсын',
    },
    '3du10sgs': {
      'ru': 'Как прошла поездка?',
      'kk': 'Сапар қалай өтті?',
    },
    'ae1emkoh': {
      'ru': 'Оцените водителя:',
      'kk': 'Жүргізушіні бағалаңыз:',
    },
    'x3psktqs': {
      'ru': 'Закрыть',
      'kk': 'Жабу',
    },
    'yy49uaf3': {
      'ru': 'Город',
      'kk': 'Қала',
    },
  },
  // setProfileDriver
  {
    '4ra1qaza': {
      'ru': 'Ваше фото',
      'kk': 'Сіздің фотосуретіңіз',
    },
    'n6nfl2wl': {
      'ru': 'Имя',
      'kk': 'Аты',
    },
    'e61j3fsj': {
      'ru': 'Фамилия',
      'kk': 'Тегі',
    },
    'z8p3pkmb': {
      'ru': 'Придумайте пароль',
      'kk': 'Құпиясөз ойлап табыңыз',
    },
    '3u2799x2': {
      'ru': 'Повторите пароль',
      'kk': 'Құпиясөзді қайталаңыз',
    },
    'otwuet73': {
      'ru': 'Гос. Номер',
      'kk': 'Мемлекеттік нөмірі',
    },
    '77se37qq': {
      'ru': 'Цвет авто',
      'kk': 'Көлік түсі',
    },
    '4rnxa3yb': {
      'ru': 'Ваш город',
      'kk': 'Сіздің қалаңыз',
    },
    'ng2fhoq4': {
      'ru': 'Option 1',
      'kk': '1-нұсқа',
    },
    'jae81zbb': {
      'ru': 'Дата рождения',
      'kk': 'Туған күні',
    },
    'ykq61gl7': {
      'ru': 'Далее',
      'kk': 'Келесі',
    },
    'sm34687d': {
      'ru': 'Home',
      'kk': 'Home',
    },
  },
  // homeDriver
  {
    'wz03ijzb': {
      'ru': 'Home',
      'kk': 'Home',
    },
  },
  // homeDriverOrder
  {
    'qengqwvq': {
      'ru': 'Ваше предложение:',
      'kk': 'Сіздің ұсынысыңыз:',
    },
    'prg6ranz': {
      'ru': 'Отменить',
      'kk': 'Бас тарту',
    },
    '3yq9hpc2': {
      'ru': 'Отменить заказ',
      'kk': 'Тапсырысты болдырмау',
    },
    'itk8h4k6': {
      'ru': 'Позвонить пассажиру',
      'kk': 'Жолаушыға қоңырау шалу',
    },
    'vg5doj63': {
      'ru': 'На месте',
      'kk': 'Орнында',
    },
    'czouzoh2': {
      'ru': 'Отменить заказ',
      'kk': 'Тапсырысты болдырмау',
    },
    'bxf0c872': {
      'ru': 'Позвонить пассажиру',
      'kk': 'Жолаушыға қоңырау шалу',
    },
    'tuafhyu7': {
      'ru': 'Поездка началась',
      'kk': 'Сапар басталды',
    },
    'jtywv6to': {
      'ru': 'Отменить заказ',
      'kk': 'Тапсырысты болдырмау',
    },
    'afzible9': {
      'ru': 'Позвонить пассажиру',
      'kk': 'Жолаушыға қоңырау шалу',
    },
    'em0tbhtk': {
      'ru': 'Поездка завершена ',
      'kk': 'Сапар аяқталды',
    },
    'tjoqlsxc': {
      'ru': 'Как прошла поездка?',
      'kk': 'Сапар қалай өтті?',
    },
    '3asauvo1': {
      'ru': 'Оцените пассажира:',
      'kk': 'Жолаушыны бағалаңыз:',
    },
    '655dut6a': {
      'ru': 'Закрыть',
      'kk': 'Жабу',
    },
    'hmf12chq': {
      'ru': 'Home',
      'kk': 'Home',
    },
  },
  // EditOt
  {
    'ort4s3os': {
      'ru': 'Введите адрес откуда вас забрать?',
      'kk': 'Сізді қай жерден алып кететін мекенжайыңызды енгізіңіз?',
    },
    'cs29mwp3': {
      'ru': 'Введите адрес',
      'kk': 'Мекенжайды енгізіңіз',
    },
    'eha2khr5': {
      'ru': 'Option 1',
      'kk': '1-нұсқа',
    },
    'pzftczuq': {
      'ru': 'Сохранить',
      'kk': 'Сақтау',
    },
  },
  // setLang
  {
    '747mwqtn': {
      'ru': 'Русский язык',
      'kk': 'Орыс тілі',
    },
    'f0g95qzg': {
      'ru': 'Казахский язык',
      'kk': 'Қазақ тілі',
    },
  },
  // selectBalance
  {
    'z7k6pyqm': {
      'ru': 'Введите сумму на которую хотите пополнить',
      'kk': 'Толықтырғыңыз келетін соманы енгізіңіз',
    },
    '22igrtdf': {
      'ru': 'Сумма пополнения',
      'kk': 'Толықтыру сомасы',
    },
    'l63lcb7u': {
      'ru': 'Закрыть',
      'kk': 'Жабу',
    },
    'vcuaf3du': {
      'ru': 'Пополнить',
      'kk': 'Толықтыру',
    },
  },
  // paymentPage
  {
    '0myks36k': {
      'ru': 'Вернуться в приложение',
      'kk': 'Қосымшаға оралу',
    },
  },
  // Editkuda
  {
    '5pzzplbn': {
      'ru': 'Введите адрес конечной точки?',
      'kk': 'Сізді қай жерден алып кететін мекенжайыңызды енгізіңіз?',
    },
    '309yrxpg': {
      'ru': 'Введите адрес',
      'kk': 'Мекенжайды енгізіңіз',
    },
    'sdepcyhh': {
      'ru': 'Option 1',
      'kk': '1-нұсқа',
    },
    '18pcaf1u': {
      'ru': 'Сохранить',
      'kk': 'Сақтау',
    },
    'e57cmal8': {
      'ru': '',
      'kk': '',
    },
  },
  // setRole
  {
    'clmphjaf': {
      'ru': 'Пассажир',
      'kk': 'Жолаушы',
    },
    '4ibkabcs': {
      'ru': 'Водитель',
      'kk': 'Жүргізуші',
    },
  },
  // Miscellaneous
  {
    '2v4dbdq7': {
      'ru': 'Загрузка фото',
      'kk': 'Фото жүктеп салынуда',
    },
    'oiqsmn1h': {
      'ru': 'Загрузка фото',
      'kk': 'Фото жүктеп салынуда',
    },
    'urahspmy': {
      'ru': '',
      'kk': '',
    },
    'u6hy4dv3': {
      'ru': 'Определение местоположения',
      'kk': 'Орналасқан жерді анықтау',
    },
    'fiks8z2q': {
      'ru': 'Получение уведомлений',
      'kk': 'Хабарландыруларды алу',
    },
    'dg2dkmjx': {
      'ru': 'Выбор даты рождения',
      'kk': 'Туған күнін таңдаңыз',
    },
    'an3imoyd': {
      'ru': '',
      'kk': '',
    },
    'u4ycect0': {
      'ru': '',
      'kk': '',
    },
    'oxztglji': {
      'ru': '',
      'kk': '',
    },
    'izhzo3xg': {
      'ru': '',
      'kk': '',
    },
    'f55fwr2x': {
      'ru': '',
      'kk': '',
    },
    'yz8s7t08': {
      'ru': '',
      'kk': '',
    },
    'su3m56cx': {
      'ru': '',
      'kk': '',
    },
    'khyz7mbg': {
      'ru': '',
      'kk': '',
    },
    'rfac2pk6': {
      'ru': '',
      'kk': '',
    },
    'fn6gf95n': {
      'ru': '',
      'kk': '',
    },
    'gh3y7cbf': {
      'ru': '',
      'kk': '',
    },
    'af4f4fvx': {
      'ru': '',
      'kk': '',
    },
    'k8dr9o3u': {
      'ru': '',
      'kk': '',
    },
    's73801ea': {
      'ru': '',
      'kk': '',
    },
    'tbptlzo4': {
      'ru': '',
      'kk': '',
    },
    'w327044r': {
      'ru': '',
      'kk': '',
    },
    '0gqh7yn4': {
      'ru': '',
      'kk': '',
    },
    'v3xxp86v': {
      'ru': '',
      'kk': '',
    },
    'fvmwv3mt': {
      'ru': '',
      'kk': '',
    },
    's2olrvbl': {
      'ru': '',
      'kk': '',
    },
    'rwkobnn6': {
      'ru': '',
      'kk': '',
    },
    'c667y29x': {
      'ru': '',
      'kk': '',
    },
    'yetcsnhx': {
      'ru': '',
      'kk': '',
    },
    'kmphr0jj': {
      'ru': '',
      'kk': '',
    },
    'wgxczrs2': {
      'ru': '',
      'kk': '',
    },
  },
].reduce((a, b) => a..addAll(b));
