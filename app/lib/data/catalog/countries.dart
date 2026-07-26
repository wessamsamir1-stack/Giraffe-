/// دول الإطلاق: مصر + دول الخليج.
///
/// كل دولة ليها عملة بعدد خانات عشرية مختلف — الدينار الكويتي والبحريني
/// والريال العماني بـ 3 خانات، والباقي بخانتين. ده بيكسر التنسيق لو
/// مش متعامل معاه من الأول.
class Country {
  const Country({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.dialCode,
    required this.flag,
    required this.currency,
    required this.phoneDigits,
    required this.cities,
  });

  final String code; // ISO alpha-2
  final String nameAr;
  final String nameEn;
  final String dialCode;
  final String flag;
  final Currency currency;

  /// عدد أرقام الموبايل بعد كود الدولة وبدون الصفر البادئ.
  final int phoneDigits;

  final List<City> cities;

  String name(bool ar) => ar ? nameAr : nameEn;
}

class Currency {
  const Currency({
    required this.code,
    required this.symbolAr,
    required this.symbolEn,
    required this.decimals,
  });

  final String code;
  final String symbolAr;
  final String symbolEn;
  final int decimals;

  String format(num value, {required bool ar}) {
    final text = value.toStringAsFixed(decimals);
    return ar ? '$text ${symbolAr}' : '$text $symbolEn';
  }

  /// تنسيق مختصر بدون كسور — للاستخدام في الكروت الضيقة.
  String formatCompact(num value, {required bool ar}) {
    final rounded = value.round();
    return ar ? '$rounded ${symbolAr}' : '$rounded $symbolEn';
  }
}

class City {
  const City({required this.id, required this.nameAr, required this.nameEn});

  final String id;
  final String nameAr;
  final String nameEn;

  String name(bool ar) => ar ? nameAr : nameEn;
}

const _egp = Currency(code: 'EGP', symbolAr: 'ج.م', symbolEn: 'EGP', decimals: 2);
const _sar = Currency(code: 'SAR', symbolAr: 'ر.س', symbolEn: 'SAR', decimals: 2);
const _aed = Currency(code: 'AED', symbolAr: 'د.إ', symbolEn: 'AED', decimals: 2);
const _kwd = Currency(code: 'KWD', symbolAr: 'د.ك', symbolEn: 'KWD', decimals: 3);
const _qar = Currency(code: 'QAR', symbolAr: 'ر.ق', symbolEn: 'QAR', decimals: 2);
const _bhd = Currency(code: 'BHD', symbolAr: 'د.ب', symbolEn: 'BHD', decimals: 3);
const _omr = Currency(code: 'OMR', symbolAr: 'ر.ع', symbolEn: 'OMR', decimals: 3);

class Countries {
  const Countries._();

  static const List<Country> all = [egypt, saudi, uae, kuwait, qatar, bahrain, oman];

  static Country byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => egypt);

  static const Country egypt = Country(
    code: 'EG',
    nameAr: 'مصر',
    nameEn: 'Egypt',
    dialCode: '+20',
    flag: '🇪🇬',
    currency: _egp,
    phoneDigits: 10,
    cities: [
      City(id: 'cairo', nameAr: 'القاهرة', nameEn: 'Cairo'),
      City(id: 'giza', nameAr: 'الجيزة', nameEn: 'Giza'),
      City(id: 'alex', nameAr: 'الإسكندرية', nameEn: 'Alexandria'),
      City(id: 'mansoura', nameAr: 'المنصورة', nameEn: 'Mansoura'),
      City(id: 'tanta', nameAr: 'طنطا', nameEn: 'Tanta'),
      City(id: 'zagazig', nameAr: 'الزقازيق', nameEn: 'Zagazig'),
      City(id: 'ismailia', nameAr: 'الإسماعيلية', nameEn: 'Ismailia'),
      City(id: 'portsaid', nameAr: 'بورسعيد', nameEn: 'Port Said'),
      City(id: 'suez', nameAr: 'السويس', nameEn: 'Suez'),
      City(id: 'asyut', nameAr: 'أسيوط', nameEn: 'Asyut'),
      City(id: 'sohag', nameAr: 'سوهاج', nameEn: 'Sohag'),
      City(id: 'minya', nameAr: 'المنيا', nameEn: 'Minya'),
      City(id: 'fayoum', nameAr: 'الفيوم', nameEn: 'Fayoum'),
      City(id: 'luxor', nameAr: 'الأقصر', nameEn: 'Luxor'),
      City(id: 'aswan', nameAr: 'أسوان', nameEn: 'Aswan'),
      City(id: 'hurghada', nameAr: 'الغردقة', nameEn: 'Hurghada'),
      City(id: 'damietta', nameAr: 'دمياط', nameEn: 'Damietta'),
      City(id: 'beheira', nameAr: 'البحيرة', nameEn: 'Beheira'),
    ],
  );

  static const Country saudi = Country(
    code: 'SA',
    nameAr: 'السعودية',
    nameEn: 'Saudi Arabia',
    dialCode: '+966',
    flag: '🇸🇦',
    currency: _sar,
    phoneDigits: 9,
    cities: [
      City(id: 'riyadh', nameAr: 'الرياض', nameEn: 'Riyadh'),
      City(id: 'jeddah', nameAr: 'جدة', nameEn: 'Jeddah'),
      City(id: 'makkah', nameAr: 'مكة المكرمة', nameEn: 'Makkah'),
      City(id: 'madinah', nameAr: 'المدينة المنورة', nameEn: 'Madinah'),
      City(id: 'dammam', nameAr: 'الدمام', nameEn: 'Dammam'),
      City(id: 'khobar', nameAr: 'الخبر', nameEn: 'Khobar'),
      City(id: 'dhahran', nameAr: 'الظهران', nameEn: 'Dhahran'),
      City(id: 'taif', nameAr: 'الطائف', nameEn: 'Taif'),
      City(id: 'buraidah', nameAr: 'بريدة', nameEn: 'Buraidah'),
      City(id: 'tabuk', nameAr: 'تبوك', nameEn: 'Tabuk'),
      City(id: 'abha', nameAr: 'أبها', nameEn: 'Abha'),
      City(id: 'jubail', nameAr: 'الجبيل', nameEn: 'Jubail'),
      City(id: 'hail', nameAr: 'حائل', nameEn: 'Hail'),
      City(id: 'najran', nameAr: 'نجران', nameEn: 'Najran'),
    ],
  );

  static const Country uae = Country(
    code: 'AE',
    nameAr: 'الإمارات',
    nameEn: 'United Arab Emirates',
    dialCode: '+971',
    flag: '🇦🇪',
    currency: _aed,
    phoneDigits: 9,
    cities: [
      City(id: 'dubai', nameAr: 'دبي', nameEn: 'Dubai'),
      City(id: 'abudhabi', nameAr: 'أبوظبي', nameEn: 'Abu Dhabi'),
      City(id: 'sharjah', nameAr: 'الشارقة', nameEn: 'Sharjah'),
      City(id: 'ajman', nameAr: 'عجمان', nameEn: 'Ajman'),
      City(id: 'rak', nameAr: 'رأس الخيمة', nameEn: 'Ras Al Khaimah'),
      City(id: 'fujairah', nameAr: 'الفجيرة', nameEn: 'Fujairah'),
      City(id: 'uaq', nameAr: 'أم القيوين', nameEn: 'Umm Al Quwain'),
      City(id: 'alain', nameAr: 'العين', nameEn: 'Al Ain'),
    ],
  );

  static const Country kuwait = Country(
    code: 'KW',
    nameAr: 'الكويت',
    nameEn: 'Kuwait',
    dialCode: '+965',
    flag: '🇰🇼',
    currency: _kwd,
    phoneDigits: 8,
    cities: [
      City(id: 'kuwaitcity', nameAr: 'مدينة الكويت', nameEn: 'Kuwait City'),
      City(id: 'hawalli', nameAr: 'حولي', nameEn: 'Hawalli'),
      City(id: 'salmiya', nameAr: 'السالمية', nameEn: 'Salmiya'),
      City(id: 'farwaniya', nameAr: 'الفروانية', nameEn: 'Farwaniya'),
      City(id: 'ahmadi', nameAr: 'الأحمدي', nameEn: 'Ahmadi'),
      City(id: 'jahra', nameAr: 'الجهراء', nameEn: 'Jahra'),
      City(id: 'mubarak', nameAr: 'مبارك الكبير', nameEn: 'Mubarak Al-Kabeer'),
      City(id: 'fahaheel', nameAr: 'الفحيحيل', nameEn: 'Fahaheel'),
    ],
  );

  static const Country qatar = Country(
    code: 'QA',
    nameAr: 'قطر',
    nameEn: 'Qatar',
    dialCode: '+974',
    flag: '🇶🇦',
    currency: _qar,
    phoneDigits: 8,
    cities: [
      City(id: 'doha', nameAr: 'الدوحة', nameEn: 'Doha'),
      City(id: 'rayyan', nameAr: 'الريان', nameEn: 'Al Rayyan'),
      City(id: 'wakrah', nameAr: 'الوكرة', nameEn: 'Al Wakrah'),
      City(id: 'khor', nameAr: 'الخور', nameEn: 'Al Khor'),
      City(id: 'lusail', nameAr: 'لوسيل', nameEn: 'Lusail'),
    ],
  );

  static const Country bahrain = Country(
    code: 'BH',
    nameAr: 'البحرين',
    nameEn: 'Bahrain',
    dialCode: '+973',
    flag: '🇧🇭',
    currency: _bhd,
    phoneDigits: 8,
    cities: [
      City(id: 'manama', nameAr: 'المنامة', nameEn: 'Manama'),
      City(id: 'muharraq', nameAr: 'المحرق', nameEn: 'Muharraq'),
      City(id: 'riffa', nameAr: 'الرفاع', nameEn: 'Riffa'),
      City(id: 'hamad', nameAr: 'مدينة حمد', nameEn: 'Hamad Town'),
      City(id: 'isa', nameAr: 'مدينة عيسى', nameEn: 'Isa Town'),
    ],
  );

  static const Country oman = Country(
    code: 'OM',
    nameAr: 'عُمان',
    nameEn: 'Oman',
    dialCode: '+968',
    flag: '🇴🇲',
    currency: _omr,
    phoneDigits: 8,
    cities: [
      City(id: 'muscat', nameAr: 'مسقط', nameEn: 'Muscat'),
      City(id: 'salalah', nameAr: 'صلالة', nameEn: 'Salalah'),
      City(id: 'sohar', nameAr: 'صحار', nameEn: 'Sohar'),
      City(id: 'nizwa', nameAr: 'نزوى', nameEn: 'Nizwa'),
      City(id: 'sur', nameAr: 'صور', nameEn: 'Sur'),
    ],
  );
}
