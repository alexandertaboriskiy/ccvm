#!/bin/bash
# Set up a GCP budget alert that emails you when spending hits thresholds.
#
# Usage:
#   bash setup-budget-alert.sh
#   BUDGET=50 EMAIL=me@example.com bash setup-budget-alert.sh
set -euo pipefail

PROJECT="${PROJECT:-my-project}"
BUDGET="${BUDGET:-30}"
CURRENCY="${CURRENCY:-CHF}"
EMAIL="${EMAIL:-}"

if [ -z "$EMAIL" ]; then
  echo "EMAIL is required. Usage: EMAIL=you@example.com bash setup-budget-alert.sh"
  exit 1
fi

echo "=== Setting up budget alert ==="
echo "Project:  $PROJECT"
echo "Budget:   $BUDGET $CURRENCY"
echo "Email:    $EMAIL"
echo ""

# Enable monitoring API
gcloud services enable monitoring.googleapis.com --project="$PROJECT"

# Create notification channel
CHANNEL_ID=$(gcloud beta monitoring channels create \
  --display-name="budget-alert-email" \
  --type=email \
  --channel-labels=email_address="$EMAIL" \
  --project="$PROJECT" \
  --format="value(name)" 2>&1 | grep notificationChannels)

echo "Created notification channel: $CHANNEL_ID"

# Get billing account
BILLING_ACCOUNT=$(gcloud billing projects describe "$PROJECT" --format="value(billingAccountName)" | sed 's|billingAccounts/||')
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format="value(projectNumber)")

echo "Billing account: $BILLING_ACCOUNT"

# Create budget with thresholds at 50%, 90%, 100%
gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT" \
  --display-name="${PROJECT}-${BUDGET}${CURRENCY}-budget" \
  --budget-amount="${BUDGET}${CURRENCY}" \
  --filter-projects="projects/$PROJECT_NUMBER" \
  --threshold-rule=percent=0.5,basis=current-spend \
  --threshold-rule=percent=0.9,basis=current-spend \
  --threshold-rule=percent=1.0,basis=current-spend \
  --notifications-rule-monitoring-notification-channels="$CHANNEL_ID"

echo ""
echo "=== Budget alert created ==="
echo "You'll receive emails at $EMAIL when spending hits:"
echo "  50% = $((BUDGET / 2)) $CURRENCY"
echo "  90% = $((BUDGET * 9 / 10)) $CURRENCY"
echo "  100% = $BUDGET $CURRENCY"
