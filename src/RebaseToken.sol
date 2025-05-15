// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Rebase Token
 * @author Sai Krishna
 * @notice This is a cross-chain rebase token that incentivitises users to deposit into a vault and in return, receive rebase tokens.
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate of the protocol at the time the user deposits into vault.
 */
contract RebaseToken is ERC20 {

    ////////////////////////////////////////// 
    /////////// errors /////////////////////// 
    ////////////////////////////////////////// 
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 s_interestRate,uint256 _newInterestRate);

    uint256 private s_interestRate = 5e10;
    mapping (address => uint256) s_userInterestRate;

    event InterestRateSet(uint256 _newInterestRate);

    constructor() ERC20("Rebase Token", "RBC") {}
    /**
     * @notice set the interest rate in the contract
     * @param _newInterestRate  The new interest rate to set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external {

        if(_newInterestRate<s_interestRate){
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate,_newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to,_amount);
    }

    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principle balance
        // (2) calculate their current balance including any interest -> balanceOf
        // calculate thenumber of tokens that need to be minted to the user -> (2) -(1)
        // call _mint to mint the token to the user
    }

    /**
     * @notice get the interest rate for the user
     * @param _user The user to get interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address _user) external view returns(uint256){
        return s_userInterestRate[_user];
    }

}
