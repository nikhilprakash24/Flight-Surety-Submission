
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // READS/VIEWS
        //EXAMPLE GIVEN
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        contract.checkNumAirlines((error, result) => {
            console.log(error,result);
            display('Number of Registered Airlines', 'Check how many airlines are registred', [ { label: 'Number of Registered Airlines', error: error, value: result} ]);
        });

        contract.testFlagVariable((error, result) => {
            console.log(error,result);
            display('The Test No.', 'The Test No. is presently:', [ { label: 'The Test No.', error: error, value: result} ]);
        });

        contract.testFlagBool((error, result) => {
            console.log(error,result);
            display('The Test Bool', 'The Test Bool is presently:', [ { label: 'The Test Bool', error: error, value: result} ]);
        });
    
        // //LIST FLIGHT FUNCTION
        // DOM.elid('list-airline').addEventListener('click', () => {
        //     let airline = DOM.elid('list-airline-address').value;
        //     // Write transaction
        //     contract.listAirline(airline, (error, result) => {
        //         display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
        //     });
        // })

        //REGISTER FLIGHT FUNCTION
        DOM.elid('register-airline').addEventListener('click', () => {
            let airline = DOM.elid('reg-airline-address').value;
            // Write transaction
            contract.registerAirline(airline, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // EXAMPLE GIVEN
        // // User-submitted transaction
        // DOM.elid('submit-oracle').addEventListener('click', () => {
        //     let flight = DOM.elid('flight-number').value;
        //     // Write transaction
        //     contract.fetchFlightStatus(flight, (error, result) => {
        //         display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
        //     });
        // })
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







