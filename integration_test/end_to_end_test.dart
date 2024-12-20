// test/integration_tests/end_to_end_test.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hedieaty/main.dart' as app; // adjust as needed
import 'package:integration_test/integration_test.dart';


void main() {
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

      testWidgets('End-to-end scenario: Login -> Home -> EventList -> GiftList -> Add Gift -> Gift Details',
              (WidgetTester tester) async {
                WidgetsFlutterBinding.ensureInitialized();
                await Firebase.initializeApp();
                app.main();
                await tester.pumpAndSettle();

                // Step 1: Login
                final emailField = find.byKey(const Key('email_field'));
                final passwordField = find.byKey(const Key('password_field'));
                final loginButton = find.byKey(const Key('login_button'));

                expect(emailField, findsOneWidget);
                expect(passwordField, findsOneWidget);
                expect(loginButton, findsOneWidget);

                // Enter credentials
                await tester.enterText(emailField, 'kareemmoataz13@gmail.com');
                await tester.enterText(passwordField, 'Kimo_61912');

                // Tap login
                await tester.tap(loginButton);
                await tester.pumpAndSettle(Duration(seconds: 5));

                // Step 2: Verify Home page
                // Assuming 'Friends List' is the text on the home screen after login
                final homeScreenIndicator = find.text('Friends List');
                expect(homeScreenIndicator, findsOneWidget);

                // Step 3: Open Drawer and go to Event List
                final createEventButton = find.text('Create Your Own Event');
                expect(createEventButton, findsOneWidget);
                await tester.tap(createEventButton);
                await tester.pumpAndSettle(Duration(seconds: 5));


                // Step 4: Verify Event List Page
                final eventListTitle = find.textContaining('Events -');
                expect(eventListTitle, findsOneWidget);

                // Assuming an event named "Test Event" already exists
                final testEventTile = find.text('Birthday<3');
                expect(testEventTile, findsOneWidget);
                await tester.tap(testEventTile);
                await tester.pumpAndSettle();

                // Step 6: Add a New Gift
                final createGiftButton = find.text('Create New Gift');
                expect(createGiftButton, findsOneWidget);

                await tester.tap(createGiftButton);
                await tester.pumpAndSettle();

                // Assuming you've added keys to AddGiftPage fields:
                final giftNameField = find.byKey(const Key('gift_name_field'));
                final giftdescription = find.byKey(const Key('gift_description_field'));
                final giftCategoryField = find.byKey(const Key('gift_category_field'));
                final giftPriceField = find.byKey(const Key('gift_price_field'));
                final saveGiftButton = find.text('Save Gift');

                expect(giftNameField, findsOneWidget);
                expect(giftdescription, findsOneWidget);
                expect(giftCategoryField, findsOneWidget);
                expect(giftPriceField, findsOneWidget);
                // expect(uploadImageButton, findsOneWidget);
                expect(saveGiftButton, findsOneWidget);

                // Fill the gift details
                await tester.enterText(giftNameField, 'New Test Gift');
                await tester.enterText(giftdescription, 'Description');
                await tester.enterText(giftCategoryField, 'Category A');
                await tester.enterText(giftPriceField, '10.00');


                // Upload image step (this might need a mock or you can just omit)
                // await tester.tap(uploadImageButton);
                // await tester.pumpAndSettle();

                // Save the gift
                await tester.tap(saveGiftButton);
                await tester.pumpAndSettle();

                // After saving, back on Gift List page
                // expect(giftListTitle, findsOneWidget);

                // Verify the newly added gift is visible
                final newGiftTile = find.text('New Test Gift');
                expect(newGiftTile, findsAny);
          });
}
