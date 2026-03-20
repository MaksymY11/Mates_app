# Mates

A roommate matching app built with Flutter, connecting to a FastAPI backend.

## Tech Stack

- **Flutter** (Dart) — cross-platform frontend targeting web and Windows desktop
- **Backend** — FastAPI, live at `https://mates-backend-dxma.onrender.com`
- **Storage** — PostgreSQL on Neon
- **Deployment** — Netlify (web build at `https://matesv1.netlify.app`)

## Project Structure

```
lib/
├── main.dart               # App entry point, theme, routing
├── landing_page.dart       # Marketing page (web only)
├── login_page.dart         # Login screen
├── signup_page.dart        # Registration screen
├── home_page.dart          # Main shell with bottom nav + tab pages
├── profile_page.dart       # Profile editing, avatar upload
└── services/
    ├── api_service.dart    # Centralized HTTP client with 401 handling
    ├── auth_service.dart   # Register and login
    └── user_service.dart   # Fetch and update user profile
```

## Screens

| Screen     | Description                                                                                     |
| ---------- | ----------------------------------------------------------------------------------------------- |
| Landing    | Marketing page shown on web. Features hero section, feature highlights, and verification steps. |
| Login      | Email + password login. Saves JWT to SharedPreferences on success.                              |
| Sign Up    | Email + password registration. Auto-logs in after successful registration.                      |
| Home Shell | 5-tab bottom nav: Matching, Chats, Home Feed, Notifications, Profile.                           |
| Home Feed  | Browsable list of roommate profiles (currently mock data).                                      |
| Profile    | Edit name, age, state, city, budget, move-in date, bio, lifestyle chips, and avatar.            |

## Architecture

- **No state management library** — uses `setState` and service classes
- **ApiService** — all authenticated HTTP calls go through `ApiService.get()` and `ApiService.post()`. Automatically clears the token and redirects to login on a 401 response.
- **Auth token** — stored in `SharedPreferences` under `auth_token`
- **Web vs mobile** — `kIsWeb` in `main.dart` determines the entry point. Web shows `LandingPage`, mobile shows `LoginPage`.

## Dependencies

| Package              | Purpose                                 |
| -------------------- | --------------------------------------- |
| `http`               | HTTP requests                           |
| `shared_preferences` | Token storage                           |
| `image_picker`       | Avatar selection from camera or gallery |
| `path_provider`      | Local file storage for avatars          |
| `http_parser`        | Multipart file upload MIME types        |
| `url_launcher`       | Opening external URLs from landing page |

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run on Windows desktop (recommended for development)
flutter run -d windows

# Run on Chrome (shows web/landing page flow)
flutter run -d chrome
```

## Backend

Backend repository: `https://github.com/MaksymY11/mates_backend`

Endpoints used by this app:

| Method | Endpoint        | Auth | Description                |
| ------ | --------------- | ---- | -------------------------- |
| POST   | `/registerUser` | No   | Create account             |
| POST   | `/loginUser`    | No   | Login, returns JWT         |
| POST   | `/logout`       | Yes  | Invalidate token           |
| GET    | `/me`           | Yes  | Fetch current user profile |
| POST   | `/updateUser`   | Yes  | Update profile fields      |
| POST   | `/uploadAvatar` | Yes  | Upload profile photo       |

## Known Limitations

- Home Feed is currently mock data — real user discovery endpoint not yet implemented
- Matching, Chats, and Notifications tabs are stubs
- Avatar storage uses Render's local filesystem, which is ephemeral and will be migrated to persistent object storage in a future update
