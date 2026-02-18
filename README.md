# Finance Tracker App

A comprehensive personal finance management mobile application built with Flutter. Track your income, expenses, loans, and get AI-powered financial insights.

## 📱 Features

### Core Features
- **Transaction Management**
  - Add income and expenses with categories
  - View transaction history with filtering
  - Track spending by category

- **Dashboard**
  - Total balance overview (income vs expenses)
  - Monthly overview with bar charts
  - Recent transactions display
  - Quick action buttons for adding transactions

- **Loan Tracking**
  - Track loans given to others
  - Track loans borrowed from others
  - View all active loans with status

- **Analytics**
  - Income vs Expenses line chart
  - Expense breakdown by category (pie chart)
  - Savings rate calculation
  - Monthly trend analysis

- **AI Financial Assistant**
  - AI-powered financial advice
  - Personalized insights based on spending patterns
  - Tips for better financial health

- **User Authentication**
  - Secure login/signup
  - JWT token-based authentication
  - Profile management

### Technical Features
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Charts**: fl_chart for data visualization
- **HTTP Client**: http package for API calls
- **Local Storage**: SharedPreferences

---

## 🏗️ Architecture

### Project Structure
```
finance-tracker-app/
├── lib/
│   ├── core/
│   │   └── theme/           # App theming (dark theme)
│   ├── models/              # Data models
│   ├── providers/           # Riverpod state providers
│   ├── routes/              # App routing
│   ├── screens/             # UI screens
│   ├── services/            # API services
│   ├── utils/               # Utilities & formatters
│   ├── widgets/             # Reusable widgets
│   └── main.dart            # App entry point
├── android/                 # Android configuration
├── test/                    # Widget tests
└── pubspec.yaml             # Dependencies
```

### Backend
The app uses a Python Flask backend with:
- Supabase for database
- JWT authentication
- AI service integration

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Python 3.x
- Supabase account

### Installation

1. **Clone the repository**
   ```bash
   cd finance-tracker-app-draft01
   ```

2. **Install Flutter dependencies**
   ```bash
   cd finance_tracker_app
   flutter pub get
   ```

3. **Set up the backend**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

4. **Configure environment variables**
   - Create a `.env` file in the backend directory
   - Add your Supabase credentials

5. **Run the app**
   ```bash
   # Run Flutter app
   flutter run
   
   # Or run backend
   python app.py
   ```

---

## 📋 API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/signup` | Register new user |
| POST | `/api/auth/login` | User login |
| GET | `/api/auth/profile` | Get user profile |
| PUT | `/api/auth/profile` | Update user profile |

### Transactions
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/transactions` | Get all transactions |
| POST | `/api/transactions` | Create transaction |
| PUT | `/api/transactions/:id` | Update transaction |
| DELETE | `/api/transactions/:id` | Delete transaction |

### Dashboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard/summary` | Get dashboard summary |

### Loans
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/loans` | Get all loans |
| POST | `/api/loans` | Create loan |
| PUT | `/api/loans/:id` | Update loan |
| DELETE | `/api/loans/:id` | Delete loan |

### AI
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/ai/advice` | Get AI financial advice |

---

## 🎨 UI Screens

| Screen | Description |
|--------|-------------|
| Splash Screen | App loading with logo |
| Login Screen | User authentication |
| Signup Screen | New user registration |
| Dashboard | Main overview with balance, charts, quick actions |
| Add Transaction | Form to add income/expense |
| Transaction History | List of all transactions |
| Add Loan | Form to add loan (given/borrowed) |
| Loan List | View all loans |
| Analytics | Charts and financial insights |
| Profile | User settings and logout |
| AI Assistant | AI-powered financial advice |

---

## 📦 Dependencies

### Flutter
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  flutter_riverpod: ^2.4.9
  go_router: ^13.0.0
  fl_chart: ^0.66.0
  http: ^1.1.0
  shared_preferences: ^2.2.2
  intl: ^0.18.1
  flutter_contacts: ^1.1.7+1
  permission_handler: ^11.1.0
```

### Python (Backend)
```
flask
flask-cors
supabase
python-jose
cryptography
openai (optional)
```

---

## 🔧 Configuration

### Android Permissions
The app requires the following permissions:
- `READ_CONTACTS` - For contact-based features

### Supabase Schema
The app uses the following tables:
- `users` - User accounts
- `transactions` - Income/Expense records
- `loans` - Loan tracking (given/borrowed)

---

## 📄 License

This project is for demonstration purposes.

---

## 👤 Author

Musfiqul Islam Shaon

---

## 🛠️ Built With

- [Flutter](https://flutter.dev) - Cross-platform framework
- [Riverpod](https://riverpod.dev) - State management
- [GoRouter](https://pub.dev/packages/go_router) - Declarative routing
- [Fl Chart](https://fl_chart.dev) - Beautiful charts
- [Supabase](https://supabase.com) - Backend-as-a-Service
- [Flask](https://flask.palletsprojects.com) - Python web framework

