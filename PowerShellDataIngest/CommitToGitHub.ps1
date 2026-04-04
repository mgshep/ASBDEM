# ============================================================================
# GitHub Commit and Push Script for ASBDEM Project
# ============================================================================
# This script commits all changes to git and pushes to GitHub
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$CommitMessage = "Database updates and script improvements"
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "GitHub Commit and Push Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to the repository root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# If script is in PowerShellDataIngest subdirectory, go up one level to repo root
if ((Split-Path -Leaf $scriptPath) -eq "PowerShellDataIngest") {
    $repoRoot = Split-Path -Parent $scriptPath
}
else {
    $repoRoot = $scriptPath
}

Set-Location $repoRoot
Write-Host "Working directory: $(Get-Location)" -ForegroundColor Cyan
Write-Host ""

# Check if git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: git is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "Git version:" -ForegroundColor Yellow
git --version
Write-Host ""

# Initialize git repository if needed
if (-not (Test-Path .git)) {
    Write-Host "Initializing git repository..." -ForegroundColor Yellow
    git init
    Write-Host "Git repository initialized" -ForegroundColor Green
    Write-Host ""
}

# Configure git user (only if not already configured)
$gitUserName = git config user.name
$gitUserEmail = git config user.email

if (-not $gitUserName) {
    Write-Host "Setting up git user configuration..." -ForegroundColor Yellow
    Write-Host "Please enter your GitHub username: " -NoNewline
    $username = Read-Host
    git config user.name "$username"
}

if (-not $gitUserEmail) {
    Write-Host "Please enter your GitHub email: " -NoNewline
    $email = Read-Host
    git config user.email "$email"
}

Write-Host ""
Write-Host "Git configured as: $(git config user.name) <$(git config user.email)>" -ForegroundColor Green
Write-Host ""

# Create .gitignore if it doesn't exist
if (-not (Test-Path .gitignore)) {
    Write-Host "Creating .gitignore file..." -ForegroundColor Yellow
    @"
# Build and release directories
bin/
Debug/
Release/
obj/

# Visual Studio cache/options
.vs/
*.user
*.suo
*.sln.docstates
.vscode/

# Local environment variables
.env
.env.local

# Log files
*.log
logs/

# OS files
.DS_Store
Thumbs.db

# Dependencies
node_modules/
packages/

# Test results
TestResults/

# IDE
*.swp
*.swo
*~
"@ | Out-File -Encoding UTF8 .gitignore
    Write-Host ".gitignore created" -ForegroundColor Green
    Write-Host ""
}

# Add all files
Write-Host "Adding files to git..." -ForegroundColor Yellow
git add -A
Write-Host "Files staged for commit" -ForegroundColor Green
Write-Host ""

# Show status
Write-Host "Git status:" -ForegroundColor Yellow
git status
Write-Host ""

# Commit changes
Write-Host "Committing changes..." -ForegroundColor Yellow
git commit -m "$CommitMessage" 2>&1 | Out-Host
if ($LASTEXITCODE -eq 0) {
    Write-Host "Commit successful" -ForegroundColor Green
}
else {
    Write-Host "Note: No new changes to commit or commit failed (Check git status above)" -ForegroundColor Yellow
}
Write-Host ""

# Check for remote
$remotes = git remote
if (-not ($remotes -contains "origin")) {
    Write-Host "Setting up GitHub remote..." -ForegroundColor Yellow
    Write-Host "Enter your GitHub repository URL: " -NoNewline
    $repoUrl = Read-Host
    git remote add origin $repoUrl
    Write-Host "Remote 'origin' added: $repoUrl" -ForegroundColor Green
}
else {
    Write-Host "Remote 'origin' already configured:" -ForegroundColor Green
    git remote get-url origin
}
Write-Host ""

# Setup main branch
Write-Host "Setting up main branch..." -ForegroundColor Yellow
$currentBranch = git symbolic-ref --short HEAD 2>$null
if ([string]::IsNullOrEmpty($currentBranch)) {
    Write-Host "Creating and checking out main branch..." -ForegroundColor Cyan
    git checkout -b main
}
elseif ($currentBranch -ne "main") {
    Write-Host "Current branch: $currentBranch, renaming to main..." -ForegroundColor Cyan
    git branch -M main
}
Write-Host "Current branch: $(git symbolic-ref --short HEAD)" -ForegroundColor Green
Write-Host ""

# Push to GitHub
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
$currentBranch = git symbolic-ref --short HEAD
git push -u origin $currentBranch 2>&1 | Out-Host
if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully pushed to GitHub on branch '$currentBranch'" -ForegroundColor Green
    Write-Host ""
    Write-Host "Repository is now available at:" -ForegroundColor Cyan
    git remote get-url origin
}
else {
    Write-Host "Push failed. You may need to:" -ForegroundColor Yellow
    Write-Host "1. Ensure your GitHub repository exists" -ForegroundColor Yellow
    Write-Host "2. Check your GitHub credentials and authentication" -ForegroundColor Yellow
    Write-Host "3. Try: git push -u origin $currentBranch --force (use with caution)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "GitHub commit process completed" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
