# Projet #1
Développement d'un smart contract `Voting.sol`  - un système de votes sur la blockchain

# Projet #2
Tests unitaires du smart contract `Voting.sol` 

## Contexte
Ce projet contient un smart contract `Voting.sol` développé en Solidity (`^0.8.28`).  
Il implémente un processus de vote structuré en plusieurs étapes (`WorkflowStatus`) :  
- **Enregistrement des votants**  
- **Enregistrement des propositions**  
- **Ouverture et clôture de la session de vote**  
- **Comptabilisation des votes**  

L'objectif des tests unitaires est de **vérifier la conformité du contrat** avec les règles métier définies, ainsi que la bonne gestion des erreurs et événements.

---

## Scénarios de tests couverts

### 1. **Gestion des votants**
- L’owner peut ajouter un votant.  
- Un utilisateur non "owner" ne peut pas ajouter de votant (vérification via le contrat OpenZeppelin `Ownable`).  
- Un votant déjà enregistré ne peut pas être ajouté à nouveau.  
- Vérification de l’événement `VoterRegistered`.  

---

### 2. **Enregistrement des propositions**
- Un votant peut enregistrer une proposition lorsque l’état est `ProposalsRegistrationStarted`.  
- Vérification de l’ajout automatique de la proposition **GENESIS** lors du démarrage.  
- Vérification de l’événement `ProposalRegistered`. 
- Rejet si :  
  - la description est vide,  
  - l’utilisateur n’est pas un votant,  
  - le workflow n’est pas à la bonne étape.

---

### 3. **Vote**
- Un votant peut voter pour une proposition valide pendant `VotingSessionStarted`.  
- Vérification de l’événement `Voted`.  
- Vérification que le statut du votant (`hasVoted`, `votedProposalId`) est bien mis à jour.  
- Rejet si :  
  - l’utilisateur n’est pas un votant,  
  - il a déjà voté,  
  - la proposition n’existe pas,  
  - la session de vote n’est pas ouverte.

---

### 4. **Gestion du workflow**
- Vérification du passage d’un état à un autre avec l’événement `WorkflowStatusChange`.  
- Tests de sécurité : impossible de changer d’état si la phase précédente n’est pas terminée.  
- Vérification que seul l’owner peut modifier l’état du workflow.  

---

### 5. **Comptabilisation des votes**
- Après la clôture de la session de vote, `tallyVotes()` détermine la proposition gagnante.  
- Vérification de la mise à jour de `winningProposalID`.  
- Vérification de l’émission de l’événement `WorkflowStatusChange` (vers `VotesTallied`).  
- Rejet si la fonction est appelée alors que l’état n’est pas `VotingSessionEnded`.  

---

## Organisation des tests
- Les tests sont organisés en **sous-sections (`describe`)** correspondant aux étapes du workflow.  
- Utilisation du **hook `beforeEach`** pour redéployer un contrat propre avant chaque test.  
- Définition **d'un contexte** pour exécuter les tests.

---

## Lancer les tests
```bash
npx hardhat test
