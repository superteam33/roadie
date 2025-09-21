#!/bin/bash

echo "🚀 Setting up Roadie - AI-Powered Project Management Platform"
echo "=============================================================="

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed. Please install Ruby 3.2.2+ first."
    exit 1
fi

# Check Ruby version
RUBY_VERSION=$(ruby -v | cut -d' ' -f2 | cut -d'p' -f1)
echo "✅ Ruby version: $RUBY_VERSION"

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo "❌ PostgreSQL is not installed. Please install PostgreSQL 12+ first."
    echo "   On macOS: brew install postgresql"
    echo "   On Ubuntu: sudo apt-get install postgresql postgresql-contrib"
    exit 1
fi

# Check if Redis is installed
if ! command -v redis-server &> /dev/null; then
    echo "❌ Redis is not installed. Please install Redis 6+ first."
    echo "   On macOS: brew install redis"
    echo "   On Ubuntu: sudo apt-get install redis-server"
    exit 1
fi

echo "✅ PostgreSQL and Redis are installed"

# Install gems
echo "📦 Installing gems..."
bundle install

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cat > .env << EOF
# Database
DATABASE_URL=postgresql://localhost/roadie_development

# JWT Secret (generate a secure secret)
JWT_SECRET_KEY=$(openssl rand -hex 32)

# Redis URL for Sidekiq
REDIS_URL=redis://localhost:6379/0

# AI Service API Keys
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# External Service API Keys
SLACK_BOT_TOKEN=your_slack_bot_token_here
GITHUB_ACCESS_TOKEN=your_github_access_token_here
GMAIL_CLIENT_ID=your_gmail_client_id_here
GMAIL_CLIENT_SECRET=your_gmail_client_secret_here

# Application Settings
RAILS_ENV=development
RAILS_MAX_THREADS=5
EOF
    echo "✅ Created .env file with generated JWT secret"
else
    echo "✅ .env file already exists"
fi

# Start PostgreSQL if not running
if ! pg_isready -q; then
    echo "🐘 Starting PostgreSQL..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew services start postgresql
    else
        sudo service postgresql start
    fi
    sleep 3
fi

# Start Redis if not running
if ! redis-cli ping &> /dev/null; then
    echo "🔴 Starting Redis..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew services start redis
    else
        sudo service redis-server start
    fi
    sleep 2
fi

# Create and setup database
echo "🗄️  Setting up database..."
rails db:create
rails db:migrate
rails db:seed

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Update your .env file with your API keys"
echo "2. Start the Rails server: rails server"
echo "3. Start Sidekiq in another terminal: bundle exec sidekiq"
echo "4. Visit http://localhost:3000 to see the API"
echo ""
echo "Default admin user:"
echo "Email: admin@roadie.com"
echo "Password: password123"
echo ""
echo "Happy coding! 🚀"
