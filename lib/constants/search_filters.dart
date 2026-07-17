/// Search filter constants for book search API

/// Language options for book search
const searchLanguages = {
  'all': null,
  'chinese': 'chinese',
  'traditional_chinese': 'traditional chinese',
  'english': 'english',
  'russian': 'russian',
  'german': 'german',
  'spanish': 'spanish',
  'dutch': 'dutch',
  'french': 'french',
  'italian': 'italian',
  'portuguese': 'portuguese',
  'brazilian': 'brazilian',
  'polish': 'polish',
  'ukrainian': 'ukrainian',
  'bulgarian': 'bulgarian',
  'greek': 'greek',
  'romanian': 'romanian',
  'moldavian': 'moldavian',
  'turkish': 'turkish',
  'persian': 'persian',
  'arabic': 'arabic',
  'japanese': 'japanese',
  'swedish': 'swedish',
  'hungarian': 'hungarian',
  'serbian': 'serbian',
  'latin': 'latin',
  'croatian': 'croatian',
  'czech': 'czech',
  'kazakh': 'kazakh',
  'belarusian': 'belarusian',
  'indonesian': 'indonesian',
  'malaysian': 'malaysian',
  'lithuanian': 'lithuanian',
  'catalan': 'catalan',
  'finnish': 'finnish',
  'azerbaijani': 'azerbaijani',
  'korean': 'korean',
  'bengali': 'bengali',
  'esperanto': 'esperanto',
  'hindi': 'hindi',
  'urdu': 'urdu',
  'danish': 'danish',
  'uzbek': 'uzbek',
  'slovak': 'slovak',
  'norwegian': 'norwegian',
  'vietnamese': 'vietnamese',
  'thai': 'thai',
  'hebrew': 'hebrew',
};

/// Localized language display names (key: api_value)
Map<String, String> getLanguageDisplayNames(String locale) {
  // Common languages with localized names
  if (locale.startsWith('zh')) {
    return {
      'all': '所有语言',
      'chinese': '简体中文',
      'traditional_chinese': '繁体中文',
      'english': '英语',
      'russian': '俄语',
      'german': '德语',
      'spanish': '西班牙语',
      'french': '法语',
      'italian': '意大利语',
      'portuguese': '葡萄牙语',
      'brazilian': '巴西葡萄牙语',
      'japanese': '日语',
      'korean': '韩语',
      'arabic': '阿拉伯语',
      'turkish': '土耳其语',
      'vietnamese': '越南语',
      'thai': '泰语',
      'indonesian': '印度尼西亚语',
      'polish': '波兰语',
      'ukrainian': '乌克兰语',
      'dutch': '荷兰语',
      'swedish': '瑞典语',
      'danish': '丹麦语',
      'norwegian': '挪威语',
      'finnish': '芬兰语',
      'greek': '希腊语',
      'czech': '捷克语',
      'romanian': '罗马尼亚语',
      'hungarian': '匈牙利语',
      'persian': '波斯语',
      'hindi': '印地语',
      'bengali': '孟加拉语',
      'hebrew': '希伯来语',
      'latin': 'latin',
    };
  }
  // Default: English names
  return {
    'all': 'All Languages',
    'chinese': 'Chinese',
    'traditional_chinese': 'Traditional Chinese',
    'english': 'English',
    'russian': 'Russian',
    'german': 'German',
    'spanish': 'Spanish',
    'french': 'French',
    'italian': 'Italian',
    'portuguese': 'Portuguese',
    'brazilian': 'Brazilian Portuguese',
    'japanese': 'Japanese',
    'korean': 'Korean',
    'arabic': 'Arabic',
    'turkish': 'Turkish',
    'vietnamese': 'Vietnamese',
    'thai': 'Thai',
    'indonesian': 'Indonesian',
    'polish': 'Polish',
    'ukrainian': 'Ukrainian',
    'dutch': 'Dutch',
    'swedish': 'Swedish',
    'danish': 'Danish',
    'norwegian': 'Norwegian',
    'finnish': 'Finnish',
    'greek': 'Greek',
    'czech': 'Czech',
    'romanian': 'Romanian',
    'hungarian': 'Hungarian',
    'persian': 'Persian',
    'hindi': 'Hindi',
    'bengali': 'Bengali',
    'hebrew': 'Hebrew',
    'latin': 'Latin',
  };
}

/// Sort order options
const searchOrders = {
  'default': null,
  'popular': 'popular',
  'bestmatch': 'bestmatch',
  'title': 'title',
  'date': 'date',
  'year': 'year',
};

/// Localized sort order names
Map<String, String> getOrderDisplayNames(String locale) {
  if (locale.startsWith('zh')) {
    return {
      'default': '默认顺序',
      'popular': '热度',
      'bestmatch': '匹配度',
      'title': '书名',
      'date': '上传日期',
      'year': '出版日期',
    };
  }
  return {
    'default': 'Default',
    'popular': 'Popular',
    'bestmatch': 'Best Match',
    'title': 'Title',
    'date': 'Upload Date',
    'year': 'Publish Year',
  };
}

/// File extension options
const searchExtensions = {
  'all': null,
  'pdf': 'pdf',
  'epub': 'epub',
  'mobi': 'mobi',
  'txt': 'txt',
  'azw': 'azw',
  'azw3': 'azw3',
};

/// Localized extension names
Map<String, String> getExtensionDisplayNames(String locale) {
  if (locale.startsWith('zh')) {
    return {
      'all': '所有格式',
      'pdf': 'PDF',
      'epub': 'EPUB',
      'mobi': 'MOBI',
      'txt': 'TXT',
      'azw': 'AZW',
      'azw3': 'AZW3',
    };
  }
  return {
    'all': 'All Formats',
    'pdf': 'PDF',
    'epub': 'EPUB',
    'mobi': 'MOBI',
    'txt': 'TXT',
    'azw': 'AZW',
    'azw3': 'AZW3',
  };
}
