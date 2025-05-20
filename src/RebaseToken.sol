// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Sai Krishna
 * @notice This is a cross-chain rebase token that incentivitises users to deposit into a vault and in return, receive rebase tokens.
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate of the protocol at the time the user deposits into vault.
 */
contract RebaseToken is ERC20, Ownable , AccessControl {
    //////////////////////////////////////////
    /////////// errors ///////////////////////
    //////////////////////////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 s_interestRate, uint256 _newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) s_userInterestRate;
    mapping(address => uint256) s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 _newInterestRate);

    constructor() ERC20("Rebase Token", "RBC") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE,_account);
    }

    /**
     * @notice set the interest rate in the contract
     * @param _newInterestRate  The new interest rate to set
     * @dev The interest rate can only decrease
     */

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }
    /**
     * @notice Get the principle balance of a user, This is the number of tokens that have currently have been minted to the user, not including any interest
     * @param _user The user to get the principle balance for
     * @return The principle balance of the user
     */
    function principleBalanceOf(address _user) external view returns(uint256){
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint tokens
     * @param _amount The amount of tokens to mint
     */

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }
    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn tokens from
     * @param _amount The amount of tokens to burn
     */

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * caluculate the balance for the user including the interest that has accumulated since
     * (principle balance) * some interest that has accrued
     * @param _user The user to caluculate the balance for
     * @return The balance of the user that includes the interest that has accumulated
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of user
        // multiply the principle balance by interest that had accumulated
        // super keyword is used to call a function from parent contract (ohh its good)
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer is successful
     */
    function transfer(address _recipient, uint256 _amount) public override returns(bool){
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if(_amount==type(uint256).max){
            _amount = balanceOf(msg.sender);
        }
        if(balanceOf(_recipient)==0){
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }
    /**
     * @notice Transfer tokens from one user to another
     * @param _sender The user to transfer the tokens from
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True of the transfer is successfu;
     */
    function transferFrom(address _sender,address _recipient, uint256 _amount) public override returns(bool){
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if(_amount==type(uint256).max){ // to sweep all the balance we can send the uint256.max value then this condition automatically sets to availble balance
            _amount = balanceOf(_sender);
        }
        if(balanceOf(_recipient)==0){
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender,_recipient, _amount);
    }



    /**
     * @notice calculate the interest that has accumulated since the last update
     * @param _user The user to calculate the interest for
     * @return linearInterest The interest that has accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
        return linearInterest;
    }

    /**
     * @notice Mint the accrued interest to the user since the last time they interacted with the protocol
     * @param _user The user to mint accured interest
     */
    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate thenumber of tokens that need to be minted to the user -> (2) -(1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // call _mint to mint the token to the user
        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Get the interest rate for the contract
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns(uint256) {
        return s_interestRate;
    }

    /**
     * @notice get the interest rate for the user
     * @param _user The user to get interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
