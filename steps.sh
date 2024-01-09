# Variables
RESOURCE_GROUP="event-grid-demos"
LOCATION="westeurope"
EVENT_GRID_TOPIC="heroes-events"
EVENT_GRID_SUBSCRIPTION="heroes-subscription"
STORAGE_ACCOUNT_NAME="storeheroes"
STORAGE_CONTAINER_NAME="pics"

NGROK_ENDPOINT="https://fcd8-89-7-164-45.ngrok-free.app/webhook"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Azure Service Events
STORAGE_RESOURCE_ID=$(az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --kind StorageV2 \
    --query "id" \
    --output tsv)

# Create a container
az storage container create \
    --name $STORAGE_CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT_NAME \
    --public-access blob

# Subscribe to Azure Storage Events
az eventgrid event-subscription create \
    --name $EVENT_GRID_SUBSCRIPTION \
    --source-resource-id $STORAGE_RESOURCE_ID \
    --endpoint-type webhook \
    --endpoint $NGROK_ENDPOINT


# Create Event Grid Topic
az eventgrid topic create \
--name $EVENT_GRID_TOPIC \
--resource-group $RESOURCE_GROUP \
--location $LOCATION

# Get topic resource id
TOPIC_RESOURCE_ID=$(az eventgrid topic show \
--name $EVENT_GRID_TOPIC \
--resource-group $RESOURCE_GROUP \
--query id \
--output tsv)

# Create Event Grid Subscription
az eventgrid event-subscription create \
    --name $EVENT_GRID_SUBSCRIPTION \
    --source-resource-id $TOPIC_RESOURCE_ID \
    --endpoint-type webhook \
    --endpoint $NGROK_ENDPOINT

az eventgrid event-subscription create \
    --name $EVENT_GRID_SUBSCRIPTION-2 \
    --source-resource-id $TOPIC_RESOURCE_ID \
    --endpoint-type webhook \
    --endpoint $NGROK_ENDPOINT

# Send a custom event to the topic

EVENT_GRID_KEY=$(az eventgrid topic key list --name $EVENT_GRID_TOPIC -g $RESOURCE_GROUP --query "key1" --output tsv)
EVENT_GRID_ENDPOINT=$(az eventgrid topic show --name $EVENT_GRID_TOPIC -g $RESOURCE_GROUP --query "endpoint" --output tsv)

EVENT='[ {"id": "'"$RANDOM"'", "eventType": "recordInserted", "subject": "myapp/heroes/gotham", "eventTime": "'`date +%Y-%m-%dT%H:%M:%S%z`'", "data":{ "hero": "Batman", "genre": "male"},"dataVersion": "1.0"} ]'

curl -X POST -H "aeg-sas-key: $EVENT_GRID_KEY" -d "$EVENT" $EVENT_GRID_ENDPOINT

# https://learn.microsoft.com/en-us/azure/event-grid/quotas-limits