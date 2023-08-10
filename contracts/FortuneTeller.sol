// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

// define interface to demand a seeker has a fulfillFortune function
interface IFortuneSeeker {
    function fulfillFortune(string memory fortune) external;
}

contract FortuneTeller is VRFConsumerBaseV2, ConfirmedOwner {

    event RequestSent(uint requestId, uint32 numWords);

    event RequestFulfilled(uint requestIf, uint[] randomWords);

    string[] fortunes = [
        "A beautiful, smart, and loving person will be coming into your life.",
        "A faithful friend is a strong defense.",
        "You are going to be a blockchain developer.",
        "A golden egg of opportunity falls into your lap this month.",
        "A hunch is creativity trying to tell you something.",
        "All EVM error messages are designed to build your character.",
        "A short pencil is usually better than a long memory any day.",
        "A soft voice may be awfully persuasive.",
        "All your hard work will soon pay off.",
        "Because you demand more from yourself, others respect you deeply.",
        "Better ask twice than lose yourself once.",
        "You will learn patience from Smart Contracts."
    ];

    string public lastReturnedFortune;

    struct RequestStatus {
        bool isRequested;
        bool isFulfilled;
        uint[] randomWords;
    }

    mapping(uint => RequestStatus) public s_requests;

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;

    uint[] public requestIds;
    uint public lastRequestId;

    bytes32 keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;

    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 1;

    uint32 numWords = 1;


    constructor(uint64 subscriptionId, address VRFCoordinator)
        VRFConsumerBaseV2(VRFCoordinator)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(VRFCoordinator);
        s_subscriptionId = subscriptionId;
    }

    modifier onlyRequested(uint _requestId) {
        require(s_requests[_requestId].isRequested, "request not found");
        _;
    }

    // request the random words from Chainlink VRF
    // this will take some time to process
    function requestRandomWords() external onlyOwner returns (uint requestId) {

        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        s_requests[requestId] = RequestStatus({
            isRequested: true,
            isFulfilled: false,
            randomWords: new uint[](numWords)
        });

        requestIds.push(requestId);
        lastRequestId = requestId;

        emit RequestSent(requestId, numWords);

        return requestId;
    }

    // callback function used to retrieve the random words
    function fulfillRandomWords(
            uint _requestId,
            uint[] memory _randomWords
        )
            internal
            override
            onlyRequested(_requestId)
    {
        require(!s_requests[_requestId].isFulfilled, "request already fulfilled");

        s_requests[_requestId].isFulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint _requestId)
        external
        view
        onlyRequested(_requestId)
        returns (
            bool fulfilled,
            uint[] memory randomWords
        )
    {
        RequestStatus memory request = s_requests[_requestId];
        return (request.isFulfilled, request.randomWords);
    }

    // callback example
    function seekFortune() external payable {
        // provides funds for callback to seeker
        require(msg.value >= 0.001 ether, "insufficient payment to fortune teller");
        require(lastRequestId != 0, "no fortune available yet");

        string memory fortune = getFortune();

        // wrap the msg.sender in an interface
        // demands that the seeker has a fulfillFortune function
        IFortuneSeeker seeker = IFortuneSeeker(msg.sender);

        seeker.fulfillFortune(fortune);
    }

    function getFortune() public returns (string memory) {
        // divide by fortunes.length to keep in bounds of fortunes array
        string memory fortune = fortunes[
            s_requests[lastRequestId].randomWords[0] % fortunes.length
        ];
        lastReturnedFortune = fortune;
        return fortune;
    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function withdraw() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "withdraw failed");
    }

}