// Flutter
export 'package:flutter/material.dart';

// Firebase
export 'package:firebase_auth/firebase_auth.dart';
export 'package:firebase_core/firebase_core.dart';
export 'package:firebase_database/firebase_database.dart';
export 'package:cloud_firestore/cloud_firestore.dart' hide Query, Transaction, TransactionHandler;
export 'package:firebase_messaging/firebase_messaging.dart';

// Other packages
export 'package:intl/intl.dart' hide TextDirection;

// Main
export 'main.dart';

// Pages
export 'pages/account_page.dart';
export 'pages/code_verification_page.dart';
export 'pages/email_verification_page.dart';
export 'pages/forgot_password_page.dart';
export 'pages/homepage.dart';
export 'pages/login_page.dart';
export 'pages/notifications_page.dart';
export 'pages/register_page.dart';
export 'pages/reset_password_page.dart';
export 'pages/system_monitor_page.dart';
export 'pages/system_selector_page.dart';
export 'pages/system_settings_page.dart';

// Screens
export 'screens/activity_log_screen.dart';
export 'screens/dashboard_screen.dart';
export 'screens/schedule_screen.dart';

// Models
export 'models/user_role.dart';
export 'models/shared_user.dart';

// Services
export 'services/permission_service.dart';

// Widgets
export 'widgets/permission_badge.dart';
export 'widgets/user_list_tile.dart';

// Utils
export 'utils/validators.dart';
