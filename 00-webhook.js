const express = require('express');
const bodyParser = require('body-parser');

const app = express();

app.use(bodyParser.json());

app.post('/webhook', (req, res) => {

    var json = req.body[0];

    switch (json.eventType) {

        case 'Microsoft.EventGrid.SubscriptionValidationEvent':
            console.log('Validation event ✅ received');
            console.log(req.body);

            res.send({
                "validationResponse": json.data.validationCode
            });

            break;

        default:
            console.log('Event received');
            console.log(json);
            res.sendStatus(200);
            break;

    }

});

const port = 3000;
app.listen(port, () => console.log(`Webhook server is listening on port ${port}`));