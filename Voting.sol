//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Voting is Ownable {
    struct Voter {
        bool isRegistred;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus { 
        RegisteringVoters, 
        ProposalsRegistrationStarted, 
        ProposalsRegistrationEnded, 
        VotingSessionStarted, 
        VotingSessionEnded, 
        VotesTallied 
    }

    uint winningProposalId;
    address winner;
    Proposal[] private proposals;
    WorkflowStatus private currentStatus;

    mapping(address => Voter) public whitelistOfVoters;
    mapping(uint => address) public proposalOwners;

    uint numberOfVoters = 0; 

    constructor() Ownable(msg.sender){}

    // ---------- EVENTS ----------
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event Result(string message);

    // ---------- FUNCTIONS ----------
    function registerVoter(address _voterAddress) external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters,"The registering session is closed.");
        require(!whitelistOfVoters[_voterAddress].isRegistred,"This voter is already registered !");
        // Enregistrement et initialisation un électeur s'il remplit la condition ci-dessus
        whitelistOfVoters[_voterAddress]= Voter(true, false, 0);
        numberOfVoters++;
        emit VoterRegistered(_voterAddress); // Log de cet événement sur la blockchain
    }

    function startProposalRegistrationSession() external onlyOwner { 
        // La session de dépôt d'une proposition va être ouverte
        require(currentStatus == WorkflowStatus.RegisteringVoters, "This proposal session is not opened yet or is closed");
        require(numberOfVoters > 0, "This can not be done before the registering session.");
        emit WorkflowStatusChange(currentStatus, WorkflowStatus.ProposalsRegistrationStarted); // Log de cet événement sur la blockchain
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
    }

    function endProposalRegistrationSession() external onlyOwner { 
        // La session de dépôt d'une proposition va être clôturée
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "This proposal session must be started before being closed");
        emit WorkflowStatusChange(currentStatus, WorkflowStatus.ProposalsRegistrationEnded); // Log de cet événement sur la blockchain
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
    }

    function addProposal(string memory _proposalDescription) external { 
        require(currentStatus >= WorkflowStatus.ProposalsRegistrationStarted && currentStatus < WorkflowStatus.ProposalsRegistrationEnded, "The proposal session is not opened yet or is closed.");
        require(whitelistOfVoters[msg.sender].isRegistred, "You must be registered in the list of approved voters to add a proposal.");
        // Ajout d'une proposition par un électeur 
        proposals.push(Proposal({
            description: _proposalDescription,
            voteCount: 0
        }));
        proposalOwners[proposals.length-1]= msg.sender;
        emit ProposalRegistered(proposals.length-1); // Log de cet événement sur la blockchain
    }

    function startVotingRegistrationSession() external onlyOwner { 
        // La session de vote va être ouverte
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "This voting session is not opened yet or is closed");
        emit WorkflowStatusChange(currentStatus, WorkflowStatus.VotingSessionStarted); // Log de cet événement sur la blockchain
        currentStatus = WorkflowStatus.VotingSessionStarted;
    }

    function endVotingRegistrationSession() external onlyOwner { 
        // La session de vote va être clôturée
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "This proposal session must be started before being closed");
        emit WorkflowStatusChange(currentStatus, WorkflowStatus.VotingSessionEnded); // Log de cet événement sur la blockchain
        currentStatus = WorkflowStatus.VotingSessionEnded;
    }

    function voteForAProposal(uint _proposalId) external { 
        require(currentStatus >= WorkflowStatus.VotingSessionStarted && currentStatus < WorkflowStatus.VotingSessionEnded, "The voting session is not opened yet or is closed.");
        require(whitelistOfVoters[msg.sender].isRegistred, "You must be registered in the list of approved voters to vote.");
        require(!whitelistOfVoters[msg.sender].hasVoted, "You have already voted.");
        require(_proposalId < proposals.length, "Invalid proposal ID");
        // Enregistrement du vote d'un électeur s'il remplit les conditions ci-dessus   
        // N'importe qui peut voter pour cette proposition y compris celui qui l'a créée et l'administrateur 
        whitelistOfVoters[msg.sender].hasVoted = true;
        whitelistOfVoters[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;
        if(whitelistOfVoters[msg.sender].isRegistred) {
            emit Voted(msg.sender, _proposalId); // Log de cet événement sur la blockchain
        }
    }

    function tallyVotes() external onlyOwner {
        require(currentStatus == WorkflowStatus.VotingSessionEnded, "This action can not be done before the voting session is ended.");    
        // Récupération de l'id de la proposition ayant eu le plus de votes
        winningProposalId = getBestProposal();
        // Récupération de l'initiateur
        winner = proposalOwners[winningProposalId];
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied); // Log de cet événement sur la blockchain
        emit Result(string.concat("The winning proposal is ", Strings.toString(winningProposalId))); // Log du résultat
    }

    // ---------- HELPERS ----------
    function getBestProposal() internal view returns(uint){
        uint highestVoteCount = 0;
        uint proposalId= 0;
 
        for(uint i = 0; i < proposals.length; i++){
            if(proposals[i].voteCount>highestVoteCount){
                highestVoteCount = proposals[i].voteCount;
                proposalId = i;
            }
        }
        return proposalId;
    }
}
