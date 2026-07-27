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
    return ar ? '$text $symbolAr' : '$text $symbolEn';
  }

  /// تنسيق مختصر بدون كسور — للاستخدام في الكروت الضيقة.
  String formatCompact(num value, {required bool ar}) {
    final rounded = value.round();
    return ar ? '$rounded $symbolAr' : '$rounded $symbolEn';
  }
}

class City {
  const City({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  /// مركز المدينة. بيتزحزح عشوائياً قبل الحفظ — إحنا مش بناخد الموقع
  /// الحقيقي للمستخدم أبداً. القيم دي مطابقة لبذور قاعدة البيانات.
  final double lat;
  final double lng;

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
      City(id: 'cairo', nameAr: 'القاهرة', nameEn: 'Cairo', lat: 30.0444, lng: 31.2357),
      City(id: 'giza', nameAr: 'الجيزة', nameEn: 'Giza', lat: 30.0131, lng: 31.2089),
      City(id: 'alex', nameAr: 'الإسكندرية', nameEn: 'Alexandria', lat: 31.2001, lng: 29.9187),
      City(id: 'mansoura', nameAr: 'المنصورة', nameEn: 'Mansoura', lat: 31.0409, lng: 31.3785),
      City(id: 'tanta', nameAr: 'طنطا', nameEn: 'Tanta', lat: 30.7865, lng: 31.0004),
      City(id: 'zagazig', nameAr: 'الزقازيق', nameEn: 'Zagazig', lat: 30.5877, lng: 31.502),
      City(id: 'ismailia', nameAr: 'الإسماعيلية', nameEn: 'Ismailia', lat: 30.5965, lng: 32.2715),
      City(id: 'portsaid', nameAr: 'بورسعيد', nameEn: 'Port Said', lat: 31.2653, lng: 32.3019),
      City(id: 'suez', nameAr: 'السويس', nameEn: 'Suez', lat: 29.9668, lng: 32.5498),
      City(id: 'asyut', nameAr: 'أسيوط', nameEn: 'Asyut', lat: 27.1783, lng: 31.1859),
      City(id: 'sohag', nameAr: 'سوهاج', nameEn: 'Sohag', lat: 26.5591, lng: 31.6957),
      City(id: 'minya', nameAr: 'المنيا', nameEn: 'Minya', lat: 28.1099, lng: 30.7503),
      City(id: 'fayoum', nameAr: 'الفيوم', nameEn: 'Fayoum', lat: 29.3084, lng: 30.8428),
      City(id: 'luxor', nameAr: 'الأقصر', nameEn: 'Luxor', lat: 25.6872, lng: 32.6396),
      City(id: 'aswan', nameAr: 'أسوان', nameEn: 'Aswan', lat: 24.0889, lng: 32.8998),
      City(id: 'hurghada', nameAr: 'الغردقة', nameEn: 'Hurghada', lat: 27.2579, lng: 33.8116),
      City(id: 'damietta', nameAr: 'دمياط', nameEn: 'Damietta', lat: 31.4175, lng: 31.8144),
      City(id: 'beheira', nameAr: 'البحيرة', nameEn: 'Beheira', lat: 31.0341, lng: 30.4682),
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
      City(id: 'riyadh', nameAr: 'الرياض', nameEn: 'Riyadh', lat: 24.7136, lng: 46.6753),
      City(id: 'jeddah', nameAr: 'جدة', nameEn: 'Jeddah', lat: 21.4858, lng: 39.1925),
      City(id: 'makkah', nameAr: 'مكة المكرمة', nameEn: 'Makkah', lat: 21.3891, lng: 39.8579),
      City(id: 'madinah', nameAr: 'المدينة المنورة', nameEn: 'Madinah', lat: 24.5247, lng: 39.5692),
      City(id: 'dammam', nameAr: 'الدمام', nameEn: 'Dammam', lat: 26.4207, lng: 50.0888),
      City(id: 'khobar', nameAr: 'الخبر', nameEn: 'Khobar', lat: 26.2794, lng: 50.2083),
      City(id: 'dhahran', nameAr: 'الظهران', nameEn: 'Dhahran', lat: 26.2361, lng: 50.0393),
      City(id: 'taif', nameAr: 'الطائف', nameEn: 'Taif', lat: 21.2703, lng: 40.4158),
      City(id: 'buraidah', nameAr: 'بريدة', nameEn: 'Buraidah', lat: 26.326, lng: 43.975),
      City(id: 'tabuk', nameAr: 'تبوك', nameEn: 'Tabuk', lat: 28.3838, lng: 36.555),
      City(id: 'abha', nameAr: 'أبها', nameEn: 'Abha', lat: 18.2465, lng: 42.5117),
      City(id: 'jubail', nameAr: 'الجبيل', nameEn: 'Jubail', lat: 27.0174, lng: 49.6225),
      City(id: 'hail', nameAr: 'حائل', nameEn: 'Hail', lat: 27.5219, lng: 41.6907),
      City(id: 'najran', nameAr: 'نجران', nameEn: 'Najran', lat: 17.4917, lng: 44.1322),
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
      City(id: 'dubai', nameAr: 'دبي', nameEn: 'Dubai', lat: 25.2048, lng: 55.2708),
      City(id: 'abudhabi', nameAr: 'أبوظبي', nameEn: 'Abu Dhabi', lat: 24.4539, lng: 54.3773),
      City(id: 'sharjah', nameAr: 'الشارقة', nameEn: 'Sharjah', lat: 25.3463, lng: 55.4209),
      City(id: 'ajman', nameAr: 'عجمان', nameEn: 'Ajman', lat: 25.4052, lng: 55.5136),
      City(id: 'rak', nameAr: 'رأس الخيمة', nameEn: 'Ras Al Khaimah', lat: 25.7895, lng: 55.9432),
      City(id: 'fujairah', nameAr: 'الفجيرة', nameEn: 'Fujairah', lat: 25.1288, lng: 56.3265),
      City(id: 'uaq', nameAr: 'أم القيوين', nameEn: 'Umm Al Quwain', lat: 25.5647, lng: 55.5552),
      City(id: 'alain', nameAr: 'العين', nameEn: 'Al Ain', lat: 24.1302, lng: 55.8023),
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
      City(id: 'kuwaitcity', nameAr: 'مدينة الكويت', nameEn: 'Kuwait City', lat: 29.3759, lng: 47.9774),
      City(id: 'hawalli', nameAr: 'حولي', nameEn: 'Hawalli', lat: 29.3328, lng: 48.0289),
      City(id: 'salmiya', nameAr: 'السالمية', nameEn: 'Salmiya', lat: 29.3339, lng: 48.0755),
      City(id: 'farwaniya', nameAr: 'الفروانية', nameEn: 'Farwaniya', lat: 29.2775, lng: 47.9586),
      City(id: 'ahmadi', nameAr: 'الأحمدي', nameEn: 'Ahmadi', lat: 29.0769, lng: 48.0838),
      City(id: 'jahra', nameAr: 'الجهراء', nameEn: 'Jahra', lat: 29.3375, lng: 47.6581),
      City(id: 'mubarak', nameAr: 'مبارك الكبير', nameEn: 'Mubarak Al-Kabeer', lat: 29.2, lng: 48.07),
      City(id: 'fahaheel', nameAr: 'الفحيحيل', nameEn: 'Fahaheel', lat: 29.0826, lng: 48.1301),
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
      City(id: 'doha', nameAr: 'الدوحة', nameEn: 'Doha', lat: 25.2854, lng: 51.531),
      City(id: 'rayyan', nameAr: 'الريان', nameEn: 'Al Rayyan', lat: 25.2919, lng: 51.4244),
      City(id: 'wakrah', nameAr: 'الوكرة', nameEn: 'Al Wakrah', lat: 25.1659, lng: 51.6032),
      City(id: 'khor', nameAr: 'الخور', nameEn: 'Al Khor', lat: 25.684, lng: 51.4969),
      City(id: 'lusail', nameAr: 'لوسيل', nameEn: 'Lusail', lat: 25.43, lng: 51.49),
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
      City(id: 'manama', nameAr: 'المنامة', nameEn: 'Manama', lat: 26.2285, lng: 50.586),
      City(id: 'muharraq', nameAr: 'المحرق', nameEn: 'Muharraq', lat: 26.2572, lng: 50.6119),
      City(id: 'riffa', nameAr: 'الرفاع', nameEn: 'Riffa', lat: 26.13, lng: 50.555),
      City(id: 'hamad', nameAr: 'مدينة حمد', nameEn: 'Hamad Town', lat: 26.115, lng: 50.507),
      City(id: 'isa', nameAr: 'مدينة عيسى', nameEn: 'Isa Town', lat: 26.1736, lng: 50.5478),
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
      City(id: 'muscat', nameAr: 'مسقط', nameEn: 'Muscat', lat: 23.588, lng: 58.3829),
      City(id: 'salalah', nameAr: 'صلالة', nameEn: 'Salalah', lat: 17.0151, lng: 54.0924),
      City(id: 'sohar', nameAr: 'صحار', nameEn: 'Sohar', lat: 24.3417, lng: 56.7094),
      City(id: 'nizwa', nameAr: 'نزوى', nameEn: 'Nizwa', lat: 22.9333, lng: 57.5333),
      City(id: 'sur', nameAr: 'صور', nameEn: 'Sur', lat: 22.5667, lng: 59.5289),
    ],
  );
}
