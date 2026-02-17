class Constants {
  static const String appName = 'Finance Tracker';
  
  // Base URL for the backend API
  // Use 10.0.2.2 for Android emulator to connect to host's localhost
  // Use 127.0.0.1 for iOS simulator
  // For physical device, use your computer's IP address (e.g., http://192.168.1.x:5001)
  static const String baseUrl = 'http://10.0.2.2:5001';
  
  // Supabase Configuration
  static const String supabaseUrl = 'https://oeallybeawbthptebwca.supabase.co';
  static const String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lYWxseWJlYXdidGhwdGVid2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNzk0NDQsImV4cCI6MjA4Njc1NTQ0NH0.Cdws0xQ0odwx-dW-AvGS37jZJMZuvxx5_5BJ0rO-VAQ';
  
  static const List<String> incomeCategories = [
    'Salary',
    'Business',
    'Investment',
    'Gift',
    'Other',
  ];
  
  static const List<String> expenseCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Bills',
    'Health',
    'Education',
    'Other',
  ];
}

