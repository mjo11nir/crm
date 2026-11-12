import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('es'), Locale('pt'), Locale('ru'), Locale('tr')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Beauty CRM'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tabSchedule;

  /// No description provided for @tabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// No description provided for @tabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// No description provided for @createAppointment.
  ///
  /// In en, this message translates to:
  /// **'Create appointment'**
  String get createAppointment;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @totalInBase.
  ///
  /// In en, this message translates to:
  /// **'Total in database'**
  String get totalInBase;

  /// No description provided for @finance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get finance;

  /// No description provided for @dayRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue for the day'**
  String get dayRevenue;

  /// No description provided for @freeSlots.
  ///
  /// In en, this message translates to:
  /// **'Free slots'**
  String get freeSlots;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @createOrBreak.
  ///
  /// In en, this message translates to:
  /// **'create appointment or break'**
  String get createOrBreak;

  /// No description provided for @noAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments'**
  String get noAppointments;

  /// No description provided for @dayOff.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get dayOff;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @findAndBook.
  ///
  /// In en, this message translates to:
  /// **'Find and book'**
  String get findAndBook;

  /// No description provided for @freeSlotsHint.
  ///
  /// In en, this message translates to:
  /// **'Specify when you have free time for appointments. Choose the period you need. Intervals take online booking rules into account and do not depend on service duration.'**
  String get freeSlotsHint;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @viewImage.
  ///
  /// In en, this message translates to:
  /// **'Image (social)'**
  String get viewImage;

  /// No description provided for @viewText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get viewText;

  /// No description provided for @colorTheme.
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get colorTheme;

  /// No description provided for @freeSlotsByDay.
  ///
  /// In en, this message translates to:
  /// **'FREE SLOTS BY DAY'**
  String get freeSlotsByDay;

  /// No description provided for @freeTimeForBooking.
  ///
  /// In en, this message translates to:
  /// **'Free time for booking:'**
  String get freeTimeForBooking;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book now!'**
  String get bookNow;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @scheduleAndPlace.
  ///
  /// In en, this message translates to:
  /// **'Schedule and workplace'**
  String get scheduleAndPlace;

  /// No description provided for @onlineBooking.
  ///
  /// In en, this message translates to:
  /// **'Online booking'**
  String get onlineBooking;

  /// No description provided for @waitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get waitlist;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @servicesAndProducts.
  ///
  /// In en, this message translates to:
  /// **'Services and products'**
  String get servicesAndProducts;

  /// No description provided for @webPage.
  ///
  /// In en, this message translates to:
  /// **'Web page'**
  String get webPage;

  /// No description provided for @clientNotifications.
  ///
  /// In en, this message translates to:
  /// **'Client notifications'**
  String get clientNotifications;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @calendarSync.
  ///
  /// In en, this message translates to:
  /// **'Calendar sync'**
  String get calendarSync;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @languageRegion.
  ///
  /// In en, this message translates to:
  /// **'Language and region'**
  String get languageRegion;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutAll.
  ///
  /// In en, this message translates to:
  /// **'Log out on all devices'**
  String get logoutAll;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'All your business data will be permanently deleted. Enter your password to confirm.'**
  String get deleteAccountWarning;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'No account? Create one'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get haveAccount;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @noClient.
  ///
  /// In en, this message translates to:
  /// **'Without client'**
  String get noClient;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @selectServices.
  ///
  /// In en, this message translates to:
  /// **'Select services'**
  String get selectServices;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @discountPercent.
  ///
  /// In en, this message translates to:
  /// **'Discount, %'**
  String get discountPercent;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @noFreeTime.
  ///
  /// In en, this message translates to:
  /// **'No free time on this day'**
  String get noFreeTime;

  /// No description provided for @statusBOOKED.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get statusBOOKED;

  /// No description provided for @statusCONFIRMED.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusCONFIRMED;

  /// No description provided for @statusCOMPLETED.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCOMPLETED;

  /// No description provided for @statusCANCELLED.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCANCELLED;

  /// No description provided for @statusNO_SHOW.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get statusNO_SHOW;

  /// No description provided for @markCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get markCompleted;

  /// No description provided for @markNoShow.
  ///
  /// In en, this message translates to:
  /// **'Client didn\'t come'**
  String get markNoShow;

  /// No description provided for @cancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment'**
  String get cancelAppointment;

  /// No description provided for @confirmAppointment.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAppointment;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPayment;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @refund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get refund;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance due'**
  String get balance;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @newClient.
  ///
  /// In en, this message translates to:
  /// **'New client'**
  String get newClient;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visits;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get totalSpent;

  /// No description provided for @lastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get lastVisit;

  /// No description provided for @nextAppointment.
  ///
  /// In en, this message translates to:
  /// **'Next appointment'**
  String get nextAppointment;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @newService.
  ///
  /// In en, this message translates to:
  /// **'New service'**
  String get newService;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @bufferMinutes.
  ///
  /// In en, this message translates to:
  /// **'Buffer after, min'**
  String get bufferMinutes;

  /// No description provided for @onlineBookable.
  ///
  /// In en, this message translates to:
  /// **'Available for online booking'**
  String get onlineBookable;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @offlineData.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing saved data'**
  String get offlineData;

  /// No description provided for @chatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatsEmpty;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get typeMessage;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newChat;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @internalChat.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get internalChat;

  /// No description provided for @externalChannelsBlocked.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp and Instagram inboxes require an approved Meta Business integration and are not connected.'**
  String get externalChannelsBlocked;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get workingHours;

  /// No description provided for @locations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locations;

  /// No description provided for @addLocation.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addLocation;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @weekdayOff.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get weekdayOff;

  /// No description provided for @bookingLink.
  ///
  /// In en, this message translates to:
  /// **'Booking link'**
  String get bookingLink;

  /// No description provided for @minNotice.
  ///
  /// In en, this message translates to:
  /// **'Minimum notice, min'**
  String get minNotice;

  /// No description provided for @maxHorizon.
  ///
  /// In en, this message translates to:
  /// **'Booking horizon, days'**
  String get maxHorizon;

  /// No description provided for @slotStep.
  ///
  /// In en, this message translates to:
  /// **'Slot step, min'**
  String get slotStep;

  /// No description provided for @requireApproval.
  ///
  /// In en, this message translates to:
  /// **'Confirm bookings manually'**
  String get requireApproval;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get systemLanguage;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected — requires provider credentials'**
  String get notConnected;

  /// No description provided for @sandboxDelivery.
  ///
  /// In en, this message translates to:
  /// **'Messages are queued and delivered via the sandbox adapter (no real messages are sent).'**
  String get sandboxDelivery;

  /// No description provided for @storeBillingBlocked.
  ///
  /// In en, this message translates to:
  /// **'In-app purchases require App Store / Google Play configuration.'**
  String get storeBillingBlocked;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @nothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHere;

  /// No description provided for @slotTaken.
  ///
  /// In en, this message translates to:
  /// **'This time is already taken'**
  String get slotTaken;

  /// No description provided for @versionConflict.
  ///
  /// In en, this message translates to:
  /// **'The appointment was changed on another device. Reload and try again.'**
  String get versionConflict;

  /// No description provided for @subscriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Your plan does not include this feature'**
  String get subscriptionRequired;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @earned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get earned;

  /// No description provided for @planned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get planned;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit (estimate)'**
  String get profit;

  /// No description provided for @noShowRate.
  ///
  /// In en, this message translates to:
  /// **'No-show rate'**
  String get noShowRate;

  /// No description provided for @averageTicket.
  ///
  /// In en, this message translates to:
  /// **'Average ticket'**
  String get averageTicket;

  /// No description provided for @appointmentsCount.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointmentsCount;

  /// No description provided for @topServices.
  ///
  /// In en, this message translates to:
  /// **'Top services'**
  String get topServices;

  /// No description provided for @revenueValue.
  ///
  /// In en, this message translates to:
  /// **'Revenue: {amount}'**
  String revenueValue(String amount);

  /// No description provided for @todayWithDate.
  ///
  /// In en, this message translates to:
  /// **'Today {date}'**
  String todayWithDate(String date);

  /// No description provided for @freeMinutes.
  ///
  /// In en, this message translates to:
  /// **'free: {minutes} min'**
  String freeMinutes(int minutes);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @trialDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'Trial: {days} days left'**
  String trialDaysLeft(int days);

  /// No description provided for @newInMonth.
  ///
  /// In en, this message translates to:
  /// **'{month, select, 1{in January} 2{in February} 3{in March} 4{in April} 5{in May} 6{in June} 7{in July} 8{in August} 9{in September} 10{in October} 11{in November} 12{in December} other{this month}}'**
  String newInMonth(String month);

  /// No description provided for @clientsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} clients'**
  String clientsCount(int count);

  /// No description provided for @conflictsSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} dates skipped: time taken'**
  String conflictsSkipped(int count);

  /// No description provided for @breakLabel.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get breakLabel;

  /// No description provided for @expiresAt.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get expiresAt;

  /// No description provided for @birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma separated)'**
  String get tags;

  /// No description provided for @marketingConsent.
  ///
  /// In en, this message translates to:
  /// **'Agrees to receive promotions'**
  String get marketingConsent;

  /// No description provided for @outsideWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Allow outside working hours'**
  String get outsideWorkingHours;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @everyNWeeks.
  ///
  /// In en, this message translates to:
  /// **'every {weeks} wk'**
  String everyNWeeks(int weeks);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'pt', 'ru', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
