pragma solidity >=0.4.21 <0.6.0;


import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
   ////////////////
    mapping (address => bool) private registeredAirlines;
    mapping (address => uint) private fundedAirlines;
    mapping(address => uint256) private authorizedContracts;
    address[] airlines;
/////////////
    mapping(address => uint) private accountBalance;
    mapping(bytes32 =>address[]) private airlineinsurees;

    mapping(address =>mapping(bytes32 => uint)) insuredamount;
    mapping(address => uint) private fundedinsurance;
    mapping(bytes32 =>mapping(address => uint)) insuredpayout;

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
        registeredAirlines[firstAirline] = true;
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
        require( registeredAirlines[caller] == true, "Caller not registered");
        _;
    }

    modifier requireIsCallerAuthorized()
    {
        require(authorizedContracts[msg.sender] == 1, "Caller is not contract owner");
        _;
    } 

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    
   
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
    
     function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
       
    }

    function deauthorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }
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
                            returns(bool success)
    {
        require(airline != address(0));    
        registeredAirlines[airline] = true;
        airlines.push(airline);
        return registeredAirlines[airline];
    }


 function isAirlineRegistered(address airline)
                            public
                            view
                            returns (bool)
    {
        return registeredAirlines[airline];
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
        return (fundedAirlines[airline]);
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
        
        bytes32 flightKey = getFlightKey(airline,flight,_timestamp);

       
        airlineinsurees[flightKey].push(passenger);
       
        insuredamount[passenger][flightKey]= amount;
        insuredpayout[flightKey][passenger] = 0; 
            
        
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
        bytes32 flightKey = getFlightKey(airline,flight,timestamp);
        
         address[] storage insurees = airlineinsurees[flightKey];
       
       
          for(uint8 i = 0; i < insurees.length; i++) {
             address passenger = insurees[i];
             uint256 payout;
            uint amount = insuredamount[passenger][flightKey];
            
            //check if already paid
            uint paid = insuredpayout[flightKey][passenger];
            if(paid == 0)
            {
                payout = amount.mul(factor_numerator).div(factor_denominator);               
               
                insuredpayout[flightKey][passenger] = payout;  
                accountBalance[passenger] += payout;
                
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
        bytes32 flightKey = getFlightKey(airline,flight,ts);
        insuredpayout[flightKey][passenger] = payout;  
        accountBalance[passenger] += payout;

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

