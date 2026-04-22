STRM Application - Technical Documentation

1. PROJECT OVERVIEW
STRM is a Flutter-based task management application with offline-first architecture, cloud synchronization, and weather integration. The app allows users to create, manage, and sync tasks between local SQLite database and Firebase Firestore.

Technology Stack:
- Framework: Flutter (Dart)
- Local Database: SQLite (via sqflite package)
- Cloud Database: Firebase Firestore
- Authentication: Firebase Authentication
- Weather API: OpenWeatherMap API
- State Management: Provider pattern

2. SQLITE SCHEMA

Database Configuration:
- Database Name: fastrm.db
- Version: 2
- Location: Platform-specific databases directory

Table: tasks

Schema:
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cloudId TEXT,
  userId TEXT,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL,
  createdAt TEXT NOT NULL
)

Column Details:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Local unique identifier |
| cloudId | TEXT | NULLABLE | Firestore document ID |
| userId | TEXT | NULLABLE | User ID for data isolation |
| title | TEXT | NOT NULL | Task title |
| description | TEXT | NOT NULL | Task description |
| status | TEXT | NOT NULL | 'draft' or 'synced' |
| createdAt | TEXT | NOT NULL | ISO 8601 timestamp string |

Migration History

Version 1 to Version 2:
Added support for cloud synchronization:
ALTER TABLE tasks ADD COLUMN cloudId TEXT
ALTER TABLE tasks ADD COLUMN userId TEXT

3. FIRESTORE STRUCTURE

Collection Hierarchy:
users (collection)
  - {userId} (document)
      - tasks (subcollection)
          - {cloudId} (document)

Document Structure

Collection: users/{userId}/tasks

Document Fields:

| Field | Type | Description |
|-------|------|-------------|
| id | int | Local SQLite id (for reference) |
| cloudId | String | Firestore document ID (matches document key) |
| userId | String | Firebase Auth user ID |
| title | String | Task title |
| description | String | Task description |
| status | String | 'draft' or 'synced' |
| createdAt | String | ISO 8601 timestamp |

Cloud ID Generation

Format: {userId}_{timestamp_microseconds}_{localId}

Example: abc123xyz_1713456789012345_42

4. REST API ENDPOINTS

OpenWeatherMap API

Base URL: https://api.openweathermap.org/data/2.5/weather

Endpoint: GET /weather

Authentication: API Key via appid query parameter

Request Parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| q | String | Yes | City name (default: 'Manila') |
| appid | String | Yes | OpenWeatherMap API key |
| units | String | Yes | Units system ('metric' for Celsius) |

Example Request:
GET https://api.openweathermap.org/data/2.5/weather?q=Manila&appid=YOUR_API_KEY&units=metric

Response Format (JSON):
{
  "main": {
    "temp": 33.0
  },
  "weather": [
    {
      "main": "Clouds"
    }
  ],
  "name": "Manila"
}

Response Mapping:

| JSON Path | Model Field |
|-----------|-------------|
| main.temp | temperature |
| weather[0].main | condition |
| name | locationName |

Configuration:
- API key stored in .env file as OPENWEATHER_API_KEY
- Base URL and default city defined in AppConstants
