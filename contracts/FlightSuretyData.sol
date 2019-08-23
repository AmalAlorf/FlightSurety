pragma solidity ^0.4.25;


import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping (address => bool) private registered_Airlines;
    mapping (address => uint) private funded_Airlines;
    mapping(address => uint256) private authorized_Contracts;
    address[] airlines;

    mapping(address => uint) private passenger_Balance;
    mapping(bytes32 =>address[]) private airline_Insurance ;

    mapping(address =>mapping(bytes32 => uint)) insured_Amount;

    mapping(bytes32 =>mapping(address => uint)) insured_Payout;
    

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        registered_Airlines[firstAirline] = true;
        airlines.push(firstAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

     modifier requireIsCallerAirlineRegistered(address caller)
    {
        require( registered_Airlines[caller] == true, "Caller not registered");
        _;
    }

     modifier requireisAirlineNotRegistered(address airline)
    {
        require( registered_Airlines[airline] == false, "Airline already registered");
        _;
    }
    modifier requireIsCallerAuthorized()
    {
        require(authorized_Contracts[msg.sender] == 1, "Caller is not contract owner");
        _;
    } 

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isnotinsured(address airline,string flight,uint timestamp,address passenger)                     
                    external
                    view
                    returns(bool)
    {
        bytes32 flightKey = getFlightKey(airline,flight,timestamp);
        uint amount = insured_Amount[passenger][flightKey];
        return false ;
    }

    function isAirlineRegistered(address airline)
                            public
                            view
                            returns (bool)
    {
        return registered_Airlines[airline];
    }

    /**
    * @dev Get operating status of contract
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
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
  


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */

    function registerAirline
                            (  
                                address airline 
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized  
                            requireisAirlineNotRegistered(airline)                     
                            returns(bool success)
    {
        require(airline != address(0));    
        registered_Airlines[airline] = true;
        airlines.push(airline);
        return registered_Airlines[airline];
    }

    function getAirlines()
                external
                view
                returns(address[]) 


    {
        return airlines;
    }

    
    function getPassengerFunds(address passenger)
                external
                view
                returns(uint) 


    {
        
        return passenger_Balance[passenger];
    }

    function withdrawPassengerFunds(uint amount,address passenger)
                                    external    
                                    requireIsOperational                                     
                                    requireIsCallerAuthorized                                               
                                    returns(uint)
    {
        passenger_Balance[passenger] = passenger_Balance[passenger] - amount;
        passenger.transfer(amount);

        return passenger_Balance[passenger];
    }

    //////////
function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        authorized_Contracts[contractAddress] = 1;
       
    }

/**
  * @dev airline can deposit funds in any amount  
 */
    function fundAirline
                            (
                                address airline,
                                uint amount
                            )
                            external                            
                            requireIsOperational
                            requireIsCallerAuthorized
                            requireIsCallerAirlineRegistered(airline)
                           
    {
        funded_Airlines[airline] += amount;
    }

    /**
  * @dev to see how much fund an airline has  
 */
    function getAirlineFunds
                            (
                                address airline
                               
                            )
                            external 
                            view                           
                            requireIsOperational
                            requireIsCallerAuthorized
                            requireIsCallerAirlineRegistered(airline)
                             returns(uint funds)
                           
    {
        return (funded_Airlines[airline]);
    }
  
   /**
    * @dev Buy insurance for a flight. If a passenger sends more than 1 ether then the excess is returned.
    *
    */   
    
     function buy (address  airline,string flight,uint256 _timestamp,address passenger,uint amount)          
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            requireIsCallerAirlineRegistered(airline)                                                      
    {
        
        bytes32 flightkey = getFlightKey(airline,flight,_timestamp);
       
        airline_Insurance [flightkey].push(passenger);
       
        insured_Amount[passenger][flightkey]= amount;
        insured_Payout[flightkey][passenger] = 0; 
            
        
    } 
    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline,
                                    string flight,
                                    uint256 timestamp,
                                    uint factor_numerator,
                                    uint factor_denominator
                                                       
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
                                
    {
        //get all the insurees
        bytes32 flight_Key = getFlightKey(airline,flight,timestamp);
        
         address[] storage insurees = airline_Insurance [flight_Key];
       
       
          for(uint8 i = 0; i < insurees.length; i++) {
             address passenger = insurees[i];
             uint256 payOut;
            uint amount = insured_Amount[passenger][flight_Key];
            
            //check if already paid
            uint paid = insured_Payout[flight_Key][passenger];
            if(paid == 0)
            {
                payOut = amount.mul(factor_numerator).div(factor_denominator);               
               
                insured_Payout[flight_Key][passenger] = payOut;  
                passenger_Balance[passenger] += payOut;
                
            }
              
        } 
    } 


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (   address airline,string flight,uint ts,
                                address passenger,
                                uint payout
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            
    {
        bytes32 flightkey = getFlightKey(airline,flight,ts);
        insured_Payout[flightkey][passenger] = payout;  
        passenger_Balance[passenger] += payout;

    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
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
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

