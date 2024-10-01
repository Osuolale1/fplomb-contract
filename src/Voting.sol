// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ZKMEVerifyUpgradeable {
    function hasApproved(address cooperator, address user) external view returns (bool);
}

contract Voting {
    ZKMEVerifyUpgradeable public zkmeVerifyContract;
    address public cooperator;

    struct Candidate {
        string name;
        string ipfsHash; // IPFS hash for the candidate's image
    }

    struct Election {
        string pollTitle;
        string country;
        uint256 startTime;
        uint256 endTime;
        Candidate[] candidates; // Modified to use Candidate struct
        mapping(string => uint256) votes;
        bool exists;
    }

    struct Voter {
        address voterAddress;
        string country;
        bool registered;
        bool hasVoted;
    }

    mapping(address => Voter) public voters;
    mapping(string => mapping(address => bool)) public registeredVotersByCountry;
    mapping(uint256 => Election) public elections;
    mapping(uint256 => mapping(address => bool)) public hasVotedInElection;
    // mapping(uint256 => mapping(address => address)) public delegates;

    uint256 public electionCount;

    event ElectionCreated(
        uint256 electionId, string pollTitle, string country, uint256 startTime, uint256 endTime, Candidate[] candidates
    );
    event VoterRegistered(address voterAddress, string country);
    event Voted(uint256 electionId, string candidate);
    event ElectionResult(uint256 electionId, string winner, uint256 voteCount);
    // event Delegated(uint256 indexed electionId, address indexed delegator, address indexed delegatee);

    modifier onlyRegisteredVoter(string memory country) {
        require(voters[msg.sender].registered, "Voter is not registered");
        require(
            keccak256(abi.encodePacked(voters[msg.sender].country)) == keccak256(abi.encodePacked(country)),
            "Voter not registered in this country"
        );
        _;
    }

    constructor(address _zkmeVerifyContract, address _cooperator) {
        zkmeVerifyContract = ZKMEVerifyUpgradeable(_zkmeVerifyContract);
        cooperator = _cooperator;
    }

    function createElection(
        string memory pollTitle,
        string memory country,
        uint256 _startMinutesFromNow,
        uint256 _durationMinutes,
        Candidate[] memory candidateData
    ) public {
        // Check that candidateData is not empty
        require(candidateData.length > 0, "No candidates provided");

        uint256 startTime = (_startMinutesFromNow);
        uint256 endTime = (_durationMinutes);

        electionCount++;

        Election storage newElection = elections[electionCount];
        newElection.pollTitle = pollTitle;
        newElection.country = country;
        newElection.startTime = startTime;
        newElection.endTime = endTime;
        newElection.exists = true;

        for (uint256 i = 0; i < candidateData.length; i++) {
            newElection.candidates.push(candidateData[i]);
        }

        emit ElectionCreated(electionCount, pollTitle, country, startTime, endTime, candidateData);
    }

    function registerVoter(string memory country) public {
        require(!voters[msg.sender].registered, "Voter is already registered");
        require(isCountryAvailableForElection(country), "No election available in this country");

        voters[msg.sender] = Voter({voterAddress: msg.sender, country: country, registered: true, hasVoted: false});
        registeredVotersByCountry[country][msg.sender] = true;

        emit VoterRegistered(msg.sender, country);
    }

    function isCountryAvailableForElection(string memory country) internal view returns (bool) {
        for (uint256 i = 1; i <= electionCount; i++) {
            if (
                keccak256(abi.encodePacked(elections[i].country)) == keccak256(abi.encodePacked(country))
                    && elections[i].exists && block.timestamp < elections[i].endTime
            ) {
                return true;
            }
        }
        return false;
    }

    function vote(uint256 electionId, string memory candidateName)
        public
        onlyRegisteredVoter(elections[electionId].country)
    {
        require(elections[electionId].exists, "Election does not exist");
        // require(block.timestamp >= elections[electionId].startTime, "Election has not started yet");
        require(block.timestamp <= elections[electionId].endTime, "Election has ended");
        require(!hasVotedInElection[electionId][msg.sender], "Voter has already voted in this election");

        // Ensure the candidate exists
        bool candidateExists = false;
        for (uint256 i = 0; i < elections[electionId].candidates.length; i++) {
            if (
                keccak256(abi.encodePacked(elections[electionId].candidates[i].name))
                    == keccak256(abi.encodePacked(candidateName))
            ) {
                candidateExists = true;
                break;
            }
        }
        require(candidateExists, "Candidate does not exist in this election");

        // Check if the voter has completed KYC and authorized SBT
        require(zkmeVerifyContract.hasApproved(cooperator, msg.sender), "KYC or SBT authorization not completed");

        elections[electionId].votes[candidateName]++;
        hasVotedInElection[electionId][msg.sender] = true;

        emit Voted(electionId, candidateName);
    }

    function getCandidateVotes(uint256 electionId, string memory candidateName) public view returns (uint256) {
        require(elections[electionId].exists, "Election does not exist");
        return elections[electionId].votes[candidateName];
    }

    function getElection(uint256 electionId)
        public
        view
        returns (
            string memory pollTitle,
            string memory country,
            uint256 startTime,
            uint256 endTime,
            Candidate[] memory candidates,
            uint256[] memory votes
        )
    {
        require(elections[electionId].exists, "Election does not exist");
        Election storage election = elections[electionId];
        candidates = new Candidate[](election.candidates.length);
        votes = new uint256[](election.candidates.length);

        for (uint256 i = 0; i < election.candidates.length; i++) {
            candidates[i] = election.candidates[i];
            votes[i] = election.votes[election.candidates[i].name];
        }

        return (election.pollTitle, election.country, election.startTime, election.endTime, candidates, votes);
    }

    // function getCandidate(uint256 electionId, uint256 candidateIndex)
    //     public
    //     view
    //     returns (string memory name, string memory info)
    // {
    //     return (
    //         elections[electionId].candidates[candidateIndex].name, elections[electionId].candidates[candidateIndex].info
    //     );
    // }

    function getVoteStatus(uint256 electionId) public view returns (bool hasVoted, string memory candidateName) {
        require(elections[electionId].exists, "Election does not exist");
        hasVoted = hasVotedInElection[electionId][msg.sender];

        if (hasVoted) {
            // Find the candidate the voter voted for
            for (uint256 i = 0; i < elections[electionId].candidates.length; i++) {
                candidateName = elections[electionId].candidates[i].name;
                if (elections[electionId].votes[candidateName] > 0) {
                    return (true, candidateName); // Return the candidate the voter voted for
                }
            }
        } else {
            candidateName = ""; // No candidate voted
        }

        return (false, candidateName);
    }

    function getWinner(uint256 electionId) public view returns (string memory winner) {
        require(elections[electionId].exists, "Election does not exist");

        Election storage election = elections[electionId];
        uint256 highestVotes = 0;

        for (uint256 i = 0; i < election.candidates.length; i++) {
            string memory candidateName = election.candidates[i].name;
            uint256 candidateVotes = election.votes[candidateName];

            if (candidateVotes > highestVotes) {
                highestVotes = candidateVotes;
                winner = candidateName;
            }
        }
    }

    function getCandidateIPFSHash(uint256 electionId, string memory candidateName)
        public
        view
        returns (string memory)
    {
        require(elections[electionId].exists, "Election does not exist");
        for (uint256 i = 0; i < elections[electionId].candidates.length; i++) {
            if (
                keccak256(abi.encodePacked(elections[electionId].candidates[i].name))
                    == keccak256(abi.encodePacked(candidateName))
            ) {
                return elections[electionId].candidates[i].ipfsHash;
            }
        }
        revert("Candidate not found");
    }

    function getElectionsForCountry(string memory country) public view returns (uint256[] memory) {
        uint256[] memory electionIds = new uint256[](electionCount);
        uint256 count = 0;
        for (uint256 i = 1; i <= electionCount; i++) {
            if (keccak256(abi.encodePacked(elections[i].country)) == keccak256(abi.encodePacked(country))) {
                electionIds[count] = i;
                count++;
            }
        }
        // Resize the array to remove empty slots
        assembly {
            mstore(electionIds, count)
        }
        return electionIds;
    }



    // function delegate(uint256 electionId, address delegatee) public {
    //     require(elections[electionId].exists, "Election does not exist");
    //     require(block.timestamp < elections[electionId].startTime, "Election has already started");
    //     require(msg.sender != delegatee, "Self-delegation is not allowed");
    //     require(voters[msg.sender].registered, "You are not registered to vote");
    //     require(voters[delegatee].registered, "Delegatee is not registered to vote");
    //     require(
    //         keccak256(abi.encodePacked(voters[msg.sender].country))
    //             == keccak256(abi.encodePacked(elections[electionId].country)),
    //         "You are not eligible for this election"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(voters[delegatee].country))
    //             == keccak256(abi.encodePacked(elections[electionId].country)),
    //         "Delegatee is not eligible for this election"
    //     );
    //     require(!hasVotedInElection[electionId][msg.sender], "Cannot delegate after voting");

    //     delegates[electionId][msg.sender] = delegatee;

    //     emit Delegated(electionId, msg.sender, delegatee);
    // }

    function checkVoterVerification(address voter) public view returns (bool) {
        return zkmeVerifyContract.hasApproved(cooperator, voter);
    }

    //The vote function to handle delegations
    // function delegateVote(uint256 electionId, string memory candidateName)
    //     public
    //     onlyRegisteredVoter(elections[electionId].country)
    // {
    //     require(elections[electionId].exists, "Election does not exist");
    //     require(block.timestamp >= elections[electionId].startTime, "Election has not started yet");
    //     require(block.timestamp <= elections[electionId].endTime, "Election has ended");
    //     require(!hasVotedInElection[electionId][msg.sender], "Voter has already voted in this election");

    //     // Check for delegations and ensure only the final delegatee can vote
    //     address currentVoter = msg.sender;
    //     address nextDelegatee = delegates[electionId][currentVoter];
    //     while (nextDelegatee != address(0)) {
    //         require(!hasVotedInElection[electionId][currentVoter], "A delegate in the chain has already voted");
    //         currentVoter = nextDelegatee;
    //         nextDelegatee = delegates[electionId][currentVoter];
    //     }
    //     require(currentVoter == msg.sender, "You have delegated your vote and cannot vote directly");

    //     // Ensure the candidate exists
    //     bool candidateExists = false;
    //     for (uint256 i = 0; i < elections[electionId].candidates.length; i++) {
    //         if (
    //             keccak256(abi.encodePacked(elections[electionId].candidates[i].name))
    //                 == keccak256(abi.encodePacked(candidateName))
    //         ) {
    //             candidateExists = true;
    //             break;
    //         }
    //     }
    //     require(candidateExists, "Candidate does not exist in this election");

    //     // Check if the voter has completed KYC and authorized SBT
    //     require(zkmeVerifyContract.hasApproved(cooperator, msg.sender), "KYC or SBT authorization not completed");

    //     elections[electionId].votes[candidateName]++;

    //     // Mark the entire delegation chain as having voted
    //     currentVoter = msg.sender;
    //     while (currentVoter != address(0)) {
    //         hasVotedInElection[electionId][currentVoter] = true;
    //         currentVoter = delegates[electionId][currentVoter];
    //     }

    //     emit Voted(electionId, candidateName);
    // }
}
