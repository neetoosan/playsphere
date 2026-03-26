# PlaySphere 🎬

A comprehensive social video sharing platform built with Flutter, featuring advanced video analytics, creator monetization, and cross-platform autoplay capabilities.

## 📱 Overview

PlaySphere is a modern video-centric social media application that combines the best features of popular video platforms with advanced creator tools and monetization features. Built with Flutter and Firebase, it offers a seamless experience across mobile and web platforms.

## ✨ Key Features

### 🎥 Video Management
- **Advanced Video Player**: Custom video player with autoplay, loop, and visibility-based playback
- **Smart Upload System**: Optimized video upload with thumbnail generation
- **Video Analytics**: Comprehensive view tracking and engagement metrics
- **Cross-Platform Autoplay**: Intelligent autoplay system that works across mobile and web

### 👥 Social Features
- **User Profiles**: Customizable profiles with follower/following system
- **Real-time Messaging**: Direct messaging between users
- **Comments & Likes**: Interactive engagement system
- **Search Functionality**: Discover users and content

### 💰 Monetization System
- **Creator Earnings**: View-based revenue system for content creators
- **Payment Integration**: Paystack integration for withdrawals
- **Subscription Plans**: Premium subscription tiers
- **Analytics Dashboard**: Detailed earnings and performance metrics

### 🔐 Authentication & Security
- **Firebase Authentication**: Secure user authentication
- **Email Verification**: Account verification system
- **Screen Recording Protection**: Content protection features
- **User Data Cleanup**: Comprehensive data management

## 🏗️ Architecture

### State Management
- **GetX**: Reactive state management for optimal performance
- **Controller Pattern**: Organized business logic separation
- **Lifecycle Management**: Intelligent app state handling

### Backend Services
- **Firebase Firestore**: Real-time database for user data and videos
- **Firebase Storage**: Secure file storage for videos and images
- **Firebase Analytics**: User behavior tracking
- **Cloud Functions**: Server-side processing

### Key Services
- **Video View Service**: Advanced view tracking with cooldown periods
- **Earnings Service**: Creator monetization calculations
- **Analytics Migration Service**: Data synchronization and migration
- **Autoplay Service**: Cross-platform video autoplay management
- **Historical Analytics Service**: Data preservation and cleanup

## 📂 Project Structure

```
lib/
├── controllers/           # Business logic controllers
├── models/               # Data models
├── services/             # Backend services
├── views/               # UI components
│   ├── screens/         # App screens
│   └── widgets/         # Reusable widgets
├── utils/               # Utility functions
└── constants.dart       # App constants
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest version)
- Dart SDK
- Firebase project setup
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/play_sphere.git
   cd play_sphere
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project
   - Add your Firebase configuration files:
     - `android/app/google-services.json`
     - `lib/firebase_options.dart`

4. **Run the application**
   ```bash
   flutter run
   ```

## 🔧 Configuration

### Firebase Setup
1. Enable Authentication (Email/Password)
2. Set up Firestore Database
3. Configure Firebase Storage
4. Enable Firebase Analytics

### Required Collections
- `users` - User profiles and data
- `videos` - Video metadata and analytics
- `comments` - Video comments
- `messages` - Direct messages
- `earnings` - Creator earnings data
- `subscriptions` - User subscription data

## 💡 Key Features Deep Dive

### Video Analytics System
The app includes a sophisticated analytics system that:
- Tracks video views with cooldown periods to prevent spam
- Calculates creator earnings based on engagement
- Preserves historical data even after content deletion
- Provides real-time analytics dashboards

### Smart Autoplay Management
Cross-platform autoplay system featuring:
- Visibility-based playback (videos play when 60%+ visible)
- Browser compatibility handling for web platforms
- Lifecycle-aware playback management
- Performance-optimized video switching

### Monetization Engine
Comprehensive creator economy features:
- View-based earnings calculation
- Multiple subscription tiers
- Withdrawal request system
- Payment processing integration

## 🛠️ Technologies Used

- **Frontend**: Flutter, Dart
- **State Management**: GetX
- **Backend**: Firebase (Firestore, Storage, Auth, Analytics)
- **Payment Processing**: Paystack
- **Video Processing**: Custom video player with advanced features
- **Real-time Features**: Firebase real-time listeners

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support, email [your-email@example.com] or create an issue in this repository.

## 🎯 Future Roadmap

- [ ] Live streaming capabilities
- [ ] Advanced video editing tools
- [ ] AI-powered content recommendations
- [ ] Multi-language support
- [ ] Advanced creator analytics
- [ ] Social features expansion

---

## 📸 Screenshots

### Home Screen
![Home Screen](screenshots/home_screen.png)

### Video Player
![Video Player](screenshots/video_player.png)

### Profile Screen
![Profile Screen](screenshots/profile_screen.png)

### Analytics Dashboard
![Analytics Dashboard](screenshots/analytics_dashboard.png)

### Upload Screen
![Upload Screen](screenshots/upload_screen.png)

### Messaging
![Messaging](screenshots/messaging.png)

---

*Built with ❤️ using Flutter*
