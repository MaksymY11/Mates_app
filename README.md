# Mates

![Flutter](https://img.shields.io/badge/Flutter-3.7+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.7+-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android_·_iOS-6C757D)
![Netlify](https://img.shields.io/badge/Landing_Page-Netlify-00C7B7?logo=netlify&logoColor=white)

Flutter frontend for Mates, a roommate-matching app for college students. Users furnish a virtual apartment to build a preference profile, get clustered into neighborhoods with similar people, and form households through shared activities and real-time chat. No swiping, no ranking.

> **License:** Source-available. See [LICENSE](LICENSE) for terms.

---

## Tech Stack

- **Flutter** targeting Windows desktop, Android, and web (landing page only)
- **Material 3** with a dual brand palette (`#4CAF50` primary, `#7CFF7C` accent)
- **WebSocket** via `web_socket_channel` for real-time messaging
- **Service layer** pattern with `setState` (no state management library)
- **SharedPreferences** for token persistence
- **Backend** — FastAPI + PostgreSQL ([mates-backend](https://github.com/MaksymY11/mates_backend))

---

## Features

<details>
<summary><strong>Apartment Builder</strong> — isometric floor plan with zoom-to-room animation</summary>
<br>

The center tab and default landing page after login. Users place furniture from a categorized catalog onto an isometric tilted floor plan built with Matrix4 perspective transforms. Tapping a room zooms in with an animated transition, and a furniture picker slides up for that zone. Style presets offer one-tap furnishing for an entire room. Every item placement or removal triggers an instant vibe recalculation on the backend, and the vibe label strip at the top of the page updates live.
</details>

<details>
<summary><strong>Vibe System</strong> — live preference labels derived from apartment choices</summary>
<br>

A horizontal scroll strip of label chips sits at the top of the apartment builder, showing the user's current vibe profile ("Night Owl," "Social Butterfly," etc.). These update in real time as furniture changes. When viewing another user's apartment, a comparison overlay shows their labels alongside yours, highlights similarities and differences, and surfaces conversation starters.
</details>

<details>
<summary><strong>Daily Scenarios</strong> — situational questions shown as profile conversation starters</summary>
<br>

A banner on the apartment builder page presents one new scenario per day. Answering opens a bottom sheet with the full question and options. Once a user has three active responses, answering a new one triggers a substitution step where they choose which old answer to replace. Scenario answers appear on profiles as cards, and the comparison view on another user's apartment page highlights where you agree (green) and where you diverge (orange).
</details>

<details>
<summary><strong>Discovery</strong> — neighborhood explorer with similarity scores and location filtering</summary>
<br>

The Discovery tab shows the user's assigned neighborhood, a list of neighbors ranked by similarity percentage, and expandable cards for nearby neighborhoods. A segmented button lets users toggle location filtering between same city, same state, or anywhere. Neighbor cards display avatar, name, match percentage, city/state, budget, move-in date, and vibe label chips. Tapping a card navigates to that user's apartment view. A wave button on each card lets users express interest.
</details>

<details>
<summary><strong>Quick Picks</strong> — timed trade-off sessions triggered by mutual interest</summary>
<br>

When two users wave at each other, a five-question rapid-fire session opens. Questions appear one at a time with option cards, a progress bar, and a 60-second countdown timer. After both users finish, a results page shows side-by-side answers with green (agree) and orange (diverge) indicators, a summary, and CTAs to invite to a household or start a conversation.
</details>

<details>
<summary><strong>Households</strong> — group formation with invites, roles, and collaborative house rules</summary>
<br>

The Household tab has two states. Without a household, users see a create button, pending invites, and a list of eligible connections (people they've completed Quick Picks with). Inside a household, the page splits into Members and House Rules tabs. Members shows role badges, an invite button (disabled with "Pending" for already-sent invites), and a leave option. House Rules groups rules by status (accepted, proposed, removal proposed, rejected) with voting buttons. A chat icon in the app bar opens the household's group conversation. The tab badge lights up for pending invites, unvoted rules, or unread group messages.
</details>

<details>
<summary><strong>Messaging</strong> — real-time chat with optimistic rendering and typing indicators</summary>
<br>

Full chat UI for both DMs and group conversations. Own messages render instantly on send (optimistic) while the server handles persistence and delivery to the other side. Messages are right-aligned in the brand color for the current user, left-aligned in grey for others. Group chat shows sender avatars and names. Typing indicators use a debounced send (2s) and auto-dismiss (3s). Scroll-to-top loads older messages via cursor-based pagination. Read receipts update on open and on new incoming messages.
</details>

<details>
<summary><strong>Matches</strong> — conversations and mutual interests in one view</summary>
<br>

The Matches tab splits into two sections: active conversations (with last message preview and unread count) and matches (mutual interests that haven't started a conversation yet). Users who already have a DM are filtered out of the matches list so nobody appears twice. A "Message" action on completed matches creates the DM and navigates straight to chat.
</details>

<details>
<summary><strong>WebSocket</strong> — singleton connection with auto-reconnect and auth handling</summary>
<br>

A singleton service manages one WebSocket connection per app session, connecting on app start and disconnecting on dispose. If the connection drops, it reconnects with exponential backoff (1s, 2s, 4s, capping at 30s). On an auth failure (close code 4001), it triggers logout and stops retrying. The public stream lets any page subscribe to incoming messages, typing events, and read receipts.
</details>

---

## Scale

- **29 files** across 5 feature modules + a 10-service backend integration layer
- **~8,800 lines** of Dart
- **10 services** covering auth, apartments, vibes, scenarios, discovery, Quick Picks, households, messaging, and WebSocket management
- **5-tab navigation** with per-tab refresh via GlobalKey and badge state tracking

---

## Project Structure

```
lib/
├── main.dart                            # Entry point, theme, routing, web vs mobile
├── home_page.dart                       # 5-tab shell with badge state + GlobalKey refresh
├── login_page.dart                      # Email + password login
├── signup_page.dart                     # Registration with validation
├── profile_page.dart                    # Profile editing, avatar upload, vibe + scenario display
├── landing_page.dart                    # Marketing page (web only)
│
├── apartment/
│   ├── apartment_builder_page.dart      # Isometric floor plan, zoom, furniture placement
│   ├── apartment_view_page.dart         # Other user's apartment + vibe/scenario comparison
│   ├── furniture_picker.dart            # Categorized catalog with icon mapping
│   └── vibe_picker_page.dart            # Style preset selection
│
├── discovery/
│   ├── neighborhood_page.dart           # Neighborhood view + location filter
│   ├── neighbor_card.dart               # User card with similarity + wave button
│   └── neighborhood_card.dart           # Nearby neighborhood expandable card
│
├── quickpicks/
│   ├── matches_page.dart                # Conversations + matches split view
│   ├── quick_pick_page.dart             # 5-question timed session UI
│   └── quick_pick_results_page.dart     # Side-by-side results with agree/diverge
│
├── household/
│   └── household_page.dart              # Members, invites, house rules, voting
│
├── messaging/
│   └── conversation_page.dart           # Chat UI, optimistic send, typing indicators
│
├── services/
│   ├── api_service.dart                 # HTTP gateway with 401 handling
│   ├── auth_service.dart                # Login, register, token management
│   ├── apartment_service.dart           # Apartment + furniture API wrapper
│   ├── vibe_service.dart                # Vibe profiles and comparison
│   ├── scenario_service.dart            # Daily scenarios and answers
│   ├── discovery_service.dart           # Neighborhoods and neighbors
│   ├── quickpick_service.dart           # Interest, sessions, results
│   ├── household_service.dart           # Household CRUD, invites, rules
│   ├── messaging_service.dart           # REST conversations and messages
│   └── websocket_service.dart           # Singleton WS with auto-reconnect
│
└── utils/
    └── validators.dart                  # Input validation helpers
```
