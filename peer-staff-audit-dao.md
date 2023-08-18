**This is the staff audit for the code you performed a peer audit on. We give you this so you can compare your peer audit against a staff audit for the same project.**

https://github.com/0xMacro/student.zouvier/tree/2066ea9e333003dffa7012f7893eeb97b6a7b30f/dao

Audited By: Leoni Mella (MrLeoni)

# General Comments

Hi Zoumana! It's me again 👋
Good job completing your DAO project! In general terms I felt that you were on the right track and maybe if you had more time you would have nailed it! I found some vulnerabilities and technical mistakes that were described in the following topics.

Another point is that I have to add 1 point for lacking testing. There was only a phew and they were breaking when I tried to run! I hope this audit will clarify some aspects of the project and set you on the right path for the next one! 🚀

# Design Exercise

Your answer was quite good, but your code example might not work as you think, because when we find out that a user delegated its vote we can't allow that same user to vote, instead the delegated user will.

And to this we'll have to add another process that once a delegated user votes, we compute all delegate votes that he had.

# Issues

## **[Insufficient Tests]** Lacking of integration tests (2 point)

There were not enough tests to cover all the functionalities in the project.

## **[H-1]** Reentrancy vulnerability in execute function (3 points)

In the `executeProposal` function, we have a loop calling arbitrary addresses with no guards to prevent a reentrancy attack in the same function. For example, if a proposal is sending out ETH, the receiving contract could reenter and re-execute the same proposal to send out more ETH over and over.

functions like `DAO.execute`, which can make any function call to any contract are the exact types of functions you want reentrancy guards on. If there is even a single contract that could be called for which you do not know if the source code is safe (and thus might be malicious), there is a real possibility of reentrancy.

One possible way to correct this is described in the **[M-1]** topic

## **[H-2]** Members can buy any NFT using `buyNFTFromMarketplace` function (3 points)

`buyNFTFromMarketplace()` function is an `external` function with members only access control. An attacker can list their NFT on the marketplace, buy a membership and call this function to buy it, effectively stealing funds from the DAO's balance.

Be sure this function can only be called by the DAO itself

`require(msg.sender == address(this), "ONLY_DAO");`

## **[M-1]** Proposals can be executed more than once (2 points)

The contract Proposal execution logic does not contain any state to keep track of if a Proposal has already been executed, and so there's nothing stopping an address from calling execute multiple times.

Before executing you need a check which verifies the Proposal has never been executed before, and prior to using `.call`, marks it as executed.

## **[L-1]** DAO allows new members to vote on a proposal created before joining, if both transactions are in the same block (1 point)

In the `_castVote` function, you do the following to check that the member did not join after the proposal was created:

```solidity
 require(members[voter].joinedAt < proposals[proposalId].endTime - VOTING_DURATION, "Member joined after proposal creation");
```

There is an edge case that is missed by this logic - the voter's `join` could fall after the proposal creation but still be in the same block, in which case the two transactions would have the same `block.timestamp` and we would have `members[voter].joinedAt == proposals[proposalId].endTime - VOTING_DURATION`. This voter would be able to vote on this proposal, contrary to the requirement of the voter joining before proposal creation in order to be able to vote.

Consider taking a different approach for determining whether the voter joined before proposal creation, such as assigning an incrementing ID to each proposal and recording on each `Member` the largest ID of a proposal in existence when the member joins.

## **[Technical-Mistake 01]** Quorum should be 25% of total members (2 points)

The project spec states that a quorum of 25% is needed, but instead of counting the number of members who voted for a proposal, you are counting the total voting power and comparing it to the total number of members at the time of proposal creation.

Also the `totalVotingPower` state variable, in my understanding, ends up working as a member count and some sort of voting power. If this variable was not incremented when a proposal is executed, I believe would only be a bad name for a `totalMember` variable. The problem is when the contract increments the `totalVotingPower` in proposal execution, so I didn't quite understand what was the goal of this variable in your contract.

Consider using the number of votes when checking if the quorum is met, instead of the sum of the voting powers of those votes.

## **[Technical-Mistake 02]** Unnecessary `safeTransferFrom` call on buy NFT function (1 point)

At the end of `buyNFTFromMarketplace` the function has a call to the ERC721 method `safeTransferFrom(address from, address to, uint256 tokenId)`.

This has a high chance of reverting because this method needs that the DAO contract is set as approved or operator of the NFT before calling the `safeTransferFrom`.

For this project, the NFT transfer logic was implicitly expected to operate at the `buy` function on the marketplace. 

## **[Technical-Mistake 03]** Importing code not specified in the project spec (1 point)

For this project you could not make any third party imports. We want you to gain experience implementing functionality yourself, so that when you're writing code for production, you will understand how the OpenZeppelin contracts work.

## **[Technical-Mistake 04]** DAO contract doesn’t implement onERC721Received (1 point)

The ERC721 spec contains a `safeTransferFrom` function that will fail if the recipient address does not implement the `onERC721Received` callback function. This means it's possible for the DAO to pass a Proposal for purchasing an NFT, but then have that transaction fail because the NftMarketplace used `safeTransferFrom`.

Consider implementing ERC721.onERC721Received, see the OZ contract for more info: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol

## **[Technical-Mistake 05]** `block.chainid` calculated only in the constructor does not protect against replay attacks (1 point)

Inside of your constructor you have the following code:

```solidity
DOMAIN_SEPARATOR = keccak256(
    abi.encode(
        DOMAIN_TYPEHASH,
        keccak256(bytes(NAME)),
        keccak256(bytes(VERSION)),
        block.chainid,
        address(this)
    )
);
```

Because you're calculating the EIP-712 domain hash at time of deployment, it means forever after that signatures generated for this contract must use the same block.chainid calculated in the constructor. Let's assume you're deploying to Ethereum Mainnet, where the `chainid == 1`

Now, if Ethereum has a fork and the fork's `chainid == 42`, then that new fork will continue to accept signatures with `chainid == 1`, when it should only accept signatures with `chainid == 42`. The domain hash is no longer doing its job of preventing replay protection.

Consider calculating the EIP-712 domain hash dynamically, inside of your vote-by-signature function. It costs a little bit more gas but is safer.

See OpenZeppelin for how they try to save gas by caching the value, and update the cache by checking if the block.chainid matches: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol#L70

## **[Technical-Mistake 06]** +1 what Justin Brown said about `createProposal` does not take into account the values of a call (1 point)

Without a values array no proposal can be made to send eth out of the contract when making a call. For example if you wanted to call your crowdfunder app you would not be able to contribute because you have no way to send eth

Consider adding an array of values function `createProposal(address[] memory targets, uint256[] values, bytes[] memory data) external`

## **[Q-1]** Repeated Marketplace Interface declaration

Throughout the `.sol` files in your project you declared three different `INftMarketplace`. Consider using this interface as an import of `test/INftMarketplace.sol`, making it easier to maintain.

## **[Q-2]** `createProposal` has variables initialization with default values

In `theDao.sol` at lines 111, 112 and 113 the contract initializes the following variables on a new proposal:

```solidity
proposal.yesVotes = 0;
proposal.noVotes = 0;
proposal.executed = false;
```

But these values are the defaults from their respective types, making it redundant and a bit more gas expensive. Consider remove initialization of default values

# Score

| Reason                     | Score |
| -------------------------- | ----- |
| Late                       | 0     |
| Unfinished features        | 0     |
| Extra features             | 0     |
| Vulnerability              | 9     |
| Unanswered design exercise | 0     |
| Insufficient tests         | 2     |
| Technical mistake          | 7     |

Total: 18
