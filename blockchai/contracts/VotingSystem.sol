// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VotingSystem
 * @dev Sistema de votación descentralizado en blockchain
 */
contract VotingSystem {
    
    // Estructuras de datos
    struct Candidate {
        uint256 id;
        string name;
        string description;
        uint256 voteCount;
        bool exists;
    }
    
    struct Vote {
        address voter;
        uint256 candidateId;
        uint256 timestamp;
    }
    
    struct Election {
        uint256 id;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool exists;
        mapping(uint256 => Candidate) candidates;
        mapping(address => bool) hasVoted;
        uint256[] candidateIds;
        Vote[] votes;
        uint256 totalVotes;
        address creator;
    }
    
    // Variables de estado
    address public owner;
    uint256 public electionCounter;
    
    mapping(uint256 => Election) public elections;
    uint256[] public activeElectionIds;
    uint256[] public allElectionIds;
    
    // Eventos
    event ElectionCreated(
        uint256 indexed electionId, 
        string title, 
        address indexed creator,
        uint256 startTime, 
        uint256 endTime
    );
    
    event CandidateAdded(
        uint256 indexed electionId, 
        uint256 indexed candidateId, 
        string name,
        address indexed addedBy
    );
    
    event VoteCasted(
        uint256 indexed electionId, 
        uint256 indexed candidateId, 
        address indexed voter,
        uint256 timestamp
    );
    
    event ElectionEnded(
        uint256 indexed electionId, 
        uint256 totalVotes,
        uint256 endTime
    );
    
    event ElectionStatusChanged(
        uint256 indexed electionId,
        bool isActive
    );
    
    // Modificadores
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario puede realizar esta accion");
        _;
    }
    
    modifier electionExists(uint256 _electionId) {
        require(elections[_electionId].exists, "La eleccion no existe");
        _;
    }
    
    modifier electionActive(uint256 _electionId) {
        Election storage election = elections[_electionId];
        require(election.exists, "La eleccion no existe");
        require(election.isActive, "La eleccion no esta activa");
        require(block.timestamp >= election.startTime, "La eleccion no ha comenzado");
        require(block.timestamp <= election.endTime, "La eleccion ha terminado");
        _;
    }
    
    modifier onlyElectionCreator(uint256 _electionId) {
        require(
            msg.sender == owner || msg.sender == elections[_electionId].creator,
            "Solo el creador de la eleccion o el owner pueden realizar esta accion"
        );
        _;
    }
    
    /**
     * @dev Constructor del contrato
     */
    constructor() {
        owner = msg.sender;
        electionCounter = 0;
    }
    
    /**
     * @dev Crear nueva elección
     * @param _title Título de la elección
     * @param _description Descripción de la elección
     * @param _durationSeconds Duración en segundos (AHORA la unidad son segundos)
     */
    function createElection(
        string memory _title,
        string memory _description,
        uint256 _durationSeconds
    ) public returns (uint256) {
        require(bytes(_title).length > 0, "El titulo no puede estar vacio");
        require(_durationSeconds > 0, "La duracion debe ser mayor a 0");
        
        electionCounter++;
        uint256 electionId = electionCounter;
        
        Election storage newElection = elections[electionId];
        newElection.id = electionId;
        newElection.title = _title;
        newElection.description = _description;
        newElection.startTime = block.timestamp;
        newElection.endTime = block.timestamp + _durationSeconds; // <-- sin multiplicaciones
        newElection.isActive = true;
        newElection.exists = true;
        newElection.totalVotes = 0;
        newElection.creator = msg.sender;
        
        activeElectionIds.push(electionId);
        allElectionIds.push(electionId);
        
        emit ElectionCreated(
            electionId, 
            _title, 
            msg.sender,
            newElection.startTime, 
            newElection.endTime
        );
        
        return electionId;
    }
    
    /**
     * @dev Agregar candidato
     */
    function addCandidate(
        uint256 _electionId,
        string memory _name,
        string memory _description
    ) public electionExists(_electionId) onlyElectionCreator(_electionId) {
        require(bytes(_name).length > 0, "El nombre del candidato no puede estar vacio");
        
        Election storage election = elections[_electionId];
        require(election.isActive, "No se pueden agregar candidatos a una eleccion inactiva");
        
        uint256 candidateId = election.candidateIds.length + 1;
        
        election.candidates[candidateId] = Candidate({
            id: candidateId,
            name: _name,
            description: _description,
            voteCount: 0,
            exists: true
        });
        
        election.candidateIds.push(candidateId);
        
        emit CandidateAdded(_electionId, candidateId, _name, msg.sender);
    }
    
    /**
     * @dev Votar
     */
    function vote(uint256 _electionId, uint256 _candidateId) 
        public 
        electionExists(_electionId) 
        electionActive(_electionId) 
    {
        Election storage election = elections[_electionId];
        
        require(!election.hasVoted[msg.sender], "Ya has votado en esta eleccion");
        require(election.candidates[_candidateId].exists, "El candidato no existe");
        require(election.candidateIds.length > 0, "No hay candidatos en esta eleccion");
        
        // Registrar el voto
        election.hasVoted[msg.sender] = true;
        election.candidates[_candidateId].voteCount++;
        election.totalVotes++;
        
        // Guardar detalles del voto
        election.votes.push(Vote({
            voter: msg.sender,
            candidateId: _candidateId,
            timestamp: block.timestamp
        }));
        
        emit VoteCasted(_electionId, _candidateId, msg.sender, block.timestamp);
        
        // Auto-finalizar si expiró (seguimos permitiendo auto-end en vote)
        if (block.timestamp > election.endTime && election.isActive) {
            _endElection(_electionId);
        }
    }
    
    function endElection(uint256 _electionId) 
        public 
        electionExists(_electionId)
        onlyElectionCreator(_electionId)
    {
        _endElection(_electionId);
    }
    
    function _endElection(uint256 _electionId) internal {
        Election storage election = elections[_electionId];
        require(election.isActive, "La eleccion ya ha terminado");
        
        election.isActive = false;
        
        // Remover de elecciones activas
        for (uint256 i = 0; i < activeElectionIds.length; i++) {
            if (activeElectionIds[i] == _electionId) {
                activeElectionIds[i] = activeElectionIds[activeElectionIds.length - 1];
                activeElectionIds.pop();
                break;
            }
        }
        
        emit ElectionEnded(_electionId, election.totalVotes, block.timestamp);
        emit ElectionStatusChanged(_electionId, false);
    }
    
    /**
     * @dev Obtener info de elección
     */
    function getElectionInfo(uint256 _electionId) 
        public 
        view 
        electionExists(_electionId)
        returns (
            string memory title,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            bool isActive,
            uint256 totalVotes,
            uint256 candidateCount,
            address creator
        ) 
    {
        Election storage election = elections[_electionId];

        return (
            election.title,
            election.description,
            election.startTime,
            election.endTime,
            election.isActive,
            election.totalVotes,
            election.candidateIds.length,
            election.creator
        );
    }
    
    function getCandidates(uint256 _electionId) 
        public 
        view 
        electionExists(_electionId)
        returns (
            uint256[] memory ids,
            string[] memory names,
            string[] memory descriptions,
            uint256[] memory voteCounts
        ) 
    {
        Election storage election = elections[_electionId];
        uint256 candidateCount = election.candidateIds.length;
        
        ids = new uint256[](candidateCount);
        names = new string[](candidateCount);
        descriptions = new string[](candidateCount);
        voteCounts = new uint256[](candidateCount);
        
        for (uint256 i = 0; i < candidateCount; i++) {
            uint256 candidateId = election.candidateIds[i];
            Candidate storage candidate = election.candidates[candidateId];
            
            ids[i] = candidate.id;
            names[i] = candidate.name;
            descriptions[i] = candidate.description;
            voteCounts[i] = candidate.voteCount;
        }
    }
    
    function hasUserVoted(uint256 _electionId, address _voter) 
        public 
        view 
        electionExists(_electionId)
        returns (bool) 
    {
        return elections[_electionId].hasVoted[_voter];
    }
    
    function getActiveElections() public view returns (uint256[] memory) {
        return activeElectionIds;
    }
    
    function getAllElections() public view returns (uint256[] memory) {
        return allElectionIds;
    }
    
    function getWinner(uint256 _electionId) 
        public 
        view 
        electionExists(_electionId)
        returns (
            uint256 candidateId,
            string memory name,
            uint256 voteCount,
            bool isTied
        ) 
    {
        Election storage election = elections[_electionId];
        
        uint256 winningVoteCount = 0;
        uint256 winningCandidateId = 0;
        uint256 tiedCount = 0;
        
        for (uint256 i = 0; i < election.candidateIds.length; i++) {
            uint256 currentCandidateId = election.candidateIds[i];
            uint256 currentVotes = election.candidates[currentCandidateId].voteCount;

            if (currentVotes > winningVoteCount) {
                winningVoteCount = currentVotes;
                winningCandidateId = currentCandidateId;
                tiedCount = 1;
            } else if (currentVotes == winningVoteCount && currentVotes > 0) {
                tiedCount++;
            }
        }
        
        require(winningCandidateId != 0, "No hay votos registrados");
        
        return (
            winningCandidateId,
            election.candidates[winningCandidateId].name,
            winningVoteCount,
            tiedCount > 1
        );
    }
    
    function getElectionStats(uint256 _electionId)
        public
        view
        electionExists(_electionId)
        returns (
            uint256 totalVotes,
            uint256 totalCandidates,
            uint256 timeRemaining,
            bool hasEnded
        )
    {
        Election storage election = elections[_electionId];
        
        uint256 remaining = 0;
        bool ended = !election.isActive || block.timestamp > election.endTime;
        
        if (!ended && block.timestamp < election.endTime) {
            remaining = election.endTime - block.timestamp;
        }
        
        return (
            election.totalVotes,
            election.candidateIds.length,
            remaining,
            ended
        );
    }
    
    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }
    
    function getContractInfo() 
        public 
        view 
        returns (
            address contractOwner,
            uint256 totalElections,
            uint256 activeElections
        ) 
    {
        return (
            owner,
            allElectionIds.length,
            activeElectionIds.length
        );
    }
}
