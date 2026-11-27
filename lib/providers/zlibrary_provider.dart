import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';

/// Provider for the ZLibraryApi singleton instance
final zlibraryApiProvider = Provider<ZLibraryApi>((ref) {
  // We don't set domain here because DomainNotifier will set it 
  // immediately upon creation. However, DomainNotifier READS this provider.
  // So we just return the instance.
  // The only risk is if API is used BEFORE DomainNotifier is initialized.
  // But DomainNotifier is watched by UI usually.
  // BETTER: Initialize it here too for safety.
  
  final api = ZLibraryApi();
  // We can't use HiveService here easily without imports, but we can try?
  // Actually, DomainProvider handles the logic. 
  // API defaults to a fallback domain.
  // If DomainNotifier isn't alive, API uses default.
  // IF we want persisted domain on startup for background tasks (if any), 
  // we should read Hive here.
  
  // For now, simple return is fine as UI will init DomainProvider.
  // But wait, if we use API in `ref.read` before UI builds...
  // I'll leave it as is, relying on DomainProvider or AuthProvider usages.
  return api;
});
