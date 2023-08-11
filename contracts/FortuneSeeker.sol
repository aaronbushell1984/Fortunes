// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// AutomationCompatible.sol imports the functions from both ./AutomationBase.sol and
// ./interfaces/AutomationCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

interface IFortuneTeller {
    function seekFortune() external payable;
}

// AutomationCompatibleInterface is imported by AutomationBase
// We do not need the AutomationBase and are using it for the interface only
contract FortuneSeeker is AutomationCompatibleInterface {

    event InSufficientFunds(uint balance);

    event ReceivedFunding(uint amount);

    address public owner;

    address public fortuneTeller;

    string public fortune;

    uint public immutable interval;
    uint public lastTimeStamp;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    constructor(address _fortuneTeller, uint updateInterval) {
        owner = msg.sender;
        fortuneTeller = _fortuneTeller;
        interval = updateInterval;
        lastTimeStamp = block.timestamp;
    }

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        bool intervalExceeded = (block.timestamp - lastTimeStamp) > interval;
        bool sufficientFunds = address(this).balance >= 1 ether;
        upkeepNeeded = intervalExceeded && sufficientFunds;
        performData = checkData;
    }

    function performUpkeep(bytes calldata) external override {
        bool intervalExceeded = (block.timestamp - lastTimeStamp) > interval;
        bool sufficientFunds = address(this).balance >= 1 ether;
        bool upkeepNeeded = intervalExceeded && sufficientFunds;
        require(upkeepNeeded, "upkeep not needed");

        lastTimeStamp = block.timestamp;
        seekFortune();
    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function withdrawBalance() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "failed to withdraw funds");
    }

    // instigate a call to the fortune teller which is mandated to implement seekFortune()
    // by the IFortuneTeller interface
    function seekFortune() public payable {
        if(address(this).balance < 1 ether) {
            emit InSufficientFunds(address(this).balance);
            revert("insufficient funds");
        }
        IFortuneTeller(fortuneTeller).seekFortune{value: 0.001 ether}();
    }

    // interface in Teller mandates this function so that the fortune teller can
    // call this and return the fortune to the seeker
    function fulfillFortune(string memory _fortune) external {
        fortune = _fortune;
    }

    receive() external payable {
        emit ReceivedFunding(msg.value);
    }

}

