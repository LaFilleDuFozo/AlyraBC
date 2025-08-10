//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VotingPlus is Ownable {
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

    // ---------- MODIFIERS ----------
    // Vérifie que l'état actuel correspond bien à celui attendu
    modifier checkStatus(WorkflowStatus _status) {
        require(currentStatus == _status, "Invalid workflow status for this step");
        _;
    }

    // Vérifie que l'état actuel bien comprise entre le début et la fin de l'étape courante
    modifier statusInRange(WorkflowStatus _min, WorkflowStatus _max) {
        require(
            currentStatus >= _min && currentStatus <= _max,
            "This action is not allowed at the current workflow status"
        );
        _;
    }

    // Vérifie que l'appelant est un électeur enregistré
    modifier onlyRegisteredVoter() {
        require(whitelistOfVoters[msg.sender].isRegistred, "You are not a registered voter");
        _;
    }

    // Vérifie que l'appelant n'a pas encore voté
    modifier onlyIfNotVoted() {
        require(!whitelistOfVoters[msg.sender].hasVoted, "You have already voted");
        _;
    }

    // ---------- FUNCTIONS ----------
    function registerVoter(address _voterAddress) public 
        onlyOwner 
        checkStatus(WorkflowStatus.RegisteringVoters){
        require(!whitelistOfVoters[_voterAddress].isRegistred,"This voter is already registered !");
        // Enregistrement et initialisation un électeur s'il remplit la condition ci-dessus
        whitelistOfVoters[_voterAddress]= Voter(true, false, 0);
        numberOfVoters++;
        emit VoterRegistered(_voterAddress); // Log de cet événement sur la blockchain
    }

    function startProposalRegistrationSession() external 
        onlyOwner 
        checkStatus(WorkflowStatus.RegisteringVoters){ 
        // La session de dépôt d'une proposition va être ouverte
        require(numberOfVoters > 0, "This can not be done before the registering session.");
        emit WorkflowStatusChange(currentStatus, WorkflowStatus.ProposalsRegistrationStarted); // Log de cet événement sur la blockchain
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
    }

    function endProposalRegistrationSession() external 
        onlyOwner 
        checkStatus(WorkflowStatus.ProposalsRegistrationStarted) { 
        // La session de dépôt d'une proposition va être clôturée
        emit WorkflowStatusChange(currentStatus, WorkflowStatus.ProposalsRegistrationEnded); // Log de cet événement sur la blockchain
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
    }

    function addProposal(string memory _proposalDescription) external 
        statusInRange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationStarted)
        onlyRegisteredVoter { 
        // Ajout d'une proposition par un électeur
        proposals.push(Proposal({
            description: _proposalDescription,
            voteCount: 0
        }));
        proposalOwners[proposals.length-1]= msg.sender;
        emit ProposalRegistered(proposals.length-1); // Log de cet événement sur la blockchain
    }

    function startVotingRegistrationSession() external 
        onlyOwner
        checkStatus(WorkflowStatus.ProposalsRegistrationEnded){ 
        // La session de vote va être ouverte
        emit WorkflowStatusChange(currentStatus, WorkflowStatus.VotingSessionStarted); // Log de cet événement sur la blockchain
        currentStatus = WorkflowStatus.VotingSessionStarted;
    }

    function endVotingRegistrationSession() external 
        onlyOwner 
        checkStatus(WorkflowStatus.VotingSessionStarted){ 
        // La session de vote va être clôturée
        emit WorkflowStatusChange(currentStatus, WorkflowStatus.VotingSessionEnded); // Log de cet événement sur la blockchain
        currentStatus = WorkflowStatus.VotingSessionEnded;
    }

    function voteForAProposal(uint _proposalId) external 
        statusInRange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionStarted) 
        onlyRegisteredVoter 
        onlyIfNotVoted { 
        require(_proposalId < proposals.length, "Invalid proposal ID");
        // Enregistrement du vote d'un électeur s'il remplit les conditions ci-dessus.  
        // N'importe qui peut voter pour cette proposition y compris celui qui l'a créée et l'administrateur 
        whitelistOfVoters[msg.sender].hasVoted = true;
        whitelistOfVoters[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;
        if(whitelistOfVoters[msg.sender].isRegistred) {
            emit Voted(msg.sender, _proposalId); // Log de cet événement sur la blockchain
        }
    }

    function tallyVotes() external onlyOwner 
        checkStatus(WorkflowStatus.VotingSessionEnded) {
        // Récupération de l'id de la proposition ayant eu le plus de votes
        winningProposalId = getBestProposal();
        // Vérification si un ex aequo existe
        uint proposalIdExAequo = checkExAequo();

        // Récupération de l'initiateur
        winner = proposalOwners[winningProposalId];
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied); // Log de cet événement sur la blockchain
        if(proposalIdExAequo != 0){
            emit Result(string.concat("The winning proposals are ", Strings.toString(winningProposalId), " and ", Strings.toString(proposalIdExAequo))); // Log du résultat - deux gagnants
        } else {
            emit Result(string.concat("The winning proposal is ", Strings.toString(winningProposalId))); // Log du résultat - un seul gagnant
        }
    
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

    function checkExAequo() internal view returns(uint){
        uint highestVoteCount = proposals[winningProposalId].voteCount;
        uint proposalIdExAequo = 0;

        for(uint i = 0; i < proposals.length; i++){
            if(proposals[i].voteCount==highestVoteCount && i!= winningProposalId){
                proposalIdExAequo = i;
                break;
            }
        }
        return proposalIdExAequo;
    }

}
