// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }

    function mint(address to, uint256 amount) public {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract Voting {
    enum VoteMode { ONE_PERSON_ONE_VOTE, TOKEN_WEIGHTED }
    enum CandidateStatus { PENDING, APPROVED, REJECTED }
    enum ElectionStatus { CREATED, RUNNING, PAUSED, ENDED }

    struct Candidate {
        uint256 id;
        string name;
        string info;
        address applicant;
        CandidateStatus status;
        uint256 voteCount;
    }

    struct Election {
        uint256 id;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 maxCandidates;
        VoteMode voteMode;
        ElectionStatus status;
        uint256 totalVotes;
        bool resultLocked;
    }

    address public owner;
    uint256 public electionCount;
    mapping(uint256 => Election) public elections;
    mapping(uint256 => Candidate[]) public electionCandidates;
    mapping(address => bool) public admins;
    mapping(address => bool) public reviewers;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    MockERC20 public votingToken;

    event ElectionCreated(uint256 electionId, string title);
    event ElectionStarted(uint256 electionId);
    event ElectionPaused(uint256 electionId);
    event ElectionResumed(uint256 electionId);
    event ElectionEnded(uint256 electionId);
    event CandidateApplied(uint256 electionId, uint256 candidateId, string name);
    event CandidateReviewed(uint256 electionId, uint256 candidateId, bool approved);
    event Voted(uint256 electionId, address voter, uint256 candidateId, uint256 weight);
    event AdminAdded(address admin);
    event AdminRemoved(address admin);
    event ReviewerAdded(address reviewer);
    event ReviewerRemoved(address reviewer);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Only admin");
        _;
    }

    modifier onlyReviewer() {
        require(reviewers[msg.sender] || admins[msg.sender] || msg.sender == owner, "Only reviewer");
        _;
    }

    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
        votingToken = new MockERC20("Voting Governance Token", "VGT");
    }

    function addAdmin(address _admin) public onlyOwner {
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) public onlyOwner {
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    function addReviewer(address _reviewer) public onlyAdmin {
        reviewers[_reviewer] = true;
        emit ReviewerAdded(_reviewer);
    }

    function removeReviewer(address _reviewer) public onlyAdmin {
        reviewers[_reviewer] = false;
        emit ReviewerRemoved(_reviewer);
    }

    function createElection(
        string memory _title,
        string memory _description,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxCandidates,
        VoteMode _voteMode
    ) public onlyAdmin {
        require(_startTime >= block.timestamp, "Start time must be in future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_maxCandidates > 0, "Max candidates must be at least 1");

        electionCount++;
        elections[electionCount] = Election({
            id: electionCount,
            title: _title,
            description: _description,
            startTime: _startTime,
            endTime: _endTime,
            maxCandidates: _maxCandidates,
            voteMode: _voteMode,
            status: ElectionStatus.CREATED,
            totalVotes: 0,
            resultLocked: false
        });

        emit ElectionCreated(electionCount, _title);
    }

    function startElection(uint256 _electionId) public onlyAdmin {
        Election storage election = elections[_electionId];
        require(election.id != 0, "Election not found");
        require(election.status == ElectionStatus.CREATED, "Invalid status");
        require(block.timestamp >= election.startTime, "Not yet start time");

        election.status = ElectionStatus.RUNNING;
        emit ElectionStarted(_electionId);
    }

    function pauseElection(uint256 _electionId) public onlyAdmin {
        Election storage election = elections[_electionId];
        require(election.id != 0, "Election not found");
        require(election.status == ElectionStatus.RUNNING, "Must be running");

        election.status = ElectionStatus.PAUSED;
        emit ElectionPaused(_electionId);
    }

    function resumeElection(uint256 _electionId) public onlyAdmin {
        Election storage election = elections[_electionId];
        require(election.id != 0, "Election not found");
        require(election.status == ElectionStatus.PAUSED, "Must be paused");

        election.status = ElectionStatus.RUNNING;
        emit ElectionResumed(_electionId);
    }

    function endElection(uint256 _electionId) public onlyAdmin {
        Election storage election = elections[_electionId];
        require(election.id != 0, "Election not found");
        require(election.status == ElectionStatus.RUNNING || election.status == ElectionStatus.PAUSED, "Invalid status");

        election.status = ElectionStatus.ENDED;
        election.resultLocked = true;
        emit ElectionEnded(_electionId);
    }

    function applyCandidate(uint256 _electionId, string memory _name, string memory _info) public {
        Election storage election = elections[_electionId];
        require(election.id != 0, "Election not found");
        require(election.status == ElectionStatus.CREATED || election.status == ElectionStatus.RUNNING, "Election not accepting candidates");
        
        Candidate[] storage candidates = electionCandidates[_electionId];
        require(candidates.length < election.maxCandidates, "Max candidates reached");

        for (uint256 i = 0; i < candidates.length; i++) {
            require(candidates[i].applicant != msg.sender, "Already applied");
        }

        uint256 candidateId = candidates.length;
        candidates.push(Candidate({
            id: candidateId,
            name: _name,
            info: _info,
            applicant: msg.sender,
            status: CandidateStatus.PENDING,
            voteCount: 0
        }));

        emit CandidateApplied(_electionId, candidateId, _name);
    }

    function reviewCandidate(uint256 _electionId, uint256 _candidateId, bool _approved) public onlyReviewer {
        Election storage election = elections[_electionId];
        require(election.id != 0, "Election not found");

        Candidate[] storage candidates = electionCandidates[_electionId];
        require(_candidateId < candidates.length, "Candidate not found");
        require(candidates[_candidateId].status == CandidateStatus.PENDING, "Already reviewed");

        candidates[_candidateId].status = _approved ? CandidateStatus.APPROVED : CandidateStatus.REJECTED;
        emit CandidateReviewed(_electionId, _candidateId, _approved);
    }

    function vote(uint256 _electionId, uint256 _candidateId) public {
        Election storage election = elections[_electionId];
        require(election.id != 0, "Election not found");
        require(election.status == ElectionStatus.RUNNING, "Election not running");
        require(block.timestamp >= election.startTime, "Not started");
        require(block.timestamp <= election.endTime, "Ended");
        require(!hasVoted[_electionId][msg.sender], "Already voted");

        Candidate[] storage candidates = electionCandidates[_electionId];
        require(_candidateId < candidates.length, "Candidate not found");
        require(candidates[_candidateId].status == CandidateStatus.APPROVED, "Candidate not approved");

        uint256 weight = 1;
        if (election.voteMode == VoteMode.TOKEN_WEIGHTED) {
            weight = votingToken.balanceOf(msg.sender);
            require(weight > 0, "No voting weight");
        }

        hasVoted[_electionId][msg.sender] = true;
        candidates[_candidateId].voteCount += weight;
        election.totalVotes += weight;

        emit Voted(_electionId, msg.sender, _candidateId, weight);
    }

    function getElectionInfo(uint256 _electionId) public view returns (Election memory) {
        return elections[_electionId];
    }

    function getCandidates(uint256 _electionId) public view returns (Candidate[] memory) {
        return electionCandidates[_electionId];
    }

    function getApprovedCandidates(uint256 _electionId) public view returns (Candidate[] memory) {
        Candidate[] memory allCandidates = electionCandidates[_electionId];
        uint256 approvedCount = 0;
        
        for (uint256 i = 0; i < allCandidates.length; i++) {
            if (allCandidates[i].status == CandidateStatus.APPROVED) {
                approvedCount++;
            }
        }

        Candidate[] memory approvedCandidates = new Candidate[](approvedCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allCandidates.length; i++) {
            if (allCandidates[i].status == CandidateStatus.APPROVED) {
                approvedCandidates[index] = allCandidates[i];
                index++;
            }
        }

        return approvedCandidates;
    }

    function getActiveElections() public view returns (Election[] memory) {
        uint256 activeCount = 0;
        
        for (uint256 i = 1; i <= electionCount; i++) {
            ElectionStatus status = elections[i].status;
            if (status == ElectionStatus.CREATED || status == ElectionStatus.RUNNING || status == ElectionStatus.PAUSED) {
                activeCount++;
            }
        }

        Election[] memory activeElections = new Election[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= electionCount; i++) {
            ElectionStatus status = elections[i].status;
            if (status == ElectionStatus.CREATED || status == ElectionStatus.RUNNING || status == ElectionStatus.PAUSED) {
                activeElections[index] = elections[i];
                index++;
            }
        }

        return activeElections;
    }

    function getAllElections() public view returns (Election[] memory) {
        Election[] memory allElections = new Election[](electionCount);
        
        for (uint256 i = 1; i <= electionCount; i++) {
            allElections[i - 1] = elections[i];
        }

        return allElections;
    }
}