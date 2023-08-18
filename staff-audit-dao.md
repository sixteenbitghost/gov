https://github.com/0xMacro/student.sunbreather/tree/d7fad2535dff0163bddaf4dc13902ec445de017d/dao

Audited By: Eman Herawy (emanherawy)

# General Comments

Hi Justin,

Good job on implementing this complex project. I can see that you put a lot of effort into it. I think the missing parts might be due to the time constraint and I assume you were in a hurry because I saw you submitted it 34 minutes before the deadline. I would encourage you to spend more time in reviewing the specs and make sure you are implementing all the required functions exactly as specified. In addition to that, I have a few comments below, but overall I think you did a good job!

# Design Exercise

I would encourage you to be more verbose in your answers to these questions. The more detail you provide, the more we can understand your thought process and the more we can help you improve.
To be honest, it was hard to understand your answers and I'm a bit confused why you are delegating the votes to the proposal, not a DAO member.

```
// check signatures before calling this function
function delegateVotes(from, to, proposalId) internal {
    if(member[from].amountDelegated[proposalId] == member[from].votingPower) revert NoMoreDelegationAllowed
    // perform other checks
    member[from].amountDelegated[proposalId] = member[from].votingPower;
    member[to].delegationReceived[proposalId] += member[from].votingPower;

    // call voting function

}
```

# Issues

## **[H-1]** Malicious executor can execute any functions without DAO members' approval and drain the DAO funds (3 points).

In `propose` line 160 are not storing any fingerprint for the proposal contents. In `execute` line 248, you are allowing any set functions to be executed as long as it was claimed to be belong to a successful non-executed proposal. When someone calls `execute` and provides the `_targets, _values, _calldatas`, you do not check whether these match what was provided when the proposal was originally proposed. So a malicious executor can pass any functions to `execute` and it will be executed even if they were completely different than what DAO members' voted for. This is a high vulnerability attack and can drain the DAO funds. Consider storing a fingerprint for the proposal and checking it before executing the proposal.

Consider hashing the proposal function call data and storing the result onto the proposal struct.

## **[Technical-Mistake-1]** block.chainid calculated only in the constructor does not protect against replay attacks (1 point)

Inside of your constructor you have the following code:

```solidity
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
```

Because you're calculating the EIP-712 domain hash at time of deployment, it means forever after that signatures generated for this contract must use the same `block.chainid` calculated in the constructor. Let's assume you're deploying to Ethereum Mainnet, where the `chainid == 1`

Now, if Ethereum has a fork and the fork's `chainid == 42`, then that new fork will continue to accept signatures with `chainid == 1`, when it should only accept signatures with `chainid == 42`. The domain hash is no longer doing its job of preventing replay protection.

Consider calculating the EIP-712 domain hash dynamically, inside of your vote-by-signature function. It costs a little bit more gas but is safer.

See OpenZeppelin for how they try to save gas by caching the value, and update the cache by checking if the block.chainid matches: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.1/contracts/utils/cryptography/EIP712.sol#L70

## **[Technical-Mistake-2]** Quorum should be 25% of total members (1 point)

The project spec states that a quorum of 25% is needed, but instead of counting the number of members who voted for a proposal, you are counting the total voting power and comparing it to the total number of members at the time of proposal creation.

```solidity
// line 258:262
           if (_support == uint8(Support.YES)) {
            proposal.yes += member.votingPower;
        } else {
            proposal.no += member.votingPower;
        }
```

Consider using the number of votes when checking if the quorum is met, instead of the sum of the voting powers of those votes.

## **[Q-1]** Prefer Custom Errors over `require`.

In your project you use the word `require` in line 335 `require(msg.sender == address(this));` to check caller and contract state which reverts if the expression is false. The modern-Solidity way to do this is with custom errors, which are preferable because:

1. they allow you to include dynamic values (i.e. local variables) in the error
2. they are slightly more gas efficient

This is an excellent blog post by the Solidity team about custom errors if you are interested: https://blog.soliditylang.org/2021/04/21/custom-errors/

## **[Q-2]** No need to save the proposal's `voteStart`

Proposals start voting as soon as they are created, so there is no need to save the `voteStart` timestamp since no business logic depends on it. You can remove the `voteStart` field from the `Proposal` struct and save some gas.

## **[Q-3]** Unconventional order of variables, events, errors and functions

In ICO project, the declaration order is quite unconventional.

The idiomatic order for variables that I've seen is this:

1. constants/immutables
2. storage variables
3. structs/enums
4. modifiers
5. functions
6. events/errors

I see events come after modifiers sometimes, but 1-3 are almost always at the top of the contract.

Consider writing your contracts with the code declarations as given above. It's especially important because of how in upgradeable contracts the slot numbers of variables is a potential footgun.

## **[Q-4]** First member id should be 1, not 0.

In your `buyMembership` function, When fist member buys a membership, s/he will get a member id of 0. This is because of how EVM initializes variables with default values. This might cause issues with your implementation in line 202 because you won't be able to distinguish between a member with id 0 and a non-member. Consider changing the first member id to be 1 instead of 0.

```solidity
function buyMembership() external payable {
    if (members[msg.sender].votingPower != 0) revert AlreadyMember();
    if (msg.value != 1 ether) revert InvalidInput();
    Member storage member = members[msg.sender];
    member.votingPower++;
    // first one is 0
    member.id = currentMemberCount;
    currentMemberCount++;
    emit MembershipPurchased();
}
```

## **[Q-5]** Consider removing unused `if` condition in `execute` function

In line 310:313 you have the following code:

```solidity
if(success_) {

}
```

Since you are not doing anything with this condition, consider removing it to reduce gas cost and improve code quality. Don't forget to remove `(bool success_,) =` in line 309 as well as this defined variable is not used anywhere else in the function.

## **[Q-6]** Optimize `for` loop and save some gas

I assume in W3 D3, you got introduced to some of the gas saving techniques. one of them is how to optimize `for` loop. I noticed that you can save some gas by optimizing `for` loop in `execute` and `batchVoteWithSig` functions. you can save some gas by changing the `for` loop to something like this:

```solidity
// this is an example of how to optimize for loop
uint256 i;
uint256 length=sigVote.length;
for (; i <length ; ++i) {
    voteWithSig(sigVote[i], v[i], r[i], s[i]);
}
```

## **[Q-7]** Consider declaring `Member` struct in `vote` and `_voteWithSig` with `memory` keyword

In `vote` and `_voteWithSig` functions, you are declaring `Member` struct with `storage` keyword. Since you are not writing anything to this struct within this function, you can declare it with the `memory` keyword instead.

## **[Q-8]** Consider testing a proposal with arbitrary number of functions

In your test, you are testing a proposal that execute 1 function. However, your implementation should work for any number of functions. Consider testing a proposal with arbitrary number of functions to make sure your implementation works as expected.

# Nitpicks

## `allowedVoterRange` could be named `index`

Since the `allowedVoterRange` is just an index, it could be named `index` instead. This would make the code more readable.

## Use more intuitive names for `proposalPassed`

Since this function check if the proposal passed or not, it could be named `isProposalPassed` instead to make the code more readable.

# Score

| Reason                     | Score |
| -------------------------- | ----- |
| Late                       | -     |
| Unfinished features        | -     |
| Extra features             | -     |
| Vulnerability              | 3     |
| Unanswered design exercise | -     |
| Insufficient tests         | -     |
| Technical mistake          | 2     |

Total: 5

Good luck with your next submission!
