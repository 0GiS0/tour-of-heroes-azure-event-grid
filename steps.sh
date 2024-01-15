# Variables
RESOURCE_GROUP="event-grid-demos"
LOCATION="westeurope"
EVENT_GRID_TOPIC="heroes-events"
EVENT_GRID_SUBSCRIPTION="heroes-subscription"
STORAGE_ACCOUNT_NAME="storeheroes"
STORAGE_CONTAINER_NAME="pics"

NGROK_ENDPOINT="https://anteater-alive-gratefully.ngrok-free.app/webhook"

# Install dependencies
npm install

# Start webhook
node 00-webhook.js

# https://dashboard.ngrok.com/get-started/your-authtoken
ngrok config add-authtoken <YOUR_TOKEN>

# Start ngrok
ngrok http --domain=anteater-alive-gratefully.ngrok-free.app 3000


# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

##########################################################################################
############################### Azure Services Events ####################################
##########################################################################################

# Azure Service Events
STORAGE_RESOURCE_ID=$(az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --kind StorageV2 \
    --query "id" \
    --output tsv)

STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)

# Create a container
az storage container create \
--name $STORAGE_CONTAINER_NAME \
--account-name $STORAGE_ACCOUNT_NAME \
--account-key $STORAGE_ACCOUNT_KEY

# Subscribe to Azure Storage Events (Blob Created and Deleted)
az eventgrid event-subscription create \
    --name $EVENT_GRID_SUBSCRIPTION \
    --source-resource-id $STORAGE_RESOURCE_ID \
    --endpoint-type webhook \
    --endpoint $NGROK_ENDPOINT

# Upload a file to the container
az storage blob upload \
    --container-name $STORAGE_CONTAINER_NAME \
    --file ./pics/arrow.jpeg \
    --name arrow.jpeg \
    --account-name $STORAGE_ACCOUNT_NAME

# Delete a file from the container
az storage blob delete \
--container-name $STORAGE_CONTAINER_NAME \
--name arrow.jpeg \
--account-name $STORAGE_ACCOUNT_NAME \
--account-key $STORAGE_ACCOUNT_KEY

##########################################################################################
###################################### Custom Events #####################################
##########################################################################################


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

# Send a custom event to the topic
EVENT_GRID_KEY=$(az eventgrid topic key list --name $EVENT_GRID_TOPIC -g $RESOURCE_GROUP --query "key1" --output tsv)
EVENT_GRID_ENDPOINT=$(az eventgrid topic show --name $EVENT_GRID_TOPIC -g $RESOURCE_GROUP --query "endpoint" --output tsv)

EVENT='[ {"id": "'"$RANDOM"'", "eventType": "recordInserted", "subject": "myapp/heroes/gotham", "eventTime": "'`date +%Y-%m-%dT%H:%M:%S%z`'", "data":{ "hero": "Batman", "genre": "male"},"dataVersion": "1.0"} ]'

curl -X POST -H "aeg-sas-key: $EVENT_GRID_KEY" -d "$EVENT" $EVENT_GRID_ENDPOINT

###########################################################################################
###################################### MQTT ###############################################
###########################################################################################

# The Azure Event Grid MQTT broker feature supports messaging by using the MQTT protocol. 
# Clients (both devices and cloud applications) can publish and subscribe to MQTT messages over flexible hierarchical topics for scenarios such as high-scale broadcast and command and control

EVENT_GRID_MQTT_NS="event-grid-mqtt-ns"

# Create Event Grid MQTT Namespace
az eventgrid namespace create \
-g $RESOURCE_GROUP \
-n $EVENT_GRID_MQTT_NS \
--topic-spaces-configuration "{state:Enabled}"

# Create a sample client certificate with step

# 1. To create root and intermediate certificates, run the following command
step ca init --deployment-type standalone \
--name MqttAppSamplesCA \
--dns localhost \
--address 127.0.0.1:443 \
--provisioner MqttAppSamplesCAProvisioner

# Generated password: yhHcz:e=_]CWW87S'krW'zZR(,saFiy~

# 2. Use the certificate authority (CA) files generated to create a certificate for the client
step certificate create client1-authnID client1-authnID.pem \
client1-authnID.key --ca /home/node/.step/certs/intermediate_ca.crt \
--ca-key /home/node/.step/secrets/intermediate_ca_key \
--no-password --insecure --not-after 2400h

# 3. To view the thumbprint, run the step command.
THUMBPRINT=$(step certificate fingerprint client1-authnID.pem)

# Create client
az eventgrid namespace client create \
-g $RESOURCE_GROUP \
--namespace-name $EVENT_GRID_MQTT_NS \
-n batmovil \
--authentication-name client1-authnID \
--client-certificate-authentication "{validationScheme:ThumbprintMatch,allowed-thumbprints:[$THUMBPRINT]}"

# Create topic space
az eventgrid namespace topic-space create \
-g $RESOURCE_GROUP \
--namespace-name $EVENT_GRID_MQTT_NS \
-n "autoslocos" \
--topic-templates ['heroes/gotham']

# Create permission bindings
az eventgrid namespace permission-binding create \
-g $RESOURCE_GROUP \
--namespace-name $EVENT_GRID_MQTT_NS \
-n publishers \
--client-group-name '$all' \
--permission publisher --topic-space-name "autoslocos"

az eventgrid namespace permission-binding create \
-g $RESOURCE_GROUP \
--namespace-name $EVENT_GRID_MQTT_NS \
-n subscribers \
--client-group-name '$all' \
--permission subscriber \
--topic-space-name "autoslocos"

# Send messages to heroes/gotham
cd client
dotnet run

# https://github.com/Azure-Samples/MqttApplicationSamples

time az group delete -n $RESOURCE_GROUP --yes


# https://learn.microsoft.com/en-us/azure/event-grid/quotas-limits