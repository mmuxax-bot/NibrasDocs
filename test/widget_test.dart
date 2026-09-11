import 'package:flutter_test/flutter_test.dart';
import 'package:nibras_docs/main.dart';
void main(){testWidgets('app starts',(tester) async {await tester.pumpWidget(const NibrasDocsApp());expect(find.text('Nibras Docs'),findOneWidget);});}
