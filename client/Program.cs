using MQTTnet.Client;
using MQTTnet;
using System.Security.Cryptography.X509Certificates;

string hostname = "event-grid-mqtt-ns.westeurope-1.ts.eventgrid.azure.net";
string clientId = "client1-session1";  //client ID can be the session identifier.  A client can have multiple sessions using username and clientId.
string x509_pem = @"../client1-authnID.pem";  //Provide your client certificate .cer.pem file path
string x509_key = @"../client1-authnID.key";  //Provide your client certificate .key.pem file path

var certificate = new X509Certificate2(X509Certificate2.CreateFromPemFile(x509_pem, x509_key).Export(X509ContentType.Pkcs12));

var mqttClient = new MqttFactory().CreateMqttClient();

var connAck = await mqttClient!.ConnectAsync(new MqttClientOptionsBuilder()
    .WithTcpServer(hostname, 8883)
    .WithClientId(clientId)
    .WithCredentials("client1-authnID", "")  //use client authentication name in the username
    .WithTls(new MqttClientOptionsBuilderTlsParameters()
    {
        UseTls = true,
        Certificates = new X509Certificate2Collection(certificate)
    })

    .Build());

Console.WriteLine($"Client Connected: {mqttClient.IsConnected} with CONNACK: {connAck.ResultCode}");

mqttClient.ApplicationMessageReceivedAsync += async m => await Console.Out.WriteAsync($"Received message on topic: '{m.ApplicationMessage.Topic}' with content: '{m.ApplicationMessage.ConvertPayloadToString()}'\n\n");

var suback = await mqttClient.SubscribeAsync("heroes/gotham");
suback.Items.ToList().ForEach(s => Console.WriteLine($"subscribed to '{s.TopicFilter.Topic}' with '{s.ResultCode}'"));

var counter = 0;

while (true)
{
    var puback = await mqttClient.PublishStringAsync("heroes/gotham", $"hello world #{counter}!");
    Console.WriteLine(puback.ReasonString);
    await Task.Delay(5000);

    counter++;

}