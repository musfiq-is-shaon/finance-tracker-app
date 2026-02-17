# APK Build & Deployment Plan

## APK Location
The debug APK has been built at:
- `finance_tracker_app/build/app/outputs/flutter-apk/app-debug.apk` (142MB)

## Files Created for Render Deployment:
1. **Procfile** (root) - `web: cd backend && PYTHONPATH=. gunicorn -w 4 -b 0.0.0.0:$PORT app:app`
2. **requirements.txt** (root) - Python dependencies
3. **runtime.txt** - Specifies Python 3.11

## Render Deployment Steps:

1. Push all changes to GitHub
2. Create a new Web Service on Render
3. Connect your GitHub repo
4. Configure:
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `cd backend && PYTHONPATH=. gunicorn -w 4 -b 0.0.0.0:$PORT app:app`
5. Add Environment Variables:
   - `SUPABASE_URL`: your Supabase URL
   - `SUPABASE_KEY`: your Supabase key  
   - `JWT_SECRET`: a secure secret key
6. Deploy!

## After Backend Deployment:

1. Update `finance_tracker_app/lib/utils/constants.dart` with your Render URL:
   ```dart
   return 'https://your-app.onrender.com';
   ```

2. Rebuild APK:
   ```bash
   cd finance_tracker_app && flutter build apk --release
   ```

## Sharing the APK:
- Send via email, cloud storage (Google Drive), or messaging apps
- Recipients need to enable "Install from unknown sources"

