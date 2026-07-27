import 'package:flutter/material.dart';

/// شجرة الأقسام الكاملة — السوق المفتوح.
///
/// القاعدة: كل قسم لازم يكون قابل للمقايضة فعلياً. الأقسام اللي فيها
/// قيود قانونية (حيوانات، مواد بناء) معلّمة بـ [restricted] عشان الشاشة
/// تعرض تنبيه قبل النشر.
@immutable
class Category {
  const Category({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    this.subs = const [],
    this.restricted = false,
    this.isService = false,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final IconData icon;
  final List<SubCategory> subs;

  /// قسم عليه قيود قانونية — بيظهر تنبيه قبل النشر.
  final bool restricted;

  /// قسم خدمات مش منتجات — مفيهوش شحن ولا حالة منتج.
  final bool isService;

  String name(bool ar) => ar ? nameAr : nameEn;
}

@immutable
class SubCategory {
  const SubCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  String name(bool ar) => ar ? nameAr : nameEn;
}

class Categories {
  const Categories._();

  static Category byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all.last);

  /// الأقسام اللي بتظهر في الصف الأول على شاشة السوق.
  static List<Category> get featured => [
        mobiles,
        electronics,
        vehicles,
        gaming,
        furniture,
        fashion,
        services,
        watches,
      ];

  static const List<Category> all = [
    mobiles,
    computers,
    electronics,
    cameras,
    gaming,
    vehicles,
    furniture,
    appliances,
    fashion,
    watches,
    kids,
    sports,
    hobbies,
    books,
    tools,
    business,
    construction,
    agriculture,
    pets,
    services,
    misc,
  ];

  // ---------------------------------------------------------------- التقنية
  static const mobiles = Category(
    id: 'mobiles',
    nameAr: 'موبايلات وتابلت',
    nameEn: 'Mobiles & Tablets',
    icon: Icons.smartphone_rounded,
    subs: [
      SubCategory(id: 'phones', nameAr: 'موبايلات', nameEn: 'Mobile phones'),
      SubCategory(id: 'tablets', nameAr: 'تابلت', nameEn: 'Tablets'),
      SubCategory(id: 'smartwatch', nameAr: 'ساعات ذكية', nameEn: 'Smart watches'),
      SubCategory(id: 'phoneacc', nameAr: 'إكسسوارات موبايل', nameEn: 'Phone accessories'),
      SubCategory(id: 'numbers', nameAr: 'أرقام مميزة', nameEn: 'Premium numbers'),
    ],
  );

  static const computers = Category(
    id: 'computers',
    nameAr: 'كمبيوتر ولابتوب',
    nameEn: 'Computers & Laptops',
    icon: Icons.laptop_mac_rounded,
    subs: [
      SubCategory(id: 'laptops', nameAr: 'لابتوب', nameEn: 'Laptops'),
      SubCategory(id: 'desktops', nameAr: 'كمبيوتر مكتبي', nameEn: 'Desktops'),
      SubCategory(id: 'parts', nameAr: 'قطع ومكونات', nameEn: 'Components'),
      SubCategory(id: 'monitors', nameAr: 'شاشات', nameEn: 'Monitors'),
      SubCategory(id: 'printers', nameAr: 'طابعات', nameEn: 'Printers'),
      SubCategory(id: 'network', nameAr: 'شبكات وراوتر', nameEn: 'Networking'),
    ],
  );

  static const electronics = Category(
    id: 'electronics',
    nameAr: 'إلكترونيات وأجهزة',
    nameEn: 'Electronics',
    icon: Icons.tv_rounded,
    subs: [
      SubCategory(id: 'tv', nameAr: 'تلفزيونات', nameEn: 'TVs'),
      SubCategory(id: 'audio', nameAr: 'صوتيات وسماعات', nameEn: 'Audio & headphones'),
      SubCategory(id: 'projectors', nameAr: 'بروجيكتور', nameEn: 'Projectors'),
      SubCategory(id: 'drones', nameAr: 'درون', nameEn: 'Drones'),
      SubCategory(id: 'security', nameAr: 'كاميرات مراقبة', nameEn: 'Security cameras'),
      SubCategory(id: 'wearables', nameAr: 'أجهزة قابلة للارتداء', nameEn: 'Wearables'),
    ],
  );

  static const cameras = Category(
    id: 'cameras',
    nameAr: 'كاميرات وتصوير',
    nameEn: 'Cameras & Photography',
    icon: Icons.photo_camera_rounded,
    subs: [
      SubCategory(id: 'dslr', nameAr: 'كاميرات احترافية', nameEn: 'DSLR & mirrorless'),
      SubCategory(id: 'lenses', nameAr: 'عدسات', nameEn: 'Lenses'),
      SubCategory(id: 'action', nameAr: 'كاميرات أكشن', nameEn: 'Action cameras'),
      SubCategory(id: 'lighting', nameAr: 'إضاءة واستوديو', nameEn: 'Lighting & studio'),
      SubCategory(id: 'tripods', nameAr: 'حوامل ومثبتات', nameEn: 'Tripods & gimbals'),
    ],
  );

  static const gaming = Category(
    id: 'gaming',
    nameAr: 'ألعاب وأجهزة ألعاب',
    nameEn: 'Gaming',
    icon: Icons.sports_esports_rounded,
    subs: [
      SubCategory(id: 'consoles', nameAr: 'أجهزة ألعاب', nameEn: 'Consoles'),
      SubCategory(id: 'games', nameAr: 'أشرطة وألعاب', nameEn: 'Games'),
      SubCategory(id: 'gamingacc', nameAr: 'إكسسوارات ألعاب', nameEn: 'Gaming accessories'),
      SubCategory(id: 'vr', nameAr: 'نظارات واقع افتراضي', nameEn: 'VR headsets'),
      SubCategory(id: 'gamingpc', nameAr: 'أجهزة ألعاب كمبيوتر', nameEn: 'Gaming PCs'),
    ],
  );

  // ---------------------------------------------------------------- كبيرة
  static const vehicles = Category(
    id: 'vehicles',
    nameAr: 'سيارات ومركبات',
    nameEn: 'Vehicles',
    icon: Icons.directions_car_rounded,
    subs: [
      SubCategory(id: 'cars', nameAr: 'سيارات', nameEn: 'Cars'),
      SubCategory(id: 'motorcycles', nameAr: 'موتوسيكلات', nameEn: 'Motorcycles'),
      SubCategory(id: 'scooters', nameAr: 'سكوتر كهربائي', nameEn: 'E-scooters'),
      SubCategory(id: 'bicycles', nameAr: 'دراجات', nameEn: 'Bicycles'),
      SubCategory(id: 'spare', nameAr: 'قطع غيار', nameEn: 'Spare parts'),
      SubCategory(id: 'tires', nameAr: 'إطارات وجنوط', nameEn: 'Tyres & rims'),
      SubCategory(id: 'boats', nameAr: 'قوارب وجت سكي', nameEn: 'Boats & jet skis'),
      SubCategory(id: 'trucks', nameAr: 'شاحنات ومعدات ثقيلة', nameEn: 'Trucks & heavy equipment'),
    ],
  );

  // العقارات مستبعدة عمداً من التطبيق.
  //
  // مقايضة العقارات ممارسة حقيقية في المنطقة، لكنها بتحتاج توثيق ملكية
  // ووسيط قانوني وعقود مسجلة — وده خارج نطاق Giraffe تماماً، وكان
  // هيحمّلنا مسؤولية قانونية في سبع دول بقوانين مختلفة.

  // ---------------------------------------------------------------- المنزل
  static const furniture = Category(
    id: 'furniture',
    nameAr: 'أثاث ومفروشات',
    nameEn: 'Furniture & Home',
    icon: Icons.chair_rounded,
    subs: [
      SubCategory(id: 'living', nameAr: 'أنتريهات وصالونات', nameEn: 'Living room'),
      SubCategory(id: 'bedroom', nameAr: 'غرف نوم', nameEn: 'Bedroom'),
      SubCategory(id: 'dining', nameAr: 'سفرة', nameEn: 'Dining'),
      SubCategory(id: 'office', nameAr: 'أثاث مكتبي', nameEn: 'Office furniture'),
      SubCategory(id: 'decor', nameAr: 'ديكور وتحف', nameEn: 'Decor'),
      SubCategory(id: 'carpets', nameAr: 'سجاد وستائر', nameEn: 'Carpets & curtains'),
      SubCategory(id: 'outdoor', nameAr: 'أثاث خارجي', nameEn: 'Outdoor furniture'),
    ],
  );

  static const appliances = Category(
    id: 'appliances',
    nameAr: 'أجهزة منزلية',
    nameEn: 'Home Appliances',
    icon: Icons.kitchen_rounded,
    subs: [
      SubCategory(id: 'fridges', nameAr: 'ثلاجات وديب فريزر', nameEn: 'Fridges & freezers'),
      SubCategory(id: 'washers', nameAr: 'غسالات', nameEn: 'Washing machines'),
      SubCategory(id: 'ac', nameAr: 'تكييفات ومراوح', nameEn: 'AC & fans'),
      SubCategory(id: 'cooking', nameAr: 'أفران وبوتاجازات', nameEn: 'Ovens & cookers'),
      SubCategory(id: 'small', nameAr: 'أجهزة صغيرة', nameEn: 'Small appliances'),
      SubCategory(id: 'water', nameAr: 'سخانات وفلاتر مياه', nameEn: 'Heaters & water filters'),
    ],
  );

  // ---------------------------------------------------------------- شخصية
  static const fashion = Category(
    id: 'fashion',
    nameAr: 'أزياء وموضة',
    nameEn: 'Fashion',
    icon: Icons.checkroom_rounded,
    subs: [
      SubCategory(id: 'menswear', nameAr: 'ملابس رجالي', nameEn: "Men's clothing"),
      SubCategory(id: 'womenswear', nameAr: 'ملابس حريمي', nameEn: "Women's clothing"),
      SubCategory(id: 'shoes', nameAr: 'أحذية', nameEn: 'Shoes'),
      SubCategory(id: 'bags', nameAr: 'شنط', nameEn: 'Bags'),
      SubCategory(id: 'perfumes', nameAr: 'عطور', nameEn: 'Perfumes'),
      SubCategory(id: 'accessories', nameAr: 'إكسسوارات', nameEn: 'Accessories'),
      SubCategory(id: 'abaya', nameAr: 'عبايات وملابس تقليدية', nameEn: 'Abayas & traditional'),
    ],
  );

  static const watches = Category(
    id: 'watches',
    nameAr: 'ساعات ومجوهرات',
    nameEn: 'Watches & Jewellery',
    icon: Icons.watch_rounded,
    subs: [
      SubCategory(id: 'luxwatches', nameAr: 'ساعات فاخرة', nameEn: 'Luxury watches'),
      SubCategory(id: 'watches2', nameAr: 'ساعات', nameEn: 'Watches'),
      SubCategory(id: 'gold', nameAr: 'ذهب', nameEn: 'Gold'),
      SubCategory(id: 'silver', nameAr: 'فضة', nameEn: 'Silver'),
      SubCategory(id: 'gems', nameAr: 'أحجار كريمة', nameEn: 'Gemstones'),
    ],
  );

  static const kids = Category(
    id: 'kids',
    nameAr: 'مستلزمات أطفال',
    nameEn: 'Kids & Babies',
    icon: Icons.child_friendly_rounded,
    subs: [
      SubCategory(id: 'strollers', nameAr: 'عربيات أطفال', nameEn: 'Strollers'),
      SubCategory(id: 'carseats', nameAr: 'كراسي سيارة', nameEn: 'Car seats'),
      SubCategory(id: 'toys', nameAr: 'ألعاب أطفال', nameEn: 'Toys'),
      SubCategory(id: 'kidsclothes', nameAr: 'ملابس أطفال', nameEn: 'Kids clothing'),
      SubCategory(id: 'kidsfurniture', nameAr: 'أثاث أطفال', nameEn: 'Kids furniture'),
    ],
  );

  static const sports = Category(
    id: 'sports',
    nameAr: 'رياضة ولياقة',
    nameEn: 'Sports & Fitness',
    icon: Icons.fitness_center_rounded,
    subs: [
      SubCategory(id: 'gym', nameAr: 'أجهزة جيم', nameEn: 'Gym equipment'),
      SubCategory(id: 'weights', nameAr: 'أوزان', nameEn: 'Weights'),
      SubCategory(id: 'football', nameAr: 'كرة قدم', nameEn: 'Football'),
      SubCategory(id: 'camping', nameAr: 'تخييم ورحلات', nameEn: 'Camping & outdoors'),
      SubCategory(id: 'fishing', nameAr: 'صيد', nameEn: 'Fishing'),
      SubCategory(id: 'water', nameAr: 'رياضات مائية', nameEn: 'Water sports'),
    ],
  );

  static const hobbies = Category(
    id: 'hobbies',
    nameAr: 'هوايات وموسيقى',
    nameEn: 'Hobbies & Music',
    icon: Icons.piano_rounded,
    subs: [
      SubCategory(id: 'instruments', nameAr: 'آلات موسيقية', nameEn: 'Musical instruments'),
      SubCategory(id: 'collectibles', nameAr: 'مقتنيات وتحف', nameEn: 'Collectibles'),
      SubCategory(id: 'coins', nameAr: 'عملات وطوابع', nameEn: 'Coins & stamps'),
      SubCategory(id: 'art', nameAr: 'لوحات وفنون', nameEn: 'Art'),
      SubCategory(id: 'models', nameAr: 'مجسمات ومكعبات', nameEn: 'Models & figures'),
    ],
  );

  static const books = Category(
    id: 'books',
    nameAr: 'كتب ومستلزمات دراسية',
    nameEn: 'Books & Study',
    icon: Icons.menu_book_rounded,
    subs: [
      SubCategory(id: 'books2', nameAr: 'كتب', nameEn: 'Books'),
      SubCategory(id: 'textbooks', nameAr: 'كتب دراسية', nameEn: 'Textbooks'),
      SubCategory(id: 'stationery', nameAr: 'أدوات مكتبية', nameEn: 'Stationery'),
      SubCategory(id: 'ereaders', nameAr: 'أجهزة قراءة', nameEn: 'E-readers'),
    ],
  );

  // ---------------------------------------------------------------- مهنية
  static const tools = Category(
    id: 'tools',
    nameAr: 'عدد وأدوات',
    nameEn: 'Tools & Equipment',
    icon: Icons.handyman_rounded,
    subs: [
      SubCategory(id: 'power', nameAr: 'عدد كهربائية', nameEn: 'Power tools'),
      SubCategory(id: 'hand', nameAr: 'عدد يدوية', nameEn: 'Hand tools'),
      SubCategory(id: 'generators', nameAr: 'مولدات', nameEn: 'Generators'),
      SubCategory(id: 'welding', nameAr: 'لحام', nameEn: 'Welding'),
      SubCategory(id: 'measuring', nameAr: 'أجهزة قياس', nameEn: 'Measuring tools'),
    ],
  );

  static const business = Category(
    id: 'business',
    nameAr: 'معدات محلات ومطاعم',
    nameEn: 'Business Equipment',
    icon: Icons.storefront_rounded,
    subs: [
      SubCategory(id: 'restaurant', nameAr: 'معدات مطاعم', nameEn: 'Restaurant equipment'),
      SubCategory(id: 'displays', nameAr: 'فاترينات ورفوف', nameEn: 'Displays & shelving'),
      SubCategory(id: 'pos', nameAr: 'أنظمة كاشير', nameEn: 'POS systems'),
      SubCategory(id: 'salon', nameAr: 'معدات صالونات', nameEn: 'Salon equipment'),
      SubCategory(id: 'medical', nameAr: 'أجهزة عيادات', nameEn: 'Clinic equipment'),
    ],
  );

  static const construction = Category(
    id: 'construction',
    nameAr: 'مواد بناء وديكور',
    nameEn: 'Construction & Decor',
    icon: Icons.foundation_rounded,
    restricted: true,
    subs: [
      SubCategory(id: 'tiles', nameAr: 'سيراميك ورخام', nameEn: 'Tiles & marble'),
      SubCategory(id: 'doors', nameAr: 'أبواب وشبابيك', nameEn: 'Doors & windows'),
      SubCategory(id: 'paint', nameAr: 'دهانات', nameEn: 'Paint'),
      SubCategory(id: 'sanitary', nameAr: 'أدوات صحية', nameEn: 'Sanitary ware'),
      SubCategory(id: 'lighting2', nameAr: 'إضاءة', nameEn: 'Lighting'),
    ],
  );

  static const agriculture = Category(
    id: 'agriculture',
    nameAr: 'زراعة ونباتات',
    nameEn: 'Agriculture & Plants',
    icon: Icons.local_florist_rounded,
    subs: [
      SubCategory(id: 'plants', nameAr: 'نباتات', nameEn: 'Plants'),
      SubCategory(id: 'seeds', nameAr: 'بذور وشتلات', nameEn: 'Seeds & seedlings'),
      SubCategory(id: 'farmtools', nameAr: 'أدوات زراعية', nameEn: 'Farm tools'),
      SubCategory(id: 'irrigation', nameAr: 'أنظمة ري', nameEn: 'Irrigation'),
    ],
  );

  static const pets = Category(
    id: 'pets',
    nameAr: 'حيوانات ومستلزماتها',
    nameEn: 'Pets & Supplies',
    icon: Icons.pets_rounded,
    restricted: true,
    subs: [
      SubCategory(id: 'petsupplies', nameAr: 'مستلزمات حيوانات', nameEn: 'Pet supplies'),
      SubCategory(id: 'aquarium', nameAr: 'أحواض أسماك', nameEn: 'Aquariums'),
      SubCategory(id: 'cages', nameAr: 'أقفاص وبيوت', nameEn: 'Cages & houses'),
      SubCategory(id: 'birds', nameAr: 'طيور زينة', nameEn: 'Ornamental birds'),
    ],
  );

  /// ⭐ قسم مضاف للـ spec الأصلي.
  ///
  /// مفيهوش شحن ولا مخاطر منتج، ونسبة إتمامه أعلى من أي قسم تاني.
  static const services = Category(
    id: 'services',
    nameAr: 'خدمات مقابل خدمات',
    nameEn: 'Skill for Skill',
    icon: Icons.swap_horiz_rounded,
    isService: true,
    subs: [
      SubCategory(id: 'design', nameAr: 'تصميم وجرافيك', nameEn: 'Design & graphics'),
      SubCategory(id: 'dev', nameAr: 'برمجة ومواقع', nameEn: 'Development & web'),
      SubCategory(id: 'photo', nameAr: 'تصوير ومونتاج', nameEn: 'Photo & video'),
      SubCategory(id: 'teaching', nameAr: 'دروس وتدريس', nameEn: 'Tutoring'),
      SubCategory(id: 'translation', nameAr: 'ترجمة وكتابة', nameEn: 'Translation & writing'),
      SubCategory(id: 'repair', nameAr: 'صيانة وإصلاح', nameEn: 'Repair & maintenance'),
      SubCategory(id: 'marketing', nameAr: 'تسويق وسوشيال', nameEn: 'Marketing & social'),
      SubCategory(id: 'fitness', nameAr: 'تدريب رياضي', nameEn: 'Fitness training'),
      SubCategory(id: 'events', nameAr: 'تنظيم مناسبات', nameEn: 'Events'),
    ],
  );

  static const misc = Category(
    id: 'misc',
    nameAr: 'متنوع',
    nameEn: 'Everything Else',
    icon: Icons.category_rounded,
    subs: [
      SubCategory(id: 'other', nameAr: 'أخرى', nameEn: 'Other'),
    ],
  );
}
