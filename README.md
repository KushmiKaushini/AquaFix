# AquaFix

A comprehensive incident reporting and management system with AI-powered analysis for water quality and infrastructure issues.

## Overview

AquaFix is a full-stack application designed to facilitate incident reporting and management with intelligent analysis capabilities powered by Google's Gemini AI. The platform enables users to report incidents through a mobile-friendly interface and provides administrators with powerful tools for managing and analyzing reports.

## Tech Stack

### Backend
- **Framework**: Python with FastAPI
- **Database**: Configured with support for relational databases
- **Authentication**: JWT-based authentication system
- **AI Integration**: Google Gemini for incident analysis
- **API**: RESTful API with versioned endpoints (v1)

### Frontend
- **Framework**: Flutter
- **Language**: Dart
- **Features**: 
  - Incident reporting interface
  - Location services integration
  - API client for backend communication

## Project Structure

```
AquaFix/
├── backend/
│   ├── app/
│   │   ├── main.py              # Application entry point
│   │   ├── api/
│   │   │   └── v1/              # API version 1 endpoints
│   │   │       ├── auth.py      # Authentication endpoints
│   │   │       └── incidents.py # Incident endpoints
│   │   ├── core/
│   │   │   ├── auth.py          # Authentication logic
│   │   │   ├── config.py        # Configuration management
│   │   │   └── database.py      # Database connection
│   │   ├── models/
│   │   │   ├── audit.py         # Audit log model
│   │   │   ├── incident.py      # Incident model
│   │   │   └── user.py          # User model
│   │   ├── schemas/
│   │   │   ├── incident.py      # Incident request/response schema
│   │   │   └── user.py          # User request/response schema
│   │   └── services/
│   │       └── gemini.py        # Gemini AI integration service
│   └── requirements.txt         # Python dependencies
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart            # Application entry point
│   │   ├── app.dart             # App configuration and setup
│   │   ├── providers/
│   │   │   └── location_provider.dart  # Location service provider
│   │   ├── screens/
│   │   │   └── reporter/
│   │   │       └── incident_reporter_screen.dart  # Incident reporting UI
│   │   └── services/
│   │       └── api_service.dart  # Backend API client
│   └── pubspec.yaml             # Flutter dependencies
│
├── PROJECT_PLAN.md              # Project planning documentation
├── CODEBASE_AUDIT_REPORT.md     # Code audit and analysis report
├── LICENSE                      # Project license
└── README.md                    # This file
```

## Features

- **Incident Reporting**: Users can easily report incidents with location data and detailed information
- **AI Analysis**: Automatic analysis of reports using Google Gemini AI
- **User Authentication**: Secure JWT-based authentication system
- **Audit Logging**: Comprehensive audit trail of all activities
- **REST API**: Well-structured, versioned API endpoints
- **Mobile Interface**: Flutter-based responsive mobile application

## Getting Started

### Prerequisites

- **Backend**: Python 3.8+
- **Frontend**: Flutter 3.0+ with Dart SDK
- **Other**: Git

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure environment variables (create a `.env` file):
   ```
   DATABASE_URL=your_database_url
   GEMINI_API_KEY=your_gemini_api_key
   JWT_SECRET=your_secret_key
   ```

4. Run the application:
   ```bash
   python -m app.main
   ```

The backend API will be available at `http://localhost:8000`

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

## API Documentation

The backend provides a REST API with the following main endpoints:

- **Authentication** (`/api/v1/auth`)
  - `POST /login` - User login
  - `POST /register` - User registration
  - `POST /refresh` - Refresh authentication token

- **Incidents** (`/api/v1/incidents`)
  - `GET /` - List all incidents
  - `POST /` - Create new incident report
  - `GET /{id}` - Get incident details
  - `PUT /{id}` - Update incident
  - `DELETE /{id}` - Delete incident

## Environment Configuration

Create a `.env` file in the backend directory with the following variables:

```
DATABASE_URL=postgresql://user:password@localhost/aquafix
GEMINI_API_KEY=your_gemini_api_key
JWT_SECRET=your_jwt_secret_key
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

## Contributing

Contributions are welcome! Please ensure:
- Code follows the project's style guidelines
- All tests pass
- Documentation is updated
- Commit messages are clear and descriptive

## License

See the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please refer to the project documentation:
- [Project Plan](PROJECT_PLAN.md)
- [Codebase Audit Report](CODEBASE_AUDIT_REPORT.md)

## Changelog

All notable changes to this project will be documented in a CHANGELOG file when major updates are released.
