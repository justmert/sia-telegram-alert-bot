#!/bin/bash

# Improved error handling
set -euo pipefail

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

# Ask for API URL with default value
read -p "Enter the Sia API URL [default: localhost:9980]: " api_url
api_url=${api_url:-localhost:9980}

# Securely get the password before testing if the app is running
read -s -p "Provide password for $app_type: " PASSWORD
echo

# Function to check if Sia app is running by accessing its endpoint
function check_sia_endpoint() {
    if curl -s -u ":$PASSWORD" --head --request GET "http://$api_url/api/alerts" | grep "200 OK" > /dev/null; then
        echo "✓ Sia $app_type is running."
    else
        echo "Error: Unable to reach Sia $app_type at $api_url. Please check if it is running."
        exit 1
    fi
}

# Check if Sia app is running
check_sia_endpoint

# Get the unique ID from the user
read -p "Enter your unique id (get from t.me/sia_alert_bot): " unique_id

# Create the JSON data for the curl request based on app type
if [ "$app_type" == "Hostd" ]; then
    json_data='{
        "scopes": ["alerts.info", "alerts.warning", "alerts.error", "alerts.critical"],
        "callbackURL": "http://www.sia-alert-bot.com:8006/alerts?unique_id='$unique_id'&app_type='$app_type'"
    }'
    api_endpoint="/api/webhooks"
else
    json_data='{
        "module": "alerts",
        "event": "register",
        "url": "http://www.sia-alert-bot.com:8006/alerts?unique_id='$unique_id'&app_type='$app_type'"
    }'
    api_endpoint="/api/bus/webhooks"
fi

# Make the curl request and capture the response
response=$(curl -s -w "%{http_code}" --location "http://$api_url$api_endpoint" \
  --data "$json_data" -u ":$PASSWORD" --header 'Content-Type: application/json')

echo $response
# Extract the HTTP status code from the response
http_status="${response: -3}"

# Check if the request was successful (status code 200)
if [ "$http_status" == "200" ]; then
  echo "Webhook installed successfully."
else
  echo "Error: Webhook installation failed. HTTP Status Code: $http_status"
fi
