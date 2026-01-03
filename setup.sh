#!/bin/bash
# Setup script for infrastructure repository

echo "🔧 Setting up infrastructure repository..."

# Configure git to use .githooks directory
echo "📌 Configuring git hooks..."
git config core.hooksPath .githooks

echo "✅ Setup complete!"
echo "   Git hooks are now configured to use .githooks/"
echo "   The pre-commit hook will prevent committing unencrypted vault files."
