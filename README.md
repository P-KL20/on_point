# 📱 OnPoint – Personal Finance Manager (iOS)

OnPoint is a mobile app designed to help users take control of their personal finances with ease. Built using **Flutter** and backed by **Firebase**, this app enables users to track income, expenses, and subscriptions, set monthly budgets, visualize spending trends, and receive smart notifications for overspending.

> 🎯 Built by students at California State University, Northridge for COMP 583 – Software Engineering.

---

## 📦 Features

- 🔐 **Secure Authentication** – Firebase Auth handles user login and sign-up securely.
- 🧾 **Transaction Logging** – Record deposits, withdrawals, transfers, and purchases.
- 💰 **Budget Creation** – Set monthly limits by category, with custom validation and real-time tracking.
- 📊 **Visual Insights** – View spending breakdowns, trends, and top spending categories via charts.
- 🚨 **Overspending Alerts** – Get notified when you exceed your budget in any category.
- 🔔 **Bill Reminders** – Stay on top of upcoming subscriptions or bill payments with local notifications.
- ☁️ **Cloud Sync** – Your data is safely stored and synced via Firebase Firestore.
- 📱 **iOS-Only UI** – Clean, intuitive design with bottom navigation and card-based components.

---

## 🛠️ Tech Stack

| Layer           | Technology                     |
|----------------|---------------------------------|
| Mobile UI       | Flutter (Dart) + Figma (Design) |
| Auth            | Firebase Authentication         |
| Backend DB      | Firebase Firestore (JSON-based) |
| Data Charts     | fl_chart                        |
| Notifications   | flutter_local_notifications     |
| Architecture    | Service-Oriented (Clean UI/Logic separation) |

---

## 📂 Folder Structure

lib/ ├── models/ # Data models (e.g., OverspentAlert) ├── screens/ # UI screens (Login, Home, Budget, etc.) │ ├── login_screen.dart │ ├── signup_screen.dart │ ├── home_screen.dart │ ├── budget_input_screen.dart │ ├── transaction_history_screen.dart │ ├── budget_overview_screen.dart │ ├── create_budget_screen.dart │ ├── notification_history_screen.dart │ └── settings_screen.dart ├── services/ # Firestore and logic layer │ ├── auth_service.dart │ ├── budget_service.dart │ ├── transaction_service.dart │ ├── notification_service.dart │ ├── firestore_service.dart │ ├── home_service.dart │ └── logger_service.dart ├── utils/ # Utility components │ └── dialog_helper.dart ├── routes.dart # Centralized route definitions └── main.dart # App entry point

---

## 📸 Screenshots (Coming Soon)

- ✅ Login & Sign Up
- 💸 Budget Overview
- 📉 Monthly Trends
- ⚠️ Overspent Alerts
- 🔍 Transaction History
- 🔔 Notification Center

---

## 🙌 Team

- **Phone Pyae Zaw**
- **Edward Eckelberry** 
- **Alyssa Gomez**
  
California State University, Northridge

---

## 📌 Note

This is a student academic project – not for commercial release.  
Our focus is on **learning software engineering** through real-world finance problems.
