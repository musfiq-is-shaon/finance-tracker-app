# TODO - Contact Picker Feature Implementation

## Plan Status: IN PROGRESS

### 1. Database Schema Update
- [x] Add `phone_number` column to loans table in supabase_schema.sql

### 2. Backend Update
- [x] Modify loan_routes.py to accept and store phone_number

### 3. Loan Model Update
- [x] Add phoneNumber field to loan.dart

### 4. Loan Provider Update
- [x] Modify loan_provider.dart to include phone number

### 5. Android Manifest Update
- [x] Add READ_CONTACTS permission

### 6. pubspec.yaml Update
- [x] Add flutter_contacts package

### 7. Add Loan Screen Update
- [x] Add phone number field with contact picker

### 8. Loan List Screen Update
- [x] Display phone number in loan item

