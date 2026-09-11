# Nibras Docs

Premium, dark-blue, offline Flutter document workspace.

## Hazır funksiyalar
- Splash və Nibras brend dizaynı
- Sənəd yaratmaq, redaktə etmək və lokal yadda saxlamaq
- Axtarış, kateqoriyalar, seçilmişlər və pin
- Söz sayı, silmə, TXT export/share
- Dark/light tema
- GitHub Actions ilə release APK build

## GitHub ilə APK
1. ZIP-i açın və faylları yeni GitHub repository-yə yükləyin.
2. Actions bölməsində **Build Nibras Docs APK** workflow-nu başladın.
3. Build bitdikdən sonra Artifacts bölməsindən **Nibras-Docs-APK** faylını endirin.

## Lokal build
```bash
flutter create --platforms=android --org com.nibrascode .
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```

APK yolu: `build/app/outputs/flutter-apk/app-release.apk`

> Qeyd: İlk platform yaratma əmri `lib/main.dart` faylını dəyişərsə, ZIP-dəki versiyanı geri qaytarın. GitHub workflow-da mövcud fayllar qorunur.

## v2 real storage core
- App sənədləri tətbiqin Documents/NibrasDocs/workspace.json faylında atomik yazma ilə saxlanır.
- Dashboard real sənəd, seçilmiş, pin və səbət saylarını göstərir.
- Recycle Bin sənədi bərpa və ya həmişəlik silmə funksiyasına malikdir.
- Backup düyməsi tarixli JSON ehtiyat nüsxəsi yaradır.

## v3 qovluq sistemi
- İstifadəçi tətbiqin içində yeni qovluq yarada bilər.
- Qovluqlar lokal workspace faylında saxlanır.
- Qovluq çipləri ilə sənədlər real vaxtda filtrlənir.
- Yeni sənəd seçilmiş qovluğa əlavə olunur.
- Redaktorda sənədi başqa qovluğa köçürmək mümkündür.

## v4 etiket və qovluq idarəetməsi
- Sənədlərə birdən çox etiket yazmaq mümkündür.
- Axtarış artıq başlıq, məzmun və etiketlərdə işləyir.
- Qovluğa uzun basaraq adını dəyişmək mümkündür.
- Qovluq silindikdə içindəki sənədlər Personal qovluğuna köçürülür.

## v5 PDF və şrift dəstəyi
- A4 çoxsəhifəli PDF ixracı.
- Sans, Serif və Mono şrift seçimi.
- DejaVu Unicode şriftləri layihəyə lokal daxil edilib.
- Azərbaycan, türk, ərəb, fars, ivrit, kiril və geniş Latın simvolları üçün Unicode mətn dəstəyi.
- Ərəb/fars/ivrit mətn aşkarlananda RTL istiqaməti avtomatik tətbiq edilir.
- PDF başlığı, kateqoriya, etiketlər, səhifə nömrəsi və Nibras Docs başlığı ilə hazırlanır.
- PDF tətbiqin NibrasDocs/Exports/PDF qovluğunda saxlanır və paylaşma menyusu açılır.

## v6
PDF A3, A4, A5, A6, Letter, Legal; portret/landşaft. Nibras Docs EPUB önizləmə: Phone, Tablet, Kindle; Light, Sepia, Dark, AMOLED; mətn ölçüsü.
