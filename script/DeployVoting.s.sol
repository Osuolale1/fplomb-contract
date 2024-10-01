// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Voting.sol";

contract DeployVoting is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address zkmeVerifyAddress = vm.envAddress("ZKME_VERIFY_ADDRESS");
        address cooperatorAddress = vm.envAddress("COOPERATOR_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        Voting voting = new Voting(zkmeVerifyAddress, cooperatorAddress);

        console.log("Voting contract deployed at:", address(voting));

        // Optional: Set up initial state
        // For example, create an initial election
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 7 days;
        string[] memory candidates = new string[](2);
        candidates[0] = "Candidate A";
        candidates[1] = "Candidate B";

        Voting.Candidate[] memory candidateStructs = new Voting.Candidate[](2);
        candidateStructs[0] = Voting.Candidate("Candidate A", "");
        candidateStructs[1] = Voting.Candidate("Candidate B", "");
        voting.createElection("First Election", "Global", startTime, endTime, candidateStructs);

        vm.stopBroadcast();
    }
}
