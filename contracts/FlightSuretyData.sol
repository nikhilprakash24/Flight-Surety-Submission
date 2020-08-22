pragma solidity ^0.4.25;
//pragma solidity ^0.5.2;


import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = false;                                    // Blocks all state changes throughout the contract if false

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        uint256 flightNumber;
        address[] passengersWithInsurance;
    }

    struct Airline {
        airlineStatus status;
        mapping(address => bool) votesFor;
        uint256 amountFunded;
        uint256 numVotesFor;
    }

    enum airlineStatus {
        Unlisted, //the airline mapping should init to all Unlisted...
        Listed, // i.e. can accept votes for registration for multi-party consensus - bypassed if 4 or fewer airlines are currently registered
        Registered,
        Funded // i.e. full member
    }

    mapping (address => Airline) internal airlines; //the airline mapping should init to all Unlisted...
    uint256 private numAirlinesRegistered; //required for multiparty consensus

    mapping (bytes32 => Flight) internal flights;
    uint256 private flightNumberCounter;
    //could also have a (or replace the above) mapping from flight number to flight...

    //numAirlinesFunded would not be used anywhere so...

    // struct InsuranceInfo{
    //     address passenger;
    //     uint256 value;
    //     uint status;
    // }
    
    // mapping(bytes32 => InsuranceInfo) private insurances;
    mapping(address => mapping(bytes32 => uint256)) private passengerInsurances;
    mapping(address => uint256) private passengerBalances;


    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20; //only one to trigger credit => payout
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    uint8 private constant STATUS_CODE_CAN_BUY_INSURANCE = 200; //We may not use this...


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    *  Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
    }

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
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    *  Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    *  Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    *  Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            //requireContractOwner ... this logic is checked in app contract
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    *  Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function listAirline
                            (
                                address _airline
                            )
                            external
                            requireIsOperational
                            returns(bool success)
    {
        if(airlines[_airline].status == airlineStatus.Unlisted) {
            airlines[_airline].status = airlineStatus.Listed;
            return(true);
        }

        else{return(false);}
    }

    function registerAirline
                            (
                                address _airline
                            )
                            external
                            requireIsOperational
                            returns(bool success)
    {
        if(airlines[_airline].status == airlineStatus.Listed) {
            airlines[_airline].status = airlineStatus.Registered; //all other checks by the logic in the 'app' contract
            numAirlinesRegistered = numAirlinesRegistered.add(1);
            return(true);
        }

        else{return(false);}
    }

    function voteForAirlineReg
                            (
                                address _airlineVoting,
                                address _airlineToReg
                            )
                            external
                            requireIsOperational
                            returns(uint256 currentVotesFor)
    {
        //all checks in data contract i.e. listed and votesneeded computation (e.g. consenus drops to 40% then just the app contract can be updated)
        if(airlines[_airlineToReg].votesFor[_airlineVoting] == false) {                       //check
            airlines[_airlineToReg].votesFor[_airlineVoting] == true;                         //effect
            airlines[_airlineToReg].numVotesFor = airlines[_airlineToReg].numVotesFor.add(1); //interaction... pattern
        }

        return(airlines[_airlineToReg].numVotesFor);
    }

    function checkAirlineStatus
                            (
                                address _airline
                            )
                            public
                            view
                            returns(airlineStatus status)
    {
        return(airlines[_airline].status);
    }

    function checkAirlineFunds
                            (
                                address _airline
                            )
                            public
                            view
                            returns(uint256 amountFunded)
    {
        return(airlines[_airline].amountFunded);
    }

    function checkNumAirlines
                            (

                            )
                            public
                            view
                            returns(uint256 _numAirlinesRegistered)
    {
        return(numAirlinesRegistered);
    }



   /**
    *  Buy insurance for a flight
    *
    */   
    //Note that the funds are being held in the data conract (design choice)
    function buy
                            (     
                                address _passenger,
                                bytes32 _flightKey,
                                uint256 _insuranceAmount                        
                            )
                            external
                            requireIsOperational
                            payable
    {
        flights[_flightKey].passengersWithInsurance.push(_passenger);
        passengerInsurances[_passenger][_flightKey] = passengerInsurances[_passenger][_flightKey].add(_insuranceAmount);
    }

    function checkInsuranceAmount
                            (           
                              address _passenger,
                              bytes32 _flightKey                    
                            )
                            external
                            view
                            returns(uint256 _insuredAmount)
    {
        return(passengerInsurances[_passenger][_flightKey]);
    }


    //FLIGHT FUNCTIONS
    function registerFlight
                                (        
                                    bytes32 _flightKey,
                                    uint256 _timestamp,
                                    address _airline
                                )
                                external
                                requireIsOperational
                                returns(bool success)
    {
        flightNumberCounter = flightNumberCounter.add(1);

        flights[_flightKey].isRegistered = true;
        flights[_flightKey].statusCode = STATUS_CODE_UNKNOWN;
        flights[_flightKey].updatedTimestamp = _timestamp;
        flights[_flightKey].airline = _airline;
        flights[_flightKey].flightNumber = flightNumberCounter;

        return(true);
    }

    

    /**
     *   Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    bytes32 _flightKey,
                                    uint256 _INSURANCE_PAYOUT_MULTIPLIER_NUMERATOR,
                                    uint256 _INSURANCE_PAYOUT_MULTIPLIER_DENOMINATOR
                                )
                                external
                                requireIsOperational
    {
        for (uint256 i = 0; i < flights[_flightKey].passengersWithInsurance.length; i++){
            address _passenger = flights[_flightKey].passengersWithInsurance[i];
            //DONT forget to divide the multiplier by 10
            uint256 amountToCredit = passengerInsurances[_passenger][_flightKey].mul(_INSURANCE_PAYOUT_MULTIPLIER_NUMERATOR).div(_INSURANCE_PAYOUT_MULTIPLIER_DENOMINATOR);
            passengerBalances[_passenger] = passengerBalances[_passenger].add(amountToCredit);
        }
    }
    

    /**
     *   Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            requireIsOperational
                            view
    {
    }

   /**
    *  Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (
                                address _airline,
                                uint256 _amount  
                            )
                            public
                            requireIsOperational
                            payable
    {
        //correct state checks done in app contract
        airlines[_airline].amountFunded =  airlines[_airline].amountFunded.add(_amount);
    }

    //LOGIC of when to update airline to full membership via a threshold set in app to separate app & data again
    function fundStatusUpdate
                            (   
                                address _airline
                            )
                            public
                            requireIsOperational
                            returns(bool success)                           
    {
        if(airlines[_airline].status == airlineStatus.Registered) {
            airlines[_airline].status = airlineStatus.Funded;
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

    /**
    *  Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund(msg.sender, msg.value);
    }


}

