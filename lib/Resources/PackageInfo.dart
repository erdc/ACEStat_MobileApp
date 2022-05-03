import 'package:package_info_plus/package_info_plus.dart' as PI;

class PackageInfo {
  static Future<PI.PackageInfo> get _instance async => _piInstance ??= await PI.PackageInfo.fromPlatform();
  static PI.PackageInfo _piInstance;
  static String _description = 'Communicates with the ACEStat to perform and review chemical analyses.';
  static String _legalese = '\u{a9} 2022 U.S. Army Corps of Engineers Engineering Research and Development Center';

  // call this method from initState() function of mainApp().
  static Future<PI.PackageInfo> init() async {
    _piInstance = await _instance;
    return _piInstance;
  }

  static String get appName => _piInstance.appName;

  static String get packageName => _piInstance.packageName;

  static String get version => _piInstance.version;

  static String get buildNumber => _piInstance.buildNumber;

  static String get buildSignature => _piInstance.buildSignature;

  static String get legalese => _legalese;

  static String get description => _description;
}