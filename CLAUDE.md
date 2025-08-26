# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

球探社 (BallScout) is a revolutionary football media aggregation app built with Flutter frontend and Deno backend. The project aims to provide a clean, ad-free football news experience with AI-powered translation and content curation.

**Tech Stack:**
- Frontend: Flutter 3.16+ (Dart)
- Backend: Deno 1.40+ (TypeScript) 
- Database: PostgreSQL + Redis
- AI Integration: DeepSeek (primary), Claude, OpenAI (translation services)
- Deployment: Docker + Docker Compose

## Development Commands

### Frontend (Flutter)
```bash
# Install dependencies
flutter pub get

# Run web development server
flutter run -d web-server --web-port=3000

# Run mobile app (Android/iOS)
flutter run

# Run tests
flutter test

# Build for production
flutter build web
flutter build apk --release
flutter build ios --release

# Code generation (JSON serialization)
dart run build_runner build

# Lint and analyze
flutter analyze
```

### Backend (Deno)
```bash
cd backend

# Start development server with hot reload
deno task dev

# Run in production
deno task start

# Run tests
deno task test

# Format code
deno task fmt

# Lint code
deno task lint

# Type check
deno task check
```

### Database Operations
```bash
# Start database services
docker-compose -f docker-compose.dev.yml up postgres redis -d

# Connect to PostgreSQL
psql -h localhost -p 5432 -U postgres -d ball_scout

# Initialize database schema
psql -h localhost -p 5432 -U postgres -d ball_scout -f scripts/setup-database.sql
```

### Development Scripts
```bash
# Start complete development environment
./scripts/start-dev.sh

# Test API endpoints
./scripts/test-api.sh

# Test news crawler
./scripts/test-news-crawler.sh

# Test DeepSeek translation
./scripts/test-deepseek-api.sh
```

## Architecture Overview

### Frontend Structure (Flutter)
- **State Management**: Riverpod for reactive state management
- **Routing**: GoRouter for declarative navigation
- **HTTP Client**: Dio with interceptors for API requests
- **Local Storage**: SharedPreferences + SQLite + Hive
- **UI Framework**: Material 3 with custom theming

Key directories:
- `lib/models/`: Data models with JSON serialization
- `lib/services/`: API services and business logic
- `lib/screens/`: UI screens organized by feature
- `lib/widgets/`: Reusable UI components

### Backend Structure (Deno)
- **Web Framework**: Oak for HTTP server
- **Database**: PostgreSQL with client connection pooling
- **Caching**: Redis for session and data caching
- **Translation**: Multi-provider AI translation service
- **News Aggregation**: Automated crawlers for global football media

Key directories:
- `backend/services/`: Feature-based service modules
- `backend/shared/`: Common utilities and database connections
- `backend/tests/`: Test files

### Service Integration
- **Translation Service**: DeepSeek API primary, Claude/OpenAI fallback
- **News Sources**: BBC Sport, ESPN, Goal.com, local media APIs
- **User Authentication**: JWT-based with refresh token rotation
- **Community Features**: Comments, user profiles, reading history

## Configuration Files

### Environment Variables
Backend requires `.env` file with:
- Database credentials (PostgreSQL, Redis)
- AI API keys (DeepSeek, Claude, OpenAI)
- JWT secrets
- News source API keys

### Cursor AI Rules
The project includes Cursor AI rules in `.cursor/rules/`:
- `project-overview.mdc`: Always-applied project context
- `flutter-standards.mdc`: Flutter development standards
- `backend-services.mdc`: Deno/TypeScript backend patterns
- `ai-integration.mdc`: AI service integration guidelines

## Key Development Patterns

### Flutter Patterns
- Use `ConsumerWidget` for Riverpod state management
- Implement Repository pattern for data access
- Follow Material 3 design system
- Use `const` constructors for performance
- Implement proper error handling with custom exceptions

### Backend Patterns
- RESTful API design with `/api/v1/` prefix
- Unified response format with success/error structure
- Service-based architecture with dependency injection
- Comprehensive error handling with custom error classes
- Database migrations through versioned SQL scripts

### Translation Workflow
- Content detection and classification
- Context-aware football terminology translation
- Caching translated content with Redis
- Fallback provider system for high availability

## Testing Strategy
- Flutter: Unit tests for models/services, widget tests for UI
- Backend: API endpoint tests, integration tests with test database
- E2E: Critical user flows (login, news reading, translation)

## Deployment Notes
- Web app serves from `/web` build output
- Backend runs on port 8000, frontend on port 3000 in development
- Docker Compose handles service orchestration
- Database initialization through `setup-database.sql`