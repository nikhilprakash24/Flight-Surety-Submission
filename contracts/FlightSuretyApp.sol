pragma solidity ^0.4.25;
//pragma solidity ^0.5.2;


//Note: This contract should be deployed after the data contract and so this contract
//need to capture the data contracts address and link to it.


// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol"; 

//NOTE: FUNDS are held in this contract (the app contract) as a design choice (for simplicity)

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20; //only one to trigger credit => payout
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    uint8 private constant STATUS_CODE_CAN_BUY_INSURANCE = 200; //We may not use this...

    uint256 private constant REGISTERING_AIRLINE_NEEDS_CONSENSUS = 5; //can be UINT8
    uint256 private constant AIRLINE_DEPOSIT_REQUIRED = 10 ether;
    uint256 private constant MAX_INSURANCE_PREMIUM = 1 ether;
    uint256 private constant INSURANCE_PAYOUT_MULTIPLIER_NUMERATOR = 15; //b/c  no decimals NEED to use two numbers to achieve decimals
    uint256 private constant INSURANCE_PAYOUT_MULTIPLIER_DENOMINATOR = 10;
    uint256 private constant ORACLE_REG_FEE = 1 ether;
    uint256 private constant MIN_NO_OF_ORACLE_RESPONSES = 3; //can be UINT8

    FlightSuretyData flightSuretyData; // 'flightSuretyData' is the 'data contract object' we will be working with in throught this app contract

    address private contractOwner;          // Account used to deploy contract

    uint256 public testFlagVariable = 0;
    bool public testFlagBool = false;
    //Flight[] private allFlights;

    
    /********************************************************************************************/
    /*                                       EVENTS                                     */
    /********************************************************************************************/

    //Airline State Change Events
    event AirlineListed(address indexed airline);
    event AirlineRegistered(address indexed airline);
    event AirlineFunded(address indexed airline);

    //Airline Actions Events
    event AirlineVotedFor(address indexed airline, uint256 votesFor, uint256 votesNeeded);
    event AirlineFundsPaid(address indexed airline, uint256 deposit);

    //Passenger Actions
    event InsuranceBought(address indexed passenger, string flight, uint256 amount);

    event flightDelayedDueToAirline(string flight, address indexed airline);
    event insurancePaidOut(string flight, address indexed airline);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    *  Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
         // Modify to call data contract's status
        require(isOperational() == true, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    *  Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require((msg.sender == contractOwner) || (msg.sender == address(this)), "Caller is not contract owner"); 
        //address(this) b/c of constructor logic
        _;
    }

    /**
    *  Modifier that requires the called to be a "registered airline"
    */
    modifier requireRegisteredAirline()
    {

        // ***** require(airlines[msg.sender].isRegistered == true, "Caller is not registered airline");

        _;
    }

    modifier requireRegisteredAndFundedAirline()
    {

        // ***** require(airlines[msg.sender].isRegistered == true, "Caller is not registered airline");

        // ***** require(airlines[msg.sender].isFunded == true, "Caller is not (fully) funded airline");

        _;
    }


    modifier belowMinInsurancePurchaseVal()
    {
        require(msg.value <= 1 ether, "Max value of insurance is 1 Eth"); //can only buy insurance < 1.5eth
        _;
    }


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    *  Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                )
                                public
    {
        contractOwner = msg.sender; //move to data contract
        flightSuretyData = FlightSuretyData(dataContract);

        setOperatingStatus(true); 
        testFlagVariable = testFlagVariable.add(1);
        _listAirline(msg.sender);
        _registerAirline(msg.sender);

        // //could call registerAirline() but that would be from this contract? so...
        // airlines[msg.sender].isRegistered = true;
        // airlines[msg.sender].isFunded = true; // b/c it needs to be able to register other airlines right away
        // //emit airline registered event here [if doing so]
        // numRegisteredAirlines = numRegisteredAirlines.add(1);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational
                            (
                            )
                            public
                            returns(bool)
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function setOperatingStatus
                            (
                                bool _operationalStatus
                            )
                            public
                            requireContractOwner
                            returns(bool)
    {
        flightSuretyData.setOperatingStatus(_operationalStatus);
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }


   /**
    *  Add an airline to the registration queue
    *
    */
    function registerAirline
                            (
                                address _airline
                            )
                            public //so we will need to call another private function that has the actual call to the data contract
                            //requireRegisteredAndFundedAirline
                            requireIsOperational
                            returns(bool success, uint256 votes)
    {
        //check and see if the airline is unlisted, if not then list the airline
        uint256 status = uint256(flightSuretyData.checkAirlineStatus(_airline));
        if(status == 0){
            _listAirline(_airline);
        }
        //get # of airlines registered
        uint256 numAirlinesRegistered = flightSuretyData.checkNumAirlines();

        //the 1st - 4th airline can register w/o multi-party consensus
        if(numAirlinesRegistered < 4){
            _registerAirline(_airline);
            //EVENT of Airline Reg
            emit AirlineRegistered(_airline);
            return(true, 0);
        }

        //else we are in multi-party consensus and so we will return false
        //because the airline was listed and not registered w/ 0 votes - unnecessary 
        //but I initally was going to cast the first vote in this function of trying to register
        return(false,0); 

    }


    /**
    *  Vote (YES) to add an airline to the registration queue (multiparty consensus)
    *
    */
     function voteToRegisterAirline
                            (
                                address _airline
                            )
                            public
                            requireRegisteredAndFundedAirline
                            requireIsOperational
                            returns(bool voteSuccessful, uint256 votes)
    {
        uint256 status = uint256(flightSuretyData.checkAirlineStatus(_airline));
        if(status == 1){
            //then the airline is listed and accpeting votes
            //get # of airlines registered b/c logic is set at 50% consensus needed (for now) of registered airlines
            uint256 numAirlinesRegistered = flightSuretyData.checkNumAirlines();
            //vote...
            uint256 numVotesNeeded = numAirlinesRegistered.div(2); //***Is div is good in safemath with ROUND DOWN??
            uint256 curentVotesTotal = flightSuretyData.voteForAirlineReg(msg.sender, _airline);

            if(curentVotesTotal >= numVotesNeeded){
                _registerAirline(_airline);
                emit AirlineRegistered(_airline);
                return(true, curentVotesTotal);
            }

            emit AirlineVotedFor(_airline, curentVotesTotal, numVotesNeeded);

            return(true, curentVotesTotal);
        }

        else {
            return(false, 0); //not accepting votes b/c already registered or not listed yet
        }

    }

    function checkNumAirlines
                            (

                            )
                            public
                            view
                            returns(uint256 _numAirlinesRegistered)
    {
        return(flightSuretyData.checkNumAirlines());
    }


    /**
    * :Fund the airline to get to the 'isFunded' status which allows full participations (10 ether min.)
    *
    */
    function fund
                            (
                            )
                            external
                            payable
                            requireRegisteredAirline
                            requireIsOperational
                            returns(bool successfullyFundedEnough, uint256 amountFundedSoFar)
    {
        //check if in the registered or funded state
        uint256 status = uint256(flightSuretyData.checkAirlineStatus(msg.sender));
        if(status == 2){
            _fund(msg.sender, msg.value);

            //how much has this airline funded so far
            uint256 amountFunded = flightSuretyData.checkAirlineFunds(msg.sender);

            //check if > funding threshold (currently set at 10 ether)
            if(amountFunded >= 10 ether) {
                //if yes then call function that changes airlines state
                flightSuretyData.fundStatusUpdate(msg.sender);
                emit AirlineFunded(msg.sender);
                return(true, amountFunded);
            }

            //else
            return(false, amountFunded); //i.e. not past the fund threshold (of 10 ether) yet 
        }

        else if(status == 3){
            _fund(msg.sender, msg.value);
            uint256 _amountFunded = flightSuretyData.checkAirlineFunds(msg.sender);
            return(true, _amountFunded);
        }


    }


   /**
    *  Register a future flight for insuring.
    *
    */
    //Note: Intended to be triggered from the UI (button on the client dapp)
    //Alternate Option: Hardcoded list of flights
    function registerFlight
                                (
                                    string _flight,
                                    uint256 _timestamp
                                )
                                external
                                requireRegisteredAndFundedAirline
                                requireIsOperational
    {
            bytes32 flightKey = keccak256(abi.encodePacked(msg.sender, _flight, _timestamp));
            flightSuretyData.registerFlight(flightKey, _timestamp, msg.sender);
    }

   /**
    *  Called after oracle has updated flight status
    *
    */
    //key function - is triggered when the oracle has come back with the result and this
    //function directs action from that point onwards
    //most likely only want to react to Status Code 20...
    //then look for passengers (anyone right b/c we are not simulating who is a passenger on which flight)
    //who have purchased insurance for that particular flight and start the credit + payout calc.

    //the 'submitOracleResponse()' function calls this internal function
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal       
                                requireIsOperational                         
    {
        bytes32 _flightKey = keccak256(abi.encodePacked(airline, flight, timestamp));
        if(statusCode == STATUS_CODE_LATE_AIRLINE){
            //then credit the passengers with insurance
            _creditInsurees(_flightKey, flight, airline);
        }
    }


    // Generate a request for oracles to fetch flight information
    //Note: Intended to be triggered from the UI (button on the client dapp)
    //Function has been completed. Can be addded to or optimized as needed.
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


//Passenger
    function buyInsurance
                                (
                                    string flight, //ignore the warning...
                                    address airlineID,
                                    uint256 timestamp
                                )
                                external
                                payable
                                belowMinInsurancePurchaseVal
                                returns(bool success, uint256 _currentInsuranceAmount)
    {
        //Require now<timestamp of flight

        // ***** require(allFlights[_flightNumber].statusCode == STATUS_CODE_CAN_BUY_INSURANCE, "The flight has already departed or does not exist.");

        bytes32 _flightKey = keccak256(abi.encodePacked(airlineID, flight, timestamp));
        ///check current funded amount
        uint256 currentInsuranceAmount = flightSuretyData.checkInsuranceAmount(msg.sender, _flightKey);
        //total insurance after purchase should still be under 1 ether\
        require(currentInsuranceAmount.add(msg.value) <= 1 ether, "Max value of insurance is 1 Eth"); 
        //now we can purchase the insurance
        _buy(msg.sender, _flightKey, msg.value, flight); 

        currentInsuranceAmount = flightSuretyData.checkInsuranceAmount(msg.sender, _flightKey);
        return(true, currentInsuranceAmount);
        }


    /********************************************************************************************/
    /*                                     PRIVATE DATA CONTRACT FUNCTIONS                      */
    /********************************************************************************************/

    /**
    * This has been done so that we can add a third authorization (a version of a proxy or a proxy?) far easier later
    */
    function _registerAirline
                            (
                                address _airline
                            )
                            private // or internal? would actually like some reviewers advice on this!
                            //requireIsOperational => not needed b/c would've been checked in the public facing function that called this one
    {
        //flightSuretyData.registerAirline(_airline);
        //added check to see if successful...
        bool success = flightSuretyData.registerAirline(_airline);
        testFlagBool = success;
        testFlagVariable = testFlagVariable.add(1);
        if(success) {
            emit AirlineRegistered(_airline);
        }
    }

    function _listAirline
                            (
                                address _airline
                            )
                            private
    {
        bool success = flightSuretyData.listAirline(_airline);
        //testFlagBool = success;
        testFlagVariable = testFlagVariable.add(1);
        if(success) {
            emit AirlineRegistered(_airline);
        }
    }

    function _fund
                            (
                                address _airline,
                                uint256 _amount
                            )
                            private
    {
        flightSuretyData.fund(_airline, _amount);
        emit AirlineFundsPaid(_airline, _amount);
        
    }

    function _buy
                            (
                                address _passenger,
                                bytes32 _flightKey,
                                uint256 _insuranceAmount,
                                string memory _flight 
                            )
                            private
    {
        flightSuretyData.buy(_passenger, _flightKey, _insuranceAmount);
        emit InsuranceBought(_passenger, _flight, _insuranceAmount);
        
    }

    function _creditInsurees
                            (
                                bytes32 _flightKey,
                                string _flight,
                                address _airline
                            )
                            private
    {
        flightSuretyData.creditInsurees(_flightKey, INSURANCE_PAYOUT_MULTIPLIER_NUMERATOR, INSURANCE_PAYOUT_MULTIPLIER_DENOMINATOR);
        emit flightDelayedDueToAirline(_flight, _airline);
        emit insurancePaidOut(_flight, _airline);
    }

//-----------------------------------------------------------------------------


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

// region SCRAP CODE
//_____________________________________________________________________________________________________________
/*

1.     function registerAirline
                            (
                                address _airline
                            )
                            external
                            requireRegisteredAndFundedAirline
                            returns(bool success, uint256 votes)
    {
        if(numRegisteredAirlines < 5){
            airlines[_airline].isRegistered == true;
            airlines[_airline].isFunded == false; //default?
            airlines[_airline].amountFunded = 0; //default?
            airlines[_airline].numberOfVotes = 0; //default?
            airlines[_airline].isAcceptingRegistrationVotes == false; //default?
            numRegisteredAirlines = numRegisteredAirlines.add(1);
            //NEED to call registerairline on data contract
            return(true, 0);
        }
        else{ //5 or greater airlines gets ported here
            airlines[_airline].isAcceptingRegistrationVotes == true; ///skippedthe suspecteddefaults used above ^
            return (airlines[_airline].isRegistered, airlines[_airline].numberOfVotes);
        }

    }


    2.  airline vars in VARIABLES
    //NEED TO MOVE TO DATA CONTRACT THEN USE GETTERS? DONE.
    struct Airline {
        bool isRegistered;
        bool isFunded;
        uint256 amountFunded;
        bool isAcceptingRegistrationVotes;
        uint256 numberOfVotes;
        mapping(address => bool) votedToRegThisAirline;  //To prevent double voting on the multisig portion of registration
        //address[] votedToRegThisAirline; //another way to the above

    }
    //mapping(address => Airline) private airlines;
    //uint256 private numRegisteredAirlines = 0;


    3.
        /*function voteToRegisterAirline
                            (
                                address _airline
                            )
                            external
                            requireRegisteredAirline
                            returns(bool success, uint256 votes) //success and is that airline successfully registered ... not if the vote was successful or not
                            //actually if the number of votes is returned back as 0 then we know that the vote was not cast b/c the airline had not 'asked' to be registered
    {
        //If it has been 'nominated' to accept votes and this airline has not voted before then..

        // *****  if(airlines[msg.sender].isAcceptingRegistrationVotes == true && airlines[_airline].votedToRegThisAirline[msg.sender] == false){

            // ***** airlines[msg.sender].numberOfVotes = airlines[msg.sender].numberOfVotes.add(1);

            // ***** airlines[_airline].votedToRegThisAirline[msg.sender] = true;

            // ***** if(airlines[msg.sender].numberOfVotes >= numRegisteredAirlines/2){ //checking is we have >M signatures with N = numRegAirlines and M = N/2 can/NEED to migrate this to data app version
                
                // *****  airlines[msg.sender].isRegistered = true;

                // ***** numRegisteredAirlines = numRegisteredAirlines.add(1);

                //NEED to call registerairline on data contract
                //emit event if needed
            //}

            // ***** return(airlines[msg.sender].isRegistered, airlines[msg.sender].numberOfVotes);

        //}
        //else{
            ///skipped the suspected defaults used above ^

            // ***** return (airlines[_airline].isRegistered, 0);

        //}

    }

    */
// endregion