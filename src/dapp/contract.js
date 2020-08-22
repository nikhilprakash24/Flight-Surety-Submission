import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json'; //we shouldn't need to interact directly with the data contract
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];

        //this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        //replaced w/ this to inject MetaMask
        if (window.ethereum) {
            // use metamask's providers
            // modern browsers
            console.log("Modern Browser");
            this.web3 = new Web3(window.ethereum)
            // Request accounts access
            try {
              window.ethereum.enable()
            } catch (error) {
              console.error('User denied access to accounts')
            }
          } else if (window.web3) {
            // legacy browsers
            console.log("Legacy Browsers");
            this.web3 = new Web3(web3.currentProvider)
          } else {
            // fallback for non dapp browsers
            this.web3 = new Web3(new Web3.providers.HttpProvider(config.url))
          }

        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];

        this.oracles = [];

        const STATUS_CODE_UNKNOWN = 0;
        const STATUS_CODE_ON_TIME = 10;
        const STATUS_CODE_LATE_AIRLINE = 20; //only one to trigger credit => payout
        const STATUS_CODE_LATE_WEATHER = 30;
        const STATUS_CODE_LATE_TECHNICAL = 40;
        const STATUS_CODE_LATE_OTHER = 50;
        const STATUS_CODE_CAN_BUY_INSURANCE = 200; //We may not use this...
    
        const REGISTERING_AIRLINE_NEEDS_CONSENSUS = 5; //can be UINT8
        const AIRLINE_DEPOSIT_REQUIRED = 10; //ether
        const MAX_INSURANCE_PREMIUM = 1; //ether
        const INSURANCE_PAYOUT_MULTIPLIER_NUMERATOR = 15; //b/c  no decimals NEED to use two numbers to achieve decimals
        const INSURANCE_PAYOUT_MULTIPLIER_DENOMINATOR = 10;
        const ORACLE_REG_FEE = 1; //ether
        const MIN_NO_OF_ORACLE_RESPONSES = 3; //can be UINT8
    
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    checkNumAirlines(callback) {
        let self = this;
        self.flightSuretyApp.methods
             .checkNumAirlines()
             .call({ from: self.owner}, callback);
     }

     testFlagVariable(callback) {
        let self = this;
        self.flightSuretyApp.methods
             .testFlagVariable()
             .call({ from: self.owner}, callback);
    }

    testFlagBool(callback) {
        let self = this;
        self.flightSuretyApp.methods
             .testFlagBool()
             .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    listAirline(_airlineAddress) {
        let self = this;
        self.flightSuretyApp.methods    
            .listAirline(_airlineAddress)
            .send({from: _airlineAddress}, (error, result) => {

            });
        
    }

    registerAirline(_airlineAddress) {
        let self = this;
        self.flightSuretyApp.methods    
            .registerAirline(_airlineAddress)
            .send({from: _airlineAddress}, (error, result) => {

            });
        
    }

    fundAirline() {

    }

    buy() {


    }

    claim() {

    }

    withdraw() {

    }

    getPassengerCredit() {


    }

    getPassengerBalance() {


    }
}