#!/bin/bash

# Improved error handling
set -euo pipefail

# Server URL
SERVER_URL="https://66fc-176-41-28-148.ngrok-free.app"

# Function to display the initial menu and get user choice

echo "⭐ Welcome to Sia Renterd/Hostd Telegram Bot! Which application do you want to register alerts?"
echo "1. Renterd"
echo "2. Hostd"
while true; do
read -p "Enter your choice (1/2): " app_choice
case "$app_choice" in
    1|2) break;;
    *) echo "Invalid choice. Please select either 1 or 2.";;
esac
done

# Set the app_type based on the user's choice
app_type=$([ "$app_choice" == "1" ] && echo "Renterd" || echo "Hostd")

# Function to check if Sia app is running
function is_sia_running() {
  while true; do
    read -p "Sia $app_type must be running since we require its API to set up webhooks. Is $app_type running? (yes/y): " is_running
    case "$is_running" in
      [Yy]*)
        return 0;;
      *)
        echo "Please answer with yes or y."
    esac
  done
}

# Check if Sia app is running
is_sia_running

# Get the unique ID from the user
read -p "Enter your unique id (get from t.me/sia_alert_bot): " unique_id

# Securely get the password
read -s -p "Provide password for $app_type: " PASSWORD
echo

# Create the JSON data for the curl request
# Create the JSON data for the curl request
json_data='{
    "module": "alerts",
    "event": "register",
    "url": "'"$SERVER_URL/alerts?unique_id=$unique_id&app_type=$app_type"'"
}'

# Make the curl request and capture the response
response=$(curl -s -w "%{http_code}" --location "localhost:9980/api/bus/webhooks" \
  --data "$json_data" -u ":$PASSWORD")

# Extract the HTTP status code from the response
http_status="${response: -3}"

# Check if the request was successful (status code 200)
if [ "$http_status" == "200" ]; then
  echo "Webhook installed successfully."
else
  echo "Error: Webhook installation failed. HTTP Status Code: $http_status"
fi
