// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Voting.sol";

contract MockZKMEVerify {
    mapping(address => bool) public approvedUsers;

    function setApproved(address user, bool status) external {
        approvedUsers[user] = status;
    }

    function hasApproved(address, address user) external view returns (bool) {
        return approvedUsers[user];
    }
}

contract VotingTest is Test {
    Voting public voting;
    MockZKMEVerify public mockZkme;
    address public cooperator;
    address public voter1;
    address public voter2;

    function setUp() public {
        mockZkme = new MockZKMEVerify();
        cooperator = address(0x1);
        voting = new Voting(address(mockZkme), cooperator);
        voter1 = address(0x2);
        voter2 = address(0x3);
    }

    function testCreateAndVoteInElection() public {
        // vm.warp(0);

        // Create an election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Candidate A", "");
        candidates[1] = Voting.Candidate("Candidate B", "");
        uint256 startTime = 10;
        uint256 endTime = startTime + 50;

        voting.createElection("Test Election", "Global", startTime, endTime, candidates);

        // Register and approve voter
        vm.prank(voter1);
        voting.registerVoter("Global");
        mockZkme.setApproved(voter1, true);

        // Vote

        vm.prank(voter1);
        vm.warp(12);
        voting.vote(1, "Candidate A");

        // Check if the election was created correctly
        (string memory title, string memory country, uint256 start, uint256 end, bool exists) = voting.elections(1);
        assertEq(title, "Test Election");
        assertEq(country, "Global");
        assertEq(start, startTime);
        assertEq(end, endTime);
        assertTrue(exists);
    }

    function testFailVoteInClosedElection() public {
        // Create an election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Candidate A", "");
        candidates[1] = Voting.Candidate("Candidate B", "");
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;

        voting.createElection("Test Election", "Global", startTime, endTime, candidates);

        // Register and approve voter
        voting.registerVoter(vm.toString(voter1));
        mockZkme.setApproved(voter1, true);

        // Move time past the end of the election
        vm.warp(endTime + 1);

        // Attempt to vote (this should fail)
        vm.prank(voter1);
        voting.vote(1, "Candidate A");
    }

    function testFailVoteUnregistered() public {
        // vm.warp(0);

        // Create an election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Candidate A", "");
        candidates[1] = Voting.Candidate("Candidate B", "");
        uint256 startTime = 10;
        uint256 endTime = startTime + 50;

        voting.createElection("Test Election", "Global", startTime, endTime, candidates);
        vm.prank(voter1);
        voting.vote(1, "Candidate A");
    }

    function testFailVoteNotApproved() public {
        // vm.warp(0);

        // Create an election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Candidate A", "");
        candidates[1] = Voting.Candidate("Candidate B", "");
        uint256 startTime = 10;
        uint256 endTime = startTime + 50;

        voting.createElection("Test Election", "Global", startTime, endTime, candidates);
        vm.prank(voter1);
        voting.registerVoter("Global");
        voting.vote(1, "Candidate A");
    }

    function testFailVoteTwice() public {
        // vm.warp(0);

        // Create an election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Candidate A", "");
        candidates[1] = Voting.Candidate("Candidate B", "");
        uint256 startTime = 10;
        uint256 endTime = startTime + 50;

        voting.createElection("Test Election", "Global", startTime, endTime, candidates);
        vm.prank(voter1);
        voting.registerVoter("Global");
        mockZkme.setApproved(voter1, true);

        vm.startPrank(voter1);
        voting.vote(1, "Candidate A");
        voting.vote(1, "Candidate B");
        vm.stopPrank();
    }

    function testGetWinner() public {
        // vm.warp(0);

        // Create an election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Candidate A", "");
        candidates[1] = Voting.Candidate("Candidate B", "");
        uint256 startTime = 10;
        uint256 endTime = startTime + 50;

        voting.createElection("Test Election", "Global", startTime, endTime, candidates);

        vm.prank(voter1);
        voting.registerVoter("Global");

        vm.prank(voter2);
        voting.registerVoter("Global");
        mockZkme.setApproved(voter1, true);
        mockZkme.setApproved(voter2, true);

        vm.prank(voter1);
        voting.vote(1, "Candidate A");
        vm.prank(voter2);
        voting.vote(1, "Candidate A");

        vm.warp(block.timestamp + 2 days);
        string memory winner = voting.getWinner(1);
        assertEq(winner, "Candidate A");
    }

    function testFailGetWinnerBeforeEnd() public {
        vm.warp(0);

        // Create an election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Candidate A", "");
        candidates[1] = Voting.Candidate("Candidate B", "");
        uint256 startTime = 10;
        uint256 endTime = startTime + 50;

        voting.createElection("Test Election", "Global", startTime, endTime, candidates);
        vm.expectRevert("Election has not ended");
        voting.getWinner(1);
    }

    function testCreateElectionWithoutCandidates() public {
        Voting.Candidate[] memory candidates = new Voting.Candidate[](0);
        vm.expectRevert("No candidates provided");
        voting.createElection("Empty Election", "USA", 10, 60, candidates);
    }

    function testHasVoted() public {
        // Create an election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Alice", "");
        candidates[1] = Voting.Candidate("Candidate B", "");
        uint256 startTime = 10;
        uint256 endTime = startTime + 50;

        voting.createElection("Test Election", "USA", startTime, endTime, candidates);

        // Register voters
        vm.prank(voter1);
        voting.registerVoter("USA");
        // Approve voters for KYC
        mockZkme.setApproved(voter1, true);
        vm.prank(voter2);
        voting.registerVoter("USA");
        mockZkme.setApproved(voter2, true);

        // Voter1 votes for Alice
        vm.prank(voter1);
        voting.vote(1, "Alice");

        vm.expectRevert("Voter has already voted in this election");

        // Voter1 votes for Alice
        vm.prank(voter1);
        voting.vote(1, "Alice");
    }

    function testVoteForNonExistentCandidate() public {
        // Create election
        Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
        candidates[0] = Voting.Candidate("Alice", "ipfs://alice");
        candidates[1] = Voting.Candidate("Bob", "ipfs://bob");
        voting.createElection("Test Election", "USA", 10, 60, candidates);

        // Register voter1
        vm.prank(voter1);
        voting.registerVoter("USA");
        // Approve voters for KYC
        mockZkme.setApproved(voter1, true);

        // Voter1 votes for a non-existent candidate
        vm.prank(voter1);
        vm.expectRevert("Candidate does not exist in this election");
        voting.vote(1, "Charlie");
    }

    // function testDelegateVote() public {

    //     // Create election
    //     Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
    //     candidates[0] = Voting.Candidate("Alice", "ipfs://alice");
    //     candidates[1] = Voting.Candidate("Bob", "ipfs://bob");
    //     voting.createElection("Test Election", "USA", 10, 60, candidates);

    //     // Register voters
    //     vm.prank(voter1);
    //     voting.registerVoter("USA");
    //      // Approve voters for KYC
    //     mockZkme.setApproved(voter1, true);

    //     // vm.prank(voter2);
    //     // voting.registerVoter("USA");
    //     //       mockZkme.setApproved(voter2, true);

    //     // Voter1 delegates their vote to Voter2
    //     vm.prank(voter1);
    //     voting.delegate(1, voter2);

    //     // Voter2 votes for Bob
    //     vm.prank(voter2);
    //     voting.vote(1, "Bob");

    //           vm.prank(voter2);
    //     voting.vote(1, "Bob");

    // }

    // function testDelegateVoteWithoutApproval() public {
    //     // Approve only voter1
    //     mockZkme.setApproved(voter1, true);

    //     // Create election
    //     Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
    //     candidates[0] = Voting.Candidate("Alice", "ipfs://alice");
    //     candidates[1] = Voting.Candidate("Bob", "ipfs://bob");
    //     voting.createElection("Test Election", "USA", 10, 60, candidates);

    //     // Attempt to delegate vote for voter2 without approval
    //     vm.prank(voter1);
    //     vm.expectRevert("Voter not approved");
    //     voting.delegate(1, voter2);
    // }

    // function testDelegateVoteAfterVoting() public {

    //     // Create election
    //     Voting.Candidate[] memory candidates = new Voting.Candidate[](2);
    //     candidates[0] = Voting.Candidate("Alice", "ipfs://alice");
    //     candidates[1] = Voting.Candidate("Bob", "ipfs://bob");
    //     voting.createElection("Test Election", "USA", 10, 60, candidates);

    //     // Register voters
    //     vm.prank(voter1);
    //     voting.registerVoter("USA");
    //        // Approve voters for KYC
    //     mockZkme.setApproved(voter1, true);
    //     vm.prank(voter2);
    //     voting.registerVoter("USA");
    //      mockZkme.setApproved(voter2, true);

    //     // Voter1 votes for Alice
    //     vm.prank(voter1);
    //     voting.vote(1, "Alice");

    //     // Voter1 tries to delegate after voting
    //     vm.prank(voter1);
    //     vm.expectRevert("Cannot delegate after voting");
    //     voting.delegate(1, voter2);
    // }
}
