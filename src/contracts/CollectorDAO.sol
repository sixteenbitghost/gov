// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../interfaces/INftMarketplace.sol";

/// @title A dao contract for voting, and executing proposals
/// @author Justin Brown
contract CollectorDAO {

    /// @notice voting options
    enum Support {YES, NO}

    event ProposalCreated(
        address sender,
        uint256 proposalId,
        address[] _targets,
        uint256[] _values,
        bytes[] _calldatas,
        string _description,
        uint256 voteStart,
        uint256 voteEnd
    );
    event MemberVoted(address sender, uint256 proposalId, uint8 support);
    event MemberVotedWithSignature(address sender, uint256 proposalId, uint8 support);
    event ProposalExecuted(uint256 proposalId);
    event MembershipPurchased();
    event CollectorDAOCreated();

    error InvalidInput();
    error InvalidProposalLength();
    error InvalidLengthSig();
    error EmptySig();
    error AlreadyMember();
    error NotMember();
    error EmptyProposal();
    error ProposalAlreadyExists();
    error ProposalDoesNotExist();
    error VotingHasEnded();
    error VoterDenied();
    error ProposalNotPassed();
    error ExecutionFailed();
    error NftExecutionFailed();
    error TransferFailed();
    error MaxPriceExceeded();
    error InvalidSignature();
    error SignatureAlreadyUsed();
    error MemberHasAlreadyVoted();
    error ProposalAlreadyExecuted();

    /// @notice a member who has purchased membership object
    struct Member {
        uint256 id;
        uint256 votingPower;
    }

    /// @notice a created proposal object
    struct Proposal {
        address creator;
        uint256 allowedVoterRange;
        uint256 yes;
        uint256 no;
        uint256 quorumNeeded;
        uint256 voteStart;
        uint256 voteEnd;
        bool executed;
        mapping(address => bool) memberHasVoted;
    }

    /// @notice metadata for a signed vote 
    struct SigVote {
        uint256 proposalId;
        uint8 support;
        address voter;
    }

    /// @notice the total current members
    /// @dev useful for getting a snpashot at the time of a proposal, to see how many members are needed for quorum.
    /// currentMemberCount also represents a new members id at time of purchase, which is then used to see which 
    /// proposals they can vote on.
    uint256 public currentMemberCount;

    /// @notice the latest proposal id
    uint256 public proposalNonce;

    /// @notice holds all current members
    mapping(address => Member) public members;

    /// @notice holds all current proposals
    mapping(uint256 => Proposal) public proposals;

    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 constant public SIG_VOTE_TYPEHASH = keccak256("SigVote(uint256 proposalId,uint8 support,address voter)");
    bytes32 constant public APP_NAME = keccak256(bytes("CollectorDAO"));
    bytes32 constant public VERSION = keccak256(bytes("1"));
    uint256 constant public QUORUM_NUMERATOR = 25;
    uint256 constant public QUORUM_DENOMINATOR = 100;
    uint256 constant public VOTING_PERIOD = 7 days;
    uint256 constant public EXECUTION_REWARD = 0.01 ether;
    uint256 constant QUORUM_MULTIPLIER = 1_000;

    bytes32 immutable public EIP712_DOMAIN_TYPE;

    modifier onlyMember() {
        if (members[msg.sender].votingPower == 0) revert NotMember();
        _;
    }

    constructor() {
        EIP712_DOMAIN_TYPE = keccak256(
        abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            APP_NAME,
            VERSION,
            block.chainid,
            address(this)
        )
    );
    emit CollectorDAOCreated();
    }

    /// @notice returns status of given proposal
    /// @param _proposalId the id of the proposal to check status on
    /// @return status of a proposal: either true (it passed) or false (it has not passed)
    function proposalPassed(uint256 _proposalId) public view returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        if (
            block.timestamp > proposal.voteEnd &&
            proposal.yes > proposal.no &&
            (proposal.yes * QUORUM_MULTIPLIER) + (proposal.no * QUORUM_MULTIPLIER) >= proposal.quorumNeeded
        ) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice allows any address to purchase membership for 1 eth
    function buyMembership() external payable {
        if (members[msg.sender].votingPower != 0) revert AlreadyMember();
        if (msg.value != 1 ether) revert InvalidInput();
        Member storage member = members[msg.sender];
        member.votingPower++;
        member.id = currentMemberCount;
        currentMemberCount++;
        emit MembershipPurchased();
    }

    /// @notice allows members to make new proposals
    /// @param _targets The address of the contract to be called upon exectution
    /// @param _values The amount of eth to be sent to _targets[i] upon exectution
    /// @param _calldatas The function signature and args to be called/sent to _targets[i] upon exectution
    /// example: abi.encodeWithSignature(signatureString, arg);
    /// @param _description A description of the proposal
    /// @return proposalId The id of the newly created proposal
    function propose(
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _calldatas,
        string calldata _description
    ) external onlyMember returns (uint256) {
        uint256 proposalId = proposalNonce;
        Proposal storage proposal = proposals[proposalId];
        if (_targets.length == 0) revert EmptyProposal();
        if (_targets.length != _values.length) revert InvalidProposalLength();
        if (_targets.length != _calldatas.length) revert InvalidProposalLength();
        proposal.creator = msg.sender;
        proposal.voteStart = block.timestamp;
        proposal.voteEnd = block.timestamp + VOTING_PERIOD;
        proposal.quorumNeeded = ((currentMemberCount * QUORUM_MULTIPLIER) * QUORUM_NUMERATOR) / QUORUM_DENOMINATOR;
        proposal.allowedVoterRange = currentMemberCount;
        proposalNonce++;
        emit ProposalCreated(
            msg.sender,
            proposalId,
            _targets,
            _values,
            _calldatas,
            _description,
            proposal.voteStart,
            proposal.voteEnd
        );
        return proposalId;
    }

    /// @notice allows a member to vote 
    /// @param _proposalId The proposal id to vote on
    /// @param _support The YES or NO vote 
    function vote(uint256 _proposalId, uint8 _support) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        if (proposal.memberHasVoted[msg.sender]) revert MemberHasAlreadyVoted();
        if (proposal.voteStart == 0) revert ProposalDoesNotExist();
        if (block.timestamp > proposal.voteEnd) revert VotingHasEnded();
        if (members[msg.sender].id >= proposal.allowedVoterRange) revert VoterDenied();
        Member storage member = members[msg.sender];
        if (_support == uint8(Support.YES)) {
            proposal.yes += member.votingPower;
        } else {
            proposal.no += member.votingPower;
        }
        proposal.memberHasVoted[msg.sender] = true;
        emit MemberVoted(msg.sender, _proposalId, _support);
    }

    /// @notice allows any address to send in a vote on behalf of the signer
    /// @param sigVote The metadata of the signers vote
    /// @param v signature component 
    /// @param r signature component 
    /// @param s signature component 
    function voteWithSig(
        SigVote calldata sigVote,
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) public {
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        address _signer = ecrecover(hash_, v, r, s);
        if(sigVote.voter != _signer) {
            revert InvalidSignature();
        }

        _voteWithSig(sigVote.proposalId, sigVote.support, sigVote.voter);
    }

    /// @notice allows any address to send in a vote on behalf of the signer
    /// @param _proposalId The proposal id to vote on.
    /// @param _support The YES or NO vote 
    /// @param _voter The alleged signer.
    /// @dev called from the voteWithSig function
    function _voteWithSig(uint256 _proposalId, uint8 _support, address _voter) internal {
        Proposal storage proposal = proposals[_proposalId];
        if (members[_voter].votingPower == 0) revert NotMember();
        if (proposal.memberHasVoted[_voter]) revert MemberHasAlreadyVoted();
        if (proposal.voteStart == 0) revert ProposalDoesNotExist();
        if (block.timestamp >= proposal.voteEnd) revert VotingHasEnded();
        if (members[_voter].id >= proposal.allowedVoterRange) revert VoterDenied();
        Member storage member = members[_voter]; 
        if (_support == uint8(Support.YES)) {
            proposal.yes += member.votingPower;
        } else {
            proposal.no += member.votingPower;
        }
        proposal.memberHasVoted[_voter] = true;
        emit MemberVotedWithSignature(_voter, _proposalId, _support);
    }

    /// @notice allows any address to send in a batch of signed votes
    /// @param sigVote[] The array of metadata of the signers votes
    /// @param v[] The array of signature components
    /// @param r[] The array of signature components 
    /// @param s[] The array of signature components
    function batchVoteWithSig(
        SigVote[] calldata sigVote,
        uint8[] calldata v, 
        bytes32[] calldata r, 
        bytes32[] calldata s
    ) external {
        if (sigVote.length == 0) revert EmptySig();
        if (sigVote.length != v.length) revert InvalidLengthSig();
        if (sigVote.length != r.length) revert InvalidLengthSig();
        if (sigVote.length != s.length) revert InvalidLengthSig();

        for (uint256 i = 0; i < sigVote.length; i++) {
            voteWithSig(sigVote[i], v[i], r[i], s[i]);
        }
    } 

    /// @notice allows any address to execute a proposal
    /// @param _proposalId the proposal to execute
    /// @param _targets The address of the contract to be called upon exectution
    /// @param _values The amount of eth to be sent to _targets[i] upon exectution
    /// @param _calldatas The function signature and args to be called/sent to _targets[i] upon exectution
    /// example: abi.encodeWithSignature(signatureString, arg);
    function execute(
        uint256 _proposalId,
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _calldatas
    ) external {
        if (!proposalPassed(_proposalId)) revert ProposalNotPassed();
        if (proposals[_proposalId].executed == true) revert ProposalAlreadyExecuted();  
        proposals[_proposalId].executed = true;
        members[proposals[_proposalId].creator].votingPower++;
        for (uint256 i = 0; i < _targets.length; i++) {
            (bool success,) = _targets[i].call{value: _values[i]}(_calldatas[i]);
            if (!success) revert ExecutionFailed();
        }
        (bool success_,) = msg.sender.call{value: EXECUTION_REWARD}("");
        if(success_) {

        }
        emit ProposalExecuted(_proposalId);
    }

    /// @notice returns if an address has voted on a proposal
    /// @param _proposalId The proposal id
    /// @param _voter The address of the voter
    /// @return voted Returns true or false 
    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool voted) {
        voted = proposals[_proposalId].memberHasVoted[_voter];
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function buyNFTFromMarketplace(
        INftMarketplace marketplace,
        address nftContract,
        uint256 nftId,
        uint256 maxPrice
    ) external {
        require(msg.sender == address(this));
        uint256 price = marketplace.getPrice(nftContract, nftId);
        if(price > maxPrice) {
            revert MaxPriceExceeded();
        }
        marketplace.buy{value: price}(nftContract, nftId);
    }
}
