#!/bin/bash

# Improved error handling
set -euo pipefail

echo "⭐ Test your setup, and see if it is running successfully"

# Function to display the initial menu and get user choice
echo "Which Sia application would you like to test?"
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
read -s -p "Provide the password: " PASSWORD
echo # New line for clean output

# Function to check if Sia app is running by accessing its endpoint
function check_sia_endpoint() {
    if curl -s -u ":$PASSWORD" --head --request GET "http://$api_url/api/alerts" | grep "200 OK" > /dev/null; then
        echo "Sia $app_type is running."
    else
        echo "Error: Unable to reach Sia $app_type at $api_url. Please check if it is running."
        exit 1
    fi
}

# Check if Sia app is running
check_sia_endpoint

# Create a JSON payload for registering an alert
alert_payload='{
    "id": "h:804f827c66292c17c6388aecf3a98bc25c09c32ddefc289e754899bf0e93f78b",
    "severity": "info",
    "message": "Testing integration",
    "data": {
        "detail": "You are good to go!"
    },
    "timestamp": "2023-08-30T12:20:49.611086295Z"
}'

# Set the appropriate API endpoint based on the app type
api_endpoint=$([ "$app_type" == "Renterd" ] && echo "/api/bus/alerts/register" || echo "/api/alerts/register")

# Make a curl request to register an alert
response=$(curl -s -w "\n%{http_code}" --location "http://$api_url$api_endpoint" \
--header "Content-Type: application/json" \
--request POST \
--data "$alert_payload" -u ":$PASSWORD")

# Extract the HTTP status code from the response
http_status=$(echo "$response" | tail -n1)

# Check if the alert registration was successful (status code 200)
if [ "$http_status" == "200" ]; then
    echo "Alert registered successfully."

    # Ask the user if they have received a telegram message from t.me/sia_alert_bot
    read -p "Have you received a telegram message from t.me/sia_alert_bot? (yes/no): " received_telegram
    case "$received_telegram" in
        [Yy]|[Yy][Ee][Ss])
            echo "Great! Your setup appears to be working as expected."
            exit 0
            ;;
        *)
            echo "Your setup may be broken. Please run the installation script."
            exit 1
            ;;  
    esac
else
    echo "Error: Alert registration failed. HTTP Status Code: $http_status"
fi
