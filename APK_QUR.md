# Nibras Docs — APK necə yığılır

Bu qovluq **native Android Flutter** layihəsidir. Veb tətbiq deyil.
Sənədlər telefonda saxlanır (SharedPreferences). İnternet yalnız istəyə bağlı bulud üçün lazımdır.

## Tələblər
- Flutter SDK 3.24+ (https://docs.flutter.dev/get-started/install/windows və ya linux/macos)
- Android Studio + Android SDK
- Java 17

## Addımlar

1. Zip-i açın, qovluğa girin:
   ```
   cd nibras_docs
   ```

2. Asılılıqları quraşdırın:
   ```
   flutter pub get
   ```

3. Telefonda / emulyatorda yoxlamaq üçün:
   ```
   flutter run
   ```

4. **Release APK** (telefona quraşdırmaq üçün):
   ```
   flutter build apk --release
   ```
   Fayl:
   `build/app/outputs/flutter-apk/app-release.apk`

5. Play Store üçün App Bundle:
   ```
   flutter build appbundle --release
   ```
   Fayl:
   `build/app/outputs/bundle/release/app-release.aab`

## Nə düzəldildi
- Qiymət ekranında **iki dəfə `initState`** (tətbiq ümumiyyətlə yığılmırdı)
- Məxfilik siyasətində **qırılmış mətn sətri** (compile error)
- Parametrlərdə çıxış düyməsi Supabase yoxdursa **çökürdü**
- Şəkil yolu `file://` səhv yazılmışdı (şəkillər görünmürdü)
- `web` və brauzer paketləri silindi — yalnız Android

## Qeyd
İlk yığım debug açarı ilə imzalanır (`key.properties` yoxdursa).
Play Store üçün `android/key.properties.example` faylını `key.properties` kimi kopyalayıb keystore yolunu yazın.
Ətraflı: `STORE_RELEASE.md`
