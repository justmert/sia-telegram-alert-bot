#!/bin/bash

SERVER_URL="https://www.sia-alert-bot.com"

# Print a message to test the setup
echo "⭐ Test your setup, and see if it is running successfully"

# Ask the user if the Sia app is running
while true; do
    read -p "Is the Sia app running? (yes/y): " is_running
    case "$is_running" in
        [Yy]|[Yy][Ee][Ss])
            break
            ;;
        *)
            echo "Please answer with yes or y."
            ;;
    esac
done


# Ask the user for the password
read -s -p "Provide the password: " PASSWORD
echo # New line for clean output

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

# Make a curl request to register an alert
response=$(curl -s -w "\n%{http_code}" --location "http://localhost:9980/api/bus/alerts/register" \
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
