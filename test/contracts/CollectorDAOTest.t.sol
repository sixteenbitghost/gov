// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../MockNftMarketplace.sol";

contract CollectorDAOTest is Test {
    event CollectorDAOCreated();
    event MembershipPurchased();
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

    struct SigVote {
        uint256 proposalId;
        uint8 support;
        address voter;
    }

    CollectorDAO public collectorDAO;
    MockNftMarketplace public mockNftMarketplace;
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 constant SIG_VOTE_TYPEHASH = keccak256("SigVote(uint256 proposalId,uint8 support,address voter)");
    bytes32 constant APP_NAME = keccak256(bytes("CollectorDAO"));
    bytes32 constant VERSION = keccak256(bytes("1"));

    bytes32 public EIP712_DOMAIN_TYPE;

    address[] addresses;

    uint256[] values;

    bytes[] calldatas;

    CollectorDAO.SigVote[] sigs;
    uint8[] vs;
    bytes32[] rs;
    bytes32[] ss;

    function setUp() public {
        vm.chainId(1);
        collectorDAO = new CollectorDAO();
        mockNftMarketplace = new MockNftMarketplace();
        EIP712_DOMAIN_TYPE = keccak256(
        abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            APP_NAME,
            VERSION,
            block.chainid,
            address(collectorDAO)
        ));
    }

    function testConstructor() public {
        vm.expectEmit(false, false, false, false);
        emit CollectorDAOCreated();
        collectorDAO = new CollectorDAO();
        EIP712_DOMAIN_TYPE = keccak256(
        abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            APP_NAME,
            VERSION,
            block.chainid,
            address(collectorDAO)
        ));
        assertEq(collectorDAO.EIP712_DOMAIN_TYPE(), EIP712_DOMAIN_TYPE);
    }

    function testProposalPassedReturnsTrue() public {
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        collectorDAO.vote(pid, 0);
        vm.warp(block.timestamp + 8 days);
        assertTrue(collectorDAO.proposalPassed(pid));
    }

    function testProposalPassedReturnsFalseIfStillActive() public {
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        collectorDAO.vote(pid, 0);
        assertFalse(collectorDAO.proposalPassed(pid));
    }

    function testProposalPassedReturnsFalseIfNotEnoughYes() public {
        collectorDAO.buyMembership{value: 1 ether}();
        vm.deal(vm.addr(5), 1000 ether);
        vm.prank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        collectorDAO.vote(pid, 0);
        vm.prank(vm.addr(5));
        collectorDAO.vote(pid, 1);
        vm.warp(block.timestamp + 8 days);
        assertFalse(collectorDAO.proposalPassed(pid));
    }

    function testProposalPassedReturnsFalseIfQuorumNotMet() public {
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(2), 1000 ether);
        vm.prank(vm.addr(2));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(3), 1000 ether);
        vm.prank(vm.addr(3));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(4), 1000 ether);
        vm.prank(vm.addr(4));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(5), 1000 ether);
        vm.prank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(6), 1000 ether);
        vm.prank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(7), 1000 ether);
        vm.prank(vm.addr(7));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(8), 1000 ether);
        vm.prank(vm.addr(8));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        collectorDAO.vote(pid, 0);
        vm.warp(block.timestamp + 8 days);
        assertFalse(collectorDAO.proposalPassed(pid));
    }

    function testProposalPassedReturnsFalseIfVotingActiveAndMostNoVotes() public {
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(2), 1000 ether);
        vm.prank(vm.addr(2));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(3), 1000 ether);
        vm.prank(vm.addr(3));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(4), 1000 ether);
        vm.prank(vm.addr(4));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(5), 1000 ether);
        vm.prank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(6), 1000 ether);
        vm.prank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(7), 1000 ether);
        vm.prank(vm.addr(7));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(8), 1000 ether);
        vm.prank(vm.addr(8));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        collectorDAO.vote(pid, 0);

        vm.prank(vm.addr(8));
        collectorDAO.vote(pid, 1);
        assertFalse(collectorDAO.proposalPassed(pid));
    }

    function testProposalPassedReturnsFalseIfVotingActiveAndQuorumNotMet() public {
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(2), 1000 ether);
        vm.prank(vm.addr(2));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(3), 1000 ether);
        vm.prank(vm.addr(3));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(4), 1000 ether);
        vm.prank(vm.addr(4));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(5), 1000 ether);
        vm.prank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(6), 1000 ether);
        vm.prank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(7), 1000 ether);
        vm.prank(vm.addr(7));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(8), 1000 ether);
        vm.prank(vm.addr(8));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.prank(vm.addr(8));
        collectorDAO.vote(pid, 1);
        assertFalse(collectorDAO.proposalPassed(pid));
    }

    function testProposalPassedReturnsFalseIfMostNoAndQuorumNotMet() public {
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(2), 1000 ether);
        vm.prank(vm.addr(2));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(3), 1000 ether);
        vm.prank(vm.addr(3));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(4), 1000 ether);
        vm.prank(vm.addr(4));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(5), 1000 ether);
        vm.prank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(6), 1000 ether);
        vm.prank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(7), 1000 ether);
        vm.prank(vm.addr(7));
        collectorDAO.buyMembership{value: 1 ether}();

        vm.deal(vm.addr(8), 1000 ether);
        vm.prank(vm.addr(8));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.prank(vm.addr(8));
        collectorDAO.vote(pid, 1);

        vm.warp(block.timestamp + 8 days);

        assertFalse(collectorDAO.proposalPassed(pid));
    }

    function testBuyMembership() public {
        vm.expectEmit(false, false, false, false);
        emit MembershipPurchased();
        collectorDAO.buyMembership{value: 1 ether}();
        (uint256 id, uint256 votingPower) = collectorDAO.members(address(this));
        assertEq(id, 0);
        assertEq(votingPower, 1);
        assertEq(collectorDAO.currentMemberCount(), 1);
    }

    function testBuyMembershipRevertsIfAlreadyAMember() public {
        bytes memory customError = abi.encodeWithSignature(
            "AlreadyMember()"
        );

        collectorDAO.buyMembership{value: 1 ether}();

        vm.expectRevert(customError);
        collectorDAO.buyMembership{value: 1 ether}();
    }

    function testBuyMembershipRevertsIfUnderLimit() public {
        bytes memory customError = abi.encodeWithSignature(
            "InvalidInput()"
        );

        vm.expectRevert(customError);
        collectorDAO.buyMembership{value: 0.9 ether}();
    }

    function testBuyMembershipRevertsIfOverLimit() public {
        bytes memory customError = abi.encodeWithSignature(
            "InvalidInput()"
        );

        vm.expectRevert(customError);
        collectorDAO.buyMembership{value: 1.1 ether}();
    }

    function testPropose() public {
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        collectorDAO.buyMembership{value: 1 ether}();

        assertEq(collectorDAO.proposalNonce(), 0);

        vm.expectEmit(false, false, false, false);
        emit ProposalCreated(
        address(this),
        1,
        addresses,
        values,
        calldatas,
        "",
        block.timestamp,
        block.timestamp + 7 days
        );
        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        ( 
        address creator,
        uint256 allowedVoterRange,
        uint256 yes,
        uint256 no,
        uint256 quorumNeeded,
        uint256 voteStart,
        uint256 voteEnd,
        bool executed
        ) = collectorDAO.proposals(pid);

        assertEq(creator, address(this));
        assertEq(allowedVoterRange, 1);
        assertEq(yes, 0);
        assertEq(no, 0);
        assertEq(quorumNeeded, 250);
        assertEq(voteStart, block.timestamp);
        assertEq(voteEnd, block.timestamp + 7 days);
        assertFalse(executed);
        assertEq(collectorDAO.proposalNonce(), 1);
    }

    function testProposeRevertsIfNotMember() public {
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        bytes memory customError = abi.encodeWithSignature(
            "NotMember()"
        );

        vm.expectRevert(customError);
        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");
    }

    function testProposeRevertsIfInvalidLength() public {
        addresses.push(address(this));
        values.push(0);
        values.push(0);
        calldatas.push("");

        collectorDAO.buyMembership{value: 1 ether}();

        bytes memory customError = abi.encodeWithSignature(
            "InvalidProposalLength()"
        );

        vm.expectRevert(customError);
        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");
    }

    function testProposeRevertsIfInvalidLength_() public {
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");
        calldatas.push("");

        collectorDAO.buyMembership{value: 1 ether}();

        bytes memory customError = abi.encodeWithSignature(
            "InvalidProposalLength()"
        );

        vm.expectRevert(customError);
        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");
    }

    function testProposeRevertsIfEmpty() public {
        values.push(0);
        calldatas.push("");

        collectorDAO.buyMembership{value: 1 ether}();

        bytes memory customError = abi.encodeWithSignature(
            "EmptyProposal()"
        );

        vm.expectRevert(customError);
        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");
    }

    function testVoteYes() public {
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.expectEmit(false, false, false, false);
        emit MemberVoted(address(this), 0, 0);
        collectorDAO.vote(pid, 0);

        ( 
        address creator,
        uint256 allowedVoterRange,
        uint256 yes,
        uint256 no,
        uint256 quorumNeeded,
        uint256 voteStart,
        uint256 voteEnd,
        bool executed
        ) = collectorDAO.proposals(pid);

        assertEq(yes, 1);
        assertEq(no, 0);
    }

    function testVoteNo() public {
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.expectEmit(false, false, false, false);
        emit MemberVoted(address(this), 0, 1);
        collectorDAO.vote(pid, 1);

        ( 
        address creator,
        uint256 allowedVoterRange,
        uint256 yes,
        uint256 no,
        uint256 quorumNeeded,
        uint256 voteStart,
        uint256 voteEnd,
        bool executed
        ) = collectorDAO.proposals(pid);

        assertEq(yes, 0);
        assertEq(no, 1);
    }

    function testVoteRevertsIfNotMember() public {
        bytes memory customError = abi.encodeWithSignature(
            "NotMember()"
        );

        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.prank(vm.addr(4));
        vm.expectRevert(customError);
        collectorDAO.vote(pid, 0);
    }

    function testVoteRevertsIfMemberAlreadyVoted() public {
        bytes memory customError = abi.encodeWithSignature(
            "MemberHasAlreadyVoted()"
        );

        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        collectorDAO.vote(pid, 0);

        vm.expectRevert(customError);
        collectorDAO.vote(pid, 0);
    }

    function testVoteRevertsIfProposalDoesNotExist() public {
        bytes memory customError = abi.encodeWithSignature(
            "ProposalDoesNotExist()"
        );

        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.expectRevert(customError);
        collectorDAO.vote(5, 0);
    }

    function testVoteRevertsIfVotingHasEnded() public {
        bytes memory customError = abi.encodeWithSignature(
            "VotingHasEnded()"
        );

        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(customError);
        collectorDAO.vote(0, 0);
    }

    function testVoteRevertsIfVoterDenied() public {
        bytes memory customError = abi.encodeWithSignature(
            "VoterDenied()"
        );

        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        vm.expectRevert(customError);
        collectorDAO.vote(0, 0);
        vm.stopPrank();
    }

    function testVoteWithSig() public {
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        vm.stopPrank();

        vm.expectEmit(false, false, false, false);
        emit MemberVotedWithSignature(vm.addr(5), 0, 0);
        collectorDAO.voteWithSig(sigVote, v, r, s);

        ( 
        ,,
        uint256 yes,
        uint256 no,,,,
        ) = collectorDAO.proposals(pid);

        assertEq(yes, 1);
        assertEq(no, 0);
        assertTrue(collectorDAO.hasVoted(pid, vm.addr(5)));
    }

    function testVoteWithSigRevertsIfInvalidSignature() public {
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(6));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        vm.stopPrank();

        bytes memory customError = abi.encodeWithSignature(
            "InvalidSignature()"
        );

        vm.expectRevert(customError);
        collectorDAO.voteWithSig(sigVote, v, r, s);
    }

    function testVoteWithSigRevertsIfNotAMember() public {
        vm.deal(vm.addr(6), 1000 ether);
        vm.startPrank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.stopPrank();
        vm.startPrank(vm.addr(5));

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        vm.stopPrank();

        bytes memory customError = abi.encodeWithSignature(
            "NotMember()"
        );

        vm.expectRevert(customError);
        collectorDAO.voteWithSig(sigVote, v, r, s);
    }

    function testVoteWithSigRevertsIfAlreadyVoted() public {
        vm.deal(vm.addr(6), 1000 ether);
        vm.startPrank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(6));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(6, hash_);

        bytes memory customError = abi.encodeWithSignature(
            "MemberHasAlreadyVoted()"
        );

        collectorDAO.vote(pid, 0);

        vm.expectRevert(customError);
        collectorDAO.voteWithSig(sigVote, v, r, s);
    }

    function testVoteWithSigRevertsIfAlreadyVoted_() public {
        vm.deal(vm.addr(6), 1000 ether);
        vm.startPrank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(6));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(6, hash_);

        bytes memory customError = abi.encodeWithSignature(
            "MemberHasAlreadyVoted()"
        );

        collectorDAO.voteWithSig(sigVote, v, r, s);

        vm.expectRevert(customError);
        collectorDAO.voteWithSig(sigVote, v, r, s);
    }

    function testVoteWithSigRevertsIfProposalDoesNotExist() public {
        vm.deal(vm.addr(6), 1000 ether);
        vm.startPrank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(0, 0, vm.addr(6));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(6, hash_);

        bytes memory customError = abi.encodeWithSignature(
            "ProposalDoesNotExist()"
        );

        vm.expectRevert(customError);
        collectorDAO.voteWithSig(sigVote, v, r, s);
    }

    function testVoteWithSigRevertsIfVotingHasEnded() public {
        vm.deal(vm.addr(6), 1000 ether);
        vm.startPrank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(6));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(6, hash_);

        bytes memory customError = abi.encodeWithSignature(
            "VotingHasEnded()"
        );

        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(customError);
        collectorDAO.voteWithSig(sigVote, v, r, s);
    }

    function testVoteWithSigRevertsIfVoterDenied() public {
        vm.deal(vm.addr(6), 1000 ether);
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        vm.stopPrank();
        vm.startPrank(vm.addr(5));

        collectorDAO.buyMembership{value: 1 ether}();

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        vm.stopPrank();

        bytes memory customError = abi.encodeWithSignature(
            "VoterDenied()"
        );

        vm.expectRevert(customError);
        collectorDAO.voteWithSig(sigVote, v, r, s);
    }

    function testBatchVote() public {
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        sigs.push(sigVote);
        vs.push(v);
        rs.push(r);
        ss.push(s);

        assertEq(collectorDAO.EIP712_DOMAIN_TYPE(), EIP712_DOMAIN_TYPE);
        assertEq(collectorDAO.EIP712_DOMAIN_TYPEHASH(), EIP712_DOMAIN_TYPEHASH);
        assertEq(collectorDAO.SIG_VOTE_TYPEHASH(), SIG_VOTE_TYPEHASH);
        assertEq(collectorDAO.APP_NAME(), APP_NAME);
        assertEq(collectorDAO.VERSION(), VERSION);

        vm.stopPrank();

        vm.expectEmit(false, false, false, false);
        emit MemberVotedWithSignature(vm.addr(5), 0, 0);
        collectorDAO.batchVoteWithSig(sigs, vs, rs, ss);

        ( 
        ,,
        uint256 yes,
        uint256 no,,,,
        ) = collectorDAO.proposals(pid);

        assertEq(yes, 1);
        assertEq(no, 0);
        assertTrue(collectorDAO.hasVoted(pid, vm.addr(5)));
    }

    function testBatchVoteWithSigRevertsIfInvalidSigLength() public {
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        sigs.push(sigVote);
        sigs.push(sigVote);
        vs.push(v);
        rs.push(r);
        ss.push(s);

        vm.stopPrank();

        bytes memory customError = abi.encodeWithSignature(
            "InvalidLengthSig()"
        );

        vm.expectRevert(customError);
        collectorDAO.batchVoteWithSig(sigs, vs, rs, ss);
    }

    function testBatchVoteWithSigRevertsIfEmptySigLength() public {
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        vs.push(v);
        rs.push(r);
        ss.push(s);

        vm.stopPrank();

        bytes memory customError = abi.encodeWithSignature(
            "EmptySig()"
        );

        vm.expectRevert(customError);
        collectorDAO.batchVoteWithSig(sigs, vs, rs, ss);
    }

    function testBatchVoteWithSigRevertsIfInvalidVLength() public {
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        sigs.push(sigVote);
        vs.push(v);
        vs.push(v);
        rs.push(r);
        ss.push(s);

        vm.stopPrank();

        bytes memory customError = abi.encodeWithSignature(
            "InvalidLengthSig()"
        );

        vm.expectRevert(customError);
        collectorDAO.batchVoteWithSig(sigs, vs, rs, ss);
    }

    function testBatchVoteWithSigRevertsIfInvalidRLength() public {
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        sigs.push(sigVote);
        vs.push(v);
        rs.push(r);
        rs.push(r);
        ss.push(s);

        vm.stopPrank();

        bytes memory customError = abi.encodeWithSignature(
            "InvalidLengthSig()"
        );

        vm.expectRevert(customError);
        collectorDAO.batchVoteWithSig(sigs, vs, rs, ss);
    }

    function testBatchVoteWithSigRevertsIfInvalidSLength() public {
        vm.deal(vm.addr(5), 1000 ether);
        vm.startPrank(vm.addr(5));
        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(this));
        values.push(0);
        calldatas.push("");

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "");

        CollectorDAO.SigVote memory sigVote = CollectorDAO.SigVote(pid, 0, vm.addr(5));
        bytes32 hash_ = keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_TYPE, 
        keccak256(
            abi.encode(
                SIG_VOTE_TYPEHASH,
                sigVote.proposalId,
                sigVote.support,
                sigVote.voter
            )
        )));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(5, hash_);

        sigs.push(sigVote);
        vs.push(v);
        rs.push(r);
        ss.push(s);
        ss.push(s);

        vm.stopPrank();

        bytes memory customError = abi.encodeWithSignature(
            "InvalidLengthSig()"
        );

        vm.expectRevert(customError);
        collectorDAO.batchVoteWithSig(sigs, vs, rs, ss);
    }

    function testExecute() public {
        vm.deal(vm.addr(6), 10 ether);
        vm.prank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(mockNftMarketplace));
        values.push(1 ether);
        calldatas.push(abi.encodeWithSignature("buy(address,uint256)", address(mockNftMarketplace), 1));

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "buy nft");

        collectorDAO.vote(pid, 0);
        vm.warp(block.timestamp + 8 days);
        assertTrue(collectorDAO.proposalPassed(pid));

        vm.deal(vm.addr(5), 5 ether);
        vm.prank(vm.addr(5));
        collectorDAO.execute(pid, addresses, values, calldatas);

        ( 
        address creator,
        uint256 allowedVoterRange,
        uint256 yes,
        uint256 no,
        uint256 quorumNeeded,
        uint256 voteStart,
        uint256 voteEnd,
        bool executed
        ) = collectorDAO.proposals(pid);

        (uint256 id, uint256 votingPower) = collectorDAO.members(creator);

        assertTrue(executed);
        assertEq(votingPower, 2);
        assertEq(vm.addr(5).balance, 5.01 ether);
    }

    function testExecute_() public {
        vm.deal(vm.addr(6), 10 ether);
        vm.prank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(collectorDAO));
        values.push(0);
        calldatas.push(abi.encodeWithSignature("buyNFTFromMarketplace(address,address,uint256,uint256)", address(mockNftMarketplace), address(mockNftMarketplace), 1, 1 ether));

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "buy nft");

        collectorDAO.vote(pid, 0);
        vm.warp(block.timestamp + 8 days);
        assertTrue(collectorDAO.proposalPassed(pid));

        vm.deal(vm.addr(5), 5 ether);
        vm.prank(vm.addr(5));
        collectorDAO.execute(pid, addresses, values, calldatas);

        ( 
        address creator,
        uint256 allowedVoterRange,
        uint256 yes,
        uint256 no,
        uint256 quorumNeeded,
        uint256 voteStart,
        uint256 voteEnd,
        bool executed
        ) = collectorDAO.proposals(pid);

        (uint256 id, uint256 votingPower) = collectorDAO.members(creator);

        assertTrue(executed);
        assertEq(votingPower, 2);
        assertEq(vm.addr(5).balance, 5.01 ether);

        address nftOwner = mockNftMarketplace.ownerOf(1);
        assertEq(nftOwner, address(collectorDAO));
    }
    function testExecuteReverts() public {
        vm.deal(vm.addr(6), 10 ether);
        vm.prank(vm.addr(6));
        collectorDAO.buyMembership{value: 1 ether}();

        collectorDAO.buyMembership{value: 1 ether}();
        addresses.push(address(collectorDAO));
        values.push(0);
        calldatas.push(abi.encodeWithSignature("buyNFTFromMarketplace(address,address,uint256,uint256)", address(mockNftMarketplace), address(mockNftMarketplace), 1, 0.1 ether));

        uint256 pid = collectorDAO.propose(addresses, values, calldatas, "buy nft");

        collectorDAO.vote(pid, 0);
        vm.warp(block.timestamp + 8 days);
        assertTrue(collectorDAO.proposalPassed(pid));

        vm.deal(vm.addr(5), 5 ether);
        vm.prank(vm.addr(5));

        bytes memory customError = abi.encodeWithSignature(
            "ExecutionFailed()"
        );

        vm.expectRevert(customError);
        collectorDAO.execute(pid, addresses, values, calldatas);
    }
}