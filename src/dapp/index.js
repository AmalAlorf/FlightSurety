import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        contract.flightSuretyApp.events.FlightStatusInfo({

        }, function(error, result) {
            if (error) console.log(error)
            else {
                display('Oracles', 'Trigger oracles', [{ label: 'Fetch Flight Status', error: error, value: result + ' ' + result.args.flight + ' ' + result.args.timestamp }]);

            }
        });
        // Read transaction
        contract.isOperational((error, result) => {
            display('Operational Status', 'Check if contract is operational', [{ label: 'Operational Status', error: error, value: result }]);
        });

        // purchase insurance for flight
        DOM.elid('purchase-insurance').addEventListener('click', () => {
                let airline = DOM.elid('insuredAirline').value;
                let flight = DOM.elid('flightNumber').value;
                let funds_ether = DOM.elid('fundInsurance').value;
                let passenger = DOM.elid('passengers').value;
                let ts = DOM.elid('datepicker').value;
                console.log("ts:" + ts);
                let timestamp = new Date(ts).getTime() / 1000;
                console.log("timestamp:" + timestamp);
                // Write transaction
                contract.purchaseInsurance(airline, flight, passenger, funds_ether, timestamp, (error, result) => {

                    display('Insurance', 'Purchase Insurance', [{ label: 'Purchase Insurance', error: error, value: result }]);
                });
            })
            // withdraw balance for flight
        DOM.elid('withdrawFunds').addEventListener('click', () => {
            let funds = DOM.elid('withdraw_Amount').value;
            let passenger = DOM.elid('insuredPassengers').value;
            contract.withdrawFunds(passenger, funds, (error, result) => {

                display('Withdraw', 'Withdraw Funds', [{ label: 'Withdraw Funds', error: error, value: result }]);
            });
        })


        DOM.elid('insuredAirline').addEventListener('change', () => {
            let airline = DOM.elid('insuredAirline').value;
            let airlineName = contract.airlines[airline]
            let flights = contract.flights[airlineName];
            populateFlights(flights, 'flightNumber');

        })

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flightNumber').value;
            let airline = DOM.elid('airlineStatus').value;
            let ts = DOM.elid('statusdatepicker').value;
            let timestamp = new Date(ts).getTime() / 1000;
            // Write transaction
            contract.fetchFlightStatus(airline, flight, timestamp, (error, result) => {
                display('Oracles', 'Trigger oracles', [{ label: 'Fetch Flight Status', error: error, value: result }]);


            });
        })


    });


})();

function populateFlights(flights, elid) {
    var list = document.getElementById(elid);
    list.innerHTML = "";
    flights.forEach((flight) => {
        var option = document.createElement("option");
        option.text = flight;
        list.add(option);

    })
}

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");

    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({ className: 'row' }));
        row.appendChild(DOM.div({ className: 'col-sm-4 field' }, result.label));
        row.appendChild(DOM.div({ className: 'col-sm-8 field-value' }, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}