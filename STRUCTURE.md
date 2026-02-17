# Finance Tracker App Structure

## Flutter Project
finance_tracker_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── core/
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── models/
│   │   ├── user.dart
│   │   ├── transaction.dart
│   │   └── loan.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   └── auth_service.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── transaction_provider.dart
│   │   ├── loan_provider.dart
│   │   └── dashboard_provider.dart
│   ├── routes/
│   │   └── app_router.dart
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── add_transaction_screen.dart
│   │   ├── transaction_history_screen.dart
│   │   ├── add_loan_screen.dart
│   │   ├── loan_list_screen.dart
│   │   ├── analytics_screen.dart
│   │   ├── profile_screen.dart
│   │   └── ai_assistant_screen.dart
│   ├── widgets/
│   │   ├── glass_card.dart
│   │   ├── transaction_tile.dart
│   │   ├── loan_tile.dart
│   │   ├── chart_widget.dart
│   │   └── loading_overlay.dart
│   └── utils/
│       ├── constants.dart
│       └── formatters.dart

## Backend Project
backend/
├── app.py
├── config.py
├── requirements.txt
├── .env.example
├── routes/
│   ├── __init__.py
│   ├── auth_routes.py
│   ├── transaction_routes.py
│   ├── loan_routes.py
│   ├── dashboard_routes.py
│   └── ai_routes.py
├── services/
│   ├── __init__.py
│   ├── supabase_service.py
│   └── ai_service.py
└── utils/
    ├── __init__.py
    └── jwt_handler.py

