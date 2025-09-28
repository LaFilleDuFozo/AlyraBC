const { expect } = require('chai');
const { ethers } = require('hardhat');

describe("Voting Tests", function(){
    let Voting, voting, owner, voter1, voter2, voter3, winningProposalID;

    beforeEach(async function(){
        [owner, voter1, voter2, voter3] = await ethers.getSigners()
        Voting = await ethers.getContractFactory("Voting")
        voting = await Voting.deploy()
    })

    // ::::::::::::: DEPLOYMENT ::::::::::::: // 
    describe("Voting contract deployment", function(){ // test constructeur
        it("Should set the right owner", async function () {
            expect(await voting.owner()).to.equal(owner.address);
        });
    });

    // ::::::::::::: REGISTRATION ::::::::::::: // 
    describe("Add the voters", function(){ // test fonction "addVoter(xxx)"
          it("Should add a voter and should emit an event", async function () {
            await expect(voting.addVoter(voter1.address))
              .to.emit(voting, "VoterRegistered")
              .withArgs(voter1.address);
      
            const voter = await voting.connect(voter1).getVoter(voter1.address);
            expect(voter.isRegistered).to.be.true;
          });
      
          it("Should fail if the user is not the owner", async function () {
            await expect(voting.connect(voter2).addVoter(voter3.address))
                .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
                .withArgs(voter2.address); 
          });
      
          it("Should fail if the registration concerns an existing voter", async function () {
            await voting.addVoter(voter1.address);
            await expect(voting.addVoter(voter1.address)).to.be.revertedWith("Already registered");
          });

          it("Should fail if the workflow status is not 'RegisteringVoters'", async function () {
            await voting.startProposalsRegistering(); // Workflow status value = 1 / expected = 0
            await expect(voting.addVoter(voter2.address)).to.be.revertedWith("Voters registration is not open yet");
          });
    });

    // ::::::::::::: PROPOSAL ::::::::::::: // 
    describe("Add proposals", function(){ // test fonction "addProposal(xxx)"
        it("Should create a new proposal and should emit an event", async function () {
          /// Contexte
          const desc = "Ma super proposition";
          await voting.addVoter(owner.address); // L'owner s'ajoute comme votant
          await voting.startProposalsRegistering();
          ///

          // Appel et vérification de l'événement
          await expect(voting.addProposal(desc))
            .to.emit(voting, "ProposalRegistered")
            .withArgs(1); 

          // Vérifier que la proposition est enregistrée
          const proposal = await voting.getOneProposal(1);
          expect(proposal.description).to.equal(desc);
        });

        it("Should fail if the user is not a voter", async function () {
          await expect(voting.connect(voter1).addProposal("Une nouvelle proposition"))
          .to.be.revertedWith("You're not a voter");
        });       
        
        it("Should fail if the proposal description is empty", async function () {
          /// Contexte
          const desc = "Ma super proposition";
          await voting.addVoter(owner.address); 
          await voting.startProposalsRegistering();
          ///
          await expect(voting.addProposal("")).to.be.revertedWith("Vous ne pouvez pas ne rien proposer");
        });        
        
        it("Should fail if the workflow status is not 'ProposalsRegistrationStarted'", async function () {
          /// Contexte
          const desc = "Ma super proposition";
          await voting.addVoter(owner.address); 
          await voting.startProposalsRegistering();
          ///
          await voting.endProposalsRegistering(); // Workflow status value = 1 / expected = 0
          await expect(voting.addProposal("Une nouvelle proposition")).to.be.revertedWith("Proposals are not allowed yet");
        });
        
    });

    // ::::::::::::: VOTE ::::::::::::: //
    describe("Set vote", function(){ // test fonction "setVote(xxx)"
      it("Should set a vote and should emit an event", async function () {
        /// Contexte
        const voteId = 1;
        await voting.addVoter(voter1.address);
        await voting.startProposalsRegistering();
        await voting.connect(voter1).addProposal("Une proposition");
        await voting.endProposalsRegistering();
        await voting.startVotingSession();
        ///
        await expect(voting.connect(voter1).setVote(voteId))
          .to.emit(voting, "Voted")
          .withArgs(voter1.address,voteId);

        const voter = await voting.connect(voter1).getVoter(voter1.address);
        expect(voter.hasVoted).to.be.true;
        expect(voter.votedProposalId).to.be.equal(voteId)
      });

      it("Should fail if the user is not a voter", async function () {
        /// Contexte
        const voteId = 1;
        await voting.addVoter(voter1.address);
        await voting.startProposalsRegistering();
        await voting.connect(voter1).addProposal("Une proposition");
        await voting.endProposalsRegistering();
        await voting.startVotingSession();
        ///         
        await expect(voting.connect(voter2).setVote(voteId)).to.be.revertedWith("You're not a voter");
      });   

      it("Should fail if the user has already voted", async function () {
        /// Contexte
        const voteId = 1;
        await voting.addVoter(voter1.address);
        await voting.startProposalsRegistering();
        await voting.connect(voter1).addProposal("Une proposition");
        await voting.endProposalsRegistering();
        await voting.startVotingSession();
        await voting.connect(voter1).setVote(voteId);
        ///   
        await expect(voting.connect(voter1).setVote(voteId)).to.be.revertedWith("You have already voted");
      }); 

      it("Should fail if the proposal is not found", async function () {
        /// Contexte
        await voting.addVoter(voter1.address);
        await voting.startProposalsRegistering();
        await voting.connect(voter1).addProposal("Une proposition");
        await voting.endProposalsRegistering();
        await voting.startVotingSession();
        const invalidProposalId = 999;
        /// 
        await expect(voting.connect(voter1).setVote(invalidProposalId)).to.be.revertedWith("Proposal not found");
      }); 

      it("Should fail if the workflow status is not 'VotingSessionStarted'", async function () {
        /// Contexte
        const voteId = 1;
        await voting.addVoter(voter1.address);
        await voting.startProposalsRegistering();
        await voting.connect(voter1).addProposal("Une proposition");
        await voting.endProposalsRegistering();
        await voting.startVotingSession();
        ///        
        await voting.endVotingSession(); 
        await expect(voting.connect(voter1).setVote(voteId)).to.be.revertedWith("Voting session havent started yet");
      });
    });

    // ::::::::::::: STATES ::::::::::::: //
    describe("Start the proposals registration", function(){ // test fonction "startProposalsRegistering()"
        it("Should start the registration of proposals, should emitn an event and should create a first proposal", async function () {
          /// Contexte
          await voting.addVoter(owner.address);
          ///

          expect(await voting.workflowStatus()).to.equal(0);
      
          await expect(voting.startProposalsRegistering())
            .to.emit(voting, "WorkflowStatusChange")
            .withArgs(0, 1); // de RegisteringVoters(0) à ProposalsRegistrationStarted(1)
      
          expect(await voting.workflowStatus()).to.equal(1);
      
          const genesisProposal = await voting.connect(owner).getOneProposal(0);
          expect(genesisProposal.description).to.equal("GENESIS");
        });

        it("Should fail if the user is not the owner and try to start the registration", async function () {
          await expect(voting.connect(voter1).startProposalsRegistering())
              .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
              .withArgs(voter1.address); 
        });
      
        it("Should fail if the workflow status is not 'ProposalsRegistrationStarted'", async function () {
          await voting.startProposalsRegistering(); 
          await expect(voting.startProposalsRegistering()).to.be.revertedWith("Registering proposals cant be started now");
        });
    });

    describe("End the proposals registration", function(){ // test fonction "endProposalsRegistering()"
        it("Should end the registration of proposals and should emit an event", async function () {
          /// Contexte
          await voting.startProposalsRegistering();
          ///
          await expect(voting.endProposalsRegistering())
            .to.emit(voting, "WorkflowStatusChange")
            .withArgs(1, 2); // de ProposalsRegistrationStarted(0) à ProposalsRegistrationEnded(2)
        });

        it("Should fail if the user is not the owner and try to end the registration", async function () {
          await expect(voting.connect(voter1).endProposalsRegistering())
              .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
              .withArgs(voter1.address); 
        });
      
        it("Should fail if the workflow status is not 'ProposalsRegistrationEnded'", async function () {
          /// Contexte 
          await voting.startProposalsRegistering();
          await voting.endProposalsRegistering(); 
          ///
          await expect(voting.endProposalsRegistering()).to.be.revertedWith("Registering proposals havent started yet");
        });
    });

    describe("Start the voting session", function(){ // test fonction "startVotingSession()"
        it("Should start the voting session and should emit an event", async function () {
          /// Contexte
          await voting.startProposalsRegistering();
          await voting.endProposalsRegistering();
          ///
          await expect(voting.startVotingSession())
            .to.emit(voting, "WorkflowStatusChange")
            .withArgs(2, 3); // de ProposalsRegistrationEnded(2) à VotingSessionStarted(3)
        });

        it("Should fail if the user is not the owner and try to start the voting session", async function () {
          await expect(voting.connect(voter1).startVotingSession())
              .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
              .withArgs(voter1.address); 
        });
      
        it("Should fail if the workflow status is not 'VotingSessionStarted'", async function () {
          /// Contexte 
          await voting.startProposalsRegistering();
          await voting.endProposalsRegistering(); 
          ///
          await voting.startVotingSession(); 
          await expect(voting.startVotingSession()).to.be.revertedWith("Registering proposals phase is not finished");
        });
    });

    describe("End the voting session", function(){ // test fonction "endVotingSession()"
        it("Should end the voting session and should emit an event", async function () {
          /// Contexte
          await voting.startProposalsRegistering();
          await voting.endProposalsRegistering();
          await voting.startVotingSession();
          ///
          await expect(voting.endVotingSession())
            .to.emit(voting, "WorkflowStatusChange")
            .withArgs(3, 4); // de VotingSessionStarted(3) à VotingSessionEnded(4)
        });

        it("Should fail if the user is not the owner and try to end the registration", async function () {
          await expect(voting.connect(voter1).endVotingSession())
              .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
              .withArgs(voter1.address); 
        });
      
        it("Should fail if the workflow status is not 'VotingSessionEnded'", async function () {
          /// Contexte 
          await voting.startProposalsRegistering();
          await voting.endProposalsRegistering(); 
          await voting.startVotingSession();
          await voting.endVotingSession(); 
          ///
          await expect(voting.endVotingSession()).to.be.revertedWith("Voting session havent started yet");
        });
    });

    // ::::::::::::: TALLYVOTES ::::::::::::: //
    describe("Tally votes", function(){ // test fonction "tallyVotes()"
        it("Should tally the votes and should emit an event", async function () {
          /// Contexte
          await voting.addVoter(voter1.address);
          await voting.addVoter(voter2.address);
          await voting.startProposalsRegistering();
          await voting.connect(voter1).addProposal("Proposition 1");
          await voting.connect(voter1).addProposal("Proposition 2");
          await voting.endProposalsRegistering();
          await voting.startVotingSession();
          await voting.connect(voter1).setVote(1); // vote pour Proposition 1
          await voting.connect(voter2).setVote(1); // vote pour Proposition 1
          await voting.endVotingSession();
          ///
          await expect(voting.connect(owner).tallyVotes())
          .to.emit(voting, "WorkflowStatusChange")
          .withArgs(4, 5); // de VotingSessionEnded(4) à VotesTallied(5)
  
          // Vérifier la proposition gagnante
          const theWinningProposalId = await voting.winningProposalID();
          expect(theWinningProposalId).to.equal(1);
        });
  
        it("Should fail if the user is not the owner and try to tally the votes", async function () {
          await expect(voting.connect(voter1).tallyVotes())
              .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
              .withArgs(voter1.address); 
        });
  
        it("Should fail if the workflow status is not 'VotingSessionEnded'", async function () {
          /// Contexte 
          await voting.startProposalsRegistering();
          await voting.endProposalsRegistering(); 
          await voting.startVotingSession();
          ///
          await expect(voting.tallyVotes()).to.be.revertedWith("Current status is not voting session ended");
        });
      });
})